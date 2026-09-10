import AppKit
import SwiftUI
import LayoutCore

/// Grid 画在目标窗口所在 Display 的工作区上，拖拽或键盘选出 Relative Frame。
@MainActor
final class GridController {
    var onApply: ((RelativeFrame) -> Void)?
    var onCancel: (() -> Void)?

    private var panel: NSPanel?
    private var host: NSHostingView<GridView>?
    private var columns = 6
    private var rows = 4
    private var cursor = GridCell(column: 0, row: 0)
    private var selection: GridSelection?
    private var dragging = false
    private var workArea = PixelRect(x: 0, y: 0, width: 0, height: 0)
    private var localMonitor: Any?

    var isVisible: Bool { panel?.isVisible == true }

    func show(workArea: PixelRect, columns: Int, rows: Int) throws {
        self.columns = columns
        self.rows = rows
        self.workArea = workArea
        cursor = GridCell(column: 0, row: 0)
        selection = GridSelection(start: cursor, end: cursor)
        dragging = false
        let cocoa = try DisplayMap.cocoaRect(fromAX: workArea)
        let view = GridView(columns: columns, rows: rows, selection: selection, cursor: cursor)
        let hosting: NSHostingView<GridView>
        if let host {
            host.rootView = view
            hosting = host
        } else {
            hosting = NSHostingView(rootView: view)
            host = hosting
        }
        let panel = makePanel()
        panel.setFrame(cocoa, display: true)
        hosting.frame = NSRect(origin: .zero, size: cocoa.size)
        if panel.contentView !== hosting {
            panel.contentView = hosting
        }
        panel.orderFrontRegardless()
        self.panel = panel
        installMouse()
        render()
    }

    func hide() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        panel?.orderOut(nil)
        selection = nil
        dragging = false
    }

    func handleKey(code: UInt16, modifiers: KeyModifiers) -> Bool {
        if !isVisible { return false }
        if code == HardwareKey.escape {
            onCancel?()
            return true
        }
        if code == HardwareKey.returnKey {
            commit()
            return true
        }
        if let edge = edge(for: code) {
            moveCursor(edge, extend: modifiers.contains(.shift))
            return true
        }
        return false
    }

    private func edge(for code: UInt16) -> LayoutCore.Edge? {
        switch code {
        case HardwareKey.left, HardwareKey.h: return .left
        case HardwareKey.right, HardwareKey.l: return .right
        case HardwareKey.up, HardwareKey.k: return .top
        case HardwareKey.down, HardwareKey.j: return .bottom
        default: return nil
        }
    }

    private func moveCursor(_ edge: LayoutCore.Edge, extend: Bool) {
        var next = cursor
        switch edge {
        case .left: next.column = max(0, cursor.column - 1)
        case .right: next.column = min(columns - 1, cursor.column + 1)
        case .top: next.row = max(0, cursor.row - 1)
        case .bottom: next.row = min(rows - 1, cursor.row + 1)
        }
        cursor = next
        if extend, let selection {
            self.selection = GridSelection(start: selection.start, end: next)
        } else {
            selection = GridSelection(start: next, end: next)
        }
        render()
    }

    private func installMouse() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouse(event)
            return nil
        }
    }

    private func handleMouse(_ event: NSEvent) {
        guard let panel, let content = panel.contentView else { return }
        let local = content.convert(event.locationInWindow, from: nil)
        let cell = cell(at: local, in: content.bounds)
        switch event.type {
        case .leftMouseDown:
            dragging = true
            cursor = cell
            selection = GridSelection(start: cell, end: cell)
            render()
        case .leftMouseDragged:
            if dragging {
                cursor = cell
                if let start = selection?.start {
                    selection = GridSelection(start: start, end: cell)
                    render()
                }
            }
        case .leftMouseUp:
            if dragging {
                dragging = false
                commit()
            }
        default:
            break
        }
    }

    private func cell(at point: NSPoint, in bounds: NSRect) -> GridCell {
        let x = min(max(point.x, 0), bounds.width - 1)
        let y = min(max(point.y, 0), bounds.height - 1)
        let col = Int(x / bounds.width * CGFloat(columns))
        let cocoaRow = Int(y / bounds.height * CGFloat(rows))
        let row = rows - 1 - cocoaRow
        return GridCell(column: min(columns - 1, col), row: min(rows - 1, row))
    }

    private func commit() {
        guard let selection else { return }
        onApply?(selection.relativeFrame(columns: columns, rows: rows))
    }

    private func render() {
        guard let panel, let host else { return }
        host.rootView = GridView(columns: columns, rows: rows, selection: selection, cursor: cursor)
        host.frame = panel.contentView?.bounds ?? .zero
    }

    private func makePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Chrome 铺满会盖住 statusBar；Grid 必须和 Overlay 同一层，否则铺满后既点不到 Grid 也点不到页。
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}
