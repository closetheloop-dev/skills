# manifest.json reference

Every plugin is a **git repo with `manifest.json` at its root**. The authoritative
validator is `validateManifest()` in `/usr/share/omarchy/shell/services/PluginRegistry.qml`;
`omarchy plugin validate <folder>` runs it. Cross-check that file on the target
machine if anything here looks off.

## Required + optional fields

Required: `id`, `name`, `version`, `kinds`, `entryPoints`. Plus `schemaVersion`
which must be exactly `1`.

| Field | Req | Notes |
|-------|-----|-------|
| `schemaVersion` | ✓ | Must be `1`. |
| `id` | ✓ | Plugin id, e.g. `acme.weather`. **No `/`, no `..`, cannot start with `/`.** This is the install dir name under `~/.config/omarchy/plugins/` and the registry key. |
| `name` | ✓ | Human name. |
| `version` | ✓ | Semver string. |
| `kinds` | ✓ | Non-empty array; see kinds below. |
| `entryPoints` | ✓ | Object mapping kind → QML file (relative, no `..`, not absolute). |
| `author` | — | String. |
| `license` | — | String. |
| `description` | — | String. |
| `keepLoaded` | — | Bool. Keep a summoned panel/overlay/menu alive past a single summon. |
| `activation` | — | e.g. `"on-demand"` (seen on agents). |
| `barWidget` | — | Object; required in practice for `bar-widget` kind (see below). |

## Kinds → entryPoints keys

| Kind | entryPoints key | Mounts as |
|------|-----------------|-----------|
| `bar-widget` | `barWidget` | A component the active bar drops into a section. |
| `service` | `service` | A headless singleton, no UI (loads at startup / when enabled). |
| `panel` | `panel` | A persistent or summoned floating window (e.g. OSD). |
| `overlay` | `overlay` | A fullscreen overlay (e.g. background switcher). |
| `menu` | `menu` | A summoned menu surface. |
| `bar` | `bar` | A full bar that can replace the built-in `omarchy.bar` (only one active). |

A plugin may declare multiple kinds (e.g. `["menu","bar-widget"]` or
`["service","bar-widget"]`) with one entry point each.

## The `barWidget` block

```json
"barWidget": {
  "displayName": "Cool clock",
  "description": "…",
  "category": "Time",
  "defaultSection": "left",        // left | center | right  (validated)
  "allowMultiple": false,          // true → multiple independent instances allowed
  "defaults": { "format": "HH:mm" },
  "schema": [
    { "key": "format", "type": "string",  "label": "Format" },
    { "key": "count",  "type": "integer", "label": "Count", "min": 0, "max": 10, "step": 1, "defaultValue": 3 },
    { "key": "mode",   "type": "enum",    "label": "Mode", "options": ["Off","On"], "defaultValue": "Off" },
    { "key": "dir",    "type": "path",    "label": "Folder", "defaultValue": "" }
  ]
}
```

- `defaultSection` (if present) must be `left`, `center`, or `right`.
- `schema` drives a **host-managed settings form** (Setup > Plugins). Field types
  seen in the wild: `string`, `integer` (with `min`/`max`/`step`), `enum` (with
  `options`), `path`. Each entry has `key`, `type`, `label`, optional
  `defaultValue`, `description`. The widget reads these via `Panel.setting(key,
  fallback)`. For **interactive in-panel controls** that the user changes live,
  use a self-managed settings.json bridge instead (see the guide).

## Validation rules (from `validateManifest`)

- manifest must be a plain object; `schemaVersion === 1`.
- required keys present: `id, name, version, kinds, entryPoints`.
- `id`: no `/`, no `..`, not starting with `/`.
- `kinds`: non-empty array. `entryPoints`: object.
- each entry-point value must be a safe relative path (string, non-empty, not
  absolute, no `..`) and resolve inside the plugin dir.
- `barWidget.defaultSection` if present ∈ {left, center, right}.

## Real manifests (first-party, verbatim shapes)

Minimal service (`plugins/services/battery/manifest.json`):
```json
{ "schemaVersion": 1, "id": "omarchy.battery", "name": "Battery",
  "version": "1.0.0", "author": "Omarchy", "description": "Low battery warning service",
  "kinds": ["service"], "entryPoints": { "service": "Service.qml" } }
```

Multi-kind (`plugins/menu/manifest.json`):
```json
{ "schemaVersion": 1, "id": "omarchy.menu", "name": "Omarchy menu",
  "version": "1.0.0", "author": "Omarchy",
  "description": "Quickshell-powered Omarchy command menu",
  "kinds": ["menu", "bar-widget"], "keepLoaded": true,
  "entryPoints": { "menu": "Menu.qml", "barWidget": "BarWidget.qml" },
  "barWidget": { "displayName": "Omarchy menu", "description": "Launches the Omarchy menu",
    "category": "Compositor", "allowMultiple": false } }
```

Bar-widget with settings schema: see `plugins/agents/manifest.json`.
