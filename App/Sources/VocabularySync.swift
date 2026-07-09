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
        guard let url = URL(string: urlString), let scheme = url.scheme,
              ["https", "http"].contains(scheme.lowercased()) else {
            vocabularySyncError = "Not a valid http(s) URL."
            return
        }
        vocabularyLastSyncAttempt = Date()

        var request = URLRequest(url: url, timeoutInterval: 15)
        for header in vocabularyHeaders {
            let name = header.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            request.setValue(header.value, forHTTPHeaderField: name)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw SyncError.badStatus(http.statusCode)
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

    enum SyncError: Error, LocalizedError {
        case badStatus(Int)
        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "Server returned HTTP \(code)."
            }
        }
    }
}
