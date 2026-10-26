import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AppBundle
import SwiftSignalKit
import TextFormat
import TelegramCore
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextEngineEditor
import RichTextButtonIcons
import ChatInputTextNode
import CheckNode
import TelegramPresentationData

/// `RichTextChecklistMarkerView` host wrapper backing a checklist item's checkbox with a `CheckNode`
/// (an `ASDisplayNode`, so we host its `.view` — this is a `UIView`, not a node). The editor frames this
/// view in the marker gutter and calls `setChecked(_:animated:)` when the item toggles. A private copy
/// lives in each editor host (cross-module; duplication is expected).
private final class HostChecklistCheckboxView: UIView, RichTextChecklistMarkerView {
    private let checkNode: CheckNode
    init(theme: CheckNodeTheme, checked: Bool) {
        self.checkNode = CheckNode(theme: theme, content: .check(isRectangle: true))
        super.init(frame: .zero)
        self.checkNode.isUserInteractionEnabled = false
        self.addSubview(self.checkNode.view)
        self.checkNode.setSelected(checked, animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.checkNode.frame = self.bounds
    }
    func setChecked(_ checked: Bool, animated: Bool) {
        self.checkNode.setSelected(checked, animated: animated)
    }
}

/// `ChatRichTextInputNode` backend composing the TextKit-2 `RichTextEditorView`.
@available(iOS 13.0, *)
public final class RichTextEditorChatInputNode: ASDisplayNode, ChatRichTextInputNode {
    private let strings: PresentationStrings
    
    /// Built for the backend the host selected. The panel supplies it from the
    /// `inputDecTextBackend` experimental setting; everything else keeps the production
    /// `.legacy` default.
    /// `any RichTextEditor`, not a concrete view: the Debug Settings flag chooses between the
    /// legacy canvas and the InputDec-engine editor at construction, and both answer this protocol.
    /// The protocol is class-constrained to `UIView`, so positioning and hit-testing still work
    /// through it.
    private let editorView: any RichTextEditor
    private let baseFontSize: CGFloat = 17.0

    private var trackedInsets: UIEdgeInsets = .zero
    private var trackedContentMargins: UIEdgeInsets = .zero
    private var trackedRightInset: CGFloat = 0.0
    // The host's constant scroll-indicator inset (the panel sets it once during loadTextInputNode, before the
    // first layout). Threaded into every editor.update(...) so it survives — nil means "track the content insets".
    private var trackedScrollIndicatorInsets: UIEdgeInsets?
    private weak var storedDelegate: ChatInputTextNodeDelegate?

    public var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)?

    /// Factory the panel supplies (it owns `AccountContext`) to turn a `Media` + natural size into a hosted
    /// media view. The editor's media-view provider (registered in `didLoad`) resolves its opaque `mediaID` →
    /// `mediaByID` → this factory. Read lazily, so the panel may set it after `didLoad`. Mirrors `emojiViewProvider`.
    public var mediaItemViewFactory: ((_ items: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)], _ existing: (UIView & RichTextMediaItemView)?) -> (UIView & RichTextMediaItemView)?)?

    public var formulaRenderer: ((RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)? {
        didSet {
            if self.isNodeLoaded {
                self.updateFormulaRenderer()
            }
        }
    }

    /// Panel-set "user is typing" hook (wired to `ChatTextInputPanelNode.updateActivity`). Fired from `onChange`
    /// ONLY on a genuine text edit — see the gating in `didLoad`. The legacy backend reports this via the
    /// `chatInputTextNode(shouldChangeTextIn:)` delegate, which this engine never calls; this is its replacement.
    public var onTypingActivity: (() -> Void)?

    /// fileId → the file-bearing custom-emoji attribute, harvested from each `attributedText` /
    /// `setInputContent` push. The editor hosts inline emoji by their `EmojiRef` fileId STRING only
    /// (`document(from:)` / `document(fromChatInputContent:)` drop the `TelegramMediaFile`), but the host
    /// renderer (`EmojiTextAttachmentView`) needs the file — so we cache the full attribute here and rebuild it
    /// for the editor's view provider. Mirrors `RichTextEmojiKeyboardController.emojiFiles`. Also the source the
    /// direct-bridge `resolveEmoji`/`registerEmoji` closures read/write (see `currentInputContent`/`setInputContent`).
    private var customEmojiAttributes: [Int64: ChatTextInputTextCustomEmojiAttribute] = [:]

    /// `MediaBlock.mediaID` → the concrete `Media` it stands for. The editor stores only the opaque host
    /// `mediaID` string (it never holds a `Media`), so the node owns the mapping — exactly as
    /// `RichTextAttachmentScreen.attachedMedia` does. Populated by the direct-bridge `registerMedia` closure
    /// from each `setInputContent` push and read back by `resolveMedia` in `currentInputContent`, so a medium
    /// the chat layer sets round-trips through the structural model. A medium the editor never received via this
    /// path (no entry) resolves to nil and its block is dropped — see `resolveMedia` below.
    private var mediaByID: [String: EngineMedia] = [:]

    /// Typing-activity bookkeeping. The editor's `onChange` funnels THREE kinds of event into one payload-free
    /// call — a genuine text edit, a caret/selection move, and a programmatic `document` swap (draft restore /
    /// send-clear / state echo). Only the first is "typing". `lastTypingActivityText` is the plain text at the
    /// previous `onChange`, so a selection-only move (text unchanged) doesn't fire `onTypingActivity`; the flag
    /// suppresses the synchronous `onChange` a programmatic `document =` triggers (via `reload` → `setBlocks` →
    /// `notifyContentSizeChanged`) so a draft restore / state re-apply never reports typing.
    private var lastTypingActivityText: String = ""
    private var isApplyingProgrammaticContent = false

    /// Checklist checkbox palette, threaded across the `ChatRichTextThemeColors` seam (the node holds no
    /// `PresentationTheme`). Set on each `applyRichTextTheme`; the marker provider reads them lazily so a
    /// theme change takes effect on the next-built checkbox. Seeded with sane defaults so an early checkbox
    /// (before the first `applyRichTextTheme`) still renders — overwritten on the first theme apply.
    private var checkboxFill: UIColor = .systemBlue
    private var checkboxForeground: UIColor = .white
    private var checkboxBorder: UIColor = .systemGray

    public var asNode: ASDisplayNode { self }

    /// `inputBackend` names which input backend the composed `RichTextEditorView` is built for.
    /// Defaults to `.legacy`, so every existing caller keeps today's behaviour; the chat panel
    /// passes `.inputDecIfSupported` when the `inputDecTextBackend` experimental setting is on.
    /// `inputBackend` names which backend the composed legacy `RichTextEditorView` is built for.
    /// `useInputDecEngine` selects the ENGINE editor instead — a different type entirely, not
    /// another backend of the same view.
    ///
    /// The flag is read ONCE, here. Re-reading it per update would let the editor change identity
    /// mid-session with a live document and first responder in it.
    public init(strings: PresentationStrings,
                inputBackend: RichTextEditorInputBackendPreference = .legacy,
                useInputDecEngine: Bool = false) {
        #if DEBUG && false
        RichTextEditorView.debugShowLayoutOverlay = true
        #endif

        self.strings = strings
        // `if #available` because the engine's public header uses UIKit types newer than this
        // module's floor, so `IDBlockTextView` — and everything built on it — is gated at 18.4.
        // Below that the flag simply has no effect, which is the correct behaviour for a debug
        // toggle: no crash, no silent half-state, just the shipping editor.
        if useInputDecEngine, #available(iOS 18.4, *) {
            let engineEditor = RichTextEngineEditorView(frame: .zero)
            // What VoiceOver reads for a media atom: the chat list's own words for each kind.
            engineEditor.accessibilityMediaName = { kind in
                switch kind {
                case .image: return strings.Message_Photo
                case .video: return strings.Message_Video
                case .location: return strings.Message_Location
                case .audio: return strings.Message_Audio
                case .document: return strings.Message_File
                }
            }
            self.editorView = engineEditor
        } else {
            self.editorView = RichTextEditorView(frame: .zero, inputBackend: inputBackend)
        }

        // Names the editor that was ACTUALLY built, so a silent fallback is visible rather than
        // mistaken for the engine. The host app reports its canvas the same way and for the same
        // reason: under the previous attempt a fallback read exactly like a passing arm.
        self.editorView.accessibilityIdentifier = "composer.editor.\(type(of: self.editorView))"

        super.init()
    }

    /// The compact-composer layout knobs that affect measured text height. Applied to the live editor in
    /// `didLoad` AND to the throwaway probe in `measuredTextFieldHeight`, so the probe's height matches the
    /// live field's. (Height-irrelevant knobs — placeholders, theme, quote style — are NOT included.)
    /// The composer lays text out with V2's chat-message metrics, so what you type reads like the
    /// message you are about to send. It uses `RichTextRenderMetrics.default` rather than
    /// `InstantPageTheme.chatMessageRenderMetrics()` because this module cannot import `InstantPageUI` —
    /// that edge is a cycle (`InstantPageUI` depends on this module). The two are pinned equal by
    /// `RichTextV2MetricsParityTests.test_editorDefaultMetrics_equalTheAdaptedChatMessageTheme`.
    ///
    /// **`edgeSpacingReduction` trims the field's outer padding to nothing.** V2 gives a top-level
    /// paragraph `blockVerticalPadding + 2` = 6pt at each SEQUENCE EDGE (not to be confused with the
    /// inter-paragraph gap, which is 1pt), so an untrimmed one-line field measures 33pt against the
    /// text's own 21pt. In a page that padding is the page's margin; in the composer the input panel
    /// already owns the padding around the field, which is why the pre-parity config zeroed the block
    /// inset for the same reason. Trimming here is V2's own mechanism for a host that insets the whole
    /// page — the chat bubble passes 1.0 for it — and it affects ONLY the edges, so the interior rhythm
    /// stays V2-exact (guarded by `BlockSpacingTests.test_edgeSpacingReduction_trimsEdgesOnlyAndClampsAtZero`).
    /// Measured: 33pt → 21pt for one line; it clamps at 0, so 6 is "remove it entirely".
    private static let composerEdgeSpacingReduction: CGFloat = 6.0

    private static func applyComposerLayoutMetrics(to editor: any RichTextEditor) {
        editor.contentPageMargin = 0.0
        editor.minimumContentHeight = 0.0
        var metrics = RichTextRenderMetrics.default
        metrics.edgeSpacingReduction = composerEdgeSpacingReduction
        editor.renderMetrics = metrics
    }

    private func updateFormulaRenderer() {
        self.editorView.registerFormulaRenderer { [weak self] context in
            return self?.formulaRenderer?(context)
        }
    }

    /// A button pill's type icon. Registered unconditionally rather than proxied through a host hook
    /// like the formula renderer: the mapping is a pure function of the action, and it is GEOMETRY —
    /// an inline pill grows by `inlineIconReserve` to hold its icon, so a composer that skipped it
    /// would wrap a paragraph differently from the message it sends.
    private func updateButtonIconProvider() {
        self.editorView.registerButtonIconProvider(richTextEditorButtonIcon)
    }

    public override func didLoad() {
        super.didLoad()
        // Model A: this node is the wrapper (the panel frames `asNode` to fill the clipping container);
        // `editorView` is the inset child, positioned by the panel via `textFieldFrame`. They are distinct
        // views — exactly as the legacy impl keeps `textInputNodeImpl` a subnode of the wrapper.
        self.view.addSubview(self.editorView)

        // Compact-composer layout knobs — shared with the 3-line measurement probe so the two cannot drift.
        RichTextEditorChatInputNode.applyComposerLayoutMetrics(to: self.editorView)
        // Suppress the editor's built-in placeholders ("Type something…" / list hints): the chat input panel
        // draws its own placeholder ("Message", etc.), so the editor's would double up.
        
        self.editorView.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: self.strings.RichText_PlaceholderQuote, blockQuote: self.strings.RichText_PlaceholderQuote, codeBlock: self.strings.RichText_PlaceholderCode, codeLanguage: self.strings.RichText_PlaceholderCodeLanguage, detailsTitle: self.strings.RichText_PlaceholderDetailTitle, quoteAuthor: self.strings.RichText_PlaceholderQuoteAuthor, caption: self.strings.RichText_PlaceholderCaption)
        // Only the canvas editor has built-in custom menu items to title. The engine editor has none:
        // Telegram's items reach it through `contextMenuItemsProvider`, so it takes no menu strings.
        (self.editorView as? RichTextEditorView)?.editMenuStrings = RichTextEditorMenuStrings(
            format: self.strings.TextFormat_Format,
            bold: self.strings.TextFormat_Bold,
            italic: self.strings.TextFormat_Italic,
            underline: self.strings.TextFormat_Underline,
            lookUp: self.strings.Conversation_ContextMenuLookUp,
            translate: self.strings.Conversation_ContextMenuTranslate,
            share: self.strings.Conversation_ContextMenuShare
        )
        // The composer sits over the input panel's own background — clear the editor's document "page"
        // background (`.systemBackground`, opaque white in light mode) so the panel shows through. `nil`
        // (no background) rather than `.clear`: same transparency, but signals "unset" and avoids an
        // explicit clear-color fill.
        self.editorView.canvasBackgroundColor = nil
        // Disable the "tap below the content adds a trailing paragraph" affordance: that's a full-page
        // document-editor behavior (the article editor keeps it). In the compact composer there is no empty
        // area below the content to grow into, so a tap there just places the caret in the trailing paragraph.
        self.editorView.tapBelowAddsTrailingParagraph = false
        // Quote geometry for the compact composer. Defaults == the editor's built-in look; tune here to
        // diverge from the article editor (e.g. tighter insets in the narrow input field).
        self.editorView.quoteStyle = QuoteStyle(
            leadingInset: 9.0,
            trailingInset: 22.0,
            spacingBefore: 8.0,
            spacingAfter: 8.0,
            barWidth: 3.0,
            cornerRadius: 2.5,
            fillAlpha: 0.1,
            topInset: 3.0,
            bottomInset: 3.0
        )
        // Code-block geometry for the compact composer. The band does NOT bleed at all here: the
        // editor sits inside the input field's rounded background (inset by the panel's
        // `textInputViewInternalInsets`, 12 left / 11 right) and its right content margin also
        // reserves room for the accessory + send buttons, so ANY outward bleed reads as spilling past
        // what the field shows. The band therefore spans exactly the text column, and the code is
        // indented within it instead — the inward counterpart of the renderer's outward bleed. A
        // small radius keeps the band from fighting the field's own rounding.
        //
        // Deliberately NOT WYSIWYG against the sent bubble, which is full-bleed and square: a compact
        // field is a different container shape from a message bubble.
        self.editorView.codeStyle = CodeStyle(horizontalBleed: 0.0, horizontalInset: 8.0, cornerRadius: 4.0)
        // Media (image/video/location/audio) insets like the text paragraphs in the compact composer
        // (the document/article editor keeps the default edge-to-edge bleed).
        self.editorView.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0.0)
        // Quote collapse/expand affordance icons — the same bundle assets the legacy ChatInputTextNode uses.
        if let collapse = UIImage(bundleImageName: "Media Gallery/Minimize")?.precomposed().withRenderingMode(.alwaysTemplate),
           let expand = UIImage(bundleImageName: "Media Gallery/Fullscreen")?.precomposed().withRenderingMode(.alwaysTemplate) {
            self.editorView.quoteCollapseIcons = RichTextEditorQuoteCollapseIcons(collapse: collapse, expand: expand)
        }
        // Detail-block fold chevron — the same vertical arrow the InstantPage V2 renderer uses.
        self.editorView.detailsChevronImage = UIImage(bundleImageName: "Item List/ExpandingItemVerticalRegularArrow")?.withRenderingMode(.alwaysTemplate)
        // A selection-handle ("knob") drag must NOT be hijacked by the interactive keyboard-/modal-dismiss
        // gestures. Those Display flags can only be set host-side (the editor package can't import Display) and
        // are applied to the hit-testable handle views, so the effect is scoped to knob interaction — not the
        // whole editor surface.
        self.editorView.configureSelectionHandleView = { handle in
            handle.disablesInteractiveTransitionGestureRecognizer = true   // navigation back-swipe (the one a horizontal knob drag triggers)
            handle.disablesInteractiveModalDismiss = true
            handle.disablesInteractiveKeyboardGestureRecognizer = true
        }

        // Seed an editable document. RichTextEditorView starts with ZERO blocks — its canvas is only
        // populated by the `document` setter (which normalizes an empty Document to a single empty body
        // paragraph). Every proven host (RichTextAttachmentScreen, the Demo) seeds a document at setup. We
        // MUST do it here too: our `attributedText` setter's composerContentEqual guard skips the panel's
        // initial empty push (""=="" → no-op), so without this the canvas would have no paragraph box to
        // insert into and typing would do nothing.
        self.editorView.document = Document()

        // Phase 1 delegate subset: the editor exposes onChange + the two focus transitions. The panel's
        // height/state refresh keys off chatInputTextNodeDidUpdateText (it then reads `attributedText`).
        // The remaining ChatInputTextNodeDelegate methods (chatInputTextNodeDidChangeSelection,
        // chatInputTextNodeBackspaceWhileEmpty, chatInputTextNodeMenu, chatInputTextNode(shouldChangeTextIn:),
        // chatInputTextNodeShouldCopy/Paste, chatInputTextNodeShouldRespondToAction/TargetForAction) require
        // new RichTextEditorView callbacks and are deferred to Phase 2 — the editor handles selection/menu/
        // backspace internally, so omitting them only means the panel doesn't receive those hooks.

        // Hardware Return → the panel's send-on-Enter / send-on-⌘-Enter decision (chatInputTextNodeShouldReturn
        // returns true to insert a newline, false when it sent the message). Without this a hardware Return
        // just inserted a paragraph break and never sent — the legacy backend wired this via
        // ChatInputTextViewImpl's own \r keyCommand; the native editor surfaces it as onHardwareReturn.
        self.editorView.onHardwareReturn = { [weak self] modifierFlags in
            return self?.storedDelegate?.chatInputTextNodeShouldReturn(modifierFlags: modifierFlags) ?? true
        }

        // The caret's own signal, answered by re-applying the field's CURRENT geometry with the
        // reveal attached. `.immediate` on purpose: when the panel is growing the field it is already
        // animating that height, and animating the offset inside it animates the text twice; and a
        // reveal owed to a caret that moved must settle before the next key event in any case.
        //
        // This is also what makes the composer's flicker impossible rather than merely unlikely: the
        // editor no longer scrolls between the keystroke and the panel's pass, so there is no
        // intermediate state for the height animation to fight.
        self.editorView.onCaretRevealNeeded = { [weak self] in
            guard let self, self.editorView.bounds.width > 0.0 else { return }
            self.layoutInputField(caretReveal: .ifNeeded(.immediate))
        }

        self.editorView.onChange = { [weak self] in
            guard let self else { return }
            // RichTextEditorView is parent-driven: it does NOT self-layout on a content change (unlike the
            // legacy UITextView backend, which renders its own edits). The host must call `update(...)` in
            // response to `onChange`, or inserted text is never laid out — it appears that "typing does
            // nothing". Re-lay it out here at the current committed size (mirrors RichTextAttachmentScreen's
            // onChange → re-run-layout). `update`/`performLayout` never fire `onChange` synchronously
            // (the editor's contract, covered by a regression test), so this cannot recurse. The panel's
            // delegate-driven layout pass still handles field-height growth separately.
            if self.editorView.bounds.width > 0.0 {
                _ = self.editorView.update(size: self.editorView.bounds.size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins, scrollIndicatorInsets: self.trackedScrollIndicatorInsets)
            }
            // Report "typing…" chat activity ONLY on a genuine user text edit. `onChange` also fires on a
            // caret/selection move (text unchanged ⇒ no report) and on a programmatic content set (suppressed
            // by `isApplyingProgrammaticContent`). This matches the legacy backend, which reports activity from
            // `chatInputTextNode(shouldChangeTextIn:)` — a delegate the native editor never invokes. Reading the
            // plain text is the existing hot-path send-counter read; the diff keeps cursor taps off the wire.
            let currentText = self.text
            if !self.isApplyingProgrammaticContent && currentText != self.lastTypingActivityText {
                self.onTypingActivity?()
            }
            self.lastTypingActivityText = currentText
            self.storedDelegate?.chatInputTextNodeDidUpdateText()
        }
        self.editorView.onBecameFirstResponder = { [weak self] in
            self?.storedDelegate?.chatInputTextNodeDidBeginEditing()
        }
        self.editorView.onResignedFirstResponder = { [weak self] in
            self?.storedDelegate?.chatInputTextNodeDidFinishEditing()
        }

        // Custom-emoji rendering. The editor hosts each inline emoji via this provider, asking by the
        // `EmojiRef` fileId string. Forward to the chat host's `emojiViewProvider` (set by the panel),
        // passing a `ChatTextInputTextCustomEmojiAttribute`. Prefer the file-bearing attribute cached from a
        // file-carrying push/type (`customEmojiAttributes`, harvested so the file is available immediately);
        // otherwise build a FILE-LESS attribute so the renderer (`InlineStickerItemLayer`) resolves the file
        // by fileId via `resolveInlineStickers`. The file-less fallback is REQUIRED for a draft-restored /
        // entity-only emoji: a draft persists only the fileId, so its `file` is nil and it was never cached —
        // without the fallback the guard returned nil and the restored emoji rendered blank ("lost"). This
        // mirrors the legacy node, which passes its attribute straight to the provider and relies on the same
        // renderer fallback. The closure reads `self.emojiViewProvider` lazily, so the panel may set it after
        // this registration. `size` is ignored: the host renderer picks its own point size and the editor
        // frames the returned view to the glyph rect.
        // The host owns "(language, text) -> colours": `asyncStanaloneSyntaxHighlight` runs libprisma off
        // the main queue and returns the same cache model the message path stores, baking the LIGHT
        // palette — so what the editor shows is what the sent message will show. The editor cannot do
        // this itself; it cannot see TextFormat or libprisma.
        self.editorView.registerSyntaxHighlighter { language, text, completion in
            let spec = CachedMessageSyntaxHighlight.Spec(language: language, text: text)
            let _ = (asyncStanaloneSyntaxHighlight(current: nil, specs: [spec])
            |> deliverOnMainQueue).start(next: { result in
                let entities = result.values[spec]?.entities ?? []
                completion(entities.map { entity in
                    RichTextSyntaxToken(
                        range: NSRange(location: entity.range.lowerBound,
                                       length: entity.range.upperBound - entity.range.lowerBound),
                        color: UIColor(rgb: UInt32(bitPattern: entity.color)))
                })
            })
        }
        self.editorView.registerEmojiViewProvider { [weak self] id, _ in
            guard let self, let fileId = Int64(id), let provider = self.emojiViewProvider else { return nil }
            let attribute = self.customEmojiAttributes[fileId]
                ?? ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil)
            guard let view = provider(attribute) else { return nil }
            // The panel-supplied provider is typed `-> UIView?` (the `ChatRichTextInputNode` protocol seam),
            // but it hands back an `EmojiTextAttachmentView` — a `RichTextEmojiView` (conformance declared in
            // `ChatTextInputPanelNode`) — so the editor can keep its `dynamicColor` synced to the text color.
            // A non-conforming fallback view resolves to nil (the editor retries on the next layout pass).
            return view as? (UIView & RichTextEmojiView)
        }

        // Formula rendering is owned by the chat host; math-rendering dependencies live above this module.
        // Reinstalling when the provider arrives after `didLoad` reloads already-present formula atoms.
        self.updateFormulaRenderer()

        self.updateButtonIconProvider()

        // Media rendering. The editor hosts each `.media` block via this provider, asking by the opaque host
        // `mediaID` (the node's own key, recorded in `mediaByID` by `registerMediaValue`). Resolve it back to
        // the concrete `Media` and hand it + the natural size to the panel-supplied factory, which builds the
        // hosted view (it owns `AccountContext`). WITHOUT this, a `.media` block set via the model round-trips
        // but never renders. Both `mediaItemViewFactory` and `mediaByID` are read LAZILY, so the panel may set
        // the factory after this registration. The returned `(UIView & RichTextMediaItemView)?` is assignable
        // to the provider's `RichTextMediaItemView?` return type.
        self.editorView.registerMediaViewProvider { [weak self] items, _, _, existing in
            guard let self, let factory = self.mediaItemViewFactory else { return nil }
            let resolved: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)] = items.compactMap { item in
                guard let media = self.mediaByID[item.mediaID] else { return nil }
                return (media, item.naturalSize, item.isSpoiler, item.kind)
            }
            guard !resolved.isEmpty else { return nil }
            return factory(resolved, existing)
        }

        // Bridge the editor's account-free media-control request to the owner-facing context: resolve the
        // concrete media from the opaque mediaID (may repeat across blocks — the request's `delete` is
        // already bound to the exact occurrence) and hand the panel a MediaControlContext.
        self.editorView.onRequestMediaControl = { [weak self] request in
            guard let self, let media = self.mediaByID[request.mediaID] else { return }
            self.onRequestMediaControl?(MediaControlContext(
                media: media,
                control: request.control,
                sourceView: request.view,
                sourceRect: request.sourceRect,
                delete: request.delete,
                isSpoiler: request.isSpoiler,
                toggleSpoiler: request.toggleSpoiler,
                replace: request.replace,
                addMore: request.addMore
            ))
        }

        // Checklist checkbox rendering. The editor hosts each checklist item's checkbox via this provider,
        // asking for the current `checked` state. Build a `CheckNode`-backed view themed from the checkbox
        // colors threaded across the `ChatRichTextThemeColors` seam (the node holds no `PresentationTheme`).
        // The colors are read LAZILY, so a theme change applied after this registration takes effect on the
        // next-built checkbox. When this provider is unset the editor falls back to its glyph marker.
        self.editorView.registerChecklistMarkerViewProvider { [weak self] checked, _ in
            guard let self else { return nil }
            let nodeTheme = CheckNodeTheme(backgroundColor: self.checkboxFill, strokeColor: self.checkboxForeground, borderColor: self.checkboxBorder, overlayBorder: false, hasInset: false, hasShadow: false)
            return HostChecklistCheckboxView(theme: nodeTheme, checked: checked)
        }
    }

    // MARK: Display (Task 3)
    public var attributedText: NSAttributedString? {
        get { ComposerDocumentBridge.attributedString(from: self.editorView.document, baseFontSize: self.baseFontSize) }
        set {
            let incoming = newValue ?? NSAttributedString(string: "")
            // Harvest file-bearing custom-emoji attributes so the editor's fileId-only emoji-view provider
            // can rebuild them (`document(from:)` keeps only the fileId in the `EmojiRef`, dropping the
            // `TelegramMediaFile` the renderer needs). Done BEFORE the equality guard so the cache stays
            // current even when the document is not rebuilt. Only cache a file-BEARING attribute, so a later
            // file-less round-trip (the getter emits `file: nil`) never clobbers a resolved one.
            incoming.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: incoming.length), options: []) { value, _, _ in
                if let attribute = value as? ChatTextInputTextCustomEmojiAttribute, attribute.file != nil {
                    self.customEmojiAttributes[attribute.fileId] = attribute
                }
            }
            let current = ComposerDocumentBridge.attributedString(from: self.editorView.document, baseFontSize: self.baseFontSize)
            if ComposerDocumentBridge.composerContentEqual(incoming, current) {
                return
            }
            // Programmatic set: the assignment fires `onChange` synchronously (reload → setBlocks →
            // notifyContentSizeChanged); flag it so that isn't mistaken for the user typing.
            self.isApplyingProgrammaticContent = true
            self.editorView.document = ComposerDocumentBridge.document(from: incoming)
            self.isApplyingProgrammaticContent = false
        }
    }
    public var text: String {
        // What the panel's length COUNTER and a length-limited edit's Send guard count
        // (`updateCounterTextNode`, `sendButtonPressed`): the text the text route SENDS — every flat-axis
        // block's text joined by "\n", as `ChatInputContent.plainText` and the chat's `inputText` lay it out.
        // A code block counts its body (sent as a `Pre`, the language is entity data, not text); a pull quote
        // its text; a quote its children, a FOLDED one too (the send expands it); media, tables, details and
        // button rows nothing (they go on the rich route, which no limit counts). Until p24 only paragraphs
        // and quotes counted, so a caption edit whose code block took it over the limit showed no counter and
        // passed the guard (composer harness p24, `HarnessLengthCounterCodeBlockTests`). Read straight from the
        // document — this is a hot path (every keystroke) — rather than through the full conversion.
        func blockText(_ block: Block) -> String? {
            switch block {
            case .paragraph(let p): return p.text
            case .code(let code): return code.text
            case .pullQuote(let quote): return quote.text
            case .blockQuote(let bq): return bq.children.compactMap(blockText).joined(separator: "\n")
            case .media, .table, .details, .buttonRow: return nil
            }
        }
        return self.editorView.document.blocks.compactMap(blockText).joined(separator: "\n")
    }

    // Content-aware emptiness read STRAIGHT from the live document (like `text` — no ChatInputContent build,
    // no emoji/media resolvers). A direct walk is REQUIRED: `chatInputContent(fromDocument:)` with absent
    // resolvers DROPS an unresolvable media block, which would reintroduce the "media reads as empty" bug.
    public var inputContentIsEmpty: Bool {
        let blocks = self.editorView.document.blocks
        guard blocks.count <= 1 else { return false }
        guard let block = blocks.first else { return true }
        switch block {
        case let .paragraph(p): return p.text.isEmpty
        case let .code(c): return c.text.isEmpty
        case let .pullQuote(pq): return pq.text.isEmpty
        case .media, .table, .blockQuote, .details, .buttonRow: return false
        }
    }
    public var inputContentIsEmptyWhitespaceTrimmed: Bool {
        return self.editorView.document.blocks.allSatisfy { block in
            switch block {
            case let .paragraph(p): return p.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case let .code(c): return c.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case let .pullQuote(pq): return pq.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .media, .table, .blockQuote, .details, .buttonRow: return false
            }
        }
    }
    // MARK: ChatInputContent model — the STRUCTURAL draft currency (direct bridge)

    /// The node's content as the canonical `ChatInputContent` value model. This is the chat layer's draft/state
    /// read-back (the panel's `inputTextState` reads it, NOT `attributedText`), so it MUST carry the structural
    /// blocks the `NSAttributedString` vocabulary can't express — media / tables / heading & list information.
    /// We convert the editor's live `Document` STRAIGHT to `ChatInputContent` via the direct bridge
    /// (`chatInputContent(fromDocument:)`), bypassing the lossy `Document → NSAttributedString` hop the default
    /// protocol implementation (and the legacy `attributedText` getter) take. The resolvers map the editor's
    /// opaque host keys to concrete chat-layer values: an unresolvable emoji degrades to plain text and an
    /// unresolvable medium is dropped (see `resolveEmojiRef`/`resolveMediaID`). The selection rides the editor's
    /// flat composer coordinate space (`selectedRange`), mapped into the content's structural selection — the
    /// same mapping the default implementation uses.
    public func currentInputContent() -> (content: ChatInputContent, selection: ChatInputSelection) {
        let content = chatInputContent(
            fromDocument: self.editorView.document,
            resolveEmoji: { [weak self] emojiRef in self?.resolveEmojiRef(emojiRef) ?? nil },
            resolveMedia: { [weak self] mediaID in self?.resolveMediaID(mediaID) ?? nil }
        )
        return (content, ChatInputSelection(nsRange: self.selectedRange, in: content))
    }

    /// Replace the editor's content from a `ChatInputContent`. This is the chat layer's structural SET path
    /// (draft restore, send-clear, spoiler re-decorate): it MUST land the structural blocks back into the editor
    /// `Document`, so we convert STRAIGHT via the direct bridge (`document(fromChatInputContent:)`) rather than
    /// through the flattening `attributedText` setter. The registrars hand the chat-layer identity to the node's
    /// caches and return the editor-side ref/key: `registerEmoji` records the `TelegramMediaFile` so the editor's
    /// emoji-view provider can render it, and `registerMedia` records the `Media` so a later `currentInputContent`
    /// can resolve it back. Sets the editor's live document directly (NOT via `attributedText`, which would
    /// flatten structure beyond the `ChatTextInputAttributes` vocabulary, e.g. tables) and runs the same refresh
    /// `onChange` performs (so the panel re-lays-out and re-reads content), preserving the refresh/`didUpdateText`
    /// ordering, then restores the flat composer selection.
    /// **Whose caret is it?** While the editor has focus, the editor's — and a content-equal
    /// `setInputContent` may not move it.
    ///
    /// The host's copy of the selection is a LAGGING MIRROR. The editor reports a selection change
    /// asynchronously (coalesced to the next run-loop turn, `scheduleSelectionDrivenOnChange`), and
    /// the chat interface state then takes its own turns to settle, so any layout pass in that window
    /// re-applies a selection older than the one the editor holds. Measured on K3 against the shipped
    /// build, breakpointing `-[IDBlockTextView setSelectedTextRange:]` and printing the caller —
    /// three taps, each placing the caret and each overwritten ~100ms later by the echo:
    ///
    ///     tap  -> 39   (no composer frames)
    ///     echo -> 15   via RichTextEditorChatInputNode.setInputContent
    ///
    /// 15 was the caret from the PREVIOUS tap. Reported as "I tapped the input field somewhere, the
    /// cursor blinked there briefly, and moved"; intermittent because it needs a chat state update to
    /// land inside that window. Reproduced from a clean launch, so it is not an artifact of the probe.
    ///
    /// The focus test is what keeps this from being "never move the caret": an UNFOCUSED set is the
    /// host legitimately placing a caret the editor has no opinion about — a draft restore, a
    /// programmatic move — and that still applies. A focused caret move with UNCHANGED content does
    /// not otherwise exist: an edit changes content and takes the rebuild branch, and the panel's own
    /// deliberate moves go through `selectedRange` directly rather than through here.
    ///
    /// `wouldCollapseLiveRange` predates this and is kept because it covers the case where the editor
    /// is NOT focused yet still holds a range. It was the same race found one branch earlier — a
    /// double-tap word selection collapsing back to a caret — and fixing only the shape that had been
    /// seen is how the caret-to-caret half survived.
    ///
    /// Static and pure so it can be tested: constructing a `RichTextEditorChatInputNode` reaches
    /// `AccountContext`, which a test bundle cannot link (see the project `CLAUDE.md`'s
    /// `ios_unit_test` dep-link ceiling), which is the same reason `storedMargins` /
    /// `measurementMargins` are static.
    internal static func echoedSelectionShouldApply(target: NSRange,
                                                    live: NSRange,
                                                    editorHasFocus: Bool) -> Bool {
        if target == live { return false }
        // A content-equal set that would COLLAPSE the editor's live RANGE to a caret is always a
        // lagging echo, focused or not.
        if live.length > 0 && target.length == 0 { return false }
        // The editor owns its caret while it has focus.
        if editorHasFocus { return false }
        return true
    }

    /// How many `performUndoableInputChange` bodies are running: a content-changing
    /// `setInputContent` inside one is the user's edit, applied as one undo step.
    private var undoableInputChangeDepth: Int = 0

    public func performUndoableInputChange(_ body: () -> Void) {
        self.undoableInputChangeDepth += 1
        defer { self.undoableInputChangeDepth -= 1 }
        body()
    }

    /// The chat's insert on the user's behalf (its emoji keyboard, the avatar menu's Mention), made
    /// through the editor at its own selection (`RichTextEditor.insertInlineRunsOnUsersBehalf`) instead
    /// of through a transform of the flat input state, which retyped every block as body. The text is
    /// converted through the same bridge a content set uses, so a custom emoji's file is registered
    /// for the editor's emoji-view provider exactly as it would be by `setInputContent`. `false` — the
    /// editor has no such verb (the non-engine native editor) — leaves the chat on its old path.
    public func insertTextOnUsersBehalf(_ text: NSAttributedString) -> Bool {
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: chatInputRuns(fromAttributedString: text)))])
        let converted = document(
            fromChatInputContent: content,
            registerEmoji: { [weak self] fileId, file in self?.registerEmojiRef(fileId: fileId, file: file) ?? EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil) },
            registerMedia: { [weak self] media in self?.registerMediaValue(media) ?? "" }
        )
        var runs: [TextRun] = []
        for block in converted.blocks {
            if case let .paragraph(paragraph) = block {
                runs.append(contentsOf: paragraph.runs)
            }
        }
        return self.editorView.insertInlineRunsOnUsersBehalf(runs)
    }

    public func setInputContent(_ content: ChatInputContent, selection: ChatInputSelection) {
        // CONTENT-EQUALITY GUARD (the load-bearing fix for "selection/scroll reset at random times").
        //
        // The chat composer re-applies the whole `effectiveInputState` through this method on EVERY chat
        // state update: `ChatControllerNode.updateLayout` calls `updateInputTextState` whenever
        // `effectiveInputState` changes — which covers not just genuine external sets (draft restore,
        // send-clear) but also the editor's OWN edits/caret-moves echoed back through the interface state,
        // and any unrelated state update that recomputes the compose/edit input state.
        //
        // Rebuilding the document on each of those is destructive: `self.editorView.document =` runs
        // `canvas.reload` (tears down + rebuilds every block box, resetting the canvas selection) + a full
        // `performLayout` (resets the scroll offset to the top). So an UNCHANGED round-trip would reset the
        // scroll position (visible once the field has grown tall enough to scroll) and churn the live
        // selection through the flat↔structural mapping — surfacing as the caret/selection jumping at
        // seemingly random times.
        //
        // Skip the rebuild when the incoming content already matches what the editor shows, mirroring the
        // legacy backend (`ChatInputTextNodeImpl.attributedText`'s `if self.attributedText != value`) and
        // the native `attributedText` setter's `composerContentEqual` short-circuit. When content is equal we
        // only move the caret if the requested selection actually differs from the live one — so the common
        // no-op echo (the editor's own edit pushed up and applied back) leaves scroll AND selection
        // untouched, while a deliberate programmatic caret move still takes effect.
        let currentContent = self.currentInputContent().content
        if currentContent == content {
            let targetRange = selection.nsRange(in: content)
            let liveRange = self.editorView.composerSelectedRange
            // STALE-SELECTION GUARD (the double-tap "flash then deselect" fix).
            //
            // The editor reports a selection change to the host ASYNCHRONOUSLY (coalesced to the next runloop
            // turn, so a backspace's transient delete-range isn't observed). So right after a gesture RANGE
            // selection (double-tap word / triple-tap paragraph / Select-All), the editor holds the range but
            // the chat interface state STILL carries the pre-selection caret. The `presentEditMenu()` that
            // fires immediately after the selection drives a synchronous chat layout pass → this method with
            // that LAGGING caret as `selection`, which would collapse the just-made range back to a caret
            // (device-log-verified). The editor's own async notification settles the interface state to the
            // range a turn later, so this is purely a transient echo.
            //
            // A content-equal set that would COLLAPSE the editor's live RANGE to a caret is always that lagging
            // echo — a real edit changes content (→ the rebuild branch below), and a deliberate caret move goes
            // through the editor first (so `liveRange` is already that caret). Skip it and keep the live range;
            // every other move (including the unfocused/programmatic caret set) still applies.
            if Self.echoedSelectionShouldApply(target: targetRange,
                                               live: liveRange,
                                               editorHasFocus: self.editorView.isFirstResponder) {
                self.selectedRange = targetRange
            }
            return
        }

        let newDocument = document(
            fromChatInputContent: content,
            registerEmoji: { [weak self] fileId, file in self?.registerEmojiRef(fileId: fileId, file: file) ?? EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil) },
            registerMedia: { [weak self] media in self?.registerMediaValue(media) ?? "" }
        )
        // Programmatic set (draft restore / send-clear / state echo): the assignment fires `onChange`
        // synchronously (reload → setBlocks → notifyContentSizeChanged); flag it so the typing-activity
        // path in `onChange` doesn't treat this structural re-apply as the user typing.
        let applyDocument = {
            self.isApplyingProgrammaticContent = true
            self.editorView.document = newDocument
            self.isApplyingProgrammaticContent = false
        }
        if self.undoableInputChangeDepth > 0 {
            // The USER's edit through the chat (`performUndoableInputChange`: autocomplete, the emoji
            // keyboard, Translate…): ONE undo step on top of the stack, so both the edit and the typing
            // before it stay undoable (composer harness, `HarnessChatSideEditUndoTests`). Emptying the
            // stack here made a picked mention un-undoable and took the typed "@al" with it.
            self.editorView.performAsOneUndoStep(applyDocument)
        } else {
            applyDocument()
            // An EXTERNAL set (a draft sync, Send's clear, anything the chat pushes that differs from
            // what the editor holds) empties the undo and redo stacks, as a stock `UITextView` and the
            // legacy composer do on a set: a step typed before it would restore the document as it was
            // BEFORE the set and throw the pushed content away (composer harness p15,
            // `HarnessExternalSetUndoTests`). The echo above returned before this and keeps the stack.
            self.editorView.discardUndoHistory()
        }
        if self.editorView.bounds.width > 0.0 {
            _ = self.editorView.update(size: self.editorView.bounds.size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins, scrollIndicatorInsets: self.trackedScrollIndicatorInsets)
        }
        self.storedDelegate?.chatInputTextNodeDidUpdateText()
        self.selectedRange = selection.nsRange(in: content)
        // A set the editor NORMALISES is reported back, so the chat's copy — what Send reads — is what the
        // editor shows. BY CONSTRUCTION, not by a list: whenever the read-back after the set differs from the
        // content set, the editor changed something on the way in — a line break in a one-line field
        // (`EngineDocumentBridge.oneLineText`), inline code over an entity (`withoutInlineCodeOverLinks`), a
        // multi-emoji custom-emoji run, formatting / an entity / an atom in a code body (`plainCodeRuns`), an
        // empty code language, `U+2028` / CR / `U+2029` in a body (read back as "\n"), a coalesced pair of formulas
        // — and any normalisation added later is covered without touching this. Until p24 a hand-kept list
        // (`holdsContentTheEditorNormalises`, p23) named three of them and the chat sent the others as set
        // (composer harness p24, `HarnessUnreportedSetNormalisationTests`). The report above is swallowed while
        // the panel is pushing this very set (`ignoreChatInputTextNodeDidUpdateText`), so it goes a turn later;
        // the echo it causes is content-equal and returns at the guard above.
        if self.currentInputContent().content != content {
            DispatchQueue.main.async { [weak self] in
                self?.storedDelegate?.chatInputTextNodeDidUpdateText()
            }
        }
    }

    /// Direct-bridge `resolveEmoji`: map an editor `EmojiRef` (whose `id` is the fileId STRING, by the node's
    /// convention) to the chat layer's `(fileId, file)`. The `file` comes from the node's `customEmojiAttributes`
    /// cache (the editor drops the `TelegramMediaFile`), or nil if this emoji wasn't seen via a file-bearing push.
    /// A non-numeric `id` (should not occur from this path) returns nil ⇒ the run degrades to plain text, matching
    /// `ComposerDocumentBridge`'s fallback.
    private func resolveEmojiRef(_ emojiRef: EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)? {
        guard let fileId = Int64(emojiRef.id) else {
            return nil
        }
        return (fileId, self.customEmojiAttributes[fileId]?.file)
    }

    /// Direct-bridge `registerEmoji`: cache the `TelegramMediaFile` (mirroring the `attributedText`-setter
    /// harvest — only a file-BEARING attribute is recorded, so a file-less round-trip never clobbers a resolved
    /// one) and mint the editor `EmojiRef` keyed by the fileId string (the node's convention; `instanceID` via the
    /// editor's `BlockID.generate()`, as `ComposerDocumentBridge` does).
    private func registerEmojiRef(fileId: Int64, file: TelegramMediaFile?) -> EmojiRef {
        if let file {
            self.customEmojiAttributes[fileId] = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: file)
        }
        return EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil)
    }

    /// Direct-bridge `resolveMedia`: map the editor's opaque `mediaID` back to the concrete `Media` the node
    /// cached when it last received it (`registerMediaValue`). Nil ⇒ the media block is dropped on read-back
    /// (an unresolved medium has no `ChatInputMedia` representation).
    private func resolveMediaID(_ mediaID: String) -> EngineMedia? {
        return self.mediaByID[mediaID]
    }

    /// Direct-bridge `registerMedia`: cache the `Media` under a stable opaque key (`composerMediaKey`, the
    /// `"namespace:id"` convention shared with `RichTextAttachmentScreen.attachedMedia`) and hand that key to
    /// the editor. The editor stores only this opaque key (it never holds a `Media`); the node's media-view
    /// provider (registered in `didLoad`) resolves the key back through `mediaByID` to render the block. The
    /// key also round-trips `currentInputContent → setInputContent` consistently, which an id-derived key does.
    private func registerMediaValue(_ media: EngineMedia) -> String {
        let mediaID = composerMediaKey(media)
        self.mediaByID[mediaID] = media
        return mediaID
    }

    /// Map the host's theme colors 1:1 into the editor's `RichTextEditorTheme`. Assigning `editorView.theme`
    /// re-applies colors and redraws (see `RichTextEditorView.theme`).
    public func applyRichTextTheme(_ colors: ChatRichTextThemeColors) {
        // Store the checklist checkbox colors for the marker provider (registered in `didLoad`), which reads
        // them lazily — so this theme change takes effect on the next-built checkbox.
        self.checkboxFill = colors.listCheckFillColor
        self.checkboxForeground = colors.listCheckForegroundColor
        self.checkboxBorder = colors.listCheckBorderColor
        
        self.editorView.theme = RichTextEditorTheme(
            primaryText: colors.primaryText,
            secondaryText: colors.secondaryText,
            placeholder: colors.placeholder,
            accent: colors.accent,
            tableBorder: colors.tableBorder,
            tableHeaderBackground: colors.tableHeaderBackground,
            codeBackground: colors.tableHeaderBackground,  // a code band reads as a highlighted table row — the same fill, deliberately
            containerPlaceholder: colors.placeholder.mixedWith(colors.accent, alpha: 0.15).withMultipliedBrightnessBy(colors.primaryText.brightness >= 0.4 ? 1.1 : 0.9).withMultipliedAlpha(0.8),
            shadowCursor: colors.shadowCursor,
            quoteAuthorText: colors.quoteAuthorText,
            quoteAuthorPlaceholder: colors.quoteAuthorPlaceholder
        )
    }

    // MARK: Layout (Task 4)
    /// The panel sets `textFieldFrame` (the child's frame) separately; this lays the editor's content out at
    /// `size` using the tracked scroll insets + content margins. Trailing scroll inset stays `.zero` in
    /// Phase 1 (the composer field is short and grows; the keyboard inset is the panel's concern).
    public func updateLayout(size: CGSize) {
        self.updateLayout(size: size, caretReveal: .none)
    }

    public func updateLayout(size: CGSize, caretReveal: RichTextEditorCaretReveal) {
        _ = self.editorView.update(size: size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins, scrollIndicatorInsets: self.trackedScrollIndicatorInsets, caretReveal: caretReveal)
    }
    /// Measures the editor's content height at `width` with a stateless, side-effect-free measure
    /// (`RichTextEditorView.height(forWidth:)`) — it does NOT reflow the live editor or touch its
    /// frames/insets. `rightInset` is recorded for the next real `update(...)`.
    ///
    /// Passes `trackedContentMargins` (the margins the next `update(...)` will apply) so the measure reserves
    /// the right inset even when the panel sizes its field BEFORE the editor has been laid out — a draft
    /// applied before the first layout. Without this the live canvas margins are still zero, the text is
    /// measured at the full width, and the field is sized one wrap too short, then visibly grows on the next
    /// pass (the pre-set-text "jump").
    public func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        self.trackedRightInset = rightInset
        return self.editorView.height(forWidth: width,
                                      contentMargins: Self.measurementMargins(applying: rightInset,
                                                                              to: self.trackedContentMargins))
    }
    public func measuredTextFieldHeight(forWidth width: CGFloat, lineCount: Int) -> CGFloat {
        // Measure the probe with THIS composer's live content margins (the same value the live `textHeightForWidth`
        // passes), so the probe's vertical inset matches the real field and the 3-line size is exact.
        return RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: lineCount, contentMargins: self.trackedContentMargins, configure: { editor in
            RichTextEditorChatInputNode.applyComposerLayoutMetrics(to: editor)
        })
    }
    /// `caretReveal` defaults to `.none`, which is right for every caller that is laying the field
    /// out for some other reason — a theme change, a draft being applied, the send-options preview.
    /// The panel passes `.ifNeeded` on the pass that applies a NEW field size, which is the pass the
    /// caret's visibility actually depends on.
    public func layoutInputField() {
        self.layoutInputField(caretReveal: .none)
    }

    public func layoutInputField(caretReveal: RichTextEditorCaretReveal) {
        _ = self.editorView.update(size: self.editorView.bounds.size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins, scrollIndicatorInsets: self.trackedScrollIndicatorInsets, caretReveal: caretReveal)
    }
    public var textFieldFrame: CGRect {
        get { self.editorView.frame }
        set { self.editorView.frame = newValue }
    }
    public var inputView: UIView { self.editorView }
    /// **The panel's vertical insets are a SYMMETRIC pair, and this must not break them.**
    ///
    /// The field's total vertical inset is the node's frame inset plus this one:
    /// `textInputViewInternalInsets` is top 5.0 / bottom 4.0 and `calculateTextFieldRealInsets`
    /// returns top 4.5 / bottom 5.5 at the 17pt base size, which sums to **9.5 / 9.5** — the two
    /// halves are deliberately lopsided in opposite directions so the total is even, and the legacy
    /// text view gets exactly that.
    ///
    /// This accessor used to subtract 1.0 from the bottom on the way in and add it back on the way
    /// out. The round trip was lossless, so nothing read the difference — but what was STORED, and
    /// therefore what the field laid out and measured against, was 4.5 / 4.5, making the total
    /// 9.5 / 8.5. The text sat a point high in the panel and the field measured a point shorter than
    /// the legacy one for the same content. (The `top ± 0.0` beside it was a fossil of the same
    /// edit.) Removing both halves keeps the round trip lossless and restores the pair.
    public var textContainerInset: UIEdgeInsets {
        get {
            var updated = self.trackedContentMargins
            updated.right -= Self.accessoryReservation
            return updated
        }
        set { self.trackedContentMargins = Self.storedMargins(forPanelInset: newValue) }
    }

    /// The extra right margin the field reserves beyond what the panel asks for.
    internal static let accessoryReservation: CGFloat = 14.0

    /// What the field's margins ARE, for a set of panel insets. One function, because the measure and
    /// the layout must agree about the column: a draft measured against a wider column than it is laid
    /// out in wraps into fewer lines, and the field is built one line too short.
    internal static func storedMargins(forPanelInset inset: UIEdgeInsets) -> UIEdgeInsets {
        var updated = inset
        updated.right += accessoryReservation
        return updated
    }

    /// The margins a measure should use, given the right inset the caller is committing to THIS pass.
    ///
    /// It is not `trackedContentMargins`: the panel measures the field's height and applies the real
    /// insets afterwards, in the same pass, so the tracked value is one pass stale. Measured in the
    /// running app while opening a chat, the panel asked for a right inset of 88 while the tracked
    /// margins still said 56 — 46pt of column the text would not get, which is how a seven-line draft
    /// measured as six and opened scrolling inside a six-line field.
    internal static func measurementMargins(applying rightInset: CGFloat,
                                            to tracked: UIEdgeInsets) -> UIEdgeInsets {
        var updated = tracked
        updated.right = storedMargins(forPanelInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0,
                                                                  right: rightInset)).right
        return updated
    }
    public var currentRightInset: CGFloat { self.trackedRightInset }

    // MARK: Editing & focus (Task 5)
    public func deleteBackward() { self.editorView.deleteBackward() }
    public var isInputFirstResponder: Bool { self.editorView.isEditorFirstResponder }
    @discardableResult public func makeInputFirstResponder() -> Bool { self.editorView.becomeFirstResponder() }
    @discardableResult public func resignInputFirstResponder() -> Bool { self.editorView.resignEditorFirstResponder() }
    public func applyAutocorrection() { self.editorView.finalizeComposerMarkedText() }

    // MARK: Context menu + native format routing
    public var usesNativeRichTextEngine: Bool { true }

    public var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? {
        get { self.editorView.contextMenuItemsProvider }
        set { self.editorView.contextMenuItemsProvider = newValue }
    }

    public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? {
        get { self.editorView.onRequestTableStructuralMenu }
        set { self.editorView.onRequestTableStructuralMenu = newValue }
    }

    /// Set by the panel; invoked (with a resolved `EngineMedia`) when the editor reports a media control tap.
    public var onRequestMediaControl: ((MediaControlContext) -> Void)?

    public var canPasteMedia: (() -> Bool)? { didSet { self.editorView.canPasteMedia = canPasteMedia } }
    public var onPasteMedia: (() -> Bool)? { didSet { self.editorView.onPasteMedia = onPasteMedia } }
    public var pastedMarkdownFragmentParser: ((String) -> Document?)? { didSet { self.editorView.plainTextFragmentTransformer = self.pastedMarkdownFragmentParser } }

    public func performFormatAction(_ action: ChatRichTextFormatAction) {
        switch action {
        case .bold: self.editorView.toggleBold()
        case .italic: self.editorView.toggleItalic()
        case .strikethrough: self.editorView.toggleStrikethrough()
        case .underline: self.editorView.toggleUnderline()
        case .monospace: self.editorView.toggleInlineCode()
        case .spoiler: self.editorView.toggleSpoiler()
        case .quote: self.editorView.wrapInBlockQuote()
        case .pullQuote: self.editorView.makePullQuote()
        case .code: self.editorView.makeCodeBlock()
        case .date:
            // TODO: no timestamp-entity model in the editor (deferred). No-op for now.
            break
        case .clearFormatting: self.editorView.clearInlineFormatting()
        }
    }

    public func canPerformFormatAction(_ action: ChatRichTextFormatAction) -> Bool {
        switch action {
        case .italic: return self.editorView.italicReachesSelection
        case .bold, .strikethrough, .underline, .spoiler: return self.editorView.inlineFormatsReachSelection
        // Not over a mention, a date or a link (composer harness p23, `HarnessInlineCodeOverEntityTests`).
        case .monospace: return self.editorView.inlineCodeReachesSelection
        case .quote, .pullQuote, .code, .date, .clearFormatting: return true
        }
    }

    public func performRichPaste() {
        self.editorView.pasteFromPasteboard()
    }

    public func currentRichTextLinkURL() -> String? { self.editorView.currentLink() }
    public func selectedRichText() -> String { self.editorView.selectedText() }
    public func applyRichTextLink(_ url: String?) {
        if let url, !url.isEmpty {
            self.editorView.setLink(url)
        } else {
            self.editorView.removeLink()
        }
    }

    public var keyboardInputView: UIView? {
        get { self.editorView.customInputView }
        set { self.editorView.customInputView = newValue }
    }
    public func reloadInputViews() { self.editorView.reloadComposerInputViews() }
    public var inputDelegate: ChatInputTextNodeDelegate? {
        get { self.storedDelegate }
        set { self.storedDelegate = newValue }
    }

    // MARK: Simple view adapters (Task 6)
    public var inputIsUserInteractionEnabled: Bool {
        get { self.editorView.isUserInteractionEnabled }
        set { self.editorView.isUserInteractionEnabled = newValue }
    }
    public var inputClipsToBounds: Bool {
        get { self.editorView.clipsToBounds }
        set { self.editorView.clipsToBounds = newValue }
    }
    public var inputAccessibilityHint: String? {
        get { self.editorView.accessibilityHint }
        set { self.editorView.accessibilityHint = newValue }
    }
    /// Negative insets (the panel sets -5pt all sides) that ENLARGE the editor's tap target: a touch landing in
    /// the thin margin just outside `editorView` (but inside this wrapper) still focuses/positions the editor,
    /// instead of falling through to the wrapper. Applied by the `hitTest(_:with:)` override below — mirrors what
    /// the legacy backend gets for free by forwarding to its inner text node's `ASDisplayNode.hitTestSlop`.
    public var inputHitTestSlop: UIEdgeInsets = .zero

    /// `ASDisplayNode.hitTest` is forwarded to by the backing `_ASDisplayView` when overridden (with a
    /// re-entrancy guard, so `super.hitTest` below is the standard UIView pass). We special-case ONLY the slop
    /// ring around `editorView`; taps inside the field, and everywhere else, take the normal path unchanged.
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let slop = self.inputHitTestSlop
        if slop != .zero, self.editorView.isUserInteractionEnabled, !self.editorView.isHidden, self.editorView.alpha > 0.01 {
            let frame = self.editorView.frame   // in this wrapper's (self.view) coordinate space, as is `point`
            // Negative insets expand the rect. Only the ring (expanded AND outside the real frame) is remapped.
            if frame.inset(by: slop).contains(point) && !frame.contains(point) {
                // Clamp the probe into the field so `editorView.hitTest` resolves to its canvas (the real
                // UITextInput). UIKit still delivers the ACTUAL touch, which the canvas maps to the nearest caret.
                var probe = self.view.convert(point, to: self.editorView)
                probe.x = min(max(probe.x, self.editorView.bounds.minX), self.editorView.bounds.maxX - 0.5)
                probe.y = min(max(probe.y, self.editorView.bounds.minY), self.editorView.bounds.maxY - 0.5)
                if let hit = self.editorView.hitTest(probe, with: event) {
                    return hit
                }
            }
        }
        return super.hitTest(point, with: event)
    }
    public var inputContentOffset: CGPoint { self.editorView.composerContentOffset }
    public func setInputScrollIndicatorInsets(_ insets: UIEdgeInsets) { self.trackedScrollIndicatorInsets = insets }

    /// The caret/selection in the composer's flat UTF-16 coordinate space (paragraphs joined by "\n",
    /// matching `ComposerDocumentBridge`). The panel reads this to know where to insert/replace and writes
    /// it to move the caret after an edit, so it MUST reflect the editor's real selection — a stub (e.g.
    /// always end-of-text + no-op setter) makes the panel selection-blind: the caret never advances after a
    /// programmatic insert and a surrogate-pair emoji gets split on edit, leaving a stray "service character".
    public var selectedRange: NSRange {
        get { self.editorView.composerSelectedRange }
        set { self.editorView.composerSelectedRange = newValue }
    }

    // MARK: Selection geometry
    /// The current selection's first rect in the editor's CONTENT space (un-scrolled), matching the legacy
    /// `firstRect(for:)` contract — `_showTextStyleOptions` subtracts `inputContentOffset.y` itself. That
    /// legacy format-menu path is dead on iOS 16+ (it returns a nil target), so this is contract-honest but
    /// not on a live path for this engine.
    public var selectionRect: CGRect { self.editorView.composerSelectionBoundingRect }
    /// First selection rect for a flat composer range, in this node's `self.view` space (the panel anchors
    /// the emoji-suggestion popover here, then converts node-view → panel). The editor returns the rect in
    /// `editorView` space; we finish with the trivial `editorView → self.view` parent conversion.
    public func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect? {
        self.editorView.composerFirstSelectionRect(forFlatRange: characterRange).map { self.editorView.convert($0, to: self.view) }
    }
    /// The caret rect in this node's `self.view` space (the panel anchors the emoji context panel's cursor
    /// here via `asNode.view.convert(...)`). nil when there is no caret.
    public func currentCaretRect() -> CGRect? {
        self.editorView.composerCaretRect().map { self.editorView.convert($0, to: self.view) }
    }

    // MARK: Stubs — Phase 2+ (spoilers, typing attrs, theme fidelity)
    public var spoilersRevealed: Bool = false
    public func setSpoilersRevealed(_ revealed: Bool, animated: Bool) { }
    public func prepareForSpoilerReveal() { }
    public func updateRichRendering(textColor: UIColor, fullTranslucency: Bool) { }
    public func refreshTextInputAttributes(context: AnyObject, primaryTextColor: UIColor, accentTextColor: UIColor, baseFontSize: CGFloat, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) { }
    public func refreshTextInputTypingAttributes(textColor: UIColor, baseFontSize: CGFloat) { }
    public var inputTypingAttributes: [NSAttributedString.Key: Any] {
        get { [:] }
        set { }
    }
    public var toggleQuoteCollapse: ((NSRange) -> Void)?
    public func isCurrentlyEmoji() -> Bool { false }
    // Input language: read the live keyboard language back, and pre-select the draft's saved language
    // on the next focus, via the editor's `textInputMode` override (see RichTextEditorView+ComposerHost).
    public var primaryLanguage: String? { self.editorView.inputPrimaryLanguage }
    public var initialPrimaryLanguage: String? {
        get { self.editorView.initialInputPrimaryLanguage }
        set { self.editorView.initialInputPrimaryLanguage = newValue }
    }
    public func resetInitialPrimaryLanguage() { self.editorView.resetInputPrimaryLanguage() }
    public var keyboardAppearance: UIKeyboardAppearance = .default
    public var autocorrectionType: UITextAutocorrectionType = .default
    /// The theme accent the panel passes (`theme.list.itemAccentColor`), applied the way the legacy node
    /// applies it: as this node's own `tintColor`, which the editor view and the engine text view inside it
    /// inherit. UIKit draws the caret, the selection highlight and the handles with the text view's
    /// `tintColor`, so without this they were always the system blue (composer harness, 2026-09-23,
    /// `HarnessCaretTintTests`: engine `systemBlue` where legacy drew the dark theme's white accent).
    public var inputTintColor: UIColor? {
        get { return self.tintColor }
        set { self.tintColor = newValue }
    }
    public func didChangeInputTintColor() {
        self.tintColorDidChange()
    }
    /// The caret/selection tint of the editor view itself; the panel clears it around a snapshot and puts
    /// back what it read. Putting back the INHERITED colour stores nil rather than pinning it, so a later
    /// `inputTintColor` change still reaches the caret.
    public var inputCaretColor: UIColor {
        get { return self.editorView.tintColor }
        set {
            if let inherited = self.editorView.superview?.tintColor, newValue == inherited {
                self.editorView.tintColor = nil
            } else {
                self.editorView.tintColor = newValue
            }
        }
    }
    public var inputTheme: ChatInputTextView.Theme?
}
