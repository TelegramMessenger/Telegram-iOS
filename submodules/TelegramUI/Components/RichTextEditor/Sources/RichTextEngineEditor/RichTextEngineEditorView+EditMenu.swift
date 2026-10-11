#if canImport(UIKit)
import UIKit

/// Edit-menu support for the engine editor.
///
/// WHY THIS FILE EXISTS. The engine is a custom `UITextInput` that deliberately avoids
/// `UITextInteraction`, and the legacy canvas's equivalent file states the consequence outright: such
/// a view "does NOT get Look Up / Share / a Format submenu for free". The engine shipped with none of
/// this — no `UIEditMenuInteraction`, no presentation path, and `contextMenuItemsProvider` stored but
/// never read. The composer handed its Format menu over and the value went nowhere, so links and
/// inline code were fully implemented and **unreachable from the UI**.
///
/// CONTENT IS SEPARATED FROM PRESENTATION, deliberately. A presented `UIEditMenuInteraction` cannot
/// be driven or observed from a unit test; the assembly of what goes IN it can. `editMenuElements`
/// is therefore a plain function over `suggestedActions`, and the delegate below is a thin wrapper.
/// The legacy canvas splits it the same way and for the same reason.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The elements the edit menu should show, given the system's own suggestions.
    ///
    /// The host is handed the defaults and returns a SUPERSET — it never replaces them, so Cut/Copy/
    /// Paste survive. Gated on a non-collapsed selection: a bare caret is not a formatting target, and
    /// the legacy canvas gates its custom items on exactly the same condition.
    internal func editMenuElements(suggestedActions: [UIMenuElement]) -> [UIMenuElement] {
        guard hasNonEmptySelection, let provider = contextMenuItemsProvider else {
            return suggestedActions
        }
        return provider(suggestedActions)
    }

    internal var hasNonEmptySelection: Bool {
        guard let range = engine.selectedTextRange else { return false }
        return !range.isEmpty
    }

    /// Installs the menu-content provider on the engine.
    ///
    /// NOT a `UIEditMenuInteraction`. The first implementation attached one to the engine view and
    /// implemented `UIEditMenuInteractionDelegate` — it compiled, its content assembly was unit
    /// tested, and it did nothing at all, because UIKit's private `UITextInteractionAssistant`
    /// presents this menu itself and never consults a host-added interaction. That was only
    /// established by returning a marker item unconditionally from the delegate and watching it fail
    /// to appear on device; no amount of reading the code would have shown it.
    internal func installEditMenuProvider() {
        engine.tgid_editMenuElementsProvider = { [weak self] suggestedActions in
            guard let self else { return suggestedActions }
            return self.editMenuElements(suggestedActions: suggestedActions)
        }
    }

    /// The selection's union in engine coordinates — what the menu must not cover.
    internal func editMenuTargetRect() -> CGRect {
        guard let range = engine.selectedTextRange else { return .zero }
        let rects = engine.selectionRects(for: range).map(\.rect)
        let union = rects.reduce(CGRect.null) { $0.union($1) }
        return union.isNull ? engine.caretRect(for: range.start) : union
    }
}

#endif
