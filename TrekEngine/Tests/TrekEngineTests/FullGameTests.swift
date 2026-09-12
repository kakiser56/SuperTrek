import Testing
@testable import TrekEngine

/// A simple captain that knows the whole galaxy. It exists to drive the
/// engine through complete games and prove they always end.
struct Autopilot {
    var game: Game
    var commands = 0
    var lastCommand: Command?
    var lastEvents: [Event] = []

    mutating func send(_ command: Command) {
        lastCommand = command
        lastEvents = game.apply(command)
    }

    init(seed: UInt64) {
        game = Game.start(seed: seed).game
    }

    mutating func play(limit: Int = 600) {
        while game.status == .playing, commands < limit {
            step()
        }
    }

    private mutating func step() {
        commands += 1
        let before = game
        plan()
        guard game == before else { return }
        // The plan was refused. Escalate until something changes.
        if game.enemiesInQuadrant > 0, let target = game.enemies.first(where: \.isAlive) {
            send(.fireTorpedo(course: Course.heading(from: game.sector, to: target.position).course))
            if game != before { return }
        }
        send(.navigate(course: Double(1 + commands % 8), warp: 0.1))
        if game != before { return }
        send(.resign)
    }

    private mutating func plan() {
        let shieldsWork = !game.ship.isDamaged(.shieldControl)
        if game.enemiesInQuadrant > 0 {
            if shieldsWork, game.ship.shields < 400, game.ship.energy > 900 {
                send(.setShields(energy: 400))
                return
            }
            let energy = min(Int(game.ship.energy) - 200, 700)
            if energy > 50 {
                send(.fireBeams(energy: energy))
                return
            }
        }
        if game.enemiesInQuadrant == 0, shieldsWork, game.ship.energy < 300, game.ship.shields > 0 {
            send(.setShields(energy: 0))
            return
        }
        if game.ship.energy < 1000 || game.ship.torpedoes == 0, game.starbasesRemaining > 0 {
            if let base = game.starbaseInQuadrant {
                if game.ship.isDocked {
                    // Fully stocked now; fall through to hunting.
                } else {
                    approach(base)
                    return
                }
            } else if let target = nearestQuadrant(where: { $0.starbases > 0 }) {
                jump(to: target)
                return
            }
        }
        if let target = nearestQuadrant(where: { $0.enemies > 0 }) {
            jump(to: target)
        } else {
            send(.resign)
        }
    }

    private func nearestQuadrant(where predicate: (QuadrantSummary) -> Bool) -> QuadrantPosition? {
        Galaxy.allPositions
            .filter { $0 != game.quadrant && predicate(game.galaxy[$0]) }
            .min { Course.heading(from: game.quadrant, to: $0).distance < Course.heading(from: game.quadrant, to: $1).distance }
    }

    /// One warp jump aimed at the middle of the target quadrant.
    private mutating func jump(to target: QuadrantPosition) {
        let fromRow = Double(8 * game.quadrant.row + game.sector.row)
        let fromCol = Double(8 * game.quadrant.col + game.sector.col)
        let toRow = Double(8 * target.row + 4)
        let toCol = Double(8 * target.col + 4)
        let data = Course.heading(fromRow: fromRow, fromCol: fromCol, toRow: toRow, toCol: toCol)
        let warp = min(8, max(0.1, (data.distance / 8 * 10).rounded() / 10))
        let before = game.quadrant
        send(.navigate(course: data.course, warp: warp))
        if game.quadrant == before, game.status == .playing {
            // Blocked or denied; nudge sideways so the next jump differs.
            send(.navigate(course: Double(1 + commands % 8), warp: 0.1))
        }
    }

    /// Creep up next to the starbase so the next scan docks.
    private mutating func approach(_ base: SectorPosition) {
        let data = Course.heading(from: game.sector, to: base)
        let steps = max(1, Int(data.distance.rounded()) - 1)
        send(.navigate(course: data.course, warp: Double(steps) / 8))
    }
}

@Suite("Full games")
struct FullGameTests {
    @Test("Games driven by the autopilot always finish", arguments: Array(UInt64(1)...UInt64(40)))
    func finishes(seed: UInt64) {
        var pilot = Autopilot(seed: seed)
        pilot.play()
        #expect(pilot.game.status != .playing, "seed \(seed) did not finish in \(pilot.commands) commands")
        #expect(pilot.game.enemiesRemaining == pilot.game.galaxy.totalEnemies)
        #expect(pilot.game.starbasesRemaining == pilot.game.galaxy.totalStarbases)
    }

    @Test("The autopilot wins a fair share of games")
    func winnable() {
        var wins = 0
        var outcomes: [String] = []
        for seed in UInt64(1)...UInt64(200) {
            var pilot = Autopilot(seed: seed)
            pilot.play()
            if case .won = pilot.game.status { wins += 1 }
            outcomes.append("\(seed): \(pilot.game.status) after \(pilot.commands) commands, stardate \(pilot.game.stardate)")
        }
        let report = outcomes.joined(separator: "\n")
        #expect(wins >= 30, "only \(wins) wins of 200:\n\(report)")
    }

    @Test("A game played to the end still round-trips through JSON")
    func endedGameEncodes() throws {
        var pilot = Autopilot(seed: 5)
        pilot.play()
        let data = try Foundation.JSONEncoder().encode(pilot.game)
        var back = try Foundation.JSONDecoder().decode(Game.self, from: data)
        #expect(back == pilot.game)
        #expect(back.apply(.shortRangeScan) == [])
    }
}

import Foundation
