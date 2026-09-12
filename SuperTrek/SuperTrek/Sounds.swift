import AVFoundation

enum GameSound: CaseIterable {
    case hit, explosion, laser, torpedo, warp, dock, error, victory, defeat
}

/// Plays short synthesized tones. Everything is rendered once at launch, so
/// there are no audio assets and no decoding at play time.
@MainActor
final class SoundBank {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [Lane: AVAudioPlayerNode] = [:]
    private var buffers: [GameSound: AVAudioPCMBuffer] = [:]
    private var started = false

    /// Sounds on the same lane queue up; different lanes overlap.
    private enum Lane: CaseIterable { case hits, weapons, engines, ui }

    init() {
        for lane in Lane.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players[lane] = player
        }
        for sound in GameSound.allCases {
            buffers[sound] = Synth.render(sound, format: format)
        }
    }

    func play(_ sound: GameSound) {
        start()
        guard engine.isRunning, let buffer = buffers[sound], let player = players[lane(for: sound)] else { return }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func start() {
        guard !started else { return }
        started = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        engine.mainMixerNode.outputVolume = 0.9
        try? engine.start()
    }

    private func lane(for sound: GameSound) -> Lane {
        switch sound {
        case .hit, .explosion: .hits
        case .laser, .torpedo: .weapons
        case .warp: .engines
        case .dock, .error, .victory, .defeat: .ui
        }
    }
}

/// Tiny additive synth: each sound is a closure from time to amplitude,
/// with phase accumulation for sweeps and a seeded noise source.
enum Synth {
    static func render(_ sound: GameSound, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let samples: [Float]
        switch sound {
        case .hit: samples = hit(rate)
        case .explosion: samples = explosion(rate)
        case .laser: samples = laser(rate)
        case .torpedo: samples = torpedo(rate)
        case .warp: samples = warp(rate)
        case .dock: samples = dock(rate)
        case .error: samples = error(rate)
        case .victory: samples = victory(rate)
        case .defeat: samples = defeat(rate)
        }
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }

    // MARK: Building blocks

    private struct Noise {
        var state: UInt32 = 0x1234_5678
        mutating func next() -> Float {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state >> 8) / Float(1 << 24) * 2 - 1
        }
    }

    /// Runs a generator over a duration. The generator gets time, progress
    /// 0...1, a noise sample, and a phase accumulator it can advance.
    private static func run(
        _ duration: Double, _ rate: Double,
        _ body: (_ t: Double, _ p: Double, _ noise: Float, _ phase: inout Double) -> Float
    ) -> [Float] {
        let count = Int(duration * rate)
        var out = [Float](repeating: 0, count: count)
        var noise = Noise()
        var phase = 0.0
        var lowpass: Float = 0
        for i in 0..<count {
            let t = Double(i) / rate
            let sample = body(t, t / duration, noise.next(), &phase)
            // A one-pole filter takes the digital edge off everything.
            lowpass += 0.6 * (sample - lowpass)
            out[i] = max(-1, min(1, lowpass))
        }
        // Short fade out to avoid a click at the end.
        let fade = min(count, Int(0.01 * rate))
        for i in 0..<fade { out[count - 1 - i] *= Float(i) / Float(fade) }
        return out
    }

    private static func tone(_ frequency: Double, _ rate: Double, _ phase: inout Double) -> Float {
        phase += frequency / rate
        return Float(sin(2 * .pi * phase))
    }

    private static func square(_ frequency: Double, _ rate: Double, _ phase: inout Double) -> Float {
        phase += frequency / rate
        return phase.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
    }

    private static func saw(_ frequency: Double, _ rate: Double, _ phase: inout Double) -> Float {
        phase += frequency / rate
        return Float(phase.truncatingRemainder(dividingBy: 1)) * 2 - 1
    }

    // MARK: Sounds

    /// Enemy fire striking the shields: a crack of noise over a low thump.
    private static func hit(_ rate: Double) -> [Float] {
        var rumble: Float = 0
        return run(0.45, rate) { t, _, noise, phase in
            rumble += 0.15 * (noise - rumble)
            let crack = noise * Float(exp(-14 * t)) * 0.8
            let thump = tone(48, rate, &phase) * Float(exp(-5 * t)) * 0.7
            return crack + rumble * Float(exp(-6 * t)) * 0.9 + thump
        }
    }

    /// Something blowing up: slow noise with a long tail.
    private static func explosion(_ rate: Double) -> [Float] {
        var low: Float = 0
        return run(0.9, rate) { t, _, noise, _ in
            low += 0.08 * (noise - low)
            return low * Float(exp(-3.5 * t)) * 1.8 + noise * Float(exp(-20 * t)) * 0.4
        }
    }

    /// A descending square-wave zap.
    private static func laser(_ rate: Double) -> [Float] {
        run(0.3, rate) { _, p, _, phase in
            square(1500 - 1250 * p, rate, &phase) * Float(1 - p) * 0.22
        }
    }

    /// A rising whoosh: sine sweep with a little air behind it.
    private static func torpedo(_ rate: Double) -> [Float] {
        var air: Float = 0
        return run(0.55, rate) { _, p, noise, phase in
            air += 0.2 * (noise - air)
            let env = Float(sin(.pi * p))
            return tone(220 + 900 * p * p, rate, &phase) * env * 0.35 + air * env * 0.25
        }
    }

    /// Warp engines spooling up and settling.
    private static func warp(_ rate: Double) -> [Float] {
        run(0.8, rate) { _, p, _, phase in
            let env = Float(sin(.pi * p))
            let f = 70 + 520 * p
            return saw(f, rate, &phase) * env * 0.18 + Float(sin(2 * .pi * phase * 0.5)) * env * 0.1
        }
    }

    /// Two-note docking chime.
    private static func dock(_ rate: Double) -> [Float] {
        run(0.5, rate) { t, _, _, phase in
            let f = t < 0.22 ? 660.0 : 880.0
            let local = t < 0.22 ? t : t - 0.22
            return tone(f, rate, &phase) * Float(exp(-6 * local)) * 0.3
        }
    }

    /// Refused order: a low buzz.
    private static func error(_ rate: Double) -> [Float] {
        run(0.22, rate) { _, p, _, phase in
            square(110, rate, &phase) * Float(1 - p) * 0.2
        }
    }

    /// Four-note rising arpeggio.
    private static func victory(_ rate: Double) -> [Float] {
        let notes = [523.25, 659.25, 783.99, 1046.5]
        return run(1.3, rate) { t, _, _, phase in
            let index = min(3, Int(t / 0.3))
            let local = t - Double(index) * 0.3
            let sustain: Float = index == 3 ? 1.5 : 1
            return tone(notes[index], rate, &phase) * Float(exp(-4 * local / Double(sustain))) * 0.3
        }
    }

    /// Falling tone.
    private static func defeat(_ rate: Double) -> [Float] {
        run(1.1, rate) { _, p, _, phase in
            tone(240 - 140 * p, rate, &phase) * Float(1 - p * p) * 0.3
        }
    }
}
