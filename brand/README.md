# Ordino brand kit

**Omnia suo loco. Every window in its place.**  
**让每个窗口，各得其所。**

拉丁语 ōrdinō = 「我来安排」。标志是三块已经就位的窗口：左边主窗 + 右边上下两块。不是 2×2 宫格，避免和 Rectangle / Magnet 撞车。

## 色板

| 名称 | Hex | 用途 |
| --- | --- | --- |
| Forest | `#163A32` | 标志主体 |
| Forest deep | `#1E5246 → #102821` | App icon 背景 |
| Cream | `#F3EEE4` | 窗口 |
| Cream dim | `#D4CBBE` | 未聚焦窗口 |
| Leaf | `#2FA36B` | 强调色（右下格 / 绿点） |
| Ink | `#1C1C1E` | 深色文字 |

## 用哪一个文件

| 场景 | 文件 | 说明 |
| --- | --- | --- |
| GitHub README / 文档 / 官网 | `svg/mark.svg` 或 `svg/mark-adaptive.svg` | 主稿是 SVG |
| GitHub 头像 / 社交预览 | `svg/mark-contained.svg` | 带圆角底 |
| 字标 | `svg/wordmark.svg` | 标志 + Ordino |
| macOS Dock / Finder / Launchpad | `png/appicon-1024.png` | 正方形，**不要自己切圆角** |
| 菜单栏 | `svg/menubar.svg` | 18pt 黑色 template，系统会染色 |
| Favicon | `svg/favicon.svg` | 可跟随浅色 / 深色模式 |

## 格式：不要二选一

2026 年的标准做法是 **SVG 做品牌主稿，栅格按需导出**：

1. **品牌 / README / 网页：一份 SVG 就够。** 无限缩放，文件小，能做 dark mode。
2. **原生 macOS App Icon 不能只用 SVG。** 把 `appicon-1024.png` 丢进 Xcode `Assets.xcassets` 或 Icon Composer，系统生成 16 / 32 / 64 / 128 / 256 / 512 / 1024。也可以再打一份 `.icns`。
3. **菜单栏要单独一枚单色 template**（18×18 @1x / 36×36 @2x），不要直接拿彩色 App Icon 缩小。
4. **Favicon：** SVG + 32 PNG 兜底。

源文件只维护 SVG。PNG 全部从 SVG 导出，不要手绘每一档尺寸。

## App icon 注意

- 画布必须是正方形，系统会套 squircle 蒙版。
- 不要把「Ordino」字写进图标。
- 不要画完整的红黄绿三色交通灯；大尺寸最多保留一颗绿点，点题「从绿色按钮选布局」。
- 16px 只保留三块窗格剪影即可。

## 许可

标志为 Ordino 项目（Apache-2.0）配套设计，可随仓库使用。
