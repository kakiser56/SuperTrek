import Foundation
import Observation
import TrekEngine

/// A destroyed ship's explosion, shown on the grid for a moment.
struct Burst: Identifiable, Hashable {
    var id: Int
    var position: SectorPosition
    var started = Date()
}

/// Something the engine has already removed but the player hasn't seen die yet.
struct Ghost: Identifiable, Hashable {
    var id: Int
    var position: SectorPosition
    var content: SectorContent
    var kind: EnemyKind?
}

struct LongRangeScan: Hashable {
    var center: QuadrantPosition
    var cells: [LongRangeCell]
}

struct LogLine: Identifiable, Hashable, Codable {
    var id: Int
    var text: String
    var isCommand: Bool
    var isAlert: Bool

    init(id: Int, text: String, isCommand: Bool, isAlert: Bool = false) {
        self.id = id
        self.text = text
        self.isCommand = isCommand
        self.isAlert = isAlert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        isCommand = try c.decode(Bool.self, forKey: .isCommand)
        isAlert = try c.decodeIfPresent(Bool.self, forKey: .isAlert) ?? false
    }
}

/// Owns the current game, the teletype log, and the save file.
@MainActor
@Observable
final class GameStore {
    private(set) var game: Game?
    private(set) var log: [LogLine] = []
    /// The most recent long range scan, shown as an overlay until dismissed.
    private(set) var lastLongRangeScan: LongRangeScan?
    /// Counters the bridge watches to trigger flashes and haptics.
    private(set) var bursts: [Burst] = []
    private var nextBurstID = 0
    private(set) var ghosts: [Ghost] = []
    private(set) var shots: [Shot] = []
    private var nextShotID = 0
    private(set) var hitPulse = 0
    private(set) var explosionPulse = 0
    private(set) var refusalPulse = 0
    private let sounds = SoundBank()
    /// Wrapped for the log column beside the readout.
    let narrator = Narrator(columns: 38)
    let lexicon = Lexicon.standard

    private var nextLineID = 0
    private let saveURL: URL
    private static let logLimit = 600

    /// Bump when the log's rendering changes; older saved logs are dropped.
    private static let logVersion = 2

    private struct SaveFile: Codable {
        var game: Game
        var log: [LogLine]
        var nextLineID: Int
        var logVersion: Int?
    }

    init(saveURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.saveURL = saveURL ?? documents.appendingPathComponent("supertrek-save.json")
        // `-resetSave YES` on launch discards any saved game (UI tests).
        if UserDefaults.standard.bool(forKey: "resetSave") {
            try? FileManager.default.removeItem(at: self.saveURL)
        }
        load()
        // `-autoFixture battle` on launch loads a hand-built quadrant (screenshots, UI tests).
        if let name = UserDefaults.standard.string(forKey: "autoFixture"), let fixture = Self.fixture(named: name) {
            let game = Game(fixture: fixture)
            self.game = game
            log = []
            nextLineID = 0
            append([.missionBegins(quadrantName: game.quadrantName), .shortRangeScan(game.scanSnapshot)])
            for code in (UserDefaults.standard.string(forKey: "autoCommands") ?? "").split(separator: ",") {
                if code == "NAV" { send(.navigate(course: 1, warp: 1)) }
                if code == "LRS" { send(.longRangeScan) }
                if code == "TOR" { send(.fireTorpedo(course: 2)) }
            }
        }
        // `-autoStartSeed 11` on launch begins a fresh seeded game (screenshots, UI tests).
        if let seed = UInt64(UserDefaults.standard.string(forKey: "autoStartSeed") ?? "") {
            newGame(seed: seed)
            for code in (UserDefaults.standard.string(forKey: "autoCommands") ?? "").split(separator: ",") {
                switch code {
                case "LRS": send(.longRangeScan)
                case "NAV": send(.navigate(course: 1, warp: 1))
                case "TOR": send(.fireTorpedo(course: 2))
                case "SRS": send(.shortRangeScan)
                case "DAM": send(.damageReport)
                case "COM1": send(.computer(.statusReport))
                case "COM2": send(.computer(.torpedoData))
                default: break
                }
            }
        }
    }

    /// For previews: a store already holding a game.
    init(game: Game, events: [Event] = []) {
        saveURL = URL(fileURLWithPath: "/dev/null")
        self.game = game
        append(events)
    }

    static func fixture(named name: String) -> Game.Fixture? {
        switch name {
        case "battle":
            var f = Game.Fixture()
            f.enemies = [Enemy(position: SectorPosition(row: 2, col: 6), energy: 150, kind: .warbird)]
            f.stars = [SectorPosition(row: 1, col: 1), SectorPosition(row: 6, col: 3), SectorPosition(row: 7, col: 7), SectorPosition(row: 4, col: 7)]
            f.starbase = SectorPosition(row: 8, col: 2)
            f.ship.shields = 500
            f.ship.energy = 2500
            f.otherQuadrants[QuadrantPosition(row: 1, col: 1)] = QuadrantSummary(enemies: 2, starbases: 0, stars: 3)
            f.otherQuadrants[QuadrantPosition(row: 6, col: 7)] = QuadrantSummary(enemies: 1, starbases: 1, stars: 5)
            return f
        default:
            return nil
        }
    }

    // MARK: Play

    func newGame(seed: UInt64? = nil, profile: MissionProfile = .classic) {
        let seed = seed ?? UInt64.random(in: 1...UInt64(UInt32.max))
        let (game, events) = Game.start(seed: seed, profile: profile)
        self.game = game
        log = []
        nextLineID = 0
        append(events)
        save()
    }

    func send(_ command: Command) {
        guard var game, game.status == .playing else { return }
        lastLongRangeScan = nil
        appendLine("> " + describe(command), isCommand: true)
        let before = game
        let events = game.apply(command)
        self.game = game
        append(events)
        torpedoInFlight = false
        for event in events {
            switch event {
            case let .longRangeScan(center, cells):
                lastLongRangeScan = LongRangeScan(center: center, cells: cells)
            case let .enemyDestroyed(position, _), let .starbaseDestroyed(position):
                let ghost = torpedoInFlight
                    ? before.map[position].map { Ghost(id: nextBurstID, position: position, content: $0, kind: before.enemy(at: position)?.kind) }
                    : nil
                explode(at: position, after: torpedoInFlight ? FireLinesView.torpedoFlightTime : 0, keeping: ghost)
            case let .hitOnShip(_, from, _, _):
                fire(from: from, to: game.sector, kind: .enemyFire)
            case let .beamHit(_, at, _), let .beamNoDamage(at):
                fire(from: game.sector, to: at, kind: .beam)
            case let .torpedoTrack(track):
                if let end = track.last {
                    fire(from: game.sector, to: end, kind: .torpedo)
                    torpedoInFlight = true
                }
            default:
                break
            }
        }
        let moved = game.stardate != before.stardate || game.sector != before.sector
        play(TurnEffects.derive(from: command, events: events, moved: moved), explosionDelay: torpedoInFlight ? FireLinesView.torpedoFlightTime : 0)
        save()
    }

    /// True while the most recent command's torpedo is still crossing the grid.
    private var torpedoInFlight = false

    private func explode(at position: SectorPosition, after delay: TimeInterval = 0, keeping ghost: Ghost? = nil) {
        let id = nextBurstID
        nextBurstID += 1
        let frozen = UserDefaults.standard.bool(forKey: "freezeBursts")
        if let ghost { ghosts.append(ghost) }
        // Frozen with a torpedo in flight: hold the ghost and never explode (screenshots).
        if frozen, ghost != nil { return }
        Task {
            if delay > 0, !frozen {
                try? await Task.sleep(for: .seconds(delay))
            }
            if let ghost { ghosts.removeAll { $0.id == ghost.id } }
            let burst = Burst(id: id, position: position)
            bursts.append(burst)
            // `-freezeBursts` keeps explosions on screen for screenshots.
            guard !frozen else { return }
            try? await Task.sleep(for: .seconds(StarBurstView.duration + 0.1))
            bursts.removeAll { $0.id == burst.id }
        }
    }

    private func fire(from: SectorPosition, to: SectorPosition, kind: Shot.Kind) {
        let shot = Shot(id: nextShotID, from: from, to: to, kind: kind)
        nextShotID += 1
        shots.append(shot)
        guard !UserDefaults.standard.bool(forKey: "freezeBursts") else { return }
        Task {
            try? await Task.sleep(for: .seconds(FireLinesView.duration + 0.1))
            shots.removeAll { $0.id == shot.id }
        }
    }

    private func play(_ effects: TurnEffects, explosionDelay: TimeInterval = 0) {
        if effects.hits > 0 { hitPulse += 1 }
        if effects.refused { refusalPulse += 1 }
        let soundOn = FeedbackSettings.soundEnabled
        // Explosions wait for a torpedo to arrive; everything else is immediate.
        for sound in effects.sounds where sound != .explosion || explosionDelay == 0 {
            if soundOn { sounds.play(sound) }
        }
        if explosionDelay == 0 {
            if effects.enemyDestroyed { explosionPulse += 1 }
            return
        }
        if effects.enemyDestroyed || effects.sounds.contains(.explosion) {
            Task {
                try? await Task.sleep(for: .seconds(explosionDelay))
                if effects.enemyDestroyed { explosionPulse += 1 }
                if soundOn { sounds.play(.explosion) }
            }
        }
    }

    func dismissLongRangeScan() {
        lastLongRangeScan = nil
    }

    func abandon() {
        game = nil
        log = []
        try? FileManager.default.removeItem(at: saveURL)
    }

    // MARK: Log

    private func append(_ events: [Event]) {
        for event in events {
            // The grid and status strip are the scan; the log just notes it.
            if case let .shortRangeScan(scan) = event {
                appendLine("SCANNING QUADRANT \(scan.quadrant.row) , \(scan.quadrant.col)", isCommand: false)
                continue
            }
            if case let .longRangeScan(center, _) = event {
                appendLine("LONG RANGE SCAN FOR QUADRANT \(center.row) , \(center.col)", isCommand: false)
                continue
            }
            let alert = Self.isAlert(event)
            for line in narrator.lines(for: event) {
                appendLine(line, isCommand: false, isAlert: alert)
            }
        }
    }

    private static func isAlert(_ event: Event) -> Bool {
        switch event {
        case .combatAreaConditionRed, .shieldsDangerouslyLow, .hitOnShip, .deviceDamagedByHit,
             .shipDestroyed, .stranded, .relievedOfCommand, .starbaseDestroyed, .courtMartialReview:
            true
        default:
            false
        }
    }

    private func appendLine(_ text: String, isCommand: Bool, isAlert: Bool = false) {
        log.append(LogLine(id: nextLineID, text: text, isCommand: isCommand, isAlert: isAlert))
        nextLineID += 1
        if log.count > Self.logLimit {
            log.removeFirst(log.count - Self.logLimit)
        }
    }

    private func describe(_ command: Command) -> String {
        switch command {
        case let .navigate(course, warp): "NAV \(trim(course)) \(trim(warp))"
        case .shortRangeScan: "SRS"
        case .longRangeScan: "LRS"
        case let .fireBeams(energy): "\(String(lexicon.beamWeapon.prefix(3))) \(energy)"
        case let .fireTorpedo(course): "TOR \(trim(course))"
        case let .setShields(energy): "SHE \(energy)"
        case .damageReport: "DAM"
        case let .authorizeRepairs(yes): yes ? "Y" : "N"
        case let .computer(function): "COM \(computerCode(function))"
        case .resign: "XXX"
        }
    }

    private func computerCode(_ function: ComputerFunction) -> String {
        switch function {
        case .galacticRecord: "0"
        case .statusReport: "1"
        case .torpedoData: "2"
        case .starbaseNavigationData: "3"
        case .directionDistance: "4"
        case .regionMap: "5"
        }
    }

    private func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    // MARK: Persistence

    func save() {
        guard let game else { return }
        let file = SaveFile(game: game, log: log, nextLineID: nextLineID, logVersion: Self.logVersion)
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            // A failed save is not worth interrupting play over.
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let file = try? JSONDecoder().decode(SaveFile.self, from: data) else { return }
        game = file.game
        if file.logVersion == Self.logVersion {
            log = file.log
            nextLineID = file.nextLineID
        } else {
            log = []
            nextLineID = 0
            append([.enteringQuadrant(quadrantName: file.game.quadrantName), .shortRangeScan(file.game.scanSnapshot)])
        }
    }
}
