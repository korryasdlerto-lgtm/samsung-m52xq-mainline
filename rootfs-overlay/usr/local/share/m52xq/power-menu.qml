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
	// в48: texts in the system language (Qt.locale(); qmlscene gets LANG of the session): ru ko ja zh (simplified) hi ar, else English
	readonly property string lang: Qt.locale().name.substring(0, 2)
	readonly property var texts: {"Reboot menu": {"ru": "Меню перезагрузки", "ko": "재부팅 메뉴", "ja": "再起動メニュー", "zh": "重启菜单", "hi": "रीबूट मेनू", "ar": "قائمة إعادة التشغيل"}, "Reboot": {"ru": "Перезагрузка", "ko": "재부팅", "ja": "再起動", "zh": "重启", "hi": "रीबूट", "ar": "إعادة التشغيل"}, "Reboot to Recovery": {"ru": "Перезагрузка в Recovery", "ko": "리커버리로 재부팅", "ja": "リカバリーで再起動", "zh": "重启到 Recovery", "hi": "रिकवरी में रीबूट", "ar": "إعادة التشغيل إلى Recovery"}, "Power off": {"ru": "Выключение", "ko": "전원 끄기", "ja": "電源を切る", "zh": "关机", "hi": "पावर ऑफ़", "ar": "إيقاف التشغيل"}, "Cancel": {"ru": "Отмена", "ko": "취소", "ja": "キャンセル", "zh": "取消", "hi": "रद्द करें", "ar": "إلغاء"}, "Rebooting…": {"ru": "Перезагрузка…", "ko": "재부팅 중…", "ja": "再起動中…", "zh": "正在重启…", "hi": "रीबूट हो रहा है…", "ar": "جارٍ إعادة التشغيل…"}, "Rebooting to Recovery…": {"ru": "Перезагрузка в Recovery…", "ko": "리커버리로 재부팅 중…", "ja": "リカバリーで再起動中…", "zh": "正在重启到 Recovery…", "hi": "रिकवरी में रीबूट हो रहा है…", "ar": "جارٍ إعادة التشغيل إلى Recovery…"}, "Powering off…": {"ru": "Выключение…", "ko": "전원 끄는 중…", "ja": "電源を切っています…", "zh": "正在关机…", "hi": "पावर ऑफ़ हो रहा है…", "ar": "جارٍ إيقاف التشغيل…"}}
	function t(s) { var d = texts[s]; return (d && d[lang] !== undefined) ? d[lang] : s }
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

				Big { text: win.t("Reboot"); accent: "#2f7de1"; enabled: !win.busy; onClicked: win.choose("reboot", win.t("Rebooting…")) }
				Big { text: win.t("Reboot to Recovery"); enabled: !win.busy; onClicked: win.choose("recovery", win.t("Rebooting to Recovery…")) }
				Big { text: win.t("Power off"); accent: "#b3392f"; enabled: !win.busy; onClicked: win.choose("poweroff", win.t("Powering off…")) }
				Big { text: win.t("Cancel"); enabled: !win.busy; onClicked: Qt.quit() }
			}
		}
	}
}
