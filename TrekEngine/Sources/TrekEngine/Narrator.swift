import Foundation

/// Turns events into the lines a 1978 teletype would have printed.
public struct Narrator: Sendable {
    /// The widest line the narrator produces. Matches the scan readout.
    public static let columns = 57

    public var lexicon: Lexicon

    public init(lexicon: Lexicon = .standard) {
        self.lexicon = lexicon
    }

    public func lines(for events: [Event]) -> [String] {
        events.flatMap(lines(for:))
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func lines(for event: Event) -> [String] {
        let L = lexicon
        switch event {
        case let .missionBriefing(enemies, deadline, days, starbases):
            return [
                "YOUR ORDERS ARE AS FOLLOWS:",
                "     DESTROY THE \(enemies) \(L.enemyName) WARSHIPS WHICH HAVE INVADED",
                "   THE GALAXY BEFORE THEY CAN ATTACK \(L.alliance)",
                "   HEADQUARTERS ON STARDATE \(num(deadline)).  THIS GIVES YOU",
                "   \(num(days)) DAYS.  THERE \(starbases == 1 ? "IS" : "ARE") \(starbases) STARBASE\(starbases == 1 ? "" : "S") IN THE GALAXY",
                "   FOR RESUPPLYING YOUR SHIP.",
                "",
                "SENSOR LEGEND:",
                "   \(L.shipGlyph) YOUR SHIP     \(L.starbaseGlyph) STARBASE     \(L.starGlyph.trimmingCharacters(in: .whitespaces))  STAR",
                "   \(L.enemyGlyph) \(L.name(of: .cruiser))     \(L.warbirdGlyph) \(L.name(of: .warbird))",
            ]
        case let .missionBegins(name):
            return ["YOUR MISSION BEGINS WITH YOUR STARSHIP LOCATED", "IN THE GALACTIC QUADRANT, '\(name)'."]
        case let .enteringQuadrant(name):
            return ["NOW ENTERING \(name) QUADRANT . . ."]
        case .combatAreaConditionRed:
            return ["COMBAT AREA      CONDITION RED"]
        case .shieldsDangerouslyLow:
            return ["   SHIELDS DANGEROUSLY LOW"]

        case let .shortRangeScan(scan):
            return scanLines(scan)
        case .shortRangeSensorsOut:
            return ["*** SHORT RANGE SENSORS ARE OUT ***"]
        case .docked:
            return ["SHIELDS DROPPED FOR DOCKING PURPOSES"]
        case let .longRangeScan(center, cells):
            var out = ["LONG RANGE SCAN FOR QUADRANT \(center.row) , \(center.col)", "-------------------"]
            for row in 0..<3 {
                let codes = (0..<3).map { col -> String in
                    switch cells[row * 3 + col] {
                    case .outsideGalaxy: "***"
                    case let .quadrant(summary): code(summary)
                    }
                }
                out.append(": " + codes.joined(separator: " : ") + " :")
                out.append("-------------------")
            }
            return out
        case .longRangeSensorsInoperable:
            return ["LONG RANGE SENSORS ARE INOPERABLE"]

        case .incorrectCourse:
            return ["\(L.helm) REPORTS  'INCORRECT COURSE DATA, SIR!'"]
        case let .warpEnginesDamaged(maxWarp):
            return ["WARP ENGINES ARE DAMAGED.  MAXIMUM SPEED = WARP \(num(maxWarp))"]
        case let .enginesWontTake(warp):
            return ["\(L.engineer) REPORTS", "  'THE ENGINES WON'T TAKE WARP \(num(warp))!'"]
        case let .insufficientEnergy(warp, deployed):
            var out = ["ENGINEERING REPORTS  'INSUFFICIENT ENERGY AVAILABLE", "                      FOR MANEUVERING AT WARP \(num(warp))!'"]
            if let deployed {
                out.append("DEFLECTOR CONTROL ROOM ACKNOWLEDGES \(deployed) UNITS OF ENERGY")
                out.append("                        PRESENTLY DEPLOYED TO SHIELDS.")
            }
            return out
        case let .warpEnginesShutDown(at):
            return ["WARP ENGINES SHUT DOWN AT SECTOR \(at.row) , \(at.col)", "  DUE TO BAD NAVIGATION"]
        case let .perimeterCrossingDenied(quadrant, sector):
            return [
                "\(L.communications) REPORTS",
                "  MESSAGE FROM \(L.command):",
                "  'PERMISSION TO ATTEMPT CROSSING OF GALACTIC PERIMETER",
                "  IS HEREBY *DENIED*.  SHUT DOWN YOUR ENGINES.'",
                "\(L.engineer) REPORTS  'WARP ENGINES SHUT DOWN",
                "  AT SECTOR \(sector.row) , \(sector.col) OF QUADRANT \(quadrant.row) , \(quadrant.col).'",
            ]
        case .shieldControlSuppliedEnergy:
            return ["SHIELD CONTROL SUPPLIES ENERGY TO COMPLETE THE MANEUVER."]
        case let .repairCompleted(device):
            return ["DAMAGE CONTROL REPORT:", "  \(L.name(of: device)) REPAIR COMPLETED."]
        case let .deviceDamagedRandomly(device):
            return ["DAMAGE CONTROL REPORT:", "  \(L.name(of: device)) DAMAGED"]
        case let .deviceImproved(device):
            return ["DAMAGE CONTROL REPORT:", "  \(L.name(of: device)) STATE OF REPAIR IMPROVED"]

        case .starbaseShieldsProtect:
            return ["STARBASE SHIELDS PROTECT THE \(L.shipName)"]
        case let .hitOnShip(units, from, kind, remaining):
            return ["\(units) UNIT HIT ON \(L.shipName) FROM \(L.name(of: kind))", "  AT SECTOR \(from.row) , \(from.col)   <SHIELDS DOWN TO \(remaining) UNITS>"]
        case let .deviceDamagedByHit(device):
            return ["DAMAGE CONTROL REPORTS", "  '\(L.name(of: device)) DAMAGED BY THE HIT'"]
        case .shipDestroyed:
            return ["THE \(L.shipName) HAS BEEN DESTROYED.", "THE \(L.alliance) WILL BE CONQUERED."]

        case .noEnemiesInQuadrant:
            return ["\(L.scienceOfficer) REPORTS", "  'SENSORS SHOW NO ENEMY SHIPS IN THIS QUADRANT'"]
        case .beamControlDisabled:
            return ["\(L.beamWeapon) CONTROL IS DISABLED"]
        case .computerFailureHampersAccuracy:
            return ["COMPUTER FAILURE HAMPERS ACCURACY"]
        case let .notEnoughEnergy(available):
            return ["INSUFFICIENT ENERGY.  ENERGY AVAILABLE = \(available) UNITS"]
        case let .beamHit(units, at, remaining):
            var out = ["\(units) UNIT HIT ON \(L.enemyName) AT SECTOR \(at.row) , \(at.col)"]
            if remaining > 0 { out.append("   (SENSORS SHOW \(remaining) UNITS REMAINING)") }
            return out
        case let .beamNoDamage(at):
            return ["SENSORS SHOW NO DAMAGE TO ENEMY AT \(at.row) , \(at.col)"]
        case let .enemyDestroyed(_, kind):
            return ["*** \(L.name(of: kind)) DESTROYED ***"]

        case .torpedoesExpended:
            return ["ALL \(L.torpedoPlural) EXPENDED"]
        case .torpedoTubesInoperable:
            return ["\(L.torpedo) TUBES ARE NOT OPERATIONAL"]
        case let .torpedoTrack(track):
            return ["\(L.torpedo) TRACK:"] + track.map { "               \($0.row) , \($0.col)" }
        case .torpedoMissed:
            return ["\(L.torpedo) MISSED"]
        case let .starAbsorbedTorpedo(at):
            return ["STAR AT \(at.row) , \(at.col) ABSORBED \(L.torpedo) ENERGY."]
        case .starbaseDestroyed:
            return ["*** STARBASE DESTROYED ***"]
        case .courtMartialReview:
            return ["\(L.command) REVIEWING YOUR RECORD TO CONSIDER", "COURT MARTIAL!"]
        case .relievedOfCommand:
            return ["THAT DOES IT, CAPTAIN!!  YOU ARE HEREBY RELIEVED", "OF COMMAND AND SENTENCED TO 99 STARDATES AT HARD", "LABOR ON CYGNUS 12!!"]

        case .shieldControlInoperable:
            return ["SHIELD CONTROL INOPERABLE"]
        case .shieldsUnchanged:
            return ["<SHIELDS UNCHANGED>"]
        case .notTheTreasury:
            return ["SHIELD CONTROL REPORTS", "  'THIS IS NOT THE \(L.alliance) TREASURY.'", "<SHIELDS UNCHANGED>"]
        case let .shieldsSet(units):
            return ["DEFLECTOR CONTROL ROOM REPORT:", "  'SHIELDS NOW AT \(units) UNITS PER YOUR COMMAND.'"]

        case .damageReportUnavailable:
            return ["DAMAGE CONTROL REPORT NOT AVAILABLE"]
        case let .damageReport(states):
            var out = ["DEVICE             STATE OF REPAIR"]
            for state in states {
                let name = L.name(of: state.device).padding(toLength: 25, withPad: " ", startingAt: 0)
                out.append("\(name)\(num(floor(state.repair * 100) / 100))")
            }
            return out
        case let .repairOffer(stardates):
            return [
                "TECHNICIANS STANDING BY TO EFFECT REPAIRS TO YOUR",
                "SHIP;",
                "ESTIMATED TIME TO REPAIR: \(num(stardates)) STARDATES.",
                "WILL YOU AUTHORIZE THE REPAIR ORDER (Y/N)?",
            ]
        case .repairsCompleted:
            return ["REPAIRS COMPLETED."]

        case .computerDisabled:
            return ["COMPUTER DISABLED"]
        case let .galacticRecord(center, chart):
            var out = [
                "        COMPUTER RECORD OF GALAXY FOR QUADRANT \(center.row) , \(center.col)",
                "       1     2     3     4     5     6     7     8",
                "     ----- ----- ----- ----- ----- ----- ----- -----",
            ]
            for row in 1...Game.gridSize {
                let cells = (1...Game.gridSize).map { col -> String in
                    let summary = chart[(row - 1) * Game.gridSize + (col - 1)]
                    return summary.map(code) ?? "***"
                }
                out.append(" \(row)     " + cells.joined(separator: "   "))
                out.append("     ----- ----- ----- ----- ----- ----- ----- -----")
            }
            return out
        case let .statusReport(enemies, remaining, starbases):
            var out = [
                "   STATUS REPORT:",
                "\(L.enemyName)\(enemies == 1 ? "" : "S") LEFT: \(enemies)",
                "MISSION MUST BE COMPLETED IN \(num(remaining)) STARDATES",
            ]
            if starbases > 0 {
                out.append("THE \(L.alliance) IS MAINTAINING \(starbases) STARBASE\(starbases == 1 ? "" : "S")")
                out.append("  IN THE GALAXY")
            } else {
                out.append("YOUR STUPIDITY HAS LEFT YOU ON YOUR OWN IN")
                out.append("  THE GALAXY -- YOU HAVE NO STARBASES LEFT!")
            }
            return out
        case let .torpedoData(targets):
            var out: [String] = []
            for target in targets {
                out.append("FROM \(L.shipName) TO \(L.enemyName) AT SECTOR \(target.position.row) , \(target.position.col)")
                out += navigationLines(target.navigation)
            }
            return out
        case .noStarbaseInQuadrant:
            return ["\(L.scienceOfficer) REPORTS,", "  'SENSORS SHOW NO STARBASES IN THIS QUADRANT.'"]
        case let .starbaseNavigationData(data):
            return ["FROM \(L.shipName) TO STARBASE:"] + navigationLines(data)
        case let .directionDistance(data):
            return navigationLines(data)
        case .regionMap:
            var out = ["                        THE GALAXY", "       1     2     3     4     5     6     7     8", "     ----- ----- ----- ----- ----- ----- ----- -----"]
            for row in 1...Game.gridSize {
                let left = Regions.regionName(row: row, rightHalf: false)
                let right = Regions.regionName(row: row, rightHalf: true)
                out.append(" \(row)     " + left.padding(toLength: 24, withPad: " ", startingAt: 0) + right)
                out.append("     ----- ----- ----- ----- ----- ----- ----- -----")
            }
            return out

        case .stranded:
            return [
                "** FATAL ERROR **",
                "YOU'VE JUST STRANDED YOUR SHIP IN SPACE",
                "YOU HAVE INSUFFICIENT MANEUVERING ENERGY, AND SHIELD",
                "CONTROL IS PRESENTLY INCAPABLE OF CROSS-CIRCUITING",
                "TO ENGINE ROOM!!",
            ]
        case .resigned:
            return ["COMMAND RESIGNED."]
        case let .victory(stardate, efficiency):
            return [
                "IT IS STARDATE \(num(stardate))",
                "CONGRATULATIONS, CAPTAIN!  THE LAST \(L.enemyName)",
                "\(L.enemyShipClass) MENACING THE \(L.alliance)",
                "HAS BEEN DESTROYED.",
                "YOUR EFFICIENCY RATING IS \(num(floor(efficiency * 100) / 100))",
            ]
        case let .defeat(stardate, enemies, canRestart):
            var out = [
                "IT IS STARDATE \(num(stardate))",
                "THERE WERE \(enemies) \(L.enemyName) \(L.enemyShipClass)S LEFT AT",
                "THE END OF YOUR MISSION.",
            ]
            if canRestart {
                out.append("THE \(L.alliance) IS IN NEED OF A NEW STARSHIP")
                out.append("COMMANDER FOR A SIMILAR MISSION -- IF THERE IS")
                out.append("A VOLUNTEER,")
                out.append("STEP FORWARD.")
            }
            return out
        }
    }

    // MARK: Helpers

    private func scanLines(_ scan: ScanSnapshot) -> [String] {
        let panel: [String] = [
            "        STARDATE           \(num(scan.stardate))",
            "        CONDITION          \(conditionLabel(scan.condition))",
            "        QUADRANT           \(scan.quadrant.row) , \(scan.quadrant.col)",
            "        SECTOR             \(scan.sector.row) , \(scan.sector.col)",
            "        \(lexicon.torpedoPlural)         \(scan.torpedoes)",
            "        TOTAL ENERGY       \(scan.totalEnergy)",
            "        SHIELDS            \(scan.shields)",
            "        \(lexicon.enemyPlural) REMAINING  \(scan.enemiesRemaining)",
        ]
        var out = ["---------------------------------"]
        for row in 0..<Game.gridSize {
            let cells = (0..<Game.gridSize).map { col -> String in
                let position = SectorPosition(row: row + 1, col: col + 1)
                if let enemy = scan.enemies.first(where: { $0.position == position }) {
                    return lexicon.glyph(for: enemy.kind)
                }
                return lexicon.glyph(for: scan.cells[row * Game.gridSize + col])
            }
            out.append(cells.joined() + panel[row])
        }
        out.append("---------------------------------")
        return out
    }

    private func conditionLabel(_ condition: Condition) -> String {
        switch condition {
        case .docked: "DOCKED"
        case .red: "*RED*"
        case .yellow: "YELLOW"
        case .green: "GREEN"
        }
    }

    private func navigationLines(_ data: NavigationData) -> [String] {
        ["DIRECTION = \(num(data.course))", "DISTANCE = \(num(floor(data.distance * 100) / 100))"]
    }

    private func code(_ summary: QuadrantSummary) -> String {
        String(format: "%03d", summary.code)
    }

    /// Prints whole numbers bare and fractions to at most two decimals.
    func num(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
