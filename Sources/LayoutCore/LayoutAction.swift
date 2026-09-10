import Foundation

/// 一次窗口几何变换。命令面（Overlay / Hot Key / Mouse Control / Grid）都收敛到这里。
public enum LayoutAction: Equatable, Sendable, Codable {
    case moveZoom(RelativeFrame)
    case fill
    case center
    case half(Edge)
    case traverseHalf(Edge)
    case moveToEdge(Edge)
    case moveToDisplay(DisplayStep)
    case restorePrevious

    public var relativeFrame: RelativeFrame? {
        switch self {
        case .moveZoom(let frame): return frame
        case .fill: return .fill
        case .half(.left): return .leftHalf
        case .half(.right): return .rightHalf
        case .half(.top): return .topHalf
        case .half(.bottom): return .bottomHalf
        case .center, .traverseHalf, .moveToEdge, .moveToDisplay, .restorePrevious: return nil
        }
    }
}

/// 把 Layout Action 算成目标像素矩形。Display 列表由适配器提供，领域核只做几何。
public enum LayoutMath {
    public static func targetFrame(
        action: LayoutAction,
        current: PixelRect,
        workArea: PixelRect,
        displays: [PixelRect]
    ) -> PixelRect {
        switch action {
        case .moveZoom(let frame):
            return frame.absolute(in: workArea).integral
        case .fill:
            return RelativeFrame.fill.absolute(in: workArea).integral
        case .center:
            let x = workArea.x + (workArea.width - current.width) / 2
            let y = workArea.y + (workArea.height - current.height) / 2
            return PixelRect(x: x, y: y, width: current.width, height: current.height).integral
        case .half(let edge):
            let frame: RelativeFrame
            switch edge {
            case .left: frame = .leftHalf
            case .right: frame = .rightHalf
            case .top: frame = .topHalf
            case .bottom: frame = .bottomHalf
            }
            return frame.absolute(in: workArea).integral
        case .traverseHalf(let edge):
            return traverseHalfTarget(
                edge: edge,
                current: current,
                workArea: workArea,
                displays: displays
            )
        case .moveToEdge(let edge):
            return clampedToEdge(current, workArea: workArea, edge: edge).integral
        case .moveToDisplay(let step):
            let next = steppedDisplay(from: workArea, displays: displays, step: step)
            let relative = current.relative(to: workArea)
            return relative.absolute(in: next).integral
        case .restorePrevious:
            preconditionFailure("restorePrevious 由适配器读历史，不在几何核里猜")
        }
    }

    /// 命令面真正落到屏幕上的矩形：先算目标，再夹进落点 Display 的工作区。
    public static func resolvedFrame(
        action: LayoutAction,
        current: PixelRect,
        workArea: PixelRect,
        displays: [PixelRect]
    ) -> PixelRect {
        let raw = targetFrame(
            action: action,
            current: current,
            workArea: workArea,
            displays: displays
        )
        let dest = displays.first(where: { $0.contains(x: raw.midX, y: raw.midY) }) ?? workArea
        return clamped(raw, to: dest)
    }

    public static func clamped(_ rect: PixelRect, to workArea: PixelRect) -> PixelRect {
        var result = rect
        result.width = min(result.width, workArea.width)
        result.height = min(result.height, workArea.height)
        result.x = min(max(result.x, workArea.x), workArea.maxX - result.width)
        result.y = min(max(result.y, workArea.y), workArea.maxY - result.height)
        return result.integral
    }

    private static func clampedToEdge(_ current: PixelRect, workArea: PixelRect, edge: Edge) -> PixelRect {
        var rect = current
        switch edge {
        case .left:
            rect.x = workArea.x
        case .right:
            rect.x = workArea.maxX - current.width
        case .top:
            rect.y = workArea.y
        case .bottom:
            rect.y = workArea.maxY - current.height
        }
        rect.x = min(max(rect.x, workArea.x), workArea.maxX - rect.width)
        rect.y = min(max(rect.y, workArea.y), workArea.maxY - rect.height)
        return rect
    }

    /// 重复左右半屏命令时沿物理方向跨屏，并落到相邻显示器的近侧半屏，保持空间连续性。
    private static func traverseHalfTarget(
        edge: Edge,
        current: PixelRect,
        workArea: PixelRect,
        displays: [PixelRect]
    ) -> PixelRect {
        switch edge {
        case .left:
            if approximately(current, matches: .leftHalf, in: workArea),
               let display = horizontalNeighbor(of: workArea, in: displays, edge: .left) {
                return RelativeFrame.rightHalf.absolute(in: display).integral
            }
            if approximately(current, matches: .leftHalf, in: workArea) {
                return current.integral
            }
            return RelativeFrame.leftHalf.absolute(in: workArea).integral
        case .right:
            if approximately(current, matches: .rightHalf, in: workArea),
               let display = horizontalNeighbor(of: workArea, in: displays, edge: .right) {
                return RelativeFrame.leftHalf.absolute(in: display).integral
            }
            if approximately(current, matches: .rightHalf, in: workArea) {
                return current.integral
            }
            return RelativeFrame.rightHalf.absolute(in: workArea).integral
        case .top:
            return RelativeFrame.topHalf.absolute(in: workArea).integral
        case .bottom:
            return RelativeFrame.bottomHalf.absolute(in: workArea).integral
        }
    }

    private static func approximately(_ rect: PixelRect, matches frame: RelativeFrame, in area: PixelRect) -> Bool {
        let current = rect.relative(to: area)
        let tolerance = 0.03
        return abs(current.x - frame.x) < tolerance
            && abs(current.y - frame.y) < tolerance
            && abs(current.width - frame.width) < tolerance
            && abs(current.height - frame.height) < tolerance
    }

    /// 只选择物理上位于目标方向的显示器；边界处不循环到桌面的另一端。
    private static func horizontalNeighbor(of area: PixelRect, in displays: [PixelRect], edge: Edge) -> PixelRect? {
        let candidates = displays.filter { display in
            switch edge {
            case .left: return display.midX < area.midX - 1
            case .right: return display.midX > area.midX + 1
            case .top, .bottom: return false
            }
        }
        return candidates.min { lhs, rhs in
            horizontalScore(lhs, from: area, edge: edge) < horizontalScore(rhs, from: area, edge: edge)
        }
    }

    private static func horizontalScore(_ candidate: PixelRect, from area: PixelRect, edge: Edge) -> Double {
        let horizontal: Double
        switch edge {
        case .left: horizontal = abs(area.x - candidate.maxX)
        case .right: horizontal = abs(candidate.x - area.maxX)
        case .top, .bottom: horizontal = .greatestFiniteMagnitude
        }
        let vertical: Double
        if candidate.maxY < area.y {
            vertical = area.y - candidate.maxY
        } else if candidate.y > area.maxY {
            vertical = candidate.y - area.maxY
        } else {
            vertical = 0
        }
        return horizontal + vertical * 2
    }

    private static func steppedDisplay(from workArea: PixelRect, displays: [PixelRect], step: DisplayStep) -> PixelRect {
        precondition(!displays.isEmpty, "Display 列表不能空")
        let sorted = displays.sorted { $0.x < $1.x }
        let index = sorted.firstIndex { abs($0.x - workArea.x) < 1 && abs($0.y - workArea.y) < 1 }
        guard let index else {
            preconditionFailure("当前工作区不在 Display 列表中")
        }
        switch step {
        case .next:
            return sorted[(index + 1) % sorted.count]
        case .previous:
            return sorted[(index - 1 + sorted.count) % sorted.count]
        }
    }
}
