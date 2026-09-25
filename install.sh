#!/usr/bin/env bash

# Omarchy Weather-FX Plugin Installer
# Installs the desktop weather effect service and top bar widget.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="$HOME/.config/omarchy/plugins/jaj.weather-fx"
TARGET_BIN_DIR="$HOME/.local/bin"

echo "==> Installing Weather-FX Omarchy Plugin..."

# 1. Install Plugin
mkdir -p "$(dirname "$TARGET_PLUGIN_DIR")"
if [[ -L "$TARGET_PLUGIN_DIR" ]] || [[ -d "$TARGET_PLUGIN_DIR" ]]; then
  rm -rf "$TARGET_PLUGIN_DIR"
fi
ln -sf "$SCRIPT_DIR" "$TARGET_PLUGIN_DIR"
echo "  [✓] Linked plugin to $TARGET_PLUGIN_DIR"

# 2. Install CLI Helper
mkdir -p "$TARGET_BIN_DIR"
cp "$SCRIPT_DIR/scripts/omarchy-weather-fx" "$TARGET_BIN_DIR/omarchy-weather-fx"
chmod +x "$TARGET_BIN_DIR/omarchy-weather-fx"
echo "  [✓] Installed CLI helper to $TARGET_BIN_DIR/omarchy-weather-fx"

# 3. Validate Plugin
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$TARGET_PLUGIN_DIR"
  echo "  [✓] Plugin validation passed"
fi

# 4. Check shell.json layout
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
if [[ -f "$SHELL_CONFIG" ]]; then
  if ! grep -q "jaj.weather-fx" "$SHELL_CONFIG"; then
    echo "  [i] Note: Add \"jaj.weather-fx\" to your bar layout in $SHELL_CONFIG"
    echo "      e.g. In \"center\": [ ..., \"jaj.weather-fx\" ]"
  else
    echo "  [✓] Plugin already present in $SHELL_CONFIG"
  fi
fi

# 5. Restart shell if omarchy is active
if pgrep -f "quickshell.*shell.qml" >/dev/null 2>&1; then
  echo "  [i] Restarting omarchy shell to apply..."
  omarchy restart shell || true
fi

echo "==> Installation complete! Run 'omarchy-weather-fx' or click the bar widget."
