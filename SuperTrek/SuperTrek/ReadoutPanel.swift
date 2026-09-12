import SwiftUI
import TrekEngine

/// The eight-line readout that the original printed beside the sector grid.
struct ReadoutPanel: View {
    let game: Game
    let lexicon: Lexicon

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row("STARDATE", stardate)
            row("CONDITION", conditionText, color: Theme.color(for: game.condition))
            row("QUADRANT", "\(game.quadrant.row) , \(game.quadrant.col)")
            row("SECTOR", "\(game.sector.row) , \(game.sector.col)")
            row(lexicon.torpedoPlural, String(game.ship.torpedoes), color: game.ship.torpedoes == 0 ? Theme.amber : Theme.phosphor)
            row("TOTAL ENERGY", String(Int(game.ship.totalEnergy)), color: game.ship.energy < 300 ? Theme.amber : Theme.phosphor)
            row("SHIELDS", String(Int(game.ship.shields)), color: game.ship.shields < 200 && game.enemiesInQuadrant > 0 ? Theme.alert : Theme.phosphor)
            row("\(lexicon.enemyPlural) LEFT", String(game.enemiesRemaining), color: game.enemiesInQuadrant > 0 ? Theme.alert : Theme.phosphor)
        }
        .padding(.top, 14)
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

    private func row(_ label: String, _ value: String, color: Color = Theme.phosphor) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(value)
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .accessibilityIdentifier("readout.\(label)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.capitalized) \(value)")
    }
}
