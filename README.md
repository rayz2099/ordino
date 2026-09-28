# Ordino

**Omnia suo loco. Every window in its place.**

Ordino is a fast, keyboard-first window manager for macOS. Arrange windows, move between displays, or pick a layout from the window’s green button.

## Quick Start

1. Open Ordino.
2. Allow Ordino in **System Settings → Privacy & Security → Accessibility**.
3. Press `⇧⌘M` to open the command panel.
4. Press a key below to arrange the current window.

| Key | Action |
| --- | --- |
| `H` / `J` / `K` / `L` | Left / bottom / top / right half |
| `Space` | Fill the current display |
| `Return` | Center the window |
| `Tab` / `⇧Tab` | Move to the next / previous display |
| `` ` `` | Restore the previous size and position |
| `1` / `2` | Use an imported custom layout |
| `Esc` | Close the command panel |

Arrow keys also work for half-screen layouts.

### Move Between Displays

Press `L` again when a window is already on the right half to move it to the left half of the display on the right. Press `H` again from the left half to move to the display on the left.

You can also press `Tab` to move a window between displays while keeping its size and position.

### Use the Mouse

Hover over a window’s green button, then choose a layout.

## Install and Updates

Download `Ordino-x.y.z.zip` from [GitHub Releases](https://github.com/rayz2099/ordino/releases/latest). Open the app once; the setup guide will copy it to `/Applications`, offer login at startup, and ask for Accessibility.

Ordino checks GitHub Releases daily and can install updates from the menu bar.

### Release (maintainers)

1. Set `VERSION` to the new semver (and the same `MARKETING_VERSION` in `project.yml`).
2. Commit, then tag `vX.Y.Z` and push the tag.
3. Store the Sparkle private key as repo secret `SPARKLE_PRIVATE_KEY` (the file is `.sparkle/eddsa` on the machine that generated the keypair).

## Privacy

Ordino works entirely on your Mac. It does not collect, upload, or share personal data. Accessibility permission is used only to find and arrange windows.

## License

Copyright 2026 rayz2099. Licensed under the [Apache License 2.0](LICENSE).

---

## 中文

**Omnia suo loco. 让每个窗口，各得其所。**

Ordino 是一款快捷、键盘优先的 macOS 窗口管理工具。你可以用键盘排列窗口、跨显示器移动，也可以从窗口的绿色按钮选择布局。

### 快速开始

1. 打开 Ordino。
2. 前往 **系统设置 → 隐私与安全性 → 辅助功能**，允许 Ordino。
3. 按 `⇧⌘M` 打开命令面板。
4. 按下列按键排列当前窗口。

| 按键 | 操作 |
| --- | --- |
| `H` / `J` / `K` / `L` | 左半 / 下半 / 上半 / 右半 |
| `Space` | 铺满当前显示器 |
| `Return` | 居中窗口 |
| `Tab` / `⇧Tab` | 移到下一块 / 上一块显示器 |
| `` ` `` | 恢复上一次大小和位置 |
| `1` / `2` | 使用已导入的自定义布局 |
| `Esc` | 关闭命令面板 |

方向键也可以完成半屏布局。

#### 跨显示器移动

窗口已经在右半屏时，再按一次 `L`，它会移到右侧显示器的左半屏。窗口已经在左半屏时，再按一次 `H`，它会移到左侧显示器的右半屏。

也可以按 `Tab`，在保持窗口大小和相对位置的同时切换显示器。

#### 使用鼠标

把鼠标停在窗口的绿色按钮上，然后选择布局。

### 安装与更新

从 [GitHub Releases](https://github.com/rayz2099/ordino/releases/latest) 下载 `Ordino-x.y.z.zip`。第一次打开会进入安装引导：复制到「应用程序」、开机自启、辅助功能权限。

之后 Ordino 每天检查一次 GitHub Releases，也可在菜单栏手动检查更新。

#### 发布（维护者）

1. 把 `VERSION` 改成新的语义化版本（同时改 `project.yml` 里的 `MARKETING_VERSION`）。
2. 提交后打 `vX.Y.Z` 标签并推送。
3. 把 Sparkle 私钥写入仓库密钥 `SPARKLE_PRIVATE_KEY`（生成本地密钥对后在 `.sparkle/eddsa`）。

### 隐私

Ordino 完全在本机运行，不收集、上传或共享个人数据。辅助功能权限只用于查找和排列窗口。

### 许可证

Copyright 2026 rayz2099。基于 [Apache License 2.0](LICENSE) 开源。
