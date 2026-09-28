import SwiftUI

/// 首次启动必须先落到 Apps、开机项和 AX，否则热键和权限在下载目录会失效。
struct SetupView: View {
    @ObservedObject var runtime: OrdinoRuntime
    let onFinish: () -> Void

    @State private var step: SetupStep
    @State private var installing = false

    init(runtime: OrdinoRuntime, onFinish: @escaping () -> Void) {
        self.runtime = runtime
        self.onFinish = onFinish
        let start: SetupStep = AppInstall.needsInstall ? .install : .login
        _step = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            stepBody
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .frame(width: 480, height: 360)
        .onAppear { runtime.refreshPermission() }
        .onChange(of: runtime.lastError) { _, error in
            if error != nil { installing = false }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            OrdinoMark(size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("设置 Ordino")
                    .font(.title2.weight(.semibold))
                Text(step.caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .install:
            Text("从「应用程序」运行，辅助功能和开机启动才会稳定生效。")
                .font(.body)
        case .login:
            VStack(alignment: .leading, spacing: 12) {
                Text("登录后自动启动，窗口管理热键才能随时可用。")
                Toggle("开机时启动 Ordino", isOn: loginBinding)
                if LoginItem.needsApproval {
                    Text("系统还在等待你确认登录项。")
                        .foregroundStyle(.orange)
                    Button("打开登录项设置") { LoginItem.openLoginSettings() }
                }
            }
        case .permission:
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(runtime.axTrusted ? "辅助功能已授权" : "需要辅助功能权限才能排列窗口")
                } icon: {
                    Image(systemName: runtime.axTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(runtime.axTrusted ? Color.green : Color.orange)
                }
                HStack {
                    if !runtime.axTrusted {
                        Button("请求权限") { runtime.requestPermission() }
                    }
                    Button("系统设置") { AXPermission.openSystemSettings() }
                }
            }
        case .done:
            VStack(alignment: .leading, spacing: 8) {
                Text("按 \(runtime.config.overlayHotKey.displayText) 打开命令面板，即可排列当前窗口。")
                Text("之后可在菜单栏图标里打开设置、检查更新。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(step.progress)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if step != firstStep {
                Button("上一步") { goBack() }
            }
            Button(primaryTitle) { goForward() }
                .keyboardShortcut(.defaultAction)
                .disabled(installing)
        }
        .padding(16)
    }

    private var firstStep: SetupStep {
        AppInstall.needsInstall ? .install : .login
    }

    private var primaryTitle: String {
        switch step {
        case .install: return installing ? "正在安装…" : "安装到应用程序"
        case .login, .permission: return "继续"
        case .done: return "开始使用"
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { runtime.loginEnabled },
            set: { runtime.setLoginEnabled($0) }
        )
    }

    private func goBack() {
        switch step {
        case .install: break
        case .login: if AppInstall.needsInstall { step = .install }
        case .permission: step = .login
        case .done: step = .permission
        }
    }

    private func goForward() {
        switch step {
        case .install:
            installing = true
            runtime.installToApps()
        case .login:
            step = .permission
        case .permission:
            step = .done
        case .done:
            SetupGate.markCompleted()
            onFinish()
        }
    }
}

private enum SetupStep {
    case install
    case login
    case permission
    case done

    var caption: String {
        switch self {
        case .install: return "第 1 步 · 安装到应用程序"
        case .login: return "开机自启"
        case .permission: return "辅助功能"
        case .done: return "已就绪"
        }
    }

    var progress: String {
        switch self {
        case .install: return "1 / 4"
        case .login: return AppInstall.needsInstall ? "2 / 4" : "1 / 3"
        case .permission: return AppInstall.needsInstall ? "3 / 4" : "2 / 3"
        case .done: return AppInstall.needsInstall ? "4 / 4" : "3 / 3"
        }
    }
}
