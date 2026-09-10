# Swift：AppKit 做热路径，SwiftUI 做 Settings，布局计算放纯领域模块

macOS 上 Overlay、全局 Hot Key、红绿灯悬停都走 Accessibility 与事件点，必须落在 AppKit。Settings 用 SwiftUI `Form`。Relative Frame / Layout Action / Overlay Session 放无 UI 模块，禁止从领域核 import AppKit。

不选 Kotlin Native：最终仍要手写同一套 ObjC 桥，只换语法。不选 Electron/Tauri：做不了 Mouse Control。不选 Hammerspoon：不是可分发 App。
