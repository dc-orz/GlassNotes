#!/bin/bash
set -euo pipefail

bin_dir="$1"
mkdir -p dist
stage=$(mktemp -d dist/.packaging.XXXXXX)
trap 'rm -rf "$stage"' EXIT
bundle="$stage/墨笺.app"
target="dist/墨笺.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
install -m 755 "$bin_dir/GlassNotes" "$bundle/Contents/MacOS/GlassNotes"
install -m 644 Packaging/Info.plist "$bundle/Contents/Info.plist"
install -m 644 Packaging/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
ditto "$bin_dir/GlassNotes_NoteDesign.bundle" "$bundle/Contents/Resources/GlassNotes_NoteDesign.bundle"
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"

# Replace only after verification. An already-running process keeps its mapped executable.
if [[ -d "$target" ]]; then mv "$target" "$stage/previous.app"; fi
if ! mv "$bundle" "$target"; then
    if [[ -d "$stage/previous.app" ]]; then mv "$stage/previous.app" "$target"; fi
    exit 1
fi
echo "$target"
