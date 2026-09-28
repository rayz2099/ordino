import AppKit
import SwiftUI
import LayoutCore

/// 把四个命令面接到同一个 LayoutApplier。UI 不得自己改窗口几何。
@MainActor
final class OrdinoRuntime: ObservableObject {
    @Published var config: AppConfig
    @Published var axTrusted = false
    @Published var recordingOverlay = false
    @Published var lastError: String?
    @Published var loginEnabled = false
    @Published var autoCheck = true

    let updates = UpdateCenter()
    private let store = ConfigStore()
    private let applier = LayoutApplier()
    private let overlay = OverlayController()
    private let palette = PaletteController()
    private let grid = GridController()
    private let tap = SessionTap()
    private var hotKeys: HotKeyCenter?
    private var status: StatusItemController?
    private var settingsWindow: NSWindow?
    private var setup: SetupController?
    private var recordMonitor: Any?
    private var overlayTarget: AXWindow?
    /// Chrome 铺满后系统可能把 overlay 面板藏掉；会话不能跟 isVisible 绑死，否则后续方向键会落到 Chrome。
    private var overlaySession = false
    private var frontmostObserver: NSObjectProtocol?
    private var trustObserver: NSObjectProtocol?

    init() {
        do {
            config = try store.load()
        } catch {
            lastError = error.localizedDescription
            config = AppConfig()
        }
    }

    func start() {
        status = StatusItemController()
        status?.onSettings = { [weak self] in self?.openSettings() }
        status?.onCheckUpdates = { [weak self] in self?.checkForUpdates() }
        status?.onQuit = { NSApp.terminate(nil) }
        refreshLogin()
        autoCheck = updates.autoCheck
        if SetupGate.shouldPresent {
            presentSetup()
        }
        palette.onPick = { [weak self] window, action in
            self?.perform(action, on: window)
        }
        grid.onApply = { [weak self] frame in
            self?.perform(.moveZoom(frame), on: self?.overlayTarget)
            self?.closeSessions()
        }
        grid.onCancel = { [weak self] in
            self?.closeSessions()
        }
        tap.onKey = { [weak self] code, modifiers in
            _ = self?.handleSessionKey(code: code, modifiers: modifiers)
        }
        applier.onAnimationFinished = { [weak self] in
            guard let self else { return }
            self.lastError = nil
            if self.overlaySession {
                self.followOverlay()
            }
        }
        applier.onAnimationError = { [weak self] error in
            self?.present(error)
        }
        watchFrontmost()
        watchTrust()
        refreshPermission()
        installHotKeys()
        syncPalette()
    }

    func presentSetup() {
        if setup == nil {
            let controller = SetupController()
            controller.onFinished = { [weak self] in
                self?.setup = nil
            }
            setup = controller
        }
        setup?.show(runtime: self)
    }

    func checkForUpdates() {
        updates.check()
    }

    func setAutoCheck(_ enabled: Bool) {
        updates.autoCheck = enabled
        autoCheck = enabled
    }

    func refreshLogin() {
        loginEnabled = LoginItem.isEnabled
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            refreshLogin()
        } catch {
            present(error)
        }
    }

    func installToApps() {
        do {
            SetupGate.markResume()
            try AppInstall.install()
            Task { [weak self] in
                do {
                    try await AppInstall.relaunch()
                    NSApp.terminate(nil)
                } catch {
                    self?.present(error)
                }
            }
        } catch {
            present(error)
        }
    }

    func requestPermission() {
        AXPermission.prompt()
        refreshPermission()
    }

    func refreshPermission() {
        axTrusted = AXPermission.isTrusted()
    }

    func openSettings() {
        refreshPermission()
        applier.captureFrontmost()
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Ordino"
            window.tabbingMode = .disallowed
            window.minSize = NSSize(width: 480, height: 500)
            window.contentView = NSHostingView(rootView: SettingsView(runtime: self))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func updateOverlayHotKey(_ spec: HotKeySpec) {
        config.overlayHotKey = spec
        recordingOverlay = false
        persistAndRebind()
    }

    func setMouseControl(_ enabled: Bool) {
        config.mouseControlEnabled = enabled
        persistAndRebind()
        syncPalette()
    }

    func setGridEnabled(_ enabled: Bool) {
        config.gridEnabled = enabled
        persistAndRebind()
    }

    func setGridSize(columns: Int, rows: Int) {
        config.gridColumns = columns
        config.gridRows = rows
        persistAndRebind()
    }

    func reimportMoom() {
        config = store.importFromMoom()
        persistAndRebind()
        syncPalette()
    }

    func beginRecordingOverlay() {
        recordingOverlay = true
        if let recordMonitor {
            NSEvent.removeMonitor(recordMonitor)
        }
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.captureHotKey(event)
            return nil
        }
    }

    private func captureHotKey(_ event: NSEvent) {
        if event.keyCode == HardwareKey.escape {
            recordingOverlay = false
            clearRecordMonitor()
            return
        }
        let spec = HotKeySpec(keyCode: event.keyCode, modifiers: KeyModifiers.from(event: event))
        updateOverlayHotKey(spec)
        clearRecordMonitor()
    }

    private func clearRecordMonitor() {
        if let recordMonitor {
            NSEvent.removeMonitor(recordMonitor)
        }
        recordMonitor = nil
    }

    private func installHotKeys() {
        do {
            if hotKeys == nil {
                hotKeys = try HotKeyCenter()
            }
            try hotKeys?.replace(
                overlay: config.overlayHotKey,
                overlayHandler: { [weak self] in self?.toggleOverlay() }
            )
        } catch {
            present(error)
        }
    }

    private func persistAndRebind() {
        do {
            try store.save(config)
        } catch {
            present(error)
        }
        installHotKeys()
    }

    private func syncPalette() {
        if config.mouseControlEnabled {
            palette.start(controls: config.customControls)
        } else {
            palette.stop()
        }
    }

    private func toggleOverlay() {
        refreshPermission()
        if !axTrusted {
            AXPermission.prompt()
            openSettings()
            return
        }
        if overlaySession {
            if config.gridEnabled {
                openGridFromOverlay()
            } else if overlay.isVisible {
                closeSessions()
            } else {
                followOverlay()
            }
            return
        }
        if grid.isVisible {
            closeSessions()
            return
        }
        do {
            let window = try applier.targetWindow()
            overlayTarget = window
            overlaySession = true
            try overlay.show(
                title: window.title,
                controls: config.customControls,
                overlayHotKey: config.overlayHotKey,
                around: window.frame()
            )
            try tap.start()
        } catch {
            overlaySession = false
            overlayTarget = nil
            present(error)
        }
    }

    private func openGridFromOverlay() {
        overlay.hide()
        do {
            let window: AXWindow
            if let overlayTarget, !overlayTarget.isOwnProcess {
                window = overlayTarget
            } else {
                window = try applier.targetWindow()
            }
            overlayTarget = window
            let area = try DisplayMap.workArea(containing: window.frame())
            try grid.show(workArea: area, columns: config.gridColumns, rows: config.gridRows)
            try tap.start()
        } catch {
            present(error)
        }
    }

    private func handleSessionKey(code: UInt16, modifiers: KeyModifiers) -> Bool {
        if grid.isVisible {
            return grid.handleKey(code: code, modifiers: modifiers)
        }
        if overlaySession {
            let map = OverlayMap(overlayHotKey: config.overlayHotKey, controls: config.customControls)
            guard let command = map.command(keyCode: code, modifiers: modifiers) else {
                return true
            }
            switch command {
            case .dismiss:
                closeSessions()
            case .openGrid:
                if config.gridEnabled {
                    openGridFromOverlay()
                } else {
                    closeSessions()
                }
            case .apply(let action):
                scheduleLayout(action)
            case .custom(let id):
                scheduleCustom(id: id)
            }
            return true
        }
        return false
    }

    /// AX 写几何不能堵在 Event Tap 回调里，否则铺满会拖垮 Event Tap，后续命令无法连续执行。
    private func scheduleLayout(_ action: LayoutAction) {
        let target = overlayTarget
        DispatchQueue.main.async { [weak self] in
            guard let self, self.overlaySession else { return }
            self.perform(action, on: target)
        }
    }

    private func scheduleCustom(id: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.overlaySession else { return }
            self.runCustom(id: id)
        }
    }

    private func runCustom(id: String) {
        guard let control = config.customControls.first(where: { $0.id == id }) else {
            present(OrdinoError.attributeMissing("Custom Control"))
            return
        }
        perform(control.action, on: overlayTarget)
    }

    private func perform(_ action: LayoutAction, on window: AXWindow?) {
        do {
            let target: AXWindow
            if let window, !window.isOwnProcess {
                target = try window.resolved()
            } else {
                target = try applier.targetWindow()
            }
            overlayTarget = target
            try applier.apply(action, to: target)
            lastError = nil
        } catch {
            present(error)
        }
    }

    /// TCC 授权变更不会立刻反映到 AXIsProcessTrusted，必须听系统通知再读一次。
    private func watchTrust() {
        if trustObserver != nil { return }
        trustObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.refreshPermission()
            }
        }
    }

    /// 前台切到别的 App 时记下窗口，避免 Settings 成为 AX 目标。
    private func watchFrontmost() {
        if frontmostObserver != nil { return }
        frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applier.captureFrontmost()
            }
        }
        applier.captureFrontmost()
    }

    /// Overlay 一次会话要能连续听键：⇧⌘M → 左 → 右，不能每步都重新唤起。
    private func followOverlay() {
        guard overlaySession, let current = overlayTarget else { return }
        do {
            let window = try current.resolved()
            overlayTarget = window
            try overlay.show(
                title: window.title,
                controls: config.customControls,
                overlayHotKey: config.overlayHotKey,
                around: window.frame()
            )
        } catch {
            present(error)
        }
    }

    private func closeSessions() {
        overlaySession = false
        overlay.hide()
        grid.hide()
        tap.stop()
        overlayTarget = nil
    }

    private func present(_ error: Error) {
        lastError = error.localizedDescription
        NSSound.beep()
        NSLog("Ordino error: %@", error.localizedDescription)
    }
}


extension KeyModifiers {
    static func from(event: NSEvent) -> KeyModifiers {
        var result: KeyModifiers = []
        if event.modifierFlags.contains(.command) { result.insert(.command) }
        if event.modifierFlags.contains(.shift) { result.insert(.shift) }
        if event.modifierFlags.contains(.option) { result.insert(.option) }
        if event.modifierFlags.contains(.control) { result.insert(.control) }
        return result
    }
}
