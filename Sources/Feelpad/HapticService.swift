import AppKit
import FeelCore
import MTBridge
import Observation
import Synchronization

/// Engine and latest settings, shared between the main actor and the touch thread.
private final class TouchState: Sendable {
    private struct Inner { var engine = TextureEngine(); var settings = FeelSettings() }
    private let inner: Mutex<Inner>

    init(_ settings: FeelSettings) { inner = Mutex(Inner(settings: settings)) }

    func set(_ settings: FeelSettings) { inner.withLock { $0.settings = settings } }

    func update(points: [SIMD2<Double>], time: Double) -> Pulse? {
        inner.withLock { $0.engine.update(points: points, time: time, settings: $0.settings) }
    }
}

/// Runs on the framework's touch thread.
private func onFrame(_ touching: UnsafePointer<mt_point>?, _ count: Int32, _ time: Double, _ ctx: UnsafeMutableRawPointer?) {
    guard let ctx else { return }
    let state = Unmanaged<TouchState>.fromOpaque(ctx).takeUnretainedValue()
    var points: [SIMD2<Double>] = []
    if let touching, count > 0 {
        points.reserveCapacity(Int(count))
        for i in 0..<Int(count) { points.append(SIMD2(Double(touching[i].x), Double(touching[i].y))) }
    }
    if let pulse = state.update(points: points, time: time) { _ = mt_actuate(pulse.actuationID) }
}

/// Owns the trackpad: reads touches, runs the texture engine, fires the actuator.
@MainActor @Observable
final class HapticService {
    enum Status: Equatable {
        case running
        case off
        case unavailable(String)  // human-readable reason, shown in the menu
    }

    /// Persisted to UserDefaults; changes apply immediately.
    var settings: FeelSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "settings") }
            touchState.set(settings)
            apply()
        }
    }

    private(set) var status: Status = .off

    @ObservationIgnored private let touchState: TouchState
    @ObservationIgnored private let ctx: UnsafeMutableRawPointer  // retained for the app's lifetime
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    init() {
        let saved = UserDefaults.standard.data(forKey: "settings").flatMap { try? JSONDecoder().decode(FeelSettings.self, from: $0) }
        let initial = saved ?? FeelSettings()
        settings = initial
        touchState = TouchState(initial)
        ctx = Unmanaged.passRetained(touchState).toOpaque()
        // The stream stops after system sleep, so restart it (and reopen the actuator) on wake.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.enabled else { return }
                mt_touch_stop()
                mt_haptics_close()
                self.apply()
            }
        }
        apply()
    }

    /// Fire one pulse at the current strength, for the menu's "Test" button.
    func testPulse() {
        guard mt_haptics_open() == 0 else { return }
        _ = mt_actuate(TextureEngine.testPulse(strength: settings.strength).actuationID)
    }

    private func apply() {
        guard settings.enabled else {
            mt_touch_stop()
            status = .off
            return
        }
        let openErr = mt_haptics_open()
        if openErr != 0 {
            status = .unavailable("No haptic trackpad found (error \(openErr))")
            return
        }
        let startErr = mt_touch_start(onFrame, ctx)
        status = startErr == 0 ? .running : .unavailable("Could not read the trackpad (error \(startErr))")
    }
}
