# Host injection reference

`omarchy-shell` constructs each plugin entry point, then sets host properties on
it **only if the property exists** on the instance (`if ("x" in target) target.x =
…`). So: **declare exactly the injected properties you use**, and don't read them
in `Component.onCompleted` — they're assigned *after* construction (still null at
init).

## What the shell injects

Common to services, bar widgets, and panels:

| Property | Type | What it is |
|----------|------|-----------|
| `omarchyPath` | string | Path to the omarchy install. |
| `shell` | object | The `ShellRoot` host — exposes IPC/config functions (`summon`, `hide`, `toggle`, `serviceFor(id)`, config mutators). |
| `manifest` | object | This plugin's parsed manifest (includes `__sourceDir`, `__isFirstParty`). |
| `pluginRegistry` | object | `services/PluginRegistry.qml` — discovery, enabled-state, bar-layout mutation. |
| `barWidgetRegistry` | object | `services/BarWidgetRegistry.qml` — register/unregister/has/availableIds. |

Additionally, **panel/overlay/menu** plugins get:

| Property | Type | What it is |
|----------|------|-----------|
| `service` | object | The **same-id `service` singleton**, via `shell.serviceFor(pluginId)`. This is how a panel UI shares state with its companion service. |

## Panels via the `Panel` base

If your bar-widget/panel root extends `qs.Ui`'s `Panel`, the base also gives you
`bar`, `settings` (host-managed inline settings from `shell.json`), `moduleName`,
and `setting(name, fallback)` — you don't inject those yourself.

## Minimal declarations

A service that needs the shell handle and its manifest:
```qml
Item {
  property var shell: null
  property var manifest: null
  // …only declare what you use
}
```

A bar widget rarely needs any of these directly — the `Panel` base handles `bar`
and settings; declare `shell`/`pluginRegistry` only if you call into them.

Source: the three injection sites in `/usr/share/omarchy/shell/shell.qml`
(service creation, bar-widget/registry path, and the panel `Loader.onLoaded`).
