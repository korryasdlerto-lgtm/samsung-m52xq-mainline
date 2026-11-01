/*
    m52xq: location (GPS) indicator for the status bar, next to Bluetooth: visible while the "Location"
    quick setting (m52xq-gps) has the GNSS receiver on.
    SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

Kirigami.Icon {
    id: locationIcon

    property bool gpsOn: false

    source: "gps-symbolic"
    visible: gpsOn

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            locationIcon.gpsOn = ((data["stdout"] || "").trim() === "on")
            disconnectSource(source)
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource("/usr/local/bin/m52xq-gps status")
    }
}
