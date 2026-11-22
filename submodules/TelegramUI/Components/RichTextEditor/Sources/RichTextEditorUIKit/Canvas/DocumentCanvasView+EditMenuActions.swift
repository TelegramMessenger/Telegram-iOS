#if canImport(UIKit)
import UIKit
import SwiftUI
import Translation

/// Rich edit-menu items appended to the system `suggestedActions`. A custom UITextInput view that avoids
/// UITextInteraction does NOT get Look Up / Share / a Format submenu for free (those are text-services
/// features of UITextView/UITextInteraction/WebKit/PDFKit), so we add them ourselves and present modals
/// from the owning view controller found via the responder chain. Writing Tools, when the OS surfaces it,
/// rides in `suggestedActions`.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Append our items to the system-suggested actions (which carry Cut/Copy/Paste/Select and, on a
    /// capable device, Writing Tools). iOS 16+ only — the `UIEditMenuInteraction` delegate hook; the iOS
    /// 13–15 `UIMenuController` fallback builds its flat items in DocumentCanvasView+EditMenu.
    @available(iOS 16.0, *)
    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             menuFor configuration: UIEditMenuConfiguration,
                             suggestedActions: [UIMenuElement]) -> UIMenu? {
        if pendingSpellingMenu != nil { return UIMenu(children: spellingGuessMenuElements()) }
        if imageSelection != nil { return nil }   // media atom: no edit menu — Spoiler/Delete live in the host's "•••" media menu; delete is also Backspace on the selected atom
        let defaults = suggestedActions + customEditMenuElements()
        if selFrom < selTo, let provider = hostContextMenuItemsProvider {
            return UIMenu(children: provider(defaults))
        }
        return UIMenu(children: defaults)
    }

    /// Our custom elements for the current selection — empty when the selection is collapsed.
    func customEditMenuElements() -> [UIMenuElement] {
        guard selFrom < selTo else { return [] }
        var elements: [UIMenuElement] = [
            formatMenu(),
            UIAction(title: editMenuStrings.lookUp) { [weak self] _ in self?.presentLookUp() },
        ]
        if #available(iOS 17.4, *) {
            elements.append(UIAction(title: editMenuStrings.translate) { [weak self] _ in self?.presentTranslate() })
        }
        elements.append(UIAction(title: editMenuStrings.share) { [weak self] _ in self?.presentShare() })
        return elements
    }

    private func formatMenu() -> UIMenu {
        UIMenu(title: editMenuStrings.format, identifier: UIMenu.Identifier("org.telegram.RichTextEditor.format"), children: [
            UIAction(title: editMenuStrings.bold) { [weak self] _ in self?.toggleBold() },
            UIAction(title: editMenuStrings.italic) { [weak self] _ in self?.toggleItalic() },
            UIAction(title: editMenuStrings.underline) { [weak self] _ in self?.toggleUnderline() },
        ])
    }

    /// The nearest view controller up the responder chain (to present Look Up / Share / Translate modals).
    func owningViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    /// The selection's plain text (nil when collapsed/empty).
    private func selectedPlainText() -> String? {
        guard selFrom < selTo, let range = selectedTextRange, let t = text(in: range), !t.isEmpty else { return nil }
        return t
    }

    func presentLookUp() {
        guard let term = selectedPlainText(), let vc = owningViewController() else { return }
        vc.present(UIReferenceLibraryViewController(term: term), animated: true)
    }

    func presentTranslate() {
        guard #available(iOS 17.4, *) else { return }
        guard let term = selectedPlainText(), let vc = owningViewController() else { return }
        weak var host: UIViewController?
        let hc = UIHostingController(rootView: TranslatePresenter(text: term) { host?.dismiss(animated: false) })
        host = hc
        hc.view.backgroundColor = .clear
        // The host is invisible; the inner system translate sheet provides its own animation.
        hc.modalPresentationStyle = .overCurrentContext
        vc.present(hc, animated: false)
    }

    func presentShare() {
        guard let term = selectedPlainText(), let vc = owningViewController() else { return }
        let activity = UIActivityViewController(activityItems: [term], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {   // iPad: anchor to the selection
            pop.sourceView = self
            pop.sourceRect = selectionRects(globalFrom: selFrom, globalTo: selTo).first ?? bounds
        }
        vc.present(activity, animated: true)
    }
}

/// A zero-size SwiftUI view that drives the system Translate sheet via `.translationPresentation`, then
/// calls `onClose` when the sheet closes so its UIKit hosting controller can be torn down explicitly
/// (relying on @Environment(\.dismiss) for a UIKit-presented host is not guaranteed). The public
/// Translate API is SwiftUI-only.
@available(iOS 17.4, *)
private struct TranslatePresenter: View {
    let text: String
    let onClose: () -> Void
    @State private var isPresented = true
    var body: some View {
        Color.clear
            .translationPresentation(isPresented: $isPresented, text: text)
            .onChange(of: isPresented) { _, shown in if !shown { onClose() } }
    }
}
#endif
