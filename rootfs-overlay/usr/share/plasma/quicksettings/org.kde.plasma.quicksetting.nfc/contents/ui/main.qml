import QtQuick 2.15

import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.plasma5support as P5Support

QS.QuickSetting {
    id: root

    property bool nfcOn: false
    property bool busy: false

    text: i18n("NFC")
    icon: "m52xq-nfc-symbolic"
    enabled: nfcOn
    status: busy ? "…" : (nfcOn ? i18n("On") : i18n("Off"))

    function toggle() {
        busy = true
        runner.connectSource("/usr/local/bin/m52xq-nfc toggle")
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (out === "on") root.nfcOn = true
            else if (out === "off") root.nfcOn = false
            if (source.indexOf("toggle") >= 0) root.busy = false
            disconnectSource(source)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.busy) runner.connectSource("/usr/local/bin/m52xq-nfc status")
    }
}
