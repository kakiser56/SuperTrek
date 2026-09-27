import SwiftUI
import TrekEngine

/// The eight-line readout that the original printed beside the sector grid.
struct ReadoutPanel: View {
    let game: Game
    let lexicon: Lexicon
    /// Tighter type and spacing for 4.7-inch screens.
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 3) {
            ForEach(Self.items(game: game, lexicon: lexicon), id: \.label) { item in
                row(item.label, item.value, color: item.color)
            }
        }
        .padding(.top, compact ? 4 : 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("readout")
    }

    struct Item {
        var label: String
        var value: String
        var color: Color
    }

    /// The eight lines of the original readout, with their warning colors.
    static func items(game: Game, lexicon: Lexicon) -> [Item] {
        let stardate = game.stardate == game.stardate.rounded() ? String(Int(game.stardate)) : String(format: "%.1f", game.stardate)
        let condition = switch game.condition {
        case .docked: "DOCKED"
        case .red: "*RED*"
        case .yellow: "YELLOW"
        case .green: "GREEN"
        }
        let p = Theme.phosphor
        return [
            Item(label: "STARDATE", value: stardate, color: p),
            Item(label: "CONDITION", value: condition, color: Theme.color(for: game.condition)),
            Item(label: "QUADRANT", value: "\(game.quadrant.row) , \(game.quadrant.col)", color: p),
            Item(label: "SECTOR", value: "\(game.sector.row) , \(game.sector.col)", color: p),
            Item(label: lexicon.torpedoPlural, value: String(game.ship.torpedoes), color: game.ship.torpedoes == 0 ? Theme.amber : p),
            Item(label: "TOTAL ENERGY", value: String(Int(game.ship.totalEnergy)), color: game.ship.energy < 300 ? Theme.amber : p),
            Item(label: "SHIELDS", value: String(Int(game.ship.shields)), color: game.ship.shields < 200 && game.enemiesInQuadrant > 0 ? Theme.alert : p),
            Item(label: "\(lexicon.enemyPlural) LEFT", value: String(game.enemiesRemaining), color: game.enemiesInQuadrant > 0 ? Theme.alert : p),
        ]
    }

    /// Label over value, so the panel fits a narrow column.
    private func row(_ label: String, _ value: String, color: Color = Theme.phosphor) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Theme.mono(compact ? 7 : 8))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(Theme.mono(compact ? 11 : 12, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("readout.\(label)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.capitalized) \(value)")
    }
}
