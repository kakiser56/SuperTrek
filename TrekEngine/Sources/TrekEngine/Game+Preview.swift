import Foundation

/// What a warp maneuver would do, computed without touching the game.
/// Enemies relocate before the ship moves, so a path that looks clear can
/// still be blocked by an enemy; stars and starbases are reliable.
public struct NavigationPreview: Hashable, Sendable {
    public var course: Double
    public var warp: Double
    public var steps: Int
    /// Sectors the ship passes through inside this quadrant, in order.
    public var path: [SectorPosition]
    /// Where the ship would end up if it stays in this quadrant.
    public var landing: SectorPosition?
    /// The obstacle that would shut the engines down, if any.
    public var blockedBy: SectorPosition?
    public var leavesQuadrant: Bool
    public var destinationQuadrant: QuadrantPosition?
    public var destinationSector: SectorPosition?
    public var perimeterDenied: Bool
    public var energyCost: Int
    public var stardateCost: Double
    public var insufficientEnergy: Bool
}

public struct TorpedoPreview: Hashable, Sendable {
    public var course: Double
    public var track: [SectorPosition]
    /// What the torpedo would strike, or nil if it leaves the quadrant.
    public var target: SectorContent?
}

/// Course and warp factor that reach a chosen point in one maneuver.
public struct PlottedCourse: Hashable, Sendable {
    public var course: Double
    public var warp: Double
}

extension Game {
    /// Mirrors `navigate` step for step without enemy movement or dice.
    public func previewNavigation(course rawCourse: Double, warp: Double) -> NavigationPreview? {
        guard let course = Course.normalized(rawCourse), warp > 0, warp <= 8 else { return nil }
        let steps = Int(warp * 8 + 0.5)
        let vector = Course.vector(course)
        var preview = NavigationPreview(
            course: course, warp: warp, steps: steps, path: [], landing: nil, blockedBy: nil,
            leavesQuadrant: false, destinationQuadrant: nil, destinationSector: nil,
            perimeterDenied: false, energyCost: steps + 10, stardateCost: Game.stardateCost(warp: warp),
            insufficientEnergy: ship.energy - Double(steps) - 10 < 0
        )
        let startRow = Double(sector.row)
        let startCol = Double(sector.col)
        var row = startRow
        var col = startCol
        for _ in 0..<steps {
            row += vector.dRow
            col += vector.dCol
            if row < 1 || row >= 9 || col < 1 || col >= 9 {
                let exit = Game.exit(from: quadrant, startRow: startRow, startCol: startCol, steps: steps, vector: vector)
                preview.perimeterDenied = exit.denied
                if exit.quadrant == quadrant {
                    preview.landing = exit.sector
                } else {
                    preview.leavesQuadrant = true
                    preview.destinationQuadrant = exit.quadrant
                    preview.destinationSector = exit.sector
                }
                return preview
            }
            let here = SectorPosition(row: Int(row), col: Int(col))
            if here != sector, !map.isEmpty(at: here) {
                preview.blockedBy = here
                let stop = SectorPosition(row: Int(floor(row - vector.dRow)), col: Int(floor(col - vector.dCol)))
                preview.landing = stop
                return preview
            }
            if here != sector, preview.path.last != here {
                preview.path.append(here)
            }
        }
        var landing = SectorPosition(row: Int(floor(row + 0.5)), col: Int(floor(col + 0.5)))
        if landing != sector, !map.isEmpty(at: landing) {
            landing = SectorPosition(row: Int(row), col: Int(col))
        }
        preview.landing = landing
        return preview
    }

    /// Mirrors `fireTorpedo`'s tracking loop.
    public func previewTorpedo(course rawCourse: Double) -> TorpedoPreview? {
        guard let course = Course.normalized(rawCourse) else { return nil }
        let vector = Course.vector(course)
        var row = Double(sector.row)
        var col = Double(sector.col)
        var track: [SectorPosition] = []
        while true {
            row += vector.dRow
            col += vector.dCol
            let here = SectorPosition(row: Int(floor(row + 0.5)), col: Int(floor(col + 0.5)))
            guard here.isInsideQuadrant else { return TorpedoPreview(course: course, track: track, target: nil) }
            track.append(here)
            switch map[here] {
            case nil, .ship: continue
            case let content?: return TorpedoPreview(course: course, track: track, target: content)
            }
        }
    }

    /// The course and warp that land exactly on a sector of this quadrant.
    public func plotCourse(to target: SectorPosition) -> PlottedCourse? {
        plotCourse(fromRow: sector.row, fromCol: sector.col, toRow: target.row, toCol: target.col)
    }

    /// The course and warp that land on a sector of another quadrant.
    public func plotCourse(toQuadrant target: QuadrantPosition, sector targetSector: SectorPosition = SectorPosition(row: 4, col: 4)) -> PlottedCourse? {
        plotCourse(
            fromRow: 8 * quadrant.row + sector.row, fromCol: 8 * quadrant.col + sector.col,
            toRow: 8 * target.row + targetSector.row, toCol: 8 * target.col + targetSector.col
        )
    }

    private func plotCourse(fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) -> PlottedCourse? {
        let steps = max(abs(toRow - fromRow), abs(toCol - fromCol))
        guard steps > 0, steps <= 64 else { return nil }
        let heading = Course.heading(fromRow: Double(fromRow), fromCol: Double(fromCol), toRow: Double(toRow), toCol: Double(toCol))
        return PlottedCourse(course: heading.course, warp: Double(steps) / 8)
    }

    // MARK: Shared with navigate

    static func stardateCost(warp: Double) -> Double {
        warp < 1 ? 0.1 * floor(10 * warp + 1e-9) : 1
    }

    /// Line 3500: where a path that leaves the quadrant ends up.
    static func exit(
        from quadrant: QuadrantPosition, startRow: Double, startCol: Double, steps: Int, vector: Vector
    ) -> (quadrant: QuadrantPosition, sector: SectorPosition, denied: Bool) {
        let x = 8 * Double(quadrant.row) + startRow + Double(steps) * vector.dRow
        let y = 8 * Double(quadrant.col) + startCol + Double(steps) * vector.dCol
        var q1 = Int(floor(x / 8))
        var q2 = Int(floor(y / 8))
        var s1 = Int(floor(x - Double(q1) * 8))
        var s2 = Int(floor(y - Double(q2) * 8))
        if s1 == 0 { q1 -= 1; s1 = 8 }
        if s2 == 0 { q2 -= 1; s2 = 8 }
        var denied = false
        if q1 < 1 { denied = true; q1 = 1; s1 = 1 }
        if q1 > 8 { denied = true; q1 = 8; s1 = 8 }
        if q2 < 1 { denied = true; q2 = 1; s2 = 1 }
        if q2 > 8 { denied = true; q2 = 8; s2 = 8 }
        return (QuadrantPosition(row: q1, col: q2), SectorPosition(row: s1, col: s2), denied)
    }
}
