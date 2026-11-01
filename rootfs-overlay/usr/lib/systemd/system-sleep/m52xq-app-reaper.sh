#!/bin/sh
# m52xq: before the sleep end the apps that have no window and play no sound any more (see /usr/local/bin/m52xq-app-reaper)
# v40 (23.10): moved to m52xq-app-reaper.service (WantedBy=/Before=sleep.target). The system-sleep hooks run after
# systemd has frozen user.slice, so here the reaper could never reach KWin or `systemctl --user`: it hung until its
# 10 s timeout on every sleep, did nothing, and made the phone ignore the power key for those seconds.
exit 0
