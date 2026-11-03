#if canImport(UIKit)
import UIKit

/// Deliberately empty.
///
/// Its ONLY purpose is to be a distinct concrete class that
/// `TGRichTextInputDecInstallCanvasCallbacks` may `class_addMethod` onto, so that the legacy
/// `DocumentCanvasView` never acquires a private UIKit selector. `class_addMethod` adds to the
/// class it is given and never to a superclass, so this subclass is the whole isolation
/// mechanism (spec: "The ID-specific subclass may contain private callbacks; the legacy class
/// must not acquire them").
///
/// It is Swift, not Objective-C: ObjC source in a separate SwiftPM/Bazel module cannot see
/// `DocumentCanvasView` (no generated `-Swift.h` crosses a target boundary) and
/// `DocumentCanvasView` is internal to `RichTextEditorUIKit`.
@available(iOS 17.0, *)
final class IDDocumentCanvasView: DocumentCanvasView {
}
#endif
