import ApplicationServices
import AppKit
import LayoutCore

/// 前台窗口句柄。发现走 AX；AXSize 可写时改几何走 AX，否则走 WindowServer。
struct AXWindow {
    let element: AXUIElement

    var pid: pid_t {
        var value: pid_t = 0
        AXUIElementGetPid(element, &value)
        return value
    }

    var isOwnProcess: Bool {
        pid == getpid()
    }

    static func focused() throws -> AXWindow {
        try requireTrust()
        guard let running = NSWorkspace.shared.frontmostApplication else {
            throw OrdinoError.noFocusedWindow
        }
        return try best(in: running.processIdentifier)
    }

    static func at(axPoint point: CGPoint) throws -> AXWindow {
        try requireTrust()
        let system = AXUIElementCreateSystemWide()
        var found: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &found)
        if status != .success { throw OrdinoError.noWindowAtPoint }
        guard let found else { throw OrdinoError.noWindowAtPoint }
        return try AXWindow(element: try windowAncestor(found)).resolved()
    }

    var title: String {
        if let value = try? copyString(element, kAXTitleAttribute), !value.isEmpty {
            return value
        }
        return "无标题窗口"
    }

    func frame() throws -> PixelRect {
        let window = try resolved()
        if !CFEqual(window.element, element) {
            return try window.frame()
        }
        if try sizeIsSettable() {
            return try axFrame()
        }
        return try WindowServer.frame(of: try WindowServer.windowID(of: element))
    }

    /// 铺满后系统常把窗口标成 Zoomed，后续 AXSize 会直接拒写，所以写几何前必须先退出全屏/缩放。
    /// 先写成当前点还能放下的尺寸，再落到目标 origin，再按实际 origin 能放下的尺寸写，避免中心小窗 inflate 被卡。
    /// iTerm Hotkey 把 AXSize 标成只读，AX 写必失败；这类窗改走 WindowServer 形状，不走 AppleEvent。
    func setFrame(_ rect: PixelRect) throws {
        let window = try resolved()
        if !CFEqual(window.element, element) {
            try window.setFrame(rect)
            return
        }
        if isOwnProcess { throw OrdinoError.ownWindow }
        let integral = rect.integral
        if integral.width <= 0 || integral.height <= 0 {
            throw OrdinoError.setFailed(kAXSizeAttribute, .illegalArgument)
        }
        let app = AXUIElementCreateApplication(pid)
        let write = { try self.applyGeometry(integral) }
        // Chrome 开关 Enhanced UI 会重建页面，铺满后点击和键盘都进不了渲染进程。
        if isChromeApp {
            try write()
        } else {
            try withEnhancedUIDisabled(app, write)
        }
    }

    func greenButtonFrame() throws -> PixelRect {
        if let zoom = optionalElement(element, kAXZoomButtonAttribute) {
            return try buttonFrame(zoom)
        }
        if let fullScreen = optionalElement(element, kAXFullScreenButtonAttribute) {
            return try buttonFrame(fullScreen)
        }
        throw OrdinoError.noGreenButton
    }

    /// Chrome 的 HelpTag / 翻译条也是 AXWindow，而且 AXSize 只读；那些不是布局目标。
    func resolved() throws -> AXWindow {
        if isLiveLayoutWindow { return self }
        return try AXWindow.best(in: pid)
    }

    fileprivate var isAccessory: Bool {
        let role = optionalString(element, kAXRoleAttribute)
        if role == "AXHelpTag" { return true }
        if role != kAXWindowRole { return true }
        if optionalString(element, kAXSubroleAttribute) == kAXStandardWindowSubrole {
            return false
        }
        if optionalBool(element, kAXMainAttribute) == true {
            return false
        }
        var settable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        if status != .success {
            return false
        }
        return !settable.boolValue
    }

    private var isLiveLayoutWindow: Bool {
        if isAccessory { return false }
        var settable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        return status == .success
    }

    /// 同一进程里挑真正能布局的窗：先 focused / main，再标准窗口列表。
    static func best(in pid: pid_t) throws -> AXWindow {
        try requireTrust()
        let app = AXUIElementCreateApplication(pid)
        if let focused = optionalElement(app, kAXFocusedWindowAttribute) {
            let window = AXWindow(element: focused)
            if window.isLiveLayoutWindow { return window }
        }
        if let main = optionalElement(app, kAXMainWindowAttribute) {
            let window = AXWindow(element: main)
            if window.isLiveLayoutWindow { return window }
        }
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
        if status == .success, let list = raw as? [AXUIElement] {
            let windows = list.map { AXWindow(element: $0) }.filter(\.isLiveLayoutWindow)
            if let first = windows.first { return first }
        }
        throw OrdinoError.noFocusedWindow
    }

    private func buttonFrame(_ button: AXUIElement) throws -> PixelRect {
        let position = try copyPoint(button, kAXPositionAttribute)
        let size = try copySize(button, kAXSizeAttribute)
        return PixelRect(x: position.x, y: position.y, width: size.width, height: size.height)
    }

    private func axFrame() throws -> PixelRect {
        let position = try copyPoint(element, kAXPositionAttribute)
        let size = try copySize(element, kAXSizeAttribute)
        return PixelRect(x: position.x, y: position.y, width: size.width, height: size.height)
    }

    private func sizeIsSettable() throws -> Bool {
        var settable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        if status != .success {
            throw OrdinoError.setFailed(kAXSizeAttribute, status)
        }
        return settable.boolValue
    }

    private func writeGeometry(_ target: PixelRect) throws {
        let current = try axFrame()
        let currentArea = try DisplayMap.workArea(nearestTo: current)
        let targetArea = try DisplayMap.workArea(nearestTo: target)
        // Chrome 把工作区附近的窗锁成最大化，1pt 收缩仍算铺满，必须让出明显缺口才能再写下半/左半。
        let nearFill = abs(current.x - currentArea.x) < 4
            && abs(current.width - currentArea.width) < 4
            && abs(current.maxY - currentArea.maxY) < 4
        let shrinking = target.width + 8 < current.width || target.height + 8 < current.height
        if nearFill && shrinking {
            let gap = 64.0
            let unlocked = CGSize(
                width: min(current.width, max(target.width, current.width - gap)),
                height: min(current.height, max(target.height, current.height - gap))
            )
            try writeSize(unlocked)
        }
        let origin = try axFrame()
        let first = PixelRect(
            x: origin.x,
            y: origin.y,
            width: target.width,
            height: target.height
        ).clampedSize(to: currentArea)
        try writeSize(CGSize(width: first.width, height: first.height))
        try writePosition(CGPoint(x: target.x, y: target.y))
        let placed = try axFrame()
        let second = PixelRect(
            x: placed.x,
            y: placed.y,
            width: target.width,
            height: target.height
        ).clampedSize(to: targetArea)
        try writeSize(CGSize(width: second.width, height: second.height))
        try writePosition(CGPoint(x: target.x, y: target.y))
    }

    private var isChromeApp: Bool {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier?.hasPrefix("com.google.Chrome") == true
    }

    private var isStandardWindow: Bool {
        optionalString(element, kAXSubroleAttribute) == kAXStandardWindowSubrole
    }

    /// AXSize 可写时不能清 Zoomed：系统的异步还原会覆盖刚写入的矩形，导致连续布局漂移。
    /// 只有 AXSize 已只读才退出全屏/缩放；标准窗仍禁止走 WindowServer，避免命中区域与画面分离。
    private func applyGeometry(_ integral: PixelRect) throws {
        if try sizeIsSettable() {
            try writeGeometry(integral)
            return
        }
        clearFullscreenAndZoom()
        if isStandardWindow {
            if try sizeIsSettable() {
                try writeGeometry(integral)
                return
            }
            pressZoomButton()
            if try sizeIsSettable() {
                try writeGeometry(integral)
                return
            }
            throw OrdinoError.notResizable
        }
        try WindowServer.setFrame(integral, of: try WindowServer.windowID(of: element))
    }

    /// 这两个属性不是每扇窗都有；没有就保持现状，有且为 true 才关掉。
    private func clearFullscreenAndZoom() {
        clearBoolAttribute("AXFullScreen")
        clearBoolAttribute("AXZoomed")
    }

    private func pressZoomButton() {
        guard let zoom = optionalElement(element, kAXZoomButtonAttribute) else { return }
        AXUIElementPerformAction(zoom, kAXPressAction as CFString)
    }

    private func clearBoolAttribute(_ attribute: String) {
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &raw)
        if status != .success { return }
        if (raw as? Bool) == true {
            AXUIElementSetAttributeValue(element, attribute as CFString, kCFBooleanFalse)
        }
    }

    private func writePosition(_ point: CGPoint) throws {
        var value = point
        guard let encoded = AXValueCreate(.cgPoint, &value) else {
            throw OrdinoError.setFailed(kAXPositionAttribute, .failure)
        }
        try setValue(element, kAXPositionAttribute, encoded)
    }

    private func writeSize(_ size: CGSize) throws {
        var settable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        if settableStatus == .success && !settable.boolValue {
            throw OrdinoError.notResizable
        }
        var value = size
        guard let encoded = AXValueCreate(.cgSize, &value) else {
            throw OrdinoError.setFailed(kAXSizeAttribute, .failure)
        }
        try setValue(element, kAXSizeAttribute, encoded)
    }
}

private func requireTrust() throws {
    if !AXPermission.isTrusted() { throw OrdinoError.accessibilityDenied }
}

/// Enhanced UI 会让 AXSize 写成动画/拒绝，必须在写几何期间关掉。
private func withEnhancedUIDisabled(_ app: AXUIElement, _ body: () throws -> Void) throws {
    let key = "AXEnhancedUserInterface" as CFString
    var raw: CFTypeRef?
    let readStatus = AXUIElementCopyAttributeValue(app, key, &raw)
    let wasEnabled = readStatus == .success && (raw as? Bool) == true
    if wasEnabled {
        AXUIElementSetAttributeValue(app, key, kCFBooleanFalse)
    }
    defer {
        if wasEnabled {
            AXUIElementSetAttributeValue(app, key, kCFBooleanTrue)
        }
    }
    try body()
}

private func copyElement(_ element: AXUIElement, _ attribute: String) throws -> AXUIElement {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { throw OrdinoError.attributeMissing(attribute) }
    guard let window = value else { throw OrdinoError.attributeMissing(attribute) }
    return (window as! AXUIElement)
}

private func copyString(_ element: AXUIElement, _ attribute: String) throws -> String {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { throw OrdinoError.attributeMissing(attribute) }
    guard let string = value as? String else { throw OrdinoError.attributeMissing(attribute) }
    return string
}

private func optionalString(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { return nil }
    return value as? String
}

private func optionalBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { return nil }
    return value as? Bool
}

private func copyPoint(_ element: AXUIElement, _ attribute: String) throws -> CGPoint {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { throw OrdinoError.attributeMissing(attribute) }
    guard let axValue = value else { throw OrdinoError.attributeMissing(attribute) }
    var point = CGPoint.zero
    if !AXValueGetValue(axValue as! AXValue, .cgPoint, &point) {
        throw OrdinoError.attributeMissing(attribute)
    }
    return point
}

private func copySize(_ element: AXUIElement, _ attribute: String) throws -> CGSize {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { throw OrdinoError.attributeMissing(attribute) }
    guard let axValue = value else { throw OrdinoError.attributeMissing(attribute) }
    var size = CGSize.zero
    if !AXValueGetValue(axValue as! AXValue, .cgSize, &size) {
        throw OrdinoError.attributeMissing(attribute)
    }
    return size
}

private func setValue(_ element: AXUIElement, _ attribute: String, _ value: CFTypeRef) throws {
    let status = AXUIElementSetAttributeValue(element, attribute as CFString, value)
    if status != .success {
        throw OrdinoError.setFailed(attribute, status)
    }
}

private func windowAncestor(_ element: AXUIElement) throws -> AXUIElement {
    var current = element
    for _ in 0..<8 {
        let role = try copyString(current, kAXRoleAttribute)
        if role == kAXWindowRole || role == "AXHelpTag" {
            let window = AXWindow(element: current)
            if window.isAccessory {
                return try AXWindow.best(in: window.pid).element
            }
            return current
        }
        current = try copyElement(current, kAXParentAttribute)
    }
    throw OrdinoError.noWindowAtPoint
}

private func optionalElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if status != .success { return nil }
    guard let value else { return nil }
    return (value as! AXUIElement)
}
