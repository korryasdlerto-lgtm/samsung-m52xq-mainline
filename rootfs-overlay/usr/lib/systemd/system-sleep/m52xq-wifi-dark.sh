#!/bin/sh
# M52XQ: "dark" resume after a Wi-Fi wake-up. With WoW + APF (boot v228) the Wi-Fi firmware wakes the system for a packet
# to us (WOW reason 39 BPF_ALLOW, interrupt ce2), like the stock Android. Plasma then turns the display on and the phone
# stays awake until the normal auto-suspend (60 s + 120 s); m52xq-wifi-dark keeps the display off and suspends again.
# boot v230: the panel driver keeps the display off for $DARK s (dark_resume, set here before user space is thawed), so
# the display no longer flashes; m52xq-wifi-dark ends it (0) when the phone stays awake. Any other wake-up: display on.
QS=/run/m52xq-qrtr-sms-events
# в44: event count of the modem (SMS / voice call) wakeup source, to recognise a modem wake-up (pm_wakeup_irq stays empty for it)
qrtr_events() { for w in /sys/class/wakeup/wakeup*; do [ "$(cat $w/name 2>/dev/null)" = qrtr-voice-sms ] && cat $w/event_count && return; done; echo 0; }
if [ "$1" = pre ]; then
	qrtr_events > $QS
	exit 0
fi
[ "$1" = post ] || exit 0
DR=/sys/module/panel_samsung_s6e3hab_amb667an01/parameters/dark_resume
DARK=40	# boot v232+: the power / volume keys end the dark window in the panel driver
irq=$(cat /sys/power/pm_wakeup_irq 2>/dev/null)
ce2=$(awk '$NF == "ce2" { sub(":", "", $1); print $1 }' /proc/interrupts)
# v42: a packet over mobile data wakes the system through the IPA (irq "ipa") - the same dark resume as Wi-Fi.
# Calls and SMS come over QMI (glink-smem / qrtr-voice-sms), not over the IPA, so they still turn the display on.
ipa=$(awk '$NF == "ipa" { sub(":", "", $1); print $1 }' /proc/interrupts)
case "$irq" in
"") wake= ;;
"$ce2") wake=Wi-Fi ;;
"$ipa") wake="mobile data" ;;
*) wake= ;;
esac
# в44 (01.11, user): an SMS wake-up is dark too (only the notification sound); m52xq-wifi-dark turns the display on for a call
if [ -z "$wake" ] && [ "$(qrtr_events)" != "$(cat $QS 2>/dev/null)" ]; then
	wake=modem
fi
if [ -z "$wake" ]; then
	[ -w $DR ] && echo 0 > $DR
	exit 0
fi
[ -w $DR ] && echo $DARK > $DR
systemd-run --no-block --collect --unit=m52xq-wifi-dark --setenv=WAKE="$wake" /usr/local/bin/m52xq-wifi-dark >/dev/null 2>&1
exit 0
