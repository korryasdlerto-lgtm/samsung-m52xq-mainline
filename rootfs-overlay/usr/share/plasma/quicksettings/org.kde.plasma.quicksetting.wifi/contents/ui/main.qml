// SPDX-FileCopyrightText: 2022 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later
// m52xq: the tile powers Wi-Fi off for real (m52xq-wifi-soft -> m52xq-wifi-hw: unload ath11k_ahb, WPSS shut down) instead
// of rfkill, with which the WPSS firmware never sleeps; on = WCN6750 re-init + ath11k_ahb (~15-20 s).

import QtQuick 2.15

import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.private.mobileshell as MobileShell

QS.QuickSetting {
    id: root

    property bool softOff: false
    readonly property bool wifiOn: enabledConnections.wirelessEnabled && !softOff
    property int runId: 0
    property double holdUntil: 0

    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            // while WPSS is being started (~15-20 s) the status still says "off": keep the tile on
            if (source.indexOf("/usr/local/bin/m52xq-wifi-soft status") === 0 && Date.now() > root.holdUntil) {
                root.softOff = (data["stdout"] || "").trim() === "off";
            }
            disconnectSource(source);
        }
    }

    function run(arg) {
        runId++;
        exec.connectSource("/usr/local/bin/m52xq-wifi-soft " + arg + " # " + runId);
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run("status")
    }

    Timer {
        id: refresh
        interval: 1500
        onTriggered: root.run("status")
    }

    text: i18n("Wi-Fi")
    status: wifiOn ? MobileShell.NetworkInfo.wirelessStatus.wifiSSID : ""
    icon: wifiOn ? "network-wireless" : "network-wireless-disconnected"
    settingsCommand: "plasma-open-settings kcm_mobile_wifi"
    enabled: wifiOn

    function toggle() {
        if (wifiOn) {
            softOff = true;
            run("off");
            refresh.interval = 2000;
        } else {
            softOff = false;
            holdUntil = Date.now() + 40000;
            run("on");
            refresh.interval = 41000;
        }
        refresh.restart();
    }
}
