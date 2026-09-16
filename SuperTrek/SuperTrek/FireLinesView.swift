import SwiftUI
import TrekEngine

/// A weapon discharge drawn across the grid for a moment.
struct Shot: Identifiable, Hashable {
    enum Kind: Hashable { case enemyFire, beam, torpedo }
    var id: Int
    var from: SectorPosition
    var to: SectorPosition
    var kind: Kind
    /// When it was fired. Lives in the data so a view rebuild can't restart it.
    var fired = Date()
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

    var body: some View {
        TimelineView(.animation) { context in
            let frozen = UserDefaults.standard.bool(forKey: "freezeBursts")
            Canvas { ctx, _ in
                for shot in shots {
                    let elapsed = frozen ? 0.5 : context.date.timeIntervalSince(shot.fired)
                    let progress = min(1, elapsed / Self.duration)
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
                    // A torpedo is a projectile, not a beam: a circle crossing the grid, no line.
                    let travel = shot.kind == .torpedo ? min(1, progress / 0.45) : 1
                    let tip = CGPoint(x: a.x + (b.x - a.x) * travel, y: a.y + (b.y - a.y) * travel)
                    if shot.kind != .torpedo {
                        ctx.stroke(
                            line,
                            with: .color(color.opacity(fade)),
                            style: StrokeStyle(lineWidth: shot.kind == .beam ? 2 : 2.5, lineCap: .round, dash: [5, 7], dashPhase: phase)
                        )
                    } else if travel < 1 {
                        let radius = cell * 0.18
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: tip.x - radius * 2, y: tip.y - radius * 2, width: radius * 4, height: radius * 4)),
                            with: .color(color.opacity(0.3))
                        )
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: tip.x - radius, y: tip.y - radius, width: radius * 2, height: radius * 2)),
                            with: .color(color)
                        )
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: tip.x - radius * 0.5, y: tip.y - radius * 0.5, width: radius, height: radius)),
                            with: .color(Color.white.opacity(0.95))
                        )
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
