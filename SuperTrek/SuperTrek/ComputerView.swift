import SwiftUI
import TrekEngine

/// The library computer: a tappable galactic chart plus the report functions.
struct ComputerView: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game
    let lexicon: Lexicon
    var onFunction: (ComputerFunction) -> Void
    var onPlot: (QuadrantPosition) -> Void
    @State private var showRegions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LIBRARY-COMPUTER").font(Theme.mono(15, weight: .bold))
                Spacer()
                Button("CLOSE") { dismiss() }
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(Theme.dim)
            }
            Text(showRegions ? "GALAXY REGION MAP" : "GALACTIC RECORD  ·  TAP A QUADRANT TO PLOT A COURSE")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.dim)
            if showRegions {
                regionMap
            } else {
                chart
                Text("ENEMIES · BASES · STARS      *** UNCHARTED")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.dim)
            }
            VStack(spacing: 8) {
                row("1  STATUS REPORT", .statusReport)
                row("2  \(lexicon.torpedo) DATA", .torpedoData)
                row("3  STARBASE NAV DATA", .starbaseNavigationData)
                Button(showRegions ? "0  GALACTIC RECORD" : "5  GALAXY REGION MAP") { showRegions.toggle() }
                    .buttonStyle(TerminalButtonStyle(tint: Theme.dim))
            }
            Spacer(minLength: 0)
            FeedbackToggles()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Theme.phosphor)
        .background(Theme.background)
    }

    private var chart: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Color.clear.frame(width: 14, height: 10)
                ForEach(1...Game.gridSize, id: \.self) { col in
                    Text("\(col)").font(Theme.mono(9)).foregroundStyle(Theme.dim).frame(maxWidth: .infinity)
                }
            }
            ForEach(1...Game.gridSize, id: \.self) { row in
                GridRow {
                    Text("\(row)").font(Theme.mono(9)).foregroundStyle(Theme.dim).frame(width: 14)
                    ForEach(1...Game.gridSize, id: \.self) { col in
                        let position = QuadrantPosition(row: row, col: col)
                        let summary = game.charted(position)
                        let isHere = position == game.quadrant
                        Button {
                            guard !isHere else { return }
                            onPlot(position)
                            dismiss()
                        } label: {
                            Text(summary.map { String(format: "%03d", $0.code) } ?? "***")
                                .font(Theme.mono(11, weight: isHere ? .bold : .regular))
                                .foregroundStyle(color(summary, isHere: isHere))
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(isHere ? Theme.phosphor.opacity(0.2) : Theme.phosphor.opacity(0.06))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quadrant \(row) \(col)")
                        .accessibilityIdentifier("chart.\(row).\(col)")
                    }
                }
            }
        }
    }

    /// The 8x2 table of region names, with the current quadrant's row lit.
    private var regionMap: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 3) {
            GridRow {
                Text("").frame(width: 14)
                Text("1 - 4").font(Theme.mono(9)).foregroundStyle(Theme.dim).frame(maxWidth: .infinity, alignment: .leading)
                Text("5 - 8").font(Theme.mono(9)).foregroundStyle(Theme.dim).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(1...Game.gridSize, id: \.self) { row in
                GridRow {
                    Text("\(row)").font(Theme.mono(9)).foregroundStyle(Theme.dim).frame(width: 14)
                    ForEach([false, true], id: \.self) { right in
                        let isHere = row == game.quadrant.row && (game.quadrant.col > 4) == right
                        Text(Regions.regionName(row: row, rightHalf: right))
                            .font(Theme.mono(11, weight: isHere ? .bold : .regular))
                            .foregroundStyle(isHere ? Theme.phosphor : Theme.phosphor.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 30)
                            .padding(.horizontal, 6)
                            .background(Theme.phosphor.opacity(isHere ? 0.2 : 0.06))
                    }
                }
            }
        }
    }

    private func color(_ summary: QuadrantSummary?, isHere: Bool) -> Color {
        guard let summary else { return Theme.dim }
        if summary.enemies > 0 { return Theme.alert }
        if summary.starbases > 0 { return Theme.cyan }
        return isHere ? Theme.phosphor : Theme.phosphor.opacity(0.8)
    }

    private func row(_ title: String, _ function: ComputerFunction) -> some View {
        Button(title) {
            onFunction(function)
            dismiss()
        }
        .buttonStyle(TerminalButtonStyle(tint: Theme.dim))
    }
}
