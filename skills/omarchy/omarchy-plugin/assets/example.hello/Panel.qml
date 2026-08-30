import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The panel loaded by BarWidget.qml: a live gallery of the common qs.Ui controls,
// each wired to the Settings bridge so changes persist (and would apply live to
// any component watching the same file). It does NOT own IPC (manageIpc: false) —
// the bar widget does — and it keeps moduleName = the manifest id.
// bar/settings/anchorItem/hostWidget are injected by BarWidget.injectPanel();
// setting(name, fallback) then reads host-managed settings (manifest schema).
Panel {
  id: root
  moduleName: "example.hello"
  ipcTarget: "example.hello"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  // The bar tracks the widget mounted in its slot (BarWidget.qml), not this
  // nested panel, so stand in for it wherever the bar identifies a panel.
  readonly property var barIdentity: hostWidget || root

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Guarded so the panel still renders before the bar is injected.
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.6)
  readonly property string ff: bar ? bar.fontFamily : Style.font.family

  Settings { id: settings }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    // Size the card to the content (capped), so nothing overflows the border.
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        padding: Style.space(16)
        spacing: Style.space(12)

        // A HOST-managed setting (declared in manifest barWidget.schema), read
        // with setting(name, fallback). Users edit it in Setup > Plugins.
        Text {
          text: "Hello, " + root.setting("name", "world")
          color: root.fg
          font.family: root.ff
          font.pixelSize: Style.font.title
          font.bold: true
        }

        PanelSectionHeader { text: "CONTROLS" }

        // Toggle (boolean).
        Toggle {
          width: parent.width - Style.space(32)
          label: "Enabled"
          description: "A boolean, persisted to settings.json."
          checked: settings.enabled
          onClicked: { settings.enabled = !settings.enabled; settings.save(); }
        }

        // Slider (number). onMoved fires during the drag — persist there so a
        // watching component applies it live.
        Column {
          width: parent.width - Style.space(32)
          spacing: Style.space(6)
          Text { text: "Level · " + settings.level.toFixed(2); color: root.dim; font.family: root.ff; font.pixelSize: Style.font.caption }
          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0; maximum: 1; step: 0.05
            value: settings.level
            onMoved: function(v) { settings.level = v; settings.save(); }
          }
        }

        // Segmented control (enum). options: [{label, value}]; changed(value).
        Column {
          width: parent.width - Style.space(32)
          spacing: Style.space(6)
          Text { text: "Mode"; color: root.dim; font.family: root.ff; font.pixelSize: Style.font.caption }
          ButtonGroup {
            width: parent.width
            options: [ { label: "Low", value: "low" }, { label: "Medium", value: "medium" }, { label: "High", value: "high" } ]
            value: settings.mode
            onChanged: function(v) { settings.mode = v; settings.save(); }
          }
        }

        // Text input (string). editingFinished fires on Enter / focus-out.
        Column {
          width: parent.width - Style.space(32)
          spacing: Style.space(6)
          Text { text: "Label"; color: root.dim; font.family: root.ff; font.pixelSize: Style.font.caption }
          TextField {
            width: parent.width
            text: settings.label
            placeholderText: "Type something…"
            onEditingFinished: { settings.label = text; settings.save(); }
          }
        }

        PanelSeparator { width: parent.width - Style.space(32) }

        Button {
          text: "Reset to defaults"
          bordered: true
          onClicked: settings.reset()
        }
      }
    }
  }
}
