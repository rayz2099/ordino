import ApplicationServices
import CoreGraphics
import Darwin
import Foundation
import LayoutCore

/// iTerm Hotkey 这类窗口会关掉 AXSize，辅助功能写不进去。
/// WindowServer 改的是合成器里的窗口形状，不发 AppleEvent，所以不会再弹 Automation。
enum WindowServer {
    static func windowID(of element: AXUIElement) throws -> CGWindowID {
        let api = try SkyLight.current()
        var identifier: CGWindowID = 0
        let status = api.windowID(element, &identifier)
        if status != 0 || identifier == 0 {
            throw OrdinoError.windowServerFailed("无法读取窗口编号")
        }
        return identifier
    }

    static func frame(of identifier: CGWindowID) throws -> PixelRect {
        let api = try SkyLight.current()
        var bounds = CGRect.zero
        let status = api.bounds(api.connection, identifier, &bounds)
        if status != 0 {
            throw OrdinoError.windowServerFailed("无法读取窗口服务器矩形（\(status)）")
        }
        return PixelRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height).integral
    }

    /// 必须先把 origin 落到目标点，再按「当前 origin + 局部尺寸」写形状。
    /// 偏移不等于当前 origin 时，本机 iTerm TOP 窗高度不会变。
    static func setFrame(_ rect: PixelRect, of identifier: CGWindowID) throws {
        let api = try SkyLight.current()
        var origin = CGPoint(x: rect.x, y: rect.y)
        let moveStatus = api.move(api.connection, identifier, &origin)
        if moveStatus != 0 {
            throw OrdinoError.windowServerFailed("无法移动窗口（\(moveStatus)）")
        }
        var local = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
        var region: CFTypeRef?
        let regionStatus = api.newRegion(&local, &region)
        guard regionStatus == 0, let region else {
            throw OrdinoError.windowServerFailed("无法创建窗口形状")
        }
        let status = api.setShape(
            api.connection,
            identifier,
            Float(rect.x),
            Float(rect.y),
            region
        )
        if status != 0 {
            throw OrdinoError.windowServerFailed("无法写入窗口形状（\(status)）")
        }
    }
}

private struct SkyLight {
    typealias ConnectionFn = @convention(c) () -> Int32
    typealias BoundsFn = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32
    typealias MoveFn = @convention(c) (Int32, UInt32, UnsafePointer<CGPoint>) -> Int32
    typealias ShapeFn = @convention(c) (Int32, UInt32, Float, Float, CFTypeRef) -> Int32
    typealias RegionFn = @convention(c) (UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<CFTypeRef?>) -> Int32
    typealias WindowIDFn = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32

    let connection: Int32
    let bounds: BoundsFn
    let move: MoveFn
    let setShape: ShapeFn
    let newRegion: RegionFn
    let windowID: WindowIDFn

    nonisolated(unsafe) private static var cached: SkyLight?

    static func current() throws -> SkyLight {
        if let cached { return cached }
        let created = try SkyLight()
        cached = created
        return created
    }

    private init() throws {
        guard let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            throw OrdinoError.windowServerFailed("无法加载 SkyLight")
        }
        guard let services = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW) else {
            throw OrdinoError.windowServerFailed("无法加载 ApplicationServices")
        }
        connection = try SkyLight.symbol(sky, "SLSMainConnectionID", as: ConnectionFn.self)()
        bounds = try SkyLight.symbol(sky, "SLSGetWindowBounds", as: BoundsFn.self)
        move = try SkyLight.symbol(sky, "SLSMoveWindow", as: MoveFn.self)
        setShape = try SkyLight.symbol(sky, "SLSSetWindowShapeInWindowCoordinates", as: ShapeFn.self)
        newRegion = try SkyLight.symbol(sky, "CGSNewRegionWithRect", as: RegionFn.self)
        windowID = try SkyLight.symbol(services, "_AXUIElementGetWindow", as: WindowIDFn.self)
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String, as type: T.Type) throws -> T {
        guard let pointer = dlsym(handle, name) else {
            throw OrdinoError.windowServerFailed("缺少符号 \(name)")
        }
        return unsafeBitCast(pointer, to: T.self)
    }
}
