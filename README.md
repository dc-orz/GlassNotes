<img src="Packaging/AppIcon.png" alt="GlassNotes icon" width="80" height="80">

# GlassNotes

[![CI](https://github.com/dc-orz/GlassNotes/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dc-orz/GlassNotes/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-555555)](#install)
[![MIT License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[简体中文](README.zh-CN.md)

GlassNotes is a native macOS menu bar app for short notes that live on your desktop. Each note is a separate pane of frosted glass. Arrange a few where you want them, glance at them between windows, and wipe them away when you're done.

![Four desktop notes on glass, with English and Chinese text and the edit and complete buttons visible on one note](docs/preview.jpg)

## Install

GlassNotes runs on macOS 14 or later. The app interface is currently in Simplified Chinese.

If you have a GlassNotes DMG, open it and drag **GlassNotes.app** into **Applications**. The architecture is in the DMG filename. Choose `arm64` for Apple silicon. When upgrading, quit the running copy first. Your notes carry over automatically.

## Use GlassNotes

| Action | How |
| --- | --- |
| Capture | Click the handwritten mark in the menu bar or press **⌃⌥N**. Enter a note and press **⌘↩** to place it on the desktop. |
| Arrange | Drag the text, edge, or open area of a note. Regular app windows sit above your notes. |
| Edit | Hover over the note and click the pencil in the lower-right corner. Press **⌘↩** to save or **Esc** to cancel. |
| Complete and restore | Click the circled checkmark. The text wipes away and the glass fades. Undo within five seconds, or restore it later from **已完成** in the menu bar panel. |
| Permanently delete | In **已完成**, click the trash icon next to a note, then confirm **永久删除**. |
| Check for updates | Choose **… → 检查更新**, then **下载并安装** to download and install the update for your Mac. Once installation finishes, quit and reopen GlassNotes. |

To set a global capture shortcut, open **… → 快速记录快捷键 → 录制快捷键** and press the combination. Use Command, Option, or Control with a key, or use a function key on its own. Press Esc to cancel. The **预设** menu restores a preset or turns the shortcut off.

## Choose a glass style

Open **… → 玻璃透明度** (Glass appearance) in the menu bar panel. On macOS 26 or later, **使用原生 Liquid Glass** switches every desktop note immediately.

| Setting | What you’ll see |
| --- | --- |
| Off · Frosted glass (default, macOS 14+) | An AppKit backdrop softly blurs the wallpaper and stays steady when you switch windows. Choose a preset, then adjust **材质强度** (material strength, 20–100%) and **背景压暗** (background dimming, 0–62%). **恢复** restores the preset values. |
| On · Native Liquid Glass (macOS 26+) | Apple’s material bends wallpaper details around the edges of the focused note. When another window takes focus, the system softens the effect. A note left on the desktop can look more muted most of the time. |

To compare on your own wallpaper, drag a note or click its pencil. The glass stays focused after you release the note or finish editing, until another window takes focus. Hold **⌘** while dragging to keep focus in the current window. Switch Liquid Glass off to return to your saved frosted settings. Both styles use a solid background when Reduce Transparency is enabled. Note animations follow Reduce Motion.

![The same note and wallpaper with frosted glass, focused Liquid Glass, and unfocused Liquid Glass, from left to right](docs/glass-modes.jpg)

## Local storage

GlassNotes works offline. It stores note text, completion history, and desktop positions in `~/Library/Application Support/GlassNotes/notes.json`. Quit GlassNotes before copying or restoring that file. Appearance and shortcut preferences use macOS user defaults.

## Build from source

Install a Swift 6.2 or later toolchain with the macOS 26 SDK or later, plus Python 3 for the design checks. From the repository root run:

```sh
make app
open dist/GlassNotes.app
```

| Command | Purpose |
| --- | --- |
| `make check` | Check formatting and design conventions, then run the unit tests. |
| `make smoke` | Exercise native windows in a logged-in Mac desktop session. |
| `make fmt` | Format Swift sources. |
| `make dmg` | Build the app and create a drag-to-install disk image in `dist/` for the build machine's architecture. |

Local builds use an ad hoc signature. For public binary distribution, sign with Developer ID and notarize the disk image. [Apple's distribution guide](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

GitHub Actions runs `make check` and `make dmg` on macOS for pushes and pull requests to `main`. Download **GlassNotes-arm64** from the workflow run’s **Artifacts** section for the verified DMG and its SHA-256 checksum. Use `make smoke` locally to test window focus and keyboard interaction in a logged-in desktop session.

## Publish a release

Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Packaging/Info.plist`. Once that change has merged and CI passes, tag the release commit with `v` followed by the exact app version and push that tag. The tag workflow builds and verifies the arm64 DMG on macOS, then publishes those same bytes and their checksum to GitHub Releases. If an upload is interrupted, rerun the failed release job to resume the draft.

## Contributing

Keep storage and layout logic in [NoteCore](Sources/NoteCore), visual tokens and components in [NoteDesign](Sources/NoteDesign), and windows and menu interactions in [GlassNotes](Sources/GlassNotes). Before submitting a change, run `make check` and, for window interactions, `make smoke`. See the [architecture](docs/architecture.md), [design system](docs/design-system.md), and [repository conventions](AGENTS.md).

## License

[MIT License](LICENSE). GlassNotes renders text through the macOS system font APIs. The app package contains no font binaries.
