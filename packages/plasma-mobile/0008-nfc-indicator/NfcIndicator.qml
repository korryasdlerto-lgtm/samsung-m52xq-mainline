/*
    m52xq: NFC indicator for the status bar, next to the location one: visible while the "NFC"
    quick setting (m52xq-nfc) has the NFC chip on.
    SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

Kirigami.Icon {
    id: nfcIcon

    property bool nfcOn: false

    source: "m52xq-nfc-symbolic"
    visible: nfcOn

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            nfcIcon.nfcOn = ((data["stdout"] || "").trim() === "on")
            disconnectSource(source)
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: runner.connectSource("/usr/local/bin/m52xq-nfc status")
    }
}
