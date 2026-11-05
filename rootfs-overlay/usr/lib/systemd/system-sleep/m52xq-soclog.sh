#!/bin/sh
# m52xq: log the raw fuel gauge SOC right before and right after every suspend (current during sleep = delta SOC / delta t).
# line: <pre|post> <epoch> <soc_raw 1/256 %> <soc %> <current_avg mA> <vbat mV> cap=<%> variant=<name>
# в44: the full state snapshot (genpd, icc, subsystems, apps, inhibitors, gps, active devices, irq delta) costs CPU on every
# suspend and wake-up; it runs only while /etc/m52xq-soclog-verbose exists. в44 release: without that file nothing is logged.
# While /etc/m52xq-sleepvar-enable exists every sleep cycle also runs one test variant (see m52xq-sleepvar).
L=/var/log/m52xq-sleep.log
# platform state counters (read-only): cluster idle states, cpu0 cpuidle usage, GPU/display runtime state
state() {
	echo "$1-state cl=$(awk 'NR>2{printf "%s:%s/%s ", $1, $3, $4}' /sys/kernel/debug/pm_genpd/power-domain-cluster/idle_states 2>/dev/null) cpu0=$(for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do printf '%s ' $(cat $s/usage); done) gpu=$(cat $(ls -d /sys/devices/platform/soc*/3d00000.* 2>/dev/null | head -n 1)/power/runtime_status 2>/dev/null) mdss=$(cat /sys/devices/platform/soc*/ae00000.display-subsystem/power/runtime_status 2>/dev/null) usb=$(cat $(ls -d /sys/devices/platform/soc*/a600000.* 2>/dev/null | head -n 1)/power/runtime_status 2>/dev/null)" >> $L
	# interconnect votes held at this moment (consumer lines with a non-zero average or peak)
	echo "$1-icc $(awk 'NF>=4 && $1 !~ /@/ && ($3+0>0 || $4+0>0) {printf "%s/%s/%s ", $1, $3, $4}' /sys/kernel/debug/interconnect/interconnect_summary 2>/dev/null | cut -c1-900)" >> $L
	# devices whose runtime PM state is "active" (candidates for the remaining current)
	# remote processors (own firmware, invisible to the CPU counters above): sleep count / accumulated sleep in ms
	# (qcom_stats ticks are 19.2 MHz) + the modem network type and signal
	echo "$1-subsys $(for f in modem adsp wpss; do awk -v n=$f '/^Count/{c=$2} /^Accumulated/{a=$3} END{printf "%s=%s/%dms ", n, c, a/19200}' /sys/kernel/debug/qcom_stats/$f 2>/dev/null; done) $(timeout 2 mmcli -m any --output-keyvalue 2>/dev/null | awk -F': *' '/generic.state /{st=$2} /access-technologies.value\[1\]/{t=$2} /signal-quality.value/{q=$2} END{printf "mm=%s/%s/%s%%", st, t, q}')" >> $L
	# user programs other than the shell services (an app whose window was closed but whose process stayed, e.g. haruna on
	# 19.10): name:pid:RSS MB:CPU seconds
	echo "$1-apps $(for p in /proc/[0-9]*; do [ "$(awk '/^Uid/{print $2}' $p/status 2>/dev/null)" = 10000 ] || continue; n=$(cat $p/comm 2>/dev/null); case "$n" in plasmashell|kwin_wayland*|Xwayland|xwaylandvideobr|plasma-keyboard|kded6|org_kde_powerde|kactivitymanage|kalendarac|xdg-*|wireplumber|pipewire*|pulseaudio|akonadi*|dbus*|systemd|sd-pam|ksmserver|kglobalaccel*|polkit-kde-auth|baloo*|drkonqi*|kwalletd*|ksecretd|kiod6|kioworker|startplasma*|plasma_session|gvfs*|at-spi*|dconf-service|obexd|ssh-agent|gpg-agent|kaccess|kscreen*|m52xq-*|python3|sh|bash|sleep|"") continue;; esac; awk -v n="$n" -v p="${p##*/}" '/VmRSS/{r=int($2/1024)} END{printf "%s:%s:%dM:", n, p, r}' $p/status; awk '{printf "%ds ", ($14+$15)/100}' $p/stat; done 2>/dev/null)" >> $L
	# r4 (2026-10-21): what may spoil the sleep: inhibitors (block = no sleep at all, delay = normal services), sound
	# streams (the audio path stays on) and the modem location (GPS) state
	if [ "$1" = pre ]; then
		UE="XDG_RUNTIME_DIR=/run/user/10000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/10000/bus"
		echo "$1-inhibit $(timeout 3 systemd-inhibit --list --no-pager --no-legend 2>/dev/null | awk '{printf "%s:%s:%s ", $1, $4, $NF}')" >> $L
		# v40: running sound streams straight from the kernel (PulseAudio is frozen with user.slice here: `su user pactl`
		# only waited for its 3 s timeout on every sleep)
		echo "$1-sound $(grep -l RUNNING /proc/asound/card*/pcm*/sub*/status 2>/dev/null | sed 's,/proc/asound/,,; s,/sub[0-9]*/status,,' | tr '\n' ' ')" >> $L
		# v40 dual SIM: the modem object with the GNSS engine (gps-raw), not just the first one
		GM=any
		for m in $(timeout 2 mmcli -L 2>/dev/null | grep -o "Modem/[0-9]*" | cut -d/ -f2); do
			timeout 2 mmcli -m $m --location-status 2>/dev/null | grep -q "capabilities:.*gps-raw" && { GM=$m; break; }
		done
		echo "$1-gps $(timeout 2 mmcli -m $GM --location-status --output-keyvalue 2>/dev/null | sed -n 's/.*location.enabled.value\[[0-9]*\] *: *//p' | tr '\n' ' ')" >> $L
	fi
	echo "$1-active $(for d in /sys/devices/platform/soc*/*/ /sys/bus/i2c/devices/* /sys/bus/spi/devices/*; do [ "$(cat $d/power/runtime_status 2>/dev/null)" = active ] && printf '%s ' $(basename $d); done 2>/dev/null)" >> $L
}
# interrupts that fired during the sleep (snapshot at pre, diff at post) + the IRQ that woke the system
IRQ=/run/m52xq-irq-pre
irq_snap() { awk 'NR>1{t=0;for(i=2;i<=9;i++)t+=$i; print $1, t, $(NF-1), $NF}' /proc/interrupts > "$1"; }
# monotonic clock stops in s2idle, boottime does not: (boot delta - mono delta) = real time asleep
clocks() { echo "$1-clocks mono=$(awk '/now at/{printf "%d", $3/1000000; exit}' /proc/timer_list 2>/dev/null)ms boot=$(awk '{printf "%d", $1*1000}' /proc/uptime)ms" >> $L; }
irq_diff() {
	irq_snap /run/m52xq-irq-post
	echo "irq-delta $(awk 'NR==FNR{a[$1]=$2; next} $2>a[$1]{printf "%s%s=%d ", $3, $4, $2-a[$1]}' $IRQ /run/m52xq-irq-post | cut -c1-600)" >> $L
	echo "wake-irq $(cat /sys/power/pm_wakeup_irq 2>/dev/null) suspends=$(cat /sys/power/suspend_stats/success 2>/dev/null) fail=$(cat /sys/power/suspend_stats/fail 2>/dev/null)" >> $L
}
V=/etc/m52xq-sleep-variant
T0=$(cut -d' ' -f1 /proc/uptime)
case "$1" in
pre)
	if [ -f /etc/m52xq-sleepvar-enable ]; then
		/usr/local/bin/m52xq-sleepvar next > $V
		timeout 8 /usr/local/bin/m52xq-sleepvar apply "$(cat $V)"
	else
		rm -f $V
	fi
	# в44 release: the per-cycle lines (SOC, wake IRQ) only with /etc/m52xq-soclog-verbose (touch it for a sleep measurement)
	if [ -f /etc/m52xq-soclog-verbose ]; then
		state pre; irq_snap $IRQ; clocks pre
		echo "pre $(/usr/local/bin/m52xq-soc 2>/dev/null) cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null) variant=$(cat $V 2>/dev/null)" >> $L
		echo "pre-time start=$T0 end=$(cut -d' ' -f1 /proc/uptime)" >> $L	# v40: how long this hook takes
	fi
	;;
post)
	if [ -f /etc/m52xq-soclog-verbose ]; then
		state post; clocks post; irq_diff
		echo "post $(/usr/local/bin/m52xq-soc 2>/dev/null) cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null) variant=$(cat $V 2>/dev/null)" >> $L
	fi
	[ -f /etc/m52xq-sleepvar-enable ] && systemd-run --no-block --collect --unit=m52xq-sleepvar-restore /usr/local/bin/m52xq-sleepvar restore "$(cat $V)" >/dev/null 2>&1
	;;
esac
exit 0
