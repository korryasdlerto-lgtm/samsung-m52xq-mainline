// M52XQ: "SIM cards manager" window (qmlscene), started by m52xq-sim-mode-menu: it copies this file to $XDG_RUNTIME_DIR with
// @STATE@ = the path of the state file the script keeps (lines: mode dsds|sim1|sim2, data SIM 1|2, "flight" or "",
// "busy" or "", message, card slots with a SIM "12"/"1"/"2"). With one SIM inserted only the SIM power button works. Three rows of big buttons in the middle of the screen: 1 - SIM mode, 2 - SIM of the mobile
// data, 3 - SIM cards off/on (flight mode). A choice is printed as "m52xq-choice: <action>" (the script does it) and
// the window stays open: it reads the state file every second (XHR, QML_XHR_ALLOW_FILE_READ=1), the buttons are off
// while a switch runs. Only "Close" closes it.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
	id: win
	visible: true
	visibility: Window.FullScreen
	title: "SIM cards manager"
	color: "#101418"

	property string mode: "dsds"
	property string dataSim: "1"
	property bool flight: false
	property bool busy: true
	property string message: ""
	property string cards: "12"
	readonly property bool oneSim: cards.length === 1
	// with one SIM inserted the phone runs on that SIM only: the (grey) buttons show it, whatever mode is saved for
	// the time both SIMs are inserted: "Only SIMx" and "Data: SIMx" of the slot with the card
	readonly property string effMode: oneSim ? "sim" + cards : mode
	readonly property string effData: oneSim ? cards : (mode === "sim1" ? "1" : mode === "sim2" ? "2" : dataSim)
	property real chosenAt: 0
	// landscape: two columns (left: title, state, message, Close; right: the three rows of buttons, ~20 units high)
	readonly property bool landscape: width > height
	// size unit: portrait 1/20 of the width, the whole window (~31 units high) must also fit the height;
	// landscape: both columns (~46 units wide) and the button column (~21 units high) must fit
	readonly property real u: landscape ? Math.min(width / 47, height / 22) : Math.min(width / 20, height / 31)

	function choose(a) {
		busy = true
		chosenAt = Date.now()
		message = "Switching…"
		console.log("m52xq-choice: " + a)
	}

	function readState() {
		var x = new XMLHttpRequest()
		x.open("GET", "file://@STATE@", false)
		x.send()
		var l = x.responseText.split("\n")
		if (l.length < 4 || !l[0])
			return
		if (l[3] !== "busy" && Date.now() - chosenAt < 3000)
			return	// the script has not taken the choice yet
		mode = l[0]
		dataSim = l[1]
		flight = l[2] === "flight"
		busy = l[3] === "busy"
		message = l[4] || ""
		cards = l[5] || "12"
	}

	Timer {
		interval: 1000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: win.readState()
	}

	component Big: Button {
		property bool current: false
		Layout.fillWidth: true
		Layout.preferredHeight: win.u * 3.4
		enabled: !win.busy
		font.pixelSize: win.u * 1.05
		font.bold: current
		background: Rectangle {
			radius: win.u * 0.6
			color: !parent.enabled ? "#1c2228" : parent.current ? "#2f7de1" : parent.down ? "#3a4652" : "#28313a"
			border.color: parent.current ? "#8cc0ff" : "#3a4652"
			border.width: parent.current ? 3 : 1
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

	component Caption: Label {
		Layout.fillWidth: true
		Layout.topMargin: win.u * 0.8
		font.pixelSize: win.u * 0.85
		color: "#aab4be"
		horizontalAlignment: Text.AlignHCenter
	}

	// scrolls only if it still does not fit
	Flickable {
		anchors.fill: parent
		contentWidth: width
		contentHeight: Math.max(height, col.implicitHeight + win.u * 2)
		boundsBehavior: Flickable.StopAtBounds
		clip: true

	GridLayout {
		id: col
		anchors.centerIn: parent
		width: win.landscape ? Math.min(parent.width - win.u * 2, win.u * 46) : Math.min(parent.width - win.u * 2, win.u * 30)
		columns: win.landscape ? 2 : 1
		columnSpacing: win.u * 1.5
		rowSpacing: win.u * 0.6

		// title, state, message (and Close in landscape)
		ColumnLayout {
			Layout.fillWidth: !win.landscape
			Layout.preferredWidth: win.landscape ? win.u * 14 : -1
			Layout.alignment: Qt.AlignVCenter
			spacing: win.u * 0.6

			Label {
				Layout.fillWidth: true
				text: "SIM cards manager"
				font.pixelSize: win.u * 1.6
				font.bold: true
				color: "white"
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
			}
			Label {
				Layout.fillWidth: true
				text: win.flight ? "SIM cards are OFF (flight mode)"
					: win.oneSim ? "Only SIM" + win.cards + " is inserted"
					: (win.mode === "sim1" ? "Only SIM1" : win.mode === "sim2" ? "Only SIM2" : "Both SIMs")
					  + " · data: SIM" + win.effData
				font.pixelSize: win.u * 0.9
				color: win.flight ? "#ff9a5a" : "#8cc0ff"
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
			}
			Label {
				Layout.fillWidth: true
				Layout.preferredHeight: win.u * (win.landscape ? 4 : 2.4)
				text: win.message
				font.pixelSize: win.u * 0.8
				color: win.busy ? "#ffd75a" : "#9be29b"
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				wrapMode: Text.WordWrap
			}
			Big {
				visible: win.landscape
				Layout.topMargin: win.u * 0.6
				Layout.preferredHeight: win.u * 2.6
				text: "Close"
				enabled: true
				onClicked: Qt.quit()
			}
		}

		// the three rows of buttons (and Close in portrait)
		ColumnLayout {
			Layout.fillWidth: true
			Layout.preferredWidth: win.landscape ? win.u * 30 : -1
			spacing: win.u * 0.6

			Caption { text: win.oneSim ? "Mode (one SIM inserted)" : "Mode"; Layout.topMargin: win.landscape ? 0 : win.u * 0.8 }
			RowLayout {
				spacing: win.u * 0.5
				Big { text: "Both\nSIMs"; current: win.effMode === "dsds"; enabled: !win.busy && !win.oneSim; onClicked: win.choose("dsds") }
				Big { text: "Only\nSIM1"; current: win.effMode === "sim1"; enabled: !win.busy && !win.oneSim; onClicked: win.choose("sim1") }
				Big { text: "Only\nSIM2"; current: win.effMode === "sim2"; enabled: !win.busy && !win.oneSim; onClicked: win.choose("sim2") }
			}

			Caption { text: win.mode === "dsds" && !win.oneSim ? "Mobile data" : "Mobile data (choose with both SIMs)" }
			RowLayout {
				spacing: win.u * 0.5
				Big {
					text: "Data: SIM1"; enabled: !win.busy && !win.oneSim && win.mode === "dsds"
					current: win.effData === "1"
					onClicked: win.choose("data1")
				}
				Big {
					text: "Data: SIM2"; enabled: !win.busy && !win.oneSim && win.mode === "dsds"
					current: win.effData === "2"
					onClicked: win.choose("data2")
				}
			}

			Caption { text: "SIM cards power" }
			Big {
				text: win.flight ? "Turn SIM cards ON" : "Turn SIM cards OFF (flight mode)"
				current: win.flight
				onClicked: win.choose("flight")
			}

			Big {
				visible: !win.landscape
				Layout.topMargin: win.u * 1.2
				Layout.preferredHeight: win.u * 2.6
				text: "Close"
				enabled: true
				onClicked: Qt.quit()
			}
		}
	}
	}
}
