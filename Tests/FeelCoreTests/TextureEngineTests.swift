import Testing
@testable import FeelCore

private func settings(_ material: Material = .ridges) -> FeelSettings {
    var s = FeelSettings()
    s.material = material
    s.spacingMM = 4
    return s
}

/// Runs one-finger frames along `xs` at y = 5, 20 ms apart, returning each frame's pulse.
private func run(_ xs: [Double], _ s: FeelSettings) -> [Pulse?] {
    var e = TextureEngine()
    return xs.enumerated().map { i, x in
        e.update(points: [SIMD2(x, 5)], time: Double(i) * 0.02, settings: s)
    }
}

@Test func ridgesFireOncePerBoundaryAndNeverWithinACell() {
    let out = run([0.5, 1, 3.9, 4.1, 5, 7.9, 8.1], settings())
    #expect(out.map { $0 != nil } == [false, false, false, true, false, false, true])
}

@Test func fingerCountChangeDoesNotPulseOnTheJump() {
    var e = TextureEngine()
    let s = settings()
    #expect(e.update(points: [SIMD2(1, 5)], time: 0, settings: s) == nil)
    // second finger lands far away, centroid jumps several cells
    #expect(e.update(points: [SIMD2(1, 5), SIMD2(30, 5)], time: 0.02, settings: s) == nil)
    #expect(e.update(points: [SIMD2(1, 5), SIMD2(34, 5)], time: 0.04, settings: s) != nil)
}

@Test func gatingHonoursEnabledOnMoveAndOnScroll() {
    let one = [SIMD2(0.5, 5)], one2 = [SIMD2(9.0, 5)]
    let two = [SIMD2(0.5, 5), SIMD2(0.5, 6)], two2 = [SIMD2(9.0, 5), SIMD2(9.0, 6)]
    func pulses(_ a: [SIMD2<Double>], _ b: [SIMD2<Double>], _ s: FeelSettings) -> Bool {
        var e = TextureEngine()
        _ = e.update(points: a, time: 0, settings: s)
        return e.update(points: b, time: 0.1, settings: s) != nil
    }
    var s = settings()
    #expect(pulses(one, one2, s))
    #expect(pulses(two, two2, s))
    #expect(!pulses(one, [one[0], one[0], one[0]], s))
    s.onMove = false
    #expect(!pulses(one, one2, s))
    #expect(pulses(two, two2, s))
    s.onMove = true; s.onScroll = false
    #expect(pulses(one, one2, s))
    #expect(!pulses(two, two2, s))
    s.enabled = false
    #expect(!pulses(one, one2, s))
}

@Test func rateLimiterDropsCloseCrossingWithoutFiringLate() {
    var e = TextureEngine()
    let s = settings()
    #expect(e.update(points: [SIMD2(3.9, 5)], time: 1.0, settings: s) == nil)
    #expect(e.update(points: [SIMD2(4.1, 5)], time: 1.1, settings: s) != nil)
    #expect(e.update(points: [SIMD2(8.1, 5)], time: 1.105, settings: s) == nil)  // dropped
    #expect(e.update(points: [SIMD2(8.2, 5)], time: 1.2, settings: s) == nil)    // same cell, no late fire
}

@Test func sandIsDeterministicWithRoughlyAThirdOfCellsGrained() {
    let xs = (0..<400).map { Double($0) * 0.25 }  // 100 mm sweep over 4/3 mm cells: 75 cells entered
    let a = run(xs, settings(.sand)), b = run(xs, settings(.sand))
    #expect(a == b)
    let n = a.compactMap { $0 }.count
    #expect((15...38).contains(n))  // 20...50% of 75 cells
}

@Test func ridgesUseFloorSoNegativeCoordinatesCrossAtZero() {
    #expect(run([-0.5, 0.5], settings()).map { $0 != nil } == [false, true])
}

@Test func gridFiresOnVerticalMotionButRidgesDoNot() {
    func vertical(_ m: Material) -> Bool {
        var e = TextureEngine()
        _ = e.update(points: [SIMD2(1, 3.9)], time: 0, settings: settings(m))
        return e.update(points: [SIMD2(1, 4.1)], time: 0.02, settings: settings(m)) != nil
    }
    #expect(vertical(.grid))
    #expect(!vertical(.ridges))
}

@Test func strengthMappingIsMonotonicAndInLadder() {
    let ids = stride(from: -0.5, through: 1.5, by: 0.05).map { TextureEngine.testPulse(strength: $0).actuationID }
    #expect(ids == ids.sorted())
    #expect(ids.allSatisfy { (1...6).contains($0) })
    #expect(ids.first == 1 && ids.last == 6)
}

@Test func manyCrossingsInOneFrameGiveOnePulse() {
    var e = TextureEngine()
    let s = settings()
    _ = e.update(points: [SIMD2(0.5, 5)], time: 0, settings: s)
    #expect(e.update(points: [SIMD2(40, 5)], time: 0.02, settings: s) != nil)
    #expect(e.update(points: [SIMD2(40.5, 5)], time: 0.04, settings: s) == nil)
}
