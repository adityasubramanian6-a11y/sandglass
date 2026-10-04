import AVFoundation

/// Natural sounds that play while the sand runs. They are synthesised live rather than looped
/// from files, so they never repeat and can follow the sand (the "Falling sand" sound stops
/// the moment the sand stops).
enum FocusSound: String, CaseIterable, Identifiable {
    case off, sand, rain, ocean, fire, brownNoise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .sand: "Falling sand"
        case .rain: "Rain"
        case .ocean: "Ocean waves"
        case .fire: "Fireplace"
        case .brownNoise: "Brown noise"
        }
    }

    var symbol: String {
        switch self {
        case .off: "speaker.slash"
        case .sand: "hourglass"
        case .rain: "cloud.rain"
        case .ocean: "water.waves"
        case .fire: "flame"
        case .brownNoise: "waveform"
        }
    }

    fileprivate var synthKind: Int32 {
        switch self {
        case .off: 0
        case .sand: 1
        case .rain: 2
        case .ocean: 3
        case .fire: 4
        case .brownNoise: 5
        }
    }
}

/// The sound played when a phase ends.
enum Chime: String, CaseIterable, Identifiable {
    case bowl, bell, windChimes, marimba, woodBlock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bowl: "Singing bowl"
        case .bell: "Soft bell"
        case .windChimes: "Wind chimes"
        case .marimba: "Marimba"
        case .woodBlock: "Wood block"
        }
    }

    /// File in the app bundle, also used as the notification sound.
    var fileName: String { "chime-\(rawValue).wav" }

    static var current: Chime { Chime(rawValue: Prefs.chimeName) ?? .bowl }
}

@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let params: UnsafeMutablePointer<SynthState>
    private var chimePlayer: AVAudioPlayer?
    private var stopAt: Date?
    private var lastStartAttempt: Date?

    /// True while the focus sound engine is playing (including its fade-out).
    private(set) var isRunning = false

    private init() {
        params = UnsafeMutablePointer<SynthState>.allocate(capacity: 1)
        params.initialize(to: SynthState())
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        // Mix with other audio so a podcast or music can keep playing alongside.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: Focus sounds

    /// Called every frame with what the session is doing.
    func update(sound: FocusSound, active: Bool, flowing: Bool, volume: Float) {
        let wanted = active && sound != .off
        if wanted {
            stopAt = nil
            // Restart if needed (a phone call or headphones change can stop the engine), but
            // don't hammer a failing audio session every frame.
            if !isRunning || !engine.isRunning,
               Date().timeIntervalSince(lastStartAttempt ?? .distantPast) > 3 {
                start()
            }
            params.pointee.kind = sound.synthKind
            // Falling sand follows the sand exactly; the others just dip while paused.
            let level: Float = sound == .sand ? (flowing ? 1 : 0) : (flowing ? 1 : 0.35)
            params.pointee.targetGain = max(0, min(1, volume)) * level
        } else if isRunning {
            params.pointee.targetGain = 0
            let deadline = stopAt ?? Date().addingTimeInterval(2)
            stopAt = deadline
            if Date() >= deadline { stop() }
        }
    }

    private func start() {
        lastStartAttempt = Date()
        activateSession()
        if source == nil {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            let node = Self.makeSourceNode(format: format, state: params)
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            source = node
        }
        params.pointee.gain = 0
        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// Built outside the main actor: the render block runs on the real-time audio thread.
    nonisolated private static func makeSourceNode(format: AVAudioFormat,
                                                   state: UnsafeMutablePointer<SynthState>) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            SynthState.render(state, into: data, frames: Int(frameCount))
            for extra in buffers.dropFirst() {
                extra.mData?.copyMemory(from: data, byteCount: Int(frameCount) * MemoryLayout<Float>.size)
            }
            return noErr
        }
    }

    private func stop() {
        engine.pause()
        isRunning = false
        stopAt = nil
    }

    // MARK: Chimes

    func playChime(_ chime: Chime = .current) {
        guard let url = Bundle.main.url(forResource: chime.fileName, withExtension: nil) else { return }
        activateSession()
        chimePlayer = try? AVAudioPlayer(contentsOf: url)
        chimePlayer?.volume = 1
        chimePlayer?.play()
    }
}

/// Synth state shared with the real-time audio thread through a raw pointer
/// (no locks or allocation are allowed there).
struct SynthState {
    var kind: Int32 = 0
    var targetGain: Float = 0
    var gain: Float = 0

    var seed: UInt32 = 0x9E37_79B9
    var brown: Float = 0
    var lowA: Float = 0
    var lowB: Float = 0
    var highIn: Float = 0
    var highOut: Float = 0
    var grain: Float = 0
    var drop: Float = 0
    var dropPhase: Float = 0
    var dropStep: Float = 0
    var crackle: Float = 0
    var wavePhase: Float = 0
    var wavePeriod: Float = 9

    private mutating func random() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max)
    }

    private mutating func white() -> Float { random() * 2 - 1 }

    private mutating func nextBrown() -> Float {
        brown = (brown + 0.02 * white()) / 1.02
        return brown * 3.5
    }

    /// High-pass a white noise sample (gives the hiss of sand and rain).
    private mutating func hiss(_ coefficient: Float) -> Float {
        let x = white()
        highOut = coefficient * (highOut + x - highIn)
        highIn = x
        return highOut
    }

    static func render(_ state: UnsafeMutablePointer<SynthState>, into out: UnsafeMutablePointer<Float>, frames: Int) {
        var s = state.pointee
        let rate: Float = 44_100
        let grainDecay = expf(-1 / (0.0016 * rate))
        let dropDecay = expf(-1 / (0.006 * rate))
        let crackleDecay = expf(-1 / (0.012 * rate))

        for i in 0..<frames {
            var sample: Float = 0
            switch s.kind {
            case 1: // Falling sand: thousands of tiny grain clicks over a soft hiss.
                if s.random() < 1100 / rate { s.grain = 0.35 + 0.65 * s.random() }
                s.grain *= grainDecay
                let h = s.hiss(0.82)
                s.lowA += 0.45 * (h * (s.grain + 0.06) - s.lowA)
                sample = s.lowA * 1.6

            case 2: // Rain: steady wash plus pattering drops.
                let wash = s.hiss(0.9)
                s.lowA += 0.25 * (wash - s.lowA)
                if s.random() < 45 / rate {
                    s.drop = 0.25 + 0.75 * s.random()
                    s.dropStep = 2 * .pi * (1800 + 4200 * s.random()) / rate
                }
                s.drop *= dropDecay
                s.dropPhase += s.dropStep
                if s.dropPhase > 2 * .pi { s.dropPhase -= 2 * .pi }
                if s.random() < 400 / rate { s.grain = 0.3 * s.random() }
                s.grain *= grainDecay
                sample = s.lowA * 0.5 + sinf(s.dropPhase) * s.drop * 0.45 + wash * s.grain * 1.3

            case 3: // Ocean: brown noise swelling and receding in slow, uneven waves.
                s.wavePhase += 1 / (s.wavePeriod * rate)
                if s.wavePhase >= 1 {
                    s.wavePhase -= 1
                    s.wavePeriod = 7 + 6 * s.random()
                }
                let swell = 0.5 - 0.5 * cosf(2 * .pi * s.wavePhase)
                let envelope = 0.12 + 0.88 * swell * swell
                let cutoff = 250 + 1600 * envelope
                let alpha = 1 - expf(-2 * .pi * cutoff / rate)
                let body = s.nextBrown() * 1.4 + s.white() * 0.25 * envelope
                s.lowA += alpha * (body - s.lowA)
                sample = s.lowA * envelope

            case 4: // Fireplace: low rumble with crackles and the odd pop.
                s.lowA += 0.06 * (s.nextBrown() - s.lowA)
                if s.random() < 14 / rate { s.crackle = 0.3 + 0.7 * s.random() }
                if s.random() < 0.8 / rate { s.crackle = 1.2 }
                s.crackle *= crackleDecay
                sample = s.lowA * 0.7 + s.hiss(0.7) * s.crackle * 0.6

            case 5: // Brown noise.
                s.lowA += 0.5 * (s.nextBrown() - s.lowA)
                sample = s.lowA * 0.8

            default:
                sample = 0
            }

            s.gain += (s.targetGain - s.gain) * 0.00008
            out[i] = max(-1, min(1, sample * s.gain))
        }
        state.pointee = s
    }
}
