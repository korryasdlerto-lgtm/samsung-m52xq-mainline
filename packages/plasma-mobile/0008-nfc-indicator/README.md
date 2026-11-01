# plasma-mobile 0008: NFC indicator (prepared, not built yet)

NFC icon in the status bar, visible while `/usr/local/bin/m52xq-nfc status` reports `on` (polled every 4 s).

The status bar is compiled into `libmobileshellplugin.so` (its `qmldir` has
`prefer :/qt/qml/org/kde/plasma/private/mobileshell/`), so QML files on disk are ignored:
this has to go into the next plasma-mobile build together with patches 0001…0007.

- `NfcIndicator.qml` → `components/mobileshell/qml/statusbar/indicators/`, and add it to the QML file
  list in `components/mobileshell/CMakeLists.txt`
- `qmldir-nfc.diff`: the line `NfcIndicator 254.0 NfcIndicator.qml` after `LocationIndicator`
- `StatusBar-nfc.diff`: `MobileShell.NfcIndicator { … }` before `LocationIndicator`

Both diffs were made against the installed files of plasma-mobile 6.7.5 (paths under `/usr/lib/qt6/qml`);
apply the same change to the matching source files. The icon `m52xq-nfc-symbolic.svg` is in rootfs-overlay.
