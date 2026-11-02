// widget-sandbox v0.1.1's Intl parity fixture end to end on iOS, as the app answers it: each case run as the call a
// widget would make (WidgetRuntime's Tests/IntlCases.js), the runtime's request answered by widget-sandbox's iOS glue
// (the delegate does what MessageWidgetCore's does), against the drift list's `ios` lines.
import Foundation
import XCTest

import WidgetRuntimeIOS
import WidgetSandboxIntl

final class WRIntlCasesTests: XCTestCase {
    private final class Delegate: NSObject, WRSessionDelegate {
        func session(_ session: WRSession, diagnostic kind: String, detail: String) {}
        func session(_ session: WRSession, log level: Int, text: String) {}
        func session(_ session: WRSession, bridge method: String, args argsJson: String) {}
        func session(_ session: WRSession, intl requestJson: String) -> String {
            return WidgetSandboxIntl.answer(requestJson)
        }
    }

    private func resource(_ name: String) -> String? {
        let url = URL(fileURLWithPath: name)
        guard let path = Bundle(for: WRIntlCasesTests.self).path(forResource: url.deletingPathExtension().lastPathComponent, ofType: url.pathExtension) else {
            return nil
        }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// The line's id: what precedes " ## ", trailing spaces dropped.
    private static func idOf(_ line: String) -> String {
        let head = line.range(of: " ## ").map { String(line[..<$0.lowerBound]) } ?? line
        return head.trimmingCharacters(in: .whitespaces)
    }

    func testTheIntlCasesAnswerAsV8() throws {
        let fixture = try XCTUnwrap(self.resource("intl-cases.json"))
        let script = try XCTUnwrap(self.resource("IntlCases.js"))
        let list = try XCTUnwrap(self.resource("intl-cases-expected-failures.txt"))
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 300.0, dark: false, scale: 2.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: "<!doctype html><p>x</p>"))
        let quoted = String(decoding: try JSONSerialization.data(withJSONObject: fixture, options: [.fragmentsAllowed]), as: UTF8.self)
        let result = session.evaluate(forTesting: "window.intlCasesText = \(quoted);\n\(script)") ?? ""
        let expected = Set(list.split(separator: "\n").map(String.init).filter { $0.hasPrefix("ios ") }.map { Self.idOf(String($0.dropFirst(4))) })
        var failures = Set<String>()
        for line in result.split(separator: "\n").map(String.init) where !line.isEmpty {
            let id = Self.idOf(line)
            failures.insert(id)
            XCTAssertTrue(expected.contains(id), "unexpected: \(line)")
        }
        for id in expected {
            XCTAssertTrue(failures.contains(id), "answers as V8 now (remove it from the list): \(id)")
        }
        print("intl cases: \(failures.count) differ")
        withExtendedLifetime(delegate) {}
    }
}
