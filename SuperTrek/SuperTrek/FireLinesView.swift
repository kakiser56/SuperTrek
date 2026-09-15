import SwiftUI
import TrekEngine

/// A weapon discharge drawn across the grid for a moment.
struct Shot: Identifiable, Hashable {
    enum Kind: Hashable { case enemyFire, beam, torpedo }
    var id: Int
    var from: SectorPosition
    var to: SectorPosition
    var kind: Kind
}

/// Draws shots as dashed lines whose dashes crawl toward the target and
/// fade out. Positioned over the sector grid using its cell geometry.
struct FireLinesView: View {
    static let duration: TimeInterval = 1.6
    /// How long a torpedo takes to cross to its target: the first part of the animation.
    static let torpedoFlightTime: TimeInterval = duration * 0.45
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
                    let color: Color = switch shot.kind {
                    case .enemyFire: Theme.alert
                    case .beam: Theme.phosphor
                    case .torpedo: Theme.amber
                    }
                    let fade = progress < 0.7 ? 1 : (1 - progress) / 0.3
                    let phase = -CGFloat(elapsed * 60)
                    // A torpedo's trail only exists as far as the torpedo has flown.
                    let travel = shot.kind == .torpedo ? min(1, progress / 0.45) : 1
                    let tip = CGPoint(x: a.x + (b.x - a.x) * travel, y: a.y + (b.y - a.y) * travel)
                    if shot.kind == .torpedo {
                        line = Path()
                        line.move(to: a)
                        line.addLine(to: tip)
                    }
                    ctx.stroke(
                        line,
                        with: .color(color.opacity(fade)),
                        style: StrokeStyle(lineWidth: shot.kind == .beam ? 2 : 2.5, lineCap: .round, dash: [5, 7], dashPhase: phase)
                    )
                    if shot.kind == .torpedo, travel < 1 {
                        // The torpedo itself, in flight.
                        let head = Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y - 4, width: 8, height: 8))
                        ctx.fill(head, with: .color(Color.white.opacity(0.95)))
                        ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 8, y: tip.y - 8, width: 16, height: 16)), with: .color(color.opacity(0.4)))
                    }
                    // A small flare where the shot lands.
                    if travel >= 1 {
                        let flare = cell * 0.35 * CGFloat(1 - progress)
                        let dot = Path(ellipseIn: CGRect(x: b.x - flare, y: b.y - flare, width: flare * 2, height: flare * 2))
                        ctx.fill(dot, with: .color(color.opacity(0.6 * fade)))
                    }
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
