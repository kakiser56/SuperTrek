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
            row("STARDATE", stardate)
            row("CONDITION", conditionText, color: Theme.color(for: game.condition))
            row("QUADRANT", "\(game.quadrant.row) , \(game.quadrant.col)")
            row("SECTOR", "\(game.sector.row) , \(game.sector.col)")
            row(lexicon.torpedoPlural, String(game.ship.torpedoes), color: game.ship.torpedoes == 0 ? Theme.amber : Theme.phosphor)
            row("TOTAL ENERGY", String(Int(game.ship.totalEnergy)), color: game.ship.energy < 300 ? Theme.amber : Theme.phosphor)
            row("SHIELDS", String(Int(game.ship.shields)), color: game.ship.shields < 200 && game.enemiesInQuadrant > 0 ? Theme.alert : Theme.phosphor)
            row("\(lexicon.enemyPlural) LEFT", String(game.enemiesRemaining), color: game.enemiesInQuadrant > 0 ? Theme.alert : Theme.phosphor)
        }
        .padding(.top, compact ? 4 : 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("readout")
    }

    private var stardate: String {
        game.stardate == game.stardate.rounded() ? String(Int(game.stardate)) : String(format: "%.1f", game.stardate)
    }

    private var conditionText: String {
        switch game.condition {
        case .docked: "DOCKED"
        case .red: "*RED*"
        case .yellow: "YELLOW"
        case .green: "GREEN"
        }
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
