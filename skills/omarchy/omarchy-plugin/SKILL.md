---
name: omarchy-plugin
description: Create, scaffold, validate, install, and debug Omarchy shell plugins built with Quickshell/QML, including bar widgets, panels, services, menus, overlays, manifests, qs.Ui controls, settings, host injection, IPC, and reload workflows. Use when the user mentions Omarchy plugins, omarchy-shell, Quickshell plugins, bar widgets or icons, or ~/.config/omarchy/plugins.
---

# Building Omarchy shell plugins

Omarchy's desktop shell is a single long-running **Quickshell** (Qt/QML) process,
`omarchy-shell`. The bar, panels, menus, overlays, background — everything — runs
inside it as a **plugin**. This skill shows how to build one.

Bundled with this skill:
- `assets/example.hello/` — a complete **bar-widget** reference: the two-file
  `BarWidget.qml` + `Panel.qml` contract with an icon, a panel of live controls,
  and a settings bridge. Read it and borrow fragments; scaffold new plugins with
  `scripts/new-plugin.sh` rather than copying it wholesale (it carries the
  `example.hello` identity).
- `assets/templates/` — a headless **service** and a **wallpaper-overlay** template.
- `references/` — deep dives loaded on demand: `manifest.md`, `qs-ui.md`,
  `host-injection.md`, `ipc-and-cli.md`, `dev-reload.md`.
- `scripts/new-plugin.sh` — scaffold a fresh plugin (`BarWidget.qml` + `Panel.qml`,
  manifest, icon, README, LICENSE); takes `<id>` and `--name "<Display Name>"`.

**Ground truth is the target machine.** The APIs here are pinned to one omarchy
version. On the machine you're building for, treat `/usr/share/omarchy/shell/` as
authoritative — its `README.md`, `plugins/README.md`, `Ui/*.qml`,
`Commons/*.qml`, and `services/PluginRegistry.qml`. Read the actual component file
when a detail matters.

## What a plugin is

A plugin is a **git repo with `manifest.json` at its root**, installed as a real
directory at `~/.config/omarchy/plugins/<id>/`. The manifest declares one or more
**kinds**, each pointing at a QML entry-point file:

| Kind | Mounts as |
|------|-----------|
| `bar-widget` | A component the active bar drops into a section. |
| `service` | A headless singleton, no UI. |
| `panel` | A persistent or summoned floating window (e.g. OSD). |
| `overlay` | A fullscreen overlay. |
| `menu` | A summoned menu surface. |
| `bar` | A full bar replacing the built-in one (only one active). |

A plugin may combine kinds (e.g. `["service","bar-widget"]`). See
`references/manifest.md` for the full schema and validation rules.

## Quickstart (a bar widget in 5 steps)

**Before scaffolding, ask the user for the naming inputs — don't invent them.**
They are distinct, so ask for each separately:
- the permanent **namespaced id** (e.g. `io.github.you.custom-clock`; the
  `omarchy.*` namespace is reserved) — the machine identity: install dir, registry
  key, `moduleName`, and IPC target;
- the **human-facing name** (e.g. `Custom Clock`) — manifest `name` and
  `barWidget.displayName`;
- for anything publishable, the **author** and **license**.

Then pass them explicitly rather than letting the script guess:
`scripts/new-plugin.sh <id> --name "<Name>" --author "<Author>" --license MIT`.
(Run interactively on a terminal, the script prompts for any it's missing; run
noninteractively it requires at least `--name` and warns on a placeholder author.)

1. **Scaffold.** Run the command above — `new-plugin.sh` is the scaffold path; it
   writes `manifest.json`, `BarWidget.qml`, `Panel.qml`, `assets/icon.svg`,
   `README.md`, and `LICENSE`. Edit the two QML files. (To start from working code
   instead, `omarchy plugin clone <builtin.id> --edit` reassigns the id for you.
   `assets/example.hello/` is a **reference** to read and borrow fragments from —
   don't copy it wholesale, or the new plugin inherits the example's
   `id`/`moduleName`/IPC/state identity across `manifest.json`, both QML files, and
   `Settings.qml`.)
2. **Install** as a real directory:
   `cp -r <your-plugin> ~/.config/omarchy/plugins/<id>` (or start from a built-in
   with `omarchy plugin clone <builtin.id> --edit`).
3. **Register:** `OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell rescanPlugins`.
4. **Enable:** `omarchy plugin enable <id>` (bar widgets land in
   `barWidget.defaultSection`, else center).
5. **See it.** The icon appears in the bar; click it to open the panel. Iterate
   in place — saved changes auto-reload (see `references/dev-reload.md`).

Validate before and after installing (see **Verify** below):
`omarchy plugin validate <folder>` plus
`qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml`.

## The manifest

Required: `id, name, version, kinds, entryPoints` plus `schemaVersion: 1`; include
`author` and `license` for anything you share. Three distinct names:
- **`id`** — the permanent **machine identity**: install dir, registry key, and the
  `moduleName`/IPC target in the QML. Reverse-DNS namespaced
  (`io.github.you.custom-clock`); no `/`, no `..`; the `omarchy.*` namespace is
  reserved for built-ins.
- **`name`** — the human-facing plugin name (`"Custom Clock"`).
- **`barWidget.displayName`** — the label shown for the bar widget itself.

Map each kind to its entry file — a `bar-widget` loads `BarWidget.qml`:

```json
{
  "schemaVersion": 1,
  "id": "io.github.you.custom-clock", "name": "Custom Clock", "version": "0.1.0",
  "author": "Your name", "license": "MIT", "description": "…",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": { "displayName": "Custom Clock", "category": "Time", "defaultSection": "center", "allowMultiple": false }
}
```

Full field list, `barWidget.schema` settings types, and validation rules:
`references/manifest.md`.

## Building a bar widget

A bar widget is **two QML files**. `BarWidget.qml` is the entry point the manifest
loads (`entryPoints.barWidget`): it owns the bar icon and, through a `Loader`,
hosts `Panel.qml`. The bar drives the widget through its root, so `BarWidget.qml`
**forwards the panel lifecycle** — `opened`, `popoutSwitchClosing`, `open()`,
`close()`, `toggle()`, `closeForPopoutSwitch()` — down to the loaded panel, and
**injects** `bar`, `settings`, `anchorItem`, and `hostWidget` into it. Keep one
`moduleName` (= the manifest `id`) in both files, and do **not** declare the
nested panel as a second manifest kind.

`BarWidget.qml` — the bar entry point:

```qml
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "acme.hello"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open()   { if (panelLoader.item) panelLoader.item.open() }
  function close()  { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {                 // bar/settings are null in onCompleted
    var t = panelLoader.item; if (!t) return
    if ("bar" in t) t.bar = root.bar
    if ("settings" in t) t.settings = root.settings
    if ("anchorItem" in t) t.anchorItem = button
    if ("hostWidget" in t) t.hostWidget = root
  }

  // REQUIRED — the bar sizes the slot from the root's implicit size.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader; active: true; visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  BarIconButton {                          // a WidgetButton; bundled SVG beats a glyph
    id: button; anchors.fill: parent; bar: root.bar
    iconComponent: Component { Image { anchors.fill: parent; source: Qt.resolvedUrl("assets/icon.svg"); fillMode: Image.PreserveAspectFit; sourceSize.width: 48; sourceSize.height: 48 } }
    onPressed: function(b) { if (b === Qt.LeftButton) root.toggle() }
  }
}
```

`Panel.qml` — loaded by the bar widget; owns the panel UI, not IPC:

```qml
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "acme.hello"
  ipcTarget: "acme.hello"
  manageIpc: false                         // the bar widget owns IPC

  property var anchorItem: null            // injected by BarWidget.injectPanel()
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function open()  { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {        // Tab between adjacent bar panels
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    anchorItem: root.anchorItem; owner: root.barIdentity; bar: root.bar; open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(300))
    contentHeight: fittedContentHeight(column.implicitHeight, Style.space(760))
    PanelKeyCatcher {
      id: keyCatcher; anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      Column { id: column; width: parent.width; padding: Style.space(16); spacing: Style.space(12)
        // controls…
      }
    }
  }
}
```

The complete, working version — with `Toggle`, `PanelSlider`, `ButtonGroup`,
`TextField`, `Button`, `PanelSectionHeader`, `PanelSeparator`, and a persisted
settings bridge — is `assets/example.hello/` (`BarWidget.qml` + `Panel.qml`). The
control APIs are in `references/qs-ui.md`.

**Must-knows** (details in `references/dev-reload.md`):
- Set `implicitWidth/Height` on the `BarWidget` root or the slot is zero-wide.
- Keep one `moduleName` (= manifest `id`) across both files; the panel is
  `manageIpc: false` and is never a separate kind.
- Use a bundled SVG icon — the bar font's glyph coverage is uneven.

## Settings & persistence

Two options:

1. **Host-managed** — declare a `barWidget.schema` in the manifest; users edit it
   in Setup > Plugins; read values with `root.setting(key, fallback)`. Best for
   static config.
2. **Self-managed bridge** — a small `Settings.qml` that reads/writes a
   `settings.json` under `~/.local/state/<id>/` with `FileView { watchChanges }`.
   Best for **interactive in-panel controls**: the panel writes on change (set a
   property + `save()`), and any component watching the same file (e.g. a
   companion service) reloads instantly. Copy `assets/example.hello/Settings.qml`.

## Other kinds

- **Service** (headless singleton): a plain `Item` that declares only the
  host-injected props it uses. Template: `assets/templates/service/`.
- **Wallpaper overlay**: a `service` whose root uses `Variants { model:
  Quickshell.screens }` to mount one per-monitor `PanelWindow` on
  `WlrLayer.Bottom`, `color: "transparent"`, `mask: Region {}` for click-through,
  guarded by `ScreenMoveRemap`. Keep `updatesEnabled: true`. Template:
  `assets/templates/wallpaper-overlay/`.
- **panel / overlay / menu**: floating surfaces loaded when **summoned** via IPC
  (`omarchy-shell shell summon <id> '<json>'`, `toggle`, `hide`); add
  `keepLoaded: true` to persist past one summon.

## Reading data / running commands

Use `Quickshell.Io`:
- `Process { command: [...]; stdout: StdioCollector { onStreamFinished: … } }` to
  run a command.
- `FileView { path; watchChanges: true; onLoaded: parse(text()) }` to read/watch a
  file.
- To watch a *set* of files, discover them with a `Process` (`find …`), then
  drive an `Instantiator` of `FileView` over the list. Keep a per-file cursor if
  you only care about deltas. (This is how the agents plugin reads usage records.)

## Host injection

The shell sets `shell`, `omarchyPath`, `manifest`, `pluginRegistry`,
`barWidgetRegistry` on your instance **only if you declare them** — and only
*after* construction (they're null in `Component.onCompleted`). Panels also
receive `service` (their same-id service singleton). The `Panel` base already
provides `bar`/`settings`/`setting()`. Details: `references/host-injection.md`.

## Install, enable, place

- `omarchy plugin add <git-url>` clones a repo into
  `~/.config/omarchy/plugins/<id>/` (it lands **disabled** — plugins run
  unsandboxed, so review first), then `omarchy plugin enable <id>`.
- Hand install: put the folder there, `rescanPlugins`, `enable`.
- Bar placement: `barWidget.defaultSection`, `omarchy bar move`, or
  `omarchy-shell shell enablePlugin <id> '{}'`.

CLI + IPC surface and `shell.json` layout: `references/ipc-and-cli.md`.

## Develop & reload

Plugins share the **one** long-running `omarchy-shell` process — never start a
second Quickshell process for a plugin. Iterate in the installed/cloned directory:

- Start from a built-in with `omarchy plugin clone <builtin.id> --edit`, or work
  directly in `~/.config/omarchy/plugins/<id>/`.
- Saving a file there **auto-reloads** the plugin; `omarchy-shell shell rescanPlugins`
  forces a re-walk; `omarchy-restart-shell` restarts the shell cleanly.
- Plugin QML runs **unsandboxed** with your user's permissions — review third-party
  code before enabling.
- Don't mistake omarchy's **startup splash** (on restart) or **screensaver** (on
  idle) for your plugin.

Full workflow, the gotchas checklist, and troubleshooting: `references/dev-reload.md`.

## Verify

Static checks (both must exit clean — don't declare success while either fails):
1. `omarchy plugin validate "$PLUGIN_DIR"` passes.
2. `qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR"/BarWidget.qml "$PLUGIN_DIR"/Panel.qml`
   passes.

Lifecycle (install → `rescanPlugins` → `enable`, then exercise each):
3. **Discovered & enabled:** `omarchy plugin list --json | jq '.[] | select(.id=="<id>")'`
   shows `"enabled": true`.
4. **Click** the bar icon opens the panel; **Escape** closes it.
5. **Summon/hide:** `omarchy-shell shell summon <id> '{}'` opens it,
   `omarchy-shell shell hide <id>` closes it.
6. **Disable → re-enable**, **restart the shell**, and **remove**
   (`omarchy plugin remove <id>`) all behave; settings persist across a restart.
