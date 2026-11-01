// M52XQ: "Reboot menu" window (qmlscene), started by /usr/local/bin/m52xq-reboot-recovery: four big buttons - Reboot, Reboot to Recovery (TWRP),
// Power off, Cancel (English only, as the Plasma system language; the Lomiri copy in 003/в4 has Russian texts). A choice is printed as "m52xq-power: <action>" (the script does it).
// "Cancel" closes the window. Portrait: one column; landscape: 2x2 grid so that everything fits on the screen.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
	id: win
	visible: true
	title: "Reboot menu"
	color: "#101418"

	property bool busy: false
	property string message: ""
	readonly property bool landscape: width > height
	readonly property real u: landscape ? Math.min(width / 36, height / 12) : Math.min(width / 20, height / 24)

	function choose(a, text) {
		busy = true
		message = text
		console.log("m52xq-power: " + a)
	}

	component Big: Button {
		property color accent: "#28313a"
		Layout.fillWidth: true
		Layout.preferredHeight: win.u * 3.2
		font.pixelSize: win.u * 1.1
		background: Rectangle {
			radius: win.u * 0.6
			color: !parent.enabled ? "#1c2228" : parent.down ? "#3a4652" : parent.accent
			border.color: "#3a4652"
			border.width: 1
		}
		contentItem: Text {
			text: parent.text
			font: parent.font
			color: parent.enabled ? "white" : "#5a646e"
			horizontalAlignment: Text.AlignHCenter
			verticalAlignment: Text.AlignVCenter
			wrapMode: Text.WordWrap
		}
	}

	Flickable {
		anchors.fill: parent
		contentWidth: width
		contentHeight: Math.max(height, col.implicitHeight + win.u * 2)
		boundsBehavior: Flickable.StopAtBounds
		clip: true

		ColumnLayout {
			id: col
			anchors.centerIn: parent
			width: Math.min(parent.width - win.u * 2, win.u * (win.landscape ? 30 : 17))
			spacing: win.u * 0.7

			Label {
				Layout.fillWidth: true
				text: "Reboot menu"
				font.pixelSize: win.u * 1.7
				font.bold: true
				color: "white"
				horizontalAlignment: Text.AlignHCenter
			}
			Label {
				Layout.fillWidth: true
				visible: win.busy
				text: win.message
				font.pixelSize: win.u * 0.9
				color: "#ffd75a"
				horizontalAlignment: Text.AlignHCenter
			}
			GridLayout {
				Layout.fillWidth: true
				columns: win.landscape ? 2 : 1
				columnSpacing: win.u * 0.7
				rowSpacing: win.u * 0.7

				Big { text: "Reboot"; accent: "#2f7de1"; enabled: !win.busy; onClicked: win.choose("reboot", "Rebooting…") }
				Big { text: "Reboot to Recovery"; enabled: !win.busy; onClicked: win.choose("recovery", "Rebooting to Recovery…") }
				Big { text: "Power off"; accent: "#b3392f"; enabled: !win.busy; onClicked: win.choose("poweroff", "Powering off…") }
				Big { text: "Cancel"; enabled: !win.busy; onClicked: Qt.quit() }
			}
		}
	}
}
