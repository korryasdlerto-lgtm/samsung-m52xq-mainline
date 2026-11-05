# plasma-nm 6.7.5 patch (m52xq)

`plasma-nm-0001-m52xq-sim-display-id-by-slot.patch`: with both SIMs active (one ModemManager modem object per SIM)
the SIM is numbered by the card slot of its modem (`PrimarySimSlot` 1/2) instead of the tail of its D-Bus path,
which grows with every ModemManager restart.

Only `libplasmanm_cellular.so` is rebuilt, with `CMakeLists.standalone.txt` (`add_subdirectory(src/libs/cellular)`,
`plasmanm_editor` imported from the phone), against the exact versions installed on the phone (see the manual, `docs/`, appendix F).
Check after the build: same soname and NEEDED as the phone's library, 266 exported symbols.

## plasma-nm-0002-m52xq-wifi-switch-like-tile.patch (v2)

The Wi-Fi switch of the mobile KCM used `onCheckedChanged` + `handler.enableWireless()`, which also fires on state changes and
looped endlessly on this phone. The patch uses `onToggled` and calls `m52xq-wifi-soft` like the quick-settings tile.

In the v2 zip the page was replaced directly in the zstd resource of `kcm_mobile_wifi.so` (plasma-nm 6.7.5) to stay binary compatible
with the rootfs: a shortened copy of this QML, written at the same place with the length field updated. The zstd frame must carry the
content size, otherwise Qt reports "I/O error". After replacing the file on a running system delete `~/.cache/plasma-settings/qmlcache`.
