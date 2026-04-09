#!/usr/bin/env bash
# Installs the skill-logs viewer CLI to ~/.local/bin.
#
# Public repo:
#   curl -sL https://raw.githubusercontent.com/silverlogic/skill-observer/main/install.sh | bash
#
# Private repo (requires gh CLI):
#   gh repo clone silverlogic/skill-observer /tmp/skill-observer && bash /tmp/skill-observer/install.sh

set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
REPO="silverlogic/skill-observer"
BRANCH="main"
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR=""
fi

mkdir -p "$INSTALL_DIR"

# If running from a local clone, copy directly
if [[ -f "$SCRIPT_DIR/bin/skill-logs" ]]; then
  cp "$SCRIPT_DIR/bin/skill-logs" "$INSTALL_DIR/skill-logs"
# Otherwise download from GitHub
elif command -v curl &>/dev/null; then
  curl -sL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/bin/skill-logs" -o "$INSTALL_DIR/skill-logs"
elif command -v wget &>/dev/null; then
  wget -qO "$INSTALL_DIR/skill-logs" "https://raw.githubusercontent.com/${REPO}/${BRANCH}/bin/skill-logs"
else
  echo "Error: curl or wget required." >&2
  exit 1
fi

chmod +x "$INSTALL_DIR/skill-logs"

# Check if ~/.local/bin is on PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  SHELL_RC=""
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
  fi
  echo ""
  echo "Add ~/.local/bin to your PATH by running:"
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $SHELL_RC"
  echo "  source $SHELL_RC"
  echo ""
fi

echo "Installed skill-logs to $INSTALL_DIR/skill-logs"
echo "Run 'skill-logs --help' to get started."
