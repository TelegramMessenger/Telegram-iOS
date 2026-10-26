import XCTest
import TelegramCore
import CreateBotScreen

/// The Create Bot sheet's username field resolves to one username, read by the grey suffix, local
/// validation, the availability check, the Create button and the create call alike. The endings other
/// than 'bot' come from the `bot_allowed_suffixes` app config.
final class CreateBotUsernameTests: XCTestCase {
    private let endings = CreateBotUsernameEndings(configuredValue: ["bot", "ai", "agent", "app", "game"] as [Any])
    private let noConfiguredEndings = CreateBotUsernameEndings(configuredValue: nil)

    // MARK: - The configured list

    func testConfiguredEndingsOtherThanBotNeedPremium() {
        XCTAssertEqual(self.endings.premium, ["ai", "agent", "app", "game"])
        XCTAssertEqual(self.endings.all, ["bot", "ai", "agent", "app", "game"])
    }

    func testEndingsAreReadThroughTheAppConfigurationsJSON() {
        // The production value is a JSON element, not a Swift array literal.
        let data: JSON = ["bot_allowed_suffixes": ["bot", "ai", "app"]]
        let endings = CreateBotUsernameEndings(configuredValue: data[CreateBotUsernameEndings.appConfigurationKey])
        XCTAssertEqual(endings.premium, ["ai", "app"])
    }

    func testConfiguredEndingsAreNormalized() {
        let endings = CreateBotUsernameEndings(configuredValue: ["AI", "ai", "", "Bot", "app"] as [Any])
        XCTAssertEqual(endings.premium, ["ai", "app"])
    }

    func testWithoutTheKeyOnlyBotIsOffered() {
        XCTAssertEqual(self.noConfiguredEndings.all, ["bot"])
        XCTAssertEqual(CreateBotUsernameEndings(configuredValue: "ai,app").all, ["bot"], "not an array")
        XCTAssertEqual(CreateBotUsernameEndings(configuredValue: [1.0, 2.0] as [Any]).all, ["bot"])
    }

    // MARK: - Endings

    func testPlainTextGetsTheGreyBotSuffix() {
        let value = CreateBotUsername(typedText: "durgerking", endings: self.endings)

        XCTAssertEqual(value.ending, "bot")
        XCTAssertEqual(value.appendedSuffix, "bot")
        XCTAssertEqual(value.username, "durgerkingbot")
        XCTAssertFalse(value.requiresPremium)
    }

    func testATypedEndingIsUsedExactlyAsTyped() {
        for ending in self.endings.all {
            let value = CreateBotUsername(typedText: "durgerking" + ending, endings: self.endings)

            XCTAssertEqual(value.ending, ending)
            XCTAssertNil(value.appendedSuffix, "\(ending) was typed, so nothing is appended")
            XCTAssertEqual(value.username, "durgerking" + ending)
            XCTAssertEqual(value.requiresPremium, ending != "bot")
        }
    }

    func testAnEndingTheServerDoesNotListIsOrdinaryText() {
        let value = CreateBotUsername(typedText: "durgerkingapp", endings: self.noConfiguredEndings)
        XCTAssertEqual(value.username, "durgerkingappbot")
        XCTAssertFalse(value.requiresPremium)
    }

    func testTheLongestConfiguredEndingWins() {
        let endings = CreateBotUsernameEndings(configuredValue: ["gpt", "chatgpt"] as [Any])
        XCTAssertEqual(CreateBotUsername(typedText: "mychatgpt", endings: endings).ending, "chatgpt")
        XCTAssertEqual(CreateBotUsername(typedText: "mygpt", endings: endings).ending, "gpt")
    }

    func testEndingsAreCaseInsensitiveAndKeepTheTypedCase() {
        XCTAssertEqual(CreateBotUsername(typedText: "DurgerKingApp", endings: self.endings).ending, "app")
        XCTAssertEqual(CreateBotUsername(typedText: "DurgerKingApp", endings: self.endings).username, "DurgerKingApp")

        // A deep link suggesting "FooBot" used to show "Bot" as the grey suffix but create "foobot".
        XCTAssertEqual(CreateBotUsername(typedText: "FooBot", endings: self.endings).ending, "bot")
        XCTAssertEqual(CreateBotUsername(typedText: "FooBot", endings: self.endings).username, "FooBot")
    }

    func testAnEndingAloneIsOrdinaryText() {
        XCTAssertEqual(CreateBotUsername(typedText: "agent", endings: self.endings).username, "agentbot")
        XCTAssertEqual(CreateBotUsername(typedText: "bot", endings: self.endings).username, "botbot")
        XCTAssertEqual(CreateBotUsername(typedText: "", endings: self.endings).username, "bot")
    }

    func testAWordThatHappensToEndInAnEndingTakesIt() {
        // Accepted in the design: "shanghai" reads as the 'ai' ending; "shanghaibot" is the bot one.
        XCTAssertEqual(CreateBotUsername(typedText: "shanghai", endings: self.endings).ending, "ai")
        XCTAssertEqual(CreateBotUsername(typedText: "shanghai", endings: self.endings).username, "shanghai")
        XCTAssertEqual(CreateBotUsername(typedText: "shanghaibot", endings: self.endings).ending, "bot")
    }

    func testAPartlyTypedEndingKeepsTheGreySuffix() {
        XCTAssertEqual(CreateBotUsername(typedText: "durgerkingap", endings: self.endings).username, "durgerkingapbot")
        XCTAssertEqual(CreateBotUsername(typedText: "durgerkingbo", endings: self.endings).username, "durgerkingbobot")
    }

    // MARK: - Validation runs on the full username

    func testMinimumLengthCountsTheAppendedSuffix() {
        XCTAssertNil(CreateBotUsername(typedText: "ab", endings: self.endings).validationError, "abbot is 5 characters")
        XCTAssertEqual(CreateBotUsername(typedText: "a", endings: self.endings).validationError, .tooShort)
    }

    func testMaximumLengthCountsTheAppendedSuffix() {
        let stem29 = String(repeating: "a", count: 29)
        XCTAssertNil(CreateBotUsername(typedText: stem29, endings: self.endings).validationError, "29 + bot is 32")
        XCTAssertEqual(CreateBotUsername(typedText: stem29 + "a", endings: self.endings).validationError, .tooLong)
        XCTAssertNil(CreateBotUsername(typedText: stem29 + "app", endings: self.endings).validationError,
                     "a typed ending adds nothing")
    }

    func testCharacterRules() {
        XCTAssertEqual(CreateBotUsername(typedText: "1durger", endings: self.endings).validationError, .startsWithNumber)
        XCTAssertEqual(CreateBotUsername(typedText: "durger-king", endings: self.endings).validationError, .unsupportedCharacters)
        XCTAssertNil(CreateBotUsername(typedText: "durger_king", endings: self.endings).validationError)
    }

    // MARK: - Server errors

    func testKnownServerErrors() {
        XCTAssertEqual(BotUsernameServerError(errorDescription: "USERNAME_OCCUPIED"), .occupied)
        XCTAssertEqual(BotUsernameServerError(errorDescription: "USERNAME_PURCHASE_AVAILABLE"), .purchaseAvailable)
        // Seen live for "durgerk7731app" from an account whose app config lists no extra endings.
        XCTAssertEqual(BotUsernameServerError(errorDescription: "USERNAME_SUFFIX_MISSING"), .suffixNotAllowed)
    }

    func testPremiumErrorsMatchByKeyword() {
        for error in ["USERNAME_PREMIUM_REQUIRED", "PREMIUM_ACCOUNT_REQUIRED", "BOT_USERNAME_SUFFIX_PREMIUM"] {
            XCTAssertEqual(BotUsernameServerError(errorDescription: error), .premiumRequired, error)
        }
    }

    func testTheEndingCapMatchesByKeywordAndReadsATrailingNumber() {
        XCTAssertEqual(BotUsernameServerError(errorDescription: "BOT_USERNAME_SUFFIX_LIMIT_EXCEEDED"),
                       .suffixLimitExceeded(limit: nil))
        XCTAssertEqual(BotUsernameServerError(errorDescription: "USERNAME_SUFFIX_LIMIT_2"),
                       .suffixLimitExceeded(limit: 2))
        XCTAssertEqual(BotUsernameServerError(errorDescription: "BOT_USERNAMES_TOO_MANY"),
                       .suffixLimitExceeded(limit: nil))
    }

    func testTheCapWinsOverPremiumWhenBothKeywordsAppear() {
        // A user without Premium never reaches the server with a premium ending, so an error naming
        // both is a Premium user hitting the cap.
        XCTAssertEqual(BotUsernameServerError(errorDescription: "USERNAME_PREMIUM_LIMIT_EXCEEDED"),
                       .suffixLimitExceeded(limit: nil))
    }

    func testUnrelatedErrorsAreNotClaimed() {
        for error in ["BOT_CREATE_LIMIT_EXCEEDED", "USERNAME_INVALID", "FLOOD_WAIT_30", "INTERNAL"] {
            XCTAssertNil(BotUsernameServerError(errorDescription: error), error)
        }
    }
}
