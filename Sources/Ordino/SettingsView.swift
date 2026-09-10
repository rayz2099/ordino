import SwiftUI
import LayoutCore

struct SettingsView: View {
    @ObservedObject var runtime: OrdinoRuntime

    var body: some View {
        Form {
            Section("状态") {
                HStack {
                    Label {
                        Text(runtime.axTrusted ? "辅助功能已授权" : "需要辅助功能权限")
                    } icon: {
                        Image(systemName: runtime.axTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .foregroundStyle(runtime.axTrusted ? Color.green : Color.orange)
                    }
                    Spacer()
                    if !runtime.axTrusted {
                        Button("请求权限") { runtime.requestPermission() }
                    }
                    Button("系统设置") { AXPermission.openSystemSettings() }
                }
            }

            Section("快捷操作") {
                LabeledContent("命令面板") {
                    HotKeyRecorder(
                        spec: runtime.config.overlayHotKey,
                        recording: runtime.recordingOverlay,
                        onStart: { runtime.beginRecordingOverlay() }
                    )
                }
                Toggle("悬停绿色按钮显示布局菜单", isOn: mouseBinding)
                Toggle("启用网格选择器", isOn: gridBinding)
                Stepper(value: columnsBinding, in: 2...12) {
                    Text("网格列数：\(runtime.config.gridColumns)")
                }
                .disabled(!runtime.config.gridEnabled)
                Stepper(value: rowsBinding, in: 2...8) {
                    Text("网格行数：\(runtime.config.gridRows)")
                }
                .disabled(!runtime.config.gridEnabled)
            }

            if let lastError = runtime.lastError {
                Section("错误") {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section("自定义布局") {
                ForEach(runtime.config.customControls) { control in
                    HStack {
                        Text(control.title)
                        Spacer()
                        if let digit = control.overlayDigit {
                            OrdinoKeycap(text: KeyName.text(digit))
                                .accessibilityLabel("命令面板快捷键 \(KeyName.text(digit))")
                        } else {
                            Text("无快捷键")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("重新导入 Moom Classic", systemImage: "arrow.clockwise") {
                    runtime.reimportMoom()
                }
            }
        }
        .formStyle(.grouped)
        .tint(.accentColor)
        .frame(minWidth: 480, minHeight: 420)
        .onAppear { runtime.refreshPermission() }
    }

    private var mouseBinding: Binding<Bool> {
        Binding(
            get: { runtime.config.mouseControlEnabled },
            set: { runtime.setMouseControl($0) }
        )
    }

    private var gridBinding: Binding<Bool> {
        Binding(
            get: { runtime.config.gridEnabled },
            set: { runtime.setGridEnabled($0) }
        )
    }

    private var columnsBinding: Binding<Int> {
        Binding(
            get: { runtime.config.gridColumns },
            set: { runtime.setGridSize(columns: $0, rows: runtime.config.gridRows) }
        )
    }

    private var rowsBinding: Binding<Int> {
        Binding(
            get: { runtime.config.gridRows },
            set: { runtime.setGridSize(columns: runtime.config.gridColumns, rows: $0) }
        )
    }
}

struct HotKeyRecorder: View {
    let spec: HotKeySpec
    let recording: Bool
    let onStart: () -> Void

    var body: some View {
        Button(recording ? "按下组合键…" : spec.displayText) {
            onStart()
        }
        .font(.system(.body, design: .monospaced))
    }
}
