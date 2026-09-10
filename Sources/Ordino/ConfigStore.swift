import Foundation
import LayoutCore

/// 自己的偏好与 Moom Classic 导入源分开，避免写回 Many Tricks 的 suite。
final class ConfigStore {
    private let defaults = UserDefaults.standard
    private let key = "ordino.config"
    private let legacyKey = "pane.config"
    private let legacyDefaults = UserDefaults(suiteName: "com.radiance.pane")
    private let moomKeys = [
        "Keyboard Controls",
        "Mouse Controls",
        "Mouse Controls Grid",
        "Custom Controls"
    ]

    func load() throws -> AppConfig {
        if let data = defaults.data(forKey: key) {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        }
        // 更名会切换偏好域；迁移旧配置才能避免升级后丢失快捷键和布局。
        if let data = defaults.data(forKey: legacyKey) ?? legacyDefaults?.data(forKey: legacyKey) {
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            try save(config)
            return config
        }
        return importFromMoom()
    }

    func save(_ config: AppConfig) throws {
        let data = try JSONEncoder().encode(config)
        defaults.set(data, forKey: key)
    }

    func importFromMoom() -> AppConfig {
        guard let suite = UserDefaults(suiteName: "com.manytricks.Moom") else {
            return AppConfig()
        }
        var dict: [String: Any] = [:]
        for key in moomKeys {
            if let value = suite.object(forKey: key) {
                dict[key] = value
            }
        }
        let snapshot = MoomImport.snapshot(from: dict)
        return MoomImport.mergedConfig(from: snapshot)
    }
}
