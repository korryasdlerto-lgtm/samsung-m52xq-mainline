// M52XQ (v47): show the Telegram Desktop call window for an incoming call. Loaded by /usr/local/bin/m52xq-call-screen-wake
// (org.kde.kwin.Scripting) when a Telegram sound plays longer than 2 s (= the ringtone). KWin refuses Telegram's own activation
// request while the screen is locked ("Cannot grant a token"), so after unlocking the call window was not visible.
// The call window is named after the caller; the main window is "Telegram" -> prefer the window that is not the main one.
const ws = workspace.windowList();
let tg = [];
for (let i = 0; i < ws.length; i++) {
    const w = ws[i];
    const id = (String(w.resourceClass) + " " + String(w.desktopFileName)).toLowerCase();
    if (w.normalWindow && id.indexOf("telegram") >= 0)
        tg.push(w);
}
let pick = null;
for (let i = 0; i < tg.length; i++) {
    tg[i].minimized = false;
    if (!pick || String(tg[i].caption) !== "Telegram")
        pick = tg[i];
}
if (pick) {
    workspace.activeWindow = pick;
    print("m52xq-raise-telegram: " + tg.length + " window(s), raised \"" + pick.caption + "\"");
} else {
    print("m52xq-raise-telegram: no Telegram window");
}
