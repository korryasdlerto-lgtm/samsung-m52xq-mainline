#!/bin/sh
# M52XQ (v47): keep the Wi-Fi association over a suspend. NetworkManager leaves a device with Wake-on-WLAN up when the system
# goes to sleep, but on the wake-up it "belatedly takes down Wake-on-LAN devices" (nm-manager.c do_sleep_wake): wlan0 ->
# unmanaged -> deauth (DEAUTH_LEAVING, local choice) -> reconnect 7-8 s later, on EVERY wake-up. Telegram's server pushes
# sent in that gap are lost and arrive minutes later (TCP retransmission backoff), also with the screen on (2026-11-05).
# NM asks the kernel whether WoWLAN is armed; this hook runs before logind tells NM about the resume: disarm WoWLAN here,
# NM then keeps wlan0 as it is, and re-arm it 3 s later for the next suspend (same rule as NetworkManager/dispatcher.d/90-m52xq-wowlan).
[ "$1" = post ] || exit 0
[ -e /sys/class/net/wlan0/phy80211 ] || exit 0
phy=$(basename "$(readlink -f /sys/class/net/wlan0/phy80211)")
mac=$(cat /sys/class/net/wlan0/address 2>/dev/null)
iw phy "$phy" wowlan show 2>/dev/null | grep -q 'WoWLAN is enabled' || exit 0
iw phy "$phy" wowlan disable 2>/dev/null
systemd-run --no-block --collect --on-active=3 --unit=m52xq-wowlan-rearm \
	/usr/sbin/iw phy "$phy" wowlan enable disconnect magic-packet patterns "$mac" >/dev/null 2>&1
exit 0
