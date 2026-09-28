import ServiceManagement

/// 开机项以 SMAppService 为准，不写进自己的 JSON，避免和系统状态分叉。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
