import AppKit

/// 从磁盘镜像或下载目录跑会丢 TCC 与开机项；必须落到 /Applications 才算安装完成。
enum AppInstall {
    static var destURL: URL {
        URL(fileURLWithPath: "/Applications/Ordino.app")
    }

    static var isInApps: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/")
    }

    /// Debug 产物在 derived 里，强行拷进 Apps 会覆盖正式包。
    static var isDevBuild: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/.derived/") || path.contains("/Build/Products/")
    }

    static var needsInstall: Bool {
        !isInApps && !isDevBuild
    }

    static func install() throws {
        let dest = destURL
        let src = Bundle.main.bundleURL
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: src, to: dest)
        try clearQuarantine(at: dest)
    }

    static func relaunch() async throws {
        let dest = destURL
        let config = NSWorkspace.OpenConfiguration()
        _ = try await NSWorkspace.shared.openApplication(at: dest, configuration: config)
    }

    private static func clearQuarantine(at url: URL) throws {
        let listed = try xattrList(url)
        guard listed.contains("com.apple.quarantine") else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        proc.arguments = ["-dr", "com.apple.quarantine", url.path]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw OrdinoError.quarantineFailed(proc.terminationStatus)
        }
    }

    private static func xattrList(_ url: URL) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        proc.arguments = ["-lr", url.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw OrdinoError.quarantineFailed(proc.terminationStatus)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            throw OrdinoError.quarantineFailed(proc.terminationStatus)
        }
        return text
    }
}
