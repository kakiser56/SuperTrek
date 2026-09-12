/// Every franchise-adjacent word in one place. The engine and narrator never
/// hard-code a ship, enemy, or weapon name; they ask the lexicon.
public struct Lexicon: Hashable, Codable, Sendable {
    public var shipName: String
    public var enemyName: String
    public var enemyPlural: String
    public var enemyShipClass: String
    public var cruiserName: String
    public var warbirdName: String
    public var alliance: String
    public var command: String
    public var beamWeapon: String
    public var torpedo: String
    public var torpedoPlural: String
    public var helm: String
    public var engineer: String
    public var scienceOfficer: String
    public var communications: String
    public var shipGlyph: String
    public var enemyGlyph: String
    public var warbirdGlyph: String
    public var starbaseGlyph: String
    public var starGlyph: String
    public var emptyGlyph: String

    public init(
        shipName: String = "VANGUARD",
        enemyName: String = "INVADER",
        enemyPlural: String = "INVADERS",
        enemyShipClass: String = "WARSHIP",
        cruiserName: String = "BATTLE CRUISER",
        warbirdName: String = "WARBIRD",
        alliance: String = "ALLIANCE",
        command: String = "FLEET COMMAND",
        beamWeapon: String = "LASER",
        torpedo: String = "TORPEDO",
        torpedoPlural: String = "TORPEDOES",
        helm: String = "THE HELMSMAN",
        engineer: String = "THE CHIEF ENGINEER",
        scienceOfficer: String = "THE SCIENCE OFFICER",
        communications: String = "THE COMMUNICATIONS OFFICER",
        shipGlyph: String = "<*>",
        enemyGlyph: String = "+K+",
        warbirdGlyph: String = "+R+",
        starbaseGlyph: String = ">!<",
        starGlyph: String = " * ",
        emptyGlyph: String = "   "
    ) {
        self.shipName = shipName
        self.enemyName = enemyName
        self.enemyPlural = enemyPlural
        self.enemyShipClass = enemyShipClass
        self.cruiserName = cruiserName
        self.warbirdName = warbirdName
        self.alliance = alliance
        self.command = command
        self.beamWeapon = beamWeapon
        self.torpedo = torpedo
        self.torpedoPlural = torpedoPlural
        self.helm = helm
        self.engineer = engineer
        self.scienceOfficer = scienceOfficer
        self.communications = communications
        self.shipGlyph = shipGlyph
        self.enemyGlyph = enemyGlyph
        self.warbirdGlyph = warbirdGlyph
        self.starbaseGlyph = starbaseGlyph
        self.starGlyph = starGlyph
        self.emptyGlyph = emptyGlyph
    }

    public static let standard = Lexicon()

    public func name(of device: Device) -> String {
        switch device {
        case .warpEngines: "WARP ENGINES"
        case .shortRangeSensors: "SHORT RANGE SENSORS"
        case .longRangeSensors: "LONG RANGE SENSORS"
        case .beamControl: "\(beamWeapon) CONTROL"
        case .torpedoTubes: "\(torpedo) TUBES"
        case .damageControl: "DAMAGE CONTROL"
        case .shieldControl: "SHIELD CONTROL"
        case .computer: "LIBRARY-COMPUTER"
        }
    }

    /// e.g. "INVADER WARBIRD".
    public func name(of kind: EnemyKind) -> String {
        switch kind {
        case .cruiser: "\(enemyName) \(cruiserName)"
        case .warbird: "\(enemyName) \(warbirdName)"
        }
    }

    public func glyph(for kind: EnemyKind) -> String {
        switch kind {
        case .cruiser: enemyGlyph
        case .warbird: warbirdGlyph
        }
    }

    public func glyph(for content: SectorContent?) -> String {
        switch content {
        case .ship: shipGlyph
        case .enemy: enemyGlyph
        case .starbase: starbaseGlyph
        case .star: starGlyph
        case nil: emptyGlyph
        }
    }
}
