import Foundation

/// Sends saved sessions to the website, and deletes the ones removed in Today (see docs/pet-design.md, Upload).
/// The ids already sent and the deletes still owed are kept in UserDefaults, so they survive relaunches.
@MainActor
final class Uploader: ObservableObject {
    static let siteURLKey = "siteURL"
    static let tokenKey = "uploadToken"
    private static let sentKey = "sentSessionIDs"
    private static let deletesKey = "pendingDeleteIDs"

    /// The caption under the dropdown's fields, such as "All sent" or "3 waiting · wrong token".
    @Published private(set) var status = ""

    private let sessions: SessionStore
    private var sent: Set<UUID>
    private var deletes: Set<UUID>
    /// Why the last round stopped, if it did.
    private var problem: String?
    private var isSending = false
    /// Set when `send()` is called mid-round, so another round follows.
    private var sendAgain = false
    private var typingPause: Task<Void, Never>?

    init(sessions: SessionStore) {
        self.sessions = sessions
        sent = Self.ids(forKey: Self.sentKey)
        deletes = Self.ids(forKey: Self.deletesKey)
        updateStatus()
    }

    /// Saved sessions the site doesn't have yet, leaving out any about to be deleted.
    private var unsent: [Session] {
        sessions.sessions.filter { !sent.contains($0.id) && !deletes.contains($0.id) }
    }

    /// Owes the site a delete for a row removed in Today, then sends.
    func delete(_ id: UUID) {
        deletes.insert(id)
        Self.store(deletes, forKey: Self.deletesKey)
        send()
    }

    /// The fields change on every keystroke, so this waits for a pause in typing before sending.
    func settingsChanged() {
        problem = nil
        updateStatus()
        typingPause?.cancel()
        typingPause = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            send()
        }
    }

    /// Sends the deletes, then the unsent sessions, one request each. Stops at the first problem.
    func send() {
        guard !isSending else {
            sendAgain = true
            return
        }
        guard let endpoint = Self.endpoint, let token = Self.setting(Self.tokenKey) else {
            updateStatus()
            return
        }
        isSending = true
        Task {
            await sendAll(to: endpoint, token: token)
            isSending = false
            if sendAgain {
                sendAgain = false
                send()
            }
        }
    }

    private func sendAll(to endpoint: URL, token: String) async {
        problem = nil
        for id in deletes {
            var request = URLRequest(url: endpoint.appendingPathComponent(id.uuidString))
            request.httpMethod = "DELETE"
            guard await perform(request, token: token, what: "the delete of \(id)") else {
                updateStatus()
                return
            }
            deletes.remove(id)
            sent.remove(id)
            Self.store(deletes, forKey: Self.deletesKey)
            Self.store(sent, forKey: Self.sentKey)
            updateStatus()
        }
        for session in unsent {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? SessionStore.encoder.encode(session)
            guard await perform(request, token: token, what: "session \(session.id)") else {
                updateStatus()
                return
            }
            sent.insert(session.id)
            Self.store(sent, forKey: Self.sentKey)
            updateStatus()
        }
        updateStatus()
    }

    /// Sends one request. True if the site took it, or turned it down for good with a 400 (logged, never retried).
    private func perform(_ request: URLRequest, token: String, what: String) async -> Bool {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch code {
            case 200..<300:
                return true
            case 400:
                NSLog("%@", "Pomodoro: the site turned down \(what): \(String(decoding: data, as: UTF8.self))")
                return true
            case 401:
                problem = "wrong token"
            default:
                problem = "site answered \(code)"
            }
        } catch {
            NSLog("%@", "Pomodoro: couldn't reach the site: \(error.localizedDescription)")
            problem = "can't reach site"
        }
        return false
    }

    private func updateStatus() {
        let waiting = unsent.count + deletes.count
        if Self.setting(Self.siteURLKey) == nil || Self.setting(Self.tokenKey) == nil {
            status = waiting == 0 ? "Not set up" : "Not set up · \(waiting) waiting"
        } else if Self.endpoint == nil {
            status = "Check the site URL"
        } else {
            status = [waiting == 0 ? "All sent" : "\(waiting) waiting", problem].compactMap { $0 }.joined(separator: " · ")
        }
    }

    /// The site's /api/sessions, or nil until the URL is filled in with an http(s) address.
    private static var endpoint: URL? {
        guard var site = setting(siteURLKey) else { return nil }
        while site.hasSuffix("/") { site.removeLast() }
        guard let url = URL(string: site + "/api/sessions"),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }

    /// A field's value without surrounding spaces or newlines, or nil if it's empty.
    private static func setting(_ key: String) -> String? {
        let value = (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func ids(forKey key: String) -> Set<UUID> {
        Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
    }

    private static func store(_ ids: Set<UUID>, forKey key: String) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
    }
}
