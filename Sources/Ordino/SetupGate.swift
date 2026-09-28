import Foundation

/// 引导完成标记独立于布局配置，避免和 Moom 导入、偏好迁移缠在一起。
enum SetupGate {
    private static let completedKey = "ordino.setupCompleted"
    private static let resumeKey = "ordino.setupResume"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static var shouldResume: Bool {
        UserDefaults.standard.bool(forKey: resumeKey)
    }

    static var shouldPresent: Bool {
        !isCompleted || AppInstall.needsInstall || shouldResume
    }

    static func markCompleted() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: completedKey)
        defaults.set(false, forKey: resumeKey)
    }

    static func markResume() {
        UserDefaults.standard.set(true, forKey: resumeKey)
    }
}
