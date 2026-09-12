import Testing
@testable import TrekEngine

@Suite("Narrator")
struct NarratorTests {
    @Test("Every event renders at least one line with no franchise names")
    func rendersOpening() {
        let (_, events) = Game.start(seed: 3)
        let lines = Narrator().lines(for: events)
        #expect(lines.count > 10)
        let text = lines.joined(separator: "\n")
        for banned in ["KLINGON", "ROMULAN", "ENTERPRISE", "FEDERATION", "PHASER", "PHOTON", "STARFLEET", "SPOCK", "SULU", "SCOTT", "UHURA"] {
            #expect(!text.contains(banned), "found \(banned)")
        }
    }

    @Test("Short range scan draws an 8x8 grid with a side panel")
    func scanGrid() {
        var f = Game.Fixture()
        f.enemies = [Enemy(position: SectorPosition(row: 1, col: 1), energy: 100)]
        f.stars = [SectorPosition(row: 8, col: 8)]
        let game = Game(fixture: f)
        let lines = Narrator().lines(for: .shortRangeScan(game.scanSnapshot))
        #expect(lines.count == 10)
        #expect(lines[1].hasPrefix("+K+"))
        #expect(lines[4].hasPrefix("         <*>"))
        #expect(lines[8].hasPrefix("                     " + " * "))
        #expect(lines[2].contains("CONDITION          *RED*"))
    }

    @Test("Numbers print like the teletype did")
    func numbers() {
        let n = Narrator()
        #expect(n.num(3000) == "3000")
        #expect(n.num(3000.5) == "3000.5")
        #expect(n.num(2.6666) == "2.67")
        #expect(n.num(0.2) == "0.2")
    }
}

@Suite("Briefing legend")
struct BriefingLegendTests {
    @Test("The orders explain the sensor glyphs")
    func legend() {
        let lines = Narrator().lines(for: .missionBriefing(enemies: 5, deadline: 3030, days: 30, starbases: 2))
        let text = lines.joined(separator: "\n")
        #expect(text.contains("<*> YOUR SHIP"))
        #expect(text.contains(">!< STARBASE"))
        #expect(text.contains("+K+ INVADER BATTLE CRUISER"))
        #expect(text.contains("+R+ INVADER WARBIRD"))
        #expect(text.contains("*  STAR"))
    }
}
