import Testing
import Foundation
@testable import LuxiconKit

@Suite struct VocabularyJSONTests {
    private let entries = [
        VocabularyEntry(term: "Choreo", soundsLike: ["corio", "correo"],
                        category: "project", notes: "Platform framework"),
        VocabularyEntry(term: "Oracle HCM", category: "acronym"),
    ]

    @Test func exportParseRoundTrip() throws {
        let parsed = try VocabularyJSON.parse(VocabularyJSON.export(entries))
        #expect(parsed == entries)
    }

    @Test func templateRoundTripsAndInstructionsAreIgnored() throws {
        let parsed = try VocabularyJSON.parse(VocabularyJSON.template(existing: entries))
        #expect(parsed == entries)
    }

    @Test func acceptsSnakeCaseAndBareArrayAndStrings() throws {
        let json = """
        [
          {"term": "Lake Norman", "sounds_like": ["lake normin"], "category": "place"},
          "Chambers",
          {"term": "  ", "soundsLike": ["ignored"]}
        ]
        """
        let parsed = try VocabularyJSON.parse(Data(json.utf8))
        #expect(parsed == [
            VocabularyEntry(term: "Lake Norman", soundsLike: ["lake normin"], category: "place"),
            VocabularyEntry(term: "Chambers"),
        ])
    }

    @Test func envelopeWithoutTermsThrows() {
        #expect(throws: VocabularyJSON.ParseError.self) {
            try VocabularyJSON.parse(Data(#"{"kind": "luxicon-vocabulary"}"#.utf8))
        }
    }

    @Test func emptyTermsThrows() {
        #expect(throws: VocabularyJSON.ParseError.self) {
            try VocabularyJSON.parse(Data(#"{"terms": []}"#.utf8))
        }
    }
}

@Suite struct AgentPromptTests {
    @Test func promptEmbedsCurrentTermsAndSchema() {
        let prompt = VocabularyJSON.agentPrompt(existing: [
            VocabularyEntry(term: "Choreo", soundsLike: ["corio"]),
        ])
        #expect(prompt.contains("\"kind\": \"luxicon-vocabulary\""))
        #expect(prompt.contains("Choreo"))
        #expect(prompt.contains("Return only the finished JSON"))
    }

    @Test func promptHandlesEmptyVocabulary() {
        let prompt = VocabularyJSON.agentPrompt(existing: [])
        #expect(prompt.contains("(none yet)"))
    }
}
