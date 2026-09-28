import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    var onSettings: (() -> Void)?
    var onCheckUpdates: (() -> Void)?
    var onQuit: (() -> Void)?

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "Ordino")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "检查更新…", action: #selector(checkUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Ordino", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items {
            menuItem.target = self
        }
        item.menu = menu
    }

    @objc private func openSettings() {
        onSettings?()
    }

    @objc private func checkUpdates() {
        onCheckUpdates?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
