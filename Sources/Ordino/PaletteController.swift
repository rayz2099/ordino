import AppKit
import SwiftUI
import LayoutCore

/// 悬停绿色缩放按钮才弹出。没有绿钮就保持静默，不改挂到关闭按钮上。
@MainActor
final class PaletteController {
    var onPick: ((AXWindow, LayoutAction) -> Void)?
    private var panel: NSPanel?
    private var host: NSHostingView<PaletteView>?
    private var monitor: Any?
    private var dwell: DispatchWorkItem?
    private var activeWindow: AXWindow?
    private var buttonRect: PixelRect?
    private var panelRect: NSRect = .zero
    private var items: [PaletteItem] = []

    func start(controls: [CustomControl]) {
        items = PaletteItems.make(controls: controls)
        stopMonitor()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.mouseMoved()
            }
        }
    }

    func stop() {
        stopMonitor()
        hide()
    }

    func update(controls: [CustomControl]) {
        items = PaletteItems.make(controls: controls)
    }

    private func stopMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func mouseMoved() {
        if !AXPermission.isTrusted() {
            hide()
            return
        }
        let cocoa = NSEvent.mouseLocation
        let ax: CGPoint
        do {
            ax = try DisplayMap.axPoint(fromCocoa: cocoa)
        } catch {
            hide()
            return
        }
        if panel?.isVisible == true, panelRect.insetBy(dx: -8, dy: -8).contains(cocoa) {
            return
        }
        if let buttonRect, buttonRect.contains(x: ax.x, y: ax.y) {
            return
        }
        dwell?.cancel()
        do {
            let window = try AXWindow.at(axPoint: ax)
            // Settings 也有绿钮，弹 palette 会把 AXSize 写到 Ordino 自己身上。
            if window.isOwnProcess {
                hide()
                return
            }
            let green = try window.greenButtonFrame()
            if green.contains(x: ax.x, y: ax.y) {
                let work = DispatchWorkItem { [weak self] in
                    self?.show(window: window, button: green)
                }
                dwell = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
                return
            }
        } catch {
            hide()
            return
        }
        hide()
    }

    private func show(window: AXWindow, button: PixelRect) {
        activeWindow = window
        buttonRect = button
        let view = PaletteView(items: items) { [weak self] action in
                guard let self, let target = self.activeWindow else { return }
                self.onPick?(target, action)
                self.hide()
            }
        let hosting: NSHostingView<PaletteView>
        if let host {
            host.rootView = view
            hosting = host
        } else {
            hosting = NSHostingView(rootView: view)
            host = hosting
        }
        let size = hosting.fittingSize
        let cocoaButton: CGRect
        do {
            cocoaButton = try DisplayMap.cocoaRect(fromAX: button)
        } catch {
            hide()
            return
        }
        let screen = NSScreen.screens.max { lhs, rhs in
            intersectionArea(lhs.frame, cocoaButton) < intersectionArea(rhs.frame, cocoaButton)
        }
        let visible = screen?.visibleFrame ?? cocoaButton
        var origin = CGPoint(x: cocoaButton.minX, y: cocoaButton.minY - size.height - 6)
        if origin.y < visible.minY {
            origin.y = cocoaButton.maxY + 6
        }
        origin.x = min(max(origin.x, visible.minX + 8), max(visible.minX + 8, visible.maxX - size.width - 8))
        origin.y = min(max(origin.y, visible.minY + 8), max(visible.minY + 8, visible.maxY - size.height - 8))
        let panel = makePanel()
        hosting.frame = NSRect(origin: .zero, size: size)
        if panel.contentView !== hosting {
            panel.contentView = hosting
        }
        panel.setContentSize(size)
        panel.setFrameOrigin(origin)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        panelRect = NSRect(origin: origin, size: size)
        self.panel = panel
    }

    private func hide() {
        dwell?.cancel()
        panel?.orderOut(nil)
        activeWindow = nil
        buttonRect = nil
    }

    private func makePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 44),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}

private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
    let intersection = lhs.intersection(rhs)
    return intersection.isNull ? 0 : intersection.width * intersection.height
}
