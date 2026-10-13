import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TextFormat
import InvisibleInkDustNode
import EmojiTextAttachmentView
import RichTextEditorCore
import RichTextEditorUIKit

/// Host theme colors for the rich-text composer backend, passed across the seam as plain `UIColor`s so
/// `ChatInputTextNode` need not depend on the editor package. The RichTextEditor backend maps these 1:1
/// into its `RichTextEditorTheme`; the legacy backend ignores them (it themes via `inputTheme`).
public struct ChatRichTextThemeColors {
    public var primaryText: UIColor
    public var secondaryText: UIColor
    public var placeholder: UIColor
    public var accent: UIColor
    public var tableBorder: UIColor
    public var tableHeaderBackground: UIColor
    /// Checklist checkbox palette (the standard app checkbox `list.itemCheckColors`): fill = box background,
    /// foreground = checkmark/stroke, border = box border. The native backend maps these into the `CheckNode`
    /// it hosts as a checklist marker; the legacy backend ignores them (it has no checklist UI).
    public var listCheckFillColor: UIColor
    public var listCheckForegroundColor: UIColor
    public var listCheckBorderColor: UIColor
    /// Quote AUTHOR (attribution) line text color — dedicated (defaults to `secondaryText` at the mapping
    /// site so there is no visual change until the host picks a distinct value). See `RichTextEditorTheme.quoteAuthorText`.
    public var quoteAuthorText: UIColor
    /// Quote AUTHOR (attribution) line placeholder color — dedicated (defaults to `placeholder` at the
    /// mapping site). See `RichTextEditorTheme.quoteAuthorPlaceholder`.
    public var quoteAuthorPlaceholder: UIColor
    /// Passthrough
    public var shadowCursor: UIColor

    public init(primaryText: UIColor, secondaryText: UIColor, placeholder: UIColor, accent: UIColor, tableBorder: UIColor, tableHeaderBackground: UIColor, listCheckFillColor: UIColor, listCheckForegroundColor: UIColor, listCheckBorderColor: UIColor, quoteAuthorText: UIColor, quoteAuthorPlaceholder: UIColor, shadowCursor: UIColor) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.placeholder = placeholder
        self.accent = accent
        self.tableBorder = tableBorder
        self.tableHeaderBackground = tableHeaderBackground
        self.listCheckFillColor = listCheckFillColor
        self.listCheckForegroundColor = listCheckForegroundColor
        self.listCheckBorderColor = listCheckBorderColor
        self.quoteAuthorText = quoteAuthorText
        self.quoteAuthorPlaceholder = quoteAuthorPlaceholder
        self.shadowCursor = shadowCursor
    }
}

/// Format commands routable from the new editor backend's context menu. `Link` is intentionally absent —
/// it is handled host-side via `openLinkEditing` (it needs a URL-entry UI). `code`/`date` have no native
/// editor representation yet and are no-ops on the new backend.
public enum ChatRichTextFormatAction {
    case bold, italic, monospace, strikethrough, underline, spoiler, quote, pullQuote, code, date
}

/// The owner-facing media-control descriptor: the resolved `EngineMedia` ("what we're dealing with") plus
/// occurrence-bound operations ("how to act on it") and the anchor. Built by the native rich-text node from
/// the editor's account-free `MediaControlRequest` (resolving `EngineMedia` from its media store) and handed
/// to the panel, which builds its own owner-specific menu. `replace`/`addMore` are reserved (nil until built).
@available(iOS 13.0, *)
public struct MediaControlContext {
    public let media: EngineMedia
    public let control: RichTextMediaControlKind
    public let sourceView: UIView?
    public let sourceRect: CGRect
    public let delete: () -> Void
    public let isSpoiler: Bool
    public let toggleSpoiler: () -> Void
    public let replace: ((String, CGSize, MediaKind) -> Void)?
    public let addMore: ((String, CGSize, MediaKind) -> Void)?

    public init(media: EngineMedia, control: RichTextMediaControlKind, sourceView: UIView?, sourceRect: CGRect,
                delete: @escaping () -> Void,
                isSpoiler: Bool,
                toggleSpoiler: @escaping () -> Void,
                replace: ((String, CGSize, MediaKind) -> Void)?,
                addMore: ((String, CGSize, MediaKind) -> Void)?) {
        self.media = media
        self.control = control
        self.sourceView = sourceView
        self.sourceRect = sourceRect
        self.delete = delete
        self.isSpoiler = isSpoiler
        self.toggleSpoiler = toggleSpoiler
        self.replace = replace
        self.addMore = addMore
    }
}

/// Protocol seam for the chat composer's text editor. Implemented today by
/// `ChatRichTextInputNodeImpl` (which composes the existing `ChatInputTextNode`);
/// intended to be implemented directly by the TextKit-2 RichTextEditor later.
public protocol ChatRichTextInputNode: AnyObject {
    /// The display node to insert into the view hierarchy and assign a frame to.
    var asNode: ASDisplayNode { get }

    /// Provider for animated custom-emoji views, resolved at render time. Set after creation.
    var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)? { get set }

    /// Factory the PANEL supplies (it owns `AccountContext`) so the editor can render a `.media` block. The
    /// native backend forwards it to the editor's media-view provider, resolving its private `mediaByID` →
    /// this factory; the legacy `UITextView` backend stores it but never uses it (no media). `naturalSize` is
    /// the medium's natural size, for aspect-correct display. Mirrors `emojiViewProvider`'s host-owned seam.
    var mediaItemViewFactory: ((_ items: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)], _ existing: (UIView & RichTextMediaItemView)?) -> (UIView & RichTextMediaItemView)?)? { get set }

    /// Host-provided formula renderer. The native backend forwards it to `RichTextEditorView`; the legacy
    /// backend stores it but never uses it, matching the media seam.
    var formulaRenderer: ((RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)? { get set }

    /// Recompute and lay out the spoiler dust and custom-emoji overlays from the current
    /// attributed text, hosting both inside the composed text view's scrolling content.
    /// `textColor` / `fullTranslucency` are passed live on every call because the host's
    /// theme and energy-usage settings can change between calls; the impl reuses the most
    /// recent values for its own layout-driven refreshes.
    func updateRichRendering(textColor: UIColor, fullTranslucency: Bool)

    /// Cross-fade the spoiler dust for a reveal-state change, snapshotting the text so the
    /// transition reads as a dissolve. The caller rewrites the attributed text first (that
    /// is host/message-state domain); this method owns only the rendering side.
    func setSpoilersRevealed(_ revealed: Bool, animated: Bool)

    /// The bounding rect of the first selection rect for the given character range, in
    /// `asNode`'s coordinate space (nil if the range cannot be resolved). Lets the host
    /// anchor UI (e.g. the emoji-suggestion popup) to the caret without assuming a
    /// `UITextView` backend or reaching into scroll-view geometry.
    func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect?

    /// The caret (insertion point) rect for the current selection, in `asNode`'s coordinate
    /// space (nil if there is no caret). Like `firstSelectionRect`, this is a
    /// backend-agnostic geometry query for anchoring UI to the cursor.
    func currentCaretRect() -> CGRect?

    /// The editor's attributed content. Reads return the current text; writes replace it
    /// (the host rebuilds the attributed string after edits/state changes). Forwards to the
    /// composed editor today; a future backend implements it natively.
    var attributedText: NSAttributedString? { get set }

    /// The editor's plain-text string (read-only convenience for length/counter checks).
    var text: String { get }

    /// Whether the editor currently holds NO content. Content-aware (mirrors `ChatInputContent.isEmpty`) —
    /// NOT flat-text-aware, so a lone media/table block reads as non-empty even though its flat text is empty.
    /// The default implementation answers from `attributedText` length (correct for the legacy backend, which
    /// has no non-text blocks); the native backend overrides it with a direct document walk.
    var inputContentIsEmpty: Bool { get }

    /// As `inputContentIsEmpty`, but a block whose text is only whitespace counts as empty (mirrors
    /// `ChatInputContent.isEmptyWhitespaceTrimmed`). Drives the composer's expand-button affordance, which stays
    /// hidden for a field that is tall only because of blank lines. Same backend split as `inputContentIsEmpty`.
    var inputContentIsEmptyWhitespaceTrimmed: Bool { get }

    /// Apply host theme colors to the editor. No-op on the legacy `UITextView` backend (it themes via
    /// `inputTheme`/`refreshTextInputAttributes`); the RichTextEditor backend maps these into its
    /// `RichTextEditorTheme`.
    func applyRichTextTheme(_ colors: ChatRichTextThemeColors)

    /// The current selection range. Reads return the live selection; writes move/extend it
    /// (the host restores the cursor after rebuilding content). Forwards to the editor today.
    var selectedRange: NSRange { get set }

    /// The bounding rect of the current selection in the editor's coordinate space (used to
    /// anchor the system text-style menu). Read-only; forwarded as-is.
    var selectionRect: CGRect { get }

    /// Whether the editor currently holds first-responder (keyboard) focus.
    /// Distinct from `ASDisplayNode.isFirstResponder()` (which would target the wrapper).
    var isInputFirstResponder: Bool { get }

    /// Make the composed editor first responder. Returns whether it succeeded.
    @discardableResult func makeInputFirstResponder() -> Bool

    /// Resign the composed editor's first-responder status. Returns whether it succeeded.
    @discardableResult func resignInputFirstResponder() -> Bool

    /// The active input mode's primary language (for input-language tracking). Read-only.
    var primaryLanguage: String? { get }

    /// The language the editor should default its keyboard to on next focus (get/set).
    var initialPrimaryLanguage: String? { get set }

    /// Re-apply `initialPrimaryLanguage` to the live input (used when forcing the emoji keyboard).
    func resetInitialPrimaryLanguage()

    /// The text container inset (caret/text padding). Recomputed by the host each layout pass.
    var textContainerInset: UIEdgeInsets { get set }

    /// The keyboard appearance (light/dark) for the editor.
    var keyboardAppearance: UIKeyboardAppearance { get set }

    /// Whether predictive text / autocorrection is enabled.
    var autocorrectionType: UITextAutocorrectionType { get set }

    /// The editor's tint (caret + selection) color. `input`-prefixed because the impl is an
    /// `ASDisplayNode` whose own `tintColor` targets the wrapper, not the composed editor.
    var inputTintColor: UIColor? { get set }

    /// Propagate a tint-color change to the editor (mirrors `tintColorDidChange`).
    func didChangeInputTintColor()

    /// Hit-test slop expanding the editor's touch area. `input`-prefixed (wrapper collision).
    var inputHitTestSlop: UIEdgeInsets { get set }

    /// Whether the editor's scrolling content clips to bounds. `input`-prefixed (collision).
    var inputClipsToBounds: Bool { get set }

    /// The accessibility hint announced for the editor. `input`-prefixed (NSObject collision).
    var inputAccessibilityHint: String? { get set }

    /// Whether the editor accepts user interaction. `input`-prefixed because the impl's own
    /// `ASDisplayNode.isUserInteractionEnabled` targets the wrapper.
    var inputIsUserInteractionEnabled: Bool { get set }

    /// Callback to collapse/expand a quote block at a range (set once after creation).
    var toggleQuoteCollapse: ((NSRange) -> Void)? { get set }

    /// Delete one character backward from the caret (UIKeyInput-style).
    func deleteBackward()

    /// Whether the editor is currently in the emoji input mode.
    func isCurrentlyEmoji() -> Bool

    /// The attributes applied to text typed next at the caret (font/color/paragraph + the
    /// active bold/italic/monospace run). Generic text-editing concept; forwards to the
    /// editor's typing attributes.
    var inputTypingAttributes: [NSAttributedString.Key: Any] { get set }

    /// Re-derive the full attribute set of the current text (fonts, colors, spoilers,
    /// custom-emoji & collapsed-quote attachments) from theme-derived colors and state.
    /// The impl supplies its own collapsed-quote attachment factory.
    func refreshTextInputAttributes(
        context: AnyObject,
        primaryTextColor: UIColor,
        accentTextColor: UIColor,
        baseFontSize: CGFloat,
        spoilersRevealed: Bool,
        availableEmojis: Set<String>,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    )

    /// Re-derive only the typing attributes from the theme-derived text color.
    func refreshTextInputTypingAttributes(textColor: UIColor, baseFontSize: CGFloat)

    /// Set the insets for the editor's scroll indicator. No-op for non-scrolling backends.
    /// (A setter method rather than a property: `UIScrollView.scrollIndicatorInsets`'s
    /// getter is deprecated, and only the setter is needed here.)
    func setInputScrollIndicatorInsets(_ insets: UIEdgeInsets)

    /// Freeze the editor's scrolling ahead of a spoiler-reveal content rewrite, so the
    /// attributed-text mutation doesn't auto-scroll. `setSpoilersRevealed(_:animated:)`
    /// re-enables scrolling when the reveal completes. No-op for non-scrolling backends.
    func prepareForSpoilerReveal()

    /// The editor's current content scroll offset, used to map content-space rects into
    /// the visible coordinate space. `.zero` for non-scrolling backends.
    var inputContentOffset: CGPoint { get }

    /// Measure the editor's content height for a width (mirrors the child's signature).
    func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat

    /// Measures the field's content height for `lineCount` body lines (used to size the 3-line AI-button
    /// trigger). Side-effect-free: builds a throwaway probe, never touches the live editor — but it is an
    /// INSTANCE method because it must measure with this node's live content inset (rich: `trackedContentMargins`;
    /// legacy: the text view's `textContainerInset`), the same inset the live `textHeightForWidth` adds, so the
    /// 3-line size matches the real field exactly. `lineCount` floors at 1.
    func measuredTextFieldHeight(forWidth width: CGFloat, lineCount: Int) -> CGFloat

    /// Lay out the editor's content for a size.
    func updateLayout(size: CGSize)

    /// Force an immediate layout pass of the editor child (distinct name: `ASDisplayNode`
    /// already has `layout()`, which targets the wrapper).
    func layoutInputField()

    /// The editor child's own frame, inset within `asNode` per the Model-A geometry.
    /// Distinct from `asNode.frame` (the full-size wrapper).
    var textFieldFrame: CGRect { get set }

    /// The editor child's backing view (for gesture/snapshot/layout hooks). Backend-
    /// agnostic: a direct backend returns its own content view (== `asNode.view` there).
    var inputView: UIView { get }

    /// The caret/selection tint. Distinct from `inputTintColor` (the node-level tint):
    /// this is the inner editor's caret color, toggled to hide the caret during snapshots.
    var inputCaretColor: UIColor { get set }

    /// The editor's quote/code rendering theme (quote background/foreground, line style,
    /// code colors). Set on load and on theme change.
    var inputTheme: ChatInputTextView.Theme? { get set }

    /// The editor's delegate (text/selection/editing/paste callbacks). Set once after
    /// creation. Weak at the storage layer (the composed node holds it weakly).
    var inputDelegate: ChatInputTextNodeDelegate? { get set }

    /// The editor's custom keyboard input view (`nil` ⇒ system keyboard). Distinct from
    /// `inputView` (the editor's backing view): this is the `UITextView.inputView` slot,
    /// set to an empty view to suppress the system keyboard for the entity keyboard.
    var keyboardInputView: UIView? { get set }

    /// Reload the editor's input views (after changing `keyboardInputView`).
    func reloadInputViews()

    /// The editor's current right text inset (composer accessory width); read by the
    /// send-options morph to match the bubble's text wrapping.
    var currentRightInset: CGFloat { get }

    /// Commit any pending marked/autocorrect text (called before send). For the UITextView
    /// backend this applies keyboard autocorrection; another backend finalizes marked text.
    func applyAutocorrection()

    /// Whether this backend uses the native TextKit-2 `Document` engine (the new editor). The legacy
    /// `UITextView` backend returns `false`. Used by the host (e.g. `openLinkEditing`) to route through the
    /// native format API instead of the legacy `ChatTextInputState`.
    var usesNativeRichTextEngine: Bool { get }

    /// Transform of the editor backend's default edit-menu elements (e.g. swap in the chat "Format" submenu),
    /// forwarded to the editor's menu. No-op on the legacy backend (it uses the `chatInputTextNodeMenu` delegate).
    var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? { get set }

    /// Fired when the native editor wants its table row/column structural menu presented; the PANEL presents it
    /// as a ContextController. No-op on the legacy backend (it has no tables).
    var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? { get set }

    /// Fired when a media control (the more button; the "+" later) is tapped; the PANEL presents an
    /// owner-specific menu. No-op on the legacy backend (its editor has no inline media).
    var onRequestMediaControl: ((MediaControlContext) -> Void)? { get set }

    /// Pasting media (image/gif/video/sticker) is a host concern. The PANEL sets these so the native editor
    /// can delegate a media paste back to the chat send flow. `canPasteMedia` gates whether the editor offers
    /// Paste for the current pasteboard; `onPasteMedia` performs the routing (returns whether it consumed it).
    var canPasteMedia: (() -> Bool)? { get set }
    var onPasteMedia: (() -> Bool)? { get set }

    /// Paste the richest representation currently on the system pasteboard at the caret using the editor's own
    /// reader + fragment splice (private fragment UTI → RTF → plain). Native backend only; the legacy backend is
    /// a no-op (the host routes its paste through the `NSAttributedString` path instead).
    func performRichPaste()

    /// Host transform for pasted PLAIN text, forwarded to the native editor's
    /// `plainTextFragmentTransformer`. Returning a `Document` splices rich content at the caret;
    /// returning nil keeps the built-in plain paste. Native backend only — legacy backend ignores it.
    var pastedMarkdownFragmentParser: ((String) -> Document?)? { get set }

    /// Fired on a genuine user TEXT edit (typing/delete/paste/IME) so the host can report the "typing…" chat
    /// activity. Set by the PANEL, wired to its `updateActivity`. It must NOT fire on a caret/selection move or
    /// on a programmatic content set (draft restore / send-clear / state echo) — otherwise the chat partner
    /// sees "typing…" when the user merely moves the cursor or a draft loads. The LEGACY backend leaves this
    /// stored-but-unused (it reports activity via the `chatInputTextNode(shouldChangeTextIn:)` delegate, which
    /// the native editor never calls); the native backend fires it from its content-change path.
    var onTypingActivity: (() -> Void)? { get set }

    /// Apply a format command through the backend's native engine. No-op on the legacy backend.
    func performFormatAction(_ action: ChatRichTextFormatAction)

    /// The link URL the current selection carries (for prefilling a link editor), or nil.
    func currentRichTextLinkURL() -> String?

    /// The plain text of the current selection (for a link editor's prompt label).
    func selectedRichText() -> String

    /// Apply (or, for empty/nil, remove) a link over the current selection via the native engine.
    func applyRichTextLink(_ url: String?)

    /// The node's content as the canonical `ChatInputContent` model + opaque selection. Default
    /// implementations bridge through `attributedText`/`selectedRange` + the TextFormat conversion utility.
    func currentInputContent() -> (content: ChatInputContent, selection: ChatInputSelection)
    func setInputContent(_ content: ChatInputContent, selection: ChatInputSelection)

    /// Supply the host rendering inputs the LEGACY backend needs to decorate a `ChatInputContent` into the
    /// displayed `NSAttributedString` inside `setInputContent` (fonts/colors/spoiler/emoji overlays) AND to run
    /// the in-place per-edit fix-up (`refreshTextInputAttributes`) the node now drives itself. No-op on the
    /// native backend (it renders from its own `Document`). `textColor` is the body color for the
    /// `setInputContent` decorate step (the host's `inputTextColor`); `primaryTextColor` is the body color the
    /// in-place fix-up re-derives with (the host's `primaryTextColor`) — these are deliberately distinct, so the
    /// node must carry both. The host calls this whenever those inputs change (theme/energy/spoilers + before a
    /// drive), so the stored config is never stale for the node's self-refreshes.
    func applyRenderingConfig(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?)

    /// Re-run the full per-text-change decoration the node owns: the in-place fix-up
    /// (`refreshTextInputAttributes`), the caret typing attributes (`refreshTextInputTypingAttributes`), and the
    /// spoiler-dust + custom-emoji overlay rebuild (`updateRichRendering`). The host calls this once at each
    /// text-change moment with the current theme/energy inputs (so values are never stale), instead of driving
    /// those three steps itself. `textColor` is the overlay/dust color (the host's `inputTextColor`);
    /// `primaryTextColor` is the body color for the fix-up + typing attributes. The default implementation
    /// forwards to the three steps in order, so both backends keep their existing behavior.
    func decorateAfterTextChange(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, spoilersRevealed: Bool, fullTranslucency: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?)

    /// Whether spoilers are currently revealed. The node owns this state: the decoration reads it (via the
    /// `spoilersRevealed:` arg the host passes from here) and the spoiler-reveal flow (`updateSpoilersRevealed`)
    /// flips it. Replaces the former host-side flag.
    var spoilersRevealed: Bool { get set }

    /// Run the spoiler-reveal flow: detect whether the current selection intersects a spoiler and, if that
    /// changed, reveal it immediately (or hide it after the un-reveal delay), re-decorating with the flipped
    /// flag and cross-fading the dust. The host calls this at selection-change and after applying the spoiler
    /// format, passing the live theme inputs; the default implementation owns the whole flow (detection +
    /// 1.5s hide delay + dust animation), so the chat layer no longer drives it.
    func updateSpoilersRevealed(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?, animated: Bool)

    /// Decorate a plain-text replacement fragment (for the paste / `shouldChangeText` splice) the way the node
    /// renders content: applies font/colors and clears spoiler text using the node's own `spoilersRevealed`.
    /// Returns the decorated fragment for the host to splice in — so the chat layer no longer calls
    /// `textAttributedStringForStateText` itself. The host passes the live theme inputs.
    func decorateReplacementFragment(plainText: String, context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, accentTextColor: UIColor, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) -> NSAttributedString
}

public extension ChatRichTextInputNode {
    var inputContentIsEmpty: Bool {
        return (self.attributedText?.length ?? 0) == 0
    }
    var inputContentIsEmptyWhitespaceTrimmed: Bool {
        return (self.attributedText?.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ?? true
    }
    func currentInputContent() -> (content: ChatInputContent, selection: ChatInputSelection) {
        let attr = self.attributedText ?? NSAttributedString()
        let content = chatInputContent(from: attr)
        return (content, ChatInputSelection(nsRange: self.selectedRange, in: content))
    }
    func setInputContent(_ content: ChatInputContent, selection: ChatInputSelection) {
        self.attributedText = attributedString(from: content)
        self.selectedRange = selection.nsRange(in: content)
    }
    func applyRenderingConfig(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) {}
    func decorateAfterTextChange(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, spoilersRevealed: Bool, fullTranslucency: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) {
        // The three decoration steps the host used to drive directly in `chatInputTextNodeDidUpdateText`, now
        // owned by the node — same order, same live inputs. Each step is an existing backend method, so this
        // forwards identically for both the legacy and native backends.
        self.refreshTextInputAttributes(context: context, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, baseFontSize: baseFontSize, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider)
        self.refreshTextInputTypingAttributes(textColor: primaryTextColor, baseFontSize: baseFontSize)
        self.updateRichRendering(textColor: textColor, fullTranslucency: fullTranslucency)
    }

    func decorateReplacementFragment(plainText: String, context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, accentTextColor: UIColor, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) -> NSAttributedString {
        return textAttributedStringForStateText(context: context, stateText: NSAttributedString(string: plainText), fontSize: baseFontSize, textColor: textColor, accentTextColor: accentTextColor, writingDirection: nil, spoilersRevealed: self.spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
            return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
        })
    }

    func updateSpoilersRevealed(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?, animated: Bool) {
        // Detect whether the caret/selection now intersects a spoiler (same scan the host used to run).
        let selectionRange = self.selectedRange
        var revealed = false
        if let attributedText = self.attributedText {
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let _ = attributes[ChatTextInputAttributes.spoiler] {
                    if let _ = selectionRange.intersection(range) {
                        revealed = true
                    }
                }
            })
        }

        guard self.spoilersRevealed != revealed else {
            return
        }
        self.spoilersRevealed = revealed

        if revealed {
            self.applyInternalSpoilersRevealed(true, animated: animated, context: context, baseFontSize: baseFontSize, textColor: textColor, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider)
        } else {
            // Keep the spoiler revealed briefly after the caret leaves it, mirroring the host's prior timing.
            Queue.mainQueue().after(1.5, { [weak self] in
                guard let self else {
                    return
                }
                self.applyInternalSpoilersRevealed(false, animated: true, context: context, baseFontSize: baseFontSize, textColor: textColor, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider)
            })
        }
    }
}

private extension ChatRichTextInputNode {
    /// The reveal/hide half of `updateSpoilersRevealed`: prepare the editor, re-decorate the current content
    /// with the flipped flag (length-preserving, so the selection is kept), then cross-fade the dust. Guards on
    /// the flag still matching `revealed` (the caret may have moved back during the un-reveal delay). Mirrors
    /// the host's former `updateInternalSpoilersRevealed`.
    func applyInternalSpoilersRevealed(_ revealed: Bool, animated: Bool, context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) {
        guard self.spoilersRevealed == revealed else {
            return
        }

        self.prepareForSpoilerReveal()

        self.refreshTextInputAttributes(context: context, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, baseFontSize: baseFontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider)

        if !self.usesNativeRichTextEngine {
            self.applyRenderingConfig(context: context, baseFontSize: baseFontSize, textColor: textColor, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, spoilersRevealed: self.spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider)
        }
        // Re-decorate the current content with the flipped spoilers-revealed flag; the string length is
        // unchanged, so the selection is preserved across the rewrite. `currentInputContent()` is exactly the
        // host's former `chatInputContent(from: inputTextState.inputText)` + current selection.
        let current = self.currentInputContent()
        self.setInputContent(current.content, selection: current.selection)

        self.setSpoilersRevealed(revealed, animated: animated)
    }
}

/// Creates the default composition-based rich text input node.
public func makeChatRichTextInputNode(disableTiling: Bool = false) -> ChatRichTextInputNode {
    return ChatRichTextInputNodeImpl(disableTiling: disableTiling)
}

final class ChatRichTextInputNodeImpl: ASDisplayNode, ChatRichTextInputNode {
    private let textInputNodeImpl: ChatInputTextNode

    private var dustNode: InvisibleInkDustNode?
    private var customEmojiContainerView: CustomEmojiContainerView?
    // The node owns the spoilers-revealed state (was a host-side flag). Drives the dust alpha in
    // `updateRichRendering` and the `spoilersRevealed:` decoration arg the host now reads back from here.
    var spoilersRevealed: Bool = false

    // Most recent values supplied by the host via updateRichRendering. The internal
    // layout-driven refresh (onUpdateLayout) reuses them so it renders with the same
    // theme/energy state the host last drove. nil textColor means "not configured yet".
    private var lastTextColor: UIColor?
    private var lastFullTranslucency: Bool = true

    // Host rendering inputs for decorating a `ChatInputContent` inside `setInputContent`. Refreshed by the
    // host (`applyRenderingConfig`) immediately before each `setInputContent` drive, so it is never stale.
    private struct RenderingConfig {
        weak var context: AnyObject?
        var baseFontSize: CGFloat
        var textColor: UIColor
        var primaryTextColor: UIColor
        var accentTextColor: UIColor
        var spoilersRevealed: Bool
        var availableEmojis: Set<String>
        var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    }
    private var renderingConfig: RenderingConfig?

    var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)?

    // Stored-but-unused: the legacy `UITextView` backend has no media blocks to render, so it satisfies the
    // protocol but never reads this. The native (`RichTextEditorChatInputNode`) backend wires it to the editor.
    var mediaItemViewFactory: ((_ items: [(media: EngineMedia, naturalSize: CGSize, isSpoiler: Bool, kind: MediaKind)], _ existing: (UIView & RichTextMediaItemView)?) -> (UIView & RichTextMediaItemView)?)?

    // Stored-but-unused: the legacy backend has no formula atoms to render. The native backend wires this into
    // `RichTextEditorView`.
    var formulaRenderer: ((RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)?

    // Stored-but-unused: the legacy backend reports "typing…" activity via the panel's
    // `chatInputTextNode(shouldChangeTextIn:)` delegate, so it never fires this. Only the native
    // (`RichTextEditorChatInputNode`) backend fires it (it doesn't call that delegate). See the protocol doc.
    var onTypingActivity: (() -> Void)?

    // Bridges to ASDisplayNode for callers that hold this only as a ChatRichTextInputNode.
    var asNode: ASDisplayNode {
        return self
    }

    init(disableTiling: Bool = false) {
        self.textInputNodeImpl = ChatInputTextNode(disableTiling: disableTiling)

        super.init()

        self.addSubnode(self.textInputNodeImpl)

        // Refresh overlays when the composed editor relayouts (e.g. content size changes
        // on scroll/typing), reusing the host's most recent rendering values.
        self.textInputNodeImpl.textView.onUpdateLayout = { [weak self] in
            guard let self, let textColor = self.lastTextColor else {
                return
            }
            self.updateRichRendering(textColor: textColor, fullTranslucency: self.lastFullTranslucency)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRichRendering(textColor: UIColor, fullTranslucency: Bool) {
        self.lastTextColor = textColor
        self.lastFullTranslucency = fullTranslucency

        let textInputNode = self.textInputNodeImpl

        var rects: [CGRect] = []
        var customEmojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute, CGFloat)] = []

        // The host pins the composer font size to 17.0; match it here.
        let fontSize: CGFloat = 17.0

        if let attributedText = textInputNode.attributedText {
            let beginning = textInputNode.textView.beginningOfDocument
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let _ = attributes[ChatTextInputAttributes.spoiler] {
                    func addSpoiler(startIndex: Int, endIndex: Int) {
                        if let start = textInputNode.textView.position(from: beginning, offset: startIndex), let end = textInputNode.textView.position(from: start, offset: endIndex - startIndex), let textRange = textInputNode.textView.textRange(from: start, to: end) {
                            let textRects = textInputNode.textView.selectionRects(for: textRange)
                            for textRect in textRects {
                                if textRect.rect.width > 1.0 && textRect.rect.size.height > 1.0 {
                                    rects.append(textRect.rect.insetBy(dx: 1.0, dy: 1.0).offsetBy(dx: 0.0, dy: 1.0))
                                }
                            }
                        }
                    }

                    var startIndex: Int?
                    var currentIndex: Int?

                    let nsString = (attributedText.string as NSString)
                    nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                        if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                            if let currentStartIndex = startIndex {
                                startIndex = nil
                                let endIndex = range.location
                                addSpoiler(startIndex: currentStartIndex, endIndex: endIndex)
                            }
                        } else if startIndex == nil {
                            startIndex = range.location
                        }
                        currentIndex = range.location + range.length
                    }

                    if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                        startIndex = nil
                        let endIndex = currentIndex
                        addSpoiler(startIndex: currentStartIndex, endIndex: endIndex)
                    }
                }

                if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                    if let start = textInputNode.textView.position(from: beginning, offset: range.location), let end = textInputNode.textView.position(from: start, offset: range.length), let textRange = textInputNode.textView.textRange(from: start, to: end) {
                        let textRects = textInputNode.textView.selectionRects(for: textRange)
                        for textRect in textRects {
                            var emojiFontSize = fontSize
                            if let font = attributes[.font] as? UIFont {
                                emojiFontSize = font.pointSize
                            }
                            customEmojiRects.append((textRect.rect, value, emojiFontSize))
                            break
                        }
                    }
                }
            })
        }

        if !rects.isEmpty {
            let dustNode: InvisibleInkDustNode
            if let current = self.dustNode {
                dustNode = current
            } else {
                dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: fullTranslucency)
                dustNode.alpha = self.spoilersRevealed ? 0.0 : 1.0
                dustNode.isUserInteractionEnabled = false
                textInputNode.textView.addSubview(dustNode.view)
                self.dustNode = dustNode
            }
            dustNode.frame = CGRect(origin: CGPoint(), size: textInputNode.textView.contentSize)
            dustNode.update(size: textInputNode.textView.contentSize, color: textColor, textColor: textColor, rects: rects, wordRects: rects)
        } else if let dustNode = self.dustNode {
            dustNode.removeFromSupernode()
            self.dustNode = nil
        }

        if !customEmojiRects.isEmpty {
            let customEmojiContainerView: CustomEmojiContainerView
            if let current = self.customEmojiContainerView {
                customEmojiContainerView = current
            } else {
                customEmojiContainerView = CustomEmojiContainerView(emojiViewProvider: { [weak self] emoji in
                    guard let strongSelf = self, let emojiViewProvider = strongSelf.emojiViewProvider else {
                        return nil
                    }
                    return emojiViewProvider(emoji)
                })
                customEmojiContainerView.isUserInteractionEnabled = false
                textInputNode.textView.addSubview(customEmojiContainerView)
                self.customEmojiContainerView = customEmojiContainerView
            }

            customEmojiContainerView.update(fontSize: fontSize, textColor: textColor, emojiRects: customEmojiRects)
        } else if let customEmojiContainerView = self.customEmojiContainerView {
            customEmojiContainerView.removeFromSuperview()
            self.customEmojiContainerView = nil
        }
    }

    func setSpoilersRevealed(_ revealed: Bool, animated: Bool) {
        self.spoilersRevealed = revealed

        let textView = self.textInputNodeImpl.textView

        if textView.subviews.count > 1, animated {
            let containerView = textView.subviews[1]
            if let canvasView = containerView.subviews.first {
                if let snapshotView = canvasView.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = canvasView.frame.offsetBy(dx: 0.0, dy: -textView.contentOffset.y)
                    self.textInputNodeImpl.view.insertSubview(snapshotView, at: 0)
                    canvasView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView, weak textView] _ in
                        textView?.isScrollEnabled = false
                        snapshotView?.removeFromSuperview()
                        Queue.mainQueue().after(0.1) {
                            textView?.isScrollEnabled = true
                        }
                    })
                }
            }
        }
        Queue.mainQueue().after(0.1) { [weak textView] in
            textView?.isScrollEnabled = true
        }

        if animated {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
            if let dustNode = self.dustNode {
                transition.updateAlpha(node: dustNode, alpha: revealed ? 0.0 : 1.0)
            }
        } else if let dustNode = self.dustNode {
            dustNode.alpha = revealed ? 0.0 : 1.0
        }
    }

    func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect? {
        let textView = self.textInputNodeImpl.textView
        let beginning = textView.beginningOfDocument
        guard let start = textView.position(from: beginning, offset: characterRange.location),
              let end = textView.position(from: start, offset: characterRange.length),
              let textRange = textView.textRange(from: start, to: end),
              let rect = textView.selectionRects(for: textRange).first?.rect else {
            return nil
        }
        // selectionRects are in the text view's (scrolling) coordinate space; convert up to
        // this node's space so the caller never depends on the editor being a scroll view.
        return textView.convert(rect, to: self.view)
    }

    func currentCaretRect() -> CGRect? {
        let textView = self.textInputNodeImpl.textView
        guard let selectedTextRange = textView.selectedTextRange else {
            return nil
        }
        let rect = textView.caretRect(for: selectedTextRange.end)
        guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.size.width.isFinite, rect.size.height.isFinite else {
            return nil
        }
        return textView.convert(rect, to: self.view)
    }

    var attributedText: NSAttributedString? {
        get { return self.textInputNodeImpl.attributedText }
        set { self.textInputNodeImpl.attributedText = newValue }
    }

    var text: String {
        return self.textInputNodeImpl.textView.text
    }

    /// No-op: the legacy `UITextView` backend themes via `inputTheme`/`refreshTextInputAttributes`.
    func applyRichTextTheme(_ colors: ChatRichTextThemeColors) {
    }

    var selectedRange: NSRange {
        get { return self.textInputNodeImpl.selectedRange }
        set { self.textInputNodeImpl.selectedRange = newValue }
    }

    var selectionRect: CGRect {
        return self.textInputNodeImpl.selectionRect
    }

    var isInputFirstResponder: Bool {
        return self.textInputNodeImpl.isFirstResponder()
    }

    @discardableResult func makeInputFirstResponder() -> Bool {
        return self.textInputNodeImpl.becomeFirstResponder()
    }

    @discardableResult func resignInputFirstResponder() -> Bool {
        return self.textInputNodeImpl.resignFirstResponder()
    }

    var primaryLanguage: String? {
        return self.textInputNodeImpl.textInputMode?.primaryLanguage
    }

    var initialPrimaryLanguage: String? {
        get { return self.textInputNodeImpl.initialPrimaryLanguage }
        set { self.textInputNodeImpl.initialPrimaryLanguage = newValue }
    }

    func resetInitialPrimaryLanguage() {
        self.textInputNodeImpl.resetInitialPrimaryLanguage()
    }

    var textContainerInset: UIEdgeInsets {
        get { return self.textInputNodeImpl.textContainerInset }
        set { self.textInputNodeImpl.textContainerInset = newValue }
    }

    var keyboardAppearance: UIKeyboardAppearance {
        get { return self.textInputNodeImpl.keyboardAppearance }
        set { self.textInputNodeImpl.keyboardAppearance = newValue }
    }

    var autocorrectionType: UITextAutocorrectionType {
        get { return self.textInputNodeImpl.textView.autocorrectionType }
        set { self.textInputNodeImpl.textView.autocorrectionType = newValue }
    }

    var inputTintColor: UIColor? {
        get { return self.textInputNodeImpl.tintColor }
        set { self.textInputNodeImpl.tintColor = newValue }
    }

    func didChangeInputTintColor() {
        self.textInputNodeImpl.tintColorDidChange()
    }

    var inputHitTestSlop: UIEdgeInsets {
        get { return self.textInputNodeImpl.hitTestSlop }
        set { self.textInputNodeImpl.hitTestSlop = newValue }
    }

    var inputClipsToBounds: Bool {
        get { return self.textInputNodeImpl.textView.clipsToBounds }
        set { self.textInputNodeImpl.textView.clipsToBounds = newValue }
    }

    var inputAccessibilityHint: String? {
        get { return self.textInputNodeImpl.textView.accessibilityHint }
        set { self.textInputNodeImpl.textView.accessibilityHint = newValue }
    }

    var inputIsUserInteractionEnabled: Bool {
        get { return self.textInputNodeImpl.isUserInteractionEnabled }
        set { self.textInputNodeImpl.isUserInteractionEnabled = newValue }
    }

    var toggleQuoteCollapse: ((NSRange) -> Void)? {
        get { return self.textInputNodeImpl.textView.toggleQuoteCollapse }
        set { self.textInputNodeImpl.textView.toggleQuoteCollapse = newValue }
    }

    func deleteBackward() {
        self.textInputNodeImpl.textView.deleteBackward()
    }

    func isCurrentlyEmoji() -> Bool {
        return self.textInputNodeImpl.isCurrentlyEmoji()
    }

    var inputTypingAttributes: [NSAttributedString.Key: Any] {
        get { return self.textInputNodeImpl.textView.typingAttributes }
        set { self.textInputNodeImpl.textView.typingAttributes = newValue }
    }

    func refreshTextInputAttributes(
        context: AnyObject,
        primaryTextColor: UIColor,
        accentTextColor: UIColor,
        baseFontSize: CGFloat,
        spoilersRevealed: Bool,
        availableEmojis: Set<String>,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    ) {
        refreshChatTextInputAttributes(context: context, textView: self.textInputNodeImpl.textView, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, baseFontSize: baseFontSize, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
            return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
        })
    }

    func refreshTextInputTypingAttributes(textColor: UIColor, baseFontSize: CGFloat) {
        refreshChatTextInputTypingAttributes(self.textInputNodeImpl.textView, textColor: textColor, baseFontSize: baseFontSize)
    }

    // MARK: - ChatInputContent model seam (legacy backend)

    func applyRenderingConfig(context: AnyObject, baseFontSize: CGFloat, textColor: UIColor, primaryTextColor: UIColor, accentTextColor: UIColor, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) {
        self.renderingConfig = RenderingConfig(context: context, baseFontSize: baseFontSize, textColor: textColor, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider)
    }

    /// Run the in-place per-edit decoration fix-up on the live text storage, using the host inputs last supplied
    /// via `applyRenderingConfig`. This is `refreshChatTextInputAttributes` — the typing-maintenance pass
    /// (mention/url/quote range re-validation + re-decoration), NOT the same as `setInputContent`'s decorate
    /// step. The node calls this itself (after a content set; later, on its own text changes), so the chat layer
    /// no longer drives `refreshTextInputAttributes`. No-op until the host has configured the node.
    private func refreshDecorationFromStoredConfig() {
        guard let cfg = self.renderingConfig, let context = cfg.context else {
            return
        }
        refreshChatTextInputAttributes(context: context, textView: self.textInputNodeImpl.textView, primaryTextColor: cfg.primaryTextColor, accentTextColor: cfg.accentTextColor, baseFontSize: cfg.baseFontSize, spoilersRevealed: cfg.spoilersRevealed, availableEmojis: cfg.availableEmojis, emojiViewProvider: cfg.emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
            return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
        })
    }

    func setInputContent(_ content: ChatInputContent, selection: ChatInputSelection) {
        // Convert the model to its display-neutral string, then decorate it exactly as the host used to
        // (fonts/colors/spoiler-clear/collapsed-quote attachments). `attributedString(from:)` round-trips the
        // chat currency for the carried attribute set, so this is byte-identical to the former host path.
        let semantic = attributedString(from: content)
        if let cfg = self.renderingConfig, let context = cfg.context {
            self.attributedText = textAttributedStringForStateText(context: context, stateText: semantic, fontSize: cfg.baseFontSize, textColor: cfg.textColor, accentTextColor: cfg.accentTextColor, writingDirection: nil, spoilersRevealed: cfg.spoilersRevealed, availableEmojis: cfg.availableEmojis, emojiViewProvider: cfg.emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
                return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
            })
        } else {
            // No host config yet (not expected at a drive site, since the host calls applyRenderingConfig first).
            self.attributedText = semantic
        }
        self.selectedRange = selection.nsRange(in: content)

        // Run the in-place fix-up the host used to call right after `setInputContent` (the former
        // `refreshTextInputAttributes` at the drive sites). Same function, same stored inputs, same point in the
        // sequence — so this is a 1:1 relocation. Overlay rebuild (`updateRichRendering`) still self-heals on the
        // subsequent layout pass (`onUpdateLayout`).
        self.refreshDecorationFromStoredConfig()
    }

    func currentInputContent() -> (content: ChatInputContent, selection: ChatInputSelection) {
        // Strip the display decoration (emoji/collapsed-quote attachments → semantic attributes) before
        // converting, mirroring the host's `stateAttributedStringForText` read-back.
        let semantic = stateAttributedStringForText(self.attributedText ?? NSAttributedString())
        let content = chatInputContent(from: semantic)
        return (content, ChatInputSelection(nsRange: self.selectedRange, in: content))
    }

    func setInputScrollIndicatorInsets(_ insets: UIEdgeInsets) {
        self.textInputNodeImpl.textView.scrollIndicatorInsets = insets
    }

    func prepareForSpoilerReveal() {
        self.textInputNodeImpl.textView.isScrollEnabled = false
    }

    var inputContentOffset: CGPoint {
        return self.textInputNodeImpl.textView.contentOffset
    }

    func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        return self.textInputNodeImpl.textHeightForWidth(width, rightInset: rightInset)
    }

    func measuredTextFieldHeight(forWidth width: CGFloat, lineCount: Int) -> CGFloat {
        let count = max(1, lineCount)
        let text = Array(repeating: "A", count: count).joined(separator: "\n")
        let attributed = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: max(1.0, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0.0
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        layoutManager.ensureLayout(for: container)
        // Add the same vertical container inset the live `textHeightForWidth` adds (ChatInputTextView), so the
        // probe matches the real field height.
        let inset = self.textInputNodeImpl.textView.textContainerInset
        return ceil(layoutManager.usedRect(for: container).height + inset.top + inset.bottom)
    }

    func updateLayout(size: CGSize) {
        self.textInputNodeImpl.updateLayout(size: size)
    }

    func layoutInputField() {
        self.textInputNodeImpl.layout()
    }

    var textFieldFrame: CGRect {
        get { return self.textInputNodeImpl.frame }
        set { self.textInputNodeImpl.frame = newValue }
    }

    var inputView: UIView {
        return self.textInputNodeImpl.view
    }

    var inputCaretColor: UIColor {
        get { return self.textInputNodeImpl.textView.tintColor }
        set { self.textInputNodeImpl.textView.tintColor = newValue }
    }

    var inputTheme: ChatInputTextView.Theme? {
        get { return self.textInputNodeImpl.textView.theme }
        set { self.textInputNodeImpl.textView.theme = newValue }
    }

    var inputDelegate: ChatInputTextNodeDelegate? {
        get { return self.textInputNodeImpl.delegate }
        set { self.textInputNodeImpl.delegate = newValue }
    }

    var keyboardInputView: UIView? {
        get { return self.textInputNodeImpl.textView.inputView }
        set { self.textInputNodeImpl.textView.inputView = newValue }
    }

    func reloadInputViews() {
        self.textInputNodeImpl.textView.reloadInputViews()
    }

    var currentRightInset: CGFloat {
        return self.textInputNodeImpl.textView.currentRightInset
    }

    func applyAutocorrection() {
        Keyboard.applyAutocorrection(textView: self.textInputNodeImpl.textView)
    }

    var usesNativeRichTextEngine: Bool { return false }

    // The legacy backend builds its menu via ChatTextInputPanelNode.chatInputTextNodeMenu; this hook is unused.
    var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])?

    // The legacy backend has no tables; this hook is never fired.
    var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?

    // The legacy backend has no inline media; this hook is never fired.
    var onRequestMediaControl: ((MediaControlContext) -> Void)?

    // The legacy path routes media via `chatInputTextNodeShouldPaste`; these hooks are never read.
    public var canPasteMedia: (() -> Bool)?
    public var onPasteMedia: (() -> Bool)?
    // The legacy backend has no native editor; the parser is stored but never consulted.
    public var pastedMarkdownFragmentParser: ((String) -> Document?)?

    func performFormatAction(_ action: ChatRichTextFormatAction) {}
    func performRichPaste() {}
    func currentRichTextLinkURL() -> String? { return nil }
    func selectedRichText() -> String { return "" }
    func applyRichTextLink(_ url: String?) {}
}
