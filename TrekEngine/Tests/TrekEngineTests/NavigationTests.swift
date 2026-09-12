import Testing
@testable import TrekEngine

@Suite("Navigation")
struct NavigationTests {
    func quietGame(_ configure: (inout Game.Fixture) -> Void = { _ in }) -> Game {
        var f = Game.Fixture()
        // Keep an enemy somewhere else so nothing ends the game early.
        f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 1, starbases: 0, stars: 1)
        configure(&f)
        return Game(fixture: f)
    }

    @Test("Warp 1 on course 1 crosses into the next quadrant east")
    func crossQuadrantEast() {
        var game = quietGame()
        let events = game.apply(.navigate(course: 1, warp: 1))
        #expect(game.quadrant == QuadrantPosition(row: 4, col: 5))
        #expect(game.sector == SectorPosition(row: 4, col: 4))
        #expect(game.ship.energy == 3000 - 8 - 10)
        #expect(game.stardate == 3001)
        #expect(events.contains(.enteringQuadrant(quadrantName: "BETELGEUSE I")))
        #expect(game.charted(QuadrantPosition(row: 4, col: 5)) != nil)
    }

    @Test("Warp 0.5 on course 3 crosses north and lands on the bottom row")
    func crossQuadrantNorth() {
        var game = quietGame()
        game.apply(.navigate(course: 3, warp: 0.5))
        #expect(game.quadrant == QuadrantPosition(row: 3, col: 4))
        #expect(game.sector == SectorPosition(row: 8, col: 4))
        #expect(abs(game.stardate - 3000.5) < 1e-9)
        #expect(game.ship.energy == 3000 - 4 - 10)
    }

    @Test("Moving inside the quadrant")
    func moveWithinQuadrant() {
        var game = quietGame()
        game.apply(.navigate(course: 1, warp: 0.25))
        #expect(game.quadrant == QuadrantPosition(row: 4, col: 4))
        #expect(game.sector == SectorPosition(row: 4, col: 6))
        #expect(game.map[SectorPosition(row: 4, col: 6)] == .ship)
        #expect(game.map[SectorPosition(row: 4, col: 4)] == nil)
        #expect(abs(game.stardate - 3000.2) < 1e-9)
    }

    @Test("A star in the path shuts the engines down")
    func badNavigation() {
        var game = quietGame { $0.stars = [SectorPosition(row: 4, col: 6)] }
        let events = game.apply(.navigate(course: 1, warp: 0.5))
        #expect(events.contains(.warpEnginesShutDown(at: SectorPosition(row: 4, col: 5))))
        #expect(game.sector == SectorPosition(row: 4, col: 5))
        #expect(game.map[SectorPosition(row: 4, col: 6)] == .star)
        #expect(game.ship.energy == 3000 - 4 - 10)
    }

    @Test("The galactic perimeter cannot be crossed")
    func perimeterDenied() {
        var game = quietGame {
            $0.quadrant = QuadrantPosition(row: 1, col: 4)
            $0.sector = SectorPosition(row: 1, col: 4)
        }
        let events = game.apply(.navigate(course: 3, warp: 1))
        #expect(events.contains(.perimeterCrossingDenied(quadrant: QuadrantPosition(row: 1, col: 4), sector: SectorPosition(row: 1, col: 4))))
        #expect(game.quadrant == QuadrantPosition(row: 1, col: 4))
        #expect(game.sector == SectorPosition(row: 1, col: 4))
        #expect(game.stardate == 3001)
        #expect(game.ship.energy == 3000 - 8 - 10)
    }

    @Test("Bad course and warp inputs are rejected without moving")
    func rejectedInputs() {
        var game = quietGame()
        let before = game
        #expect(game.apply(.navigate(course: 0, warp: 1)) == [.incorrectCourse])
        #expect(game.apply(.navigate(course: 9.5, warp: 1)) == [.incorrectCourse])
        #expect(game.apply(.navigate(course: 1, warp: 8.5)) == [.enginesWontTake(warp: 8.5)])
        #expect(game.apply(.navigate(course: 1, warp: -1)) == [.enginesWontTake(warp: -1)])
        #expect(game.apply(.navigate(course: 1, warp: 0)) == [])
        #expect(game == before)
    }

    @Test("Damaged engines cap warp at 0.2")
    func damagedEngines() {
        var game = quietGame { $0.ship.setDamage(.warpEngines, -1) }
        #expect(game.apply(.navigate(course: 1, warp: 1)) == [.warpEnginesDamaged(maxWarp: 0.2)])
        #expect(game.sector == SectorPosition(row: 4, col: 4))
        game.apply(.navigate(course: 1, warp: 0.2))
        #expect(game.sector == SectorPosition(row: 4, col: 6))
    }

    @Test("Insufficient energy refuses the maneuver")
    func insufficientEnergy() {
        var game = quietGame { $0.ship.energy = 15; $0.ship.shields = 500 }
        let events = game.apply(.navigate(course: 1, warp: 1))
        #expect(events.first == .insufficientEnergy(warp: 1, shieldsDeployed: 500))
        #expect(game.sector == SectorPosition(row: 4, col: 4))
        #expect(game.ship.energy == 15)
    }

    @Test("Travel repairs damaged devices")
    func travelRepairs() {
        var game = quietGame { $0.ship.setDamage(.longRangeSensors, -0.5) }
        let events = game.apply(.navigate(course: 1, warp: 0.5))
        #expect(!game.ship.isDamaged(.longRangeSensors))
        #expect(events.contains(.repairCompleted(.longRangeSensors)))
    }

    @Test("Running out of time ends the mission")
    func deadline() {
        var game = quietGame { $0.stardate = 3000; $0.missionDuration = 0.5 }
        let events = game.apply(.navigate(course: 1, warp: 1))
        #expect(game.status == .lost(.timeExpired))
        #expect(events.contains { if case .defeat = $0 { true } else { false } })
        #expect(game.apply(.shortRangeScan) == [])
    }
}
