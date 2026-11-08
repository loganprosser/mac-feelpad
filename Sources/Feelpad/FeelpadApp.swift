import AppKit
import FeelCore
import SwiftUI

// No @State / #Preview: SwiftUI's macros need full Xcode; this builds with Command Line Tools only.
@main
struct FeelpadApp: App {
    let service = HapticService()

    var body: some Scene {
        MenuBarExtra("Feelpad", systemImage: "hand.point.up.left") {
            MenuView(service: service)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuView: View {
    @Bindable var service: HapticService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Feelpad").font(.headline)
                Spacer()
                Toggle("Enabled", isOn: $service.settings.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if case .unavailable(let reason) = service.status {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }

            Group {
                Picker("Material", selection: $service.settings.material) {
                    ForEach(Material.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength")
                    Slider(value: $service.settings.strength, in: 0.05...1) { Text("Strength") }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Spacing")
                        Spacer()
                        Text("\(Int(service.settings.spacingMM.rounded())) mm").foregroundStyle(.secondary)
                    }
                    Slider(value: $service.settings.spacingMM, in: 1...12, step: 1) { Text("Spacing") }
                }

                Toggle("One-finger movement", isOn: $service.settings.onMove)
                Toggle("Two-finger scrolling", isOn: $service.settings.onScroll)
                Button("Test pulse") { service.testPulse() }
            }
            .disabled(!service.settings.enabled)

            Divider()
            Button("Quit Feelpad") { NSApplication.shared.terminate(nil) }
        }
        .padding(14)
        .frame(width: 260)
    }
}
