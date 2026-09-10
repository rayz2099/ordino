import Foundation

/// 生成短时平滑过渡帧；领域层只负责几何，不决定计时和窗口写入方式。
public enum FrameAnimation {
    private static let frameCount = 8

    public static func frames(from start: PixelRect, to end: PixelRect) -> [PixelRect] {
        let count = frameCount
        return (1...count).map { index in
            let t = Double(index) / Double(count)
            let eased = t * t * (3 - 2 * t)
            return PixelRect(
                x: interpolate(start.x, end.x, progress: eased),
                y: interpolate(start.y, end.y, progress: eased),
                width: interpolate(start.width, end.width, progress: eased),
                height: interpolate(start.height, end.height, progress: eased)
            )
        }
    }

    private static func interpolate(_ start: Double, _ end: Double, progress: Double) -> Double {
        start + (end - start) * progress
    }
}
