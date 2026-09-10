import Carbon
import Foundation
import LayoutCore

/// 全局热键必须能吞键，所以走 Carbon RegisterEventHotKey，而不是 NSEvent 监视器。
final class HotKeyCenter: @unchecked Sendable {
    private var handlerRef: EventHandlerRef?
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private let signature: OSType = 0x50414E45

    init() throws {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &spec,
            context,
            &handlerRef
        )
        if status != noErr { throw OrdinoError.hotKeyRegisterFailed }
    }

    deinit {
        clear()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    /// 只注册 Overlay；其余键位仅在 Overlay Session 内生效，避免抢占宿主应用。
    func replace(overlay: HotKeySpec, overlayHandler: @escaping () -> Void) throws {
        clear()
        try register(id: 1, spec: overlay, handler: overlayHandler)
    }

    private func register(id: UInt32, spec: HotKeySpec, handler: @escaping () -> Void) throws {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(spec.keyCode),
            spec.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status != noErr { throw OrdinoError.hotKeyRegisterFailed }
        guard let ref else { throw OrdinoError.hotKeyRegisterFailed }
        hotKeys[id] = ref
        callbacks[id] = handler
    }

    fileprivate func invoke(id: UInt32) {
        callbacks[id]?()
    }

    private func clear() {
        for (_, ref) in hotKeys {
            UnregisterEventHotKey(ref)
        }
        hotKeys.removeAll()
        callbacks.removeAll()
    }
}

private func hotKeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    if status != noErr { return status }
    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        center.invoke(id: hotKeyID.id)
    }
    return noErr
}
