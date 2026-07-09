import Foundation
import LuxiconKit

/// Keeps the vocabulary synchronized with a user-provided URL. The remote
/// file is the source of truth: a successful sync replaces the glossary.
/// Runs on foreground activation (rate-limited) and on demand via Sync Now.
extension Store {
    private static let syncCooldown: TimeInterval = 60

    /// Foreground/auto trigger; skips if unconfigured or synced recently.
    func syncVocabularyIfConfigured() {
        guard !vocabularySourceURL.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let last = vocabularyLastSyncAttempt,
           Date().timeIntervalSince(last) < Self.syncCooldown { return }
        Task { await syncVocabulary() }
    }

    /// One sync pass. Errors land in `vocabularySyncError` for the UI.
    func syncVocabulary() async {
        let urlString = vocabularySourceURL.trimmingCharacters(in: .whitespaces)
        guard !urlString.isEmpty else { return }
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https" else {
            vocabularySyncError = "Not a valid https URL. (Plain http would expose your auth headers.)"
            return
        }
        vocabularyLastSyncAttempt = Date()

        var request = URLRequest(url: url, timeoutInterval: 15)
        // Trim newlines too: a pasted token with a trailing newline makes
        // CFNetwork silently drop the header. Skip blank rows entirely so an
        // accidentally-added duplicate can't overwrite a real one (setValue
        // replaces any earlier value for the same name).
        for header in vocabularyHeaders {
            let name = header.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = header.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !value.isEmpty else { continue }
            request.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw SyncError.badStatus(http.statusCode, hint: Self.gitHubHint(for: http))
            }
            let entries = try VocabularyJSON.parse(data)
            vocabularyEntries = entries
            vocabularyLastSync = Date()
            vocabularySyncError = nil
            save()
        } catch {
            vocabularySyncError = error.localizedDescription
        }
    }

    /// GitHub answers 404, not 401, for private files, which hides whether
    /// the problem is the URL, the credentials, or the token's access. Its
    /// rate-limit ceiling tells them apart: 60/hour means the request was
    /// treated as anonymous; authenticated requests get 5000+.
    private static func gitHubHint(for response: HTTPURLResponse) -> String? {
        guard response.statusCode == 404,
              response.url?.host == "api.github.com" else { return nil }
        let limit = response.value(forHTTPHeaderField: "x-ratelimit-limit")
            .flatMap(Int.init) ?? 0
        return limit <= 60
            ? "GitHub did not receive valid credentials — check the Authorization header row (value: “Bearer <token>”)."
            : "GitHub recognized your token, but it does not grant access to this file — check the token's Repository access and Contents permission, and the file path."
    }

    enum SyncError: Error, LocalizedError {
        case badStatus(Int, hint: String?)
        var errorDescription: String? {
            switch self {
            case .badStatus(let code, let hint):
                let message = "Server returned HTTP \(code)."
                if let hint { return message + " " + hint }
                if code == 404 {
                    // Same ambiguity on non-GitHub hosts; say so generically.
                    return message + " Check the URL — private files can also return 404 when the Authorization header is missing or invalid."
                }
                return message
            }
        }
    }
}
