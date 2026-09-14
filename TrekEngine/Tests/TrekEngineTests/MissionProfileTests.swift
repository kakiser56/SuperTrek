import Testing
@testable import TrekEngine

@Suite("Mission profile")
struct MissionProfileTests {
    func average(_ profile: MissionProfile, _ value: (Game) -> Double) -> Double {
        let seeds = UInt64(1)...UInt64(80)
        return seeds.map { value(Game.start(seed: $0, profile: profile).game) }.reduce(0, +) / Double(seeds.count)
    }

    @Test("Classic profile is the unmodified game")
    func classicUnchanged() {
        let a = Game.start(seed: 9)
        let b = Game.start(seed: 9, profile: MissionProfile(length: .medium, skill: .good))
        #expect(a.game == b.game)
        #expect(a.events == b.events)
        #expect(!a.events.contains { if case .missionProfile = $0 { true } else { false } })
    }

    @Test("Length changes enemy count and time")
    func lengthScales() {
        let short = average(MissionProfile(length: .short)) { Double($0.initialEnemyCount) }
        let medium = average(MissionProfile(length: .medium)) { Double($0.initialEnemyCount) }
        let long = average(MissionProfile(length: .long)) { Double($0.initialEnemyCount) }
        #expect(short < medium && medium < long, "\(short) \(medium) \(long)")
        let shortDays = average(MissionProfile(length: .short)) { $0.missionDuration }
        let longDays = average(MissionProfile(length: .long)) { $0.missionDuration }
        #expect(shortDays < longDays)
        for seed in UInt64(1)...UInt64(50) {
            let game = Game.start(seed: seed, profile: MissionProfile(length: .long)).game
            #expect(Double(game.initialEnemyCount) <= game.missionDuration)
        }
    }

    @Test("Skill scales enemy strength")
    func skillScales() {
        let novice = average(MissionProfile(skill: .novice)) { $0.enemies.map(\.energy).reduce(0, +) / Double(max(1, $0.enemies.count)) }
        let skilled = average(MissionProfile(skill: .skilled)) { $0.enemies.map(\.energy).reduce(0, +) / Double(max(1, $0.enemies.count)) }
        #expect(novice < skilled)
        #expect(abs(skilled / novice - 2.5) < 0.6, "ratio \(skilled / novice)")
    }

    @Test("Harder profiles score higher for the same win")
    func scoring() {
        func win(_ profile: MissionProfile) -> Double {
            Game.start(seed: 3, profile: profile).game.profile.scoreMultiplier
        }
        #expect(win(MissionProfile(length: .long, skill: .skilled)) == 3.0)
        #expect(win(.classic) == 1.0)
        #expect(win(MissionProfile(length: .short, skill: .novice)) == 0.375)
    }

    @Test("Profile survives a save")
    func persisted() throws {
        let game = Game.start(seed: 4, profile: MissionProfile(length: .long, skill: .expert)).game
        let data = try Foundation.JSONEncoder().encode(game)
        let back = try Foundation.JSONDecoder().decode(Game.self, from: data)
        #expect(back.profile == MissionProfile(length: .long, skill: .expert))
        let lines = Narrator().lines(for: Game.start(seed: 4, profile: MissionProfile(length: .long, skill: .expert)).events)
        #expect(lines.contains("THIS IS A LONG GAME AT EXPERT SKILL."))
    }
}

import Foundation
