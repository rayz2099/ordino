import ApplicationServices
import Foundation

/// AX 调用失败必须显式暴露，禁止把「读不到窗口」当成空操作。
enum OrdinoError: Error, LocalizedError {
    case accessibilityDenied
    case noFocusedWindow
    case noWindowAtPoint
    case attributeMissing(String)
    case setFailed(String, AXError)
    case notResizable
    case windowServerFailed(String)
    case ownWindow
    case noDisplay
    case noGreenButton
    case noPreviousFrame
    case eventTapCreateFailed
    case hotKeyRegisterFailed
    case quarantineFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied: return "未授予辅助功能权限"
        case .noFocusedWindow: return "没有可操作的前台窗口"
        case .noWindowAtPoint: return "指针下没有窗口"
        case .attributeMissing(let name): return "窗口缺少属性 \(name)"
        case .setFailed(let name, let code):
            return "无法写入 \(name)（AXError \(code.rawValue)）"
        case .notResizable: return "该窗口不允许调整大小"
        case .windowServerFailed(let reason): return reason
        case .ownWindow: return "不能操作 Ordino 自己的窗口"
        case .noDisplay: return "窗口不在任何 Display 工作区内"
        case .noGreenButton: return "该窗口没有绿色缩放按钮"
        case .noPreviousFrame: return "没有可恢复的上一次位置"
        case .eventTapCreateFailed: return "无法建立按键截获"
        case .hotKeyRegisterFailed: return "无法注册全局热键"
        case .quarantineFailed(let code): return "无法清除隔离属性（xattr \(code)）"
        }
    }
}
