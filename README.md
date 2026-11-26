# 墨笺 · GlassNotes

一个 macOS 菜单栏便签工具。便签散放在桌面，可以移动、原位编辑，完成时先擦去笔迹，再淡出玻璃。

## 运行

双击 `dist/墨笺.app`。首次启动会在桌面放入四张可编辑示例。点菜单栏的方框铅笔图标或按 **⌃⌥N**，输入内容后按 **⌘↩** 贴到桌面。快速记录面板的「…」菜单可以换快捷键或退出。

- **移动**　拖住便签上沿。普通应用窗口会盖住桌面便签。
- **编辑**　点击正文，或在菜单栏的「桌面」列表选择一张便签。按 ⌘↩ 或点勾保存，Esc 取消。当正文较长时可滚动阅读。
- **完成**　移入便签，点击右下角的勾。也可以在菜单栏列表中完成。撤销提示显示 5 秒，之后仍可在「已完成」中恢复。
- **墨色**　使用自动前景，或选择瓷白、炭黑、深青。减少动态效果和减少透明度跟随系统设置。

本机存储位于 `~/Library/Application Support/GlassNotes/notes.json`。退出应用后可以复制这个文件进行备份。首版提供本地纯文本便签；手写外观来自随包字体。程序可离线工作。

## 开发

使用 macOS、Swift 6.2+ 和 macOS 26+ SDK。完整 Xcode 或包含这些版本的 Command Line Tools 均可。运行目标为 macOS 14+。macOS 26+ 使用原生 Liquid Glass，14–15 使用原生毛玻璃。构建默认针对当前 Mac 的架构，打包采用本地签名。

| 命令 | 用途 |
| --- | --- |
| `make check` | 检查格式、设计系统边界，并运行数据、布局和字体测试 |
| `make smoke` | 在有桌面会话的 Mac 上短暂创建真实面板，验证编辑、完成、撤销和恢复 |
| `make app` | 编译 Release，复制字体与图标，签名并校验，输出到 dist/ |
| `make fmt` | 用 Swift 工具链的格式化器整理 Swift 源码 |

## 仓库导航

| 目录 | 职责 |
| --- | --- |
| [NoteCore](Sources/NoteCore) | 存档、状态转换、便签布局与坐标 |
| [NoteDesign](Sources/NoteDesign) | 视觉 token、玻璃、手写字、控件和擦字动效 |
| [GlassNotes](Sources/GlassNotes) | 桌面窗口、菜单栏、快捷键、应用装配 |
| [Tests](Tests) | 文件兼容、写入失败、布局、字体和原生窗口验证 |

开发规则见 [AGENTS.md](AGENTS.md)，设计依据与分层决策见 [技术方案](docs/architecture.md)，组件的使用入口见 [设计系统](docs/design-system.md)。
