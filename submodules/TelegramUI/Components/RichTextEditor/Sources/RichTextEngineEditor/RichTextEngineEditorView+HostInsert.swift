#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// **An insert the host makes on the user's behalf goes in where the user is, as the user would.**
///
/// The chat inserts text into the composer from outside the editor: an emoji tapped on its emoji
/// keyboard (static or custom), the avatar context menu's Mention. It used to do that by rewriting the
/// flat `NSAttributedString` projection of the whole composer and setting it back, which has no
/// vocabulary for a heading, a list, a table or a pull quote's author — so each of those edits retyped
/// the whole composer as body paragraphs and dropped the table. It also could not reach a caret that is
/// off the composer's flat axis: with the caret in a table cell the flat selection reads as the end of
/// the text, so the emoji landed after the last paragraph (composer harness p18,
/// `HarnessChatInsertStructureTests`).
///
/// Here the insert is made at the ENGINE's selection, one run at a time, through the verbs the editor
/// already has:
/// - plain text through `insertText`, the typing path — the surface gate decides the selection and any
///   newline, and the typed-text policy gives the text the caret's formatting, so the result is what
///   typing the same text produces;
/// - a custom emoji through `insertEmoji`, carrying a spoiler it lands inside (the one inline mark that
///   is model state on an atom);
/// - a run carrying a link (a mention or date marker, a URL) typed, cleared of inline code it inherited
///   (an entity is never code too), and then linked with `setLink`.
///
/// The whole insert is ONE undo step on top of the stack (the typing before it stays its own step) and
/// ONE change notification.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    public func insertInlineRunsOnUsersBehalf(_ runs: [TextRun]) -> Bool {
        let runs = runs.filter { !$0.text.isEmpty }
        guard !runs.isEmpty, !currentRoles.isEmpty else { return true }
        // Asked once, before anything moves: the caret the user tapped at is the one whose spoiler an
        // emoji inherits, not the one its own text leaves behind.
        let insideSpoiler = selectionIsInsideSpoiler()
        let before = currentUndoSnapshot()
        endTypingRun()
        deliveringOneChangeNotificationAcrossSteps {
            engineUndoManager.disableUndoRegistration()
            for run in runs {
                insertRunOnUsersBehalf(run, insideSpoiler: insideSpoiler)
            }
            engineUndoManager.enableUndoRegistration()
            // Registered before the notification is delivered, so a host reading `canUndo` from it
            // sees the step.
            if replayDocument != before.document {
                recordUndoStepForCommand(restoring: before)
            }
        }
        setNeedsLayout()
        return true
    }

    private func insertRunOnUsersBehalf(_ run: TextRun, insideSpoiler: Bool) {
        if let emoji = run.attributes.emoji {
            insertEmoji(id: emoji.id, altText: emoji.altText, spoiler: insideSpoiler)
            return
        }
        guard let link = run.attributes.link, !link.isEmpty else {
            insertText(run.text)
            return
        }
        insertText(run.text)
        // Linked only when the gate forwarded the text as it was given (a refusal, or a one-line field
        // rewriting it, leaves nothing to link): the range ending at the caret must hold exactly it.
        let typed = EngineDocumentBridge.engineText(run.text)
        let length = (typed as NSString).length
        let caret = engineSelectedRange
        guard caret.length == 0, caret.location >= length else { return }
        let range = NSRange(location: caret.location - length, length: length)
        guard flatEngineText(in: range) == typed else { return }
        engineSelectedRange = range
        // Content arriving on the user's behalf keeps its ENTITY (the p23 rule, `withoutInlineCodeOverLinks`):
        // typed inside or after inline code the run took the code's typing attributes, and `setLink` refuses a
        // range holding inline code — the refusal is the Format ▸ Link COMMAND's, so the mention was inserted as
        // plain code text (composer harness p24, `HarnessMentionIntoInlineCodeTests`). The inserted run sheds the
        // code first; the code around it is untouched.
        if inlineTargetsHold(Self.inlineCodeAttributeKey) {
            applyInlineCode(enabling: false)
        }
        setLink(link)
        engineSelectedRange = NSRange(location: caret.location, length: 0)
    }

    /// Whether an atom inserted over the selection belongs inside a spoiler. Over a range, the range's
    /// own answer; at a caret, the character BEFORE it (what the user was typing in), else the one at
    /// it — the chat's old transform's rule. `isSpoilerActive()` cannot answer a caret: a spoiler
    /// continues into typed text through the typed-text POLICY, not through the typing attributes it
    /// reads, so at a caret inside a spoiler it says no.
    private func selectionIsInsideSpoiler() -> Bool {
        let selection = engineSelectedRange
        if selection.length > 0 {
            return isSpoilerActive()
        }
        guard let index = roleIndex(atFlatOffset: selection.location) else { return false }
        let blocks = engine.attributedBlocks
        guard index < blocks.count else { return false }
        let block = blocks[index]
        let local = selection.location - flatOffset(ofRoleAt: index)
        let source = local > 0 ? local - 1 : 0
        guard source >= 0, source < block.length else { return false }
        return (block.attribute(Self.spoilerAttributeKey, at: source, effectiveRange: nil) as? Bool) == true
    }

    /// The engine's text over a flat range, on the canonical axis `engineSelectedRange` speaks.
    private func flatEngineText(in range: NSRange) -> String? {
        guard let start = engine.position(from: engine.beginningOfDocument, offset: range.location),
              let end = engine.position(from: start, offset: range.length),
              let textRange = engine.textRange(from: start, to: end) else { return nil }
        return engine.text(in: textRange)
    }
}
#endif
