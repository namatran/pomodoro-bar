import AppKit

/// Which sprite the pet shows. The raw value is the PNG's file name.
enum PetState: String, CaseIterable {
    case idle, focus, onBreak = "break", celebrate

    @MainActor
    init(timer: PomodoroTimer) {
        if timer.isAlarming {
            // The timer has already moved on, so a break phase means focus just finished.
            self = timer.phase == .work ? .onBreak : .celebrate
        } else if timer.isRunning {
            self = timer.phase == .work ? .focus : .onBreak
        } else {
            self = .idle
        }
    }
}

/// The owner's doodles from ~/Library/Application Support/Pomodoro/sprites/.
/// Each state looks for `<state>.png`, then `pet.png`; with neither, the drawn tomato shows.
@MainActor
final class Sprites: ObservableObject {
    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Pomodoro/sprites", isDirectory: true)

    @Published private(set) var images: [String: NSImage] = [:]

    init() { reload() }

    func reload() {
        // Create the folder so there's somewhere obvious to drop files.
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        var loaded: [String: NSImage] = [:]
        for name in PetState.allCases.map(\.rawValue) + ["pet"] {
            loaded[name] = NSImage(contentsOf: Self.folder.appendingPathComponent("\(name).png"))
        }
        images = loaded
    }

    func image(for state: PetState) -> NSImage? {
        images[state.rawValue] ?? images["pet"]
    }
}
