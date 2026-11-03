#if canImport(UIKit)
import UIKit

/// Spelling, grammar, autocorrection, and private checking controllers use transient annotations and
/// rendering attributes. They are neither persisted document content nor backend-owned drawing.
/// Telegram owns their storage and renders the resulting decorations; the backend owns the checking
/// lifecycle that adds and removes them.
///
/// The shared contract treats annotation keys and values as opaque. Private key names, classes, or
/// constants cannot appear in this file family.
///
/// Annotation operations are synchronous, revision-checked, and do not increment the document content
/// revision. The annotation client does not call `UITextInputDelegate` and cannot change canonical
/// selection.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputAnnotationClient: AnyObject {
    func annotatedSubstring(
        in range: NSRange,
        revision: UInt64
    ) -> NSAttributedString?

    func annotationValue(
        for key: AnyHashable,
        at position: RichTextInputPosition,
        revision: UInt64
    ) -> Any?

    @discardableResult
    func addAnnotation(
        key: AnyHashable,
        value: Any,
        range: NSRange,
        revision: UInt64
    ) -> Bool

    @discardableResult
    func removeAnnotation(
        key: AnyHashable,
        range: NSRange,
        revision: UInt64
    ) -> Bool

    @discardableResult
    func addRenderingAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        range: NSRange,
        revision: UInt64
    ) -> Bool

    @discardableResult
    func removeRenderingAttributes(
        _ keys: [NSAttributedString.Key],
        range: NSRange,
        revision: UInt64
    ) -> Bool

    func invalidateTemporaryAttributes(
        in range: NSRange,
        revision: UInt64
    )
}
#endif
