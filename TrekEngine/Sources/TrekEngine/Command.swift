/// The library computer's functions, numbered 0 to 5 in the original.
public enum ComputerFunction: Hashable, Codable, Sendable {
    /// COM 0: cumulative galactic record.
    case galacticRecord
    /// COM 1: status report plus damage report.
    case statusReport
    /// COM 2: course and distance to each enemy in the quadrant.
    case torpedoData
    /// COM 3: course and distance to the starbase in the quadrant.
    case starbaseNavigationData
    /// COM 4: course and distance between two arbitrary points.
    case directionDistance(fromRow: Double, fromCol: Double, toRow: Double, toCol: Double)
    /// COM 5: region name map.
    case regionMap
}

/// Everything a captain can do. One command is one turn of the original loop.
public enum Command: Hashable, Codable, Sendable {
    /// NAV. Course 1..<9 (9 wraps to 1), warp factor 0...8.
    case navigate(course: Double, warp: Double)
    /// SRS
    case shortRangeScan
    /// LRS
    case longRangeScan
    /// PHA. Energy to pour into the beam weapons.
    case fireBeams(energy: Int)
    /// TOR
    case fireTorpedo(course: Double)
    /// SHE. Energy to hold in the shields.
    case setShields(energy: Int)
    /// DAM
    case damageReport
    /// The Y/N answer to a docked repair offer.
    case authorizeRepairs(Bool)
    /// COM
    case computer(ComputerFunction)
    /// XXX
    case resign
}
