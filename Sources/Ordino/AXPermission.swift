import ApplicationServices
import AppKit

/// Accessibility 是窗口几何热路径的唯一许可。没有它就不得调用 AX。
enum AXPermission {
    static func isTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    /// 只在用户点「请求权限」或真正要用 AX 时弹出。启动时弹会把已授权的旧条目和当前签名对不上。
    static func prompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
