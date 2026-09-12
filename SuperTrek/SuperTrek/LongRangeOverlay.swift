import SwiftUI
import TrekEngine

/// The 3x3 long range readout, floated over the sector grid until tapped.
struct LongRangeOverlay: View {
    let scan: LongRangeScan
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("LONG RANGE SCAN · \(scan.center.row),\(scan.center.col)")
                .font(Theme.mono(11, weight: .bold))
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { col in
                            let cell = scan.cells[row * 3 + col]
                            Text(label(cell))
                                .font(Theme.mono(18, weight: row == 1 && col == 1 ? .bold : .regular))
                                .foregroundStyle(color(cell, isCenter: row == 1 && col == 1))
                                .frame(width: 54, height: 38)
                                .background(Theme.phosphor.opacity(row == 1 && col == 1 ? 0.15 : 0.06))
                        }
                    }
                }
            }
            Text("ENEMIES·BASES·STARS  TAP TO DISMISS")
                .font(Theme.mono(8))
                .foregroundStyle(Theme.dim)
        }
        .padding(10)
        .background(Theme.background.opacity(0.96))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.phosphor, lineWidth: 1))
        .foregroundStyle(Theme.phosphor)
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lrs.overlay")
    }

    private func label(_ cell: LongRangeCell) -> String {
        switch cell {
        case .outsideGalaxy: "***"
        case let .quadrant(summary): String(format: "%03d", summary.code)
        }
    }

    private func color(_ cell: LongRangeCell, isCenter: Bool) -> Color {
        switch cell {
        case .outsideGalaxy: Theme.dim
        case let .quadrant(summary): summary.enemies > 0 ? Theme.alert : (isCenter ? Theme.phosphor : Theme.phosphor.opacity(0.8))
        }
    }
}
