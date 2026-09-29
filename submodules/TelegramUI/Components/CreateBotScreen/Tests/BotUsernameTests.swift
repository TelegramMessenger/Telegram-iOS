import XCTest

final class BotUsernameTests: XCTestCase {
    private let configuration = BotUsernameConfiguration(allowedSuffixes: ["agent", "ai", "app", "game"])

    func testConfiguredSuffixesAreAcceptedWithoutChangingUsername() throws {
        for username in ["sampleagent", "abcai", "sampleapp", "samplegame", "SampleAI"] {
            XCTAssertEqual(try self.configuration.validate(username).get(), username)
        }
    }

    func testUnconfiguredAndNonTrailingSuffixesAreRejected() {
        for username in ["samplebot", "sample", "agent_sample"] {
            XCTAssertEqual(self.configuration.validate(username), .failure(.invalidSuffix))
        }
    }

    func testMissingOrMalformedConfigurationFallsBackToBot() throws {
        for data: [String: Any]? in [nil, [:], ["bot_allowed_suffixes": "ai"], ["bot_allowed_suffixes": [""]]] {
            let configuration = BotUsernameConfiguration(allowedSuffixes: data?["bot_allowed_suffixes"] as? [String])
            XCTAssertEqual(try configuration.validate("SampleBot").get(), "SampleBot")
            XCTAssertEqual(configuration.validate("sampleai"), .failure(.invalidSuffix))
        }
    }

    func testEmptyConfiguredListDoesNotAllowAnySuffix() {
        let configuration = BotUsernameConfiguration(allowedSuffixes: [])
        XCTAssertEqual(configuration.validate("samplebot"), .failure(.invalidSuffix))
    }

    func testSuggestedUsernamePreservesSuffixAndCase() {
        XCTAssertEqual(self.configuration.initialUsername("SampleAI"), "SampleAI")
        XCTAssertEqual(self.configuration.initialUsername("sample"), "sampleagent")
        XCTAssertEqual(self.configuration.initialUsername(nil), "")
        XCTAssertEqual(self.configuration.initialUsername(""), "")
        XCTAssertEqual(BotUsernameConfiguration(allowedSuffixes: nil).initialUsername("sample"), "samplebot")
    }

    func testValidationUsesFullUsernameAndPreservesFormatRules() {
        XCTAssertEqual(self.configuration.validate("abcai"), .success("abcai"))
        XCTAssertEqual(self.configuration.validate("abai"), .failure(.insufficientLength))
        XCTAssertEqual(self.configuration.validate("1testai"), .failure(.startsWithNumber))
        XCTAssertEqual(self.configuration.validate("test-ai"), .failure(.unsupportedCharacters))
        XCTAssertEqual(self.configuration.validate("téstai"), .failure(.unsupportedCharacters))
    }
}
