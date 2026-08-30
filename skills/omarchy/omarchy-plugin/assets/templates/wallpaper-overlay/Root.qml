import QtQuick
import Quickshell

// Service root: mount one Layer window per monitor. Variants rebuilds the set as
// monitors are connected/disconnected, so overlays follow the current outputs.
Item {
  id: root

  // Injected by the host (declare what you use).
  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  Variants {
    model: Quickshell.screens
    Layer {}
  }
}
