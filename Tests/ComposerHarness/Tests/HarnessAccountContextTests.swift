import XCTest
import TelegramUIPreferences
import SwiftSignalKit
import TelegramCore
import AccountContext
@testable import HarnessAppContext

/// **A HOSTED test, and it has to be.** `HarnessSharedAccountContext.init` builds a
/// `PresentationData`, and `defaultPresentationStrings` force-unwraps
/// `getAppBundle().path(forResource: "Localizable", ofType: "strings" …)`
/// (`TelegramPresentationData/Sources/DefaultPresentationStrings.swift:44`). In a hostless logic
/// test there is no app bundle carrying that resource, so merely constructing the context traps.
/// That is why these cases live beside the app rather than in `AppContextTests/`.
final class HarnessAccountContextTests: XCTestCase {
    private func makeAccount() -> HarnessAccount {
        let done = XCTestExpectation(description: "account created")
        var harnessAccount: HarnessAccount?
        let disposable = HarnessAccount.make().start(next: { value in
            harnessAccount = value
            done.fulfill()
        })
        defer { disposable.dispose() }
        wait(for: [done], timeout: 60.0)
        return harnessAccount!
    }

    private func makeContext(backend: HarnessBackend, darkTheme: Bool = false, account: HarnessAccount? = nil) -> HarnessAccountContext {
        let settings = HarnessSettings()
        settings.backend = backend
        settings.useDarkTheme = darkTheme
        return HarnessAccountContext(account: account ?? self.makeAccount(), settings: settings)
    }

    /// These reads are how the REAL panel picks its backend
    /// (ChatTextInputPanelNode.swift:863-881). If the harness answers them wrongly it silently
    /// tests the wrong editor, which is the single worst outcome available to this project.
    func testEngineBackendSetsTheTwoExperimentalFlags() {
        let context = makeContext(backend: .engine)
        let settings = context.sharedContext.immediateExperimentalUISettings
        XCTAssertTrue(settings.useInputDecEngine)
        XCTAssertTrue(settings.inputDecTextBackend)
    }

    func testLegacyBackendClearsThem() {
        let context = makeContext(backend: .legacy)
        let settings = context.sharedContext.immediateExperimentalUISettings
        XCTAssertFalse(settings.useInputDecEngine)
        XCTAssertFalse(settings.inputDecTextBackend)
    }

    func testPresentationDataAndLimitsAreReal() {
        let context = makeContext(backend: .engine)
        XCTAssertFalse(context.sharedContext.currentPresentationData.with({ $0 })
            .strings.primaryComponent.languageCode.isEmpty)
        XCTAssertGreaterThan(
            context.currentLimitsConfiguration.with({ $0 }).maxGroupMemberCount, 0)
    }

    func testAccountPeerIdIsTheHarnessPeer() {
        XCTAssertEqual(makeContext(backend: .engine).account.peerId, HarnessAccount.harnessPeerId)
    }

    /// Emoji suggestions read the shared account manager on every keystroke that ends in an emoji
    /// (`EmojiSuggestionsComponent.suggestionData` from `ChatTextInputPanelNode.updateInputField`);
    /// an unprovided member trapped there and took the whole app down on the first emoji.
    func testTheAccountManagerIsTheAccountsOwn() {
        let account = self.makeAccount()
        let context = makeContext(backend: .engine, account: account)
        XCTAssertTrue(context.sharedContext.accountManager === account.accountManager)
    }

    /// `-harness-theme dark` was parsed and then read by nothing, so the panel stayed light.
    func testTheDarkThemeReachesThePresentationData() {
        XCTAssertFalse(makeContext(backend: .engine).sharedContext.currentPresentationData.with({ $0 })
            .theme.overallDarkAppearance)
        XCTAssertTrue(makeContext(backend: .engine, darkTheme: true).sharedContext.currentPresentationData.with({ $0 })
            .theme.overallDarkAppearance)
    }

    /// `-harness-font-size` must reach the presentation data the panel reads its size from.
    func testTheFontSizeReachesThePresentationData() {
        let account = self.makeAccount()
        let settings = HarnessSettings()
        settings.fontSize = .extraLarge
        let context = HarnessAccountContext(account: account, settings: settings)
        XCTAssertEqual(context.sharedContext.currentPresentationData.with({ $0 }).chatFontSize, .extraLarge)
    }
}
