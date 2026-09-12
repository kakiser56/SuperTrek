import SwiftUI
import TrekEngine

/// What the bottom of the bridge is doing right now.
enum PanelMode: Equatable {
    case commands
    case navigation(course: Double, warp: Double)
    case torpedo(course: Double)
    case beams(energy: Double)
    case shields(energy: Double)
}

private struct PanelFrame<Content: View>: View {
    let title: String
    var onCancel: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(Theme.mono(11, weight: .bold)).foregroundStyle(Theme.dim).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Button("CANCEL", action: onCancel)
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundStyle(Theme.dim)
                    .accessibilityIdentifier("panel.cancel")
            }
            content
        }
        .foregroundStyle(Theme.phosphor)
    }
}

struct NavigationPanel: View {
    let game: Game
    let lexicon: Lexicon
    @Binding var course: Double
    @Binding var warp: Double
    var onEngage: () -> Void
    var onCancel: () -> Void

    private var maxWarp: Double { game.ship.isDamaged(.warpEngines) ? Game.damagedWarpLimit : 8 }
    private var preview: NavigationPreview? { game.previewNavigation(course: course, warp: warp) }

    var body: some View {
        PanelFrame(title: "NAVIGATION · TAP A SECTOR OR DRAG", onCancel: onCancel) {
            HStack(alignment: .top, spacing: 14) {
                CourseDial(course: $course)
                    .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        readout("COURSE", String(format: "%.2f", course))
                        readout("WARP", warpText(warp))
                    }
                    Slider(value: $warp, in: 0.1...maxWarp, step: 0.1)
                        .tint(Theme.phosphor)
                        .accessibilityIdentifier("nav.warp")
                    Text(summary)
                        .font(Theme.mono(10))
                        .foregroundStyle(summaryColor)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("ENGAGE", action: onEngage)
                        .buttonStyle(TerminalButtonStyle())
                        .disabled(preview == nil || preview?.insufficientEnergy == true)
                        .accessibilityIdentifier("nav.engage")
                }
            }
        }
        .onChange(of: maxWarp, initial: true) { _, limit in
            if warp > limit { warp = limit }
        }
    }

    private var summary: String {
        guard let preview else { return "INVALID COURSE" }
        var parts = ["\(preview.steps) SECTORS", "\(preview.energyCost) ENERGY", String(format: "%.1f STARDATES", preview.stardateCost)]
        if preview.insufficientEnergy {
            parts.append("INSUFFICIENT ENERGY")
        } else if preview.perimeterDenied {
            parts.append("GALACTIC PERIMETER — DENIED")
        } else if let blocked = preview.blockedBy {
            parts.append("BLOCKED AT \(blocked.row),\(blocked.col)")
        } else if let q = preview.destinationQuadrant {
            parts.append("TO QUADRANT \(q.row),\(q.col)")
        } else if let landing = preview.landing {
            parts.append("TO SECTOR \(landing.row),\(landing.col)")
        }
        return parts.joined(separator: "  ·  ")
    }

    private var summaryColor: Color {
        guard let preview else { return Theme.alert }
        if preview.insufficientEnergy || preview.perimeterDenied || preview.blockedBy != nil { return Theme.amber }
        return Theme.dim
    }
}

struct TorpedoPanel: View {
    let game: Game
    let lexicon: Lexicon
    @Binding var course: Double
    var onFire: () -> Void
    var onCancel: () -> Void

    private var preview: TorpedoPreview? { game.previewTorpedo(course: course) }

    var body: some View {
        PanelFrame(title: "\(lexicon.torpedo) CONTROL · TAP A TARGET OR DRAG", onCancel: onCancel) {
            HStack(alignment: .top, spacing: 14) {
                CourseDial(course: $course, tint: Theme.alert)
                    .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        readout("COURSE", String(format: "%.2f", course))
                        readout("TUBES", String(game.ship.torpedoes))
                    }
                    Text(summary)
                        .font(Theme.mono(10))
                        .foregroundStyle(preview?.target == .enemy ? Theme.phosphor : Theme.amber)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("FIRE", action: onFire)
                        .buttonStyle(TerminalButtonStyle(tint: Theme.alert))
                        .disabled(game.ship.torpedoes == 0 || game.ship.isDamaged(.torpedoTubes) || preview == nil)
                        .accessibilityIdentifier("torpedo.fire")
                }
                .frame(maxHeight: 118)
            }
        }
    }

    private var summary: String {
        if game.ship.isDamaged(.torpedoTubes) { return "\(lexicon.torpedo) TUBES ARE NOT OPERATIONAL" }
        if game.ship.torpedoes == 0 { return "ALL \(lexicon.torpedoPlural) EXPENDED" }
        guard let preview, let last = preview.track.last else { return "INVALID COURSE" }
        switch preview.target {
        case .enemy: return "TRACK ENDS ON \(lexicon.enemyName) AT \(last.row),\(last.col)"
        case .star: return "TRACK ENDS ON STAR AT \(last.row),\(last.col)"
        case .starbase: return "TRACK ENDS ON STARBASE AT \(last.row),\(last.col) — DO NOT FIRE"
        case .ship, nil: return "TRACK LEAVES THE QUADRANT — MISS"
        }
    }
}

struct EnergyPanel: View {
    let title: String
    let prompt: String
    let action: String
    let maximum: Int
    let tint: Color
    @Binding var value: Double
    var onCommit: () -> Void
    var onCancel: () -> Void

    var body: some View {
        PanelFrame(title: title, onCancel: onCancel) {
            HStack {
                Text(prompt).font(Theme.mono(11)).foregroundStyle(Theme.dim)
                Spacer()
                Text(String(Int(value))).font(Theme.mono(22, weight: .bold))
                Text("/ " + String(maximum)).font(Theme.mono(11)).foregroundStyle(Theme.dim)
            }
            Slider(value: $value, in: 0...Double(max(maximum, 1)), step: 10)
                .tint(tint)
                .disabled(maximum == 0)
                .accessibilityIdentifier("energy.slider")
            HStack(spacing: 8) {
                ForEach([100, 250, 500, 1000], id: \.self) { preset in
                    Button(String(preset)) { value = Double(min(preset, maximum)) }
                        .buttonStyle(TerminalButtonStyle(tint: Theme.dim))
                        .disabled(preset > maximum)
                }
                Button(action, action: onCommit)
                    .buttonStyle(TerminalButtonStyle(tint: tint))
                    .accessibilityIdentifier("energy.commit")
            }
        }
    }
}

/// Warp factors are tenths from the slider but eighths from a plotted course.
private func warpText(_ warp: Double) -> String {
    var s = String(format: "%.3f", warp)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

private func readout(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        Text(label).font(Theme.mono(9)).foregroundStyle(Theme.dim)
        Text(value).font(Theme.mono(16, weight: .bold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
