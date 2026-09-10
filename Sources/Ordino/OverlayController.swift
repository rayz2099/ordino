import AppKit
import SwiftUI
import LayoutCore

/// 非激活面板：前台窗口保持焦点，按键由 SessionTap 吞掉。
@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private var host: NSHostingView<OverlayView>?

    var isVisible: Bool { panel?.isVisible == true }

    func show(title: String, controls: [CustomControl], overlayHotKey: HotKeySpec, around windowFrame: PixelRect) throws {
        let view = OverlayView(title: title, hints: OverlayHints.make(controls: controls, overlayHotKey: overlayHotKey))
        let hosting: NSHostingView<OverlayView>
        if let host {
            host.rootView = view
            hosting = host
        } else {
            hosting = NSHostingView(rootView: view)
            host = hosting
        }
        hosting.frame = NSRect(x: 0, y: 0, width: 272, height: 300)
        let size = hosting.fittingSize

        let cocoa = try DisplayMap.cocoaRect(fromAX: windowFrame)
        let screen = NSScreen.screens.max { a, b in
            overlap(a.frame, cocoa) < overlap(b.frame, cocoa)
        }
        let vis = screen?.visibleFrame ?? cocoa
        var origin = CGPoint(
            x: cocoa.midX - size.width / 2,
            y: cocoa.midY - size.height / 2
        )
        origin.x = min(max(origin.x, vis.minX + 8), max(vis.minX + 8, vis.maxX - size.width - 8))
        origin.y = min(max(origin.y, vis.minY + 8), max(vis.minY + 8, vis.maxY - size.height - 8))

        let panel = makePanel()
        // 铺满后的 Chrome 会把 stationary 面板留在原 Space，命令面必须能跟着窗走。
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.level = .popUpMenu
        panel.setContentSize(size)
        hosting.frame = NSRect(origin: .zero, size: size)
        if panel.contentView !== hosting {
            panel.contentView = hosting
        }
        panel.setFrameOrigin(origin)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 272, height: 300),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Chrome 铺满会盖住 statusBar 面板，命令面必须高于普通窗口且不随 Space 被挤走。
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        return panel
    }
}

private func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let x = max(0, min(a.maxX, b.maxX) - max(a.minX, b.minX))
    let y = max(0, min(a.maxY, b.maxY) - max(a.minY, b.minY))
    return x * y
}
