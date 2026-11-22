#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

/// Only `addAnnotation`/`removeAnnotation` have a dedicated log Event
/// (`.annotationAdd`/`.annotationRemove`) — the shared `RichTextInputEventLog.Event` enum has no case
/// for the other five members (`annotatedSubstring`, `annotationValue`, the rendering-attribute pair,
/// `invalidateTemporaryAttributes`), so they are tracked with plain call counters instead of writing
/// into the shared log. This mirrors `FakeInputDocumentClient`'s own `clamp`/`isValidInsertionPosition`/
/// `typingAttributes`, none of which log either — not every protocol member has interleaving that a
/// later contract test needs pinned against the other six clients.
@MainActor
@available(iOS 16.0, *)
final class FakeInputAnnotationClient: RichTextInputAnnotationClient {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    var annotatedSubstringToReturn: NSAttributedString? = nil
    var annotationValueToReturn: Any? = nil
    var addAnnotationResult = true
    var removeAnnotationResult = true
    var addRenderingAttributesResult = true
    var removeRenderingAttributesResult = true

    private(set) var annotatedSubstringReadCount = 0
    private(set) var annotationValueReadCount = 0
    private(set) var addRenderingAttributesCallCount = 0
    private(set) var removeRenderingAttributesCallCount = 0
    private(set) var invalidateTemporaryAttributesCallCount = 0
    private(set) var lastInvalidatedRange: NSRange? = nil

    func annotatedSubstring(in range: NSRange, revision: UInt64) -> NSAttributedString? {
        annotatedSubstringReadCount += 1
        return annotatedSubstringToReturn
    }
    func annotationValue(for key: AnyHashable, at position: RichTextInputPosition,
                         revision: UInt64) -> Any? {
        annotationValueReadCount += 1
        return annotationValueToReturn
    }
    @discardableResult
    func addAnnotation(key: AnyHashable, value: Any, range: NSRange, revision: UInt64) -> Bool {
        log.record(.annotationAdd(range: range, revision: revision))
        return addAnnotationResult
    }
    @discardableResult
    func removeAnnotation(key: AnyHashable, range: NSRange, revision: UInt64) -> Bool {
        log.record(.annotationRemove(range: range, revision: revision))
        return removeAnnotationResult
    }
    @discardableResult
    func addRenderingAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange,
                               revision: UInt64) -> Bool {
        addRenderingAttributesCallCount += 1
        return addRenderingAttributesResult
    }
    @discardableResult
    func removeRenderingAttributes(_ keys: [NSAttributedString.Key], range: NSRange,
                                  revision: UInt64) -> Bool {
        removeRenderingAttributesCallCount += 1
        return removeRenderingAttributesResult
    }
    func invalidateTemporaryAttributes(in range: NSRange, revision: UInt64) {
        invalidateTemporaryAttributesCallCount += 1
        lastInvalidatedRange = range
    }
}
#endif
