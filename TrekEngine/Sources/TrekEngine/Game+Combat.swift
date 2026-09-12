import Foundation

extension Game {
    /// Line 6000: every live enemy fires. Docked ships are untouchable.
    mutating func enemiesFire() -> [Event] {
        guard enemiesInQuadrant > 0 else { return [] }
        if ship.isDocked { return [.starbaseShieldsProtect] }

        var events: [Event] = []
        for i in enemies.indices where enemies[i].isAlive {
            let distance = sector.distance(to: enemies[i].position)
            let hit = floor((enemies[i].energy / distance) * (2 + rng.unit()) * enemies[i].kind.fireMultiplier)
            ship.shields -= hit
            enemies[i].energy /= 3 + rng.unit()
            if ship.shields <= 0 {
                ship.shields = 0
                status = .lost(.shipDestroyed)
                events.append(.hitOnShip(units: Int(hit), from: enemies[i].position, kind: enemies[i].kind, shieldsRemaining: 0))
                events.append(.shipDestroyed)
                events.append(defeatEvent())
                return events
            }
            events.append(.hitOnShip(units: Int(hit), from: enemies[i].position, kind: enemies[i].kind, shieldsRemaining: Int(ship.shields)))
            if hit < 20 { continue }
            if rng.unit() > 0.6 || hit / ship.shields <= 0.02 { continue }
            let device = Device(rawValue: rng.int(in: 0...(Device.allCases.count - 1)))!
            ship.setDamage(device, ship.repairState(of: device) - hit / ship.shields - 0.5 * rng.unit())
            events.append(.deviceDamagedByHit(device))
        }
        return events
    }

    /// PHA, lines 4260 to 4670. Energy is split evenly across targets and
    /// falls off with distance.
    mutating func fireBeams(energy: Int) -> [Event] {
        if ship.isDamaged(.beamControl) { return [.beamControlDisabled] }
        if enemiesInQuadrant <= 0 { return [.noEnemiesInQuadrant] }

        var events: [Event] = []
        let computerDown = ship.isDamaged(.computer)
        if computerDown { events.append(.computerFailureHampersAccuracy) }
        guard energy > 0 else { return events }
        if Double(energy) > ship.energy {
            events.append(.notEnoughEnergy(available: Int(ship.energy)))
            return events
        }
        ship.energy -= Double(energy)

        // The listing keys this penalty to D(7); the message it prints says
        // computer. The message wins.
        var effective = Double(energy)
        if computerDown { effective *= rng.unit() }
        let perTarget = floor(effective / Double(enemiesInQuadrant))

        for i in enemies.indices where enemies[i].isAlive {
            let distance = sector.distance(to: enemies[i].position)
            let hit = floor((perTarget / distance) * (rng.unit() + 2))
            if hit <= 0.15 * enemies[i].energy {
                events.append(.beamNoDamage(at: enemies[i].position))
                continue
            }
            enemies[i].energy -= hit
            if enemies[i].energy <= 0 {
                events.append(.beamHit(units: Int(hit), at: enemies[i].position, remaining: 0))
                events += destroyEnemy(at: i)
                if status.isOver { return events }
            } else {
                events.append(.beamHit(units: Int(hit), at: enemies[i].position, remaining: Int(enemies[i].energy)))
            }
        }
        events += enemiesFire()
        return events
    }

    /// TOR, lines 4700 to 5490. The torpedo walks the course one sector at a
    /// time until it leaves the quadrant or hits something.
    mutating func fireTorpedo(course rawCourse: Double) -> [Event] {
        if ship.torpedoes <= 0 { return [.torpedoesExpended] }
        if ship.isDamaged(.torpedoTubes) { return [.torpedoTubesInoperable] }
        guard let course = Course.normalized(rawCourse) else { return [.incorrectCourse] }

        ship.energy -= 2
        ship.torpedoes -= 1
        let vector = Course.vector(course)
        var row = Double(sector.row)
        var col = Double(sector.col)
        var track: [SectorPosition] = []
        var events: [Event] = []

        tracking: while true {
            row += vector.dRow
            col += vector.dCol
            let here = SectorPosition(row: Int(floor(row + 0.5)), col: Int(floor(col + 0.5)))
            guard here.isInsideQuadrant else {
                events.append(.torpedoTrack(track))
                events.append(.torpedoMissed)
                break tracking
            }
            track.append(here)
            switch map[here] {
            case nil, .ship:
                continue tracking
            case .enemy:
                events.append(.torpedoTrack(track))
                if let i = enemies.firstIndex(where: { $0.isAlive && $0.position == here }) {
                    events += destroyEnemy(at: i)
                }
                break tracking
            case .star:
                events.append(.torpedoTrack(track))
                events.append(.starAbsorbedTorpedo(at: here))
                break tracking
            case .starbase:
                events.append(.torpedoTrack(track))
                events += destroyStarbase(at: here)
                break tracking
            }
        }

        if status.isOver { return events }
        events += enemiesFire()
        return events
    }

    /// Removes an enemy from the quadrant and the galaxy; wins if it was the last.
    mutating func destroyEnemy(at index: Int) -> [Event] {
        let position = enemies[index].position
        enemies[index].energy = 0
        map[position] = nil
        enemiesRemaining -= 1
        var summary = galaxy[quadrant]
        summary.enemies = max(0, summary.enemies - 1)
        galaxy[quadrant] = summary
        chart[Galaxy.index(quadrant)] = summary
        var events: [Event] = [.enemyDestroyed(at: position, kind: enemies[index].kind)]
        if enemiesRemaining <= 0 {
            events += declareVictory()
        } else if enemiesInQuadrant == 0 {
            updateAlertCondition()
        }
        return events
    }

    /// Line 5330: shooting your own starbase. Command is not amused.
    private mutating func destroyStarbase(at position: SectorPosition) -> [Event] {
        map[position] = nil
        starbasesRemaining -= 1
        var summary = galaxy[quadrant]
        summary.starbases = max(0, summary.starbases - 1)
        galaxy[quadrant] = summary
        chart[Galaxy.index(quadrant)] = summary
        var events: [Event] = [.starbaseDestroyed(at: position)]
        if starbasesRemaining > 0 || Double(enemiesRemaining) > stardate - startingStardate - missionDuration {
            events.append(.courtMartialReview)
            ship.isDocked = false
            updateAlertCondition()
        } else {
            events.append(.relievedOfCommand)
            status = .lost(.relievedOfCommand)
            events.append(defeatEvent())
        }
        return events
    }
}
