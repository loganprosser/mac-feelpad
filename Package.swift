// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Feelpad",
    platforms: [.macOS(.v15)],
    targets: [
        // C shim over Apple's private MultitouchSupport.framework (loaded with dlopen/dlsym).
        .target(name: "MTBridge", linkerSettings: [.linkedFramework("CoreFoundation"), .linkedFramework("IOKit")]),
        // Pure Swift: settings + texture engine. No system dependencies, fully unit-testable.
        .target(name: "FeelCore"),
        .executableTarget(name: "Feelpad", dependencies: ["MTBridge", "FeelCore"]),
        .testTarget(name: "FeelCoreTests", dependencies: ["FeelCore"]),
    ]
)
