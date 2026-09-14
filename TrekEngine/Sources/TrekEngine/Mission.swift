/// Game length and skill, after BSD trek's two opening questions.
/// Medium and good together are the unmodified 1978 game.
public enum MissionLength: String, CaseIterable, Hashable, Codable, Sendable {
    case short, medium, long

    /// Scales how often quadrants hold enemies.
    var enemyDensity: Double {
        switch self {
        case .short: 0.6
        case .medium: 1.0
        case .long: 1.6
        }
    }

    /// Scales the stardates allowed.
    var timeScale: Double {
        switch self {
        case .short: 0.8
        case .medium: 1.0
        case .long: 1.2
        }
    }

    var scoreMultiplier: Double {
        switch self {
        case .short: 0.75
        case .medium: 1.0
        case .long: 1.5
        }
    }
}

public enum Skill: String, CaseIterable, Hashable, Codable, Sendable {
    case novice, fair, good, expert, skilled

    /// Scales enemy shield strength, which also scales their fire.
    var enemyStrength: Double {
        switch self {
        case .novice: 0.6
        case .fair: 0.8
        case .good: 1.0
        case .expert: 1.25
        case .skilled: 1.5
        }
    }

    var scoreMultiplier: Double {
        switch self {
        case .novice: 0.5
        case .fair: 0.75
        case .good: 1.0
        case .expert: 1.5
        case .skilled: 2.0
        }
    }
}

public struct MissionProfile: Hashable, Codable, Sendable {
    public var length: MissionLength
    public var skill: Skill

    public init(length: MissionLength = .medium, skill: Skill = .good) {
        self.length = length
        self.skill = skill
    }

    /// The 1978 game exactly.
    public static let classic = MissionProfile()

    public var scoreMultiplier: Double { length.scoreMultiplier * skill.scoreMultiplier }
}
