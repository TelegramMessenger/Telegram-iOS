#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The consumer-facing contract both editor implementations answer — the chat composer's actual
/// surface, and nothing more.
///
/// Transcribed from `RichTextEditorView`'s PUBLIC api (`RichTextEditorView.swift` +
/// `RichTextEditorView+ComposerHost.swift`) and from what the composer
/// (`RichTextEditorChatInputNode`, `submodules/TelegramUI/Components/Chat/
/// ChatRichTextEditorComposer`) actually calls — never from a canvas. Nothing named `boxes`,
/// `mapper`, `head` or `root` may ever appear here: an earlier attempt at this project failed by
/// building against a canvas-shaped surface, which dragged in exactly those internals and
/// Legacy's private offset axis. If a member here ever starts naming an internal structure rather
/// than an editing capability, it does not belong.
///
/// This was deliberately NARROWER than `RichTextEditorView`'s full public surface, on the grounds
/// that only `RichTextAttachmentScreen`'s full-page article-editor toolbar called the rest — so
/// widening it would force `RichTextEngineEditorView` to fake fields it could not answer or trap on
/// members the composer was never going to call.
///
/// **The article editor is now a host too**, behind the same `useInputDecEngine` Debug Setting, so
/// that reasoning no longer holds: those members ARE called. The widening is the second half of that
/// argument honoured rather than abandoned — every added member either answers for real, stores what
/// the host pushes, or TRAPS naming its rung. None fakes. Where a field of `EditorState` is
/// structurally unreachable for an engine document (anything about tables — the bridge traps on a
/// table, so no document holding one can be loaded), the constant answer is the CORRECT one and says
/// so at the site, which is a different thing from a plausible default.
/// Class-constrained to `UIView` rather than `AnyObject`: the composer positions, hit-tests and
/// converts coordinates against its editor, so a bare `AnyObject` would force ~20 call sites through
/// a `view` accessor to reach members both implementations already have by inheritance.
public protocol RichTextEditor: UIView {
    var document: Document { get set }
    var onChange: (() -> Void)? { get set }
    /// Fired SYNCHRONOUSLY when a text or selection change leaves the caret wanting a reveal.
    ///
    /// Distinct from `onChange`, which is coalesced to one trailing async call per run-loop turn so
    /// a host's toolbar never observes a transient selection. A reveal riding that signal lands a
    /// turn late, and a rapid second arrow key then computes its destination against an in-flight
    /// `contentOffset` — the non-determinism `RichTextEditorView.scrollCaretIntoView`'s own comment
    /// records. A host answers this by re-applying its current layout with
    /// `caretReveal: .ifNeeded(.immediate)`; a caret that merely moved changes no geometry, so that
    /// pass is a no-op except for the reveal it carries.
    var onCaretRevealNeeded: (() -> Void)? { get set }
    func height(forWidth width: CGFloat) -> CGFloat
    /// The margin-aware form the composer actually measures with. Declared separately rather than
    /// defaulting `contentMargins`, because a defaulted parameter only witnesses a requirement whose
    /// full signature matches — the one-argument form above needs its own explicit-arity forwarder
    /// on the façade for exactly that reason.
    func height(forWidth width: CGFloat, contentMargins: UIEdgeInsets?) -> CGFloat
    func toggleBold()
    func toggleItalic()
    func toggleUnderline()
    func toggleStrikethrough()
    func setParagraphStyle(_ name: ParagraphStyleName)
    func setAlignment(_ alignment: TextAlignment)
    func setList(_ marker: ListMarker?)
    func indent()
    func outdent()
    var composerSelectedRange: NSRange { get set }
    func composerCaretRect() -> CGRect?
    var isEditorFirstResponder: Bool { get }
    func resignEditorFirstResponder() -> Bool
    func selectedText() -> String

    // MARK: Composer host — layout, placeholders and focus (answer-or-trap)
    //
    // All four `update` parameters are declared because `RichTextEditorView`'s method defaults the
    // last two, and a defaulted parameter witnesses a requirement only when the FULL signature
    // matches. (`height(forWidth:)` above is the opposite case: the protocol omits a parameter the
    // façade has, so that one needed an explicit-arity forwarder.)
    /// **The caret is revealed here or nowhere.** An editor does not scroll itself to follow the
    /// caret; it performs at most one reveal per pass, computed against the geometry THIS call is
    /// applying. So the host's second promise matters as much as the first: pass the size and insets
    /// you are committing to on this pass, not the ones currently on screen. Every defect this
    /// replaced was an editor deciding against a number the host was about to change.
    @discardableResult
    func update(size: CGSize, insets: UIEdgeInsets, contentMargins: UIEdgeInsets,
                scrollIndicatorInsets: UIEdgeInsets?,
                caretReveal: RichTextEditorCaretReveal) -> CGFloat
    var minimumContentHeight: CGFloat { get set }
    var contentPageMargin: CGFloat { get set }
    var placeholders: RichTextEditorPlaceholders { get set }
    var canvasBackgroundColor: UIColor? { get set }
    var tapBelowAddsTrailingParagraph: Bool { get set }
    var onHardwareReturn: ((UIKeyModifierFlags) -> Bool)? { get set }
    var onBecameFirstResponder: (() -> Void)? { get set }
    var onResignedFirstResponder: (() -> Void)? { get set }

    // MARK: Deferred configuration (accept-and-store)
    //
    // Configuration the host pushes for capabilities the engine path does not have yet. The engine
    // implementation stores these inertly under a rule that makes each entry name the rung that will
    // consume it (`RichTextEngineEditorView+DeferredConfiguration.swift`); the Legacy implementation
    // honours them today. Both answer the same surface, which is what lets the composer hold either.
    var quoteStyle: QuoteStyle { get set }
    var codeStyle: CodeStyle { get set }
    var mediaBlockStyle: MediaBlockStyle { get set }
    var quoteCollapseIcons: RichTextEditorQuoteCollapseIcons? { get set }
    var detailsChevronImage: UIImage? { get set }
    var renderMetrics: RichTextRenderMetrics { get set }
    var configureSelectionHandleView: ((UIView) -> Void)? { get set }
    func registerFormulaRenderer(_ provider: @escaping (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)
    func registerButtonIconProvider(_ provider: @escaping (ButtonAction) -> RichTextButtonIcon?)
    func registerEmojiViewProvider(_ provider: @escaping (_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?)
    func registerMediaViewProvider(_ provider: @escaping ([MediaProviderItem], BlockID, MediaDisplayMode, RichTextMediaItemView?) -> RichTextMediaItemView?)
    func registerChecklistMarkerViewProvider(_ provider: @escaping (_ checked: Bool, _ size: CGSize) -> (UIView & RichTextChecklistMarkerView)?)

    /// Register the host's syntax highlighter for code blocks. The host turns (language, text) into
    /// colours and calls `completion` on the main queue; answering late is expected and never
    /// answering leaves the block plain. The package cannot do this itself — it cannot see libprisma.
    /// Optional because a host may have no highlighter; both of ours register one at construction.
    func registerSyntaxHighlighter(_ provider: ((_ language: String, _ text: String, _ completion: @escaping ([RichTextSyntaxToken]) -> Void) -> Void)?)
    var canPasteMedia: (() -> Bool)? { get set }
    var onPasteMedia: (() -> Bool)? { get set }
    var plainTextFragmentTransformer: ((String) -> Document?)? { get set }
    var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? { get set }
    var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? { get set }
    var onRequestMediaControl: ((MediaControlRequest) -> Void)? { get set }


    // MARK: Actions the engine path cannot perform yet (perform-or-trap)
    //
    // Declared here because the composer calls them; the engine implementation traps naming its
    // rung rather than no-opping. A silent no-op would leave a flag user unable to say what went
    // wrong; a trap names R7 or R9 in the crash.
    func makeCodeBlock()
    func makePullQuote()
    func wrapInBlockQuote()
    func currentLink() -> String?
    func setLink(_ url: String)
    func removeLink()

    // MARK: Members both implementations already answer
    //
    // Declared last because they needed no new work on either side: the engine path grew these
    // across R1–R6 and the façade has always had them. `toggleInlineCode` and `toggleSpoiler` are
    // perform-or-trap on the engine (they are Telegram inline traits with no engine equivalent, so
    // they trap naming R9) but are listed here because the composer calls them like any other
    // toggle and neither implementation needed changing to satisfy the declaration.
    func composerFirstSelectionRect(forFlatRange range: NSRange) -> CGRect?
    var composerSelectionBoundingRect: CGRect { get }
    var customInputView: UIView? { get set }
    func deleteBackward()
    func finalizeComposerMarkedText()
    var inputPrimaryLanguage: String? { get }
    func pasteFromPasteboard()
    func reloadComposerInputViews()
    func toggleInlineCode()
    func toggleSpoiler()
    var theme: RichTextEditorTheme { get set }
    var composerContentOffset: CGPoint { get }
    var initialInputPrimaryLanguage: String? { get set }
    func resetInputPrimaryLanguage()

    // MARK: The full-page article editor's surface
    //
    // Everything below is called by `RichTextAttachmentScreen` and NOT by the chat composer. The
    // legacy view already implements all of it; the engine answers per the note above.

    /// The toolbar's per-action availability and selected state. Read on every change, so this one
    /// cannot trap without making the screen unusable — the engine answers it for real.
    func currentState() -> RichTextEditorView.EditorState
    func undo()
    func redo()
    var pullQuoteStyle: PullQuoteStyle { get set }

    func insertTable(rows: Int, cols: Int)
    func deleteTable()
    func copyCurrentTable()
    func convertCurrentTableToText()
    func toggleTableBordered()
    func toggleTableCompact()

    func insertMedia(mediaID: String, naturalSize: CGSize, kind: MediaKind, caption: [TextRun])
    func insertDocument(_ document: Document)

    func insertFormula(latex: String)
    func insertInlineFormula(latex: String)
    func makeSelectionInlineFormula()
    var onEditFormulaRequested: ((_ latex: String, _ completion: @escaping (String) -> Void) -> Void)? { get set }

    func insertButtonRow()
    func makeSelectionInlineButton()
    /// Inserts ONE inline pill carrying `button` at the caret, replacing any selection — the Add
    /// menu's "Button ▸ Inline", whose label the host authored in its sheet first. Works inside a
    /// table cell; a code block takes the label as plain text; an atom refuses.
    func insertInlineButton(_ button: ButtonRef)
    var onEditButtonRequested: ((_ button: ButtonRef, _ isBlockPill: Bool, _ completion: @escaping (ButtonRef?) -> Void) -> Void)? { get set }
    var onRequestButtonRowMenu: ((ButtonRowMenuRequest) -> Void)? { get set }

    func insertDetailsBlock()
    func unwrapBlockQuoteLevel()

    /// The selection on the LEGACY global position axis, which the engine does not have. Paired with
    /// `replaceRange` by the AI-compose flow; both trap on the engine rather than answering nil,
    /// because nil here reads as "nothing selected" and would silently do nothing.
    func selectedGlobalRange() -> (from: Int, to: Int)?
    func replaceRange(from: Int, to: Int, with document: Document)
    func moveCaretToDocumentEnd()

    /// Driven by the article editor's emoji keyboard panel, which hosts its own input view and
    /// pushes text through the editor rather than the system keyboard.
    func insertText(_ text: String)
    func insertEmoji(id: String, altText: String?)

    /// Whether a table's horizontal scroll is IN FLIGHT — being dragged, or coasting from a drag,
    /// or held by the finger that caught it mid-flight.
    ///
    /// For a host that nests the editor inside something with a drag of its own: Telegram's
    /// attachment sheet dismisses on a downward pan, and its recogniser recognises SIMULTANEOUSLY
    /// with every other pan, so a finger put down to catch a coasting table gave the sheet the drag
    /// (K3, 2026-09-11). The host declines its own gesture while this is true.
    ///
    /// Defaulted to `false`: an editor whose tables scroll in views that receive touches has no such
    /// gap to report — UIKit catches those itself.
    var hasTableScrollInFlight: Bool { get }

    /// Whether Format ▸ Italic would change anything over the current selection. False when every
    /// part of the selection is text the model cannot carry italic in — a pull quote's body (its
    /// slant is the role's: the shared mapper strips italic there on read-back, and the V2 renderer
    /// draws an italic run in a pull quote exactly like the rest) or a code block's language line.
    /// A host menu shows the command DISABLED rather than offering a silent dead end.
    ///
    /// Defaulted to `true`: an editor that offers no such answer keeps its command enabled.
    var italicReachesSelection: Bool { get }

    /// Whether the other inline formats — Bold, Underline, Strikethrough, Monospace, Spoiler, a link —
    /// would change anything over the current selection. False when the whole selection is text whose
    /// model cannot carry an inline format: a code block (its body is sent as a `Pre` entity, which
    /// holds no other entity, and its language is a plain string). A host menu shows those commands
    /// DISABLED there.
    ///
    /// Defaulted to `true`: an editor that offers no such answer keeps its commands enabled.
    var inlineFormatsReachSelection: Bool { get }

    /// Whether Monospace would change anything over the selection: `inlineFormatsReachSelection`, and
    /// not turning inline code ON over a range holding a mention, a date or a link (the platform lets no
    /// `Code` entity overlap one; composer harness p23). A host menu shows Monospace DISABLED where false.
    ///
    /// Defaulted to `inlineFormatsReachSelection`.
    var inlineCodeReachesSelection: Bool { get }

    /// Whether a link would change anything over the selection: `inlineFormatsReachSelection`, and not
    /// over a range holding inline code (composer harness p23). A host menu shows Link DISABLED where false.
    ///
    /// Defaulted to `inlineFormatsReachSelection`.
    var linkReachesSelection: Bool { get }

    /// Removes the inline marks the toggles set — bold, italic, underline, strikethrough, inline code,
    /// spoiler — from the selection, as ONE undo step, keeping every block as it is. The chat's ⇧⌘N.
    ///
    /// Defaulted to doing nothing: an editor that has no such command leaves the text alone rather
    /// than approximating it.
    func clearInlineFormatting()

    /// Empties the undo AND the redo stack, keeping the document. A host calls it right after it
    /// REPLACES the content from outside — Send's clear, a draft synced from another device — which
    /// is what a stock `UITextView` does on a `text` / `attributedText` set: a step recorded before
    /// the set describes a document the user no longer has, and replaying it threw the new content
    /// away (composer harness p15, `HarnessExternalSetUndoTests`). A `document` set alone keeps the
    /// history, deliberately: the editor's own commands rebuild through it and register their step.
    ///
    /// Defaulted to doing nothing: an editor with no stack of its own has nothing to empty.
    func discardUndoHistory()

    /// Runs `body` — a host's `document` set made on the USER's behalf (the chat's autocomplete, its
    /// emoji keyboard, Translate: an edit the chat computes and pushes back) — and records what it
    /// changed as ONE undo step on top of the stack, keeping every step before it. The counterpart of
    /// `discardUndoHistory()`, which is for a set from OUTSIDE (Send's clear, a draft sync). A body that
    /// changes nothing registers nothing (composer harness, `HarnessChatSideEditUndoTests`).
    ///
    /// Defaulted to just running `body`: an editor with no stack of its own has nothing to record.
    func performAsOneUndoStep(_ body: () -> Void)

    /// Inserts `runs` — inline text a HOST inserts on the user's behalf from outside the editor: the
    /// chat's emoji keyboard (a static or a custom emoji), the avatar menu's Mention — at the editor's
    /// OWN selection, replacing it, as ONE undo step on top of the stack, keeping every block.
    ///
    /// Plain text goes in as typing does (the surface gate decides the selection and any newline,
    /// and the text takes the caret's formatting); a custom emoji goes in as `insertEmoji` does, and
    /// keeps a spoiler it is inserted into; a run carrying a link (a mention or date marker, a URL)
    /// is typed and then linked. A run's own formatting flags are ignored — the caret's win, as they
    /// do for typing. Answers whether this editor took the insert; `false` means it has no such verb
    /// and the host keeps its own path.
    ///
    /// The alternative it replaces — the host transforming the flat `NSAttributedString` projection
    /// and setting the result back — retypes every heading, list, table and pull-quote author as a
    /// body paragraph, and cannot address a caret that is off the composer's flat axis (a table cell)
    /// at all (composer harness p18, `HarnessChatInsertStructureTests`).
    ///
    /// Defaulted to `false`: an editor without the verb keeps the host's path, unchanged.
    func insertInlineRunsOnUsersBehalf(_ runs: [TextRun]) -> Bool
}

@available(iOS 13.0, *)
public extension RichTextEditor {
    var hasTableScrollInFlight: Bool { false }
    var italicReachesSelection: Bool { true }
    var inlineFormatsReachSelection: Bool { true }
    var inlineCodeReachesSelection: Bool { inlineFormatsReachSelection }
    var linkReachesSelection: Bool { inlineFormatsReachSelection }
    func clearInlineFormatting() {}
    func discardUndoHistory() {}
    func performAsOneUndoStep(_ body: () -> Void) { body() }
    func insertInlineRunsOnUsersBehalf(_ runs: [TextRun]) -> Bool { false }
}

/// `RichTextEngineEditorView` already implements every member above verbatim — that IS R1-R6's
/// cumulative deliverable. This conformance names it; it changes no behaviour.
@available(iOS 18.4, *)
extension RichTextEngineEditorView: RichTextEditor {}

/// `RichTextEditorView`'s conformance is declaration-only too: every member already exists on the
/// façade (`RichTextEditorView.swift` + `RichTextEditorView+ComposerHost.swift`), EXCEPT
/// `height(forWidth:)` — its defaulted `contentMargins:` parameter does not witness a protocol
/// requirement that omits it, so `RichTextEditorView.swift` gained an explicit-arity forwarder in
/// the same commit as this file (a permitted façade change; it does not touch the canvas or the
/// input backend).
///
/// This conformance is declared HERE — inside `RichTextEngineEditor` — rather than inside
/// `RichTextEditorUIKit` itself, because the module dependency graph is a one-way edge:
/// `RichTextEngineEditor` imports `RichTextEditorUIKit` (for `AttributedStringMapper`, used by
/// `EngineDocumentBridge`), never the reverse. `RichTextEditorUIKit` importing this module back to
/// declare the same conformance would be a dependency cycle. Only a module downstream of BOTH
/// types — this one — can see `RichTextEditorView` and `RichTextEditor` at the same time, so this
/// is the one legal place for the declaration to live. `BUILD` (Bazel) is unaffected either way:
/// it has no `deps` edge to `RichTextEngineEditor` or `RichTextInputDecHost` (Global Constraint 2),
/// and this file only compiles under SwiftPM, where the Host app links this module deliberately.
@available(iOS 13.0, *)
extension RichTextEditorView: RichTextEditor {}

public extension RichTextEditor {
    /// The spelling every existing call site uses, and the one a host reaches for when the pass has
    /// nothing to do with the caret. `.none` is the honest default: a pass that says nothing about
    /// the caret is a pass that does not move it.
    @discardableResult
    func update(size: CGSize, insets: UIEdgeInsets, contentMargins: UIEdgeInsets,
                scrollIndicatorInsets: UIEdgeInsets?) -> CGFloat {
        update(size: size, insets: insets, contentMargins: contentMargins,
               scrollIndicatorInsets: scrollIndicatorInsets, caretReveal: .none)
    }
}
#endif
