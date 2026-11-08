/// One pulse for the trackpad actuator.
public struct Pulse: Equatable, Sendable {
    public var actuationID: Int32
    public init(actuationID: Int32) { self.actuationID = actuationID }
}

/// Turns touch frames into pulses. Pure logic: no system calls, deterministic, unit-tested.
public struct TextureEngine: Sendable {
    private var cell: SIMD2<Int>?   // cell of the last sample; nil means the next frame is a baseline
    private var gate = 0            // finger count while texture is active, else 0
    private var lastPulse = -Double.infinity

    // ponytail: fixed 12 ms floor between pulses, tune by feel if the actuator smears or drops them.
    private static let minInterval = 0.012
    // ponytail: ids 1...6 are assumed weakest to strongest but that order is unverified; tuned by feel.
    private static let ladder: [Int32] = [1, 2, 3, 4, 5, 6]

    public init() {}

    /// Feed one touch frame. `points` are the fingers touching the glass, in millimetres.
    /// Returns the pulse to fire for this frame, or nil.
    public mutating func update(points: [SIMD2<Double>], time: Double, settings: FeelSettings) -> Pulse? {
        let count = points.count
        let active = settings.enabled && ((count == 1 && settings.onMove) || (count == 2 && settings.onScroll))
        let state = active ? count : 0
        if state != gate { gate = state; cell = nil }
        guard active else { return nil }

        let p = points.reduce(SIMD2<Double>.zero, +) / Double(count)
        let s = min(max(settings.spacingMM, 1), 12)
        let (new, height) = Self.sample(p, s, settings.material)
        defer { cell = new }
        guard let old = cell, old != new, height > 0 else { return nil }
        guard time - lastPulse >= Self.minInterval else { return nil }
        lastPulse = time
        return Self.pulse(strength: settings.strength, height: height)
    }

    /// The pulse used for a strength value with no texture involved (the menu's "Test" button).
    public static func testPulse(strength: Double) -> Pulse { pulse(strength: strength, height: 1) }

    private static func pulse(strength: Double, height: Double) -> Pulse {
        let level = min(max(strength, 0), 1) * height
        let n = ladder.count
        return Pulse(actuationID: ladder[min(n - 1, Int(level * Double(n)))])
    }

    /// Cell containing `p` and the height of the feature a pulse would represent on entering it (0 = none).
    private static func sample(_ p: SIMD2<Double>, _ s: Double, _ material: Material) -> (SIMD2<Int>, Double) {
        switch material {
        case .ridges:
            return (SIMD2(Int((p.x / s).rounded(.down)), 0), 1.0)
        case .grid:
            return (SIMD2(Int((p.x / s).rounded(.down)), Int((p.y / s).rounded(.down))), 0.7)
        case .sand:
            // ponytail: only the cell the sample lands in is checked, grains skipped over in one fast frame are lost.
            let size = max(0.8, s / 3)
            let c = SIMD2(Int((p.x / size).rounded(.down)), Int((p.y / size).rounded(.down)))
            var h = UInt64(bitPattern: Int64(c.x)) &* 0x9E37_79B9_7F4A_7C15
                ^ UInt64(bitPattern: Int64(c.y)) &* 0xC2B2_AE3D_27D4_EB4F
            h ^= h >> 29
            h = h &* 0xBF58_476D_1CE4_E5B9
            h ^= h >> 32
            guard h % 100 < 35 else { return (c, 0) }
            return (c, 0.4 + 0.6 * Double((h >> 8) % 1000) / 999)
        }
    }
}
