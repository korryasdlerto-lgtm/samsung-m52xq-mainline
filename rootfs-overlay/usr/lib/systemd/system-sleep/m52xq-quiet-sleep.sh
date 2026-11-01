#!/bin/sh
# M52XQ в44: fewer wake-ups that the phone causes itself (kernel log M52XQ-RX, 31.10: with Telegram open the first frame after a wake-up
# was in 8 of 20 cases a pure TCP ACK of data the phone had sent just before the suspend, in 2 cases the reply of the NTP request that
# systemd-timesyncd sends right after every resume).
#  pre : stop the NTP client; wait (max 2 s) until the TCP sockets (not ssh) have no unacknowledged data
#  post: start the NTP client again only after 90 s of awake time (monotonic timer: suspended time does not count)
case "$1" in
pre)
	systemctl stop m52xq-ntp-resume.timer m52xq-ntp-resume.service 2>/dev/null
	systemctl stop systemd-timesyncd 2>/dev/null
	i=0
	while [ $i -lt 10 ]; do
		busy=$(ss -tn state established 2>/dev/null | awk 'NR > 1 && $2 > 0 && $4 !~ /:22$/ { n++ } END { print n + 0 }')
		[ "$busy" = 0 ] && break
		sleep 0.2
		i=$((i + 1))
	done
	;;
post)
	systemd-run --quiet --unit=m52xq-ntp-resume --on-active=90 --timer-property=AccuracySec=1s systemctl start systemd-timesyncd 2>/dev/null
	;;
esac
exit 0
