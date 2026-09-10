import CoreGraphics
import Foundation
import LayoutCore

/// Overlay / Grid 会话期间截获按键，避免快捷键落到前台 App。
final class SessionTap: @unchecked Sendable {
    var onKey: ((UInt16, KeyModifiers) -> Void)?
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private let lock = NSLock()

    func start() throws {
        if port != nil { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: context
        ) else {
            throw OrdinoError.eventTapCreateFailed
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.port = port
        self.source = source
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.runTapLoop(ready: ready)
        }
        thread.name = "com.rayz2099.ordino.session-tap"
        self.thread = thread
        thread.start()
        ready.wait()
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func stop() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
        }
        lock.lock()
        let loop = runLoop
        lock.unlock()
        if let loop {
            CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) {
                CFRunLoopStop(loop)
            }
            CFRunLoopWakeUp(loop)
        }
        port = nil
        source = nil
        thread = nil
    }

    fileprivate func handle(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = KeyModifiers.from(cgFlags: event.flags)
        // Tap 回调必须立即返回；布局期间主线程会同步访问 AX，等待它会触发系统超时并丢掉下一次按键。
        DispatchQueue.main.async { [weak self] in
            self?.onKey?(keyCode, modifiers)
        }
        return nil
    }

    /// 独立 RunLoop 保证主线程执行窗口几何时，系统仍能及时投递并吞掉会话按键。
    private func runTapLoop(ready: DispatchSemaphore) {
        guard let source else {
            ready.signal()
            return
        }
        let loop = CFRunLoopGetCurrent()
        lock.lock()
        runLoop = loop
        lock.unlock()
        CFRunLoopAddSource(loop, source, .commonModes)
        ready.signal()
        CFRunLoopRun()
        CFRunLoopRemoveSource(loop, source, .commonModes)
        lock.lock()
        if runLoop === loop {
            runLoop = nil
        }
        lock.unlock()
    }
}

extension KeyModifiers {
    static func from(cgFlags flags: CGEventFlags) -> KeyModifiers {
        var result: KeyModifiers = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskControl) { result.insert(.control) }
        return result
    }

}

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let tap = Unmanaged<SessionTap>.fromOpaque(userInfo).takeUnretainedValue()
            if let port = tap.portForReenable() {
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<SessionTap>.fromOpaque(userInfo).takeUnretainedValue()
    return tap.handle(event)
}

extension SessionTap {
    fileprivate func portForReenable() -> CFMachPort? { port }
}
