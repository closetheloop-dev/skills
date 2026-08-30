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

A plugin is a **directory with `manifest.json` at its root**, installed at
`~/.config/omarchy/plugins/<id>/` — a plain folder while you develop, and a git
repo when you share it (see **Publish**). The manifest declares one or more
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

## Quickstart (a bar widget)

Two ways to start, both landing a real directory under
`~/.config/omarchy/plugins/`. **Cloning a built-in is the easy path** the Omarchy
guide recommends for a first widget; scaffold blank for a clean slate.

### A. Clone a built-in (recommended starting point)

`omarchy plugin clone <builtin.id> --edit` (e.g. `omarchy.clock`) copies it into the
plugins dir, **generates a temporary development id**, records
`"omarchy": { "clonedFrom": "<builtin.id>" }` in the manifest, and opens it in your
editor. **Keep that generated id and the `clonedFrom` field while developing** —
together they route summon/hide to your copy and let disabling/removing it restore
the built-in. Edit `BarWidget.qml` + `Panel.qml`. You only take a permanent id and
drop `clonedFrom` when you **Publish** (below).

### B. Scaffold a blank widget

**Ask the user for the naming inputs — don't invent them.** Ask separately for:
- the permanent **namespaced id** (e.g. `io.github.yourname.custom-clock`; the
  `omarchy.*` namespace is reserved) — the machine identity: install dir, registry
  key, `moduleName`, and IPC target;
- the **human-facing name** (e.g. `Custom Clock`) — manifest `name` and
  `barWidget.displayName`;
- for anything publishable, the **author** and **license**.

Then run — it scaffolds **directly into** `~/.config/omarchy/plugins/<id>/` (there
is no separate copy step, and it errors if that id already exists):

```
scripts/new-plugin.sh <id> --name "<Name>" --author "<Author>" --license MIT
```

writing `manifest.json`, `BarWidget.qml`, `Panel.qml`, `assets/icon.svg`,
`README.md`, and `LICENSE`, then edit the two QML files. (On a terminal it prompts
for anything missing; noninteractively it requires `--name`.) `assets/example.hello/`
is a **reference** to read and borrow fragments from — don't copy it wholesale, or
the new plugin inherits the example's `id`/`moduleName`/IPC/state identity.

### Then, for either path

With `PLUGIN_DIR="$HOME/.config/omarchy/plugins/<id>"`:

1. **Validate first — static checks before the code loads** (see **Verify**). Both
   must pass:
   `omarchy plugin validate "$PLUGIN_DIR"` and
   `qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR"/BarWidget.qml "$PLUGIN_DIR"/Panel.qml`.
   (A clone is already live in the running shell, so run these before you rely on or
   publish it.)
2. **Register:** `OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell rescanPlugins`.
3. **Enable:** `omarchy plugin enable <id>` (bar widgets land in
   `barWidget.defaultSection`, else center).
4. **See it & iterate.** The icon appears in the bar; click it to open the panel.
   Edit in place under `$PLUGIN_DIR` — a real folder with **no symlinks inside it** —
   and saving reloads (the whole plugin set; see `references/dev-reload.md`). Re-run
   the static checks after edits; the full lifecycle checklist is in **Verify**.

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

### Publish

A local scaffold or clone is a plain directory that runs as-is — git is not needed
to develop or hand-install. **Publish from a separate staged copy**, not by mutating
the live clone in place: its directory name, its `shell.json` enabled-state entry,
and (for a clone) the `omarchy.clonedFrom` restore path are all bound to the
temporary id, so an in-place id change leaves a directory/manifest mismatch and
stale shell state.

1. Stage a fresh, **symlink-free** copy with a dereferencing copy:
   `cp -aL "$PLUGIN_DIR" <repo>` (or `rsync -a --copy-links`).
2. Pick a permanent **namespaced id** (`io.github.yourname.<plugin>`) and replace the
   old id **everywhere it carries identity** — not just `manifest.json` `id` and the
   two QML `moduleName`/`ipcTarget`. `grep -rn '<old-id>' <repo>` and update every
   hit, including any `Settings.qml`/`Model.js` state-directory path and asset
   references, then name the repo dir for the new id. In the staged copy, **remove**
   the clone-only `omarchy.clonedFrom` field.
3. Fill real `author`/`license`, add `README.md` + `LICENSE`, and confirm **no
   symlinks anywhere** (`omarchy plugin validate` rejects them). Test a clean install
   under the permanent id (copy into the plugins dir → `rescanPlugins` → `enable`)
   and run the static + lifecycle checks in **Verify**.
4. `git init && git add -A && git commit`, push; others install with
   `omarchy plugin add <git-url> --enable`.
5. Leave the development clone in place, or remove it with
   `omarchy plugin remove <temp-id>` — while `clonedFrom` is intact, removing the
   clone restores the built-in.

CLI + IPC surface and `shell.json` layout: `references/ipc-and-cli.md`.

## Develop & reload

Plugins share the **one** long-running `omarchy-shell` process — never start a
second Quickshell process for a plugin. Iterate in the installed/cloned directory:

- Start from a built-in with `omarchy plugin clone <builtin.id> --edit`, or work
  directly in a **real** folder at `~/.config/omarchy/plugins/<id>/`.
- **No symlinks.** The installed dir must be a real folder with **no symlinks
  anywhere inside it**: the reload watcher (recursive `inotify`) doesn't follow
  symlinks so a symlinked plugin never reloads, and `omarchy plugin validate`
  rejects any symlink in the tree. Develop in the real folder, or copy from a
  symlink-free dev tree with a **dereferencing** copy (`cp -aL`, or
  `rsync -a --copy-links`) and run `omarchy plugin validate` after.
- A change under the plugins dir reloads the **whole** plugin set — a full teardown
  and re-walk, not just yours; `omarchy-shell shell rescanPlugins` forces the same
  reload, and `omarchy-restart-shell` restarts the shell cleanly. Only
  enable/disable/move act on a single plugin.
- Plugin QML runs **unsandboxed** with your user's permissions — review third-party
  code before enabling.
- Don't mistake omarchy's **startup splash** (on restart) or **screensaver** (on
  idle) for your plugin.

Full workflow, the gotchas checklist, and troubleshooting: `references/dev-reload.md`.

## Verify

**Static checks** — both must exit clean; don't declare success while either fails:

1. `omarchy plugin validate "$PLUGIN_DIR"` passes.
2. `qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR"/BarWidget.qml "$PLUGIN_DIR"/Panel.qml` passes.

**Lifecycle** — install → `rescanPlugins` → `enable`, then exercise each:

- **Discovered & enabled:** `omarchy plugin list --json | jq '.[] | select(.id=="<id>")'` shows `"enabled": true`.
- **Click** the bar icon opens the panel; **Escape** closes it.
- **Summon/hide:** `omarchy-shell shell summon <id> '{}'` opens it, `omarchy-shell shell hide <id>` closes it.
- **Disable → re-enable**, **restart the shell**, and **remove** (`omarchy plugin remove <id>`) all behave; settings persist across a restart.
