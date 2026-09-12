import Foundation
import Testing
@testable import TrekEngine

@Suite("Save and load")
struct PersistenceTests {
    @Test("A game survives a round trip through JSON and keeps playing identically")
    func roundTrip() throws {
        var (game, _) = Game.start(seed: 7)
        game.apply(.setShields(energy: 400))
        game.apply(.navigate(course: 2, warp: 1.5))

        let data = try JSONEncoder().encode(game)
        var restored = try JSONDecoder().decode(Game.self, from: data)
        #expect(restored == game)

        let script: [Command] = [.longRangeScan, .navigate(course: 6, warp: 0.5), .fireBeams(energy: 300), .computer(.statusReport)]
        for command in script {
            let a = game.apply(command)
            let b = restored.apply(command)
            #expect(a == b)
        }
        #expect(restored == game)
    }

    @Test("Events encode")
    func eventsEncode() throws {
        let (_, events) = Game.start(seed: 99)
        let data = try JSONEncoder().encode(events)
        let back = try JSONDecoder().decode([Event].self, from: data)
        #expect(back == events)
    }
}
