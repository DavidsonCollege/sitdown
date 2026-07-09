import Foundation

/// Longitudinal (per-person) export: bundles every 1-on-1 with one person into
/// a single AI-ready document ("everything with Sam this quarter").
///
/// The caller is responsible for filtering to the person's sessions and
/// sorting oldest → newest before passing `transcripts`.
public enum LongitudinalExport {
    /// One markdown document: header (person, date range, session count,
    /// total time), a per-session overview table, then each session's full
    /// timestamped transcript in `TranscriptExport.markdown` turn format.
    /// Raw record only — no AI commentary.
    public static func markdown(personName: String, transcripts: [MeetingTranscript]) -> String {
        var out = "# 1-on-1 History: \(personName)\n\n"
        out += "- **Sessions:** \(transcripts.count)\n"
        out += "- **Date range:** \(dateRange(transcripts))\n"
        let totalDuration = transcripts.reduce(0) { $0 + $1.duration }
        out += "- **Total duration:** \(TranscriptExport.timestamp(totalDuration))\n"
        let personTime = transcripts.reduce(0) { $0 + speakingTime(of: personName, in: $1) }
        out += "- **\(personName) speaking time:** \(TranscriptExport.timestamp(personTime))\n"
        out += "\n## Overview\n\n"
        out += "| # | Date | Duration | \(personName) talk share |\n"
        out += "|---|------|----------|-----------|\n"
        let shares = talkShareTrend(of: personName, transcripts: transcripts)
        for (i, t) in transcripts.enumerated() {
            let pct = Int((shares[i] * 100).rounded())
            out += "| \(i + 1) "
            out += "| \(t.date.formatted(date: .abbreviated, time: .omitted)) "
            out += "| \(TranscriptExport.timestamp(t.duration)) "
            out += "| \(pct)% |\n"
        }
        for (i, t) in transcripts.enumerated() {
            out += "\n## Session \(i + 1): \(t.title)\n\n"
            out += "- **Date:** \(t.date.formatted(date: .long, time: .shortened))\n"
            out += "- **Duration:** \(TranscriptExport.timestamp(t.duration))\n\n"
            for turn in t.turns {
                out += "**[\(TranscriptExport.timestamp(turn.start))] \(turn.displayName):** \(turn.text)\n\n"
            }
        }
        return out
    }

    /// Structured JSON bundle (stable schema, `schemaVersion` field) for
    /// programmatic AI consumption. `generatedAt` is supplied by the caller.
    public static func json(
        personName: String, transcripts: [MeetingTranscript], generatedAt: Date
    ) throws -> Data {
        struct Envelope: Encodable {
            let schemaVersion = 1
            let kind = "one-on-one-bundle"
            let personName: String
            let generatedAt: Date
            let transcripts: [MeetingTranscript]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Envelope(
            personName: personName, generatedAt: generatedAt, transcripts: transcripts))
    }

    /// Per-session share-of-talk (0–1) for the named speaker, one entry per
    /// transcript in order. 0 for sessions where the name doesn't appear.
    public static func talkShareTrend(of name: String, transcripts: [MeetingTranscript]) -> [Double] {
        transcripts.map { t in
            t.speakers.first { $0.speakerName == name }?.talkShare ?? 0
        }
    }

    /// Seconds of speech attributed to the named speaker in one session.
    public static func speakingTime(of name: String, in transcript: MeetingTranscript) -> Double {
        transcript.speakers.first { $0.speakerName == name }?.speakingTime ?? 0
    }

    /// "May 12, 2026 – Jun 30, 2026"-style range, or "—" for an empty bundle.
    static func dateRange(_ transcripts: [MeetingTranscript]) -> String {
        guard let first = transcripts.first?.date, let last = transcripts.last?.date else {
            return "\u{2014}"
        }
        let from = first.formatted(date: .abbreviated, time: .omitted)
        let to = last.formatted(date: .abbreviated, time: .omitted)
        return from == to ? from : "\(from) \u{2013} \(to)"
    }
}
