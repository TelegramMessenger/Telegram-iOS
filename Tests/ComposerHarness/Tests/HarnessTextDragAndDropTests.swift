import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** The engine composer takes part in NO drag and drop: its text view carries no
/// `UIDragInteraction` and no `UIDropInteraction`, and it adopts neither `UITextDraggable` nor
/// `UITextDroppable`. So a selected word cannot be long-pressed and dragged to move it within the
/// message, a formatted run or a link cannot be dragged into a quote, and text or an image dragged in
/// from another app (Safari, Notes, Photos — split view on iPad, or a held drag on iPhone) cannot be
/// dropped into the composer. The legacy composer (`ChatInputTextView`, a `UITextView`) has both
/// interactions and an enabled `textDragInteraction` (control below), as a stock `UITextView` does.
///
/// **How it was seen.** p12 roam, 2026-09-24 (drag and drop within the editor): a hosted probe listed the
/// engine view's interactions — edit menu, context menu, selection, refinement, keyboard and
/// indirect-editable interactions, and no drag or drop. There is nothing to drive.
///
/// **Suspected cause.** `IDBlockTextView` is a `UIScrollView` implementing `UITextInput` with UIKit's
/// private input controller and `UITextInteraction`; UIKit adds text drag and drop only to its own text
/// views, and a custom `UITextInput` has to adopt `UITextDraggable` / `UITextDroppable` (or install
/// `UIDragInteraction` / `UIDropInteraction` itself) and route the drop through the surface gate.
///
/// **Fixed 2026-09-24:** the editor installs its own `UIDragInteraction` / `UIDropInteraction` on the
/// engine view (`RichTextEngineEditorView+DragAndDrop.swift`). The behaviour is pinned by
/// `HarnessTextDropTests` (Tier 1) and `HarnessTextDragUITests` (Tier 2, real touches).
///
/// **Tier 1**: the interactions are read off the live views.
final class HarnessTextDragAndDropTests: XCTestCase {
    private static func interactionNames(of view: UIView) -> [String] {
        return view.interactions.map { String(describing: type(of: $0)) }
    }

    @available(iOS 18.4, *)
    func testTheEngineComposerAcceptsDragAndDrop() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        _ = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText("Drag me"))
        HarnessEngine.settle(root)
        let view = try HarnessEngine.textView(in: root)
        let names = Self.interactionNames(of: view)
        XCTAssertTrue(view is UITextDroppable || view.interactions.contains(where: { $0 is UIDropInteraction }),
                      "the engine composer is not a drop target: \(names)")
        XCTAssertTrue(view is UITextDraggable || view.interactions.contains(where: { $0 is UIDragInteraction }),
                      "the engine composer's text cannot be dragged: \(names)")
    }

    /// Control: the legacy composer's text view has both, and text drag is enabled.
    func testControlLegacyComposerAcceptsDragAndDrop() throws {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        HarnessEngine.settle(root)
        let host = try XCTUnwrap(root.panelHost)
        func find(_ view: UIView) -> UITextView? {
            if let textView = view as? UITextView {
                return textView
            }
            for subview in view.subviews {
                if let found = find(subview) {
                    return found
                }
            }
            return nil
        }
        let textView = try XCTUnwrap(find(host.panel.view), "precondition: no legacy text view")
        XCTAssertTrue(textView.interactions.contains(where: { $0 is UIDropInteraction }), "\(Self.interactionNames(of: textView))")
        XCTAssertTrue(textView.interactions.contains(where: { $0 is UIDragInteraction }), "\(Self.interactionNames(of: textView))")
        XCTAssertEqual(textView.textDragInteraction?.isEnabled, true)
    }
}
