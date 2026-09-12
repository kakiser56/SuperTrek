import Testing
@testable import TrekEngine

@Suite("Galaxy generation")
struct GalaxyTests {
    @Test("Same seed, same galaxy")
    func deterministic() {
        let a = Game.start(seed: 42)
        let b = Game.start(seed: 42)
        #expect(a.game == b.game)
        #expect(a.events == b.events)
        #expect(Game.start(seed: 43).game != a.game)
    }

    @Test("Every seed produces a playable galaxy", arguments: Array(UInt64(1)...UInt64(200)))
    func playable(seed: UInt64) {
        let (game, events) = Game.start(seed: seed)
        #expect(game.galaxy.totalEnemies >= 1)
        #expect(game.galaxy.totalStarbases >= 1)
        #expect(game.enemiesRemaining == game.galaxy.totalEnemies)
        #expect(game.starbasesRemaining == game.galaxy.totalStarbases)
        #expect(game.initialEnemyCount == game.enemiesRemaining)
        #expect(Double(game.enemiesRemaining) <= game.missionDuration)
        #expect(game.missionDuration >= 25)
        #expect(game.startingStardate >= 2000 && game.startingStardate <= 3900)
        #expect(game.quadrant.isInsideGalaxy)
        #expect(game.sector.isInsideQuadrant)
        for summary in game.galaxy.quadrants {
            #expect((1...8).contains(summary.stars))
            #expect((0...3).contains(summary.enemies))
            #expect((0...1).contains(summary.starbases))
        }
        // The current quadrant is laid out to match its summary.
        let here = game.galaxy[game.quadrant]
        #expect(game.map.positions(of: .ship) == [game.sector])
        #expect(game.map.positions(of: .enemy).count == here.enemies)
        #expect(game.map.positions(of: .starbase).count == here.starbases)
        #expect(game.map.positions(of: .star).count == here.stars)
        #expect(game.enemies.count == here.enemies)
        #expect(game.charted(game.quadrant) == here)
        // Opening events: briefing, mission begins, then a scan.
        guard case .missionBriefing = events.first else {
            Issue.record("expected a briefing first")
            return
        }
        #expect(events.contains { if case .missionBegins = $0 { true } else { false } })
        #expect(events.contains { if case .shortRangeScan = $0 { true } else { false } })
    }

    @Test("Region names follow the original table")
    func regionNames() {
        #expect(Regions.name(for: QuadrantPosition(row: 1, col: 1)) == "ANTARES I")
        #expect(Regions.name(for: QuadrantPosition(row: 1, col: 4)) == "ANTARES IV")
        #expect(Regions.name(for: QuadrantPosition(row: 1, col: 5)) == "SIRIUS I")
        #expect(Regions.name(for: QuadrantPosition(row: 8, col: 8)) == "SPICA IV")
    }
}
