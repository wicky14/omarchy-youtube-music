#!/usr/bin/env bash
# Install / Uninstall the omakid.youtube-music Omarchy plugin.
#
# Usage:
#   ./install.sh                      # install plugin + add to right section
#   ./install.sh --section left       # install + add to left section
#   ./install.sh --section center     # install + add to center section
#   ./install.sh --section right      # install + add to right section
#   ./install.sh --no-bar             # install plugin only, skip bar placement
#   ./install.sh --uninstall          # remove plugin + bar entry
#   ./install.sh --remove             # alias for --uninstall
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="omakid.youtube-music"
ADD_BAR=1
ACTION="install"
BAR_SECTION="right"

for arg in "$@"; do
  case "$arg" in
    --uninstall|--remove) ACTION="uninstall" ;;
    --no-bar) ADD_BAR=0 ;;
    --section)
      # next arg is the section
      shift_next=1
      continue
      ;;
    left|center|right)
      if [[ "${shift_next:-}" == "1" ]]; then
        BAR_SECTION="$arg"
        shift_next=0
      else
        echo "unknown option: $arg (did you mean --section $arg?)" >&2; exit 1
      fi
      ;;
    --section=left|--section=center|--section=right)
      BAR_SECTION="${arg#--section=}"
      ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
  shift_next=0
done

PLUGINS_DIR="$HOME/.config/omarchy/plugins"
TARGET="$PLUGINS_DIR/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

# ── Uninstall ────────────────────────────────────────────────────────────
if [[ "$ACTION" == "uninstall" ]]; then
  echo "Uninstalling $PLUGIN_ID..."

  # Stop any running mpv instance
  SOCKET="$XDG_RUNTIME_DIR/omarchy-ytmusic/mpv-socket"
  if [[ -S "$SOCKET" ]]; then
    echo '{"command":["stop"]}' | socat - "$SOCKET" 2>/dev/null || true
  fi

  # Kill the background mpv process if tracked
  if [[ -f "$XDG_RUNTIME_DIR/omarchy-ytmusic/mpv.pid" ]]; then
    kill "$(cat "$XDG_RUNTIME_DIR/omarchy-ytmusic/mpv.pid")" 2>/dev/null || true
    rm -f "$XDG_RUNTIME_DIR/omarchy-ytmusic/mpv.pid"
  fi

  # Remove plugin directory
  if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    rm -rf "$TARGET"
    echo "Removed plugin from $TARGET"
  fi

  # Disable via omarchy CLI
  omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true

  # Remove bar entry from shell.json
  if [[ -f "$SHELL_JSON" ]]; then
    python3 - "$SHELL_JSON" "$PLUGIN_ID" <<'PY'
import json, sys
path, plugin_id = sys.argv[1], sys.argv[2]
cfg = json.load(open(path))
layout = cfg.get("bar", {}).get("layout", {})
changed = False
for section in ("left", "center", "right"):
    entries = layout.get(section, [])
    new_entries = [e for e in entries if e.get("id") != plugin_id]
    if len(new_entries) != len(entries):
        layout[section] = new_entries
        changed = True
if changed:
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("Removed " + plugin_id + " from bar layout")
else:
    print("Bar entry not found (already removed)")
PY
  fi

  # Rescan plugins
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

  # Clean up runtime files
  rm -rf "$XDG_RUNTIME_DIR/omarchy-ytmusic" 2>/dev/null || true

  echo
  echo "Done. $PLUGIN_ID has been uninstalled."
  echo "If the icon persists: omarchy restart shell"
  exit 0
fi

# ── Install ──────────────────────────────────────────────────────────────
echo "Installing $PLUGIN_ID..."

# Check dependencies
MISSING=""
for cmd in yt-dlp mpv; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING="$MISSING $cmd"
  fi
done
if [[ -n "$MISSING" ]]; then
  echo "WARNING: Missing dependencies:$MISSING" >&2
  echo "Install them with your package manager before using the plugin." >&2
  echo
fi

# 1. Install / refresh the plugin
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  echo "Replacing existing install..."
  rm -rf "$TARGET"
fi

mkdir -p "$PLUGINS_DIR" "$TARGET"
cp "$REPO_DIR/manifest.json" \
   "$REPO_DIR/BarWidget.qml" \
   "$REPO_DIR/YouTubeMusicService.qml" \
   "$REPO_DIR/SearchModel.js" \
   "$REPO_DIR/ytmusic-player" \
   "$TARGET/"
chmod +x "$TARGET/ytmusic-player"
echo "Installed $PLUGIN_ID into $TARGET"

# 2. Enable via omarchy CLI
omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || \
  omarchy plugin add "file://$REPO_DIR" --enable --yes >/dev/null 2>&1 || true
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

# 3. Add bar entry if requested
if (( ADD_BAR )); then
  if ! [[ -f "$SHELL_JSON" ]]; then
    echo "No shell.json at $SHELL_JSON; add { \"id\": \"$PLUGIN_ID\" } to the bar manually." >&2
  else
    python3 - "$SHELL_JSON" "$PLUGIN_ID" "$BAR_SECTION" <<'PY'
import json, sys
path = sys.argv[1]
plugin_id = sys.argv[2]
target_section = sys.argv[3]
cfg = json.load(open(path))
layout = cfg.setdefault("bar", {}).setdefault("layout", {})

# Remove from all sections first (in case it's elsewhere)
for section in ("left", "center", "right"):
    entries = layout.get(section, [])
    layout[section] = [e for e in entries if e.get("id") != plugin_id]

# Add to target section
entries = layout.setdefault(target_section, [])
if not any(x.get("id") == plugin_id for x in entries):
    entries.append({"id": plugin_id})

with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("Added " + plugin_id + " to bar " + target_section + " section")
PY
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
fi

echo
echo "Done. YouTube Music widget added to bar $BAR_SECTION section."
echo "Left click: open search & controls"
echo "Middle click: stop playback"
echo "Right click: play/pause"
echo "Scroll: change volume"
echo
echo "If it does not appear: omarchy restart shell"
