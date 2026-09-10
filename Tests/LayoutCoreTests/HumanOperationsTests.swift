import XCTest
import LayoutCore

/// 把 Overlay / Palette / 全局热键这些人类操作面收成同一张 API 表，防止再和 Moom 键位、链式几何偏移。
final class HumanOperationsTests: XCTestCase {
    private let overlay = HotKeySpec.overlayDefault
    private let workArea = PixelRect(x: 0, y: 38, width: 1512, height: 944)
    private let external = PixelRect(x: 1512, y: 25, width: 2560, height: 1415)
    private var displays: [PixelRect] { [workArea, external] }
    private var map: OverlayMap {
        OverlayMap(
            overlayHotKey: overlay,
            controls: [
                CustomControl(
                    id: "left-two-thirds",
                    title: "左 2/3",
                    action: .moveZoom(RelativeFrame(x: 0, y: 0, width: 0.667, height: 1)),
                    overlayDigit: HardwareKey.one
                ),
                CustomControl(
                    id: "right-one-third",
                    title: "右 1/3",
                    action: .moveZoom(RelativeFrame(x: 0.667, y: 0, width: 0.333, height: 1)),
                    overlayDigit: 19
                )
            ]
        )
    }

    func testOverlayKeysMatchMoomClassic() {
        let cases: [(String, UInt16, KeyModifiers, OverlayCommand)] = [
            ("空格铺满", HardwareKey.space, [], .apply(.fill)),
            ("回车居中", HardwareKey.returnKey, [], .apply(.center)),
            ("左半", HardwareKey.left, [], .apply(.half(.left))),
            ("右半", HardwareKey.right, [], .apply(.half(.right))),
            ("上半", HardwareKey.up, [], .apply(.half(.top))),
            ("下半", HardwareKey.down, [], .apply(.half(.bottom))),
            ("H 向左布局", HardwareKey.h, [], .apply(.traverseHalf(.left))),
            ("L 向右布局", HardwareKey.l, [], .apply(.traverseHalf(.right))),
            ("K 上半", HardwareKey.k, [], .apply(.half(.top))),
            ("J 下半", HardwareKey.j, [], .apply(.half(.bottom))),
            ("⌘← 贴左", HardwareKey.left, [.command], .apply(.moveToEdge(.left))),
            ("⌘→ 贴右", HardwareKey.right, [.command], .apply(.moveToEdge(.right))),
            ("⌘↑ 贴上", HardwareKey.up, [.command], .apply(.moveToEdge(.top))),
            ("⌘↓ 贴下", HardwareKey.down, [.command], .apply(.moveToEdge(.bottom))),
            ("⇥ 下一块 Display", HardwareKey.tab, [], .apply(.moveToDisplay(.next))),
            ("⇧⇥ 上一块 Display", HardwareKey.tab, [.shift], .apply(.moveToDisplay(.previous))),
            ("` 恢复", HardwareKey.grave, [], .apply(.restorePrevious)),
            ("Esc 关闭", HardwareKey.escape, [], .dismiss),
            ("再按 Overlay", overlay.keyCode, overlay.modifiers, .openGrid),
            ("Overlay 1", HardwareKey.one, [], .custom(id: "left-two-thirds")),
            ("Overlay 2", 19, [], .custom(id: "right-one-third"))
        ]
        for item in cases {
            let actual = map.command(keyCode: item.1, modifiers: item.2)
            XCTAssertEqual(actual, item.3, item.0)
        }
    }

    func testMoomImportKeepsOverlayDigitWithoutGlobalHotKey() {
        let defaults: [String: Any] = [
            "Custom Controls": [[
                "Action": 0,
                "Identifier": "left-two-thirds",
                "Title": "左 2/3",
                "Relative Frame": "{{0, 0}, {0.667, 1}}",
                "Hot Key": ["Key Code": Int(HardwareKey.one), "Modifier Flags": 256]
            ]]
        ]

        let snapshot = MoomImport.snapshot(from: defaults)

        XCTAssertEqual(snapshot.controls.count, 1)
        XCTAssertEqual(snapshot.controls.first?.overlayDigit, HardwareKey.one)
    }

    func testFrameAnimationIsSmoothAndEndsExactlyAtTarget() {
        let start = PixelRect(x: 220, y: 180, width: 640, height: 420)
        let target = PixelRect(x: 756, y: 38, width: 756, height: 944)

        let frames = FrameAnimation.frames(from: start, to: target)

        XCTAssertEqual(frames.count, 8)
        XCTAssertEqual(frames.last, target)
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $0.x <= $1.x })
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $0.width <= $1.width })
        XCTAssertLessThan(frames[0].x - start.x, target.x - frames[0].x)
    }

    func testFrameAnimationUsesFixedBudgetAcrossDistances() {
        let small = PixelRect(x: 240, y: 180, width: 640, height: 420)
        let nearby = PixelRect(x: 250, y: 185, width: 650, height: 425)
        let crossDisplay = PixelRect(x: 1512, y: 25, width: 1280, height: 1415)

        let nearbyCount = FrameAnimation.frames(from: small, to: nearby).count
        let crossDisplayCount = FrameAnimation.frames(from: small, to: crossDisplay).count

        XCTAssertEqual(nearbyCount, 8)
        XCTAssertEqual(crossDisplayCount, 8)
    }

    func testPaletteActionsAreTheSameAPI() {
        let palette: [(String, LayoutAction)] = [
            ("填满", .fill),
            ("左半", .half(.left)),
            ("右半", .half(.right)),
            ("上半", .half(.top)),
            ("下半", .half(.bottom)),
            ("左 2/3", .moveZoom(RelativeFrame(x: 0, y: 0, width: 0.667, height: 1))),
            ("右 1/3", .moveZoom(RelativeFrame(x: 0.667, y: 0, width: 0.333, height: 1)))
        ]
        for item in palette {
            let frame = apply(item.1, to: seed())
            assertInside(frame, workArea, name: "Palette \(item.0)")
        }
    }

    func testFillThenVerticalHalvesStayOperable() {
        var current = seed()
        current = apply(.fill, to: current)
        assertNear(current, workArea, name: "空格铺满")

        let top = apply(.half(.top), to: current)
        XCTAssertEqual(top.y, workArea.y, accuracy: 1, "上半应贴工作区顶")
        XCTAssertEqual(top.height, (workArea.height / 2).rounded(), accuracy: 1, "铺满后上半必须能缩小高度")
        XCTAssertLessThan(top.height, workArea.height - 8, "上半不能还停在铺满")
        assertInside(top, workArea, name: "上半")

        let bottom = apply(.half(.bottom), to: top)
        XCTAssertGreaterThan(bottom.y, top.y + 8, "下半应在上半下面，Y 轴不能反")
        XCTAssertEqual(bottom.maxY, workArea.maxY, accuracy: 1, "下半应贴工作区底")
        XCTAssertEqual(bottom.height, (workArea.height / 2).rounded(), accuracy: 1)
        assertInside(bottom, workArea, name: "下半")
    }

    func testChainedHumanOpsNeverLeaveWorkArea() {
        let sequence: [(String, LayoutAction)] = [
            ("铺满", .fill),
            ("上半", .half(.top)),
            ("下半", .half(.bottom)),
            ("左半", .half(.left)),
            ("右半", .half(.right)),
            ("居中", .center),
            ("铺满", .fill),
            ("左 2/3", .moveZoom(RelativeFrame(x: 0, y: 0, width: 0.667, height: 1))),
            ("右 1/3", .moveZoom(RelativeFrame(x: 0.667, y: 0, width: 0.333, height: 1))),
            ("贴上", .moveToEdge(.top)),
            ("贴下", .moveToEdge(.bottom)),
            ("铺满", .fill),
            ("上半", .half(.top)),
            ("左半", .half(.left))
        ]
        var current = seed()
        for item in sequence {
            current = apply(item.1, to: current)
            assertInside(current, workArea, name: item.0)
        }
    }

    func testMoveToNextDisplayKeepsRelativeFrame() {
        let filled = apply(.fill, to: seed())
        let moved = apply(.moveToDisplay(.next), to: filled)
        assertInside(moved, external, name: "⇥ 下一块 Display")
        XCTAssertEqual(moved.width, external.width, accuracy: 1)
        XCTAssertEqual(moved.height, external.height, accuracy: 1)

        let back = apply(.moveToDisplay(.previous), to: moved)
        assertNear(back, workArea, name: "⇧⇥ 回主屏")
    }

    func testRepeatedHorizontalHalvesCrossDisplaysSpatially() {
        let right = RelativeFrame.rightHalf.absolute(in: workArea)
        let crossedRight = LayoutMath.resolvedFrame(
            action: .traverseHalf(.right),
            current: right,
            workArea: workArea,
            displays: displays
        )
        let externalLeft = RelativeFrame.leftHalf.absolute(in: external).integral
        XCTAssertEqual(crossedRight, externalLeft)

        let crossedLeft = LayoutMath.resolvedFrame(
            action: .traverseHalf(.left),
            current: crossedRight,
            workArea: external,
            displays: displays
        )
        XCTAssertEqual(crossedLeft, right.integral)
    }

    func testHorizontalHalvesDoNotWrapAtDesktopEdges() {
        let externalRight = RelativeFrame.rightHalf.absolute(in: external).integral
        let result = LayoutMath.resolvedFrame(
            action: .traverseHalf(.right),
            current: externalRight,
            workArea: external,
            displays: displays
        )
        XCTAssertEqual(result, externalRight)
    }

    func testChromeClampedOriginStillAllowsHalves() {
        let area = PixelRect(x: 1512, y: 0, width: 2560, height: 1440)
        let placed = PixelRect(x: 1512, y: 30, width: 2560, height: 1410)
        let fill = PixelRect(
            x: placed.x,
            y: placed.y,
            width: area.width,
            height: area.height
        ).clampedSize(to: area)
        XCTAssertEqual(fill.width, 2560, accuracy: 1)
        XCTAssertEqual(fill.height, 1410, accuracy: 1)
        XCTAssertEqual(fill.maxY, area.maxY, accuracy: 1)

        let left = PixelRect(
            x: placed.x,
            y: placed.y,
            width: area.width / 2,
            height: area.height
        ).clampedSize(to: area)
        XCTAssertEqual(left.width, 1280, accuracy: 1)
        XCTAssertEqual(left.height, 1410, accuracy: 1)
        XCTAssertLessThan(left.width, fill.width - 8, "铺满后左半必须能缩小宽度")

        let top = PixelRect(
            x: placed.x,
            y: placed.y,
            width: area.width,
            height: area.height / 2
        ).clampedSize(to: area)
        XCTAssertEqual(top.height, 720, accuracy: 1)
        XCTAssertLessThan(top.height, fill.height - 8, "铺满后上半必须能缩小高度")
        XCTAssertLessThanOrEqual(top.maxY, area.maxY)
    }

    func testCenterKeepsSize() {
        let half = apply(.half(.left), to: seed())
        let centered = apply(.center, to: half)
        XCTAssertEqual(centered.width, half.width, accuracy: 1)
        XCTAssertEqual(centered.height, half.height, accuracy: 1)
        XCTAssertEqual(centered.midX, workArea.midX, accuracy: 1)
        XCTAssertEqual(centered.midY, workArea.midY, accuracy: 1)
    }

    private func seed() -> PixelRect {
        PixelRect(x: 240, y: 180, width: 640, height: 420)
    }

    private func apply(_ action: LayoutAction, to current: PixelRect) -> PixelRect {
        LayoutMath.resolvedFrame(
            action: action,
            current: current,
            workArea: workArea,
            displays: displays
        )
    }

    private func assertInside(_ rect: PixelRect, _ area: PixelRect, name: String) {
        XCTAssertGreaterThan(rect.width, 0, "\(name) 宽度")
        XCTAssertGreaterThan(rect.height, 0, "\(name) 高度")
        XCTAssertGreaterThanOrEqual(rect.x, area.x - 0.6, "\(name) 左")
        XCTAssertGreaterThanOrEqual(rect.y, area.y - 0.6, "\(name) 上")
        XCTAssertLessThanOrEqual(rect.maxX, area.maxX + 0.6, "\(name) 右")
        XCTAssertLessThanOrEqual(rect.maxY, area.maxY + 0.6, "\(name) 下")
    }

    private func assertNear(_ rect: PixelRect, _ area: PixelRect, name: String) {
        XCTAssertEqual(rect.x, area.x, accuracy: 1, "\(name) x")
        XCTAssertEqual(rect.y, area.y, accuracy: 1, "\(name) y")
        XCTAssertEqual(rect.width, area.width, accuracy: 1, "\(name) w")
        XCTAssertEqual(rect.height, area.height, accuracy: 1, "\(name) h")
    }
}
