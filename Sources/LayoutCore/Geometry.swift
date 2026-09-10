import Foundation

/// Display 可用工作区上的归一化矩形，原点左上。领域核只用比例，不碰像素和 AppKit。
public struct RelativeFrame: Equatable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let fill = RelativeFrame(x: 0, y: 0, width: 1, height: 1)
    public static let leftHalf = RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)
    public static let rightHalf = RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 1)
    public static let topHalf = RelativeFrame(x: 0, y: 0, width: 1, height: 0.5)
    public static let bottomHalf = RelativeFrame(x: 0, y: 0.5, width: 1, height: 0.5)
    public static let topLeft = RelativeFrame(x: 0, y: 0, width: 0.5, height: 0.5)
    public static let topRight = RelativeFrame(x: 0.5, y: 0, width: 0.5, height: 0.5)
    public static let bottomLeft = RelativeFrame(x: 0, y: 0.5, width: 0.5, height: 0.5)
    public static let bottomRight = RelativeFrame(x: 0.5, y: 0.5, width: 0.5, height: 0.5)

    /// 把比例映射到一块工作区。工作区必须与 AX 一样：原点左上、Y 向下。
    public func absolute(in workArea: PixelRect) -> PixelRect {
        PixelRect(
            x: workArea.x + workArea.width * x,
            y: workArea.y + workArea.height * y,
            width: workArea.width * width,
            height: workArea.height * height
        )
    }

    public func rounded(toPlaces places: Int = 4) -> RelativeFrame {
        let factor = pow(10.0, Double(places))
        return RelativeFrame(
            x: (x * factor).rounded() / factor,
            y: (y * factor).rounded() / factor,
            width: (width * factor).rounded() / factor,
            height: (height * factor).rounded() / factor
        )
    }
}

/// 像素矩形。单位是屏幕点，坐标系由调用方保证（AX 空间）。
public struct PixelRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    public var integral: PixelRect {
        let x0 = x.rounded()
        let y0 = y.rounded()
        let x1 = maxX.rounded()
        let y1 = maxY.rounded()
        return PixelRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
    }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px < maxX && py >= y && py < maxY
    }

    /// Chrome 会把 origin 卡在菜单栏下；最终尺寸必须按实际原点还能放下的最大矩形写。
    public func clampedSize(to area: PixelRect) -> PixelRect {
        let width = min(self.width, max(1, area.maxX - x))
        let height = min(self.height, max(1, area.maxY - y))
        return PixelRect(x: x, y: y, width: width, height: height).integral
    }

    /// 把当前矩形表达成相对某块工作区的 Relative Frame，供跨 Display 时保持比例。
    public func relative(to workArea: PixelRect) -> RelativeFrame {
        RelativeFrame(
            x: workArea.width == 0 ? 0 : (x - workArea.x) / workArea.width,
            y: workArea.height == 0 ? 0 : (y - workArea.y) / workArea.height,
            width: workArea.width == 0 ? 1 : width / workArea.width,
            height: workArea.height == 0 ? 1 : height / workArea.height
        )
    }
}

public enum Edge: String, Sendable, Codable {
    case left, right, top, bottom
}

public enum DisplayStep: String, Sendable, Codable {
    case next, previous
}

public enum FrameTitle {
    /// 给没有 Title 的 Custom Control 一个可读名称，避免设置页出现空白行。
    public static func describe(_ frame: RelativeFrame) -> String {
        let f = frame.rounded(toPlaces: 3)
        if f == .fill { return "填满" }
        if f == .leftHalf { return "左半" }
        if f == .rightHalf { return "右半" }
        if f == .topHalf { return "上半" }
        if f == .bottomHalf { return "下半" }
        if f.width == 0.667 && f.height == 1 && f.x == 0 { return "左 2/3" }
        if f.width == 0.333 && f.height == 1 && abs(f.x - 0.667) < 0.002 { return "右 1/3" }
        if f.width == 0.666 && f.height == 1 && f.x == 0 { return "左 2/3" }
        if f.width == 0.334 && f.height == 1 && abs(f.x - 0.666) < 0.002 { return "右 1/3" }
        let pctW = Int((f.width * 100).rounded())
        let pctH = Int((f.height * 100).rounded())
        return "\(pctW)% × \(pctH)%"
    }
}
