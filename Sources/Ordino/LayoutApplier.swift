import AppKit
import Foundation
import LayoutCore

/// 把 Layout Action 落到 AX 窗口，并记住上一次矩形供 Overlay 恢复。
@MainActor
final class LayoutApplier {
    private var previous: (window: AXWindow, frame: PixelRect)?
    private var lastForeign: AXWindow?
    private let animator = WindowAnimator()
    var onAnimationFinished: (() -> Void)?
    var onAnimationError: ((Error) -> Void)?

    func remember(_ window: AXWindow) {
        if !window.isOwnProcess {
            lastForeign = window
        }
    }

    /// Settings / Overlay 会把 Ordino 变成前台，必须在激活前记住真正的目标窗。
    func captureFrontmost() {
        do {
            remember(try AXWindow.focused())
        } catch {
            return
        }
    }

    func targetWindow() throws -> AXWindow {
        let focused = try AXWindow.focused()
        if !focused.isOwnProcess {
            lastForeign = focused
            return focused
        }
        if let lastForeign {
            return lastForeign
        }
        throw OrdinoError.noFocusedWindow
    }

    func apply(_ action: LayoutAction, to window: AXWindow) throws {
        let window = try window.resolved()
        if window.isOwnProcess { throw OrdinoError.ownWindow }
        if action == .restorePrevious {
            try restore(window)
            return
        }
        let physical = try window.frame()
        let current = animator.logicalFrame(for: window, physical: physical)
        let workArea = try DisplayMap.workArea(containing: current)
        let displays = try DisplayMap.workAreas()
        let target = LayoutMath.resolvedFrame(
            action: action,
            current: current,
            workArea: workArea,
            displays: displays
        )
        if target == current { return }
        previous = (window, current)
        animator.animate(
            window: window,
            from: physical,
            to: target,
            onFinished: { [weak self] in self?.onAnimationFinished?() },
            onError: { [weak self] error in self?.onAnimationError?(error) }
        )
        remember(window)
    }

    func apply(_ action: LayoutAction) throws {
        try apply(action, to: try targetWindow())
    }

    private func restore(_ window: AXWindow) throws {
        guard let previous, CFEqual(previous.window.element, window.element) else {
            throw OrdinoError.noPreviousFrame
        }
        let physical = try window.frame()
        let current = animator.logicalFrame(for: window, physical: physical)
        if previous.frame == current {
            self.previous = nil
            return
        }
        animator.animate(
            window: window,
            from: physical,
            to: previous.frame,
            onFinished: { [weak self] in self?.onAnimationFinished?() },
            onError: { [weak self] error in self?.onAnimationError?(error) }
        )
        self.previous = nil
    }
}

/// 同一时刻只允许一个窗口动画；新布局必须从 live frame 接管，不能被旧 completion 覆盖。
@MainActor
private final class WindowAnimator {
    private var task: Task<Void, Never>?
    private var generation = 0
    private var pending: (window: AXWindow, target: PixelRect)?

    func logicalFrame(for window: AXWindow, physical: PixelRect) -> PixelRect {
        guard let pending, CFEqual(pending.window.element, window.element) else { return physical }
        return pending.target
    }

    func animate(
        window: AXWindow,
        from start: PixelRect,
        to target: PixelRect,
        onFinished: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        task?.cancel()
        generation += 1
        let token = generation
        pending = (window, target)
        let frames: [PixelRect]
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            frames = [target]
        } else {
            frames = FrameAnimation.frames(from: start, to: target)
        }
        task = Task { @MainActor [weak self] in
            do {
                for (index, frame) in frames.enumerated() {
                    try Task.checkCancellation()
                    try window.setFrame(frame)
                    if index < frames.count - 1 {
                        try await Task.sleep(for: .milliseconds(4))
                    }
                }
                guard let self, generation == token, !Task.isCancelled else { return }
                task = nil
                pending = nil
                onFinished()
            } catch is CancellationError {
                return
            } catch {
                guard let self, generation == token else { return }
                task = nil
                pending = nil
                onError(error)
            }
        }
    }
}
