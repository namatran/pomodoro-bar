import ServiceManagement
import SwiftUI

/// The slimmed menu bar menu: the timer's controls live in the pet's popout.
struct ContentView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @EnvironmentObject var app: AppDelegate
    @EnvironmentObject var uploader: Uploader
    @AppStorage(Settings.workKey) private var workMinutes = 25
    @AppStorage(Settings.breakKey) private var breakMinutes = 5
    @AppStorage(Uploader.siteURLKey) private var siteURL = ""
    @AppStorage(Uploader.tokenKey) private var uploadToken = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(app.isPetVisible ? "Hide pet" : "Show pet") { app.togglePet() }
                Text("⌃⌥⌘T")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Stepper("Focus: \(workMinutes) min", value: $workMinutes, in: 1...90)
                Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...60)
            }
            .onChange(of: workMinutes) { timer.applySettings() }
            .onChange(of: breakMinutes) { timer.applySettings() }
            Divider()
            OpenAtLoginToggle()
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                TextField("Site URL", text: $siteURL)
                    .autocorrectionDisabled()
                SecureField("Upload token", text: $uploadToken)
                Text(uploader.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textFieldStyle(.roundedBorder)
            .onChange(of: siteURL) { uploader.settingsChanged() }
            .onChange(of: uploadToken) { uploader.settingsChanged() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 240)
        // In case the pause after typing didn't send.
        .onDisappear { uploader.send() }
    }
}

/// Registers the app as a login item. Only Pomodoro.app can be one, not `swift run`'s bare binary.
struct OpenAtLoginToggle: View {
    private static let isBundled = Bundle.main.bundleIdentifier != nil
    @State private var isOn = SMAppService.mainApp.status == .enabled
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Open at login", isOn: Binding(get: { isOn }, set: set))
                .disabled(!Self.isBundled)
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Also catches a change made in System Settings while the menu was closed.
        .onAppear(perform: refresh)
    }

    private func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            note = "Couldn't change it: \(error.localizedDescription)"
        }
    }

    private func refresh() {
        let status = SMAppService.mainApp.status
        isOn = status == .enabled
        if !Self.isBundled {
            note = "Only in Pomodoro.app"
        } else if status == .requiresApproval {
            note = "Allow it in System Settings → Login Items"
        } else {
            note = nil
        }
    }
}
