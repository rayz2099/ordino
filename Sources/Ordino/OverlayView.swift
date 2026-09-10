import SwiftUI
import LayoutCore

struct OverlayHint: Identifiable {
    let id: String
    let key: String
    let label: String
}

/// Overlay 必须即时、高密度、系统材质。它是命令面，不是营销 HUD。
struct OverlayView: View {
    let title: String
    let hints: [OverlayHint]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: OrdinoStyle.spacingSM) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding(.bottom, OrdinoStyle.spacingSM)

            Divider()
                .padding(.bottom, OrdinoStyle.spacingXS)

            ForEach(hints) { hint in
                HStack(spacing: OrdinoStyle.spacingSM) {
                    OrdinoKeycap(text: hint.key)
                        .frame(width: 68, alignment: .leading)
                    Text(hint.label)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 27)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(hint.label)，快捷键 \(hint.key)")
            }
        }
        .padding(OrdinoStyle.spacingMD)
        .frame(width: 272)
        .ordinoGlassSurface()
    }
}

enum OverlayHints {
    static func make(controls: [CustomControl], overlayHotKey: HotKeySpec) -> [OverlayHint] {
        var hints = [
            OverlayHint(id: "left", key: "H", label: "向左布局"),
            OverlayHint(id: "down", key: "J", label: "下半"),
            OverlayHint(id: "up", key: "K", label: "上半"),
            OverlayHint(id: "right", key: "L", label: "向右布局"),
            OverlayHint(id: "fill", key: "Space", label: "填满"),
            OverlayHint(id: "center", key: "⏎", label: "居中"),
            OverlayHint(id: "display", key: "⇥", label: "下一块显示器"),
            OverlayHint(id: "undo", key: "`", label: "恢复上一次"),
            OverlayHint(id: "grid", key: overlayHotKey.displayText, label: "网格"),
            OverlayHint(id: "esc", key: "⎋", label: "关闭")
        ]
        for control in controls {
            if let digit = control.overlayDigit {
                hints.append(
                    OverlayHint(
                        id: control.id,
                        key: KeyName.text(digit),
                        label: control.title
                    )
                )
            }
        }
        return hints
    }
}
