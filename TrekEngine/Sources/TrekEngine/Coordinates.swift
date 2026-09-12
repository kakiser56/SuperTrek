import Foundation

/// A quadrant in the 8x8 galaxy. Rows and columns are 1-based, as in the original.
public struct QuadrantPosition: Hashable, Codable, Sendable {
    public var row: Int
    public var col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    public var isInsideGalaxy: Bool {
        (1...Game.gridSize).contains(row) && (1...Game.gridSize).contains(col)
    }
}

/// A sector inside a quadrant. Rows and columns are 1-based, as in the original.
public struct SectorPosition: Hashable, Codable, Sendable {
    public var row: Int
    public var col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    public var isInsideQuadrant: Bool {
        (1...Game.gridSize).contains(row) && (1...Game.gridSize).contains(col)
    }

    public func distance(to other: SectorPosition) -> Double {
        let dr = Double(other.row - row)
        let dc = Double(other.col - col)
        return (dr * dr + dc * dc).squareRoot()
    }

    public func isAdjacent(to other: SectorPosition) -> Bool {
        abs(other.row - row) <= 1 && abs(other.col - col) <= 1
    }
}

/// A direction of travel as a row/column delta per step.
public struct Vector: Hashable, Sendable {
    public var dRow: Double
    public var dCol: Double

    public init(dRow: Double, dCol: Double) {
        self.dRow = dRow
        self.dCol = dCol
    }
}

/// Course and distance to a target, as the library computer reports it.
public struct NavigationData: Hashable, Codable, Sendable {
    public var course: Double
    public var distance: Double

    public init(course: Double, distance: Double) {
        self.course = course
        self.distance = distance
    }
}

/// The original nine-point compass:
///
/// ```
///   4  3  2
///    \ | /
///  5 - * - 1
///    / | \
///   6  7  8
/// ```
///
/// Course 9 is the same as course 1. Fractional courses interpolate linearly
/// between the neighbouring integer headings, tracing a square rather than a
/// circle, exactly as the BASIC C(9,2) table does.
public enum Course {
    /// C(1...9) from the listing: (row delta, column delta).
    static let table: [Vector] = [
        Vector(dRow: 0, dCol: 1),    // unused slot so indices match the listing
        Vector(dRow: 0, dCol: 1),    // 1: east
        Vector(dRow: -1, dCol: 1),   // 2: north-east
        Vector(dRow: -1, dCol: 0),   // 3: north
        Vector(dRow: -1, dCol: -1),  // 4: north-west
        Vector(dRow: 0, dCol: -1),   // 5: west
        Vector(dRow: 1, dCol: -1),   // 6: south-west
        Vector(dRow: 1, dCol: 0),    // 7: south
        Vector(dRow: 1, dCol: 1),    // 8: south-east
        Vector(dRow: 0, dCol: 1),    // 9: east again
    ]

    /// Maps course 9 to 1 and returns nil for anything outside 1..<9.
    public static func normalized(_ course: Double) -> Double? {
        guard course.isFinite else { return nil }
        let c = course == 9 ? 1 : course
        guard c >= 1, c < 9 else { return nil }
        return c
    }

    /// Per-step movement for a valid, normalized course.
    public static func vector(_ course: Double) -> Vector {
        let c = normalized(course) ?? 1
        let i = Int(c)
        let fraction = c - Double(i)
        let a = table[i]
        let b = table[i + 1]
        return Vector(
            dRow: a.dRow + (b.dRow - a.dRow) * fraction,
            dCol: a.dCol + (b.dCol - a.dCol) * fraction
        )
    }

    /// Course and distance from one point to another, in the same units
    /// (sectors or quadrants). Same point yields course 0, distance 0.
    public static func heading(fromRow: Double, fromCol: Double, toRow: Double, toCol: Double) -> NavigationData {
        let dRow = toRow - fromRow
        let dCol = toCol - fromCol
        let distance = (dRow * dRow + dCol * dCol).squareRoot()
        let m = max(abs(dRow), abs(dCol))
        guard m > 0 else { return NavigationData(course: 0, distance: 0) }
        let r = dRow / m
        let c = dCol / m
        var course: Double
        if c == 1, r <= 0 {
            course = 1 + (-r)          // (0,1) -> (-1,1)
        } else if r == -1 {
            course = 2 + (1 - c)       // (-1,1) -> (-1,-1)
        } else if c == -1 {
            course = 4 + (r + 1)       // (-1,-1) -> (1,-1)
        } else if r == 1 {
            course = 6 + (c + 1)       // (1,-1) -> (1,1)
        } else {
            course = 8 + (1 - r)       // (1,1) -> (0,1)
        }
        if course >= 9 { course -= 8 }
        return NavigationData(course: course, distance: distance)
    }

    public static func heading(from: SectorPosition, to: SectorPosition) -> NavigationData {
        heading(fromRow: Double(from.row), fromCol: Double(from.col), toRow: Double(to.row), toCol: Double(to.col))
    }

    public static func heading(from: QuadrantPosition, to: QuadrantPosition) -> NavigationData {
        heading(fromRow: Double(from.row), fromCol: Double(from.col), toRow: Double(to.row), toCol: Double(to.col))
    }
}
