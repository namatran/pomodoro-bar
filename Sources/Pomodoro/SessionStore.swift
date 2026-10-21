import Foundation

/// Every saved session, kept forever in ~/Library/Application Support/Pomodoro/sessions.json.
/// `swift run` and Pomodoro.app share the file, so don't run both at once.
@MainActor
final class SessionStore: ObservableObject {
    private static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Pomodoro", isDirectory: true)
    private static let file = folder.appendingPathComponent("sessions.json")

    @Published private(set) var sessions: [Session] = []
    /// Called after a row is deleted in Today, so the site can delete it too.
    var onDelete: @MainActor (UUID) -> Void = { _ in }
    /// Off if an unreadable file couldn't be moved aside, so saving doesn't overwrite it.
    private var canSave = true

    init() {
        // The per-day counts this replaces aren't migrated.
        UserDefaults.standard.removeObject(forKey: "completedByDay")
        load()
        // Which sessions count as today changes at midnight even though no session does.
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
    }

    /// Sessions that ended today in the local time zone, oldest first, like the site's day groups.
    var today: [Session] { sessions.filter { Calendar.current.isDateInToday($0.end) } }

    func add(_ session: Session) {
        sessions.append(session)
        save()
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
        onDelete(id)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.file.path) else { return }
        do {
            sessions = try Self.decoder.decode([Session].self, from: Data(contentsOf: Self.file))
        } catch {
            setAside(error)
        }
    }

    /// Keep an unreadable file as sessions-unreadable-<date>.json and start an empty history.
    private func setAside(_ error: Error) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let aside = Self.folder.appendingPathComponent("sessions-unreadable-\(formatter.string(from: Date())).json")
        do {
            try FileManager.default.moveItem(at: Self.file, to: aside)
            NSLog("%@", "Pomodoro: couldn't read sessions.json (\(error)); moved it to \(aside.lastPathComponent)")
        } catch {
            canSave = false
            NSLog("%@", "Pomodoro: couldn't read or move sessions.json (\(error)); not saving sessions")
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            try Self.encoder.encode(sessions).write(to: Self.file, options: .atomic)
        } catch {
            NSLog("%@", "Pomodoro: couldn't save sessions: \(error)")
        }
    }

    /// Uploads use it too, so the site gets the same JSON as the file.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
