import Testing
import Foundation
@testable import LuxiconKit

@Suite struct SummarizerParsingTests {
    @Test func parsesHeadlineAndSummaryMarkers() {
        let raw = """
        HEADLINE: Launch retro and growth plan
        SUMMARY:
        **Overview** — Shipped the registration flow.
        """
        let result = MeetingSummarizer.parse(raw, fallbackTitle: "1-on-1")
        #expect(result.headline == "Launch retro and growth plan")
        #expect(result.overview.hasPrefix("**Overview**"))
    }

    @Test func fallsBackWhenMarkersMissing() {
        let result = MeetingSummarizer.parse("Just some prose.", fallbackTitle: "1-on-1 with Josh")
        #expect(result.headline == "1-on-1 with Josh")
        #expect(result.overview == "Just some prose.")
    }

    @Test func truncatesRunawayHeadline() {
        let long = "HEADLINE: " + String(repeating: "word ", count: 40) + "\nSUMMARY:\nBody."
        let result = MeetingSummarizer.parse(long, fallbackTitle: "t")
        #expect(result.headline.count <= 120)
        #expect(result.overview == "Body.")
    }

    @Test func headlineInstructionAsksForTopicsWithoutNames() {
        #expect(MeetingSummarizer.systemPrompt.contains("topics"))
        #expect(MeetingSummarizer.systemPrompt.contains("120"))
        #expect(MeetingSummarizer.systemPrompt.contains("no people's names"))
    }

    @Test func clipKeepsHeadAndTail() {
        let text = String(repeating: "a", count: 15_000) + "MIDDLE" + String(repeating: "z", count: 15_000)
        let clipped = MeetingSummarizer.clip(text, limit: 10_000)
        #expect(clipped.count < text.count)
        #expect(clipped.hasPrefix("aaa"))
        #expect(clipped.hasSuffix("zzz"))
        #expect(clipped.contains("trimmed"))
        #expect(!clipped.contains("MIDDLE"))
    }

    @Test func clipLeavesShortTextAlone() {
        #expect(MeetingSummarizer.clip("short") == "short")
    }

    @Test func promptContainsTurnsAndParticipants() {
        let transcript = MeetingTranscript(
            title: "Weekly 1:1",
            date: Date(timeIntervalSince1970: 1_780_000_000),
            duration: 60,
            turns: [
                TranscriptTurn(id: 0, speakerId: 0, speakerName: "JD", start: 0, end: 30, text: "How was the week?"),
                TranscriptTurn(id: 1, speakerId: 1, speakerName: "Josh", start: 31, end: 60, text: "Great."),
            ]
        )
        let prompt = MeetingSummarizer.userPrompt(for: transcript)
        #expect(prompt.contains("JD: How was the week?"))
        #expect(prompt.contains("Josh (49% talk time)"))
    }
}

@Suite struct SummaryExportTests {
    @Test func summaryMarkdownIsStandalone() {
        let transcript = MeetingTranscript(
            title: "Weekly 1:1", date: Date(timeIntervalSince1970: 1_780_000_000),
            duration: 125,
            turns: [TranscriptTurn(id: 0, speakerId: 0, speakerName: "JD", start: 0, end: 60, text: "Hi.")]
        )
        let summary = SessionSummary(
            headline: "Quick check-in",
            overview: "**Overview** — brief.",
            generatedAt: Date(timeIntervalSince1970: 1_780_100_000)
        )
        let md = TranscriptExport.summaryMarkdown(summary, transcript: transcript)
        #expect(md.contains("# Summary: Weekly 1:1"))
        #expect(md.contains("Quick check-in"))
        #expect(md.contains("(on-device)"))
        // The transcript export must remain untouched by summaries.
        #expect(!TranscriptExport.markdown(transcript).contains("Quick check-in"))
    }
}
