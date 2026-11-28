#!/bin/bash
set -euo pipefail

bin_dir="$1"
mkdir -p dist
stage=$(mktemp -d dist/.packaging.XXXXXX)
trap 'rm -rf "$stage"' EXIT
bundle="$stage/GlassNotes.app"
target="dist/GlassNotes.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Helpers" "$bundle/Contents/Resources"
install -m 755 "$bin_dir/GlassNotes" "$bundle/Contents/MacOS/GlassNotes"
install -m 755 "$bin_dir/GlassNotesCLI" "$bundle/Contents/Helpers/glassnotes"
codesign --force --sign - "$bundle/Contents/Helpers/glassnotes"
install -m 644 Packaging/Info.plist "$bundle/Contents/Info.plist"
install -m 644 Packaging/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
install -m 644 Packaging/MenuBarTemplate.png "$bundle/Contents/Resources/MenuBarTemplate.png"
install -m 644 LICENSE "$bundle/Contents/Resources/LICENSE.txt"
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"

# Replace only after verification. An already-running process keeps its mapped executable.
if [[ -d "$target" ]]; then mv "$target" "$stage/previous.app"; fi
if ! mv "$bundle" "$target"; then
    if [[ -d "$stage/previous.app" ]]; then mv "$stage/previous.app" "$target"; fi
    exit 1
fi
echo "$target"
