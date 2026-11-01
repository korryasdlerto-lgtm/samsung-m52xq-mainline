#!/bin/sh
# M52XQ в44 (01.11): Spacebar turns the notifications of a number off while its chat is open (disableNotificationsForNumber)
# and does not turn them on again when the window is only left in the background: an SMS from that number in sleep came
# without sound and notification, was saved as read and with the receive time (no SIM label). Before every sleep the daemon
# is told that no chat is open; the app sets it again when the chat page is opened.
[ "$1" = pre ] || exit 0
U=user
RT=/run/user/$(id -u $U 2>/dev/null) || exit 0
timeout 3 su $U -s /bin/sh -c "DBUS_SESSION_BUS_ADDRESS=unix:path=$RT/bus busctl --user call org.kde.spacebar.Daemon /Daemon org.kde.spacebar.Daemon disableNotificationsForNumber s ''" >/dev/null 2>&1
exit 0
