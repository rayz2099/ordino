import AppKit
import SwiftUI

/// 引导必须是独立窗口：LSUIElement 没有 Dock，关了设置就再也找不到入口。
@MainActor
final class SetupController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    var onFinished: (() -> Void)?

    func show(runtime: OrdinoRuntime) {
        if window == nil {
            let view = SetupView(runtime: runtime) { [weak self] in
                self?.close()
            }
            let hosted = NSHostingView(rootView: view)
            let frame = NSRect(x: 0, y: 0, width: 480, height: 360)
            let window = NSWindow(
                contentRect: frame,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Ordino"
            window.tabbingMode = .disallowed
            window.contentView = hosted
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onFinished?()
    }

    private func close() {
        window?.delegate = nil
        window?.close()
        onFinished?()
    }
}
