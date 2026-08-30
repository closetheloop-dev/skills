# CLI + IPC reference

## `omarchy plugin` CLI

```
omarchy plugin add [git-url] [--enable] [--yes]   Add a plugin from git (clones to
                                                  ~/.config/omarchy/plugins/<id>, lands DISABLED)
omarchy plugin clone <source-id> [--edit]         Clone a built-in plugin into your config as <user>.<name>
omarchy plugin enable <id> [placement]            Enable a plugin (bar widgets → defaultSection / placement)
omarchy plugin disable <id>                        Disable a plugin
omarchy plugin list [--json]                       List discovered plugins
omarchy plugin remove [id] [--yes]                 Remove an installed plugin
omarchy plugin update [id] [--yes]                 Update git-managed plugins (fast-forward)
omarchy plugin validate <plugin-folder>            Validate a folder against the manifest schema
```

`omarchy bar move` / `omarchy bar set` edit the persisted widget layout in
`shell.json`.

Security: plugins run as **unsandboxed code** inside `omarchy-shell`. `add` only
clones + validates + toggles enabled state (it never runs plugin code or hooks);
plugins land disabled so you can review before enabling.

## `omarchy-shell shell` IPC

`omarchy-shell` forwards an IPC call to the already-running shell (it does not
start it). Form: `omarchy-shell <target> <method> [args…]`. The main target is
`shell`:

| Method | Effect |
|--------|--------|
| `ping` | Health check → `ok`. |
| `rescanPlugins` | Re-walk plugin dirs and hot-reload code. |
| `reloadConfig` | Reload `~/.config/omarchy/shell.json`. |
| `listPlugins` | JSON of every discovered plugin. |
| `enablePlugin <id> <placementJson>` | Enable + place; returns `ok` or an error. |
| `setPluginEnabled <id> <enabled>` | Flip enabled bit. **`enabled` is a string — only `"true"` enables.** |
| `putBarWidget <id> <placementJson>` | Place a bar widget. |
| `moveBarWidget <id> <placementJson>` | Move a placed widget. |
| `setBarWidget <id> <key> <valueJson> <selectorJson>` | Set an inline widget setting. |
| `summon <id> <payloadJson>` | Load + open a panel/overlay/menu plugin. |
| `hide <id>` | Close a summoned plugin. |
| `toggle <id> <payloadJson>` | Summon if closed, hide if open. |
| `call <id> <method> <arg>` | Call a method on a loaded plugin. |
| `applyTheme` / `toggleBarTransparency` / `listShellConfig` / `debugBarGeometry` | misc. |

A plugin can also register **its own IPC target** — e.g. a `Panel` with
`ipcTarget: "acme.weather"` responds to `omarchy-shell acme.weather toggle`.

Direct (bypass the wrapper): `quickshell ipc -p $OMARCHY_PATH/shell call shell ping`.

## Persisted state — `~/.config/omarchy/shell.json`

One file owns the whole layout + per-entry settings + enabled list:
```json
{
  "version": 1,
  "idle": { "screensaver": 150, "lock": 300 },
  "bar": {
    "id": "omarchy.bar", "position": "top",
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left":   [ { "id": "omarchy.menu" } ],
      "center": [ { "id": "omarchy.clock", "format": "HH:mm" } ],
      "right":  [ { "id": "omarchy.audio" } ]
    }
  },
  "plugins": []
}
```
Rules: bar widgets are entries in `bar.layout.<section>` (settings inline on the
entry, no sub-object); non-widget plugins are entries in `plugins[]`; a
third-party plugin is enabled iff its id appears in `shell.json`; `version: 1` is
required at the top level. Defaults are not deep-merged once a user customizes.
