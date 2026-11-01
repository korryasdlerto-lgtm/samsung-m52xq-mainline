#!/bin/sh

# The post-processing script gets called after taking a burst of
# pictures into a temporary directory. The first argument is the
# directory containing the raw files in the burst. The contents
# are 1.dng, 2.dng.... up to the number of photos in the burst.
#
# If the capture was from a YUV source instead of raw sensor data
# the burst dir will contain .jpg files instead of .dng files
#
# The second argument is the filename for the final photo without
# the extension, like "/home/user/Pictures/IMG202104031234" 
#
# The third argument is 1 or 0 for the cleanup user config. If this
# is 0 the .dng file should not be moved to the output directory
#
# The post-processing script is responsible for cleaning up
# temporary directory for the burst.

set -e

# m52xq r62: develop the photo below the viewfinder (the camera stays smooth while it is saved)
renice -n 10 -p $$ >/dev/null 2>&1 || true

if [ "$#" -ne 3 ]; then
	echo "Usage: $0 [burst-dir] [target-name] [save-dng]"
	exit 2
fi

BURST_DIR="$1"
TARGET_NAME="$2"
SAVE_DNG="$3"

MAIN_PICTURE="$BURST_DIR"/1

if [ -f "$MAIN_PICTURE.jpg" ]; then
  # Just move over the main jpeg if this was a YUV capture
  cp "$MAIN_PICTURE.jpg" "$TARGET_NAME.jpg"
  echo "$TARGET_NAME.jpg"

  # Clean up the temp dir containing the burst
  rm -rf "$BURST_DIR"
  exit 0
fi

# Copy the first frame of the burst as the raw photo
cp "$BURST_DIR"/1.dng "$TARGET_NAME.dng"

# m52xq r65: a 64 MP photo needs several 16-bit copies of ~0.5 GB each: convert was killed by the OOM killer (and the
# camera with it). Cap ImageMagick's memory and let it spill to a disk cache under ~/.cache (UFS; /tmp is RAM).
# m52xq r66: only for the 64 MP frame: with the cap a 16 MP photo (~256 MB per float copy) spilled to the disk cache
# too and took ~40 s instead of ~8 s
if [ "$(exiftool -s3 -n -ImageWidth "$BURST_DIR/1.dng" 2>/dev/null)" -gt 9000 ] 2>/dev/null; then
	MAGICK_TEMPORARY_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/megapixels-magick"
	mkdir -p "$MAGICK_TEMPORARY_PATH" 2>/dev/null || true
	export MAGICK_TEMPORARY_PATH MAGICK_MEMORY_LIMIT=1536MiB MAGICK_MAP_LIMIT=3GiB MAGICK_AREA_LIMIT=256MP
fi


# Create a .jpg if raw processing tools are installed
DCRAW=""
TIFF_EXT="dng.tiff"
if command -v "dcraw_emu" > /dev/null
then
	DCRAW=dcraw_emu
	# -fbdd 1	Raw denoising with FBDD
	set -- -fbdd 1
elif [ -x "/usr/lib/libraw/dcraw_emu" ]; then
	DCRAW=/usr/lib/libraw/dcraw_emu
	# -fbdd 1	Raw denoising with FBDD
	set -- -fbdd 1
elif command -v "dcraw" > /dev/null
then
	DCRAW=dcraw
	TIFF_EXT="tiff"
	set -- -w
fi

CONVERT=""
if command -v "convert" > /dev/null
then
	CONVERT="convert"
elif command -v "gm" > /dev/null
then
	CONVERT="gm"
fi


if [ -n "$DCRAW" ]; then
	# m52xq r18: the saved photo must look exactly like the viewfinder. Megapixels writes the viewfinder parameters
	# (software gain, white balance gains, black level, gamma) to megapixels-preview when the shutter is pressed.
	# With them the raw frame is developed linearly (no auto brightness, no embedded matrix, no white balance) and
	# the same operations as in the viewfinder shader are applied: (raw - black) * [red,1,blue] * gain, then gamma.
	PREVIEW_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/megapixels-preview"
	LINEAR=0
	if [ -f "$PREVIEW_FILE" ] && [ "$DCRAW" != "dcraw" ]; then
		# -4 = linear 16 bit, no auto brightness, gamma 1; -r 1 1 1 1 = no white balance; -M = no embedded matrix; -o 0 = raw colours
		if $DCRAW -4 -T -o 0 -q 3 -M -r 1 1 1 1 "$MAIN_PICTURE.dng"; then
			LINEAR=1
		fi
	fi
	if [ "$LINEAR" != 1 ]; then
	# +M		use embedded color matrix
	# -H 4		Recover highlights by rebuilding them
	# -o 1		Output in sRGB colorspace
	# -q 3		Debayer with AHD algorithm
	# -T		Output TIFF
	$DCRAW +M -H 4 -o 1 -q 3 -T "$@" "$MAIN_PICTURE.dng"
	fi

	# If imagemagick is available, convert the tiff to jpeg and apply slight sharpening
	if [ -n "$CONVERT" ];
	then
		if [ "$CONVERT" = "convert" ]; then
			# m52xq: digital zoom of the pinch gesture: crop the middle 1/zoom of the picture (zoom is written by Megapixels)
			CROP=""
			ZOOM=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/megapixels-zoom" 2>/dev/null)
			if [ -n "$ZOOM" ] && [ "$(echo "$ZOOM" | awk '{print ($1 > 1.01) ? 1 : 0}')" = 1 ]; then
				PCT=$(echo "$ZOOM" | awk '{printf "%d", 100 / $1}')
				CROP="-gravity center -crop ${PCT}%x${PCT}%+0+0 +repage"
			fi
			if [ "$LINEAR" = 1 ]; then
				# read the viewfinder parameters: gain=.. red=.. blue=.. black=.. gamma=..
				GAIN=$(sed -n 's/.*gain=\([0-9.]*\).*/\1/p' "$PREVIEW_FILE")
				RED=$(sed -n 's/.*red=\([0-9.]*\).*/\1/p' "$PREVIEW_FILE")
				BLUE=$(sed -n 's/.*blue=\([0-9.]*\).*/\1/p' "$PREVIEW_FILE")
				BLACK=$(sed -n 's/.*black=\([0-9.]*\).*/\1/p' "$PREVIEW_FILE")
				GAMMA=$(sed -n 's/.*gamma=\([0-9.]*\).*/\1/p' "$PREVIEW_FILE")
				BLACK_PCT=$(echo "$BLACK" | awk '{printf "%.4f", $1 * 100}')
				INVG=$(echo "$GAMMA" | awk '{printf "%.5f", 1 / $1}')
				# m52xq r63: the gain comes from the viewfinder; right after a camera start it can still be far too high
				# (x8 on an already bright raw: blown out, red highlights, blue veil). Measure the clipped share on a
				# small copy and lower the gain until at most 2 % of the picture clips.
				clip_share() {
					convert "$MAIN_PICTURE.$TIFF_EXT" -sample 640x -set colorspace RGB \
						-evaluate subtract "${BLACK_PCT}%" -clamp \
						-channel R -evaluate multiply "$RED" +channel \
						-channel B -evaluate multiply "$BLUE" +channel \
						-evaluate multiply "$1" -fx "max(r,max(g,b))" -threshold 98% \
						-format "%[fx:mean]" info: 2>/dev/null || echo 0
				}
				i=0
				while [ $i -lt 8 ]; do
					C=$(clip_share "$GAIN")
					[ "$(echo "$C $GAIN" | awk '{print ($1 > 0.02 && $2 > 1.0) ? 1 : 0}')" = 1 ] || break
					GAIN=$(echo "$GAIN" | awk '{printf "%.5f", $1 * 0.8}')
					i=$((i + 1))
				done
				[ $i -gt 0 ] && echo "postprocess: gain lowered to $GAIN (clipped share was too high)" >&2
				# m52xq r30: the front camera DNG carries Orientation 4 (mirror vertical) and the developed picture came
				# out upside down (radiator above the window): flip it back; the rear camera has no such tag
				FLIPOP=""
				DENOISE=""
				if command -v exiftool > /dev/null && [ "$(exiftool -s3 -n -Orientation "$MAIN_PICTURE.dng" 2>/dev/null)" = "4" ]; then
					FLIPOP="-flip"
					# m52xq r33: the front camera shoots with a software gain of x4..x16 in dark rooms and the grain was
					# plainly visible; wavelet denoising at 10 % halves it and keeps the edges
					DENOISE="-wavelet-denoise 10%"
					# m52xq r62: the 32 MP full frame: the full-size wavelet took ~18 s (with the viewfinder running ~1 min);
					# denoise a half-size copy and blend it 70/30 with the original (~5 s)
					if [ "$(exiftool -s3 -n -ImageWidth "$MAIN_PICTURE.dng" 2>/dev/null)" -gt 5000 ] 2>/dev/null; then
						DENOISE="( +clone -resize 50% -wavelet-denoise 10% -resize 200% ) -compose blend -define compose:args=70 -composite"
					fi
				fi
				convert "$MAIN_PICTURE.$TIFF_EXT" $CROP $FLIPOP -set colorspace RGB \
					-evaluate subtract "${BLACK_PCT}%" -clamp \
					-channel R -evaluate multiply "$RED" +channel \
					-channel B -evaluate multiply "$BLUE" +channel \
					-evaluate multiply "$GAIN" -clamp \
					-evaluate pow "$INVG" -clamp \
					-function polynomial -1,1.5,0.5,0 \
					-color-matrix "3x3: 1.17525 -0.14675 -0.0285  -0.07475 1.10325 -0.0285  -0.07475 -0.14675 1.2215" -clamp \
					-set colorspace sRGB $DENOISE -unsharp 0x1.0+0.9+0.03 -quality 92 "$TARGET_NAME.jpg"
			else
			convert "$MAIN_PICTURE.$TIFF_EXT" $CROP -sharpen 0x1.0 -sigmoidal-contrast 6,50% "$TARGET_NAME.jpg"
			fi
		else
			# sadly sigmoidal contrast is not available in imagemagick
			gm convert "$MAIN_PICTURE.$TIFF_EXT" -sharpen 0x1.0 "$TARGET_NAME.jpg"
		fi

		# If exiftool is installed copy the exif data over from the tiff to the jpeg
		# since imagemagick is stupid
		if command -v exiftool > /dev/null
		then
			exiftool -tagsFromfile "$MAIN_PICTURE.$TIFF_EXT" \
				 -software="Megapixels" \
				 -overwrite_original "$TARGET_NAME.jpg"
		fi

		echo "$TARGET_NAME.jpg"
	else
		cp "$MAIN_PICTURE.$TIFF_EXT" "$TARGET_NAME.tiff"

		echo "$TARGET_NAME.tiff"
	fi
fi

# Clean up the temp dir containing the burst
rm -rf "$BURST_DIR"

# Clean up the .dng if the user didn't want it
if [ "$SAVE_DNG" -eq "0" ]; then
	rm "$TARGET_NAME.dng"
fi
