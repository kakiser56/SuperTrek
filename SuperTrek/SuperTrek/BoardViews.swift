import SwiftUI
import TrekEngine

/// A titled, outlined panel for the iPad board.
struct BoardBox<Content: View>: View {
    let title: String?
    var tint: Color = Theme.dim
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(Theme.mono(12)).foregroundStyle(Theme.dim).lineLimit(1).minimumScaleFactor(0.7)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(tint, lineWidth: 1))
    }
}

/// The eight readout values laid out in a grid of large type.
struct ReadoutBoard: View {
    let game: Game
    let lexicon: Lexicon
    var columns = 4

    var body: some View {
        let items = ReadoutPanel.items(game: game, lexicon: lexicon)
        BoardBox(title: nil) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
                ForEach(0..<(items.count / columns), id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { col in
                            let item = items[row * columns + col]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label).font(Theme.mono(11)).foregroundStyle(Theme.dim).lineLimit(1).minimumScaleFactor(0.7)
                                Text(item.value).font(Theme.mono(22, weight: .bold)).foregroundStyle(item.color)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                                    .accessibilityIdentifier("readout.\(item.label)")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(item.label.capitalized) \(item.value)")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("readout")
    }
}

private func codeColor(_ summary: QuadrantSummary?, isHere: Bool) -> Color {
    guard let summary else { return Theme.dim.opacity(0.5) }
    if summary.enemies > 0 { return Theme.alert }
    if summary.starbases > 0 { return Theme.cyan }
    return isHere ? Theme.phosphor : Theme.phosphor.opacity(0.85)
}

/// The library computer's galactic record, always on screen. Tap a quadrant to plot to it.
struct GalacticChartBoard: View {
    let game: Game
    var onPlot: (QuadrantPosition) -> Void

    var body: some View {
        BoardBox(title: "GALACTIC RECORD · TAP TO PLOT A COURSE") {
            GeometryReader { geometry in
                let label: CGFloat = 18
                let w = (geometry.size.width - label) / 8
                let h = (geometry.size.height - label) / 8
                let font = min(15, max(10, min(w, h) * 0.28))
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: label, height: label)
                        ForEach(1...Game.gridSize, id: \.self) { col in
                            Text("\(col)").font(Theme.mono(10)).foregroundStyle(Theme.dim).frame(width: w, height: label)
                        }
                    }
                    ForEach(1...Game.gridSize, id: \.self) { row in
                        HStack(spacing: 0) {
                            Text("\(row)").font(Theme.mono(10)).foregroundStyle(Theme.dim).frame(width: label, height: h)
                            ForEach(1...Game.gridSize, id: \.self) { col in
                                let q = QuadrantPosition(row: row, col: col)
                                let here = q == game.quadrant
                                let summary = game.charted(q)
                                Button {
                                    if !here { onPlot(q) }
                                } label: {
                                    Text(summary.map { String(format: "%03d", $0.code) } ?? "***")
                                        .font(Theme.mono(font, weight: here ? .bold : .regular))
                                        .foregroundStyle(codeColor(summary, isHere: here))
                                        .frame(width: w - 3, height: h - 3)
                                        .background(Theme.phosphor.opacity(here ? 0.22 : 0.06))
                                }
                                .buttonStyle(.plain)
                                .frame(width: w, height: h)
                                .accessibilityLabel("Quadrant \(row) \(col)")
                                .accessibilityIdentifier("board.chart.\(row).\(col)")
                            }
                        }
                    }
                }
            }
        }
    }
}

/// The 3x3 neighborhood from the ship's record, refreshed by every long range scan.
struct LongRangeBoard: View {
    let game: Game

    var body: some View {
        BoardBox(title: "LONG RANGE SCAN · \(game.quadrant.row),\(game.quadrant.col)") {
            GeometryReader { geometry in
                let w = (geometry.size.width - 8) / 3
                let h = (geometry.size.height - 8 - 18) / 3
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(-1...1, id: \.self) { dr in
                        HStack(spacing: 4) {
                            ForEach(-1...1, id: \.self) { dc in
                                let q = QuadrantPosition(row: game.quadrant.row + dr, col: game.quadrant.col + dc)
                                let here = dr == 0 && dc == 0
                                let summary = game.charted(q)
                                Text(q.isInsideGalaxy ? (summary.map { String(format: "%03d", $0.code) } ?? "···") : "***")
                                    .font(Theme.mono(min(22, h * 0.34), weight: here ? .bold : .regular))
                                    .foregroundStyle(q.isInsideGalaxy ? codeColor(summary, isHere: here) : Theme.dim)
                                    .frame(width: w, height: h)
                                    .background(Theme.phosphor.opacity(here ? 0.2 : 0.06))
                            }
                        }
                    }
                    Text("ENEMIES · BASES · STARS").font(Theme.mono(10)).foregroundStyle(Theme.dim).frame(height: 14)
                }
            }
        }
        .accessibilityIdentifier("board.lrs")
    }
}

/// What the sensor glyphs mean.
struct LegendBoard: View {
    let lexicon: Lexicon

    var body: some View {
        BoardBox(title: "SENSOR LEGEND") {
            VStack(alignment: .leading, spacing: 10) {
                entry(lexicon.shipGlyph, "YOUR SHIP", Theme.phosphor)
                entry(lexicon.enemyGlyph, lexicon.cruiserName, Theme.alert)
                entry(lexicon.warbirdGlyph, lexicon.warbirdName, Theme.warbird)
                entry(lexicon.starbaseGlyph, "STARBASE", Theme.cyan)
                entry(" * ", "STAR", Theme.amber)
            }
        }
    }

    private func entry(_ glyph: String, _ name: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Text(glyph).font(Theme.mono(16, weight: .bold)).foregroundStyle(color).frame(width: 44, alignment: .leading)
            Text(name).font(Theme.mono(13)).foregroundStyle(Theme.phosphor.opacity(0.85)).lineLimit(1).fixedSize()
        }
    }
}
