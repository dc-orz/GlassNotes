# 墨笺 · GlassNotes

以 Liquid Glass 为核心的极简 macOS 桌面便签。平时桌面上只留玻璃和白色笔迹，指针移入时再显示操作。

## 运行

双击 `dist/墨笺.app`。首次启动会在桌面放入四张可编辑示例。点菜单栏的方框铅笔图标或按 **⌃⌥N**，输入内容后按 **⌘↩** 贴到桌面。快速记录面板的「…」菜单可以换快捷键或退出。

- **移动**　在查看状态，按住正文、边缘或空白处即可拖动整张便签。右下角留给操作按钮。普通应用窗口会盖住桌面便签。
- **编辑**　点击右下角的铅笔，或在菜单栏的「桌面」列表选择一张便签。按 ⌘↩ 或点勾保存，Esc 取消。当正文较长时可滚动阅读。
- **完成**　移入便签，点击右下角的勾。也可以在菜单栏列表中完成。撤销提示显示 5 秒，之后仍可在「已完成」中恢复。
- **外观**　每张桌面便签都用同一层深色玻璃和瓷白笔迹。减少动态效果和减少透明度跟随系统设置。

本机存储位于 `~/Library/Application Support/GlassNotes/notes.json`。退出应用后可以复制这个文件进行备份。首版提供本地纯文本便签；手写外观来自随包字体。程序可离线工作。

## 开发

使用 macOS、Swift 6.2+ 和 macOS 26+ SDK。完整 Xcode 或包含这些版本的 Command Line Tools 均可。运行目标为 macOS 14+。macOS 26+ 使用原生 Liquid Glass，14–15 使用原生毛玻璃。构建默认针对当前 Mac 的架构，打包采用本地签名。

| 命令 | 用途 |
| --- | --- |
| `make check` | 检查格式、设计系统边界，并运行数据、布局和字体测试 |
| `make smoke` | 在有桌面会话的 Mac 上短暂创建真实面板，验证拖动与按钮的命中范围、位置保存、编辑、完成和恢复 |
| `make app` | 编译 Release，复制字体与图标，签名并校验，输出到 dist/ |
| `make dmg` | 构建应用并生成带有「应用程序」快捷方式的只读安装镜像 |
| `make fmt` | 用 Swift 工具链的格式化器整理 Swift 源码 |

## 打包与分享

在仓库根目录运行 `make dmg`。生成的 `dist/GlassNotes-<版本>-<架构>.dmg` 可直接发送给测试者。接收方双击镜像，将「墨笺」拖进 Applications，再从「应用程序」打开。文件名中的 `arm64` 表示适用于 Apple 芯片 Mac。

默认构建使用本地临时签名。通过网络分享时，接收方的 Mac 可能提示无法验证开发者。准备通过 GitHub Releases 公开分发时，应使用 Developer ID Application 签名，启用 Hardened Runtime 和安全时间戳，再对分发镜像签名，提交 Apple 公证并装订公证票据。详见 [Apple 站外打包指南](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)。

## 仓库导航

| 目录 | 职责 |
| --- | --- |
| [NoteCore](Sources/NoteCore) | 存档、状态转换、便签布局与坐标 |
| [NoteDesign](Sources/NoteDesign) | 视觉 token、玻璃、手写字、控件和擦字动效 |
| [GlassNotes](Sources/GlassNotes) | 桌面窗口、菜单栏、快捷键、应用装配 |
| [Tests](Tests) | 文件兼容、写入失败、布局、字体和原生窗口验证 |

开发规则见 [AGENTS.md](AGENTS.md)，设计依据与分层决策见 [技术方案](docs/architecture.md)，组件的使用入口见 [设计系统](docs/design-system.md)。

## 项目待办

- [ ] 重新探索名称与图标。围绕透明玻璃上的白色笔迹，验证图标在 Mac 上小尺寸显示时的辨识度。
- [ ] 后续评估 AI 功能。优先打磨现有玻璃材质、版式和基础交互。
