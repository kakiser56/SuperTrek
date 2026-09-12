extension Game {
    /// A hand-built situation for tests and previews. Only the current
    /// quadrant is laid out explicitly; the rest of the galaxy holds whatever
    /// `otherQuadrants` says, with one star everywhere else.
    public struct Fixture: Sendable {
        public var seed: UInt64 = 1
        public var quadrant = QuadrantPosition(row: 4, col: 4)
        public var sector = SectorPosition(row: 4, col: 4)
        public var enemies: [Enemy] = []
        public var stars: [SectorPosition] = []
        public var starbase: SectorPosition?
        public var ship = Ship()
        public var stardate: Double = 3000
        public var missionDuration: Double = 30
        public var otherQuadrants: [QuadrantPosition: QuadrantSummary] = [:]

        public init() {}
    }

    public init(fixture: Fixture) {
        seed = fixture.seed
        rng = SeededRandom(seed: fixture.seed)
        quadrant = fixture.quadrant
        sector = fixture.sector
        ship = fixture.ship
        stardate = fixture.stardate
        startingStardate = fixture.stardate
        missionDuration = fixture.missionDuration
        status = .playing
        condition = .green
        pendingRepairEstimate = nil
        repairPenalty = 0.25

        var quadrants = Array(
            repeating: QuadrantSummary(enemies: 0, starbases: 0, stars: 1),
            count: Game.gridSize * Game.gridSize
        )
        for (position, summary) in fixture.otherQuadrants {
            quadrants[Galaxy.index(position)] = summary
        }
        quadrants[Galaxy.index(fixture.quadrant)] = QuadrantSummary(
            enemies: fixture.enemies.count,
            starbases: fixture.starbase == nil ? 0 : 1,
            stars: fixture.stars.count
        )
        galaxy = Galaxy(quadrants: quadrants)
        chart = Array(repeating: nil, count: Game.gridSize * Game.gridSize)
        chart[Galaxy.index(fixture.quadrant)] = galaxy[fixture.quadrant]

        var map = QuadrantMap()
        map[fixture.sector] = .ship
        for enemy in fixture.enemies { map[enemy.position] = .enemy }
        for star in fixture.stars { map[star] = .star }
        if let base = fixture.starbase { map[base] = .starbase }
        self.map = map
        enemies = fixture.enemies

        initialEnemyCount = galaxy.totalEnemies
        enemiesRemaining = galaxy.totalEnemies
        starbasesRemaining = galaxy.totalStarbases
        _ = refreshCondition()
    }
}
