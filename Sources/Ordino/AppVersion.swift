import Foundation

/// 版本只认 Info.plist 里构建期写入的值，禁止在运行时再拼一套号。
enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var display: String {
        "\(marketing) (\(build))"
    }
}
