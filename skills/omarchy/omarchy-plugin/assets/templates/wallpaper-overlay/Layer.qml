import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Ui   // ScreenMoveRemap

// A transparent, click-through window covering ONE monitor on the Wlr "Bottom"
// layer: above the wallpaper, below normal windows. Put your content inside.
PanelWindow {
  id: win
  required property var modelData
  screen: modelData

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  // Keep the committed buffer alive. Parking a background-layer surface with
  // updatesEnabled:false has been observed to black out the desktop — leave true.
  updatesEnabled: true

  WlrLayershell.namespace: "example-overlay"   // change to your own namespace
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Empty input region → fully click-through: pointer events reach the windows
  // and desktop beneath. Remove `mask` (or give it a Region) to receive clicks.
  mask: Region {}

  // Forces an unmap/remap when the monitor moves in the layout, so the surface
  // follows its screen instead of stranding at the old origin.
  ScreenMoveRemap { id: remapGuard; window: win }
  visible: !remapGuard.remapping

  // ---- your content here ----
  Rectangle {
    anchors.centerIn: parent
    width: 220; height: 84; radius: 12
    color: "#337aa2f7"
    Text { anchors.centerIn: parent; text: "overlay"; color: "white" }
  }
}
