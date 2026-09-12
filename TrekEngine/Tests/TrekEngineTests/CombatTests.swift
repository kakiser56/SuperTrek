import Testing
@testable import TrekEngine

@Suite("Combat")
struct CombatTests {
    func battle(_ configure: (inout Game.Fixture) -> Void = { _ in }) -> Game {
        var f = Game.Fixture()
        f.enemies = [Enemy(position: SectorPosition(row: 4, col: 6), energy: 200)]
        f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 1, starbases: 0, stars: 1)
        f.ship.shields = 1000
        f.ship.energy = 2000
        configure(&f)
        return Game(fixture: f)
    }

    @Test("A torpedo on course 1 hits the enemy two sectors east")
    func torpedoHit() {
        var game = battle()
        let events = game.apply(.fireTorpedo(course: 1))
        #expect(events.contains(.torpedoTrack([SectorPosition(row: 4, col: 5), SectorPosition(row: 4, col: 6)])))
        #expect(events.contains(.enemyDestroyed(at: SectorPosition(row: 4, col: 6), kind: .cruiser)))
        #expect(game.enemiesInQuadrant == 0)
        #expect(game.enemiesRemaining == 1)
        #expect(game.ship.torpedoes == 9)
        #expect(game.ship.energy == 1998)
        #expect(game.galaxy[game.quadrant].enemies == 0)
        #expect(game.charted(game.quadrant)?.enemies == 0)
        #expect(game.condition == .green)
    }

    @Test("A torpedo into empty space misses and the enemy fires back")
    func torpedoMiss() {
        var game = battle()
        let events = game.apply(.fireTorpedo(course: 5))
        #expect(events.contains(.torpedoMissed))
        #expect(events.contains { if case .hitOnShip = $0 { true } else { false } })
        #expect(game.ship.shields < 1000)
        #expect(game.enemiesInQuadrant == 1)
    }

    @Test("Stars absorb torpedoes")
    func torpedoStar() {
        var game = battle { $0.stars = [SectorPosition(row: 4, col: 5)] }
        let events = game.apply(.fireTorpedo(course: 1))
        #expect(events.contains(.starAbsorbedTorpedo(at: SectorPosition(row: 4, col: 5))))
        #expect(game.enemiesInQuadrant == 1)
    }

    @Test("Destroying your own starbase brings a court martial review")
    func torpedoStarbase() {
        var game = battle {
            $0.starbase = SectorPosition(row: 4, col: 2)
            $0.otherQuadrants[QuadrantPosition(row: 2, col: 2)] = QuadrantSummary(enemies: 0, starbases: 1, stars: 1)
        }
        let events = game.apply(.fireTorpedo(course: 5))
        #expect(events.contains(.starbaseDestroyed(at: SectorPosition(row: 4, col: 2))))
        #expect(events.contains(.courtMartialReview))
        #expect(game.starbasesRemaining == 1)
        #expect(game.status == .playing)
    }

    @Test("Destroying the last enemy wins with an efficiency rating")
    func victory() {
        var game = battle { $0.otherQuadrants = [:]; $0.stardate = 3000 }
        game.apply(.navigate(course: 1, warp: 0)) // no-op
        let events = game.apply(.fireTorpedo(course: 1))
        guard case let .won(rating) = game.status else {
            Issue.record("expected a win, got \(game.status)")
            return
        }
        #expect(rating > 0)
        #expect(events.contains { if case .victory = $0 { true } else { false } })
    }

    @Test("Beam weapons wear an enemy down and it fires back")
    func beamsDamage() {
        var game = battle()
        let events = game.apply(.fireBeams(energy: 100))
        #expect(game.ship.energy == 1900)
        let hit = events.first { if case .beamHit = $0 { true } else { false } }
        #expect(hit != nil)
        #expect(game.enemies[0].energy < 200)
        #expect(game.enemies[0].isAlive)
        #expect(events.contains { if case .hitOnShip = $0 { true } else { false } })
    }

    @Test("Enough beam energy destroys the enemy")
    func beamsKill() {
        var game = battle()
        let events = game.apply(.fireBeams(energy: 1500))
        #expect(events.contains(.enemyDestroyed(at: SectorPosition(row: 4, col: 6), kind: .cruiser)))
        #expect(game.enemiesInQuadrant == 0)
        #expect(!events.contains { if case .hitOnShip = $0 { true } else { false } })
    }

    @Test("Beam weapon guards")
    func beamGuards() {
        var game = battle { $0.ship.setDamage(.beamControl, -1) }
        #expect(game.apply(.fireBeams(energy: 100)) == [.beamControlDisabled])

        var quiet = battle { $0.enemies = [] }
        #expect(quiet.apply(.fireBeams(energy: 100)) == [.noEnemiesInQuadrant])

        var broke = battle()
        #expect(broke.apply(.fireBeams(energy: 5000)) == [.notEnoughEnergy(available: 2000)])
        #expect(broke.ship.energy == 2000)
    }

    @Test("Torpedo guards")
    func torpedoGuards() {
        var empty = battle { $0.ship.torpedoes = 0 }
        #expect(empty.apply(.fireTorpedo(course: 1)) == [.torpedoesExpended])
        var broken = battle { $0.ship.setDamage(.torpedoTubes, -2) }
        #expect(broken.apply(.fireTorpedo(course: 1)) == [.torpedoTubesInoperable])
        var bad = battle()
        #expect(bad.apply(.fireTorpedo(course: 12)) == [.incorrectCourse])
        #expect(bad.ship.torpedoes == 10)
    }

    @Test("Enemy fire without shields destroys the ship")
    func shipDestroyed() {
        var game = battle { $0.ship.shields = 0 }
        let events = game.apply(.fireTorpedo(course: 5))
        #expect(game.status == .lost(.shipDestroyed))
        #expect(events.contains(.shipDestroyed))
        #expect(events.last == .defeat(stardate: 3000, enemiesRemaining: 2, canRestart: false))
    }

    @Test("A docked ship is protected by starbase shields")
    func dockedProtection() {
        var game = battle { $0.starbase = SectorPosition(row: 5, col: 4) }
        #expect(game.condition == .docked)
        #expect(game.ship.shields == 0)
        #expect(game.ship.energy == Ship.maxEnergy)
        let events = game.apply(.fireTorpedo(course: 5))
        #expect(events.contains(.starbaseShieldsProtect))
        #expect(game.status == .playing)
    }

    @Test("Enemies relocate when the ship moves")
    func enemiesMove() {
        var game = battle { $0.enemies = [Enemy(position: SectorPosition(row: 1, col: 1), energy: 100)] }
        game.apply(.navigate(course: 1, warp: 0.125))
        #expect(game.map.positions(of: .enemy).count == 1)
        #expect(game.map[game.enemies[0].position] == .enemy)
    }
}

@Suite("Enemy kinds")
struct EnemyKindTests {
    @Test("Quadrants hold a mix of cruisers and warbirds, count unchanged")
    func mixedKinds() {
        var cruisers = 0
        var warbirds = 0
        for seed in UInt64(1)...UInt64(60) {
            let game = Game.start(seed: seed).game
            #expect(game.enemies.count == game.galaxy[game.quadrant].enemies)
            cruisers += game.enemies.filter { $0.kind == .cruiser }.count
            warbirds += game.enemies.filter { $0.kind == .warbird }.count
        }
        #expect(cruisers > 5)
        #expect(warbirds > 5)
    }

    @Test("Warbirds start weaker but hit harder")
    func warbirdProfile() {
        #expect(EnemyKind.warbird.initialEnergy(roll: 0.5) < EnemyKind.cruiser.initialEnergy(roll: 0.5))
        #expect(EnemyKind.warbird.fireMultiplier > EnemyKind.cruiser.fireMultiplier)

        var f = Game.Fixture()
        f.enemies = [Enemy(position: SectorPosition(row: 4, col: 6), energy: 100, kind: .warbird)]
        f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 1, starbases: 0, stars: 1)
        f.ship.shields = 1000
        var game = Game(fixture: f)
        let events = game.apply(.fireTorpedo(course: 5))
        let hit = events.compactMap { event -> Int? in
            if case let .hitOnShip(units, _, kind, _) = event, kind == .warbird { return units }
            return nil
        }.first
        #expect(hit != nil)
        // 100 energy at distance 2 with the 1.3 multiplier: between 130 and 195.
        #expect((130...195).contains(hit ?? 0))
    }

    @Test("Destroyed enemies report their kind")
    func destroyedKind() {
        var f = Game.Fixture()
        f.enemies = [Enemy(position: SectorPosition(row: 4, col: 6), energy: 100, kind: .warbird)]
        f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 1, starbases: 0, stars: 1)
        var game = Game(fixture: f)
        let events = game.apply(.fireTorpedo(course: 1))
        #expect(events.contains(.enemyDestroyed(at: SectorPosition(row: 4, col: 6), kind: .warbird)))
        #expect(Narrator().lines(for: events).contains("*** INVADER WARBIRD DESTROYED ***"))
    }
}
