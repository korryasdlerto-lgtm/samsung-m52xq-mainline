# plasma-mobile 6.7.5 patches (m52xq)

| patch | what it does |
|---|---|
| 0001-status-indicators | "camera in use" and "location" (GPS) icons in the status bar |
| 0002-m52xq-drawer-default-action | tapping a notification with a default action in the shade opens the app |
| 0003-m52xq-dual-sim-signal | second signal icon for SIM2 (one ModemManager modem object per SIM) |
| 0004-m52xq-data-sim-mark | "⇅" next to the operator of the SIM that carries mobile data |
| 0005-m52xq-folio-favourites-right-in-landscape | Folio favourites bar always on the right in landscape |
| 0006-m52xq-mobile-data-icon | mobile data icon with access technology, also while Wi-Fi is primary |
| 0007-m52xq-notification-reply | the inline reply of a notification (Telegram "Reply") is actually sent |
| 0008-nfc-indicator/ | NFC icon, prepared, not built yet (see its README) |

The paths in the patches are relative to `src/` of the plasma-mobile-6.7.5 tarball: apply them with
`patch -p1 -d src < …` (the APKBUILD here lists only 0002 and was not used for the phone build).

What runs on the phone was built from the 6.7.5 sources + 0001…0007 at once, against the exact versions installed
on the phone (Plasma 6.7.5, KF6 6.30, Qt 6.11.1; Alpine edge is already on Plasma 6.8, which does not run on 6.7.5),
with the cut-down build files in this folder:

- `CMakeLists.mobileshell-standalone.txt` → only `libmobileshellplugin.so` (+ its `qmldir`)
- `CMakeLists.folio-standalone.txt` → only `org.kde.plasma.mobile.homescreen.folio.so`

The status bar QML is compiled into `libmobileshellplugin.so` (`qmldir`: `prefer :/qt/qml/org/kde/plasma/private/mobileshell/`):
install the `.so` and the `qmldir` together, and always build with all patches (a build without 0001 loses the icons).
The pinned buildroot recipe and the install commands are in the manual, `docs/`, appendix F.
