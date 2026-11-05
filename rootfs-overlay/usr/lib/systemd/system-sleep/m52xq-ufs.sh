#!/bin/sh
# m52xq: UFS must use spm_lvl 5 while the system sleeps (s2idle); restore the previous level on resume.
# After resume ModemManager drops the modem ("qcom-soc not supported by any plugin"): restart it and enable the modem again.
U=$(ls /sys/devices/platform/soc*/1d84000.ufshc/spm_lvl 2>/dev/null | head -1)
S=/run/m52xq-ufs-spm-lvl
case "$1" in
pre)
	cat $U > $S 2>/dev/null
	echo 5 > $U 2>/dev/null
	# touch: inhibiting the input device makes the driver send a bare TCM_DISABLE_REPORT byte (the controller may not understand it:
	# awake, black screen, inhibited=1 measured +35..+55 mA, 2026-10-14); only done while /etc/m52xq-touch-inhibit exists (A/B switch)
	if [ -f /etc/m52xq-touch-inhibit ]; then
		for d in /sys/bus/i2c/devices/*-004b/input/input*; do echo 1 > $d/inhibited 2>/dev/null; done
	fi
	# the bandwidth monitors keep a CPU->LLCC (7.4 GB/s) and LLCC->DDR (4 GB/s) vote with the default ALWAYS tag, i.e. also in the sleep set
	# (icc-bwmon has no suspend handling): unbind them for the sleep (measured -12 mA), bind again right after the resume
	for d in 9091000.qcom,cpu-llcc-ddr-bwmon 90b6400.qcom,cpu-cpu-llcc-bwmon 9091000.pmu 90b6400.pmu; do echo $d > /sys/bus/platform/drivers/qcom-bwmon/unbind 2>/dev/null; done
	# the Bluetooth chip (regulators pm7325_l19, pm8350c_l11) stays powered otherwise: block it for the sleep, remember if it was on
	# 2026-11-03 test: /etc/m52xq-sleep-keep-bt keeps Bluetooth (and the shared WCN6750 supplies) on for the sleep
	if [ ! -f /etc/m52xq-sleep-keep-bt ] && rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: no'; then
		touch /run/m52xq-bt-was-on
		rfkill block bluetooth 2>/dev/null
	fi
	;;
post)
	if [ -f /etc/m52xq-touch-inhibit ]; then
		for d in /sys/bus/i2c/devices/*-004b/input/input*; do echo 0 > $d/inhibited 2>/dev/null; done
	fi
	for d in 9091000.qcom,cpu-llcc-ddr-bwmon 90b6400.qcom,cpu-cpu-llcc-bwmon 9091000.pmu 90b6400.pmu; do echo $d > /sys/bus/platform/drivers/qcom-bwmon/bind 2>/dev/null; done
	[ -f $S ] && cat $S > $U 2>/dev/null
	rm -f $S
	# a plain background job is killed when the sleep service ends: run in its own transient unit
	systemd-run --no-block --unit=m52xq-modem-recover --collect /usr/local/bin/m52xq-modem-recover >/dev/null 2>&1
	;;
esac
exit 0
