import Testing
import Foundation
@testable import LuxiconKit

@Suite struct LongitudinalExportTests {
    // Two sessions with Sam, oldest → newest, whole-second dates (iso8601-safe).
    private var sessions: [MeetingTranscript] {
        [
            MeetingTranscript(
                title: "Weekly 1:1",
                date: Date(timeIntervalSince1970: 1_780_000_000),
                duration: 120,
                turns: [
                    TranscriptTurn(id: 0, speakerId: 0, speakerName: "Sam", start: 0, end: 30, text: "I'm blocked on the review."),
                    TranscriptTurn(id: 1, speakerId: 1, speakerName: "Jordan", start: 31, end: 120, text: "Let's walk through it."),
                ]
            ),
            MeetingTranscript(
                title: "Weekly 1:1",
                date: Date(timeIntervalSince1970: 1_780_604_800),
                duration: 100,
                turns: [
                    TranscriptTurn(id: 0, speakerId: 0, speakerName: "Sam", start: 0, end: 75, text: "Review landed, moving on."),
                    TranscriptTurn(id: 1, speakerId: 1, speakerName: "Jordan", start: 76, end: 100, text: "Great."),
                ]
            ),
        ]
    }

    @Test func markdownContainsHeaderDateRangeAndEverySession() {
        let md = LongitudinalExport.markdown(personName: "Sam", transcripts: sessions)
        #expect(md.contains("# 1-on-1 History: Sam"))
        #expect(md.contains("- **Sessions:** 2"))
        let from = sessions[0].date.formatted(date: .abbreviated, time: .omitted)
        let to = sessions[1].date.formatted(date: .abbreviated, time: .omitted)
        #expect(md.contains("- **Date range:** \(from) \u{2013} \(to)"))
        #expect(md.contains("- **Total duration:** 03:40"))
        // 30s + 75s of Sam across the bundle.
        #expect(md.contains("- **Sam speaking time:** 01:45"))
        #expect(md.contains("## Session 1: Weekly 1:1"))
        #expect(md.contains("## Session 2: Weekly 1:1"))
        #expect(md.contains("**[00:00] Sam:** I'm blocked on the review."))
        #expect(md.contains("**[01:16] Jordan:** Great."))
    }

    @Test func markdownOverviewTableShowsPerSessionShare() {
        let md = LongitudinalExport.markdown(personName: "Sam", transcripts: sessions)
        #expect(md.contains("| # | Date | Duration | Sam talk share |"))
        // Session 1: 30 / 119 ≈ 25%; session 2: 75 / 99 ≈ 76%.
        #expect(md.contains("| 02:00 | 25% |"))
        #expect(md.contains("| 01:40 | 76% |"))
    }

    @Test func jsonEnvelopeRoundTrips() throws {
        let generatedAt = Date(timeIntervalSince1970: 1_781_000_000)
        let data = try LongitudinalExport.json(
            personName: "Sam", transcripts: sessions, generatedAt: generatedAt)

        struct Envelope: Decodable {
            let schemaVersion: Int
            let kind: String
            let personName: String
            let generatedAt: Date
            let transcripts: [MeetingTranscript]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(Envelope.self, from: data)
        #expect(envelope.schemaVersion == 1)
        #expect(envelope.kind == "one-on-one-bundle")
        #expect(envelope.personName == "Sam")
        #expect(envelope.generatedAt == generatedAt)
        #expect(envelope.transcripts == sessions)
    }

    @Test func emptyBundleIsValidAndDoesNotCrash() throws {
        let md = LongitudinalExport.markdown(personName: "Sam", transcripts: [])
        #expect(md.contains("# 1-on-1 History: Sam"))
        #expect(md.contains("- **Sessions:** 0"))
        #expect(md.contains("- **Date range:** \u{2014}"))

        let data = try LongitudinalExport.json(
            personName: "Sam", transcripts: [],
            generatedAt: Date(timeIntervalSince1970: 1_781_000_000))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["kind"] as? String == "one-on-one-bundle")
        #expect((obj?["transcripts"] as? [Any])?.isEmpty == true)
    }

    @Test func talkShareTrendMath() {
        let trend = LongitudinalExport.talkShareTrend(of: "Sam", transcripts: sessions)
        #expect(trend.count == 2)
        #expect(abs(trend[0] - 30.0 / 119.0) < 0.001)
        #expect(abs(trend[1] - 75.0 / 99.0) < 0.001)
    }

    @Test func talkShareTrendIsZeroForUnknownSpeaker() {
        let trend = LongitudinalExport.talkShareTrend(of: "Nobody", transcripts: sessions)
        #expect(trend == [0, 0])
        #expect(LongitudinalExport.speakingTime(of: "Nobody", in: sessions[0]) == 0)
    }
}
