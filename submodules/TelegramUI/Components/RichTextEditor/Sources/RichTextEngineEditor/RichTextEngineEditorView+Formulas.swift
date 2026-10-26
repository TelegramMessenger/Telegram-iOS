#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-formulas — a formula is an inline atom, and a paragraph holding exactly one is a BLOCK.
///
/// There is no `Block.formula` case and none is wanted: `ParagraphBlock.standaloneFormulaLatex` is
/// the definition, `InstantPageBuilder` promotes such a paragraph to `InstantPageBlock.formula` on
/// send, and Core keeps the test in one place precisely so the spacing classification cannot drift
/// from what is sent.
/// A transparent tap target over a rendered formula.
///
/// A formula is the ONE tappable thing in this editor with no view of its own — the attachment
/// carries the image and draws itself. Everything else has one: a media atom has its host view, a
/// details chevron and a checklist marker are views, and R9-buttons gave both pill kinds theirs. So
/// a formula gets one too, purely to carry a recogniser.
///
/// **LOAD-BEARING: the transparent `contents`.** A layer that renders NOTHING receives no real
/// touches even though `hitTest:` returns it — the project `CLAUDE.md` records this under "iOS
/// 26/27 windows and touch delivery", along with the fact that a near-zero background alpha only
/// works above an undocumented threshold. A test can pin that `contents` is set; only a real tap
/// proves delivery.
@available(iOS 18.4, *)
internal final class EngineFormulaTapTarget: UIView {
    private static let transparentPixel: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        layer.contents = EngineFormulaTapTarget.transparentPixel.cgImage
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The role indices whose ENGINE BLOCK is a standalone formula.
    ///
    /// Legacy's `BlockBox.spacingKind` test, ported: body style, no list, length 1, sole attachment
    /// a `FormulaTextAttachment`. Legacy reads its LAYOUT rather than the model on purpose —
    /// "reaching the model would mean `currentParagraph()`, which re-derives every run from the
    /// attributed string, and this is read on every layout pass for every block" — and this reads
    /// the ENGINE's storage for the same reason.
    ///
    /// **This does not put content in a role.** The structure-only rule forbids a role CARRYING
    /// text, not a pass READING it: the engine's storage is the one copy, read at the moment of
    /// use. The result is a plain `Set<Int>` handed to a pure spacing function, which is what keeps
    /// `EngineBlockSpacing` testable without an engine at all.
    internal func standaloneFormulaRoleIndices() -> Set<Int> {
        let blocks = engine.attributedBlocks
        guard blocks.count == currentRoles.count else { return [] }
        var result: Set<Int> = []
        for index in currentRoles.indices {
            guard currentRoles[index].secondaryKind == nil,
                  let paragraph = currentRoles[index].shape.paragraph,
                  paragraph.style == .body, paragraph.list == nil else { continue }
            let block = blocks[index]
            // A spoilered formula is sent as a paragraph holding it (`standaloneFormulaLatex`, p20), so it
            // takes a paragraph's rhythm here too.
            guard block.length == 1,
                  block.attribute(.attachment, at: 0, effectiveRange: nil) is FormulaTextAttachment,
                  block.attribute(.rtSpoiler, at: 0, effectiveRange: nil) == nil
            else { continue }
            result.insert(index)
        }
        return result
    }

    // MARK: - Authoring

    /// A formula as its own BLOCK — a paragraph whose single run is the formula, which is what
    /// `ParagraphBlock.standaloneFormulaLatex` recognises and `InstantPageBuilder` sends as
    /// `InstantPageBlock.formula`.
    ///
    /// DECIDED 2026-09-09: this diverges from legacy, whose `insertFormula` inserts "one inline
    /// atom" at the caret and reaches a block only when the user happens to leave it alone in a
    /// paragraph. The article editor's own `FormulaEditorScreen` previews the block form.
    ///
    /// NO trailing paragraph is minted, unlike a caption-less media atom or a button row: those are
    /// text-free and leave nowhere to type, while a formula paragraph IS a paragraph. Typing after
    /// the formula turns the block form into an inline one, which is the same fact
    /// `standaloneFormulaLatex` encodes.
    public func insertFormula(latex: String) {
        guard !latex.isEmpty, !currentRoles.isEmpty else { return }
        let selection = engineSelectedRange
        if selection.length > 0 { replaceFlat(selection, with: "") }
        guard roleIndex(atFlatOffset: engineSelectedRange.location) != nil else { return }
        var attributes = CharacterAttributes()
        attributes.formula = latex
        let shape = ParagraphShape(id: BlockID(UUID().uuidString))
        let rendering = bridge.mapper.attributedString(for: ParagraphBlock(
            id: shape.id, style: .body, runs: [TextRun(text: latex, attributes: attributes)]))
        // Through `engineText`, so a newline inside an UN-RENDERED latex source cannot split the
        // block: with no renderer the run's engine text is the source itself.
        let unitText = EngineDocumentBridge.engineText(rendering.string)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                guard let index = roleIndex(atFlatOffset: caret) else { return }
                let ancestry = currentRoles[index].ancestry
                let placement = planAtomUnitPlacement(
                    unitRoles: [.standalone(.paragraph(shape), within: ancestry)],
                    unitText: unitText, at: index, caret: caret)
                replaceFlat(NSRange(location: placement.insertAt, length: 0), with: placement.inserted,
                            adopting: placement.plan)
                // The attachment cannot travel through a text edit, so the rendering's attributes
                // are restored over the inserted characters — the same two-step `insertMedia` uses
                // for a caption and `insertButtonRow` for its atom.
                restoreStyleFlat(NSRange(location: placement.atomStart, length: rendering.length),
                                 from: rendering)
                engineSelectedRange = NSRange(location: placement.atomStart + rendering.length, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// A formula INLINE at the caret, carrying an authored latex — the submenu's "Inline" item.
    ///
    /// Distinct from both neighbours: `insertFormula` makes a block, and
    /// `makeSelectionInlineFormula` takes the selection's own text as the latex rather than one the
    /// host authored. Legacy's single `insertFormula` is this one, which is why its forwarder can be
    /// a one-liner.
    ///
    /// A CODE block takes the latex as PLAIN TEXT, which is legacy's rule kept deliberately: code is
    /// plain by definition, and a rendered atom there would misrepresent what is sent. An ATOM —
    /// a media block or a button row — owns no text region, so it refuses.
    public func insertInlineFormula(latex: String) {
        guard !latex.isEmpty, !currentRoles.isEmpty else { return }
        let selection = engineSelectedRange
        if selection.length > 0 { replaceFlat(selection, with: "") }
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location) else { return }
        guard atomUnitIndex(forRoleAt: index) != index else { return }
        let role = currentRoles[index]
        if case .code = role.shape {
            deliveringOneChangeNotification {
                performHostStructuralEdit {
                    let caret = engineSelectedRange.location
                    replaceFlat(NSRange(location: caret, length: 0),
                                with: EngineDocumentBridge.engineText(latex))
                    engineSelectedRange = NSRange(location: caret + (latex as NSString).length, length: 0)
                }
            }
            setNeedsLayout()
            return
        }
        var attributes = CharacterAttributes()
        attributes.formula = latex
        let rendering = bridge.mapper.attributedString(for: ParagraphBlock(
            id: role.containerID, style: role.shape.paragraph?.style ?? .body,
            runs: [TextRun(text: latex, attributes: attributes)]))
        let inserted = EngineDocumentBridge.engineText(rendering.string)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                replaceFlat(NSRange(location: caret, length: 0), with: inserted)
                restoreStyleFlat(NSRange(location: caret, length: rendering.length), from: rendering)
                engineSelectedRange = NSRange(location: caret + rendering.length, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// Turns the selection into ONE inline formula whose latex is the selected text — the mirror of
    /// `makeSelectionInlineButton`, which takes the selection as a pill's label.
    ///
    /// Clamped to the caret's own block: a selection spanning blocks has no single run to become,
    /// which is the same constraint the button verb takes.
    public func makeSelectionInlineFormula() {
        let selection = engineSelectedRange
        guard selection.length > 0, let index = roleIndex(atFlatOffset: selection.location) else { return }
        let role = currentRoles[index]
        let start = flatOffset(ofRoleAt: index)
        let available = flatLength(ofRoleAt: index) - (selection.location - start)
        let local = NSRange(location: selection.location - start, length: min(selection.length, available))
        guard local.length > 0 else { return }
        let latex = (engine.attributedBlocks[index].string as NSString).substring(with: local)
        guard !latex.isEmpty else { return }
        var attributes = CharacterAttributes()
        attributes.formula = latex
        let rendering = bridge.mapper.attributedString(for: ParagraphBlock(
            id: role.containerID, style: role.shape.paragraph?.style ?? .body,
            runs: [TextRun(text: latex, attributes: attributes)]))
        let replacement = EngineDocumentBridge.engineText(rendering.string)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(NSRange(location: selection.location, length: local.length), with: replacement)
                restoreStyleFlat(NSRange(location: selection.location, length: rendering.length),
                                 from: rendering)
                engineSelectedRange = NSRange(location: selection.location + rendering.length, length: 0)
            }
        }
        setNeedsLayout()
    }

    // MARK: - Tap to edit

    internal struct FormulaOccurrence {
        let latex: String
        let offset: Int
        let roleIndex: Int
    }

    internal func formulaOccurrences() -> [FormulaOccurrence] {
        var result: [FormulaOccurrence] = []
        var blockStart = 0
        for (index, block) in engine.attributedBlocks.enumerated() {
            block.enumerateAttribute(.attachment, in: NSRange(location: 0, length: block.length),
                                     options: []) { value, range, _ in
                guard let attachment = value as? FormulaTextAttachment else { return }
                result.append(FormulaOccurrence(latex: attachment.latex,
                                                offset: blockStart + range.location, roleIndex: index))
            }
            blockStart += block.length + 1
        }
        return result
    }

    /// Reconciles tap targets against the laid-out document. Idempotent; runs after layout.
    internal func syncFormulaTapTargets() {
        let occurrences = formulaOccurrences()
        guard !occurrences.isEmpty || !formulaTapTargets.isEmpty else { return }
        var live: Set<Int> = []
        for occurrence in occurrences {
            let frame = engine.id_attachmentFrame(forCanonicalOffset: UInt(occurrence.offset))
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }
            live.insert(occurrence.offset)
            let view: EngineFormulaTapTarget
            if let existing = formulaTapTargets[occurrence.offset] {
                view = existing
            } else {
                let fresh = EngineFormulaTapTarget()
                fresh.addGestureRecognizer(
                    gatedTapRecognizer(action: #selector(handleFormulaTap(_:))))
                formulaTapTargets[occurrence.offset] = fresh
                view = fresh
            }
            guard let placement = attachmentOverlayPlacement(canonicalOffset: occurrence.offset,
                                                             roleIndex: occurrence.roleIndex) else { continue }
            if view.superview !== placement.host { view.removeFromSuperview(); placement.host.addSubview(view) }
            view.frame = placement.frame
        }
        for (offset, view) in formulaTapTargets where !live.contains(offset) {
            view.removeFromSuperview()
            formulaTapTargets[offset] = nil
        }
    }

    /// The recogniser's entry point. Resolved in the ENGINE's space, because the frames compared
    /// below live there.
    @objc internal func handleFormulaTap(_ recognizer: UITapGestureRecognizer) {
        _ = handleFormulaTapIfNeeded(atPointInEngine: recognizer.location(in: engine))
    }

    internal func handleFormulaTapIfNeeded(atPointInEngine point: CGPoint) -> Bool {
        guard let edit = deferredConfiguration.onEditFormulaRequested else { return false }
        for occurrence in formulaOccurrences() {
            guard let view = formulaTapTargets[occurrence.offset], view.frame.contains(point) else { continue }
            edit(occurrence.latex) { [weak self] updated in
                self?.replaceFormula(atCanonicalOffset: occurrence.offset, with: updated)
            }
            return true
        }
        return false
    }

    /// Replaces one formula's run with a re-rendered one. An EMPTY latex is refused rather than
    /// removing the formula — legacy's `replaceFormula` refuses the same way, and the host's editor
    /// is what offers deletion.
    internal func replaceFormula(atCanonicalOffset offset: Int, with latex: String) {
        guard !latex.isEmpty, let index = roleIndex(atFlatOffset: offset) else { return }
        let role = currentRoles[index]
        var attributes = CharacterAttributes()
        attributes.formula = latex
        let rendering = bridge.mapper.attributedString(for: ParagraphBlock(
            id: role.containerID, style: role.shape.paragraph?.style ?? .body,
            runs: [TextRun(text: latex, attributes: attributes)]))
        let replacement = EngineDocumentBridge.engineText(rendering.string)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(NSRange(location: offset, length: 1), with: replacement)
                restoreStyleFlat(NSRange(location: offset, length: rendering.length), from: rendering)
            }
        }
        setNeedsLayout()
    }
}
#endif
