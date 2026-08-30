# Dev, reload & gotchas

## Iterate in the shell (there is only one)

`omarchy-shell` hosts every plugin in **one** long-running process. Never start a
second Quickshell process for a plugin — and `qs.Ui`/`qs.Commons` only resolve
inside the shell's config root anyway. Develop in the user-owned plugin directory
and let the shell hot-reload it:

- Clone a built-in as a working copy: `omarchy plugin clone <builtin.id> --edit`
  prints the new id, creates the folder, and opens it in your editor.
- Or work directly in a **real** folder at `~/.config/omarchy/plugins/<id>/` (not
  a symlink — see below; and never the packaged Omarchy source).

## Reloading the installed plugin

The shell watches `~/.config/omarchy/plugins/` with a recursive `inotify` watcher
(`inotifywait -m -r`) and, on any change under it, calls `reloadPlugins()`: it
unloads **every** panel/service/widget, clears the QML component cache, and
re-walks. Practical consequences:

- **Use a real directory with no symlinks inside it.** A recursive `inotify` watch
  doesn't follow symlinks, so a symlinked `~/.config/omarchy/plugins/<id>` (or any
  symlinked file within it) never reloads — and `omarchy plugin validate` rejects
  any symlink anywhere in the tree. Develop in the real folder, or copy from a
  symlink-free dev tree with a **dereferencing** copy (`cp -aL` or
  `rsync -a --copy-links`), then run `omarchy plugin validate`.
- **A save reloads all plugins, not just yours** — it's a full teardown + re-walk.
  `omarchy-shell shell rescanPlugins` forces the same full reload. Only
  enable/disable/move (`omarchy plugin enable|disable`, `omarchy bar move`) act on
  a single plugin.
- `omarchy-restart-shell` stops all shell instances and launches one fresh (a
  clean engine). Use it after big changes or if a reload seems half-applied.

## Install as a real directory

An installed plugin is a plain git checkout at `~/.config/omarchy/plugins/<id>/`.
Develop there directly, or `git clone`/`omarchy plugin add` into it. Then:
`omarchy-shell shell rescanPlugins` → `omarchy plugin enable <id>`.

## Verify (static + lifecycle)

Run the static checks first; both must exit clean, and a path you present as
verified must not swallow a validator, lint, rescan, or enable failure.

```bash
PLUGIN_ID="io.github.you.custom-clock"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

Then walk the lifecycle:

- **Discovered & enabled:** `omarchy plugin list --json | jq --arg id "$PLUGIN_ID" '.[] | select(.id==$id)'` shows `"enabled": true`.
- **Click** the bar icon opens the panel; **Escape** closes it.
- **Summon/hide:** `omarchy-shell shell summon "$PLUGIN_ID" '{}'` opens it;
  `omarchy-shell shell hide "$PLUGIN_ID"` closes it.
- **Disable → re-enable**, **restart the shell**, and **remove**
  (`omarchy plugin remove "$PLUGIN_ID"`) all behave; settings persist across a
  restart.
- On QML errors, inspect the shell log: `qs log -p "$OMARCHY_PATH/shell" --tail 100`.

## The gotchas (general)

- **Bar-widget slot sizing (#1):** the bar sizes each widget slot from your
  `BarWidget` root's `implicitWidth`/`implicitHeight`. Omit them and the slot is
  zero-wide — the icon never draws even though the component loaded and its IPC
  works. Set `implicitWidth: button.implicitWidth; implicitHeight: button.implicitHeight`.
  (Mirrors `plugins/menu/BarWidget.qml`.)
- **Bar-font glyph coverage:** the bar's Nerd font doesn't have every icon; a
  chosen codepoint may render blank or as the wrong glyph. Prefer a bundled SVG
  via `BarIconButton.iconComponent` with an `Image { anchors.fill: parent }`.
- **Wallpaper/background layer blackout:** on a Wlr `Bottom`-layer `PanelWindow`,
  keep `updatesEnabled: true`. Parking a background-layer surface with
  `updatesEnabled: false` has been observed to black out the desktop.
- **Panel content overflow:** size `KeyboardPanel.contentHeight` from your
  column's `implicitHeight` (capped) via `fittedContentHeight(...)`, or tall
  panels spill past the card border.
- **Plugins are unsandboxed:** your QML runs with full shell privileges. Review
  third-party code before enabling.

## Not-your-plugin animations (so you don't chase them)

- A **startup splash** plays whenever the shell (re)starts — e.g. after
  `omarchy-restart-shell` or login.
- A **screensaver** appears after the idle timeout (`idle.screensaver` /
  `idle.lock` in `shell.json`). Neither is your plugin; interact with the desktop
  to dismiss the screensaver before screenshotting.

## Troubleshooting (possibly environment-specific)

These helped in one setup but may not be needed generally — reach for them only
if a change genuinely won't take:

- If edited code doesn't seem to reload, run a full `omarchy-restart-shell`.
- Quickshell keeps a compiled QML cache at `~/.cache/quickshell/qmlcache/`. If a
  restart still serves stale code, `rm -rf ~/.cache/quickshell/qmlcache/*` and
  restart again.
