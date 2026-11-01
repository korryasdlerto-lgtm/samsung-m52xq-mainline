#!/bin/sh
# M52XQ: the phone has ONE analog microphone: the ALSA capture is stereo with the microphone on the left channel only.
# Make a PulseAudio source that duplicates the left channel into both channels and use it as the default source.
SRC=alsa_input.platform-soc_sound.HiFi__Mic__source
i=0
until pactl list short sources 2>/dev/null | grep -q "$SRC"; do
	i=$((i + 1)); [ $i -gt 60 ] && exit 1; sleep 1
done
pactl list short sources | grep -q "^[0-9]*[[:space:]]mic_dup" ||
	pactl load-module module-remap-source master=$SRC source_name=mic_dup \
		source_properties=device.description=Microphone channels=2 \
		channel_map=front-left,front-right master_channel_map=front-left,front-left remix=no >/dev/null
# the session restores its own default source a few seconds after login: keep asserting ours for a while
n=0
while [ $n -lt 30 ]; do
	[ "$(pactl get-default-source)" = mic_dup ] || pactl set-default-source mic_dup
	n=$((n + 1)); sleep 2
done
