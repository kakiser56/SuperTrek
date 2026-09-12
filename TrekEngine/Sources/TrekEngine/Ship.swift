/// The eight damageable systems, in the original's order.
public enum Device: Int, CaseIterable, Hashable, Codable, Sendable {
    case warpEngines = 0
    case shortRangeSensors
    case longRangeSensors
    case beamControl
    case torpedoTubes
    case damageControl
    case shieldControl
    case computer
}

public struct DeviceState: Hashable, Codable, Sendable {
    public var device: Device
    /// Negative means damaged. Shown to two decimals, as the original did.
    public var repair: Double

    public init(device: Device, repair: Double) {
        self.device = device
        self.repair = repair
    }
}

public enum Condition: String, Hashable, Codable, Sendable {
    case docked
    case red
    case yellow
    case green
}

public struct Ship: Hashable, Codable, Sendable {
    public static let maxEnergy = 3000.0
    public static let maxTorpedoes = 10

    public var energy: Double
    public var shields: Double
    public var torpedoes: Int
    /// Indexed by `Device.rawValue`. Negative is damaged.
    public var damage: [Double]
    public var isDocked: Bool

    public init(
        energy: Double = Ship.maxEnergy,
        shields: Double = 0,
        torpedoes: Int = Ship.maxTorpedoes,
        damage: [Double] = Array(repeating: 0, count: Device.allCases.count),
        isDocked: Bool = false
    ) {
        self.energy = energy
        self.shields = shields
        self.torpedoes = torpedoes
        self.damage = damage
        self.isDocked = isDocked
    }

    public func isDamaged(_ device: Device) -> Bool {
        damage[device.rawValue] < 0
    }

    public func repairState(of device: Device) -> Double {
        damage[device.rawValue]
    }

    public mutating func setDamage(_ device: Device, _ value: Double) {
        damage[device.rawValue] = value
    }

    public var totalEnergy: Double { energy + shields }

    public var deviceStates: [DeviceState] {
        Device.allCases.map { DeviceState(device: $0, repair: damage[$0.rawValue]) }
    }
}
