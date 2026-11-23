import SwiftUI

enum NotchAppearance: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct NotchAppearanceModifier: ViewModifier {
    @AppStorage("notchAppearance") private var appearance = NotchAppearance.dark
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, appearance == .system ? systemScheme : appearance == .dark ? .dark : .light)
    }
}

struct AppearanceSettings: View {
    @AppStorage("notchAppearance") private var appearance = NotchAppearance.dark
    @AppStorage("notchOpacity") private var opacity = 0.9
    @AppStorage("notchReduceTransparency") private var reduceTransparency = false
    @AppStorage("hoverDelay") private var hoverDelay = 0.06
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                LinearGradient(colors: [.indigo.opacity(0.5), .teal.opacity(0.4)],
                               startPoint: .leading, endPoint: .trailing)
                NotchMaterial().frame(width: 280, height: 62)
                Label("MyNotch", systemImage: "rectangle.topthird.inset.filled")
                    .font(.headline).modifier(NotchAppearanceModifier())
            }
            .frame(height: 84).clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Live appearance preview")

            GroupBox("Appearance") {
                VStack(spacing: 14) {
                    Picker("Theme", selection: $appearance) {
                        ForEach(NotchAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Panel opacity")
                        Slider(value: $opacity, in: 0.35...1, step: 0.01)
                            .accessibilityLabel("Panel opacity")
                        Text("\(Int((opacity * 100).rounded()))%").monospacedDigit().frame(width: 38)
                    }
                    .disabled(reduceTransparency || systemReduceTransparency)
                    Toggle("Reduce transparency", isOn: $reduceTransparency)
                        .toggleStyle(.switch)
                    if systemReduceTransparency {
                        Text("macOS Reduce Transparency is enabled.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(10)
            }
            GroupBox("Interaction") {
                HStack {
                    Text("Hover delay")
                    Slider(value: $hoverDelay, in: 0...0.5, step: 0.01)
                        .accessibilityLabel("Hover delay")
                    Text("\(Int((hoverDelay * 1000).rounded())) ms")
                        .monospacedDigit().frame(width: 52)
                }.padding(10)
            }
            HStack {
                Text("Changes apply immediately.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Restore defaults") {
                    appearance = .dark
                    opacity = 0.9
                    reduceTransparency = false
                    hoverDelay = 0.06
                }
            }
        }
        .padding(22)
        .frame(width: 480)
    }
}

/// Shared by the menu and the independently hosted notch view.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingView(rootView: AppearanceSettings())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 430),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "MyNotch Settings"
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
