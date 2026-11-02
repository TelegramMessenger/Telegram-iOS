// A locale tag with a unicode extension (`-u-nu-…`, `-u-ca-…`, `-u-hc-…`) on iOS. Until widget-sandbox v0.2.2 the glue
// built such a locale with Locale(identifier:), which misreads it, and its force-unwraps then trapped, taking the app
// down; WidgetRuntime dropped extensions until every request kind was shown to answer one (follow-ups plan, Task 3).
// Now a widget's tag reaches the glue with only the unicode extension keywords its constructor reads, each with a value
// this client supports; other extensions and private use are dropped (ECMA-402 ResolveLocale; upstream's shim sends the
// tag whole).
import Foundation
import XCTest

import WidgetRuntimeIOS
import WidgetSandboxIntl

final class WRIntlExtensionTests: XCTestCase {
    private final class Delegate: NSObject, WRSessionDelegate {
        func session(_ session: WRSession, diagnostic kind: String, detail: String) {}
        func session(_ session: WRSession, log level: Int, text: String) {}
        func session(_ session: WRSession, bridge method: String, args argsJson: String) {}
        func session(_ session: WRSession, intl requestJson: String) -> String {
            return WidgetSandboxIntl.answer(requestJson)
        }
    }

    private static let tags = [
        "ar-EG-u-nu-arab", "hi-IN-u-nu-deva-ca-indian", "en-u-hc-h23", "th-u-ca-buddhist-nu-thai", "de-u-co-phonebk",
        "ja-JP-u-ca-japanese", "en-US-u-hc-h11-nu-latn", "fa-u-nu-arabext", "en-u-attr-nu-thai", "hi-u-nu-deva-x-y",
    ]

    /// Every kind the glue answers (IntlBridge.format), and the date formatter's hour-cycle path, which rebuilds the
    /// locale from its identifier.
    private static func requests(_ tag: String) -> [[String: Any]] {
        let date: Double = 1_700_000_000_000
        var requests: [[String: Any]] = [
            ["kind": "number", "locale": tag, "opts": [:], "value": 1234.5],
            ["kind": "number", "locale": tag, "opts": ["style": "currency", "currency": "EUR"], "value": 1234.5],
            ["kind": "numberParts", "locale": tag, "opts": ["style": "percent"], "value": 0.25],
            ["kind": "numberOptions", "locale": tag, "opts": ["minimumFractionDigits": 2]],
            ["kind": "date", "locale": tag, "opts": ["dateStyle": "full", "timeStyle": "long", "timeZone": "UTC"], "value": date],
            ["kind": "dateParts", "locale": tag, "opts": ["year": "numeric", "month": "long", "day": "numeric"], "value": date],
            // As the shim sends it: toLocaleTimeString's defaults filled in (globals.ts, dateTimeOptions).
            ["kind": "dateMethod", "method": "toLocaleTimeString", "locale": tag, "opts": ["hour": "numeric", "minute": "numeric", "second": "numeric"], "value": date],
            ["kind": "dateOptions", "locale": tag, "opts": ["hour": "numeric"]],
            ["kind": "plural", "locale": tag, "opts": [:], "value": 3],
            ["kind": "relative", "locale": tag, "opts": ["numeric": "auto"], "value": -1, "unit": "day"],
            ["kind": "list", "locale": tag, "opts": ["type": "conjunction"], "value": ["a", "b", "c"]],
            ["kind": "compare", "locale": tag, "opts": ["sensitivity": "base"], "a": "a", "b": "B"],
            ["kind": "upper", "locale": tag, "value": "straße"],
            ["kind": "lower", "locale": tag, "value": "İSTANBUL"],
            ["kind": "date", "locale": tag, "opts": ["hour": "numeric", "minute": "numeric", "hour12": true], "value": date],
        ]
        for cycle in ["h11", "h12", "h23", "h24"] {
            requests.append(["kind": "dateParts", "locale": tag, "opts": ["hour": "numeric", "minute": "numeric", "hourCycle": cycle], "value": date])
        }
        return requests
    }

    /// The glue's safety for a tag with an extension: each request answers, none traps (a trap would end the test
    /// process, as it would the app). These tags hold more than the runtime sends (attributes, private use, unfiltered
    /// keywords), so the glue stays safe should that filter ever let one through.
    func testEveryRequestKindAnswersATagWithAnExtension() throws {
        var answered = 0
        for tag in Self.tags {
            for request in Self.requests(tag) {
                let json = String(decoding: try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys]), as: UTF8.self)
                XCTAssertFalse(WidgetSandboxIntl.answer(json).isEmpty, json)
                answered += 1
            }
        }
        print("intl extensions: \(answered) requests answered")
    }

    /// A widget's extension reaches the glue, which applies it on iOS 16 and later: Thai digits, the Japanese calendar's
    /// era, a 23-hour clock.
    func testAWidgetsExtensionIsApplied() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        let thai = session.evaluate(forTesting: "new Intl.NumberFormat('en-US-u-nu-thai').format(1234)") ?? ""
        XCTAssertTrue(thai.contains("๑"), thai)
        let era = session.evaluate(forTesting: "new Date(Date.UTC(2023, 0, 1)).toLocaleDateString('ja-JP-u-ca-japanese', { era: 'long', year: 'numeric', timeZone: 'UTC' })") ?? ""
        XCTAssertTrue(era.contains("令和"), era)
        let hour = session.evaluate(forTesting: "new Date(Date.UTC(2023, 0, 1, 13)).toLocaleTimeString('en-u-hc-h23', { hour: 'numeric', timeZone: 'UTC' })") ?? ""
        XCTAssertTrue(hour.hasPrefix("13"), hour)
        withExtendedLifetime(delegate) {}
    }

    /// Every Intl call a widget can make, run through a session (the runtime's own resolution, then the glue).
    private static let calls = [
        "new Intl.NumberFormat(TAG).format(1234.5)",
        "(1234.5).toLocaleString(TAG, { style: 'currency', currency: 'EUR' })",
        "new Intl.DateTimeFormat(TAG, { dateStyle: 'full', timeStyle: 'long', timeZone: 'UTC' }).format(0)",
        "new Intl.DateTimeFormat(TAG, { hour: 'numeric', minute: 'numeric', hour12: true, timeZone: 'UTC' }).format(0)",
        "new Intl.DateTimeFormat(TAG, { hour: 'numeric', hourCycle: 'h23', timeZone: 'UTC' }).formatToParts(0).length",
        "new Date(0).toLocaleTimeString(TAG)",
        "new Intl.RelativeTimeFormat(TAG, { numeric: 'auto' }).format(-1, 'day')",
        "new Intl.RelativeTimeFormat(TAG).format(3, 'quarter')",
        "new Intl.PluralRules(TAG).select(2)",
        "new Intl.ListFormat(TAG).format(['a', 'b'])",
        "new Intl.Collator(TAG, { sensitivity: 'base' }).compare('a', 'B')",
        "new Intl.NumberFormat(TAG).resolvedOptions().locale",
    ]

    private func answers(_ session: WRSession, _ tag: String) -> [String] {
        let quoted = "'" + tag + "'"
        // A call that throws answers its error's text, which the callers fail on.
        return Self.calls.map { session.evaluate(forTesting: "String(" + $0.replacingOccurrences(of: "TAG", with: quoted) + ")") ?? "" }
    }

    /// Follow-ups review, C1: a numbering system name Foundation does not know (`bogus`, a bare `nu`, `yes`, the
    /// misspelt `japanfin`) made the relative formatter trap, taking the app down. The runtime keeps only a supported
    /// value of a keyword its constructor reads, so every call answers.
    func testAnUnsupportedKeywordNeverReachesTheGlue() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        for tag in ["en-u-nu-bogus", "en-u-nu", "en-u-nu-yes", "en-u-ca-japanese-nu-japanfin", "en-u-nu-abcdefgh", "en-u-nu-zzzzzzzz",
                    "en-u-ca-bogus", "en-u-hc-h99", "de-u-co-bogus", "en-u-attr-nu-thai", "de-t-en", "hi-x-y", "en-t-ja-x-a",
                    "ar-u-nu-arab", "fa-u-nu-arabext", "ru-u-nu-latn"] {
            if tag == "en-u-nu-bogus" {
                // Follow-ups review, I2: an unknown value is ignored as a browser ignores it, not formatted as "1234.5".
                XCTAssertEqual(session.evaluate(forTesting: "new Intl.NumberFormat('en-u-nu-bogus').format(1234.5)"), "1,234.5")
            }
            for (call, answer) in zip(Self.calls, self.answers(session, tag)) {
                XCTAssertFalse(answer.isEmpty || answer.contains("Error"), "\(tag): \(call) → \(answer)")
            }
        }
        withExtendedLifetime(delegate) {}
    }

    /// Follow-ups review, I1: plural categories are the language's (ECMA-402: PluralRules reads no extension keyword).
    /// With one, the glue's language key was `ar@numbers=arab`, which matches no rules, so everything was "other".
    func testPluralRulesReadTheLanguageAlone() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('ar-u-nu-arab').select(2)"), "two")
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('ru-u-nu-latn').select(2)"), "few")
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('fa-u-nu-arabext').select(0)"), "one")
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('ar-u-nu-arab').resolvedOptions().locale"), "ar")
        // Any other extension and private use, too (they reached Foundation as `@…=` keywords on the language key).
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('ar-t-en').select(2)"), "two")
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('ru-x-private').select(2)"), "few")
        XCTAssertEqual(session.evaluate(forTesting: "new Intl.PluralRules('ar-a-bc-u-nu-arab').select(2)"), "two")
        withExtendedLifetime(delegate) {}
    }

    /// Every numbering system CLDR names, numeric or algorithmic, and some it does not, through every call: the ones the
    /// runtime keeps answer (the glue applies them), the others are dropped before the glue. A value kept that Foundation
    /// cannot format would trap here.
    func testEveryNumberingSystemAnswers() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        let systems = "adlm ahom arab arabext armn armnlow bali beng bhks brah cakm cham cyrl deva diak ethi fullwide gara geor gong gonm grek greklow gujr gukh guru hanidays hanidec hans hansfin hant hantfin hebr hmng hmnp java jpan jpanfin jpanyear kali kawi khmr knda krai lana lanatham laoo latn lepc limb mathbold mathdbl mathmono mathsanb mathsans mlym modi mong mroo mtei mymr mymrepka mymrpao mymrshan mymrtlng nagm newa nkoo olck onao orya osma outlined rohg roman romanlow saur segment shrd sind sinh sora sund sunu takr talu taml tamldec telu thai tibt tirh tnsa tols vaii wara wcho"
        for system in systems.split(separator: " ") {
            for tag in ["en-u-nu-\(system)", "ar-EG-u-nu-\(system)"] {
                for (call, answer) in zip(Self.calls, self.answers(session, tag)) {
                    XCTAssertFalse(answer.isEmpty || answer.contains("Error"), "\(tag): \(call) → \(answer)")
                }
            }
        }
        withExtendedLifetime(delegate) {}
    }
    /// Every calendar CLDR names (iOS 18's additions and islamic-rgsa among them), an unknown one and every hour cycle,
    /// through every call: what DateTimeFormat keeps answers, the rest is dropped before the glue.
    func testEveryCalendarAndHourCycleAnswers() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        let calendars = "buddhist chinese coptic dangi ethioaa ethiopic gregory hebrew indian islamic islamic-civil islamic-rgsa islamic-tbla islamic-umalqura iso8601 japanese persian roc bangla gujarati kannada marathi odia tamil telugu vikram bogus"
        for calendar in calendars.split(separator: " ") {
            for tag in ["en-u-ca-\(calendar)", "ja-JP-u-ca-\(calendar)-hc-h23", "ar-u-ca-\(calendar)-nu-arab"] {
                for (call, answer) in zip(Self.calls, self.answers(session, tag)) {
                    XCTAssertFalse(answer.isEmpty || answer.contains("Error"), "\(tag): \(call) → \(answer)")
                }
            }
        }
        for cycle in ["h11", "h12", "h23", "h24", "h99"] {
            for (call, answer) in zip(Self.calls, self.answers(session, "en-u-hc-\(cycle)")) {
                XCTAssertFalse(answer.isEmpty || answer.contains("Error"), "en-u-hc-\(cycle): \(call) → \(answer)")
            }
        }
        withExtendedLifetime(delegate) {}
    }

    /// Every collation CLDR names, `standard` and `search` (which a `co` keyword may not name), an unknown one, and the
    /// numeric and case-first keywords, through every call: what Collator keeps answers, the rest is dropped before the
    /// glue.
    func testEveryCollationAnswers() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        let collations = "big5han compat dict direct ducet emoji eor gb2312 phonebk phonetic pinyin reformed searchjl stroke trad unihan zhuyin standard search bogus"
        for collation in collations.split(separator: " ") {
            for tag in ["de-u-co-\(collation)", "zh-u-co-\(collation)-kn-true", "sv-u-co-\(collation)-kf-upper"] {
                for (call, answer) in zip(Self.calls, self.answers(session, tag)) {
                    XCTAssertFalse(answer.isEmpty || answer.contains("Error"), "\(tag): \(call) → \(answer)")
                }
            }
        }
        for keyword in ["kn-true", "kn-false", "kn", "kn-bogus", "kf-upper", "kf-lower", "kf-false", "kf-bogus"] {
            for (call, answer) in zip(Self.calls, self.answers(session, "en-u-\(keyword)")) {
                XCTAssertFalse(answer.isEmpty || answer.contains("Error"), "en-u-\(keyword): \(call) → \(answer)")
            }
        }
        withExtendedLifetime(delegate) {}
    }
}