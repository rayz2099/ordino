import AppKit
import SwiftUI

/// 瞬态命令面的共享视觉尺度，避免 Overlay、Palette、Grid 各自形成一套节奏。
enum OrdinoStyle {
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let panelRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let borderWidth: CGFloat = 1
}

/// 单层系统材质；降低透明度时必须退化为实色，保证文本对比度稳定。
private struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.12),
                    lineWidth: OrdinoStyle.borderWidth
                )
            }
    }
}

extension View {
    func ordinoGlassSurface(radius: CGFloat = OrdinoStyle.panelRadius) -> some View {
        modifier(GlassSurface(radius: radius))
    }
}

/// 统一快捷键外观，让键位和说明形成稳定的左右信息层级。
struct OrdinoKeycap: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(minWidth: 28, minHeight: 22)
            .background(
                Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.07),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
    }
}
