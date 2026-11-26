#!/bin/bash
set -euo pipefail

app="dist/墨笺.app"
version=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
archs=$(lipo -archs "$app/Contents/MacOS/GlassNotes")
target="dist/GlassNotes-$version-${archs// /-}.dmg"
stage=$(mktemp -d dist/.dmg.XXXXXX)
trap 'rm -rf "$stage"' EXIT

mkdir "$stage/contents"
ditto "$app" "$stage/contents/墨笺.app"
codesign --verify --deep --strict "$stage/contents/墨笺.app"
ln -s /Applications "$stage/contents/Applications"
hdiutil create -quiet -volname "墨笺" -srcfolder "$stage/contents" -format UDZO "$stage/image.dmg"
hdiutil verify -quiet "$stage/image.dmg"
mv -f "$stage/image.dmg" "$target"
echo "$target"
