import SwiftUI

/// A brief explosion: a white core that collapses while rays fly outward
/// and fade. Driven by a timeline so it animates without state.
struct StarBurstView: View {
    static let duration: TimeInterval = 0.8
    let size: CGFloat
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            // `-freezeBursts` holds the explosion mid-flight for screenshots.
            let frozen = UserDefaults.standard.bool(forKey: "freezeBursts")
            let progress = frozen ? 0.45 : min(1, context.date.timeIntervalSince(start) / Self.duration)
            Canvas { ctx, area in
                let center = CGPoint(x: area.width / 2, y: area.height / 2)
                let reach = area.width / 2 * CGFloat(progress)
                let fade = 1 - progress
                for i in 0..<16 {
                    let angle = Double(i) / 16 * 2 * .pi + 0.2
                    let inner = reach * 0.35
                    let outer = reach * (i % 2 == 0 ? 1 : 0.65)
                    var ray = Path()
                    ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                    ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                    let color = i % 2 == 0 ? Theme.amber : Theme.alert
                    ctx.stroke(ray, with: .color(color.opacity(fade)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                let coreRadius = size * 0.45 * CGFloat(1 - progress * progress)
                let core = Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2))
                ctx.fill(core, with: .color(Color.white.opacity(0.9 * fade + 0.1)))
                let glowRadius = coreRadius * 1.6
                let glow = Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2))
                ctx.fill(glow, with: .color(Theme.amber.opacity(0.35 * fade)))
            }
        }
        .frame(width: size * 3.4, height: size * 3.4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
