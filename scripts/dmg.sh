#!/bin/bash
set -euo pipefail

app="dist/GlassNotes.app"
version=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
archs=$(lipo -archs "$app/Contents/MacOS/GlassNotes")
target="dist/GlassNotes-$version-${archs// /-}.dmg"
stage=$(mktemp -d dist/.dmg.XXXXXX)
trap 'rm -rf "$stage"' EXIT

mkdir "$stage/contents"
ditto "$app" "$stage/contents/GlassNotes.app"
codesign --verify --deep --strict "$stage/contents/GlassNotes.app"
ln -s /Applications "$stage/contents/Applications"
hdiutil create -quiet -volname "GlassNotes" -srcfolder "$stage/contents" -format UDZO "$stage/image.dmg"
hdiutil verify -quiet "$stage/image.dmg"
mv -f "$stage/image.dmg" "$target"
echo "$target"
