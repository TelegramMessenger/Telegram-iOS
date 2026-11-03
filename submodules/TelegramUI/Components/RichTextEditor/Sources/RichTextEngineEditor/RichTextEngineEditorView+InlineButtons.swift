#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-buttons — inline `textButton` pills.
///
/// The shared `AttributedStringMapper` has always emitted a `ButtonTextAttachment` for one of these,
/// and that attachment carries a 1×1 spacer image and draws nothing: the legacy canvas draws the
/// pill with a hosted `ButtonPillView`. The engine hosted views for media atoms and custom emoji and
/// for nothing else, so until this file an inline button was a blank gap of exactly the right size.
///
/// Modelled on `syncCustomEmojiViews`, including the two things that pass learned the hard way: the
/// ATTACHMENT's frame rather than a selection rect (a selection rect is the line's height), and the
/// ENGINE as the parent, because that frame is in its content space.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal struct InlineButtonOccurrence {
        let attachment: ButtonTextAttachment
        let offset: Int
        let length: Int
        let roleIndex: Int
    }

    /// Every INLINE pill in the document, with its canonical offset. A block row's pills are not
    /// here: they are `RichTextButtonRowView` subviews, and `isBlockPill` is what tells them apart.
    internal func inlineButtonOccurrences() -> [InlineButtonOccurrence] {
        var result: [InlineButtonOccurrence] = []
        var blockStart = 0
        for (index, block) in engine.attributedBlocks.enumerated() {
            let whole = NSRange(location: 0, length: block.length)
            block.enumerateAttribute(.attachment, in: whole, options: []) { value, range, _ in
                guard let attachment = value as? ButtonTextAttachment, !attachment.isBlockPill else { return }
                result.append(InlineButtonOccurrence(attachment: attachment,
                                                     offset: blockStart + range.location,
                                                     length: range.length, roleIndex: index))
            }
            blockStart += block.length + 1
        }
        return result
    }

    /// Reconciles hosted inline pills against the laid-out document. Idempotent; runs after layout.
    internal func syncInlineButtonPills() {
        let occurrences = inlineButtonOccurrences()
        guard !occurrences.isEmpty || !inlineButtonPillViews.isEmpty else { return }

        var live: Set<Int> = []
        for occurrence in occurrences {
            let frame = engine.id_attachmentFrame(forCanonicalOffset: UInt(occurrence.offset))
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }
            live.insert(occurrence.offset)

            let view: RichTextButtonPillView
            if let existing = inlineButtonPillViews[occurrence.offset] {
                view = existing
            } else {
                let fresh = RichTextButtonPillView()
                // Its OWN recogniser, like the row view's and for the same reason: routing this
                // through `textInteractionMayBegin` would fire on touch-DOWN, so a drag that merely
                // began on a pill would open the host's edit sheet, and a query would side-effect.
                // A pill that takes its own touch also keeps the caret off itself without a second
                // rule — UIKit never consults the text hook for a touch this view swallowed.
                fresh.isUserInteractionEnabled = true
                fresh.addGestureRecognizer(
                    gatedTapRecognizer(action: #selector(handleInlineButtonTap(_:))))
                engine.addSubview(fresh)
                inlineButtonPillViews[occurrence.offset] = fresh
                view = fresh
            }
            guard let placement = attachmentOverlayPlacement(canonicalOffset: occurrence.offset,
                                                             roleIndex: occurrence.roleIndex) else { continue }
            if view.superview !== placement.host { view.removeFromSuperview(); placement.host.addSubview(view) }
            view.frame = placement.frame
            view.update(attachment: occurrence.attachment,
                        metrics: bridge.mapper.styleSheet.metrics.button,
                        emojiProvider: deferredConfiguration.emojiViewProvider)
            // A spoiler hides TEXT with a foreground colour, which does nothing to a hosted view —
            // the pill would sit fully visible behind the dust, leaking exactly what the spoiler
            // exists to conceal. Legacy has this bug today. Same reveal rule as the text hide, the
            // dust and the emoji pass, so the four cannot disagree.
            view.isHidden = isInsideHiddenSpoiler(NSRange(location: occurrence.offset,
                                                          length: occurrence.length))
        }

        for (offset, view) in inlineButtonPillViews where !live.contains(offset) {
            view.removeFromSuperview()
            inlineButtonPillViews[offset] = nil
        }
    }

    // MARK: - Authoring

    /// Turns the selection into one inline pill carrying its text as the label.
    ///
    /// The label lives INSIDE the button rather than being the carrying run's text: a button is an
    /// atom in every text-shaping helper the InstantPage renderer has, and making the label flow
    /// text would put a caret inside a pill.
    public func makeSelectionInlineButton() {
        let selection = engineSelectedRange
        guard selection.length > 0, let index = roleIndex(atFlatOffset: selection.location) else { return }
        let role = currentRoles[index]
        let start = flatOffset(ofRoleAt: index)
        let available = flatLength(ofRoleAt: index) - (selection.location - start)
        let local = NSRange(location: selection.location - start, length: min(selection.length, available))
        guard local.length > 0 else { return }
        let text = (engine.attributedBlocks[index].string as NSString).substring(with: local)
        var attributes = CharacterAttributes()
        attributes.button = ButtonRef(label: [TextRun(text: text)], action: .url(""))
        let pill = bridge.mapper.attributedString(for: ParagraphBlock(
            id: role.containerID, style: role.shape.paragraph?.style ?? .body,
            runs: [TextRun(text: "\u{FFFC}", attributes: attributes)]))
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(NSRange(location: selection.location, length: local.length), with: "\u{FFFC}")
                restoreStyleFlat(NSRange(location: selection.location, length: 1), from: pill)
                engineSelectedRange = NSRange(location: selection.location + 1, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// Inserts ONE inline pill carrying `button` at the caret, replacing any selection — the Add
    /// menu's "Button ▸ Inline", whose label the host authored in its sheet first. The mirror of
    /// `insertInlineFormula`: inside a CODE block the label is plain text (code is plain by
    /// definition, and a pill there would misrepresent what is sent); an ATOM — a media block or a
    /// button row — owns no text region, so it refuses. A table cell is a paragraph like any other.
    public func insertInlineButton(_ button: ButtonRef) {
        guard !currentRoles.isEmpty else { return }
        let selection = engineSelectedRange
        guard let index = roleIndex(atFlatOffset: selection.location) else { return }
        guard atomUnitIndex(forRoleAt: index) != index else { return }
        let role = currentRoles[index]
        if case .code = role.shape {
            let label = EngineDocumentBridge.engineText(button.labelText)
            guard !label.isEmpty else { return }
            deliveringOneChangeNotification {
                performHostStructuralEdit {
                    replaceFlat(selection, with: label)
                    engineSelectedRange = NSRange(location: selection.location + (label as NSString).length, length: 0)
                }
            }
            setNeedsLayout()
            return
        }
        var attributes = CharacterAttributes()
        attributes.button = button
        let pill = bridge.mapper.attributedString(for: ParagraphBlock(
            id: role.containerID, style: role.shape.paragraph?.style ?? .body,
            runs: [TextRun(text: "\u{FFFC}", attributes: attributes)]))
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(selection, with: "\u{FFFC}")
                // The attachment cannot travel through a text edit: restored over the atom, as
                // `makeSelectionInlineButton` does.
                restoreStyleFlat(NSRange(location: selection.location, length: 1), from: pill)
                engineSelectedRange = NSRange(location: selection.location + 1, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// Replaces one inline pill; `nil` removes it, leaving the label's plain text behind — the
    /// honest inverse of `makeSelectionInlineButton`.
    internal func replaceInlineButton(atCanonicalOffset offset: Int, with button: ButtonRef?) {
        guard let index = roleIndex(atFlatOffset: offset) else { return }
        let role = currentRoles[index]
        let blockStart = flatOffset(ofRoleAt: index)
        let existing = engine.attributedBlocks[index]
            .attribute(.attachment, at: offset - blockStart, effectiveRange: nil) as? ButtonTextAttachment
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                guard let button else {
                    replaceFlat(NSRange(location: offset, length: 1), with: existing?.button.labelText ?? "")
                    return
                }
                var attributes = CharacterAttributes()
                attributes.button = button
                let pill = bridge.mapper.attributedString(for: ParagraphBlock(
                    id: role.containerID, style: role.shape.paragraph?.style ?? .body,
                    runs: [TextRun(text: "\u{FFFC}", attributes: attributes)]))
                restoreStyleFlat(NSRange(location: offset, length: 1), from: pill)
            }
        }
        setNeedsLayout()
    }

    // MARK: - Tap routing

    /// The recogniser's entry point. Resolved in the ENGINE's space, like the row's, because the
    /// pill frames compared below live there.
    @objc internal func handleInlineButtonTap(_ recognizer: UITapGestureRecognizer) {
        _ = handleInlineButtonTapIfNeeded(atPointInEngine: recognizer.location(in: engine))
    }

    /// A tap on an inline pill, mirroring the row's. A block pill lives inside a row view and an
    /// inline one does not, so the two never contend for a touch.
    internal func handleInlineButtonTapIfNeeded(atPointInEngine point: CGPoint) -> Bool {
        guard let edit = deferredConfiguration.onEditButtonRequested else { return false }
        for occurrence in inlineButtonOccurrences() {
            guard let view = inlineButtonPillViews[occurrence.offset], !view.isHidden,
                  view.frame.contains(point) else { continue }
            edit(occurrence.attachment.button, false) { [weak self] updated in
                self?.replaceInlineButton(atCanonicalOffset: occurrence.offset, with: updated)
            }
            return true
        }
        return false
    }
}
#endif
