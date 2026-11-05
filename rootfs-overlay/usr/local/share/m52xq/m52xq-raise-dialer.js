// M52XQ (v47): un-minimise and activate the plasma-dialer window for an incoming call. Loaded by
// /usr/local/bin/m52xq-call-screen-wake through org.kde.kwin.Scripting. A dialer that is already running keeps its window
// minimised when a call comes in (it only switches its page), and a second "plasma-dialer" start does not raise it either.
const ws = workspace.windowList();
for (let i = 0; i < ws.length; i++) {
    const w = ws[i];
    if (String(w.desktopFileName) === "org.kde.plasma.dialer" || String(w.resourceClass) === "org.kde.plasma.dialer") {
        print("m52xq-raise-dialer: minimized=" + w.minimized + " -> raise");
        w.minimized = false;
        workspace.activeWindow = w;
    }
}
