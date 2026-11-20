import Foundation

/// Every saved session, kept forever in ~/Library/Application Support/Pomodoro/sessions.json.
/// `swift run` and Pomodoro.app share the file, so don't run both at once.
@MainActor
final class SessionStore: ObservableObject {
    private static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Pomodoro", isDirectory: true)
    private static let file = folder.appendingPathComponent("sessions.json")

    @Published private(set) var sessions: [Session] = []
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

    /// Sessions that ended today in the local time zone, oldest first.
    var today: [Session] { sessions.filter { Calendar.current.isDateInToday($0.end) } }

    /// Every session grouped by the local day it ended, newest day first, each day oldest first.
    var byDay: [(day: Date, sessions: [Session])] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.end) }
            .map { (day: $0.key, sessions: $0.value.sorted { $0.end < $1.end }) }
            .sorted { $0.day > $1.day }
    }

    func add(_ session: Session) {
        sessions.append(session)
        save()
    }

    /// Replace the stored session that has this one's id.
    func update(_ session: Session) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        save()
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
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

    private static let encoder: JSONEncoder = {
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
