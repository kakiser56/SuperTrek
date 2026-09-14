import SwiftUI
import TrekEngine

enum Theme {
    static let background = Color.black
    static let phosphor = Color(red: 0.2, green: 1.0, blue: 0.3)
    static let dim = Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.55)
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.2)
    static let alert = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let cyan = Color(red: 0.4, green: 0.9, blue: 1.0)
    static let warbird = Color(red: 1.0, green: 0.55, blue: 0.25)

    static func color(for kind: EnemyKind) -> Color {
        switch kind {
        case .cruiser: alert
        case .warbird: warbird
        }
    }

    static func mono(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func color(for content: SectorContent?) -> Color {
        switch content {
        case .ship: phosphor
        case .enemy: alert
        case .star: amber
        case .starbase: cyan
        case nil: dim
        }
    }

    static func color(for condition: Condition) -> Color {
        switch condition {
        case .docked: cyan
        case .red: alert
        case .yellow: amber
        case .green: phosphor
        }
    }
}

struct TerminalButtonStyle: ButtonStyle {
    var tint: Color = Theme.phosphor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(15, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(configuration.isPressed ? Theme.background : tint)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? tint : Theme.background)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(tint, lineWidth: 1))
    }
}
