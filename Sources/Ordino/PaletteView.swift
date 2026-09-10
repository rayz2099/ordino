import SwiftUI
import LayoutCore

struct PaletteItem: Identifiable {
    let id: String
    let title: String
    let action: LayoutAction
}

/// 绿钮旁的鼠标命令面，与 Overlay 共用 Layout Action。
struct PaletteView: View {
    let items: [PaletteItem]
    let onPick: (LayoutAction) -> Void

    var body: some View {
        HStack(spacing: OrdinoStyle.spacingXS) {
            ForEach(items) { item in
                PaletteButton(item: item, onPick: onPick)
            }
        }
        .padding(6)
        .ordinoGlassSurface()
    }
}

/// 按钮只使用语义状态层，不叠第二层毛玻璃，避免材质发灰和层级混乱。
private struct PaletteButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    let item: PaletteItem
    let onPick: (LayoutAction) -> Void

    var body: some View {
        Button {
            onPick(item.action)
        } label: {
            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, OrdinoStyle.spacingSM)
                .frame(minWidth: 44, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            hovered ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: OrdinoStyle.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrdinoStyle.controlRadius, style: .continuous)
                .strokeBorder(
                    hovered ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
        }
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: hovered)
        .accessibilityLabel(item.title)
        .help(item.title)
    }
}

enum PaletteItems {
    static func make(controls: [CustomControl]) -> [PaletteItem] {
        var items = [
            PaletteItem(id: "fill", title: "填满", action: .fill),
            PaletteItem(id: "left", title: "左半", action: .half(.left)),
            PaletteItem(id: "right", title: "右半", action: .half(.right)),
            PaletteItem(id: "top", title: "上半", action: .half(.top)),
            PaletteItem(id: "bottom", title: "下半", action: .half(.bottom))
        ]
        for control in controls {
            items.append(PaletteItem(id: control.id, title: control.title, action: control.action))
        }
        return items
    }
}
