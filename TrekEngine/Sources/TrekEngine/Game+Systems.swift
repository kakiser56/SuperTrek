import Foundation

extension Game {
    // MARK: Scans

    /// SRS, line 6430. Looking around is also how you dock.
    mutating func shortRangeScan() -> [Event] {
        var events = refreshCondition()
        if ship.isDamaged(.shortRangeSensors) {
            events.append(.shortRangeSensorsOut)
        } else {
            events.append(.shortRangeScan(scanSnapshot))
        }
        return events
    }

    public var scanSnapshot: ScanSnapshot {
        ScanSnapshot(
            cells: map.cells,
            enemies: enemies.filter(\.isAlive),
            stardate: stardate,
            condition: condition,
            quadrant: quadrant,
            sector: sector,
            torpedoes: ship.torpedoes,
            totalEnergy: Int(ship.totalEnergy),
            shields: Int(ship.shields),
            enemiesRemaining: enemiesRemaining
        )
    }

    /// LRS, line 4000: the 3x3 neighbourhood, charted as it is seen.
    mutating func longRangeScan() -> [Event] {
        if ship.isDamaged(.longRangeSensors) { return [.longRangeSensorsInoperable] }
        var cells: [LongRangeCell] = []
        for row in (quadrant.row - 1)...(quadrant.row + 1) {
            for col in (quadrant.col - 1)...(quadrant.col + 1) {
                let p = QuadrantPosition(row: row, col: col)
                if p.isInsideGalaxy {
                    let summary = galaxy[p]
                    chart[Galaxy.index(p)] = summary
                    cells.append(.quadrant(summary))
                } else {
                    cells.append(.outsideGalaxy)
                }
            }
        }
        return [.longRangeScan(center: quadrant, cells: cells)]
    }

    // MARK: Shields

    /// SHE, line 5530.
    mutating func setShields(energy: Int) -> [Event] {
        if ship.isDamaged(.shieldControl) { return [.shieldControlInoperable] }
        let requested = Double(energy)
        if energy < 0 || requested == ship.shields { return [.shieldsUnchanged] }
        if requested > ship.totalEnergy { return [.notTheTreasury] }
        ship.energy = ship.totalEnergy - requested
        ship.shields = requested
        return [.shieldsSet(energy)]
    }

    // MARK: Damage control

    /// DAM, line 5690. Docked ships get a repair offer.
    mutating func damageReport() -> [Event] {
        var events: [Event] = []
        if ship.isDamaged(.damageControl) {
            events.append(.damageReportUnavailable)
            guard ship.isDocked else { return events }
        } else {
            events.append(.damageReport(ship.deviceStates))
        }
        if ship.isDocked {
            events += repairOffer()
        }
        return events
    }

    private mutating func repairOffer() -> [Event] {
        var estimate = Device.allCases.filter { ship.isDamaged($0) }.reduce(0.0) { sum, _ in sum + 0.1 }
        guard estimate > 0 else {
            pendingRepairEstimate = nil
            return []
        }
        estimate += repairPenalty
        if estimate >= 1 { estimate = 0.9 }
        pendingRepairEstimate = estimate
        return [.repairOffer(stardates: floor(estimate * 100) / 100)]
    }

    mutating func authorizeRepairs(_ yes: Bool) -> [Event] {
        guard let estimate = pendingRepairEstimate else { return [] }
        pendingRepairEstimate = nil
        guard yes, ship.isDocked else { return [] }
        for device in Device.allCases where ship.isDamaged(device) {
            ship.setDamage(device, 0)
        }
        stardate = ((stardate + estimate + 0.1) * 100).rounded() / 100
        var events: [Event] = [.repairsCompleted, .damageReport(ship.deviceStates)]
        events += checkDeadline()
        return events
    }

    // MARK: Library computer

    /// COM, line 7290.
    mutating func computer(_ function: ComputerFunction) -> [Event] {
        if ship.isDamaged(.computer) { return [.computerDisabled] }
        switch function {
        case .galacticRecord:
            return [.galacticRecord(center: quadrant, chart: chart)]
        case .statusReport:
            let remaining = 0.1 * floor(stardatesRemaining * 10 + 1e-9)
            return [.statusReport(enemies: enemiesRemaining, stardatesRemaining: remaining, starbases: starbasesRemaining)]
                + damageReport()
        case .torpedoData:
            guard enemiesInQuadrant > 0 else { return [.noEnemiesInQuadrant] }
            let targets = enemies.filter(\.isAlive).map {
                EnemyTargetData(position: $0.position, navigation: Course.heading(from: sector, to: $0.position))
            }
            return [.torpedoData(targets)]
        case .starbaseNavigationData:
            guard let base = starbaseInQuadrant else { return [.noStarbaseInQuadrant] }
            return [.starbaseNavigationData(Course.heading(from: sector, to: base))]
        case let .directionDistance(fromRow, fromCol, toRow, toCol):
            return [.directionDistance(Course.heading(fromRow: fromRow, fromCol: fromCol, toRow: toRow, toCol: toCol))]
        case .regionMap:
            return [.regionMap]
        }
    }
}
