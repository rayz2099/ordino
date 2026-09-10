import Foundation

/// Overlay Session 内的一次按键解释结果。会话外的全局 Hot Key 不走这里。
public enum OverlayCommand: Equatable, Sendable {
    case apply(LayoutAction)
    case custom(id: String)
    case openGrid
    case dismiss
}

/// Classic Overlay 的键位契约：方向键切半屏，空格铺满，回车居中。HJKL 同构，单键数字走 Custom Control。
public struct OverlayMap: Sendable {
    public var overlayHotKey: HotKeySpec
    public var controls: [CustomControl]

    public init(overlayHotKey: HotKeySpec, controls: [CustomControl]) {
        self.overlayHotKey = overlayHotKey
        self.controls = controls
    }

    public func command(keyCode: UInt16, modifiers: KeyModifiers) -> OverlayCommand? {
        if keyCode == overlayHotKey.keyCode && modifiers == overlayHotKey.modifiers {
            return .openGrid
        }
        if keyCode == HardwareKey.escape {
            return .dismiss
        }
        if keyCode == HardwareKey.returnKey {
            return .apply(.center)
        }
        if keyCode == HardwareKey.space {
            return .apply(.fill)
        }
        if keyCode == HardwareKey.grave {
            return .apply(.restorePrevious)
        }
        if keyCode == HardwareKey.tab {
            let step: DisplayStep = modifiers.contains(.shift) ? .previous : .next
            return .apply(.moveToDisplay(step))
        }

        let edge = Self.edge(for: keyCode)
        if let edge {
            if modifiers.contains(.command) {
                return .apply(.moveToEdge(edge))
            }
            if keyCode == HardwareKey.h || keyCode == HardwareKey.l {
                return .apply(.traverseHalf(edge))
            }
            return .apply(.half(edge))
        }

        if modifiers.isEmpty, let control = controls.first(where: { $0.overlayDigit == keyCode }) {
            return .custom(id: control.id)
        }
        return nil
    }

    private static func edge(for keyCode: UInt16) -> Edge? {
        switch keyCode {
        case HardwareKey.left, HardwareKey.h: return .left
        case HardwareKey.right, HardwareKey.l: return .right
        case HardwareKey.up, HardwareKey.k: return .top
        case HardwareKey.down, HardwareKey.j: return .bottom
        default: return nil
        }
    }
}
