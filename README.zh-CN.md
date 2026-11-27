<img src="Packaging/AppIcon.png" alt="GlassNotes 应用图标" width="80" height="80">

# GlassNotes

[![CI](https://github.com/dc-orz/GlassNotes/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dc-orz/GlassNotes/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-555555)](#安装)
[![MIT 许可证](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[English](README.md)

GlassNotes 是一款原生 macOS 菜单栏便签。每张便签都是一块独立的毛玻璃。把几张便签散放在桌面，切回桌面时一眼就能看到，做完一件就擦掉一张。

![四张中英文玻璃便签散放在桌面，其中一张显示编辑和完成按钮](docs/preview.jpg)

## 安装

支持 macOS 14 及以上。当前应用界面为简体中文。

如果已取得 GlassNotes 的 DMG，双击打开，将 **GlassNotes.app** 拖入「应用程序」。文件名会标出架构，Apple 芯片的 Mac 选择 `arm64`。升级前先退出正在运行的旧版，原有便签会自动沿用。

## 使用

| 操作 | 方法 |
| --- | --- |
| 快速记录 | 点菜单栏的手写笔迹图标，或按 **⌃⌥N**。输入内容后按 **⌘↩** 贴到桌面。 |
| 移动 | 在正文、边缘或空白处按住拖动即可。普通应用窗口位于便签上方。 |
| 编辑 | 指针移入便签，点右下角的铅笔。按 **⌘↩** 保存，按 **Esc** 取消。 |
| 完成与恢复 | 点圆圈勾，文字会擦去，玻璃随之淡出。五秒内可点「撤销」，之后仍可在菜单栏的「已完成」列表恢复。 |
| 永久删除 | 在「已完成」里点击便签旁的垃圾桶，核对内容后点「永久删除」。 |
| 检查更新 | 打开菜单栏面板的 **… → 检查更新**。有适配这台 Mac 的新版时，点 **下载并安装**。看到安装成功提示后，退出并重新打开 GlassNotes。 |

打开「… → 快速记录快捷键 → 录制快捷键」，按下想用的组合键。可使用 ⌘、⌥ 或 ⌃ 搭配其他键，也可单独使用功能键。按 Esc 取消，在「预设」里可恢复预设或关闭快捷键。

## 选择玻璃效果

在菜单栏面板中打开 **… → 玻璃透明度**。macOS 26 及以上提供 **使用原生 Liquid Glass** 开关，切换后立即应用到所有桌面便签。

| 开关 | 桌面上的效果 |
| --- | --- |
| 关闭 · 毛玻璃（默认，macOS 14+） | AppKit 毛玻璃让壁纸轻微模糊，切换窗口时便签的明暗保持稳定。选好预设后，可调节「材质强度」（20–100%）和「背景压暗」（0–62%），点「恢复」可回到预设值。 |
| 开启 · 原生 Liquid Glass（macOS 26+） | 便签获得焦点时，边缘能看到壁纸纹理被折射、拉弯。点到其他窗口后，系统会弱化效果。便签如果常驻桌面，大部分时间看到的可能是较柔和的失焦外观。 |

想用自己的壁纸对比，可以拖动一张便签，或点铅笔编辑。松手或结束编辑后，玻璃会保持聚焦时的折射效果，直到点到其他窗口。按住 **⌘** 拖动可让焦点留在当前窗口。关掉原生效果就会恢复之前的毛玻璃设置。系统开启「减少透明度」时，两种模式都使用实色背景。便签动画跟随「减少动态效果」设置。

![同一张便签和壁纸，从左到右分别是毛玻璃、原生玻璃聚焦、原生玻璃失焦](docs/glass-modes.jpg)

## 本地存储

GlassNotes 可离线使用。正文、完成记录和桌面位置保存在 `~/Library/Application Support/GlassNotes/notes.json`。备份或恢复这个文件前请先退出应用。外观和快捷键使用 macOS 偏好设置保存。

## 从源码构建

需要 Swift 6.2 或更新工具链、macOS 26 或更新 SDK，以及用于设计检查的 Python 3。在仓库根目录运行：

```sh
make app
open dist/GlassNotes.app
```

| 命令 | 用途 |
| --- | --- |
| `make check` | 检查格式与设计规范，并运行单元测试。 |
| `make smoke` | 在已登录的 Mac 图形桌面中运行原生窗口测试。 |
| `make fmt` | 格式化 Swift 源码。 |
| `make dmg` | 按构建机器架构打包应用，在 `dist/` 生成可拖入安装的镜像。 |

本地构建使用临时签名。公开分发二进制版本时，应使用 Developer ID 签名并对镜像进行公证。[Apple 分发指南](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

推送到 `main` 或向该分支提交拉取请求时，GitHub Actions 会在 macOS 上运行 `make check` 和 `make dmg`。在该次运行的 **Artifacts** 区域下载 **GlassNotes-arm64**，即可取得经过校验的 DMG 和 SHA-256 校验文件。窗口焦点和键盘交互可在已登录的 Mac 桌面上用 `make smoke` 验证。

## 发布版本

在 `Packaging/Info.plist` 中更新 `CFBundleShortVersionString` 并递增 `CFBundleVersion`。合并且 CI 通过后，在发布提交上打一个由 `v` 加应用版本号组成的标签，将该标签推送到 GitHub。标签工作流会在 macOS 上构建并验证 arm64 DMG，再将同一份安装包及其校验文件发布到 GitHub Releases。上传中断时，可重跑失败的发布任务，继续完成草稿。

## 参与开发

存储与布局逻辑位于 [NoteCore](Sources/NoteCore)，视觉 token 和组件位于 [NoteDesign](Sources/NoteDesign)，桌面窗口及菜单交互位于 [GlassNotes](Sources/GlassNotes)。提交改动前运行 `make check`，涉及窗口交互时再运行 `make smoke`。更多约定见[技术方案](docs/architecture.md)、[设计系统](docs/design-system.md)和[仓库开发规范](AGENTS.md)。

## 许可证

项目采用 [MIT 许可证](LICENSE)。GlassNotes 通过 macOS 系统字体 API 渲染文字，安装包不包含字体文件。
