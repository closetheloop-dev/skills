import QtQuick
import Quickshell
import Quickshell.Io

// A small, self-managed settings store that PERSISTS to JSON and applies changes
// LIVE across components. The panel writes (set a property + call save()); any
// other component watching this same file (e.g. a companion service) reloads
// instantly. Use this when you have interactive in-panel controls. For static
// config a manifest `barWidget.schema` (host-managed, read via Panel.setting())
// is simpler — see the guide.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME") || ""
  // Store under XDG state. Change "example.hello" to your plugin id.
  readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/example.hello"
  readonly property string path: dir + "/settings.json"

  // Your settings + their defaults (defaults double as the reset() values).
  property bool enabled: true
  property real level: 0.5
  property string mode: "medium"
  property string label: ""

  signal changed()

  Process { id: mkdir; command: ["mkdir", "-p", root.dir] }
  Component.onCompleted: mkdir.running = true

  FileView {
    id: file
    path: root.path
    watchChanges: true          // reload when the file changes on disk
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: root.changed() // no file yet → keep the defaults above
  }

  function apply(content) {
    try {
      var d = JSON.parse(String(content || ""));
      if (d && typeof d === "object") {
        if (d.enabled !== undefined) enabled = !!d.enabled;
        if (d.level   !== undefined) level = Number(d.level);
        if (d.mode    !== undefined) mode = String(d.mode);
        if (d.label   !== undefined) label = String(d.label);
      }
    } catch (e) { /* keep current values on malformed JSON */ }
    changed();
  }

  function save() {
    file.setText(JSON.stringify(
      { enabled: enabled, level: level, mode: mode, label: label }, null, 2) + "\n");
  }

  function reset() {
    enabled = true; level = 0.5; mode = "medium"; label = "";
    save();
  }
}
