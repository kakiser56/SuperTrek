import Foundation

extension Game {
    /// NAV, lines 2290 to 3600.
    mutating func navigate(course rawCourse: Double, warp: Double) -> [Event] {
        guard let course = Course.normalized(rawCourse) else { return [.incorrectCourse] }
        if ship.isDamaged(.warpEngines), warp > Game.damagedWarpLimit {
            return [.warpEnginesDamaged(maxWarp: Game.damagedWarpLimit)]
        }
        if warp == 0 { return [] }
        guard warp > 0, warp <= 8 else { return [.enginesWontTake(warp: warp)] }

        let steps = Int(warp * 8 + 0.5)
        if ship.energy - Double(steps) - 10 < 0 {
            let canBorrow = !(ship.shields < Double(steps) - ship.energy + 10 || ship.isDamaged(.shieldControl))
            return [.insufficientEnergy(warp: warp, shieldsDeployed: canBorrow ? Int(ship.shields) : nil)]
        }

        var events: [Event] = []
        moveEnemies()
        events += enemiesFire()
        if status.isOver { return events }
        events += repairDevices(warp: warp)

        let vector = Course.vector(course)
        let startRow = Double(sector.row)
        let startCol = Double(sector.col)
        map[sector] = nil

        var row = startRow
        var col = startCol
        var stoppedShort = false
        for _ in 0..<steps {
            row += vector.dRow
            col += vector.dCol
            if row < 1 || row >= 9 || col < 1 || col >= 9 {
                return events + leaveQuadrant(
                    startRow: startRow, startCol: startCol, steps: steps, vector: vector, warp: warp
                )
            }
            let here = SectorPosition(row: Int(row), col: Int(col))
            if !map.isEmpty(at: here) {
                row = floor(row - vector.dRow)
                col = floor(col - vector.dCol)
                events.append(.warpEnginesShutDown(at: SectorPosition(row: Int(row), col: Int(col))))
                stoppedShort = true
                break
            }
        }

        var landing: SectorPosition
        if stoppedShort {
            landing = SectorPosition(row: Int(row), col: Int(col))
        } else {
            landing = SectorPosition(row: Int(floor(row + 0.5)), col: Int(floor(col + 0.5)))
            // The listing rounds without re-checking; keep the ship out of stars.
            if !map.isEmpty(at: landing) {
                landing = SectorPosition(row: Int(row), col: Int(col))
            }
        }
        sector = landing
        map[sector] = .ship

        events += consumeManeuverEnergy(steps: steps)
        advanceStardate(warp: warp)
        let expired = checkDeadline()
        if !expired.isEmpty { return events + expired }
        events += shortRangeScan()
        return events
    }

    /// Line 3500: the path left the quadrant. Work out where in the galaxy it ends.
    private mutating func leaveQuadrant(
        startRow: Double, startCol: Double, steps: Int, vector: Vector, warp: Double
    ) -> [Event] {
        var events: [Event] = []
        let exit = Game.exit(from: quadrant, startRow: startRow, startCol: startCol, steps: steps, vector: vector)
        var landing = exit.sector
        if exit.denied {
            events.append(.perimeterCrossingDenied(quadrant: exit.quadrant, sector: landing))
        }

        if exit.quadrant == quadrant {
            if !map.isEmpty(at: landing) {
                landing = map.randomEmptySector(using: &rng)
            }
            sector = landing
            map[sector] = .ship
            events += consumeManeuverEnergy(steps: steps)
            advanceStardate(warp: warp)
            let expired = checkDeadline()
            if !expired.isEmpty { return events + expired }
            events += shortRangeScan()
            return events
        }

        advanceStardate(warp: warp)
        events += consumeManeuverEnergy(steps: steps)
        let expired = checkDeadline()
        if !expired.isEmpty { return events + expired }
        quadrant = exit.quadrant
        sector = landing
        events += enterQuadrant(firstEntry: false)
        return events
    }

    /// Line 3910: N + 10 units per maneuver, shields make up any shortfall.
    private mutating func consumeManeuverEnergy(steps: Int) -> [Event] {
        ship.energy -= Double(steps) + 10
        guard ship.energy < 0 else { return [] }
        ship.shields += ship.energy
        ship.energy = 0
        if ship.shields < 0 { ship.shields = 0 }
        return [.shieldControlSuppliedEnergy]
    }

    /// One stardate per maneuver at warp 1 or above, tenths below.
    private mutating func advanceStardate(warp: Double) {
        stardate = ((stardate + Game.stardateCost(warp: warp)) * 100).rounded() / 100
    }

    /// Line 2590: every enemy in the quadrant jumps to a random empty sector.
    private mutating func moveEnemies() {
        for i in enemies.indices where enemies[i].isAlive {
            map[enemies[i].position] = nil
            let p = map.randomEmptySector(using: &rng)
            enemies[i].position = p
            map[p] = .enemy
        }
    }

    /// Lines 2770 to 3060: travel time repairs damage, and now and then a
    /// system breaks or mends on its own.
    private mutating func repairDevices(warp: Double) -> [Event] {
        var events: [Event] = []
        let increment = min(warp, 1)
        for device in Device.allCases where ship.isDamaged(device) {
            var state = ship.repairState(of: device) + increment
            if state > -0.1, state < 0 {
                state = -0.1
            }
            ship.setDamage(device, state)
            if state >= 0 {
                events.append(.repairCompleted(device))
            }
        }
        if rng.unit() > 0.2 { return events }
        let device = Device(rawValue: rng.int(in: 0...(Device.allCases.count - 1)))!
        if rng.unit() >= 0.6 {
            ship.setDamage(device, ship.repairState(of: device) + rng.unit() * 3 + 1)
            events.append(.deviceImproved(device))
        } else {
            ship.setDamage(device, ship.repairState(of: device) - (rng.unit() * 5 + 1))
            events.append(.deviceDamagedRandomly(device))
        }
        return events
    }
}
