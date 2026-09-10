import Foundation

public struct MoomSnapshot: Sendable {
    public var overlayHotKey: HotKeySpec
    public var mouseControlEnabled: Bool
    public var gridEnabled: Bool
    public var controls: [CustomControl]
}

/// 把 Moom Classic 的偏好字典收成领域对象。只认 Relative Frame 类动作，忽略分组标题。
public enum MoomImport {
    public static func snapshot(from defaults: [String: Any]) -> MoomSnapshot {
        let overlay = overlayHotKey(from: defaults["Keyboard Controls"])
        let mouse = bool(defaults["Mouse Controls"], defaultValue: true)
        let grid = bool(defaults["Mouse Controls Grid"], defaultValue: false)
        let controls = customControls(from: defaults["Custom Controls"])
        return MoomSnapshot(
            overlayHotKey: overlay,
            mouseControlEnabled: mouse,
            gridEnabled: grid,
            controls: controls
        )
    }

    public static func mergedConfig(from snapshot: MoomSnapshot) -> AppConfig {
        AppConfig(
            overlayHotKey: snapshot.overlayHotKey,
            mouseControlEnabled: snapshot.mouseControlEnabled,
            gridEnabled: snapshot.gridEnabled,
            customControls: snapshot.controls,
            importedMoom: true
        )
    }

    private static func overlayHotKey(from raw: Any?) -> HotKeySpec {
        guard let dict = raw as? [String: Any] else { return .overlayDefault }
        let keyCode = uint16(dict["Key Code"], defaultValue: HardwareKey.m)
        let flags = int(dict["Modifier Flags"])
        return HotKeySpec(keyCode: keyCode, modifiers: KeyModifiers.decodingMoom(flags))
    }

    private static func customControls(from raw: Any?) -> [CustomControl] {
        guard let items = raw as? [[String: Any]] else { return [] }
        var result: [CustomControl] = []
        for item in items {
            let actionCode = int(item["Action"])
            if actionCode < 0 { continue }
            guard let frame = relativeFrame(item["Relative Frame"]) else { continue }
            let id = string(item["Identifier"]) ?? UUID().uuidString
            let titleRaw = string(item["Title"]) ?? ""
            let title = titleRaw.isEmpty ? FrameTitle.describe(frame) : titleRaw
            // 只继承数字作为 Overlay 内命令；全局 ⌘数字会与 IDE Keymap 冲突。
            let importedHotKey = hotKey(item["Hot Key"])
            let overlayDigit = importedHotKey.flatMap { digitKey($0.keyCode) }
            result.append(
                CustomControl(
                    id: id,
                    title: title,
                    action: .moveZoom(frame),
                    overlayDigit: overlayDigit
                )
            )
        }
        return result
    }

    private static func hotKey(_ raw: Any?) -> HotKeySpec? {
        guard let dict = raw as? [String: Any] else { return nil }
        let keyCode = uint16(dict["Key Code"], defaultValue: 0)
        let flags = int(dict["Modifier Flags"])
        return HotKeySpec(keyCode: keyCode, modifiers: KeyModifiers.decodingMoom(flags))
    }

    private static func relativeFrame(_ raw: Any?) -> RelativeFrame? {
        if let string = raw as? String {
            return parseRectString(string)
        }
        return parseRectString(String(describing: raw ?? ""))
    }

    /// Moom 把 NSRect 存成 `{{x, y}, {w, h}}` 文本。
    private static func parseRectString(_ string: String) -> RelativeFrame? {
        let trimmed = string
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 4 else { return nil }
        guard let x = Double(parts[0]), let y = Double(parts[1]),
              let w = Double(parts[2]), let h = Double(parts[3]) else { return nil }
        return RelativeFrame(x: x, y: y, width: w, height: h)
    }

    private static func digitKey(_ keyCode: UInt16) -> UInt16? {
        switch keyCode {
        case 18, 19, 20, 21, 23, 22, 26, 28, 25, 29: return keyCode
        default: return nil
        }
    }

    private static func bool(_ raw: Any?, defaultValue: Bool) -> Bool {
        if let value = raw as? Bool { return value }
        if let number = raw as? NSNumber { return number.boolValue }
        return defaultValue
    }

    private static func int(_ raw: Any?) -> Int {
        if let value = raw as? Int { return value }
        if let number = raw as? NSNumber { return number.intValue }
        if let string = raw as? String, let value = Int(string) { return value }
        return 0
    }

    private static func uint16(_ raw: Any?, defaultValue: UInt16) -> UInt16 {
        if let value = raw as? Int { return UInt16(value) }
        if let number = raw as? NSNumber { return number.uint16Value }
        return defaultValue
    }

    private static func string(_ raw: Any?) -> String? {
        raw as? String
    }
}
