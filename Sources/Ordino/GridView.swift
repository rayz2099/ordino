import SwiftUI
import LayoutCore

struct GridView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let columns: Int
    let rows: Int
    let selection: GridSelection?
    let cursor: GridCell

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(columns)
            let cellH = geo.size.height / CGFloat(rows)
            ZStack {
                if reduceTransparency {
                    Color.black.opacity(0.72)
                } else {
                    Color.black.opacity(0.36)
                }
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { col in
                        let cell = GridCell(column: col, row: row)
                        let selected = selection?.contains(cell) == true
                        Rectangle()
                            .fill(selected ? Color.accentColor.opacity(0.42) : Color.clear)
                            .overlay(
                                Rectangle().strokeBorder(
                                    selected ? Color.accentColor : Color.white.opacity(0.24),
                                    lineWidth: selected && differentiateWithoutColor ? 2 : 1
                                )
                            )
                            .frame(width: cellW, height: cellH)
                            .position(
                                x: CGFloat(col) * cellW + cellW / 2,
                                y: CGFloat(row) * cellH + cellH / 2
                            )
                    }
                }
                let cursorRect = CGRect(
                    x: CGFloat(cursor.column) * cellW,
                    y: CGFloat(cursor.row) * cellH,
                    width: cellW,
                    height: cellH
                )
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .frame(width: cursorRect.width, height: cursorRect.height)
                    .position(x: cursorRect.midX, y: cursorRect.midY)
            }
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("窗口布局网格，\(columns) 列，\(rows) 行")
        .accessibilityValue("当前第 \(cursor.column + 1) 列，第 \(cursor.row + 1) 行")
    }
}

struct GridCell: Equatable {
    var column: Int
    var row: Int
}

struct GridSelection: Equatable {
    var start: GridCell
    var end: GridCell

    func contains(_ cell: GridCell) -> Bool {
        let cols = min(start.column, end.column)...max(start.column, end.column)
        let rows = min(start.row, end.row)...max(start.row, end.row)
        return cols.contains(cell.column) && rows.contains(cell.row)
    }

    func relativeFrame(columns: Int, rows: Int) -> RelativeFrame {
        let x0 = Double(min(start.column, end.column))
        let y0 = Double(min(start.row, end.row))
        let x1 = Double(max(start.column, end.column) + 1)
        let y1 = Double(max(start.row, end.row) + 1)
        return RelativeFrame(
            x: x0 / Double(columns),
            y: y0 / Double(rows),
            width: (x1 - x0) / Double(columns),
            height: (y1 - y0) / Double(rows)
        )
    }
}
