import SwiftUI
import TrekEngine

enum SectorHighlight {
    case path
    case landing
    case blocked
    case track
    case impact
    case target

    var color: Color {
        switch self {
        case .path: Theme.phosphor.opacity(0.25)
        case .landing: Theme.phosphor.opacity(0.5)
        case .blocked: Theme.amber.opacity(0.5)
        case .track: Theme.alert.opacity(0.25)
        case .impact: Theme.alert.opacity(0.6)
        case .target: Theme.cyan.opacity(0.4)
        }
    }
}

/// The 8x8 sector grid. Tapping a sector reports its position.
struct SectorGridView: View {
    let game: Game
    var highlights: [SectorPosition: SectorHighlight] = [:]
    var bursts: [Burst] = []
    var shots: [Shot] = []
    var ghosts: [Ghost] = []
    var onTap: (SectorPosition) -> Void

    private let labelWidth: CGFloat = 14
    private let spacing: CGFloat = 2
    private var sensorsOut: Bool { game.ship.isDamaged(.shortRangeSensors) }

    var body: some View {
        GeometryReader { geometry in
            let cell = (geometry.size.width - labelWidth - spacing * CGFloat(Game.gridSize)) / CGFloat(Game.gridSize)
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                GridRow {
                    Color.clear.frame(width: labelWidth, height: 12)
                    ForEach(1...Game.gridSize, id: \.self) { col in
                        Text("\(col)").font(Theme.mono(10)).foregroundStyle(Theme.dim).frame(width: cell)
                    }
                }
                ForEach(1...Game.gridSize, id: \.self) { row in
                    GridRow {
                        Text("\(row)").font(Theme.mono(10)).foregroundStyle(Theme.dim).frame(width: labelWidth)
                        ForEach(1...Game.gridSize, id: \.self) { col in
                            let position = SectorPosition(row: row, col: col)
                            let ghost = ghosts.first { $0.position == position }
                            let content: SectorContent? = sensorsOut && game.map[position] != .ship ? nil : (ghost?.content ?? game.map[position])
                            Button {
                                onTap(position)
                            } label: {
                                let kind = content == .enemy ? (ghost?.kind ?? game.enemy(at: position)?.kind) : nil
                                Text(sensorsOut && content == nil ? "?" : glyph(for: content, kind: kind))
                                    .font(Theme.mono(13, weight: content == .ship ? .bold : .regular))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .foregroundStyle(kind.map(Theme.color(for:)) ?? Theme.color(for: content))
                                    .padding(2)
                                    .frame(width: cell, height: cell)
                                    .background(highlights[position]?.color ?? Theme.phosphor.opacity(0.06))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accessibilityLabel(for: content, at: position))
                            .accessibilityIdentifier("sector.\(row).\(col)")
                        }
                    }
                }
            }
            .overlay {
                if !shots.isEmpty {
                    FireLinesView(shots: shots, cell: cell, labelWidth: labelWidth, spacing: spacing)
                }
            }
            .overlay {
                ForEach(bursts) { burst in
                    StarBurstView(size: cell)
                        .position(
                            x: labelWidth + spacing + CGFloat(burst.position.col - 1) * (cell + spacing) + cell / 2,
                            y: 12 + spacing + CGFloat(burst.position.row - 1) * (cell + spacing) + cell / 2
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            if sensorsOut {
                Text("*** SHORT RANGE SENSORS ARE OUT ***")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .padding(8)
                    .background(Theme.background.opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.amber, lineWidth: 1))
                    .allowsHitTesting(false)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(game.condition == .red ? Theme.alert : Theme.dim, lineWidth: game.condition == .red ? 1.5 : 1).padding(-4))
    }

    private func glyph(for content: SectorContent?, kind: EnemyKind?) -> String {
        switch content {
        case .ship: "<*>"
        case .enemy: kind == .warbird ? "+R+" : "+K+"
        case .star: "*"
        case .starbase: ">!<"
        case nil: "·"
        }
    }

    private func accessibilityLabel(for content: SectorContent?, at position: SectorPosition) -> String {
        let what: String = switch content {
        case .ship: "your ship"
        case .enemy: game.enemy(at: position)?.kind == .warbird ? "enemy warbird" : "enemy cruiser"
        case .star: "star"
        case .starbase: "starbase"
        case nil: "empty"
        }
        return "Sector \(position.row) \(position.col), \(what)"
    }
}
