import QtQuick

import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.plasma5support as P5Support

// m52xq: loud speaker -> earpiece -> USB headset (if plugged in) for the sound of apps such as Telegram calls
QS.QuickSetting {
    id: root

    property string route: "speaker"

    text: i18n("Sound output")
    icon: route === "earpiece" ? "audio-headphones" : route === "usb" ? "audio-headset" : "audio-speakers"
    enabled: route !== "speaker"
    status: route === "earpiece" ? i18n("Earpiece") : route === "usb" ? i18n("USB headset") : i18n("Speaker")

    function toggle() {
        runner.connectSource("/usr/local/bin/m52xq-audio-route toggle")
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (out === "speaker" || out === "earpiece" || out === "usb") root.route = out
            disconnectSource(source)
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource("/usr/local/bin/m52xq-audio-route status")
    }
}
