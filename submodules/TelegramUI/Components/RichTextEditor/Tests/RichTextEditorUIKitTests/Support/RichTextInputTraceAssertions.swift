#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit

@available(iOS 16.0, *)
func XCTAssertTrace(_ recorder: RichTextInputEventRecorder,
                    _ expected: [RichTextInputRecordedEventKind],
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(recorder.kinds, expected,
                   "trace mismatch\nactual:\n\(recorder.trace())", file: file, line: line)
}

@available(iOS 16.0, *)
func XCTAssertTraceStates(_ recorder: RichTextInputEventRecorder,
                          _ expected: [(RichTextInputRecordedEventKind, anchor: Int, head: Int, revision: UInt64)],
                          file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(recorder.events.count, expected.count,
                   "event count mismatch\nactual:\n\(recorder.trace())", file: file, line: line)
    for (i, e) in expected.enumerated() where i < recorder.events.count {
        let actual = recorder.events[i]
        XCTAssertEqual(actual.kind, e.0, "event \(i) kind", file: file, line: line)
        XCTAssertEqual(actual.anchor, e.anchor, "event \(i) anchor", file: file, line: line)
        XCTAssertEqual(actual.head, e.head, "event \(i) head", file: file, line: line)
        XCTAssertEqual(actual.revision, e.revision, "event \(i) revision", file: file, line: line)
    }
}

/// Overload adding `markedRange` to the pinned per-event state (Task 7: marked-text/prediction traces
/// are exactly the case where the plain 4-tuple overload above under-specifies the scenario — two
/// events can share `(kind, anchor, head, revision)` while disagreeing on whether a composition is
/// live). Distinguished from the overload above by BOTH arity and the labeled first element, so
/// existing 4-tuple call sites are unaffected.
@available(iOS 16.0, *)
func XCTAssertTraceStates(_ recorder: RichTextInputEventRecorder,
                          _ expected: [(kind: RichTextInputRecordedEventKind, anchor: Int, head: Int, revision: UInt64, markedRange: NSRange?)],
                          file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(recorder.events.count, expected.count,
                   "event count mismatch\nactual:\n\(recorder.trace())", file: file, line: line)
    for (i, e) in expected.enumerated() where i < recorder.events.count {
        let actual = recorder.events[i]
        XCTAssertEqual(actual.kind, e.kind, "event \(i) kind", file: file, line: line)
        XCTAssertEqual(actual.anchor, e.anchor, "event \(i) anchor", file: file, line: line)
        XCTAssertEqual(actual.head, e.head, "event \(i) head", file: file, line: line)
        XCTAssertEqual(actual.revision, e.revision, "event \(i) revision", file: file, line: line)
        XCTAssertEqual(actual.markedRange, e.markedRange, "event \(i) markedRange", file: file, line: line)
    }
}
#endif
