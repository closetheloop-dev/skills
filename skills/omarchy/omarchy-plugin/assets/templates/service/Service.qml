import QtQuick
import Quickshell
import Quickshell.Io

// A headless singleton (no UI). The host creates ONE instance when the plugin
// loads and injects the properties below AFTER construction — so they are still
// null during Component.onCompleted; don't read them at init time. Declare only
// the injected properties you actually use.
Item {
  id: root

  // Injected by omarchy-shell if declared (see references/host-injection.md):
  property var shell: null            // the shell host: IPC / summon / config
  property string omarchyPath: ""     // path to the omarchy install
  property var manifest: null         // this plugin's parsed manifest
  property var pluginRegistry: null
  property var barWidgetRegistry: null

  readonly property string home: Quickshell.env("HOME") || ""

  // --- Example: run a command on a timer (Quickshell.Io.Process) ---
  property string lastRun: ""
  Process {
    id: proc
    command: ["sh", "-c", "date +%s"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.lastRun = text.trim() }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim() !== "") console.warn("example.service", text.trim()) }
  }
  Timer {
    interval: 60000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: if (!proc.running) proc.running = true
  }

  // --- Example: watch a file for changes (Quickshell.Io.FileView) ---
  FileView {
    path: root.home + "/.local/state/example.service/state.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { var d = JSON.parse(String(text() || "")); /* use d */ }
      catch (e) { /* ignore malformed */ }
    }
    onLoadFailed: {}
  }
}
