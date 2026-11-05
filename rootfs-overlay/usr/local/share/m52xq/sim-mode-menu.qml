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
	// в48: texts in the system language (Qt.locale(); qmlscene gets LANG of the session): ru ko ja zh (simplified) hi ar, else English
	readonly property string lang: Qt.locale().name.substring(0, 2)
	readonly property var texts: {"SIM cards manager": {"ru": "Менеджер SIM-карт", "ko": "SIM 카드 관리자", "ja": "SIMカードマネージャー", "zh": "SIM 卡管理器", "hi": "सिम कार्ड प्रबंधक", "ar": "مدير بطاقات SIM"}, "SIM cards are OFF (flight mode)": {"ru": "SIM-карты выключены (режим полёта)", "ko": "SIM 카드 꺼짐 (비행기 모드)", "ja": "SIMカードはオフです（機内モード）", "zh": "SIM 卡已关闭（飞行模式）", "hi": "सिम कार्ड बंद हैं (फ़्लाइट मोड)", "ar": "بطاقات SIM متوقفة (وضع الطيران)"}, "Only SIM%1 is inserted": {"ru": "Вставлена только SIM%1", "ko": "SIM%1만 삽입됨", "ja": "SIM%1のみ挿入されています", "zh": "仅插入了 SIM%1", "hi": "केवल SIM%1 लगा है", "ar": "SIM%1 فقط مُدخلة"}, "Only SIM1": {"ru": "Только SIM1", "ko": "SIM1 전용", "ja": "SIM1のみ", "zh": "仅 SIM1", "hi": "केवल SIM1", "ar": "SIM1 فقط"}, "Only SIM2": {"ru": "Только SIM2", "ko": "SIM2 전용", "ja": "SIM2のみ", "zh": "仅 SIM2", "hi": "केवल SIM2", "ar": "SIM2 فقط"}, "Both SIMs": {"ru": "Обе SIM", "ko": "두 SIM 모두", "ja": "両方のSIM", "zh": "双 SIM", "hi": "दोनों सिम", "ar": "كلتا الشريحتين"}, " · data: SIM%1": {"ru": " · данные: SIM%1", "ko": " · 데이터: SIM%1", "ja": " ・データ: SIM%1", "zh": " · 数据：SIM%1", "hi": " · डेटा: SIM%1", "ar": " · البيانات: SIM%1"}, "Close": {"ru": "Закрыть", "ko": "닫기", "ja": "閉じる", "zh": "关闭", "hi": "बंद करें", "ar": "إغلاق"}, "Mode (one SIM inserted)": {"ru": "Режим (вставлена одна SIM)", "ko": "모드 (SIM 1개 삽입됨)", "ja": "モード（SIMが1枚）", "zh": "模式（插入了一张 SIM）", "hi": "मोड (एक सिम लगा है)", "ar": "الوضع (شريحة واحدة مُدخلة)"}, "Mode": {"ru": "Режим", "ko": "모드", "ja": "モード", "zh": "模式", "hi": "मोड", "ar": "الوضع"}, "Both\nSIMs": {"ru": "Обе\nSIM", "ko": "두 SIM\n모두", "ja": "両方の\nSIM", "zh": "双\nSIM", "hi": "दोनों\nसिम", "ar": "كلتا\nالشريحتين"}, "Only\nSIM1": {"ru": "Только\nSIM1", "ko": "SIM1\n전용", "ja": "SIM1\nのみ", "zh": "仅\nSIM1", "hi": "केवल\nSIM1", "ar": "SIM1\nفقط"}, "Only\nSIM2": {"ru": "Только\nSIM2", "ko": "SIM2\n전용", "ja": "SIM2\nのみ", "zh": "仅\nSIM2", "hi": "केवल\nSIM2", "ar": "SIM2\nفقط"}, "Mobile data": {"ru": "Мобильные данные", "ko": "모바일 데이터", "ja": "モバイルデータ", "zh": "移动数据", "hi": "मोबाइल डेटा", "ar": "بيانات الجوال"}, "Mobile data (choose with both SIMs)": {"ru": "Мобильные данные (выбор при двух SIM)", "ko": "모바일 데이터 (두 SIM 사용 시 선택)", "ja": "モバイルデータ（SIM2枚のときに選択）", "zh": "移动数据（双 SIM 时可选）", "hi": "मोबाइल डेटा (दोनों सिम होने पर चुनें)", "ar": "بيانات الجوال (اختر عند وجود شريحتين)"}, "Data: SIM1": {"ru": "Данные: SIM1", "ko": "데이터: SIM1", "ja": "データ: SIM1", "zh": "数据：SIM1", "hi": "डेटा: SIM1", "ar": "البيانات: SIM1"}, "Data: SIM2": {"ru": "Данные: SIM2", "ko": "데이터: SIM2", "ja": "データ: SIM2", "zh": "数据：SIM2", "hi": "डेटा: SIM2", "ar": "البيانات: SIM2"}, "SIM cards power": {"ru": "Питание SIM-карт", "ko": "SIM 카드 전원", "ja": "SIMカードの電源", "zh": "SIM 卡电源", "hi": "सिम कार्ड पावर", "ar": "طاقة بطاقات SIM"}, "Turn SIM cards ON": {"ru": "Включить SIM-карты", "ko": "SIM 카드 켜기", "ja": "SIMカードをオンにする", "zh": "开启 SIM 卡", "hi": "सिम कार्ड चालू करें", "ar": "تشغيل بطاقات SIM"}, "Turn SIM cards OFF (flight mode)": {"ru": "Выключить SIM-карты (режим полёта)", "ko": "SIM 카드 끄기 (비행기 모드)", "ja": "SIMカードをオフにする（機内モード）", "zh": "关闭 SIM 卡（飞行模式）", "hi": "सिम कार्ड बंद करें (फ़्लाइट मोड)", "ar": "إيقاف بطاقات SIM (وضع الطيران)"}, "Switching…": {"ru": "Переключение…", "ko": "전환 중…", "ja": "切り替え中…", "zh": "正在切换…", "hi": "बदल रहा है…", "ar": "جارٍ التبديل…"}}
	function t(s) { var d = texts[s]; return (d && d[lang] !== undefined) ? d[lang] : s }
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
		message = t("Switching…")
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
				text: win.flight ? win.t("SIM cards are OFF (flight mode)")
					: win.oneSim ? win.t("Only SIM%1 is inserted").arg(win.cards)
					: (win.mode === "sim1" ? win.t("Only SIM1") : win.mode === "sim2" ? win.t("Only SIM2") : win.t("Both SIMs"))
					  + win.t(" · data: SIM%1").arg(win.effData)
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
				text: win.t("Close")
				enabled: true
				onClicked: Qt.quit()
			}
		}

		// the three rows of buttons (and Close in portrait)
		ColumnLayout {
			Layout.fillWidth: true
			Layout.preferredWidth: win.landscape ? win.u * 30 : -1
			spacing: win.u * 0.6

			Caption { text: win.oneSim ? win.t("Mode (one SIM inserted)") : win.t("Mode"); Layout.topMargin: win.landscape ? 0 : win.u * 0.8 }
			RowLayout {
				spacing: win.u * 0.5
				Big { text: win.t("Both\nSIMs"); current: win.effMode === "dsds"; enabled: !win.busy && !win.oneSim; onClicked: win.choose("dsds") }
				Big { text: win.t("Only\nSIM1"); current: win.effMode === "sim1"; enabled: !win.busy && !win.oneSim; onClicked: win.choose("sim1") }
				Big { text: win.t("Only\nSIM2"); current: win.effMode === "sim2"; enabled: !win.busy && !win.oneSim; onClicked: win.choose("sim2") }
			}

			Caption { text: win.mode === "dsds" && !win.oneSim ? win.t("Mobile data") : win.t("Mobile data (choose with both SIMs)") }
			RowLayout {
				spacing: win.u * 0.5
				Big {
					text: win.t("Data: SIM1"); enabled: !win.busy && !win.oneSim && win.mode === "dsds"
					current: win.effData === "1"
					onClicked: win.choose("data1")
				}
				Big {
					text: win.t("Data: SIM2"); enabled: !win.busy && !win.oneSim && win.mode === "dsds"
					current: win.effData === "2"
					onClicked: win.choose("data2")
				}
			}

			Caption { text: win.t("SIM cards power") }
			Big {
				text: win.flight ? win.t("Turn SIM cards ON") : win.t("Turn SIM cards OFF (flight mode)")
				current: win.flight
				onClicked: win.choose("flight")
			}

			Big {
				visible: !win.landscape
				Layout.topMargin: win.u * 1.2
				Layout.preferredHeight: win.u * 2.6
				text: win.t("Close")
				enabled: true
				onClicked: Qt.quit()
			}
		}
	}
	}
}
