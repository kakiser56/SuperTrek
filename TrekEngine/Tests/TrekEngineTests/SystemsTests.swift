import Testing
@testable import TrekEngine

@Suite("Ship systems")
struct SystemsTests {
    func game(_ configure: (inout Game.Fixture) -> Void = { _ in }) -> Game {
        var f = Game.Fixture()
        f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 2, starbases: 1, stars: 3)
        configure(&f)
        return Game(fixture: f)
    }

    @Test("Shields move energy between the two pools")
    func shields() {
        var g = game()
        #expect(g.apply(.setShields(energy: 500)) == [.shieldsSet(500)])
        #expect(g.ship.shields == 500)
        #expect(g.ship.energy == 2500)
        #expect(g.apply(.setShields(energy: 500)) == [.shieldsUnchanged])
        #expect(g.apply(.setShields(energy: -1)) == [.shieldsUnchanged])
        #expect(g.apply(.setShields(energy: 3001)) == [.notTheTreasury])
        #expect(g.apply(.setShields(energy: 3000)) == [.shieldsSet(3000)])
        #expect(g.ship.energy == 0)
        var broken = game { $0.ship.setDamage(.shieldControl, -1) }
        #expect(broken.apply(.setShields(energy: 10)) == [.shieldControlInoperable])
    }

    @Test("Putting everything into shields strands the ship")
    func stranded() {
        var g = game { $0.ship.setDamage(.shieldControl, -1); $0.ship.energy = 12; $0.ship.shields = 800 }
        let events = g.apply(.fireBeams(energy: 5)) // no enemies: refused, but the check still runs
        #expect(events.first == .noEnemiesInQuadrant)
        #expect(g.status == .playing)
        var g2 = game { $0.ship.energy = 5; $0.ship.shields = 5 }
        let events2 = g2.apply(.shortRangeScan)
        #expect(events2.contains(.stranded))
        #expect(g2.status == .lost(.stranded))
    }

    @Test("Docking refills the ship and offers repairs")
    func docking() {
        var g = game {
            $0.starbase = SectorPosition(row: 3, col: 5)
            $0.ship.energy = 100
            $0.ship.torpedoes = 2
            $0.ship.shields = 50
            $0.ship.setDamage(.computer, -3)
        }
        #expect(g.condition == .docked)
        #expect(g.ship.energy == Ship.maxEnergy)
        #expect(g.ship.torpedoes == Ship.maxTorpedoes)
        #expect(g.ship.shields == 0)

        let report = g.apply(.damageReport)
        #expect(report.contains { if case .damageReport = $0 { true } else { false } })
        // 0.1 for one device plus the fixture's 0.25 penalty
        #expect(report.contains(.repairOffer(stardates: 0.35)))
        #expect(g.pendingRepairEstimate != nil)

        let done = g.apply(.authorizeRepairs(true))
        #expect(done.first == .repairsCompleted)
        #expect(!g.ship.isDamaged(.computer))
        #expect(abs(g.stardate - 3000.45) < 1e-9)
        #expect(g.pendingRepairEstimate == nil)
        #expect(g.apply(.authorizeRepairs(true)) == [])
    }

    @Test("Declining repairs changes nothing")
    func declineRepairs() {
        var g = game { $0.starbase = SectorPosition(row: 5, col: 5); $0.ship.setDamage(.computer, -3) }
        g.apply(.damageReport)
        #expect(g.apply(.authorizeRepairs(false)) == [])
        #expect(g.ship.isDamaged(.computer))
        #expect(g.stardate == 3000)
    }

    @Test("Damage control offline hides the report")
    func damageReportUnavailable() {
        var g = game { $0.ship.setDamage(.damageControl, -1) }
        #expect(g.apply(.damageReport) == [.damageReportUnavailable])
    }

    @Test("Long range scan charts the neighbourhood")
    func longRangeScan() {
        var g = game { $0.quadrant = QuadrantPosition(row: 1, col: 1); $0.otherQuadrants[QuadrantPosition(row: 2, col: 2)] = QuadrantSummary(enemies: 1, starbases: 1, stars: 4) }
        let events = g.apply(.longRangeScan)
        guard case let .longRangeScan(center, cells) = events.first else {
            Issue.record("expected a scan")
            return
        }
        #expect(center == QuadrantPosition(row: 1, col: 1))
        #expect(cells.count == 9)
        #expect(cells[0] == .outsideGalaxy)
        #expect(cells[8] == .quadrant(QuadrantSummary(enemies: 1, starbases: 1, stars: 4)))
        #expect(g.charted(QuadrantPosition(row: 2, col: 2))?.code == 114)
        #expect(g.charted(QuadrantPosition(row: 3, col: 3)) == nil)
        var broken = game { $0.ship.setDamage(.longRangeSensors, -1) }
        #expect(broken.apply(.longRangeScan) == [.longRangeSensorsInoperable])
    }

    @Test("Short range sensors out")
    func shortRangeSensorsOut() {
        var g = game { $0.ship.setDamage(.shortRangeSensors, -1) }
        #expect(g.apply(.shortRangeScan) == [.shortRangeSensorsOut])
    }

    @Test("Library computer functions")
    func computer() {
        var g = game {
            $0.enemies = [Enemy(position: SectorPosition(row: 2, col: 6), energy: 150)]
            $0.starbase = SectorPosition(row: 8, col: 4)
        }
        let torpedo = g.apply(.computer(.torpedoData))
        guard case let .torpedoData(targets) = torpedo.first else {
            Issue.record("expected torpedo data")
            return
        }
        #expect(targets.count == 1)
        #expect(targets[0].navigation.course == 2)
        let base = g.apply(.computer(.starbaseNavigationData))
        #expect(base.first == .starbaseNavigationData(NavigationData(course: 7, distance: 4)))

        let status = g.apply(.computer(.statusReport))
        #expect(status.first == .statusReport(enemies: 3, stardatesRemaining: 30, starbases: 2))

        let calc = g.apply(.computer(.directionDistance(fromRow: 1, fromCol: 1, toRow: 1, toCol: 5)))
        #expect(calc.first == .directionDistance(NavigationData(course: 1, distance: 4)))

        guard case let .galacticRecord(_, chart) = g.apply(.computer(.galacticRecord)).first else {
            Issue.record("expected a galactic record")
            return
        }
        #expect(chart.compactMap { $0 }.count == 1)

        var broken = game { $0.ship.setDamage(.computer, -1) }
        #expect(broken.apply(.computer(.regionMap)) == [.computerDisabled])
    }

    @Test("Resigning ends the game")
    func resign() {
        var g = game()
        let events = g.apply(.resign)
        #expect(g.status == .lost(.resigned))
        #expect(events == [.resigned, .defeat(stardate: 3000, enemiesRemaining: 2, canRestart: true)])
    }
}
