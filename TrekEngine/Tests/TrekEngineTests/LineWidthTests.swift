import Testing
@testable import TrekEngine

@Suite("Line width")
struct LineWidthTests {
    static let samples: [Event] = {
        let s = SectorPosition(row: 8, col: 8)
        let q = QuadrantPosition(row: 8, col: 8)
        let nav = NavigationData(course: 8.88, distance: 9.89)
        let states = Device.allCases.map { DeviceState(device: $0, repair: -2.75) }
        var game = Game(fixture: Game.Fixture())
        return [
            .missionBriefing(enemies: 27, deadline: 3934, days: 34, starbases: 3),
            .missionBegins(quadrantName: "SAGITTARIUS III"), .enteringQuadrant(quadrantName: "BETELGEUSE IV"),
            .combatAreaConditionRed, .shieldsDangerouslyLow, .shortRangeScan(game.scanSnapshot), .shortRangeSensorsOut, .docked,
            .longRangeScan(center: q, cells: Array(repeating: .quadrant(QuadrantSummary(enemies: 3, starbases: 1, stars: 8)), count: 9)),
            .longRangeSensorsInoperable, .incorrectCourse, .warpEnginesDamaged(maxWarp: 0.2), .enginesWontTake(warp: 8.5),
            .insufficientEnergy(warp: 7.5, shieldsDeployed: 2999), .warpEnginesShutDown(at: s), .perimeterCrossingDenied(quadrant: q, sector: s),
            .shieldControlSuppliedEnergy, .repairCompleted(.shortRangeSensors), .deviceDamagedRandomly(.longRangeSensors), .deviceImproved(.longRangeSensors),
            .starbaseShieldsProtect, .hitOnShip(units: 999, from: s, kind: .warbird, shieldsRemaining: 2999), .deviceDamagedByHit(.shortRangeSensors), .shipDestroyed,
            .noEnemiesInQuadrant, .beamControlDisabled, .computerFailureHampersAccuracy, .notEnoughEnergy(available: 2999),
            .beamHit(units: 999, at: s, remaining: 299), .beamNoDamage(at: s), .enemyDestroyed(at: s, kind: .warbird),
            .torpedoesExpended, .torpedoTubesInoperable, .torpedoTrack([s, s, s]), .torpedoMissed, .starAbsorbedTorpedo(at: s),
            .starbaseDestroyed(at: s), .courtMartialReview, .relievedOfCommand,
            .shieldControlInoperable, .shieldsUnchanged, .notTheTreasury, .shieldsSet(2999),
            .damageReportUnavailable, .damageReport(states), .repairOffer(stardates: 0.95), .repairsCompleted,
            .computerDisabled, .galacticRecord(center: q, chart: game.chart), .statusReport(enemies: 27, stardatesRemaining: 33.9, starbases: 0),
            .statusReport(enemies: 1, stardatesRemaining: 3.9, starbases: 3),
            .torpedoData([EnemyTargetData(position: s, navigation: nav)]), .noStarbaseInQuadrant, .starbaseNavigationData(nav), .directionDistance(nav), .regionMap,
            .stranded, .resigned, .victory(stardate: 3999.9, efficiency: 12345.67), .defeat(stardate: 3999.9, enemiesRemaining: 27, canRestart: true),
        ]
    }()

    @Test("No narrated line is wider than the teletype")
    func width() {
        let narrator = Narrator()
        var offenders: [String] = []
        for event in Self.samples {
            for line in narrator.lines(for: event) where line.count > narrator.columns {
                offenders.append("\(line.count): \(line)")
            }
        }
        let report = offenders.joined(separator: "\n")
        #expect(offenders.isEmpty, "\(report)")
    }

    /// Events whose lines are tables or art; the app shows those in views instead.
    static let art: [Event] = Self.samples.filter {
        switch $0 {
        case .shortRangeScan, .longRangeScan, .galacticRecord, .regionMap, .damageReport: true
        default: false
        }
    }

    @Test("Prose wraps cleanly at 40 columns for the phone")
    func narrowWidth() {
        let narrator = Narrator(columns: 40)
        var offenders: [String] = []
        for event in Self.samples where !Self.art.contains(event) {
            for line in narrator.lines(for: event) where line.count > 40 {
                offenders.append("\(line.count): \(line)")
            }
        }
        let report = offenders.joined(separator: "\n")
        #expect(offenders.isEmpty, "\(report)")
    }

    @Test("Wrapping keeps indent and never splits a word")
    func wrapMechanics() {
        let narrator = Narrator(columns: 20)
        let lines = narrator.wrap("  THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG")
        #expect(lines == ["  THE QUICK BROWN", "    FOX JUMPS OVER", "    THE LAZY DOG"])
        #expect(narrator.wrap("SHORT") == ["SHORT"])
        #expect(narrator.wrap("SUPERCALIFRAGILISTICEXPIALIDOCIOUS X") == ["SUPERCALIFRAGILISTICEXPIALIDOCIOUS", "  X"])
    }
}
