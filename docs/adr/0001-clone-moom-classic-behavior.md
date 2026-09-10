# 复刻 Moom Classic 的行为，而不是换工具或升级 Moom 4

本机 Moom Classic 3.2.30 在 macOS 26 上已被系统判为 damaged，官方不再更新这条线。决定自研一个行为等价物，而不是购买 Moom 4、映射到 Raycast/Rectangle，或改用 AeroSpace/yabai。

Moom 4 能恢复本机使用，但锁死 macOS 且没有所有权。Rectangle/Raycast 没有 Overlay 模态面。AeroSpace/yabai 是平铺世界观，会打断现有 `⇧⌘M` + `⌘1`/`⌘2` 相对布局习惯。跨平台只复用 Relative Frame / Custom Control / Overlay 这套领域模型，OS 窗口操作走适配器。
