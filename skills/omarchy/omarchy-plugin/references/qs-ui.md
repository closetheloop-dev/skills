# qs.Ui + qs.Commons reference

The omarchy shell ships a component kit. Import with `import qs.Ui` and
`import qs.Commons`. These modules resolve because the plugin runs inside the
shell process. The authoritative source is `/usr/share/omarchy/shell/Ui/*.qml`
and `Commons/*.qml` on the machine — read a component's file if you need a detail
not listed here.

## qs.Commons singletons

- `Color` — theme colors: `Color.foreground`, `Color.background`, `Color.accent`,
  `Color.urgent`, `Color.popups.background`, …
- `Style` — spacing/typography: `Style.space(n)` (scaled px), `Style.font.family`,
  `Style.font.title/body/caption/display`, `Style.spacing.*`, `Style.cornerRadius`,
  `Style.bar.iconSlot`, …
- `Util` — helpers (`Util.fileUrl`, `Util.decodeBase64`, `Util.isPlainObject`, …).
- `Border` — border specs used by inputs.

## Bar-widget building blocks

A bar widget is two files: a **`BarWidget`** entry point that loads a **`Panel`**.

**`BarWidget`** (root of the bar entry point, `entryPoints.barWidget`):
```
property QtObject bar          // injected host bar handle
property string moduleName      // = the manifest id
property var settings           // host-managed inline settings (shell.json)
function setting(name, fallback) // read a host-managed setting
// forward to the loaded Panel: opened, popoutSwitchClosing, and
// open()/close()/toggle()/closeForPopoutSwitch(); inject bar/settings/
// anchorItem/hostWidget into panelLoader.item.
```
Set `implicitWidth/implicitHeight` on the `BarWidget` root (from the bar button) —
the bar sizes the slot from it; without it the icon never draws. It hosts the
panel with a `Loader { source: Qt.resolvedUrl("Panel.qml") }`.

**`Panel`** (root of the loaded panel; `manageIpc: false`, same `moduleName`):
```
property QtObject bar           // injected by the bar widget
property string moduleName
property string ipcTarget        // registers open/close/show/hide/toggle IPC
property var anchorItem / hostWidget   // injected by the bar widget
readonly property bool opened
readonly property var controller       // controller.show() / controller.hide()
function open() / close() / setting(name, fallback)
```

**`BarIconButton`** (root `WidgetButton`): the bar glyph/icon.
```
property Component iconComponent   // set to an Image {} for a bundled SVG icon
property real slotSize / opticalSize
// inherited from WidgetButton: text (a font glyph), bar, onPressed(buttonCode), …
```
Prefer `iconComponent` with `Image { anchors.fill: parent; source: … }` over a
font glyph — the bar (Nerd) font's coverage is uneven.

**`KeyboardPanel`** (the dropdown popup, anchored to the bar; `default property
alias contentItem`):
```
property var owner
property var anchorItem
property bool open
property Item focusTarget
property int contentWidth / contentHeight
function fittedContentWidth(width, cap)
function fittedContentHeight(implicitHeight, cap)   // size the card to content, capped
```
Put a `PanelKeyCatcher { anchors.fill: parent; onCloseRequested: … }` inside,
then your `Column` of controls.

## Input controls

**`Toggle`** (labeled boolean row):
```
property string label / description
property bool checked
signal clicked()          // flip in the handler: checked isn't two-way
```

**`ToggleSwitch`** (bare switch):
```
property bool checked / busy / interactive
signal toggled()
```

**`PanelSlider`** (numeric slider):
```
property QtObject bar
property real value / minimum / maximum / step
property bool integer
property real liveValue
signal moved(real value)      // fires during drag (only on user interaction)
signal released(real value)
```
Bind `value: settings.x`; persist in `onMoved`/`onReleased`.

**`ButtonGroup`** (segmented control / enum):
```
property var options          // [{label, value}] or [string]
property string value
signal changed(string value)
```

**`TextField`** (single-line input; inherits QtQuick.Controls TextField):
```
// text, placeholderText, accepted, editingFinished, validator … all available
```
Persist in `onEditingFinished` (fires on Enter / focus-out), not every keystroke.

**`Button`**:
```
property string text / iconText / tooltipText
property bool bordered / selected / active
signal clicked() / rightClicked()
```

## Layout / labels

- `PanelSectionHeader` — a `Text` subclass; `PanelSectionHeader { text: "SECTION" }`.
- `PanelSeparator` — a `Rectangle`; `property real strength: 0.12`.
- `PanelHero`, `PanelActionButton`, `PanelToolTip`, `Dropdown`, `SearchableDropdown`,
  `MultiSelect`, `NumberField`, `ConfirmDialog` — see their files as needed.

## Multi-monitor / layer helpers

- `ScreenMoveRemap { window: <PanelWindow> }` — forces unmap/remap when a monitor
  moves so a layer-shell surface follows its screen. Bind `visible:
  !remap.remapping`.

## Live gallery

`assets/example.hello/` wires Toggle, PanelSlider, ButtonGroup, TextField, Button,
PanelSectionHeader, PanelSeparator and a BarIconButton SVG icon into one working
widget — `BarWidget.qml` (icon + panel host) plus `Panel.qml` (the controls). Copy
it as a starting point.
