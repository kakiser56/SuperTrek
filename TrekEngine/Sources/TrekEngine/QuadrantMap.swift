public enum SectorContent: String, Hashable, Codable, Sendable {
    case ship
    case enemy
    case star
    case starbase
}

/// The two kinds of invader. Cruisers are the original enemy. Warbirds
/// carry weaker shields but hit harder.
public enum EnemyKind: String, CaseIterable, Hashable, Codable, Sendable {
    case cruiser
    case warbird

    /// Shield strength on entering a quadrant, as a multiple of `Game.enemyBaseEnergy`.
    func initialEnergy(roll: Double) -> Double {
        switch self {
        case .cruiser: Game.enemyBaseEnergy * (0.5 + roll)
        case .warbird: Game.enemyBaseEnergy * (0.3 + 0.5 * roll)
        }
    }

    /// Scales the damage of each shot at the ship.
    var fireMultiplier: Double {
        switch self {
        case .cruiser: 1.0
        case .warbird: 1.3
        }
    }
}

/// An enemy warship in the current quadrant. Energy is its shield strength;
/// zero means destroyed.
public struct Enemy: Hashable, Codable, Sendable {
    public var position: SectorPosition
    public var energy: Double
    public var kind: EnemyKind

    public init(position: SectorPosition, energy: Double, kind: EnemyKind = .cruiser) {
        self.position = position
        self.energy = energy
        self.kind = kind
    }

    public var isAlive: Bool { energy > 0 }
}

/// The 8x8 sector grid of the quadrant the ship is in.
public struct QuadrantMap: Hashable, Codable, Sendable {
    public internal(set) var cells: [SectorContent?]

    public init() {
        cells = Array(repeating: nil, count: Game.gridSize * Game.gridSize)
    }

    static func index(_ position: SectorPosition) -> Int {
        (position.row - 1) * Game.gridSize + (position.col - 1)
    }

    public subscript(position: SectorPosition) -> SectorContent? {
        get { cells[QuadrantMap.index(position)] }
        set { cells[QuadrantMap.index(position)] = newValue }
    }

    public func isEmpty(at position: SectorPosition) -> Bool {
        self[position] == nil
    }

    public func positions(of content: SectorContent) -> [SectorPosition] {
        cells.indices.compactMap { i in
            cells[i] == content ? SectorPosition(row: i / Game.gridSize + 1, col: i % Game.gridSize + 1) : nil
        }
    }

    public var emptyPositions: [SectorPosition] {
        cells.indices.compactMap { i in
            cells[i] == nil ? SectorPosition(row: i / Game.gridSize + 1, col: i % Game.gridSize + 1) : nil
        }
    }

    /// Line 8590 of the listing: roll random sectors until an empty one turns up.
    mutating func randomEmptySector(using rng: inout SeededRandom) -> SectorPosition {
        precondition(cells.contains(nil), "quadrant is full")
        while true {
            let p = SectorPosition(row: rng.gridIndex(), col: rng.gridIndex())
            if isEmpty(at: p) { return p }
        }
    }
}
