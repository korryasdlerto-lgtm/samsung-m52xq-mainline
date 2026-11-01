import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support as P5Support

Kirigami.ApplicationWindow {
    id: win
    title: "Location"
    width: 360
    height: 720
    visible: true

    property bool gpsOn: false

    ListModel { id: apps }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (source.indexOf("apps list") >= 0) {
                apps.clear()
                out.split("\n").forEach(l => {
                    const p = l.split("|")
                    if (p.length === 3) apps.append({ appId: p[0], appName: p[1], state: p[2] })
                })
            } else if (source.indexOf("gps status") >= 0) {
                win.gpsOn = (out === "on")
            }
            disconnectSource(source)
        }
    }
    function run(cmd) { runner.connectSource(cmd) }

    Component.onCompleted: {
        run("/usr/local/bin/m52xq-gps status")
        run("/usr/local/bin/m52xq-gps-apps list")
    }

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: "Location permissions"
        ListView {
            model: apps
            header: ColumnLayout {
                width: parent.width
                Kirigami.SwitchDelegate {
                    Layout.fillWidth: true
                    text: "GPS (location services)"
                    checked: win.gpsOn
                    onToggled: win.run("/usr/local/bin/m52xq-gps " + (checked ? "on" : "off") + " #" + Date.now())
                }
                Kirigami.Heading {
                    level: 4
                    Layout.margins: Kirigami.Units.largeSpacing
                    text: "Apps allowed to use your location"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            delegate: Kirigami.SwitchDelegate {
                width: ListView.view.width
                text: appName
                checked: state === "allow"
                onToggled: {
                    const v = checked ? "allow" : "deny"
                    win.run("/usr/local/bin/m52xq-gps-apps set " + appId + " " + v)
                }
            }
        }
    }
}
