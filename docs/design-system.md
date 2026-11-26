# 玻璃便签设计系统

产品以 Liquid Glass 的材质表现和极简操作为核心。回到桌面时，几张便签散放在壁纸上，一眼就能读到白色笔迹。静置时只呈现玻璃和文字。

查看时，除右下角操作区外，整张玻璃都可拖动。悬停、窗口聚焦或启用旁白时，右下角依次显示「编辑」和「完成」。编辑态在同一位置呈现「取消、保存」。菜单保留 macOS 原生控件语义。视觉稿里的笔迹、玻璃和完成反馈分别有对应的运行时实现。

早期视觉探索见[桌面全景](reference/glass-desktop.png)、[擦字分镜](reference/glass-erase.png)和 [v0.3 token 表](reference/glass-tokens-v0.3.pdf)。当前桌面采用下文的单一玻璃材质与白色笔迹。

| 设计职责 | 修改位置 | 使用约定 |
| --- | --- | --- |
| 语义值 | NoteDesign/Tokens.swift | 调整颜色、字号、留白、命中区、便签尺寸和动效时长时从这里改起 |
| 材质 | GlassSurface | 每张便签一层玻璃。组件统一处理系统版本与减少透明度 |
| 字体 | Tokens.TypeStyle、InkContent、InkEditor | 标题用 24 pt Medium，正文与编辑器用 19 pt Regular。中英文共用 macOS 系统字体与字形回退，控制信息使用系统语义字号 |
| 操作 | SymbolAction | 图标控件自带统一命中区、辅助功能标签和悬浮提示 |
| 完成 | InkDismissal、InkWipe | 仅对文字施加擦除遮罩；玻璃层固定，最后整体淡出。恢复动作取消待执行的关闭 |

产品名统一写作 **GlassNotes**。应用图标以青绿色为底，一片轻微倾斜的玻璃悬浮其上。偏移的投影拉开两层距离，炭黑色笔迹从左下起笔，掠过一高一低两道弧峰，向右下轻轻收细。菜单栏沿用同一笔迹，外加一圈 1.35 pt 的圆角细框。笔迹与边框共用 18 × 18 pt 单色模板，由系统适配亮暗背景和选中状态。图标原稿和打包资源见 [Packaging](../Packaging)。

桌面正文采用系统无衬线。标题靠字重和留白区分，笔迹质感集中在品牌图形与擦除动效上。应用通过系统 API 获取字体，随 macOS 选择适合语言的字形。若未来需要在多个平台固定中文排印，可评估 Noto Sans CJK SC；分发字体时须保留其版权声明与 SIL OFL 1.1 许可证。[Apple 字体指南](https://developer.apple.com/documentation/technologyoverviews/managing-the-fonts-for-your-app) · [Noto Sans CJK 官方许可](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE)

桌面便签统一使用 `Tokens.NoteGlass`。窗口采用 Dark Aqua，笔迹为瓷白色 #F3F7FC。全局透明度有三个基础预设和两个连续参数，由 `GlassSurface` 只作用于玻璃层。阅读、原位编辑和归档恢复共用此设置。

| 预设 | 材质强度 | 背景压暗 |
| --- | --- | --- |
| 通透 | macOS 26+ 为 50%，macOS 14–15 为 28% | 0% |
| 标准（默认） | 100% | 26% |
| 低透 | 100% | 62% |

桌面玻璃参考 Dock 的轮廓和透色。卡面使用 AppKit 的 HUD 材质和窗后模糊，连续圆角为 22 pt。边缘只有柔化的局部反光，窗口关闭系统投影。材质强度在 20%–100% 之间连续调节，中段使用缓出曲线增加模糊材质的占比。压暗独立叠加在整块卡面上。

桌面背景由固定为 `active` 的 AppKit 毛玻璃实时采样壁纸。模糊、边缘高光和压暗值均独立于输入焦点，保存或切换到另一张便签时保持一致。白色笔迹与操作图标独立于玻璃的材质强度。菜单栏面板与撤销提示在 macOS 26+ 继续使用原生 Liquid Glass。[Apple 材质活跃状态](https://developer.apple.com/documentation/appkit/nsvisualeffectview/state-swift.enum)

在「玻璃透明度」面板中，材质强度为 20% 到 100%，背景压暗为 0% 到 62%。显示值取整，存储值保留拖动精度。选择预设会恢复其两个初始值。开启系统「减少透明度」时使用实色，关闭后恢复此前的选择。

新增功能先查上表。标准系统按钮、菜单、选择器可以直接组合，专属的品牌外观和运动曲线归入 NoteDesign。评审时检查正文较长的卡片、亮暗背景、减少透明度、减少动态效果和键盘操作。
