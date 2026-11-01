#!/bin/sh
# m52xq: during the sleep the modem may only use GSM (2G). In 3G (UMTS) it never went to sleep (0 % of the sleep time,
# 100-155 mA), in GSM it sleeps 95 % (night of 20-21.10: 35 mA for 11 h instead of 124 mA). Calls and SMS work in 2G.
# After the resume the modes allowed before the sleep come back. Protection: if after a sleep a SIM was not registered
# on GSM (no 2G here), 2G-only is skipped for that SIM for the next 6 hours so it is not left without network.
# v40 dual SIM: every active subscription of the DSDS modem (/etc/m52xq/sim-mode: dsds = SIM1 + SIM2, sim1, sim2) is
# switched through m52xq-nas-mode (own NAS client bound to the subscription; qmicli only reaches SIM1).
# "m52xq-modem-2g.sh restore" gives the saved modes back (m52xq-wifi-dark, when the phone stays awake).
# Off switch: touch /etc/m52xq-modem-2g-off.
N=/usr/local/bin/m52xq-nas-mode
L=/var/log/m52xq-sleep.log
SKIP=/var/lib/m52xq-modem-2g-skip
RUN=/run/m52xq-modem-2g
[ -f /etc/m52xq-modem-2g-off ] && exit 0
[ -f /etc/m52xq/flight ] && exit 0	# flight mode: the modem radio is off anyway
case $(cat /etc/m52xq/sim-mode 2>/dev/null || echo dsds) in
sim1) subs=0 ;;
sim2) subs=1 ;;
*) subs="0 1" ;;
esac

restore() {
	for s in $subs; do
		[ -f $RUN-modes$s ] || continue
		timeout 8 $N $s set "$(cat $RUN-modes$s)" >/dev/null 2>&1
		rm -f $RUN-modes$s
	done
	rm -f /run/m52xq-modem-2g-active
}

case "$1" in
pre)
	mkdir -p ${SKIP%/*}
	for s in $subs; do
		if [ -f $SKIP$s ] && [ $(( $(date +%s) - $(stat -c %Y $SKIP$s) )) -lt 21600 ]; then
			echo "modem-2g: SIM$((s + 1)) skipped (no GSM here at $(date -d @$(stat -c %Y $SKIP$s) +%H:%M))" >> $L
			continue
		fi
		m=$(timeout 8 $N $s get 2>/dev/null) || continue
		case $m in gsm) continue ;; esac
		echo "$m" > $RUN-modes$s
		timeout 8 $N $s set gsm >/dev/null 2>&1 && echo "modem-2g: SIM$((s + 1)) GSM only for the sleep (was $m)" >> $L
	done
	touch /run/m52xq-modem-2g-active
	;;
post)
	[ -f /run/m52xq-modem-2g-active ] || exit 0
	# v40: a Wi-Fi wake-up (WoW, irq ce2) is a short "dark" resume: keep GSM (m52xq-wifi-dark gives the modes back
	# if the phone stays awake) instead of a re-registration on every packet
	irq=$(cat /sys/power/pm_wakeup_irq 2>/dev/null)
	if [ -n "$irq" ] && [ "$irq" = "$(awk '$NF == "ce2" { sub(":", "", $1); print $1 }' /proc/interrupts)" ]; then
		exit 0
	fi
	# v42: a mobile data packet (IPA) is the same short dark resume (system-sleep/m52xq-wifi-dark.sh)
	if [ -n "$irq" ] && [ "$irq" = "$(awk '$NF == "ipa" { sub(":", "", $1); print $1 }' /proc/interrupts)" ]; then
		exit 0
	fi
	for s in $subs; do
		[ -f $RUN-modes$s ] || continue
		if timeout 8 $N $s gsm; then
			rm -f $SKIP$s
			echo "modem-2g: SIM$((s + 1)) was registered on GSM" >> $L
		else
			touch $SKIP$s
			echo "modem-2g: SIM$((s + 1)) NOT registered on GSM during the sleep - 2G-only skipped for 6 h" >> $L
		fi
	done
	restore
	;;
restore)
	restore
	;;
esac
exit 0
