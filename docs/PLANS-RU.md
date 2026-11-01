# Планы порта m52xq (mainline)

Отложенные задачи, которые надо сделать при удобном случае. Подробности по каждой — в README-PORTIROVANIE-M52-MAINLINE.md
(поиск по дате/ключевому слову). Сделанное отсюда вычёркивать и отмечать, в какую версию вошло.

## Значок NFC в верхнем баре (отложено 2026-10-24: «при следующей пересборке плазмы добавишь»)
- **Сделать при следующей пересборке plasma-mobile (плагин mobileshell).**
- Почему не сделано сразу: бар (`StatusBar.qml`) оболочка берёт из ресурсов, вкомпилированных в `libmobileshellplugin.so`
  (в `qmldir` стоит `prefer :/qt/qml/org/kde/plasma/private/mobileshell/`), файлы на диске игнорирует. Значок GPS
  (`LocationIndicator`) работает, потому что он вкомпилирован патчем 0001.
- Что добавить — патч **0008** (готовые файлы в `архив/в42/plasma-mobile-0008-nfc-indicator/`):
  * `NfcIndicator.qml` — значок `m52xq-nfc-symbolic`, виден при `/usr/local/bin/m52xq-nfc status` = on (опрос 4 с);
  * `qmldir`: строка `NfcIndicator 254.0 NfcIndicator.qml` после LocationIndicator (`qmldir-nfc.diff`);
  * `StatusBar.qml`: `MobileShell.NfcIndicator { … }` перед LocationIndicator (`StatusBar-nfc.diff`);
  * NfcIndicator.qml добавить в список QML-файлов модуля в `src/components/mobileshell/CMakeLists.txt`.
- Собирать вместе со всеми нашими патчами **0001…0007** (`архив/в40/plasma-mobile-shell/`), против точных версий телефона
  (Plasma 6.7.5 / KF6 6.30): среду (buildroot с ~930 закреплёнными пакетами из cache_apk_aarch64) восстановить по рецепту
  README (раздел 2026-10-23 «сборка две SIM в интерфейсе»). **Проект сборки хранить в `архив/`, а не в /tmp** — 24.10 проект
  `scratchpad/build-mobileshell` пропал при перезагрузке компьютера.
- Иконка `usr/share/icons/hicolor/scalable/status/m52xq-nfc-symbolic.svg` и плитка NFC уже сделаны (`архив/в42/nfc-ui/`).
