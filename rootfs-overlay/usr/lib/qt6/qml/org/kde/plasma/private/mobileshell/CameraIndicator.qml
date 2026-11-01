/*
    m52xq: camera-in-use indicator for the status bar, next to Bluetooth: visible while a camera is in use (virtual camera, plasma-camera, Megapixels)
    SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

Kirigami.Icon {
    id: cameraIcon

    property bool camOn: false

    source: "camera-video-symbolic"
    visible: camOn

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            cameraIcon.camOn = ((data["stdout"] || "").trim() === "on")
            disconnectSource(source)
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource("/usr/local/bin/m52xq-camera-active")
    }
}
