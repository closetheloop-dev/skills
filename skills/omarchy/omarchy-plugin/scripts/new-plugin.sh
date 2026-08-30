#!/usr/bin/env bash
# Scaffold a new Omarchy (Quattro) bar-widget plugin as a REAL directory under
#   ~/.config/omarchy/plugins/<id>/
#
# A Quattro bar widget is TWO QML files: BarWidget.qml (the bar entry point)
# loads Panel.qml through a Loader and forwards the panel lifecycle the bar
# relies on. Both files share one moduleName equal to the manifest id; the
# nested panel is NOT declared as a separate manifest kind.
#
# Usage: new-plugin.sh <id> [--name "Display Name"] [--author NAME]
#                            [--license SPDX] [--enable]
#   <id>          namespaced plugin id, e.g. io.github.yourname.custom-clock.
#                 Machine identity: the install dir, registry key, moduleName,
#                 and IPC target. Letters/digits/./_/- only, must contain a dot,
#                 and the built-in `omarchy.*` namespace is reserved.
#   --name        human-facing name + barWidget.displayName. Defaults to a
#                 title-cased form of the id's last segment.
#   --author      manifest author (default: "Your name").
#   --license     SPDX license id written to the manifest (default: MIT).
#   --enable      rescan + enable it after creating (needs the shell running).
set -euo pipefail

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

# Interactive only when both ends are a terminal; agents/pipes stay noninteractive.
is_tty() { [ -t 0 ] && [ -t 1 ]; }

# prompt_var <varname> <prompt> <default>
prompt_var() {
  local __var=$1 __prompt=$2 __def=$3 __ans=""
  if [ -n "$__def" ]; then read -r -p "$__prompt [$__def]: " __ans || __ans=""
  else read -r -p "$__prompt: " __ans || __ans=""; fi
  [ -z "$__ans" ] && __ans=$__def
  printf -v "$__var" '%s' "$__ans"
}

id=""
display=""
author=""
license=""
enable=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name)      display="${2:-}"; shift 2 ;;
    --name=*)    display="${1#*=}"; shift ;;
    --author)    author="${2:-}"; shift 2 ;;
    --author=*)  author="${1#*=}"; shift ;;
    --license)   license="${2:-}"; shift 2 ;;
    --license=*) license="${1#*=}"; shift ;;
    --enable)    enable=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    --*)         echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)           if [ -z "$id" ]; then id="$1"; shift
                 else echo "unexpected argument: $1" >&2; exit 2; fi ;;
  esac
done

# Gather the id interactively when it wasn't passed; stay strict when noninteractive.
if [ -z "$id" ] && is_tty; then
  prompt_var id "Plugin id (reverse-DNS, e.g. io.github.you.custom-clock)" ""
fi
[ -n "$id" ] || { echo "missing <id>" >&2; usage >&2; exit 2; }

# --- validate the id ---------------------------------------------------------
# Constrain to a safe namespaced charset. This keeps the id valid as a directory
# name, JSON string, and QML string with no escaping, so nothing it contains can
# corrupt the generated files. Start/end alphanumeric; letters, digits, '.', '_',
# '-' inside; at least one dot (namespaced); no '..'; and the reserved built-in
# namespace is refused.
if ! printf '%s' "$id" | grep -qE '^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$'; then
  echo "invalid id '$id': use letters, digits, '.', '_', '-'; start and end alphanumeric" >&2
  echo "  e.g. io.github.yourname.custom-clock" >&2
  exit 2
fi
case "$id" in
  *..*) echo "invalid id '$id': '..' is not allowed" >&2; exit 2 ;;
esac
if ! printf '%s' "$id" | grep -q '\.'; then
  echo "invalid id '$id': must be namespaced with a dot, e.g. io.github.yourname.custom-clock" >&2
  exit 2
fi
case "$id" in
  omarchy|omarchy.*)
    echo "invalid id '$id': the 'omarchy.*' namespace is reserved for built-in plugins." >&2
    echo "  Use your own namespace, e.g. io.github.yourname.$(printf '%s' "$id" | sed 's/^omarchy\.//')" >&2
    exit 2 ;;
esac

# --- gather the human-facing metadata ----------------------------------------
# id is the machine identity; name/displayName/author/license are presentation.
# A title-cased last id segment is only ever a suggested default, never a silent
# substitute: prompt for the real values on a TTY, and require --name (fail
# clearly) when noninteractive so an agent must collect and pass it explicitly.
default_display=""
seg="${id##*.}"
seg="${seg//-/ }"
seg="${seg//_/ }"
for word in $seg; do
  head_char="$(printf '%s' "${word:0:1}" | tr '[:lower:]' '[:upper:]')"
  default_display="${default_display}${default_display:+ }${head_char}${word:1}"
done
[ -n "$default_display" ] || default_display="$id"

if [ -z "$display" ]; then
  if is_tty; then
    prompt_var display "Human-facing name" "$default_display"
  else
    echo "no --name given and not a TTY: pass --name \"<Display Name>\" (id '$id' is the machine identity, not the display name)" >&2
    exit 2
  fi
fi
if [ -z "$author" ]; then
  if is_tty; then
    prompt_var author "Author" "Your name"
  else
    author="Your name"
    echo "note: no --author given; using placeholder \"Your name\" — pass --author for a publishable plugin" >&2
  fi
fi
if [ -z "$license" ]; then
  if is_tty; then
    prompt_var license "License (SPDX id)" "MIT"
  else
    license="MIT"
  fi
fi

# --- input policy: no control characters in free-text fields -----------------
# These land inside single-line quoted JSON/QML string fields. Control bytes
# (U+0000–U+001F and DEL) can't appear there validly and a display name, author,
# or license never needs one, so reject them with a clear diagnostic before the
# destination is created rather than emitting invalid source.
check_printable() {
  case $1 in
    *[[:cntrl:]]*)
      echo "invalid $2: contains a control character; use printable text only" >&2
      exit 2 ;;
  esac
}
check_printable "$display" "name"
check_printable "$author" "author"
check_printable "$license" "license"

# --- JSON/QML string escaping (double-quoted string body) --------------------
# Emit a value safe to drop between the quotes of a JSON or QML "..." literal.
# Control characters are already rejected above, so only the backslash and the
# double quote need escaping (backslash first, so the quote's escape isn't
# doubled).
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

display_esc="$(json_escape "$display")"
author_esc="$(json_escape "$author")"
license_esc="$(json_escape "$license")"
desc="A $display bar widget for the Omarchy bar."
desc_esc="$(json_escape "$desc")"
year="$(date +%Y)"

dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$id"
[ -e "$dir" ] && { echo "already exists: $dir" >&2; exit 1; }
mkdir -p "$dir/assets"

# --- render a template safely ------------------------------------------------
# Fill a placeholder template (a quoted heredoc, so the shell expands nothing in
# it) in a SINGLE left-to-right pass: at each step find the earliest remaining
# placeholder, copy the template text before it plus the replacement, and advance
# past the placeholder IN THE TEMPLATE. Inserted values land in the output and are
# never rescanned, so a value that itself contains a placeholder token (e.g. a
# name of "__AUTHOR__" or "__YEAR__") is preserved verbatim. No sed, no regex, no
# source-language interpolation; and bash's backslash-mangling ${v//} is avoided.
#
# emit <out> <template> <name> <author> <license> <desc>
emit() {
  local out_file=$1 tmpl=$2 name=$3 author=$4 license=$5 lic_desc=$6
  local result="" key pre pos bestpos bestkey repl adv
  while :; do
    bestpos=-1; bestkey=""
    for key in __ID__ __NAME__ __AUTHOR__ __LICENSE__ __DESC__ __YEAR__; do
      pre=${tmpl%%"$key"*}
      [ "$pre" = "$tmpl" ] && continue          # token not present
      pos=${#pre}
      if [ "$bestpos" -lt 0 ] || [ "$pos" -lt "$bestpos" ]; then
        bestpos=$pos; bestkey=$key
      fi
    done
    [ "$bestpos" -lt 0 ] && break               # no placeholders left
    case $bestkey in
      __ID__)      repl=$id ;;
      __NAME__)    repl=$name ;;
      __AUTHOR__)  repl=$author ;;
      __LICENSE__) repl=$license ;;
      __DESC__)    repl=$lic_desc ;;
      __YEAR__)    repl=$year ;;
    esac
    result+=${tmpl:0:bestpos}$repl
    adv=$(( bestpos + ${#bestkey} ))
    tmpl=${tmpl:adv}
  done
  printf '%s\n' "$result$tmpl" > "$out_file"
}

# --- manifest.json -----------------------------------------------------------
emit "$dir/manifest.json" "$(cat <<'JSON'
{
  "schemaVersion": 1,
  "id": "__ID__",
  "name": "__NAME__",
  "version": "0.1.0",
  "author": "__AUTHOR__",
  "license": "__LICENSE__",
  "description": "__DESC__",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "__NAME__",
    "category": "Fun",
    "defaultSection": "center",
    "allowMultiple": false
  }
}
JSON
)" "$display_esc" "$author_esc" "$license_esc" "$desc_esc"

# --- BarWidget.qml (the bar entry point) -------------------------------------
emit "$dir/BarWidget.qml" "$(cat <<'QML'
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar entry point. It owns the bar icon and hosts the panel: the Loader below
// loads Panel.qml, this root forwards the panel lifecycle the bar routes through
// (open/close/toggle/opened/popoutSwitchClosing), and it injects bar/anchorItem/
// hostWidget into the loaded panel. Keep moduleName equal to the manifest id in
// BOTH files, and do not add a second manifest kind for the nested panel.
BarWidget {
  id: root
  moduleName: "__ID__"

  // Panel lifecycle, forwarded to the loaded Panel.qml. The bar identifies and
  // routes summon/hide/popout switching through these on the bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  // bar is null during Component.onCompleted, so inject on load, once more via
  // callLater, and again whenever the bar changes.
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  // REQUIRED: the bar sizes the slot from the root's implicit size. Omit these
  // and the icon never draws even though the widget loaded.
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
    // A bundled SVG renders reliably; the bar font's glyph coverage is uneven.
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
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
QML
)" "$display_esc" "$author_esc" "$license_esc" "$desc_esc"

# --- Panel.qml (loaded by BarWidget.qml) -------------------------------------
emit "$dir/Panel.qml" "$(cat <<'QML'
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The panel loaded by BarWidget.qml. It does NOT own IPC (manageIpc: false) —
// the bar widget does — and it keeps the same moduleName as the manifest id.
// bar / anchorItem / hostWidget are injected by BarWidget.injectPanel().
Panel {
  id: root
  moduleName: "__ID__"
  ipcTarget: "__ID__"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  // The bar tracks the widget mounted in its slot (BarWidget.qml), not this
  // nested panel, so stand in for it wherever the bar identifies a panel.
  readonly property var barIdentity: hostWidget || root

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  // Tab between adjacent bar panels; guarded because bar is injected late.
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Guarded so the panel still renders before the bar is injected.
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        padding: Style.space(16)
        spacing: Style.space(10)

        Text {
          width: parent.width - Style.space(32)
          text: "__NAME__"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          wrapMode: Text.WordWrap
        }
        Text {
          width: parent.width - Style.space(32)
          text: "Edit Panel.qml to build your panel."
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
QML
)" "$display_esc" "$author_esc" "$license_esc" "$desc_esc"

# --- bundled SVG icon (guaranteed to render, unlike an arbitrary glyph) -------
cat > "$dir/assets/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="#7aa2f7"/></svg>
SVG

# --- README.md (publish-ready placeholder; documents the privilege boundary) -
emit "$dir/README.md" "$(cat <<'MD'
# __NAME__

__DESC__

> **Plugins run unsandboxed** in the long-running Omarchy shell process with your
> user's permissions. Before sharing this plugin, document every external
> dependency, command, service, installer, and privilege it uses — and review any
> third-party plugin before enabling it.

## Install

```sh
omarchy plugin add <git-url> --enable
```

## Usage

Click the bar icon to open the panel; press Escape to close it.

## Configure

```sh
omarchy bar move __ID__ --section center
```

## Remove

```sh
omarchy plugin remove __ID__
```
MD
)" "$display" "$author" "$license" "$desc"

# --- LICENSE -----------------------------------------------------------------
if [ "$license" = "MIT" ]; then
  emit "$dir/LICENSE" "$(cat <<'LIC'
MIT License

Copyright (c) __YEAR__ __AUTHOR__

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LIC
)" "$display" "$author" "$license" "$desc"
else
  emit "$dir/LICENSE" "$(cat <<'LIC'
__LICENSE__ License

Copyright (c) __YEAR__ __AUTHOR__

Add the full text of the __LICENSE__ license here before publishing.
LIC
)" "$display" "$author" "$license" "$desc"
fi

echo "created $dir"
echo "  id:    $id"
echo "  name:  $display"
echo "  files: manifest.json, BarWidget.qml, Panel.qml, assets/icon.svg, README.md, LICENSE"

if [ "$enable" = 1 ]; then
  OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}" omarchy-shell shell rescanPlugins
  omarchy plugin enable "$id"
  echo "enabled $id"
fi
