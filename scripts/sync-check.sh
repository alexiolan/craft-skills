#!/bin/bash
# Check if superpowers has a new version available

SYNC_FILE="$(dirname "$0")/../references/superpowers-sync.md"
LOCAL_VER=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$SYNC_FILE" | head -1)

REMOTE_VER=$(curl -s https://raw.githubusercontent.com/obra/superpowers/main/package.json \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null)

if [ -z "$REMOTE_VER" ]; then
  echo "✗ Could not fetch remote version"
  exit 1
fi

echo "Local:  $LOCAL_VER"
echo "Remote: $REMOTE_VER"

if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
  echo "✓ Up to date"
else
  echo "⚠ New version available ($REMOTE_VER) — run /reflect evolve in Claude Code"
fi
