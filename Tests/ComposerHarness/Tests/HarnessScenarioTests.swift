import XCTest
import TelegramUIPreferences
@testable import ComposerHarnessLib
@testable import HarnessAppContext

final class HarnessScenarioTests: XCTestCase {
    func testDefaultsWhenNoArgumentsAreGiven() {
        let options = HarnessLaunchOptions.parse([])
        XCTAssertEqual(options.scenario.name, "empty")
        XCTAssertEqual(options.backend, .engine)
        XCTAssertFalse(options.useDarkTheme)
        XCTAssertEqual(options.fontSize, .regular)
    }

    /// Settings ▸ Appearance ▸ Text Size, by the `PresentationFontSize` case name.
    func testParsesTheFontSize() {
        XCTAssertEqual(HarnessLaunchOptions.parse(["-harness-font-size", "extraLargeX2"]).fontSize, .extraLargeX2)
        XCTAssertEqual(HarnessLaunchOptions.parse(["-harness-font-size", "nope"]).fontSize, .regular)
    }

    func testParsesEveryKnob() {
        let options = HarnessLaunchOptions.parse([
            "-harness-scenario", "one-paragraph",
            "-harness-backend", "legacy",
            "-harness-theme", "dark",
        ])
        XCTAssertEqual(options.scenario.name, "one-paragraph")
        XCTAssertEqual(options.backend, .legacy)
        XCTAssertTrue(options.useDarkTheme)
    }

    /// An unknown scenario must fall back safely rather than crash an app an agent is trying to
    /// drive; the readout shows "empty" and the mismatch is obvious from the screen.
    func testUnknownScenarioFallsBackToEmpty() {
        XCTAssertEqual(
            HarnessLaunchOptions.parse(["-harness-scenario", "nope"]).scenario.name, "empty")
    }

    func testEveryRegisteredScenarioHasAUniqueName() {
        let names = HarnessScenario.all.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
    }

    /// The seeds are the fixtures every later test arranges from, so a seed that does not produce
    /// the text it claims would corrupt every case built on it.
    func testSeedsProduceTheirText() throws {
        let single = try XCTUnwrap(HarnessScenario.named("one-paragraph")?.seed)
        XCTAssertEqual(single.plainText, "The quick brown fox jumps over the lazy dog.")

        let double = try XCTUnwrap(HarnessScenario.named("two-paragraphs")?.seed)
        XCTAssertEqual(double.blocks.count, 2)
        XCTAssertEqual(double.plainText, "First paragraph.\nSecond paragraph.")
    }
}
