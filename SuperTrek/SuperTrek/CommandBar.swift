import SwiftUI
import TrekEngine

struct CommandBar: View {
    enum Action: CaseIterable {
        case navigate, shortRangeScan, longRangeScan
        case beams, torpedo, shields
        case damage, computer, resign
    }

    let lexicon: Lexicon
    let isPlaying: Bool
    var onCommand: (Action) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Action.allCases, id: \.self) { action in
                Button(code(action)) { onCommand(action) }
                    .buttonStyle(TerminalButtonStyle(tint: action == .resign ? Theme.alert : Theme.phosphor))
                    .disabled(!isPlaying)
                    .accessibilityLabel(label(action))
                    .accessibilityIdentifier("command.\(code(action))")
            }
        }
    }

    private func code(_ action: Action) -> String {
        switch action {
        case .navigate: "NAV"
        case .shortRangeScan: "SRS"
        case .longRangeScan: "LRS"
        case .beams: String(lexicon.beamWeapon.prefix(3))
        case .torpedo: "TOR"
        case .shields: "SHE"
        case .damage: "DAM"
        case .computer: "COM"
        case .resign: "XXX"
        }
    }

    private func label(_ action: Action) -> String {
        switch action {
        case .navigate: "Navigate"
        case .shortRangeScan: "Short range scan"
        case .longRangeScan: "Long range scan"
        case .beams: "Fire \(lexicon.beamWeapon.lowercased())s"
        case .torpedo: "Fire torpedo"
        case .shields: "Shield control"
        case .damage: "Damage report"
        case .computer: "Library computer"
        case .resign: "Resign command"
        }
    }
}
