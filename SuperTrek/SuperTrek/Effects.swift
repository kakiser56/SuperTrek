import SwiftUI
import TrekEngine

/// Sensory side effects of a turn: what to flash, buzz, and play.
struct TurnEffects: Equatable {
    var sounds: [GameSound] = []
    var hits = 0
    var enemyDestroyed = false
    var refused = false
    var ended = false

    static func derive(from command: Command, events: [Event], moved: Bool) -> TurnEffects {
        var fx = TurnEffects()
        switch command {
        case .navigate where moved:
            fx.sounds.append(.warp)
        case .fireBeams where events.contains(where: isBeamShot):
            fx.sounds.append(.laser)
        case .fireTorpedo where events.contains(where: isTorpedoShot):
            fx.sounds.append(.torpedo)
        default:
            break
        }
        for event in events {
            switch event {
            case .hitOnShip:
                fx.hits += 1
                fx.sounds.append(.hit)
            case .enemyDestroyed, .starbaseDestroyed, .shipDestroyed:
                fx.enemyDestroyed = true
                fx.sounds.append(.explosion)
            case .docked:
                fx.sounds.append(.dock)
            case .victory:
                fx.ended = true
                fx.sounds.append(.victory)
            case .defeat:
                fx.ended = true
                fx.sounds.append(.defeat)
            case .incorrectCourse, .enginesWontTake, .insufficientEnergy, .warpEnginesDamaged,
                 .warpEnginesShutDown, .perimeterCrossingDenied, .beamControlDisabled, .notEnoughEnergy,
                 .torpedoesExpended, .torpedoTubesInoperable, .shieldControlInoperable, .notTheTreasury,
                 .computerDisabled, .longRangeSensorsInoperable, .shortRangeSensorsOut, .damageReportUnavailable:
                fx.refused = true
                fx.sounds.append(.error)
            default:
                break
            }
        }
        return fx
    }

    private static func isBeamShot(_ event: Event) -> Bool {
        if case .beamHit = event { return true }
        if case .beamNoDamage = event { return true }
        return false
    }

    private static func isTorpedoShot(_ event: Event) -> Bool {
        if case .torpedoTrack = event { return true }
        return false
    }
}

/// User preferences for feedback. Stored in UserDefaults.
enum FeedbackSettings {
    static let soundKey = "soundEnabled"
    static let hapticsKey = "hapticsEnabled"

    static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
    }

    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
}

struct FeedbackToggles: View {
    @AppStorage(FeedbackSettings.soundKey) private var sound = true
    @AppStorage(FeedbackSettings.hapticsKey) private var haptics = true

    var body: some View {
        HStack(spacing: 8) {
            Button("SOUND \(sound ? "ON" : "OFF")") { sound.toggle() }
                .buttonStyle(TerminalButtonStyle(tint: sound ? Theme.phosphor : Theme.dim))
                .accessibilityIdentifier("settings.sound")
            Button("HAPTICS \(haptics ? "ON" : "OFF")") { haptics.toggle() }
                .buttonStyle(TerminalButtonStyle(tint: haptics ? Theme.phosphor : Theme.dim))
                .accessibilityIdentifier("settings.haptics")
        }
    }
}
