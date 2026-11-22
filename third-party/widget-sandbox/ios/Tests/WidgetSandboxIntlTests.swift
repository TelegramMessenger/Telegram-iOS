// widget-sandbox's iOS glue alone against its own Intl fixture (fixtures/intl-cases.json: requests as the shim sends
// them, with V8's answers), compared as upstream's IntlBridgeTests.testSharedFixtureMatchesV8 compares: strings with
// U+00A0, U+202F and U+2009 as spaces, parts as [type, value] lists, options on the expected keys. On the host's
// Foundation; WidgetRuntimeIOS's WRIntlCasesTests runs the same cases through the runtime on iOS's.
import Foundation
import XCTest

import WidgetSandboxIntl

final class WidgetSandboxIntlTests: XCTestCase {
    private func fixture() throws -> [[String: Any]] {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["WR_INTL_CASES"])
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any])
        return try XCTUnwrap(root["cases"] as? [[String: Any]])
    }

    func testTheFixtureAnswersAsV8() throws {
        let cases = try self.fixture()
        var mismatches: [String] = []
        for c in cases {
            let request = try XCTUnwrap(c["request"] as? [String: Any])
            let json = String(decoding: try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys]), as: UTF8.self)
            let got = WidgetSandboxIntl.answer(json)
            if !Self.matches(got, c["expected"]) {
                mismatches.append("\(json): \(got) != \(c["expected"] ?? "nil")")
            }
        }
        XCTAssertGreaterThan(cases.count, 100)
        XCTAssertEqual(mismatches, [], mismatches.joined(separator: "\n"))
    }

    /// The extremes a widget can make WidgetRuntime send (any finite number, a BigInt's digits, the largest digit
    /// options, the time range's ends, the longest strings and lists, a locale tag of every shape but a unicode
    /// extension, which the runtime never sends) are answered, never trapped on: a trap would take the app down.
    func testTheExtremesAreAnswered() throws {
        let long = String(repeating: "ab", count: 500_000)
        let digits = String(repeating: "9", count: 100_000)
        let items = (0 ..< 10_000).map { "\"item\($0)\"" }.joined(separator: ",")
        let requests = [
            #"{"kind":"relative","locale":"en","opts":{"numeric":"auto"},"value":1e305,"unit":"years"}"#,
            #"{"kind":"relative","locale":"ru","opts":{},"value":-1.7976931348623157e308,"unit":"quarter"}"#,
            #"{"kind":"relative","locale":"en","opts":{"style":"narrow"},"value":1.7976931348623157e308,"unit":"quarters"}"#,
            #"{"kind":"relative","locale":"de","opts":{},"value":5e-324,"unit":"second"}"#,
            #"{"kind":"plural","locale":"ru","opts":{"minimumFractionDigits":100,"maximumFractionDigits":100},"value":1.7976931348623157e308}"#,
            #"{"kind":"plural","locale":"fr","opts":{"type":"ordinal"},"value":-1e-300}"#,
            #"{"kind":"number","locale":"en","opts":{"minimumFractionDigits":100,"minimumIntegerDigits":21},"value":1.7976931348623157e308}"#,
            #"{"kind":"numberParts","locale":"en","opts":{"maximumSignificantDigits":21,"signDisplay":"exceptZero"},"value":-5e-324}"#,
            #"{"kind":"number","locale":"en","opts":{"style":"currency","currency":"XXX","currencyDisplay":"name"},"value":"# + digits + "}",
            #"{"kind":"date","locale":"en","opts":{"timeZone":"Mars/Base","year":"numeric","era":"long","fractionalSecondDigits":3},"value":8640000000000000}"#,
            #"{"kind":"dateParts","locale":"ar-EG","opts":{"dateStyle":"full","timeStyle":"full","hourCycle":"h24","calendar":"islamic"},"value":-8640000000000000}"#,
            #"{"kind":"dateMethod","method":"toLocaleString","locale":"zz-Zzzz-ZZ-x-priv","opts":{"hour12":true,"hourCycle":"h23","hour":"numeric"},"value":0}"#,
            #"{"kind":"list","locale":"en","opts":{"type":"unit","style":"narrow"},"value":["# + items + "]}",
            #"{"kind":"compare","locale":"de","opts":{"sensitivity":"base","numeric":true},"a":""# + long + #"","b":""# + long + #"c"}"#,
        ]
        for request in requests {
            _ = WidgetSandboxIntl.answer(request)
        }
    }

    private static func spaces(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{a0}", with: " ").replacingOccurrences(of: "\u{202f}", with: " ").replacingOccurrences(of: "\u{2009}", with: " ")
    }

    private static func matches(_ got: String, _ expected: Any?) -> Bool {
        if let s = expected as? String {
            return spaces(got) == spaces(s)
        }
        let parsed = try? JSONSerialization.jsonObject(with: Data(got.utf8))
        if let list = expected as? [[String: String]] {
            guard let g = parsed as? [[String: Any]] else {
                return false
            }
            return g.map { [$0["type"] as? String ?? "", spaces($0["value"] as? String ?? "")] } == list.map { [$0["type"] ?? "", spaces($0["value"] ?? "")] }
        }
        if let object = expected as? [String: Any] {
            guard let g = parsed as? [String: Any] else {
                return false
            }
            return object.allSatisfy { (g[$0.key] as? NSObject)?.isEqual($0.value) == true }
        }
        return false
    }
}
