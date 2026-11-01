// SPDX-FileCopyrightText: 2022 Yari Polla <skilvingr@gmail.com>
// SPDX-License-Identifier: LGPL-2.0-or-later
// m52xq: the hotspot runs as a SECOND Wi-Fi interface (wlan1) next to the client connection (m52xq-hotspot.service), so the
// Wi-Fi connection is not dropped; the stock tile used the only adapter for the access point and switched Wi-Fi off.

import QtQuick

import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.plasma5support as P5Support

QS.QuickSetting {
    id: root

    property bool running: false
    property string ssid: "M52XQ"

    text: i18n("Hotspot")
    icon: "network-wireless-hotspot"

    enabled: running
    status: running ? ssid : ""

    function toggle() {
        runner.connectSource("systemctl " + (running ? "stop" : "start") + " m52xq-hotspot.service")
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (source.indexOf("is-active") >= 0) {
                root.running = (out === "active")
            } else if (source.indexOf("grep") >= 0 && out.length > 0) {
                root.ssid = out
            }
            disconnectSource(source)
            if (source.indexOf("systemctl start") >= 0 || source.indexOf("systemctl stop") >= 0) {
                runner.connectSource("systemctl is-active m52xq-hotspot.service")
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            runner.connectSource("systemctl is-active m52xq-hotspot.service")
            runner.connectSource("sed -n s/^ssid=//p /etc/m52xq-hotspot.conf | grep .")
        }
    }
}
