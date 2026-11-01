// prints the process id and the application of the active window (read back from the journal by m52xq-camera-grab)
var w = workspace.activeWindow;
print("M52XQ_ACTIVE " + (w ? w.pid : 0) + " " + (w ? w.resourceClass : "none"));
