/// A snapshot of the short range scan: the sector grid plus the side panel.
public struct ScanSnapshot: Hashable, Codable, Sendable {
    public var cells: [SectorContent?]
    public var enemies: [Enemy]
    public var stardate: Double
    public var condition: Condition
    public var quadrant: QuadrantPosition
    public var sector: SectorPosition
    public var torpedoes: Int
    public var totalEnergy: Int
    public var shields: Int
    public var enemiesRemaining: Int
}

public enum LongRangeCell: Hashable, Codable, Sendable {
    case outsideGalaxy
    case quadrant(QuadrantSummary)
}

public struct EnemyTargetData: Hashable, Codable, Sendable {
    public var position: SectorPosition
    public var navigation: NavigationData
}

/// Everything the engine wants to tell the crew. The engine emits these; the
/// narrator turns them into teletype text and the app turns them into UI.
public enum Event: Hashable, Codable, Sendable {
    // Opening
    case missionBriefing(enemies: Int, deadline: Double, days: Double, starbases: Int)
    case missionProfile(length: MissionLength, skill: Skill)
    case missionBegins(quadrantName: String)
    case enteringQuadrant(quadrantName: String)
    case combatAreaConditionRed
    case shieldsDangerouslyLow

    // Scans and docking
    case shortRangeScan(ScanSnapshot)
    case shortRangeSensorsOut
    case docked
    case longRangeScan(center: QuadrantPosition, cells: [LongRangeCell])
    case longRangeSensorsInoperable

    // Navigation
    case incorrectCourse
    case warpEnginesDamaged(maxWarp: Double)
    case enginesWontTake(warp: Double)
    case insufficientEnergy(warp: Double, shieldsDeployed: Int?)
    case warpEnginesShutDown(at: SectorPosition)
    case perimeterCrossingDenied(quadrant: QuadrantPosition, sector: SectorPosition)
    case shieldControlSuppliedEnergy
    case repairCompleted(Device)
    case deviceDamagedRandomly(Device)
    case deviceImproved(Device)

    // Enemy fire
    case starbaseShieldsProtect
    case hitOnShip(units: Int, from: SectorPosition, kind: EnemyKind, shieldsRemaining: Int)
    case deviceDamagedByHit(Device)
    case shipDestroyed

    // Beam weapons
    case noEnemiesInQuadrant
    case beamControlDisabled
    case computerFailureHampersAccuracy
    case notEnoughEnergy(available: Int)
    case beamHit(units: Int, at: SectorPosition, remaining: Int)
    case beamNoDamage(at: SectorPosition)
    case enemyDestroyed(at: SectorPosition, kind: EnemyKind)

    // Torpedoes
    case torpedoesExpended
    case torpedoTubesInoperable
    case torpedoTrack([SectorPosition])
    case torpedoMissed
    case starAbsorbedTorpedo(at: SectorPosition)
    case starbaseDestroyed(at: SectorPosition)
    case courtMartialReview
    case relievedOfCommand

    // Shields
    case shieldControlInoperable
    case shieldsUnchanged
    case notTheTreasury
    case shieldsSet(Int)

    // Damage control
    case damageReportUnavailable
    case damageReport([DeviceState])
    case repairOffer(stardates: Double)
    case repairsCompleted

    // Library computer
    case computerDisabled
    case galacticRecord(center: QuadrantPosition, chart: [QuadrantSummary?])
    case statusReport(enemies: Int, stardatesRemaining: Double, starbases: Int)
    case torpedoData([EnemyTargetData])
    case noStarbaseInQuadrant
    case starbaseNavigationData(NavigationData)
    case directionDistance(NavigationData)
    case regionMap

    // Outcomes
    case stranded
    case resigned
    case victory(stardate: Double, efficiency: Double)
    case defeat(stardate: Double, enemiesRemaining: Int, canRestart: Bool)
}
