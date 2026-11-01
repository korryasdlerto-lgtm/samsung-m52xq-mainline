#!/bin/sh
# Copyright 2022, 2024 Pavel Machek, GPLv2+
# m52xq: POSIX sh version of the Megapixels movie script (postmarketOS has no /bin/bash: "Failed to execute child
# process movie.sh (No such file or directory)" made the video button do nothing).

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GIGA_DIR="$2"
DEST_NAME="$3"
FPS="$4"
MODE="$5"

echo script_dir $SCRIPT_DIR 1>&2
echo GIGA_DIR $GIGA_DIR 1>&2
echo DEST_NAME $DEST_NAME 1>&2
echo FPS $FPS dfps 1>&2

if [ "$1" = "start" ]; then
	mkdir "$GIGA_DIR/sm" || echo Message: NOSPC
	cd "$GIGA_DIR/sm" || exit 1
	/usr/libexec/megapixels/movie_audio_rec $FPS &
	echo $! > "$GIGA_DIR/audio.pid"
	/usr/libexec/megapixels/mpegize.py start "$GIGA_DIR/" "$DEST_NAME" $FPS $MODE
elif [ "$1" = "stop" ]; then
	kill `cat "$GIGA_DIR/audio.pid"`
	rm "$GIGA_DIR/audio.pid"
	cd "$GIGA_DIR"
	/usr/libexec/megapixels/mpegize.py stop "$GIGA_DIR/" "$DEST_NAME" $FPS $MODE
	echo Message: Rec
else
	echo "Unrecognized command"
fi
