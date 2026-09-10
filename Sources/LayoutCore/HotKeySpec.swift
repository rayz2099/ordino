import Foundation

/// 与具体事件 API 无关的修饰键集合。导入 Moom 时再把 Carbon / NSEvent 两种位域解码进来。
public struct KeyModifiers: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let shift = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let control = KeyModifiers(rawValue: 1 << 3)

    public var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= 256 }
        if contains(.shift) { flags |= 512 }
        if contains(.option) { flags |= 2048 }
        if contains(.control) { flags |= 4096 }
        return flags
    }

    public var symbolText: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }

    /// Moom plist 同时出现过 Carbon（cmdKey=256）和 NSEvent（command=1<<20）两种写法。
    public static func decodingMoom(_ flags: Int) -> KeyModifiers {
        var result: KeyModifiers = []
        if flags & 256 != 0 { result.insert(.command) }
        if flags & 512 != 0 { result.insert(.shift) }
        if flags & 2048 != 0 { result.insert(.option) }
        if flags & 4096 != 0 { result.insert(.control) }
        if flags & (1 << 20) != 0 { result.insert(.command) }
        if flags & (1 << 17) != 0 { result.insert(.shift) }
        if flags & (1 << 19) != 0 { result.insert(.option) }
        if flags & (1 << 18) != 0 { result.insert(.control) }
        return result
    }
}

public struct HotKeySpec: Equatable, Sendable, Codable, Hashable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let overlayDefault = HotKeySpec(keyCode: 46, modifiers: [.shift, .command])

    public var displayText: String {
        modifiers.symbolText + KeyName.text(keyCode)
    }
}

public enum KeyName {
    public static func text(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 46: return "M"
        case 36: return "⏎"
        case 48: return "⇥"
        case 49: return "Space"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 50: return "`"
        case 4: return "H"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        default: return "Key\(keyCode)"
        }
    }
}

public enum HardwareKey {
    public static let escape: UInt16 = 53
    public static let returnKey: UInt16 = 36
    public static let space: UInt16 = 49
    public static let tab: UInt16 = 48
    public static let left: UInt16 = 123
    public static let right: UInt16 = 124
    public static let down: UInt16 = 125
    public static let up: UInt16 = 126
    public static let grave: UInt16 = 50
    public static let h: UInt16 = 4
    public static let j: UInt16 = 38
    public static let k: UInt16 = 40
    public static let l: UInt16 = 37
    public static let one: UInt16 = 18
    public static let m: UInt16 = 46
}
