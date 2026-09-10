import AppKit
import LayoutCore

/// Cocoa 屏幕坐标（原点左下）转到 AX 坐标（原点左上）。只在适配器里做。
enum DisplayMap {
    static func workAreas() throws -> [PixelRect] {
        let screens = NSScreen.screens
        if screens.isEmpty { throw OrdinoError.noDisplay }
        return try screens.map { try axRect(fromCocoa: $0.visibleFrame) }
    }

    static func workArea(containing rect: PixelRect) throws -> PixelRect {
        let areas = try workAreas()
        let ranked = areas.map { area in (area, overlap(area, rect)) }
        guard let best = ranked.max(by: { $0.1 < $1.1 }), best.1 > 0 else {
            throw OrdinoError.noDisplay
        }
        return best.0
    }

    /// 跨屏动画可能短暂经过显示器间隙；此时使用几何上最近的工作区，不能把过渡当成无显示器错误。
    static func workArea(nearestTo rect: PixelRect) throws -> PixelRect {
        let areas = try workAreas()
        let ranked = areas.map { area in (area, overlap(area, rect)) }
        if let best = ranked.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            return best.0
        }
        guard let nearest = areas.min(by: { distanceSquared($0, rect) < distanceSquared($1, rect) }) else {
            throw OrdinoError.noDisplay
        }
        return nearest
    }

    static func cocoaRect(fromAX rect: PixelRect) throws -> CGRect {
        let height = try primaryHeight()
        return CGRect(
            x: rect.x,
            y: height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func axPoint(fromCocoa point: CGPoint) throws -> CGPoint {
        let height = try primaryHeight()
        return CGPoint(x: point.x, y: height - point.y)
    }

    static func axRect(fromCocoa rect: CGRect) throws -> PixelRect {
        let height = try primaryHeight()
        return PixelRect(
            x: rect.origin.x,
            y: height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func primaryHeight() throws -> CGFloat {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) else {
            throw OrdinoError.noDisplay
        }
        return primary.frame.height
    }

    private static func overlap(_ a: PixelRect, _ b: PixelRect) -> Double {
        let x = max(0, min(a.maxX, b.maxX) - max(a.x, b.x))
        let y = max(0, min(a.maxY, b.maxY) - max(a.y, b.y))
        return x * y
    }

    private static func distanceSquared(_ area: PixelRect, _ rect: PixelRect) -> Double {
        let x = area.midX - rect.midX
        let y = area.midY - rect.midY
        return x * x + y * y
    }
}
