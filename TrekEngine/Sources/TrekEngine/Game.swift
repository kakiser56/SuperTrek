import Foundation

public enum DefeatReason: String, Hashable, Codable, Sendable {
    case shipDestroyed
    case timeExpired
    case stranded
    case relievedOfCommand
    case resigned
}

public enum GameStatus: Hashable, Codable, Sendable {
    case playing
    case won(efficiency: Double)
    case lost(DefeatReason)

    public var isOver: Bool { self != .playing }
}

/// One complete game as a value. `apply` advances it by one command and
/// returns what happened. Encode it to save, decode it to resume.
public struct Game: Hashable, Codable, Sendable {
    public static let gridSize = 8
    public static let maxEnemiesPerQuadrant = 3
    /// S9 in the listing: the base shield strength of an enemy ship.
    public static let enemyBaseEnergy = 200.0
    /// Warp ceiling while the engines are damaged.
    public static let damagedWarpLimit = 0.2

    public let seed: UInt64
    var rng: SeededRandom

    public internal(set) var galaxy: Galaxy
    /// Z(8,8) in the listing: what the ship has charted. nil is unexplored.
    public internal(set) var chart: [QuadrantSummary?]
    public internal(set) var quadrant: QuadrantPosition
    public internal(set) var sector: SectorPosition
    public internal(set) var map: QuadrantMap
    public internal(set) var enemies: [Enemy]
    public internal(set) var ship: Ship
    public internal(set) var stardate: Double
    public let startingStardate: Double
    public internal(set) var missionDuration: Double
    public internal(set) var initialEnemyCount: Int
    public internal(set) var enemiesRemaining: Int
    public internal(set) var starbasesRemaining: Int
    public internal(set) var status: GameStatus
    public internal(set) var condition: Condition
    /// Set by a docked damage report; consumed by `authorizeRepairs`.
    public internal(set) var pendingRepairEstimate: Double?
    /// D4 in the listing: the random extra time repairs take in this quadrant.
    var repairPenalty: Double

    // MARK: Derived

    public var deadline: Double { startingStardate + missionDuration }
    public var stardatesRemaining: Double { deadline - stardate }
    public var enemiesInQuadrant: Int { enemies.filter(\.isAlive).count }
    public var starbaseInQuadrant: SectorPosition? { map.positions(of: .starbase).first }

    public func enemy(at position: SectorPosition) -> Enemy? {
        enemies.first { $0.isAlive && $0.position == position }
    }
    public var quadrantName: String { Regions.name(for: quadrant) }

    public func charted(_ position: QuadrantPosition) -> QuadrantSummary? {
        guard position.isInsideGalaxy else { return nil }
        return chart[Galaxy.index(position)]
    }

    // MARK: Creation

    /// Generates a new galaxy from the seed and returns the opening events:
    /// the briefing, the first quadrant, and the first scan.
    public static func start(seed: UInt64) -> (game: Game, events: [Event]) {
        var game = Game(seed: seed)
        var events: [Event] = [
            .missionBriefing(
                enemies: game.enemiesRemaining,
                deadline: game.deadline,
                days: game.missionDuration,
                starbases: game.starbasesRemaining
            ),
        ]
        events += game.enterQuadrant(firstEntry: true)
        return (game, events)
    }

    /// Lines 810 to 1200 of the listing.
    private init(seed: UInt64) {
        self.seed = seed
        var rng = SeededRandom(seed: seed)

        let stardate = Double(Int(rng.unit() * 20 + 20)) * 100
        self.stardate = stardate
        self.startingStardate = stardate
        self.missionDuration = Double(25 + Int(rng.unit() * 10))
        self.ship = Ship()
        self.status = .playing
        self.condition = .green
        self.pendingRepairEstimate = nil
        self.repairPenalty = 0

        var quadrant = QuadrantPosition(row: rng.gridIndex(), col: rng.gridIndex())
        self.sector = SectorPosition(row: rng.gridIndex(), col: rng.gridIndex())

        var summaries: [QuadrantSummary] = []
        var totalEnemies = 0
        var totalBases = 0
        for _ in 0..<(Game.gridSize * Game.gridSize) {
            let roll = rng.unit()
            let enemies: Int
            if roll > 0.98 {
                enemies = 3
            } else if roll > 0.95 {
                enemies = 2
            } else if roll > 0.80 {
                enemies = 1
            } else {
                enemies = 0
            }
            let bases = rng.unit() > 0.96 ? 1 : 0
            totalEnemies += enemies
            totalBases += bases
            summaries.append(QuadrantSummary(enemies: enemies, starbases: bases, stars: rng.gridIndex()))
        }
        var galaxy = Galaxy(quadrants: summaries)

        if Double(totalEnemies) > missionDuration {
            missionDuration = Double(totalEnemies + 1)
        }
        // The original guarantees a starbase by dropping one into the starting
        // quadrant (with an extra enemy if it was quiet) and then moving the
        // ship somewhere else.
        if totalBases == 0 {
            var home = galaxy[quadrant]
            if home.enemies < 2 {
                home.enemies += 1
                totalEnemies += 1
            }
            home.starbases += 1
            totalBases = 1
            galaxy[quadrant] = home
            quadrant = QuadrantPosition(row: rng.gridIndex(), col: rng.gridIndex())
        }
        // Not in the listing, but a galaxy with nothing to fight is unwinnable.
        if totalEnemies == 0 {
            var home = galaxy[quadrant]
            home.enemies = 1
            galaxy[quadrant] = home
            totalEnemies = 1
        }

        self.rng = rng
        self.galaxy = galaxy
        self.quadrant = quadrant
        self.chart = Array(repeating: nil, count: Game.gridSize * Game.gridSize)
        self.map = QuadrantMap()
        self.enemies = []
        self.initialEnemyCount = totalEnemies
        self.enemiesRemaining = totalEnemies
        self.starbasesRemaining = totalBases
    }

    // MARK: Turn loop

    /// Applies one command. Returns nothing once the game is over.
    @discardableResult
    public mutating func apply(_ command: Command) -> [Event] {
        guard status == .playing else { return [] }
        var events: [Event]
        switch command {
        case let .navigate(course, warp):
            events = navigate(course: course, warp: warp)
        case .shortRangeScan:
            events = shortRangeScan()
        case .longRangeScan:
            events = longRangeScan()
        case let .fireBeams(energy):
            events = fireBeams(energy: energy)
        case let .fireTorpedo(course):
            events = fireTorpedo(course: course)
        case let .setShields(energy):
            events = setShields(energy: energy)
        case .damageReport:
            events = damageReport()
        case let .authorizeRepairs(yes):
            events = authorizeRepairs(yes)
        case let .computer(function):
            events = computer(function)
        case .resign:
            events = resign()
        }
        if status == .playing {
            events += checkStranded()
        }
        return events
    }

    // MARK: Quadrant entry

    /// Line 1320: chart the quadrant, lay out its contents, and scan.
    mutating func enterQuadrant(firstEntry: Bool) -> [Event] {
        let summary = galaxy[quadrant]
        chart[Galaxy.index(quadrant)] = summary
        repairPenalty = 0.5 * rng.unit()

        var events: [Event] = [
            firstEntry ? .missionBegins(quadrantName: quadrantName) : .enteringQuadrant(quadrantName: quadrantName),
        ]
        if summary.enemies > 0 {
            events.append(.combatAreaConditionRed)
            if ship.shields <= 200 {
                events.append(.shieldsDangerouslyLow)
            }
        }

        map = QuadrantMap()
        map[sector] = .ship
        enemies = []
        for _ in 0..<summary.enemies {
            let p = map.randomEmptySector(using: &rng)
            map[p] = .enemy
            let kind: EnemyKind = rng.unit() < 0.5 ? .cruiser : .warbird
            enemies.append(Enemy(position: p, energy: kind.initialEnergy(roll: rng.unit()), kind: kind))
        }
        for _ in 0..<summary.starbases {
            let p = map.randomEmptySector(using: &rng)
            map[p] = .starbase
        }
        for _ in 0..<summary.stars {
            let p = map.randomEmptySector(using: &rng)
            map[p] = .star
        }
        events += shortRangeScan()
        return events
    }

    // MARK: Condition and docking

    /// Line 6430: docking happens as a side effect of looking around.
    mutating func refreshCondition() -> [Event] {
        var events: [Event] = []
        if let base = starbaseInQuadrant, base.isAdjacent(to: sector) {
            let announce = !ship.isDocked || ship.shields > 0
            ship.isDocked = true
            condition = .docked
            ship.energy = Ship.maxEnergy
            ship.torpedoes = Ship.maxTorpedoes
            ship.shields = 0
            if announce { events.append(.docked) }
        } else {
            ship.isDocked = false
            updateAlertCondition()
        }
        return events
    }

    mutating func updateAlertCondition() {
        if enemiesInQuadrant > 0 {
            condition = .red
        } else if ship.energy < Ship.maxEnergy * 0.1 {
            condition = .yellow
        } else {
            condition = .green
        }
    }

    // MARK: Endings

    /// Line 1990: out of maneuvering energy with no way to borrow from shields.
    mutating func checkStranded() -> [Event] {
        let stranded = ship.totalEnergy <= 10 || (ship.energy <= 10 && ship.isDamaged(.shieldControl))
        guard stranded else { return [] }
        status = .lost(.stranded)
        return [.stranded, defeatEvent()]
    }

    mutating func checkDeadline() -> [Event] {
        guard stardate > deadline else { return [] }
        status = .lost(.timeExpired)
        return [defeatEvent()]
    }

    func defeatEvent() -> Event {
        .defeat(stardate: stardate, enemiesRemaining: enemiesRemaining, canRestart: starbasesRemaining > 0)
    }

    mutating func resign() -> [Event] {
        status = .lost(.resigned)
        return [.resigned, defeatEvent()]
    }

    /// Line 6370: the efficiency rating is 1000 * (K7 / elapsed)^2.
    mutating func declareVictory() -> [Event] {
        let elapsed = max(stardate - startingStardate, 0.1)
        let rating = 1000 * pow(Double(initialEnemyCount) / elapsed, 2)
        status = .won(efficiency: rating)
        return [.victory(stardate: stardate, efficiency: rating)]
    }
}
