# plasma-nm 6.7.5 patch (m52xq)

`plasma-nm-0001-m52xq-sim-display-id-by-slot.patch`: with both SIMs active (one ModemManager modem object per SIM)
the SIM is numbered by the card slot of its modem (`PrimarySimSlot` 1/2) instead of the tail of its D-Bus path,
which grows with every ModemManager restart.

Only `libplasmanm_cellular.so` is rebuilt, with `CMakeLists.standalone.txt` (`add_subdirectory(src/libs/cellular)`,
`plasmanm_editor` imported from the phone), against the exact versions installed on the phone (see the manual, `docs/`, appendix F).
Check after the build: same soname and NEEDED as the phone's library, 266 exported symbols.
