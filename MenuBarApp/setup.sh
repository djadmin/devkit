#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "→ Checking for xcodegen…"
if ! command -v xcodegen &>/dev/null; then
  echo "→ Installing xcodegen via Homebrew…"
  brew install xcodegen
fi

echo "→ Generating Xcode project…"
xcodegen generate

echo ""
echo "✓ Done! Open in Xcode:"
echo "  open DevkitBar.xcodeproj"
echo ""
echo "  Or build from the command line:"
echo "  xcodebuild -scheme DevkitBar -configuration Debug build"
