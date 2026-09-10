import AppKit

/// LSUIElement 入口。不能走普通文档 App 生命周期，否则会抢前台窗口。
@main
enum OrdinoMain {
    nonisolated(unsafe) static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        OrdinoMain.delegate = delegate
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: OrdinoRuntime?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let runtime = OrdinoRuntime()
        self.runtime = runtime
        runtime.start()
    }
}
