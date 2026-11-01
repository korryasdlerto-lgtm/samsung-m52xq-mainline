#!/bin/sh
# m52xq v42: the GNSS engine of the modem kept searching the satellites while the phone slept (24.10: "Location" on,
# 8 % in 2.2 h, ~150 mA). Pause it for the sleep (m52xq-gps pause: only the ModemManager location sources, the
# user's switch and the quick setting stay "on") and give it back after a real wake-up. A dark wake-up (a Wi-Fi or
# mobile data packet, system-sleep/m52xq-wifi-dark.sh) keeps it paused: the phone goes back to sleep, and
# m52xq-wifi-dark resumes it if the phone stays awake.
L=/var/log/m52xq-sleep.log
G=/usr/local/bin/m52xq-gps
case "$1" in
pre)
	[ "$($G pause 2>/dev/null)" = paused ] && echo "gps: paused for the sleep" >> $L
	;;
post)
	[ -f /run/m52xq-gps-paused ] || exit 0
	irq=$(cat /sys/power/pm_wakeup_irq 2>/dev/null)
	if [ -n "$irq" ]; then
		for n in ce2 ipa; do
			if [ "$irq" = "$(awk -v n=$n '$NF == n { sub(":", "", $1); print $1 }' /proc/interrupts)" ]; then
				echo "gps: dark wake-up ($n), kept paused" >> $L
				exit 0
			fi
		done
	fi
	echo "gps: resumed after the sleep ($($G resume 2>/dev/null))" >> $L
	;;
esac
exit 0
