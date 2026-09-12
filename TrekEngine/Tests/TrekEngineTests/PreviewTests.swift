import Testing
@testable import TrekEngine

@Suite("Previews and plotting")
struct PreviewTests {
    func game(_ configure: (inout Game.Fixture) -> Void = { _ in }) -> Game {
        var f = Game.Fixture()
        f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 1, starbases: 0, stars: 1)
        configure(&f)
        return Game(fixture: f)
    }

    @Test("Navigation preview matches the real move inside the quadrant")
    func previewMatchesMove() {
        let g = game { $0.stars = [SectorPosition(row: 4, col: 7)] }
        let preview = g.previewNavigation(course: 1, warp: 0.25)!
        #expect(preview.path == [SectorPosition(row: 4, col: 5), SectorPosition(row: 4, col: 6)])
        #expect(preview.landing == SectorPosition(row: 4, col: 6))
        #expect(preview.blockedBy == nil)
        #expect(preview.energyCost == 12)
        #expect(abs(preview.stardateCost - 0.2) < 1e-9)
        var moved = g
        moved.apply(.navigate(course: 1, warp: 0.25))
        #expect(moved.sector == preview.landing)
    }

    @Test("Navigation preview reports obstacles")
    func previewBlocked() {
        let g = game { $0.stars = [SectorPosition(row: 4, col: 6)] }
        let preview = g.previewNavigation(course: 1, warp: 0.5)!
        #expect(preview.blockedBy == SectorPosition(row: 4, col: 6))
        #expect(preview.landing == SectorPosition(row: 4, col: 5))
        #expect(preview.path == [SectorPosition(row: 4, col: 5)])
        var moved = g
        moved.apply(.navigate(course: 1, warp: 0.5))
        #expect(moved.sector == SectorPosition(row: 4, col: 5))
    }

    @Test("Navigation preview reports quadrant changes and the perimeter")
    func previewLeaves() {
        let g = game()
        let east = g.previewNavigation(course: 1, warp: 1)!
        #expect(east.leavesQuadrant)
        #expect(east.destinationQuadrant == QuadrantPosition(row: 4, col: 5))
        #expect(east.destinationSector == SectorPosition(row: 4, col: 4))
        #expect(!east.perimeterDenied)

        let edge = game { $0.quadrant = QuadrantPosition(row: 1, col: 4); $0.sector = SectorPosition(row: 1, col: 4) }
        let north = edge.previewNavigation(course: 3, warp: 1)!
        #expect(north.perimeterDenied)
        #expect(!north.leavesQuadrant)
        #expect(north.landing == SectorPosition(row: 1, col: 4))
    }

    @Test("Invalid input yields no preview")
    func previewInvalid() {
        let g = game()
        #expect(g.previewNavigation(course: 0, warp: 1) == nil)
        #expect(g.previewNavigation(course: 1, warp: 0) == nil)
        #expect(g.previewNavigation(course: 1, warp: 9) == nil)
        #expect(g.previewNavigation(course: 1, warp: 1)?.insufficientEnergy == false)
        let low = game { $0.ship.energy = 10 }
        #expect(low.previewNavigation(course: 1, warp: 1)?.insufficientEnergy == true)
    }

    @Test("Torpedo preview matches the real track")
    func torpedoPreview() {
        let g = game { $0.enemies = [Enemy(position: SectorPosition(row: 2, col: 6), energy: 100)] }
        let preview = g.previewTorpedo(course: 2)!
        #expect(preview.track == [SectorPosition(row: 3, col: 5), SectorPosition(row: 2, col: 6)])
        #expect(preview.target == .enemy)
        let miss = g.previewTorpedo(course: 5)!
        #expect(miss.target == nil)
        #expect(miss.track.last == SectorPosition(row: 4, col: 1))
        #expect(g.previewTorpedo(course: 0) == nil)
    }

    @Test("Plotting a sector lands exactly on it", arguments: [
        SectorPosition(row: 1, col: 1), SectorPosition(row: 8, col: 8), SectorPosition(row: 4, col: 8),
        SectorPosition(row: 2, col: 5), SectorPosition(row: 7, col: 1), SectorPosition(row: 4, col: 5),
    ])
    func plotSector(target: SectorPosition) {
        let g = game()
        let plot = g.plotCourse(to: target)!
        var moved = g
        moved.apply(.navigate(course: plot.course, warp: plot.warp))
        #expect(moved.quadrant == g.quadrant)
        #expect(moved.sector == target, "plot \(plot)")
        #expect(g.previewNavigation(course: plot.course, warp: plot.warp)?.landing == target)
    }

    @Test("Plotting a quadrant arrives in it", arguments: [
        QuadrantPosition(row: 1, col: 1), QuadrantPosition(row: 8, col: 8), QuadrantPosition(row: 4, col: 5),
        QuadrantPosition(row: 1, col: 8), QuadrantPosition(row: 5, col: 4),
    ])
    func plotQuadrant(target: QuadrantPosition) {
        let g = game()
        let plot = g.plotCourse(toQuadrant: target)!
        #expect(plot.warp <= 8)
        var moved = g
        moved.apply(.navigate(course: plot.course, warp: plot.warp))
        #expect(moved.quadrant == target, "plot \(plot)")
        #expect(moved.sector == SectorPosition(row: 4, col: 4))
    }

    @Test("Plotting your own sector is nil")
    func plotSelf() {
        let g = game()
        #expect(g.plotCourse(to: g.sector) == nil)
        #expect(g.plotCourse(toQuadrant: g.quadrant) == nil)
    }
}
