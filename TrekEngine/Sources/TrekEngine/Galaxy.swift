/// What the galaxy record knows about one quadrant: the K*100 + B*10 + S code
/// from the original, kept as three fields.
public struct QuadrantSummary: Hashable, Codable, Sendable {
    public var enemies: Int
    public var starbases: Int
    public var stars: Int

    public init(enemies: Int, starbases: Int, stars: Int) {
        self.enemies = enemies
        self.starbases = starbases
        self.stars = stars
    }

    /// The three-digit code the original printed, e.g. 207.
    public var code: Int { enemies * 100 + starbases * 10 + stars }
}

/// The 8x8 galaxy. Truth, as opposed to the chart the ship has recorded.
public struct Galaxy: Hashable, Codable, Sendable {
    public internal(set) var quadrants: [QuadrantSummary]

    init(quadrants: [QuadrantSummary]) {
        precondition(quadrants.count == Game.gridSize * Game.gridSize)
        self.quadrants = quadrants
    }

    static func index(_ position: QuadrantPosition) -> Int {
        (position.row - 1) * Game.gridSize + (position.col - 1)
    }

    public subscript(position: QuadrantPosition) -> QuadrantSummary {
        get { quadrants[Galaxy.index(position)] }
        set { quadrants[Galaxy.index(position)] = newValue }
    }

    public var totalEnemies: Int { quadrants.reduce(0) { $0 + $1.enemies } }
    public var totalStarbases: Int { quadrants.reduce(0) { $0 + $1.starbases } }

    public static var allPositions: [QuadrantPosition] {
        (1...Game.gridSize).flatMap { row in
            (1...Game.gridSize).map { col in QuadrantPosition(row: row, col: col) }
        }
    }
}

/// Region names. These are real stars, not franchise property, so they stay.
public enum Regions {
    static let left = ["ANTARES", "RIGEL", "PROCYON", "VEGA", "CANOPUS", "ALTAIR", "SAGITTARIUS", "POLLUX"]
    static let right = ["SIRIUS", "DENEB", "CAPELLA", "BETELGEUSE", "ALDEBARAN", "REGULUS", "ARCTURUS", "SPICA"]
    static let numerals = ["I", "II", "III", "IV"]

    /// e.g. "ANTARES III" for row 1, column 3.
    public static func name(for position: QuadrantPosition) -> String {
        let half = position.col <= 4 ? left : right
        let region = half[max(0, min(7, position.row - 1))]
        let numeral = numerals[max(0, min(3, (position.col - 1) % 4))]
        return "\(region) \(numeral)"
    }

    /// The region name without the numeral, as the galaxy map prints it.
    public static func regionName(row: Int, rightHalf: Bool) -> String {
        (rightHalf ? right : left)[max(0, min(7, row - 1))]
    }
}
