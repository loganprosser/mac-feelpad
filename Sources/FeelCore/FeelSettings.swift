/// A texture the trackpad can feel like.
public enum Material: String, CaseIterable, Codable, Sendable, Identifiable {
    case ridges  // parallel ridges across the pad
    case grid    // ridges in both directions
    case sand    // fine, random grains fixed to the glass

    public var id: Self { self }
    public var title: String {
        switch self {
        case .ridges: "Ridges"
        case .grid: "Grid"
        case .sand: "Sand"
        }
    }
}

/// User settings, persisted as JSON in UserDefaults.
public struct FeelSettings: Codable, Equatable, Sendable {
    public var enabled = true
    public var material = Material.ridges
    public var strength = 0.5   // 0...1, picks how hard each pulse is
    public var spacingMM = 4.0  // 1...12, distance between texture features in millimetres
    public var onMove = true    // texture under one finger
    public var onScroll = true  // texture under two fingers

    public init() {}
}
