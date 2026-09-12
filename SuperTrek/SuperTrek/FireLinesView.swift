import SwiftUI
import TrekEngine

/// A weapon discharge drawn across the grid for a moment.
struct Shot: Identifiable, Hashable {
    enum Kind: Hashable { case enemyFire, beam }
    var id: Int
    var from: SectorPosition
    var to: SectorPosition
    var kind: Kind
}

/// Draws shots as dashed lines whose dashes crawl toward the target and
/// fade out. Positioned over the sector grid using its cell geometry.
struct FireLinesView: View {
    static let duration: TimeInterval = 1.6
    let shots: [Shot]
    let cell: CGFloat
    let labelWidth: CGFloat
    let spacing: CGFloat
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let frozen = UserDefaults.standard.bool(forKey: "freezeBursts")
            let elapsed = frozen ? 0.5 : context.date.timeIntervalSince(start)
            let progress = min(1, elapsed / Self.duration)
            Canvas { ctx, _ in
                for shot in shots {
                    let a = center(of: shot.from)
                    let b = center(of: shot.to)
                    var line = Path()
                    line.move(to: a)
                    line.addLine(to: b)
                    let color = shot.kind == .enemyFire ? Theme.alert : Theme.phosphor
                    let fade = progress < 0.7 ? 1 : (1 - progress) / 0.3
                    let phase = -CGFloat(elapsed * 60)
                    ctx.stroke(
                        line,
                        with: .color(color.opacity(fade)),
                        style: StrokeStyle(lineWidth: shot.kind == .enemyFire ? 2.5 : 2, lineCap: .round, dash: [5, 7], dashPhase: phase)
                    )
                    // A small flare where the shot lands.
                    let flare = cell * 0.35 * CGFloat(1 - progress)
                    let dot = Path(ellipseIn: CGRect(x: b.x - flare, y: b.y - flare, width: flare * 2, height: flare * 2))
                    ctx.fill(dot, with: .color(color.opacity(0.6 * fade)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func center(of position: SectorPosition) -> CGPoint {
        CGPoint(
            x: labelWidth + spacing + CGFloat(position.col - 1) * (cell + spacing) + cell / 2,
            y: 12 + spacing + CGFloat(position.row - 1) * (cell + spacing) + cell / 2
        )
    }
}
