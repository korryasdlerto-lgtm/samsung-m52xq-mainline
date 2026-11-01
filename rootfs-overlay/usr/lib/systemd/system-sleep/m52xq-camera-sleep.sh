#!/bin/sh
# m52xq: no camera may stay powered while the system sleeps. An open camera application keeps the sensor and the ISP
# runtime-active through s2idle (night 2026-10-16/17 with Megapixels left open: acb3000.isp + s5kgw3 active, ~190 mA
# against ~112 mA). Before the sleep: the native camera applications (Megapixels, plasma-camera) are closed the same way
# m52xq-camera-launch does it, and m52xq-virtualcam sees /run/m52xq-camera-sleep and stops both virtual webcams
# (black frames only). After the resume the flag goes away; the virtual webcams start again when somebody reads them.
# A video being recorded is left alone (its camera keeps running).
F=/run/m52xq-camera-sleep
VSTATE=/home/user/.cache/m52xq-virtualcam-state
log() { logger -t m52xq-camera-sleep "$*" 2>/dev/null; }

case "$1" in
pre)
	touch $F
	if pgrep -f '/home/user/Videos/VID' >/dev/null 2>&1; then
		log "a video is being recorded: camera applications left running"
	else
		for name in megapixels plasma-camera; do
			pids=$(pgrep -x "$name")
			[ -n "$pids" ] || continue
			log "closing $name ($pids) for the sleep"
			kill $pids 2>/dev/null
			i=0
			while [ $i -lt 30 ] && pgrep -x "$name" >/dev/null 2>&1; do
				sleep 0.1
				i=$((i + 1))
			done
			pgrep -x "$name" >/dev/null 2>&1 && kill -KILL $(pgrep -x "$name") 2>/dev/null
		done
	fi
	# m52xq-virtualcam polls every 0.5 s: wait until it has stopped its real camera pipeline
	i=0
	while [ $i -lt 40 ] && [ "$(cat $VSTATE 2>/dev/null)" != off ] && [ -f $VSTATE ]; do
		sleep 0.1
		i=$((i + 1))
	done
	[ "$(cat $VSTATE 2>/dev/null)" = off ] || [ ! -f $VSTATE ] || log "virtual webcam still running: $(cat $VSTATE)"
	;;
post)
	rm -f $F
	;;
esac
exit 0
