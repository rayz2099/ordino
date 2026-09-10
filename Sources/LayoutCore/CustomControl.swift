import Foundation

/// 用户定义的 Layout Action，仅在 Overlay 里用单键触发，避免占用宿主应用快捷键。
public struct CustomControl: Equatable, Sendable, Codable, Identifiable {
    public var id: String
    public var title: String
    public var action: LayoutAction
    public var overlayDigit: UInt16?

    public init(
        id: String = UUID().uuidString,
        title: String,
        action: LayoutAction,
        overlayDigit: UInt16? = nil
    ) {
        self.id = id
        self.title = title
        self.action = action
        self.overlayDigit = overlayDigit
    }
}

public struct AppConfig: Equatable, Sendable, Codable {
    public var overlayHotKey: HotKeySpec
    public var mouseControlEnabled: Bool
    public var gridEnabled: Bool
    public var gridColumns: Int
    public var gridRows: Int
    public var customControls: [CustomControl]
    public var importedMoom: Bool

    public init(
        overlayHotKey: HotKeySpec = .overlayDefault,
        mouseControlEnabled: Bool = true,
        gridEnabled: Bool = false,
        gridColumns: Int = 6,
        gridRows: Int = 4,
        customControls: [CustomControl] = [],
        importedMoom: Bool = false
    ) {
        self.overlayHotKey = overlayHotKey
        self.mouseControlEnabled = mouseControlEnabled
        self.gridEnabled = gridEnabled
        self.gridColumns = gridColumns
        self.gridRows = gridRows
        self.customControls = customControls
        self.importedMoom = importedMoom
    }
}
