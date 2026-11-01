import QtQuick 2.15

import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.plasma5support as P5Support

QS.QuickSetting {
    id: root

    property bool gpsOn: false
    property bool busy: false

    text: i18n("Location")
    icon: "gps-symbolic"
    enabled: gpsOn
    status: busy ? "…" : (gpsOn ? i18n("On") : i18n("Off"))

    settingsCommand: "qmlscene /usr/local/share/m52xq/gps-permissions.qml"

    function toggle() {
        busy = true
        runner.connectSource("/usr/local/bin/m52xq-gps toggle")
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (out === "on") root.gpsOn = true
            else if (out === "off") root.gpsOn = false
            if (source.indexOf("toggle") >= 0) root.busy = false
            disconnectSource(source)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.busy) runner.connectSource("/usr/local/bin/m52xq-gps status")
    }
}
