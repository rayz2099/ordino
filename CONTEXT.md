# Ordino

本上下文描述「窗口相对布局」领域：把前台窗口放到某块显示器可用区域上。产品目标是行为等价于 Moom Classic，皮肤用系统原生控件画到能用，不复刻 Moom 的视觉和商标。v1 只交付 macOS。

## Language

**Window**:
当前被操作的操作系统窗口，一次命令只作用一个目标窗口。
_Avoid_: App, view, screen

**Display**:
一块物理显示器上的可用工作区（扣除菜单栏、Dock 后的矩形），是布局计算的坐标系，不是屏幕像素全集。
_Avoid_: Screen, monitor, desktop

**Relative Frame**:
Display 可用工作区上的归一化矩形，原点左上，范围 `[0,1]`。例如左 2/3 为 `{{0,0},{0.666,1}}`。
_Avoid_: Pixel frame, tile, snap region

**Layout Action**:
对目标 Window 施加的一次几何变换：落到某个 Relative Frame、居中、移到另一块 Display，或按增量移动/缩放。
_Avoid_: Shortcut, command, snap

**Custom Control**:
用户定义的 Layout Action，可在 Overlay 内绑定单键。本机已有：`1` → 左 2/3，`2` → 右 1/3。
_Avoid_: Macro, preset, snippet

**Overlay**:
由 Hot Key 唤起的模态键盘命令面（本机为 `⇧⌘M`）。它是一块紧贴目标窗口的系统材质面板，不是网页式 HUD。
_Avoid_: Palette, HUD, cheatsheet, launcher

**Overlay Session**:
从 Overlay 出现到关闭的一次模态会话。会话内按键只解释为 Layout Action，不落到当前应用。
方向布局以 HHKB/Vim 的裸 `H/J/K/L` 为主，方向键为兼容入口，不要求额外修饰键。
_Avoid_: Focus, grab, capture

**Hot Key**:
打开 Overlay 的全局快捷键。所有布局键位仅在 Overlay Session 内生效；Custom Control 暂不注册全局快捷键，避免 `⌘数字` 抢占宿主应用 Keymap。
_Avoid_: Shortcut, binding, accelerator

**Mouse Control**:
悬停在窗口红绿灯「放大」按钮上弹出的鼠标命令面，用于点选布局。与 Overlay 是同一套 Layout Action 的另一条入口。
_Avoid_: Zoom button menu, tooltip

**Grid**:
把 Display 切成单元格后，用拖拽画出 Relative Frame 的鼠标命令面。本机 Moom Classic 中 Grid 为关闭。
_Avoid_: Tiling, cell, mosaic

**Settings**:
配置 Custom Control、Hot Key、Overlay 与 Mouse Control 的系统设置窗口。不是布局命令面。
_Avoid_: Preferences, dashboard, admin
