#!/usr/bin/env bash
# Installs the skill-observer viewer CLI to ~/.local/bin.
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
if [[ -f "$SCRIPT_DIR/bin/skill-observer" ]]; then
  cp "$SCRIPT_DIR/bin/skill-observer" "$INSTALL_DIR/skill-observer"
# Otherwise download from GitHub
elif command -v curl &>/dev/null; then
  curl -sL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/bin/skill-observer" -o "$INSTALL_DIR/skill-observer"
elif command -v wget &>/dev/null; then
  wget -qO "$INSTALL_DIR/skill-observer" "https://raw.githubusercontent.com/${REPO}/${BRANCH}/bin/skill-observer"
else
  echo "Error: curl or wget required." >&2
  exit 1
fi

chmod +x "$INSTALL_DIR/skill-observer"

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

echo "Installed skill-observer to $INSTALL_DIR/skill-observer"
echo "Run 'skill-observer --help' to get started."
