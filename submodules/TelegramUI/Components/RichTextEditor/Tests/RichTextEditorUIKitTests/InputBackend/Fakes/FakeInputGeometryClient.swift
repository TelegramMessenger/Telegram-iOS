#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

/// Every query method funnels into the log's single `.geometryQuery(kind:revision:purpose:)` case —
/// there is no per-method Event case, so `kind` (the method name) is what a test greps for. Each
/// method's return value is a settable stored property, mirroring `FakeInputDocumentClient`'s shape.
@MainActor
@available(iOS 16.0, *)
final class FakeInputGeometryClient: RichTextInputGeometryClient {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    var layoutGeneration: UInt64 = 1

    var caretGeometryToReturn: RichTextInputCaretGeometry? = nil
    var closestPositionToReturn: RichTextInputPosition? = nil
    var characterRangeToReturn: NSRange? = nil
    var lineRangeToReturn: (range: NSRange, resolvedAffinity: RichTextInputAffinity)? = nil
    var navigateResultToReturn: RichTextInputNavigationResult? = nil
    var firstRectToReturn: CGRect? = nil
    var selectionSegmentsToReturn: [RichTextInputSelectionSegment]? = nil
    var baseWritingDirectionToReturn: RichTextInputWritingDirection = .leftToRight

    private(set) var callCounts: [String: Int] = [:]
    private func bump(_ kind: String) { callCounts[kind, default: 0] += 1 }

    func caretGeometry(at position: RichTextInputPosition, revision: UInt64,
                       purpose: RichTextInputGeometryPurpose) -> RichTextInputCaretGeometry? {
        bump("caretGeometry")
        log.record(.geometryQuery(kind: "caretGeometry", revision: revision, purpose: "\(purpose)"))
        return caretGeometryToReturn
    }
    func closestPosition(to point: CGPoint, within range: NSRange?, revision: UInt64,
                        purpose: RichTextInputGeometryPurpose) -> RichTextInputPosition? {
        bump("closestPosition")
        log.record(.geometryQuery(kind: "closestPosition", revision: revision, purpose: "\(purpose)"))
        return closestPositionToReturn
    }
    func characterRange(at point: CGPoint, revision: UInt64) -> NSRange? {
        bump("characterRange")
        log.record(.geometryQuery(kind: "characterRange", revision: revision, purpose: "n/a"))
        return characterRangeToReturn
    }
    func lineRange(enclosing position: RichTextInputPosition,
                  revision: UInt64) -> (range: NSRange, resolvedAffinity: RichTextInputAffinity)? {
        bump("lineRange")
        log.record(.geometryQuery(kind: "lineRange", revision: revision, purpose: "n/a"))
        return lineRangeToReturn
    }
    func navigate(from position: RichTextInputPosition, direction: RichTextInputLayoutDirection,
                 offset: Int, anchorPositionOffset: CGFloat?,
                 revision: UInt64) -> RichTextInputNavigationResult? {
        bump("navigate")
        log.record(.geometryQuery(kind: "navigate", revision: revision, purpose: "n/a"))
        return navigateResultToReturn
    }
    func firstRect(for range: NSRange, revision: UInt64,
                  purpose: RichTextInputGeometryPurpose) -> CGRect? {
        bump("firstRect")
        log.record(.geometryQuery(kind: "firstRect", revision: revision, purpose: "\(purpose)"))
        return firstRectToReturn
    }
    func selectionSegments(for request: RichTextInputSelectionGeometryRequest,
                          revision: UInt64) -> [RichTextInputSelectionSegment]? {
        bump("selectionSegments")
        log.record(.geometryQuery(kind: "selectionSegments", revision: revision, purpose: "\(request.purpose)"))
        return selectionSegmentsToReturn
    }
    func baseWritingDirection(at position: RichTextInputPosition,
                             revision: UInt64) -> RichTextInputWritingDirection {
        bump("baseWritingDirection")
        log.record(.geometryQuery(kind: "baseWritingDirection", revision: revision, purpose: "n/a"))
        return baseWritingDirectionToReturn
    }
}
#endif
