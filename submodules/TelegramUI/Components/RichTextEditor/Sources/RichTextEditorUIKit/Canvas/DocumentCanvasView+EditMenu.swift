#if canImport(UIKit)
import UIKit

/// A minimal pasteboard seam so copy/cut/paste are unit-testable with a fake — the simulator's
/// UIPasteboard.general can be unauthorized and hang on reads. Production uses UIPasteboard.general.
protocol TextPasteboard: AnyObject {
    var string: String? { get set }
    var hasStrings: Bool { get }
    func data(forPasteboardType type: String) -> Data?
    func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any])
    func contains(pasteboardTypes: [String]) -> Bool
}
extension UIPasteboard: TextPasteboard {}

/// The system edit menu + the responder actions that populate it. On iOS 16+ the menu is presented via
/// `UIEditMenuInteraction` (install + delegate live in the gated extension below); on iOS 13–15 it falls
/// back to the deprecated `UIMenuController`. The responder actions (Select/Copy/Cut/Paste + the custom
/// Bold/Italic/Underline/Look Up/Share) are SHARED — only the presentation differs. Presentation is
/// gesture-driven (see DocumentCanvasView+Interaction).
extension DocumentCanvasView {
    /// How far the edit-menu target rect grows above/below a text selection so the menu clears the round
    /// selection-handle knobs (the OS draws them a few points beyond the first/last line). Tuned visually.
    static let selectionHandleAllowance: CGFloat = 12

    /// The content the edit menu must not obscure, in canvas coordinates: a structurally-selected table
    /// row/column, else the selection union, else the image atom at a gap caret, else the collapsed caret.
    func editMenuContentRect() -> CGRect {
        if let outline = tableSelectionOutlineRect() { return outline }
        if selFrom != selTo {
            let union = selectionRects(globalFrom: selFrom, globalTo: selTo)
                .reduce(CGRect.null) { $0.union($1) }
            if !union.isNull { return union }
        }
        if let img = mediaBox(atGap: head) { return img.mediaRect() }
        return caretRect(atGlobal: head)
    }

    /// The rect the menu lays out AROUND — the content rect grown to clear the drag handles for a
    /// non-collapsed TEXT selection; a caret/image/structural-table pick has no text handles, so unpadded.
    func editMenuTargetRect() -> CGRect {
        let content = editMenuContentRect()
        if selFrom != selTo, tableSelection == nil {
            return content.insetBy(dx: 0, dy: -Self.selectionHandleAllowance)
        }
        return content
    }

    /// Present the system menu, anchored at the top-center of the content rect. iOS 16+ uses
    /// `UIEditMenuInteraction` (it lays out around `targetRectFor`); below 16, `UIMenuController`.
    func presentEditMenu() {
        // TASK 30 test seam, mirroring `dismissEditMenuCountForTesting` exactly (same shape, same
        // reason — a presented `UIEditMenuInteraction` cannot be driven or observed from a unit test,
        // and BOTH of this method's real effects are unreachable there: `isFirstResponder` is false
        // for an unhosted canvas and `editMenuInteraction` is nil until `installEditMenuInteraction()`
        // runs). Counted BEFORE the guard, deliberately: what a test needs to see is that the
        // ATTEMPT happened, which is the fact routing could delete. `CommandRouterTests
        // .test_select_stillPresentsTheEditMenu_whichTheCommandClientRouteWouldHaveDropped` is why
        // this exists.
        presentEditMenuCountForTesting += 1
        guard isFirstResponder else { return }
        let rect = editMenuContentRect()
        if #available(iOS 16.0, *) {
            guard let interaction = editMenuInteraction else { return }
            let cfg = UIEditMenuConfiguration(identifier: nil, sourcePoint: CGPoint(x: rect.midX, y: rect.minY))
            interaction.presentEditMenu(with: cfg)
        } else {
            presentLegacyEditMenu(targetRect: editMenuTargetRect())
        }
    }

    func dismissEditMenu() {
        dismissEditMenuCountForTesting += 1
        if #available(iOS 16.0, *) {
            editMenuInteraction?.dismissMenu()
        } else {
            UIMenuController.shared.hideMenu()
            editMenuVisible = false
        }
    }

    /// Native UITextView dismisses the edit menu the moment the text or the caret/selection changes.
    /// Called from the selection setters, the `selectedTextRange` setter, and the `editing { }` wrapper.
    /// UNCONDITIONAL (not gated on `editMenuVisible`) — see the long note that previously lived here:
    /// a presented menu does not self-dismiss on a selection change, and the system clears `editMenuVisible`
    /// on touch-down before the gesture's setter runs. `dismissMenu()`/`hideMenu()` is a no-op when nothing
    /// is presented.
    func dismissEditMenuForSelectionOrTextChange() {
        pendingSpellingMenu = nil
        dismissEditMenu()
    }

    /// TASK 30 (Family 7) — the ONE witness in the whole of Phase 4 that is not a bare
    /// `inputBackend.…` one-liner, and the deviation is the spec's own "translate a UIKit-required
    /// representation difference": UIKit asks in `Selector`s, the seam speaks `RichTextInputCommand`.
    /// `richTextInputCommand(for:)` (`Clients/TelegramCommandInputClient.swift`, Task 19) is that
    /// translation — a pure function with its own tests — and it maps exactly SIX selectors
    /// (`copy:`/`cut:`/`paste:`/`select:`/`selectAll:`/`delete:`). Everything it does not map keeps its
    /// existing handling verbatim, which is what the two cases below are: the five custom
    /// `UIMenuItem` actions of the iOS 13-15 `UIMenuController` fallback, and the six spelling-menu
    /// actions. Everything else still goes to `super`, exactly as before.
    ///
    /// **`delete(_:)` is a disclosed axis-4 divergence, and the only one this witness has.** It was
    /// never a `case` here, so it fell to `super` — which, because the canvas implements no `delete(_:)`
    /// responder action, **consults the NEXT RESPONDER and answers `false` for every chain this package
    /// can produce**. `richTextInputCommand(for:)` DOES map it, so it now asks the backend, which asks
    /// the command client, which makes `.delete` unconditionally unavailable — also `false`. Same
    /// answer, different decider. Filed rather than repaired, per the Phase-4 rule for stage-1
    /// divergences.
    ///
    /// **FIX ROUND 1 (Min-8): the chain clause is new, and it is the half that was missing.** This
    /// comment (and the command client's copy of the same argument, and the Task-30 coordinator
    /// supplement §5) said `super` answers `false` "because the canvas implements no `delete(_:)`",
    /// full stop. `UIResponder.canPerformAction(_:withSender:)`'s default returns `true` if the RECEIVER
    /// implements the action and **otherwise asks the next responder**, so the pre-seam answer was the
    /// responder CHAIN's, not the canvas's — `false` in a unit test (nil next responder) and, in the
    /// app, dependent on whatever sits above `DocumentCanvasView`. Nothing in Telegram's chain plausibly
    /// implements `delete:`, and the new unconditional `false` is if anything SAFER (the old
    /// composition could have made the canvas the `target(forAction:)` for an action it cannot
    /// perform). Stated this way so nobody later "verifies" the disclosure by re-reading the canvas
    /// alone.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if let command = richTextInputCommand(for: action) {
            return inputBackend.canPerformCommand(command, sender: sender)
        }
        switch action {
        case #selector(legacyBold), #selector(legacyItalic), #selector(legacyUnderline),
             #selector(legacyLookUp), #selector(legacyShare):
            // The custom items of the UIMenuController (iOS 13–15) fallback — a non-collapsed selection only.
            return selFrom < selTo
        case #selector(spellGuess0), #selector(spellGuess1), #selector(spellGuess2),
             #selector(spellGuess3), #selector(spellNoop), #selector(spellRevert):
            return pendingSpellingMenu != nil
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    // TASK 30 (Family 7): one-line router. See `legacySelect(_:)` just below for the body.
    @objc override func select(_ sender: Any?) { inputBackend.performCommand(.selectWord, sender: sender) }

    /// Was `DocumentCanvasView.select(_:)`, renamed by TASK 30; the body is untouched.
    ///
    /// **The `presentEditMenu()` line is why `performCommand` forwards HERE rather than through the
    /// command client** (whose `.selectWord` commit case is `canvas.selectWord(at: canvas.head)` —
    /// the first line only). Routing this witness through that client would have silently deleted the
    /// menu re-presentation, with no compiler error and, before this task, no test that could see it.
    /// Pinned now by `CommandRouterTests
    /// .test_select_stillPresentsTheEditMenu_whichTheCommandClientRouteWouldHaveDropped`.
    @objc func legacySelect(_ sender: Any?) {
        selectWord(at: head)
        presentEditMenu()
    }

    // TASK 30 (Family 7): one-line router. See `legacySelectAll(_:)` just below for the body.
    @objc override func selectAll(_ sender: Any?) { inputBackend.performCommand(.selectAll, sender: sender) }

    /// Was `DocumentCanvasView.selectAll(_:)`, renamed by TASK 30; the body is untouched. Same
    /// `presentEditMenu()` reasoning as `legacySelect(_:)` above, plus a second one specific to this
    /// member: the client's `canPerform(.selectAll)` gate REJECTS when everything is already selected,
    /// where this body re-selects and re-presents the menu. A programmatic `selectAll(nil)` — which
    /// several in-tree tests make — would have started no-op'ing.
    @objc func legacySelectAll(_ sender: Any?) {
        selectAllText()
        presentEditMenu()
    }

    // MARK: - Legacy UIMenuController fallback (iOS 13–15)

    /// Presents the deprecated `UIMenuController`. Standard Cut/Copy/Paste/Select/Select All surface
    /// automatically from `canPerformAction`; the custom items (Format toggles + Look Up + Share) are added
    /// as flat `UIMenuItem`s (UIMenuController has no submenus, so the iOS-16+ "Format" submenu is flattened).
    /// `Translate` is iOS 17.4+, so it never appears on this path. Reuses the shared responder actions.
    private func presentLegacyEditMenu(targetRect: CGRect) {
        let mc = UIMenuController.shared
        mc.menuItems = pendingSpellingMenu != nil ? legacySpellingMenuItems() : legacyCustomMenuItems()
        mc.showMenu(from: self, rect: targetRect)
        editMenuVisible = true
    }

    private func legacyCustomMenuItems() -> [UIMenuItem] {
        guard selFrom < selTo else { return [] }
        return [
            UIMenuItem(title: editMenuStrings.bold, action: #selector(legacyBold)),
            UIMenuItem(title: editMenuStrings.italic, action: #selector(legacyItalic)),
            UIMenuItem(title: editMenuStrings.underline, action: #selector(legacyUnderline)),
            UIMenuItem(title: editMenuStrings.lookUp, action: #selector(legacyLookUp)),
            UIMenuItem(title: editMenuStrings.share, action: #selector(legacyShare)),
        ]
    }

    @objc private func legacyBold() { toggleBold() }
    @objc private func legacyItalic() { toggleItalic() }
    @objc private func legacyUnderline() { toggleUnderline() }
    @objc private func legacyLookUp() { presentLookUp() }
    @objc private func legacyShare() { presentShare() }

    private func legacySpellingMenuItems() -> [UIMenuItem] {
        guard let pending = pendingSpellingMenu else {
            return [UIMenuItem(title: "No Replacements Found", action: #selector(spellNoop))]
        }
        var items: [UIMenuItem] = []
        // N5: a fixed selector (mirrors spellGuess0…3) — UIMenuItem needs an Obj-C #selector, so unlike the
        // iOS-16+ UIAction closure this can't just close over `revertTo`; `spellRevert` re-reads it from
        // `pendingSpellingMenu` at invocation time.
        if pending.revertTo != nil {
            items.append(UIMenuItem(title: "Revert to \u{201C}\(pending.revertTo!)\u{201D}", action: #selector(spellRevert)))
        }
        if pending.guesses.isEmpty {
            items.append(UIMenuItem(title: "No Replacements Found", action: #selector(spellNoop)))
            return items
        }
        let sels: [Selector] = [#selector(spellGuess0), #selector(spellGuess1),
                                #selector(spellGuess2), #selector(spellGuess3)]
        items.append(contentsOf: zip(pending.guesses.prefix(4), sels).map { UIMenuItem(title: $0.0, action: $0.1) })
        return items
    }
    @objc private func spellNoop() {}
    @objc private func spellRevert() {
        guard let revertTo = pendingSpellingMenu?.revertTo else { return }
        applySpellingReplacement(revertTo)
    }
    @objc private func spellGuess0() { applyLegacyGuess(0) }
    @objc private func spellGuess1() { applyLegacyGuess(1) }
    @objc private func spellGuess2() { applyLegacyGuess(2) }
    @objc private func spellGuess3() { applyLegacyGuess(3) }
    private func applyLegacyGuess(_ i: Int) {
        guard let g = pendingSpellingMenu?.guesses, i < g.count else { return }
        applySpellingReplacement(g[i])
    }
}

/// iOS 16+ system edit menu: the `UIEditMenuInteraction` install + its delegate. Below 16 this whole
/// extension is absent and `presentEditMenu`/`dismissEditMenu` use `UIMenuController` instead.
@available(iOS 16.0, *)
extension DocumentCanvasView {
    func installEditMenuInteraction() {
        guard editMenuInteraction == nil else { return }
        let interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        editMenuInteraction = interaction
    }
}

@available(iOS 16.0, *)
extension DocumentCanvasView: UIEditMenuInteractionDelegate {
    /// Returning the content rect makes the menu present AROUND it (the default zero-size rect would let it
    /// overlap the selection + handles). Recomputed each call (the system re-invokes on layout changes).
    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        editMenuTargetRect()
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             willPresentMenuFor configuration: UIEditMenuConfiguration,
                             animator: UIEditMenuInteractionAnimating) {
        editMenuVisible = true
    }
    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             willDismissMenuFor configuration: UIEditMenuConfiguration,
                             animator: UIEditMenuInteractionAnimating) {
        editMenuVisible = false
        lastMenuDismissTime = Date().timeIntervalSinceReferenceDate
    }
}
#endif
