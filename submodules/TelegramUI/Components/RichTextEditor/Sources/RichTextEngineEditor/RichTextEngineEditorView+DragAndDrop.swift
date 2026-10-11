#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
import RichTextEditorCore
import RichTextEditorUIKit

/// **Text drag and drop, which the engine does not provide.**
///
/// A `UITextView` gets both halves from UIKit's private `UITextDragInteraction` /
/// `UITextDropInteraction`; the engine view is a custom `UITextInput` whose `UITextInteraction`
/// installs neither, and adopting `UITextDraggable` / `UITextDroppable` alone changes nothing (those
/// protocols describe the private interactions, they do not install them). So this editor installs a
/// plain `UIDragInteraction` and `UIDropInteraction` on the engine view and answers them itself
/// (composer harness, p12, `HarnessTextDragAndDropTests`).
///
/// **Drag.** A long press INSIDE a non-empty selection lifts it. The item carries the editor's
/// fragment (`RichTextEditorClipboard.fragmentUTI`, visible to this process only), RTF and plain text
/// — the clipboard's three representations — so a drag out to another app gives text. The lift
/// preview is the selection's own line rects.
///
/// **Gesture arbitration, UITextView's rule.** A long press inside the selection is the drag's; a long
/// press anywhere else is the loupe's, exactly as before. The text interaction's long-press
/// recognizers (the loupe) are refused for a touch inside the selection
/// (`tgid_shouldBeginGestureRecognizerHandler`), and the drag answers no items for a touch outside it,
/// so the two never compete for one touch. Taps, the selection handles, the table knobs and the scroll
/// pan are not long presses and are untouched.
///
/// **Drop.** A drop is a PASTE at the drop point, read from the drop session instead of the clipboard
/// (`EnginePasteSource`), so the user's clipboard is never read or written. It runs the same handlers
/// in the same order — a one-line field takes plain text with newlines as spaces, a fragment splices
/// through `Document.replacingRange`, markdown is parsed — and plain text goes in through the gated
/// `replaceRange:withText:` surface in place of the engine's pasteboard-reading `paste:`.
///
/// **A local move IS Cut + Paste, as one undo step** (`performLocalMove`, composer harness p19). The
/// drag lifts what a copy of the selection takes (`clipboardSelection()`), the source is deleted
/// through the surface gate exactly as Cut deletes it, and the lifted content lands at the drop point
/// through the paste's own handlers. It used to be two replacements composed on a `Document`, whose
/// deletion was Core's complement rather than the gate's rule — so the source's halves were not joined
/// across a container — and whose insertion dropped whatever the destination could not hold while
/// the deletion still removed it. A move whose destination cannot hold what it carries is REFUSED
/// (`destinationHolds`): a medium, a table or a row into a caption, a cell or a pull quote; any atom
/// into plain text (a code body, a one-line field). So is a move whose source covers a table only in
/// part, and a drop inside what the move takes away.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal func installDragAndDrop() {
        textDragAndDrop.install(on: engine)
        engine.tgid_shouldBeginGestureRecognizerHandler = { [weak self] recognizer in
            self?.textDragAndDrop.gestureRecognizerMayBegin(recognizer) ?? true
        }
    }

    // MARK: - Geometry

    /// The engine flat offset closest to `point` (engine coordinates).
    internal func flatOffset(closestTo point: CGPoint) -> Int? {
        guard let position = engine.closestPosition(to: point) else { return nil }
        return engine.offset(from: engine.beginningOfDocument, to: position)
    }

    /// The selection's rects in engine coordinates, empty ones dropped.
    internal func selectionRectsForDrag(_ range: NSRange) -> [CGRect] {
        guard range.length > 0,
              let start = engine.position(from: engine.beginningOfDocument, offset: range.location),
              let end = engine.position(from: start, offset: range.length),
              let textRange = engine.textRange(from: start, to: end) else { return [] }
        return engine.selectionRects(for: textRange).map(\.rect).filter { $0.width > 0.5 && $0.height > 0.5 }
    }

    /// Whether a long press at `point` lifts the selection: the editor is focused, nothing is
    /// marked, and the point lies in one of the selection's rects.
    internal func pointLiftsSelection(_ point: CGPoint) -> Bool {
        guard engine.isFirstResponder, engine.markedTextRange == nil else { return false }
        return selectionRectsForDrag(engineSelectedRange).contains { $0.contains(point) }
    }

    // MARK: - Drag

    /// What a drag lifted from the current selection carries, or nil when there is nothing to lift:
    /// what a copy of it takes, and the range a Cut of it deletes (`clipboardSelection()`), so a move
    /// takes away exactly what it carries.
    internal func makeTextDragContext() -> EngineTextDragContext? {
        let selection = engineSelectedRange
        guard selection.length > 0 else { return nil }
        let clipboard = clipboardSelectionWithCoveredText()
        let fragment = clipboard?.fragment ?? Document(blocks: [])
        let source = clipboard?.deletion ?? selection
        var plain: String
        if !fragment.blocks.isEmpty {
            plain = externalChecklistPlainText(fragment.blocks)
        } else {
            guard let start = engine.position(from: engine.beginningOfDocument, offset: source.location),
                  let end = engine.position(from: start, offset: source.length),
                  let textRange = engine.textRange(from: start, to: end) else { return nil }
            plain = (engine.text(in: textRange) ?? "").replacingOccurrences(of: "\u{2028}", with: "\n")
        }
        guard !plain.isEmpty || !fragment.blocks.isEmpty else { return nil }
        let context = EngineTextDragContext(editor: self, sourceRange: source, fragment: fragment,
                                            plainText: plain, documentAtLift: document)
        // What a one-line field takes from the move: exactly what it deletes (p22).
        if !fragment.blocks.isEmpty { context.oneLineFieldText = oneLineFieldText(ofFlatRange: source) }
        // And a runs-only region the text the move covered (p23), as a Paste of its Cut would.
        context.coveredText = clipboard?.coveredText
        return context
    }

    // MARK: - Drop

    /// Whether a drop at `target` is accepted: the offset is on a role that holds text (not a media
    /// atom, a button row or a folded quote), and for a local move the source is movable and the
    /// target lies outside it.
    internal func dropIsAcceptable(atFlatOffset target: Int, movingFrom source: NSRange?) -> Bool {
        guard engine.markedTextRange == nil,
              let index = roleIndex(atFlatOffset: target), textNodeRef(ofRoleAt: index) != nil else { return false }
        if let source {
            if rangeCoversATableOnlyInPart(source) { return false }
            if target > source.location && target < NSMaxRange(source) { return false }
        }
        return true
    }

    /// A drop of content from outside this editor (another app, another editor, or a local drag
    /// whose source changed since the lift): a paste of `source` at `target`. Answers whether
    /// anything was inserted.
    @discardableResult
    internal func performDrop(_ source: EnginePasteSource, atFlatOffset target: Int) -> Bool {
        guard dropIsAcceptable(atFlatOffset: target, movingFrom: nil) else { return false }
        var inserted = false
        deliveringChangeNotification {
            endTypingRun()
            engineSelectedRange = NSRange(location: target, length: 0)
            inserted = performHostPaste(from: source) || insertPlainText(from: source)
        }
        return inserted
    }

    /// A drag within this editor, dropped at `target`: Cut + Paste, as ONE undo step and one change
    /// notification, the caret after the moved content. The source is deleted through the surface
    /// gate — Cut's deletion, so its halves are joined by the gate's cross-block rule as Cut and
    /// Backspace join them — and the lifted content is pasted at the target through the paste's own
    /// handlers (`performHostPaste`), in the order a Paste runs them. The target is carried across the
    /// deletion by the length it removed. `expecting` is the document the drag was lifted from; if the
    /// document has changed since, the source range no longer names what was lifted and the move
    /// degrades to inserting the lifted content (a copy).
    @discardableResult
    internal func performLocalMove(_ context: EngineTextDragContext, toFlatOffset target: Int) -> Bool {
        let pasteSource: EnginePasteSource = context.fragment.blocks.isEmpty
            ? .loaded(fragmentData: nil, string: context.plainText)
            : .fragment(context.fragment, oneLineFieldText: context.oneLineFieldText, coveredText: context.coveredText)
        guard document == context.documentAtLift else {
            return performDrop(pasteSource, atFlatOffset: target)
        }
        guard localMoveIsAcceptable(context, toFlatOffset: target) else { return false }
        let sourceRange = context.sourceRange
        // Dropped at its own edge: nothing moves, as in a text view.
        if target == sourceRange.location || target == NSMaxRange(sourceRange) { return false }
        var moved = false
        // The outer frame ends the gated edit's in-flight state and reports the caret, as every
        // host-driven mutation does; the inner one delivers ONE notification for both steps.
        deliveringChangeNotification { deliveringOneChangeNotificationAcrossSteps {
            endTypingRun()
            // The step restores the selection that was lifted.
            engineSelectedRange = sourceRange
            performAsOneUndoStep(registeringWhenUnchanged: { moved }) {
                let lengthBefore = joinedFlatLength()
                replaceFlat(sourceRange, with: "")
                let removed = lengthBefore - joinedFlatLength()
                // The gate refused the deletion (it decides what a range may lose): nothing moves.
                guard removed > 0 else { return }
                let at = target >= NSMaxRange(sourceRange) ? target - removed : target
                engineSelectedRange = NSRange(location: Swift.max(0, Swift.min(at, joinedFlatLength())), length: 0)
                moved = performHostPaste(from: pasteSource) || insertPlainText(from: pasteSource)
                // Nothing landed: the move is refused, and a refused move changes nothing — its
                // deletion is put back (composer harness p21, `HarnessSeparatorBeforeQuoteDeletionTests`:
                // the source was deleted and the move then reported refused).
                if !moved {
                    document = context.documentAtLift
                    engineSelectedRange = sourceRange
                }
            }
            endTypingRun()
        } }
        return moved
    }

    /// Whether a local move of `context` to `target` is taken: the drop is acceptable for its source
    /// (`dropIsAcceptable`), it lies outside what the move takes away, and the destination can hold
    /// what the move carries.
    internal func localMoveIsAcceptable(_ context: EngineTextDragContext, toFlatOffset target: Int) -> Bool {
        let source = context.sourceRange
        guard dropIsAcceptable(atFlatOffset: target, movingFrom: source) else { return false }
        return destinationHolds(context.fragment, atFlatOffset: target)
    }

    /// Whether the text region at `target` can hold `fragment` without dropping any of it. A move
    /// deletes its source, so what the destination cannot hold would be LOST, not merely left behind
    /// (composer harness p19, `HarnessLocalMoveContentLossTests`):
    ///
    /// - a caption, a table cell and a pull quote's body hold a line of RUNS: a fragment is spliced
    ///   there as its inline content, so a medium, a table, a button row or a code block's language in
    ///   it has nowhere to go;
    /// - a code body and the one-line fields (a language, an author, a details title) hold plain TEXT:
    ///   an inline atom (custom emoji, formula, pill) would become its plain text as well;
    /// - anywhere else holds blocks.
    private func destinationHolds(_ fragment: Document, atFlatOffset target: Int) -> Bool {
        guard !fragment.blocks.isEmpty, let index = roleIndex(atFlatOffset: target),
              index < currentRoles.count else { return true }
        let role = currentRoles[index]
        let holdsRunsOnly: Bool
        let holdsTextOnly: Bool
        switch role.position {
        case .tableCell:
            (holdsRunsOnly, holdsTextOnly) = (true, false)
        case let .secondary(_, _, kind):
            (holdsRunsOnly, holdsTextOnly) = kind == .mediaCaption ? (true, false) : (true, true)
        case let .standalone(shape):
            switch shape {
            case .code: (holdsRunsOnly, holdsTextOnly) = (true, true)
            case .pullQuote: (holdsRunsOnly, holdsTextOnly) = (true, false)
            case .paragraph, .media, .buttonRow, .collapsedQuote: (holdsRunsOnly, holdsTextOnly) = (false, false)
            }
        }
        // A ONE-LINE field (a language, an author, a details title) takes the move's exact text — what it
        // deletes, language lines included (`oneLineFieldText(ofFlatRange:)`, p22) — so a code block's
        // language is no reason to refuse there. A cell, a caption and a pull quote's body take RUNS, and a
        // fragment's language is metadata the runs cannot tell from text (a partial copy of a code body
        // carries it too), so a move carrying one is still refused there (p19).
        let isOneLineField = role.secondaryKind != nil && role.secondaryKind != .mediaCaption
        if holdsRunsOnly, Self.containsUnit(fragment.blocks)
            || (!isOneLineField && Self.containsCodeLanguage(fragment.blocks)) { return false }
        if holdsTextOnly, Self.containsInlineAtom(fragment.blocks) { return false }
        return true
    }

    /// A medium, a table or a button row anywhere in `blocks`, quotes and details included.
    private static func containsUnit(_ blocks: [Block]) -> Bool {
        blocks.contains { block in
            switch block {
            case .media, .table, .buttonRow: return true
            case let .blockQuote(quote): return containsUnit(quote.children)
            case let .details(details): return containsUnit(details.children)
            case .paragraph, .code, .pullQuote: return false
            }
        }
    }

    /// A code block with a language anywhere in `blocks`: degraded to runs a code block is its text, so
    /// its language would be dropped while the move deletes it (p19 fix wave, edited seed 57).
    private static func containsCodeLanguage(_ blocks: [Block]) -> Bool {
        blocks.contains { block in
            switch block {
            case let .code(code): return !(code.language ?? "").isEmpty
            case let .blockQuote(quote): return containsCodeLanguage(quote.children)
            case let .details(details): return containsCodeLanguage(details.children)
            case .paragraph, .pullQuote, .media, .table, .buttonRow: return false
            }
        }
    }

    /// A custom emoji, a formula or an inline button in any run of `blocks`.
    private static func containsInlineAtom(_ blocks: [Block]) -> Bool {
        func atom(_ runs: [TextRun]) -> Bool {
            runs.contains { $0.attributes.emoji != nil || $0.attributes.formula != nil || $0.attributes.button != nil }
        }
        return blocks.contains { block in
            switch block {
            case let .paragraph(paragraph): return atom(paragraph.runs)
            case let .pullQuote(quote): return atom(quote.runs) || atom(quote.author)
            case let .code(code): return atom(code.runs)
            case let .media(media): return atom(media.caption)
            case let .table(table): return table.rows.contains { $0.cells.contains { containsInlineAtom($0.blocks) } }
            case let .blockQuote(quote): return containsInlineAtom(quote.children) || atom(quote.author)
            case let .details(details): return atom(details.title) || containsInlineAtom(details.children)
            case .buttonRow: return true
            }
        }
    }

    private func joinedFlatLength() -> Int {
        let blocks = engine.attributedBlocks
        return blocks.reduce(0) { $0 + $1.length } + Swift.max(0, blocks.count - 1)
    }
}

/// What a drag lifted from an engine editor carries, as the session's `localContext`.
@available(iOS 18.4, *)
internal final class EngineTextDragContext {
    weak var editor: RichTextEngineEditorView?
    /// The lifted selection, on the engine's flat axis.
    let sourceRange: NSRange
    /// The selection as a `Document` fragment; empty when the selection holds no extractable
    /// structure (a one-line field), in which case `plainText` is what moves.
    let fragment: Document
    let plainText: String
    let documentAtLift: Document
    /// Set when this editor's own drop consumed the drag.
    var consumedByDrop = false
    /// The exact text a ONE-LINE field takes from this move — what the move deletes
    /// (`oneLineFieldText(ofFlatRange:)`, p22); nil for a plain-text lift.
    var oneLineFieldText: String?
    /// The text the move covered, a code language as a line only when its line was in the range
    /// (`Document.extractFragmentAsCoveredText`, p23) — what a runs-only region takes; nil for a plain-text lift.
    var coveredText: Document?

    init(editor: RichTextEngineEditorView, sourceRange: NSRange, fragment: Document, plainText: String,
         documentAtLift: Document) {
        self.editor = editor
        self.sourceRange = sourceRange
        self.fragment = fragment
        self.plainText = plainText
        self.documentAtLift = documentAtLift
    }
}

/// The two interactions' delegate.
@available(iOS 18.4, *)
internal final class EngineTextDragAndDrop: NSObject, UIDragInteractionDelegate, UIDropInteractionDelegate {
    private weak var editor: RichTextEngineEditorView?
    private(set) var dragInteraction: UIDragInteraction?
    private(set) var dropInteraction: UIDropInteraction?
    /// The caret shown at the drop point while a drop hovers.
    private let dropCaretView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        view.layer.cornerRadius = 1.0
        return view
    }()

    private static let acceptedTypes: [String] = [
        RichTextEditorClipboard.fragmentUTI, UTType.plainText.identifier, UTType.utf8PlainText.identifier,
        UTType.rtf.identifier, UTType.flatRTFD.identifier, UTType.text.identifier
    ]

    init(editor: RichTextEngineEditorView) {
        self.editor = editor
        super.init()
    }

    final func install(on view: UIView) {
        let drag = UIDragInteraction(delegate: self)
        // Off by default on iPhone, and kept off until there is a selection to lift
        // (`refreshDragAvailability`).
        drag.isEnabled = false
        view.addInteraction(drag)
        dragInteraction = drag
        let drop = UIDropInteraction(delegate: self)
        view.addInteraction(drop)
        dropInteraction = drop
    }

    // MARK: - Arbitration

    /// A long press inside the selection belongs to the drag, so the text interaction's long-press
    /// recognizers (the loupe) do not begin there. Everything else is unchanged.
    ///
    /// Measured on the engine view (iOS 26.5, `HarnessTextDropTests`): its long presses are the
    /// drag's own `_UIDragLiftGestureRecognizer` family, the text interaction's
    /// `UIVariableDelayLoupeGesture`, and the scroll view's `UIScrollViewKnobLongPressGestureRecognizer`
    /// (the scroll indicator's), which is left alone. Taps, `UITapAndAHalfRecognizer`, the range
    /// adjustment pan and the scroll pan are not long presses and are never asked.
    ///
    /// The drag's own LIFT is refused outside the selection for the same reason from the other side,
    /// so it fails at once rather than after asking for items; and the whole drag interaction is
    /// DISABLED while there is nothing to lift (`refreshDragAvailability`), so without a selection
    /// the view's recognisers are exactly what they were before drag and drop existed.
    final func gestureRecognizerMayBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let editor, dragInteraction?.isEnabled == true,
              recognizer is UILongPressGestureRecognizer,
              !NSStringFromClass(type(of: recognizer)).hasPrefix("UIScrollView") else { return true }
        let lifts = editor.pointLiftsSelection(recognizer.location(in: editor.engine))
        return Self.isDragRecognizer(recognizer) ? lifts : !lifts
    }

    /// Enables the drag only while a long press could lift something: the editor is focused, nothing
    /// is marked, and the selection is not empty.
    final func refreshDragAvailability() {
        guard let editor, let drag = dragInteraction else { return }
        let available = editor.engine.isFirstResponder && editor.engine.markedTextRange == nil
            && editor.engineSelectedRange.length > 0
        if drag.isEnabled != available {
            drag.isEnabled = available
        }
    }

    /// The drag interaction's own recognizers (the lift and its helpers) are UIKit-private classes
    /// named `_UIDrag…`.
    static func isDragRecognizer(_ recognizer: UIGestureRecognizer) -> Bool {
        NSStringFromClass(type(of: recognizer)).hasPrefix("_UIDrag")
    }

    // MARK: - UIDragInteractionDelegate

    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let editor else { return [] }
        let point = session.location(in: editor.engine)
        guard editor.pointLiftsSelection(point), let context = editor.makeTextDragContext() else { return [] }
        let provider = NSItemProvider()
        if !context.fragment.blocks.isEmpty {
            let item = RichTextEditorClipboard.pasteboardItem(for: context.fragment, plain: context.plainText)
            if let data = item[RichTextEditorClipboard.fragmentUTI] as? Data {
                provider.registerDataRepresentation(forTypeIdentifier: RichTextEditorClipboard.fragmentUTI,
                                                    visibility: .ownProcess) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            if let rtf = item[UTType.rtf.identifier] as? Data {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { completion in
                    completion(rtf, nil)
                    return nil
                }
            }
        }
        provider.registerObject(context.plainText as NSString, visibility: .all)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = context
        session.localContext = context
        return [dragItem]
    }

    func dragInteraction(_ interaction: UIDragInteraction, itemsForAddingTo session: UIDragSession,
                         withTouchAt point: CGPoint) -> [UIDragItem] {
        return []
    }

    func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem,
                         session: UIDragSession) -> UITargetedDragPreview? {
        guard let editor, let context = item.localObject as? EngineTextDragContext else { return nil }
        let engine = editor.engine
        let visible = engine.bounds
        let rects = editor.selectionRectsForDrag(context.sourceRange)
            .map { $0.intersection(visible) }.filter { !$0.isNull && !$0.isEmpty }
        guard let first = rects.first else { return nil }
        let union = rects.dropFirst().reduce(first) { $0.union($1) }
        guard let snapshot = engine.resizableSnapshotView(from: union, afterScreenUpdates: false,
                                                          withCapInsets: .zero) else { return nil }
        let lineRects = rects.map { NSValue(cgRect: $0.offsetBy(dx: -union.minX, dy: -union.minY)) }
        let parameters = UIDragPreviewParameters(textLineRects: lineRects)
        let target = UIDragPreviewTarget(container: engine, center: CGPoint(x: union.midX, y: union.midY))
        return UITargetedDragPreview(view: snapshot, parameters: parameters, target: target)
    }

    func dragInteraction(_ interaction: UIDragInteraction, sessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        return false
    }

    /// A MOVE into another view of this app (one that proposes `.move`) takes the text away from
    /// here, as a text view's does; a copy, a cancel or this editor's own drop leaves it.
    func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) {
        guard operation == .move, let editor,
              let context = session.localContext as? EngineTextDragContext, context.editor === editor,
              !context.consumedByDrop, editor.document == context.documentAtLift else { return }
        editor.deliveringChangeNotification {
            editor.endTypingRun()
            editor.replaceFlat(context.sourceRange, with: "")
        }
    }

    // MARK: - UIDropInteractionDelegate

    private func localContext(of session: UIDropSession) -> EngineTextDragContext? {
        guard let editor, let context = session.localDragSession?.localContext as? EngineTextDragContext,
              context.editor === editor else { return nil }
        return context
    }

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        guard let editor, editor.engine.isEditable else { return false }
        return session.hasItemsConforming(toTypeIdentifiers: Self.acceptedTypes)
            || session.canLoadObjects(ofClass: NSString.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        guard let editor else { return UIDropProposal(operation: .cancel) }
        let point = session.location(in: editor.engine)
        let context = localContext(of: session)
        let moving = context.flatMap { editor.document == $0.documentAtLift ? $0 : nil }
        guard let target = editor.flatOffset(closestTo: point),
              moving.map({ editor.localMoveIsAcceptable($0, toFlatOffset: target) })
                ?? editor.dropIsAcceptable(atFlatOffset: target, movingFrom: nil) else {
            hideDropCaret()
            return UIDropProposal(operation: .forbidden)
        }
        showDropCaret(atFlatOffset: target)
        return UIDropProposal(operation: moving != nil ? .move : .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        hideDropCaret()
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        hideDropCaret()
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        hideDropCaret()
        guard let editor, let target = editor.flatOffset(closestTo: session.location(in: editor.engine)) else { return }
        if let context = localContext(of: session) {
            context.consumedByDrop = true
            editor.performLocalMove(context, toFlatOffset: target)
            return
        }
        Self.loadSource(from: session) { [weak editor] source in
            guard let editor, let source else { return }
            // The items load asynchronously: the target is re-checked against the document as it is
            // NOW (still inside it, still on a role holding text) before anything lands.
            let length = editor.engine.attributedBlocks.reduce(0) { $0 + $1.length }
                + Swift.max(0, editor.engine.attributedBlocks.count - 1)
            editor.performDrop(source, atFlatOffset: Swift.min(target, length))
        }
    }

    /// Reads a drop session's items into a paste source, on the main queue: the editor's fragment
    /// when every item carries one, else the items' plain text joined by newlines (RTF read as text).
    static func loadSource(from session: UIDropSession, completion: @escaping (EnginePasteSource?) -> Void) {
        let providers = session.items.map(\.itemProvider)
        guard !providers.isEmpty else { return completion(nil) }
        let results = EngineDropLoadResults(count: providers.count)
        var hasRichText = false
        let group = DispatchGroup()
        for (index, provider) in providers.enumerated() {
            let providesRichText = provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.flatRTFD.identifier)
            hasRichText = hasRichText || providesRichText
            if provider.hasItemConformingToTypeIdentifier(RichTextEditorClipboard.fragmentUTI) {
                group.enter()
                _ = provider.loadDataRepresentation(forTypeIdentifier: RichTextEditorClipboard.fragmentUTI) { data, _ in
                    results.setFragment(data, at: index)
                    group.leave()
                }
            }
            if provider.canLoadObject(ofClass: NSString.self) {
                group.enter()
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    results.setString(object as? String, at: index)
                    group.leave()
                }
            } else if providesRichText {
                group.enter()
                _ = provider.loadObject(ofClass: NSAttributedString.self) { object, _ in
                    results.setString((object as? NSAttributedString)?.string, at: index)
                    group.leave()
                }
            }
        }
        let richText = hasRichText
        group.notify(queue: .main) {
            let hasRichText = richText
            let fragments = results.fragments
            let strings = results.strings
            let text = strings.compactMap { $0 }
            let joinedText = text.isEmpty ? nil : text.joined(separator: "\n")
            if fragments.allSatisfy({ $0 != nil }) {
                let documents = fragments.compactMap { $0.flatMap { try? DocumentCodec.decode($0) } }
                if documents.count == fragments.count {
                    let merged = documents.count == 1 ? documents[0]
                        : Document(blocks: documents.flatMap(\.blocks))
                    if let data = try? DocumentCodec.encode(merged) {
                        return completion(.loaded(fragmentData: data, string: joinedText, hasRichText: hasRichText))
                    }
                }
            }
            completion(joinedText.map { .loaded(fragmentData: nil, string: $0, hasRichText: hasRichText) })
        }
    }

    // MARK: - The drop caret

    /// Attached only while a drop hovers, so no other pass over the engine's subviews ever meets it.

    private func showDropCaret(atFlatOffset offset: Int) {
        guard let editor, let position = editor.engine.position(from: editor.engine.beginningOfDocument, offset: offset)
        else { return hideDropCaret() }
        let rect = editor.engine.caretRect(for: position)
        guard !rect.isNull, !rect.isInfinite else { return hideDropCaret() }
        dropCaretView.backgroundColor = editor.engine.tintColor
        dropCaretView.frame = CGRect(x: rect.minX, y: rect.minY, width: Swift.max(2.0, rect.width), height: rect.height)
        if dropCaretView.superview !== editor.engine {
            editor.engine.addSubview(dropCaretView)
        } else {
            editor.engine.bringSubviewToFront(dropCaretView)
        }
        dropCaretView.isHidden = false
    }

    private func hideDropCaret() {
        dropCaretView.isHidden = true
        dropCaretView.removeFromSuperview()
    }
}

/// A drop's loaded representations, written from NSItemProvider's completion queues.
private final class EngineDropLoadResults: @unchecked Sendable {
    private let lock = NSLock()
    private var fragmentValues: [Data?]
    private var stringValues: [String?]

    init(count: Int) {
        fragmentValues = Array(repeating: nil, count: count)
        stringValues = Array(repeating: nil, count: count)
    }

    func setFragment(_ data: Data?, at index: Int) {
        lock.lock(); defer { lock.unlock() }
        fragmentValues[index] = data
    }

    func setString(_ string: String?, at index: Int) {
        lock.lock(); defer { lock.unlock() }
        stringValues[index] = string
    }

    var fragments: [Data?] { lock.lock(); defer { lock.unlock() }; return fragmentValues }
    var strings: [String?] { lock.lock(); defer { lock.unlock() }; return stringValues }
}
#endif
