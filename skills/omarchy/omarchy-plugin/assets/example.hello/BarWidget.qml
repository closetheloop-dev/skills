import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The bar entry point for the example. It owns the bar icon and hosts the panel:
// the Loader loads Panel.qml, this root forwards the panel lifecycle the bar
// routes through (open/close/toggle/opened/popoutSwitchClosing), and it injects
// bar/settings/anchorItem/hostWidget into the loaded panel. Both files share
// moduleName = the manifest id; the panel is NOT a separate manifest kind.
BarWidget {
  id: root
  moduleName: "example.hello"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  // bar/settings are null during Component.onCompleted, so inject on load, once
  // more via callLater, and again whenever they change.
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  // REQUIRED. The bar sizes each widget slot from the root's implicit size. Omit
  // this and the slot is zero-wide — the icon never draws even though the
  // component loaded and its IPC works.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Prefer a bundled SVG over a font glyph: the bar (Nerd) font's coverage is
    // uneven, so a chosen codepoint can render blank or as the wrong glyph.
    iconComponent: Component {
      Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("assets/icon.svg")
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 48
        sourceSize.height: 48
        smooth: true
      }
    }
    onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle(); }
  }
}
