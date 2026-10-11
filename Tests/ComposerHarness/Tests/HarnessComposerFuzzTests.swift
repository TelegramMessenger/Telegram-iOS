import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
// `ChatTextInputAttributes`, for the chat-side insert op (p18).
import TextFormat
// `defaultDarkPresentationTheme`, for the end-of-sequence theme round trip.
import TelegramPresentationData
// `ChatTextInputState`, for the external-push ops.
import AccountContext
@testable import ComposerHarnessLib
// The engine's own presentation / derived-view verifiers, asked directly (non-fatally) after each step.
@testable import RichTextEngineEditor

/// A deterministic, seeded, random-operation test of the ENGINE composer, with invariant checks after
/// every step and three round trips at the end of each sequence. (Engine only by decision,
/// 2026-09-23: legacy is a control, not a subject; the legacy regressions this fuzz found while it
/// still covered legacy stand as their own tests.)
///
/// **Operations** — each drives the surface the keyboard, the edit menu or the Format menu drives:
/// - `insert`: `UIKeyInput.insertText` on `TGIDObservingBlockTextView` — Latin, punctuation, emoji
///   (skin tone, ZWJ family), CJK, Japanese, Arabic, Hebrew, Devanagari, Thai, a combining accent, a
///   bidi mark, mixed-direction runs, and a lone `"\n"` (Return);
/// - `deleteBackward`; `select` (caret or range, snapped to composed characters);
/// - `edge`: Return / Backspace / a letter with the caret first put at a block (engine line) start or
///   end — where the structural rules live;
/// - `format`: `performFormatAction` for Bold, Italic, Monospace, Strikethrough, Underline, Spoiler,
///   Quote, Code, Pull Quote (always on a selection, as the menu is);
/// - `link`: Format ▸ Link through the panel, answered by `linkPromptOverride` (empty = remove);
/// - `copy` / `cut` / `paste` on the view; `pasteText`: markdown lists, ordered lists, checklists,
///   headings, a quote, a code fence, inline markup, multi-line plain text (the harness wires the
///   app's `pastedMarkdownParser`);
/// - `tab`: Tab / Shift-Tab — the editor's own key command when it claims one (list item), else
///   UIKit's default, a tab character;
/// - `undo` / `redo` on the view's `undoManager`, interleaved.
///
/// **The extended mix** (eleventh wave, 2026-09-23): `typeInFormat` (select, format, then type at the
/// range's start / inside / end: inline code and spoilers typed into, around and across),
/// `selectAllFormat` (Select All + any Format command), `formatThrice` (inline formats only, see the
/// invariant), `selfPaste` (the document's own copy pasted at a random offset), `send` (the chat's
/// clear, then a letter); a very long typed run; pastes of pipe tables, a nested quote and a very long
/// paragraph; and starting documents with a pull quote and a block quote WITH authors, a nested
/// quote, a table and an expanded details block. Tables and details are projected onto the engine
/// axis (one line per cell, row-major; a details title line then its body).
///
/// **The p11 mix** (2026-09-24): `compose` (Japanese, kana, Korean and pinyin candidate sequences
/// through `setMarkedText(_:selectedRange:)`, over a caret or a selection, committed by `unmarkText`,
/// by `insertText` of the final candidate, or cancelled) and `keyMove` (the private arrow-key actions
/// UIKit performs for ←/→/↑/↓ with ⌥/⌘/⇧), plus emoji-keyboard clusters among the insertions. Their
/// op-specific invariants are on `composeViolation` and in `execute` (an arrow never edits).
///
/// **External pushes** (p15, 2026-09-24): now and then (`FuzzConfig.externalPushPercent`, drawn from a
/// stream of its own) a step begins with `push` — the chat replacing the composer's content and/or
/// selection from outside (`updateChatPresentationInterfaceState` → `updateInputTextState`, driven
/// through `HarnessPanelHost.setInputContent(_:selectionRange:)`), as a draft synced from another device
/// or Send's clear does: the model with a paragraph appended / prepended, its first
/// block replaced, its last dropped, a starting document, or the SAME content with another selection.
/// Invariants in `pushViolation` (the push lands exactly; a content-equal push leaves the focused
/// editor's selection alone; nothing is left to undo across it). On in `runFuzz` only (both methods);
/// the pinned seed-34 test runs without it, so its stream is unchanged.
///
/// **Line ops** (p16, 2026-09-25): now and then (`FuzzConfig.lineOpPercent`, a stream of its own) a
/// step begins with a `line` op (`FuzzLineOp`): a checklist seeded by paste, the checkbox tap (flips
/// exactly that item, undo / redo round trip), Return at a checked item's start, a whole top-level line
/// selected to the next line's start then Backspace, or then Quote / Code / Pull Quote. On in `runFuzz`
/// only; the pinned seed-34 test leaves it off. Also p16: no run in the model may hold a bare U+FFFC.
///
/// **Repeated-arrow walks** (p17, 2026-09-25): now and then (`FuzzConfig.keyWalkPercent`, a stream of its
/// own) a step begins with `keyWalk` — ↑ or ↓ pressed 2-6 times from a caret, each press given the history
/// the previous press returned, as `UIKeyboardImpl` does for a held key (the `keyMove` op passes none).
/// Invariant: every press moves the moving end the key's way or not at all; the model is unchanged. On in
/// `runFuzz` only.
///
/// **Chat-side inserts** (p18, 2026-09-25): now and then (`FuzzConfig.chatInsertPercent`, a stream of its
/// own) a step begins with `chatInsert`, an emoji inserted by the CHAT as its emoji keyboard does
/// (`HarnessChatInserts.emojiKeyboard` — the shared `chatComposerInsertTextOnUsersBehalf` the chat's
/// closure calls, not a copy of it). Invariants in `chatInsertViolation`: one undo step, and the result
/// equals typing the emoji at the same selection. The op leaves the TYPED result, so the sequence goes
/// on. Every paste op now spins `FuzzConfig.pasteSettle`: UIKit's plain paste lands 20-30 ms late, in
/// a stock `UITextView` too (`HarnessPasteLatencyOracleTests`).
///
/// **Local moves** (p19, 2026-09-25): now and then (`FuzzConfig.movePercent`, a stream of its own) a step
/// begins with `move` — a range dragged to another offset through the editor's own lift and drop entry
/// points (`makeTextDragContext` / `performLocalMove`). Invariants in `moveViolation`: a refused move
/// changes nothing, an accepted one is one undo step both ways and neither creates nor loses an atom.
/// Also p19: `FuzzTextInputConsistency` asks the selection's GEOMETRY (finite rects, one logical start
/// and end, a finite first rect) and `characterRange(byExtending:)` at the selection's ends.
///
/// **The send path and external pastes** (p20, 2026-09-30): after every step the CHAT's copy of the state
/// (what `sendCurrentMessage` reads) must equal the node's model in full, not only its text, and sending it
/// as the chat does and loading the message back as editing does (`HarnessSendPath`) must give it back,
/// modulo the oracle's documented canonical form. The sequence ends with that edit load done for real (an
/// external set of the reloaded content, read back). Now and then (`FuzzConfig.externalPastePercent`, its
/// own stream) a step begins with `externalPaste` — RTF, RTFD, HTML, a URL or two text items from another
/// app, pasted at a caret; one undo reverts it, redo restores it (`externalPasteViolation`).
///
/// **p21 (2026-10-01).** The `compose` oracle composes a second time on the state the undo restored and
/// compares THAT with typing there (like with like; an undo restores the model, not a separator's typing
/// attributes, `HarnessUndoSeparatorTypingAttributesTests`). Two more ops, each from its own stream and on in
/// `runFuzz` only: `undoRedo` after the step's op (one undo + one redo returns the document, the undo
/// changes something) and `environment` before it (dark / light theme, 340 / 402pt, left in place; reset
/// before the end-of-sequence round trips), plus a `customInsert` phase (a custom emoji through the chat's
/// emoji keyboard; one undo step and its redo). The bare-`U+FFFC` invariant now also reads code languages.
///
/// **p22 (2026-10-01).** A `formatTypeOver` op (own stream, `runFuzz` only): an inline trait (Bold, Italic,
/// Strikethrough, Underline) over a selection — half the time one starting on an EMPTY line — then a
/// character typed over it; judged in documents of top-level body paragraphs only: the typed text carries
/// the trait exactly when the selection does after the command (`formatTypeOverViolation`). The `compose`
/// op also asks, after the first candidate, that nothing can be REDONE while the composition is open (a
/// stock text view's first marked edit clears the redo stack). The `move` op's letter check counts a LOSS
/// only (text moved out of a code language line into its body is a gain, default seed 27).
///
/// **p24 (2026-10-02).** A `chatMention` op (own stream, `runFuzz` only): the avatar menu's Mention at the selection, one
/// undo step, and a mention entity wherever the destination holds runs (`chatMentionViolation`). A `normalisingSet` op
/// (own stream, `runFuzz` only): the model with a block the editor normalises on a set appended from outside
/// (`FuzzNormalisingSet`), checked — the chat's copy is the model, the send path carries it, every `UITextInput`
/// answer over it agrees — and then set back. And a per-step LENGTH check in `violations()` only: on the text route
/// the panel counts what is sent. Each defect they hit was filed with a red test and fixed in the p24 fix wave
/// (which added `U+2029`, NEL and lone-CR variants to `FuzzNormalisingSet`); none is filtered.
///
/// **Invariants after every step** (`violations()`, each re-read once after a further 0.3 s settle
/// before it counts — a paste's change reaches the chat's state later than a keystroke's):
/// - the process is alive (every op is printed BEFORE it runs, prefixed `FUZZ`);
/// - the model (`currentInputContent`) projected onto the ENGINE axis equals the engine view's text,
///   line by line (`FuzzModel.engineLines`: a code block's language line first, compared exactly; a
///   quote's author line only when the bridge emits one; `"\n"` inside any block is `U+2028`);
/// - the chat's copy of the input state (`effectiveInputState`) has the model's plain text;
/// - the node's selection (model axis) and the view's selection (view axis) lie within bounds;
/// - the backend is still the engine;
/// - the engine's own verifiers: presentation derived from the role, derived views present and
///   placed. In a test process the engine TRAPS on these; the fuzz switches the trap off
///   (`FuzzEngineVerifier`) and asks the questions itself;
/// - op-specific: after `formatThrice` the model after the third application equals the model after
///   the first (after the first the range is uniform, so the second must be an exact round trip);
///   after `send` the typed letter is a plain body paragraph.
///
/// Every op that can take long is printed as `FUZZ SLOW` (over 1 s): not a failure, a lead.
/// The pasteboard is written by this process before it is ever read, and re-written before a paste
/// whenever its `changeCount` moved since our last write (the simulator syncs the Mac's clipboard).
///
/// **At the end of a sequence:**
/// 1. redo whatever is left (the tip); undo until `canUndo` is false → the starting model; redo until
///    `canRedo` is false → the tip (models compared with adjacent equal runs merged);
/// 1a. a theme round trip, a WIDTH round trip (300, 700, back to 402pt through the panel's own
///    `updateLayout(width:)`: the document, the selection and the settled invariants survive, and back at
///    402pt every caret rect equals the one before; p14) and a local drag-and-drop move plus its undo. None
///    of them consumes randomness, so every seed's op stream is unchanged;
/// 2. copy → paste-back: Select All, Copy, Paste over it → the tip again, modulo the documented
///    trailing line a paste ending in a non-body block at the document end adds
///    (`HarnessContainerCutPasteRoundTripTests`); then one Undo → the tip.
///
/// **Known defects — excluded, never silently.** Each is reduced to a red regression test and filed in
/// `docs/findings.md`; the summary line prints how often each was hit. Remove an entry when its test
/// goes green. `FuzzKnownDefect` recognises exact signatures (see each case for its red test); a
/// signature that leaves the document corrupt ENDS the sequence, counted rather than failed.
///
/// **Replay.** A failure prints the seed, the failing step and the op log as `FuzzOp` literals, which
/// `replay` / `perform` take. `--test_env=FUZZ_SEEDS=<n>` or `<a>-<b>` reruns or widens the seeds;
/// `FUZZ_STEPS=<n>` changes the length; `FUZZ_VERBOSE=1` prints the model after every op.
///
/// **Tier 1**: every op is the UIKit / menu entry point, in-process.
enum FuzzConfig {
    static let seeds: [UInt64] = Array(1 ... 30)
    static var steps: Int {
        return ProcessInfo.processInfo.environment["FUZZ_STEPS"].flatMap { Int($0) } ?? 60
    }
    /// Set to replay exactly one seed.
    static let onlySeed: UInt64? = nil
    /// `--test_env=FUZZ_SEEDS=<a>-<b>` (or one number) runs those seeds instead: a wider discovery
    /// sweep, or a replay, without editing the file.
    static var effectiveSeeds: [UInt64] {
        if let onlySeed = self.onlySeed {
            return [onlySeed]
        }
        if let value = ProcessInfo.processInfo.environment["FUZZ_SEEDS"] {
            let parts = value.split(separator: "-").compactMap { UInt64($0) }
            if parts.count == 2, parts[0] <= parts[1] {
                return Array(parts[0] ... parts[1])
            }
            if parts.count == 1 {
                return parts
            }
        }
        return self.seeds
    }
    /// Seconds the run loop is spun after every op (the editors deliver selection and change
    /// notifications a run-loop turn late, and the panel syncs its state after them).
    static let stepSettle: TimeInterval = 0.02
    static let undoAllCap = 400
    /// p15 (2026-09-24): the chance, per step, of an EXTERNAL push before the step's op — the chat
    /// replacing the composer's content and/or selection (a draft synced from another device, a reply or
    /// bot-keyboard insert, a suggestion commit). Drawn from a stream of its own, so the op stream is the
    /// same draw sequence it was; the document the ops act on differs once a push has landed. On only in
    /// `runFuzz` (both fuzz methods); pinned-seed tests leave it off.
    static let externalPushPercent = 7
    static var externalPushes = false
    /// p16 (2026-09-25): the chance, per step, of a LINE op (`FuzzLineOp`) before the step's op — list and
    /// checklist state and whole-line selections — drawn from a stream of its own, so the op stream is
    /// the same draw sequence it was. On only in `runFuzz`; pinned-seed tests leave it off.
    static let lineOpPercent = 8
    static var lineOps = false
    /// p17 (2026-09-25): the chance, per step, of a repeated-arrow WALK (`FuzzOp.keyWalk`) before the
    /// step's op, drawn from a stream of its own so every other stream is unchanged. On only in `runFuzz`.
    static let keyWalkPercent = 6
    static var keyWalks = false
    /// p17: the chance, per step, of a table / details command (`FuzzOp.structural`), its own stream.
    static let structuralPercent = 6
    static var structuralOps = false
    /// p18 (2026-09-25): the chance, per step, of a CHAT-SIDE insert (`FuzzOp.chatInsert`) before the
    /// step's op, its own stream. On only in `runFuzz`.
    static let chatInsertPercent = 5
    static var chatInserts = false
    /// p19 (2026-09-25): the chance, per step, of a local drag-and-drop move (`FuzzOp.move`), its own
    /// stream. On only in `runFuzz`.
    static let movePercent = 5
    static var moves = false
    /// p18 (2026-09-25): seconds spun after a paste op. UIKit's own paste (a stock `UITextView`'s too)
    /// lands asynchronously, 20-30 ms after `paste:` (measured: 6-9 run-loop spins), so the step's 0.02 s
    /// settle sometimes ended before it and the NEXT op (seed 28 step 17: an external push) ran first,
    /// then the paste landed on the pushed content. A stock text view does exactly the same, so that
    /// ordering is not a product defect; the fuzz waits for the paste instead.
    static let pasteSettle: TimeInterval = 0.25
    /// p20 (2026-09-30): the chance, per step, of an EXTERNAL rich paste (`FuzzOp.externalPaste`), its own
    /// stream. On only in `runFuzz`.
    static let externalPastePercent = 5
    static var externalPastes = false
    /// p21 (2026-10-01): the chance, per step, of an UNDO + REDO round trip (`FuzzOp.undoRedo`) — every op's
    /// last step undone and redone at once, which until now only a few ops checked for themselves — its
    /// own stream. On only in `runFuzz`.
    static let undoRedoPercent = 6
    static var undoRedos = false
    /// p21: the chance, per step, of an ENVIRONMENT change mid-sequence (`FuzzOp.environment`: the dark or
    /// light theme, a 340pt or the 402pt width), left in place for the ops that follow; its own stream. The
    /// sequence goes back to light / 402pt before its end-of-sequence round trips. On only in `runFuzz`.
    static let environmentPercent = 4
    static var environments = false
    /// p21: the chance, per step, of a CUSTOM emoji inserted by the chat's emoji keyboard (`chatInsert` with
    /// `custom: true`), its own stream. No typing twin exists, so its invariants are one undo step and a
    /// redo that restores it, plus every per-step check (the send oracle, no bare `U+FFFC`). `runFuzz` only.
    static let customInsertPercent = 4
    static var customInserts = false
    /// p22 (2026-10-01): the chance, per step, of an inline Format command over a selection followed by
    /// TYPING over that selection (`FuzzOp.formatTypeOver`), its own stream; half the time the selection
    /// starts on an empty line. `runFuzz` only.
    static let formatTypeOverPercent = 5
    static var formatTypeOvers = false
    /// p23 (2026-10-01): the chance, per step, of text holding a line-break character other than "\n"
    /// (`U+2028`, `U+2029`, CR, NEL) typed into a ONE-LINE field — a code language, a quote's or pull
    /// quote's author, a details title (`FuzzOp.oneLineInsert`) — its own stream. `runFuzz` only.
    static let oneLineInsertPercent = 4
    static var oneLineInserts = false
    /// p24 (2026-10-02): the chance, per step, of the avatar menu's Mention (`FuzzOp.chatMention`, the chat's shared
    /// `chatComposerInsertMention`) at the current selection, its own stream. `runFuzz` only.
    static let chatMentionPercent = 4
    static var chatMentions = false
    /// p24: the chance, per step, of an external set of content the editor NORMALISES on the way in
    /// (`FuzzOp.normalisingSet`: formatting / a mention / a custom emoji in a code body, a language with whitespace,
    /// a line separator or CRLF in a body paragraph, and the p23 kinds as controls), its own stream. `runFuzz` only.
    static let normalisingSetPercent = 3
    static var normalisingSets = false
    /// `--test_env=FUZZ_VERBOSE=1` prints the model after every op (for reducing a failure).
    static let verbose = ProcessInfo.processInfo.environment["FUZZ_VERBOSE"] != nil
}

/// SplitMix64: small, fast, and identical on every run for a given seed.
struct FuzzRandom {
    private var state: UInt64
    init(seed: UInt64) {
        // Scrambled, so that consecutive seeds are unrelated streams (a plain `seed * golden` start
        // makes seed n+1's stream seed n's shifted by one draw).
        var z = seed &+ 0x2545F4914F6CDD1D
        z = (z ^ (z >> 33)) &* 0xFF51AFD7ED558CCD
        z = (z ^ (z >> 33)) &* 0xC4CEB9FE1A85EC53
        self.state = z ^ (z >> 33)
    }
    mutating func next() -> UInt64 {
        self.state = self.state &+ 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(self.next() % UInt64(upperBound))
    }
    mutating func pick<T>(_ values: [T]) -> T {
        return values[self.int(values.count)]
    }
    mutating func chance(_ percent: Int) -> Bool {
        return self.int(100) < percent
    }
}

enum FuzzFormat: String, CaseIterable {
    case bold, italic, monospace, strikethrough, underline, spoiler, quote, code, pullQuote
}

/// Non-ASCII made visible: the Bazel test log does not carry it reliably.
func fuzzEscaped(_ text: String) -> String {
    return "\"" + text.unicodeScalars.map { scalar -> String in
        if scalar == "\n" { return "\\n" }
        if scalar.value >= 0x20 && scalar.value < 0x7F { return String(scalar) }
        return String(format: "\\u{%X}", scalar.value)
    }.joined() + "\""
}

/// One operation, fully resolved (offsets included), so a logged sequence replays exactly and a
/// reduced regression test can spell one out.
enum FuzzOp: CustomStringConvertible {
    case insert(String)
    case deleteBackward
    /// View-axis offsets (UTF-16), a caret when equal.
    case select(Int, Int)
    /// A Format command; when `selecting` is set the selection is made first (the menu is offered on
    /// a selection).
    case format(FuzzFormat, selecting: (Int, Int)?)
    case copy, cut, paste, undo, redo
    /// Return / Backspace / a letter with the caret put at a block (engine line) boundary first.
    case edge(Int, EdgeAction)
    /// Plain text written to the pasteboard, then `paste:` — markdown lists, headings, quotes, code
    /// fences reach the composer this way (the harness wires the app's `pastedMarkdownParser`).
    case pasteText(String)
    /// Tab / Shift-Tab from a hardware keyboard: the editor's own key command when it claims one
    /// (list item, table cell, details), else UIKit's default, a tab character.
    case tab(shift: Bool)
    /// Format ▸ Link answered through `linkPromptOverride`; an empty URL removes the link.
    case link(String, selecting: (Int, Int)?)
    /// Select the range, apply the format, put the caret at the range's start / inside it / at its
    /// end, and type — inline code and spoilers typed into, around and across.
    case typeInFormat(FuzzFormat, (Int, Int), TypeAt, String)
    /// Select All, then a Format command.
    case selectAllFormat(FuzzFormat)
    /// The same Format command three times on the same range. Invariant: the model after the third
    /// equals the model after the first (the pair in between is a round trip; after the first
    /// application the range is uniform, so the toggle's partial-coverage rule does not apply).
    case formatThrice(FuzzFormat, (Int, Int))
    /// Select All, Copy, caret at the offset, Paste: the document's own copy pasted into itself.
    case selfPaste(Int)
    /// Send: the chat's programmatic clear, then one typed letter. Invariant: that letter is a plain
    /// body paragraph with no formatting carried over.
    case send
    /// An IME composition — the candidate steps a Japanese / Korean / pinyin keyboard sends through
    /// `setMarkedText(_:selectedRange:)` — over the selection made first (when given), then committed
    /// (p11, 2026-09-24). Invariants in `composeViolation`.
    case compose(FuzzIME, FuzzCommit, selecting: (Int, Int)?)
    /// A hardware arrow-key action on the first responder (`_moveLeft:withHistory:` & co., what ⌘/⌥/⇧
    /// + arrows perform), extending the selection or not. Invariant: the model is unchanged.
    case keyMove(String, extend: Bool)
    /// p15: an EXTERNAL set, as the chat makes one through `updateChatPresentationInterfaceState` →
    /// `updateInputTextState` → `setInputContent`: the content `FuzzPush` derives from the current model
    /// (variant indexes the starting documents for `.startingDocument`), with the selection given on the
    /// MODEL's flat axis. Invariants in `pushViolation`.
    case push(FuzzPush, Int, (Int, Int))
    /// p16: a list / line op (`FuzzLineOp`) on the `a`-th candidate top-level block (modulo the
    /// candidates), `b` choosing a variant. Invariants in `lineOpViolation`.
    case line(FuzzLineOp, Int, Int)
    /// p17: ↑ / ↓ pressed `presses` times from a caret put at `from` first, each press given the history
    /// the previous one returned (as `UIKeyboardImpl` does for a held or repeated arrow key), extending
    /// the selection or not. Invariants in `keyWalkViolation`.
    case keyWalk(down: Bool, from: Int, presses: Int, extend: Bool)
    /// p17: a structural command on a table or a details block (`FuzzStructOp`), with the caret first put
    /// in the `a`-th candidate cell / details title (modulo the candidates). Invariants in
    /// `structuralViolation`.
    case structural(FuzzStructOp, Int)
    /// p18: an emoji inserted by the CHAT, as its emoji keyboard does (`ChatControllerLoadDisplayNode`'s
    /// `insertText` closure, through `updateTextInputStateAndMode`), at the current selection; a custom
    /// emoji when the flag is set. Invariants in `chatInsertViolation`.
    case chatInsert(String, custom: Bool)
    /// p19: a local drag-and-drop MOVE of `[a, b)` to `target` (engine axis), through the editor's own
    /// lift and drop entry points. Invariants in `moveViolation`.
    case move(Int, Int, Int)
    /// p20: rich text from ANOTHER app (`FuzzExternalPaste.sources[variant]`: RTF, RTFD, HTML, a URL, two
    /// items) written to the pasteboard and pasted at a caret put at `at` first. Invariants in
    /// `externalPasteViolation`.
    case externalPaste(Int, at: Int)
    /// p21: undo the last step and redo it (`undoRedoViolation`).
    case undoRedo
    /// p21: 0 dark theme, 1 light theme, 2 a 340pt width, 3 the 402pt width (`environmentViolation`).
    case environment(Int)
    /// p22: select `[a, b)` (view axis), apply an inline format, then type over the selection
    /// (`formatTypeOverViolation`).
    case formatTypeOver(FuzzFormat, (Int, Int))
    /// p23: text holding a line-break character typed at the end of the `a`-th one-line field (modulo the
    /// candidates; `b` picks the character) — `oneLineInsertViolation`.
    case oneLineInsert(Int, Int)
    /// p24: the avatar context menu's Mention at the current selection (`chatMentionViolation`).
    case chatMention
    /// p24: the model with `FuzzNormalisingSet.blocks[variant]` appended, set from outside (`normalisingSetViolation`).
    case normalisingSet(Int)

    var description: String {
        switch self {
        case let .insert(text): return ".insert(\(fuzzEscaped(text)))"
        case .deleteBackward: return ".deleteBackward"
        case let .select(a, b): return ".select(\(a), \(b))"
        case let .format(format, selecting):
            if let selecting { return ".format(.\(format.rawValue), selecting: (\(selecting.0), \(selecting.1)))" }
            return ".format(.\(format.rawValue), selecting: nil)"
        case .copy: return ".copy"
        case .cut: return ".cut"
        case .paste: return ".paste"
        case .undo: return ".undo"
        case .redo: return ".redo"
        case let .edge(offset, action): return ".edge(\(offset), .\(action.rawValue))"
        case let .pasteText(text): return ".pasteText(\(fuzzEscaped(text)))"
        case let .tab(shift): return ".tab(shift: \(shift))"
        case let .link(url, selecting):
            if let selecting { return ".link(\(fuzzEscaped(url)), selecting: (\(selecting.0), \(selecting.1)))" }
            return ".link(\(fuzzEscaped(url)), selecting: nil)"
        case let .typeInFormat(format, range, at, text):
            return ".typeInFormat(.\(format.rawValue), (\(range.0), \(range.1)), .\(at.rawValue), \(fuzzEscaped(text)))"
        case let .selectAllFormat(format):
            return ".selectAllFormat(.\(format.rawValue))"
        case let .formatThrice(format, range):
            return ".formatThrice(.\(format.rawValue), (\(range.0), \(range.1)))"
        case let .selfPaste(offset):
            return ".selfPaste(\(offset))"
        case .send:
            return ".send"
        case let .compose(ime, commit, selecting):
            if let selecting { return ".compose(.\(ime.rawValue), .\(commit.rawValue), selecting: (\(selecting.0), \(selecting.1)))" }
            return ".compose(.\(ime.rawValue), .\(commit.rawValue), selecting: nil)"
        case let .keyMove(name, extend):
            return ".keyMove(\(fuzzEscaped(name)), extend: \(extend))"
        case let .push(kind, variant, selection):
            return ".push(.\(kind.rawValue), \(variant), (\(selection.0), \(selection.1)))"
        case let .line(kind, a, b):
            return ".line(.\(kind.rawValue), \(a), \(b))"
        case let .keyWalk(down, from, presses, extend):
            return ".keyWalk(down: \(down), from: \(from), presses: \(presses), extend: \(extend))"
        case let .structural(kind, a):
            return ".structural(.\(kind.rawValue), \(a))"
        case let .chatInsert(text, custom):
            return ".chatInsert(\(fuzzEscaped(text)), custom: \(custom))"
        case let .move(a, b, target):
            return ".move(\(a), \(b), \(target))"
        case let .externalPaste(variant, at):
            return ".externalPaste(\(variant), at: \(at))"
        case .undoRedo:
            return ".undoRedo"
        case let .environment(kind):
            return ".environment(\(kind))"
        case let .formatTypeOver(format, range):
            return ".formatTypeOver(.\(format.rawValue), (\(range.0), \(range.1)))"
        case let .oneLineInsert(a, b):
            return ".oneLineInsert(\(a), \(b))"
        case .chatMention:
            return ".chatMention"
        case let .normalisingSet(variant):
            return ".normalisingSet(\(variant))"
        }
    }
}

/// p16 (2026-09-25): ops over lists, checklists and whole lines, drawn from their own stream.
/// - `seedChecklist`: a checklist pasted as markdown at the caret (so the others have items to act on);
/// - `toggleCheck`: the checkbox tap (`toggleChecklistItem`) on a top-level checklist item — exactly
///   that item's `checked` flips, one undo reverts it, redo brings it back;
/// - `returnAtItemStart`: Return at the start of a top-level CHECKED item — the item keeps its check
///   (`HarnessChecklistReturnAtStartTests`, open);
/// - `deleteLine`: a top-level paragraph selected from its start to the next top-level paragraph's
///   start, then Backspace — exactly that paragraph goes (`HarnessWholeLineDeletionTests`, open);
/// - `boundaryFormat`: the same selection, then Quote / Code / Pull Quote — the next paragraph is left
///   alone (`HarnessBlockCommandSelectionEndTests`, open).
/// p17 (2026-09-25): the table and details commands a host menu runs (the table's structural menu, the
/// details chevron), driven on the editor with the caret in a table cell / a details title.
enum FuzzStructOp: String, CaseIterable {
    case rowAbove, rowBelow, deleteRow, columnLeft, columnRight, deleteColumn, convertToText, deleteTable, header, toggleDetails
}

enum FuzzLineOp: String, CaseIterable {
    case seedChecklist, toggleCheck, returnAtItemStart, deleteLine, boundaryFormat
}

/// What an external push puts in the composer (p15), derived from the model at the moment of the push so
/// a logged op replays exactly.
enum FuzzPush: String, CaseIterable {
    /// A paragraph appended after everything (a draft edited on another device).
    case appendParagraph
    /// A paragraph put before everything.
    case prependParagraph
    /// The first block replaced by a plain paragraph.
    case replaceFirstBlock
    /// The last block dropped (with one block: a paragraph appended instead).
    case dropLastBlock
    /// One of the sequence's starting documents (`variant` indexes them): a whole different draft.
    case startingDocument
    /// The SAME content with a different selection: the chat's selection-only echo.
    case sameContent

    static var startingDocuments: [ChatInputContent] = []

    func content(from model: ChatInputContent, variant: Int) -> ChatInputContent {
        var blocks = model.blocks
        switch self {
        case .appendParagraph:
            blocks.append(HarnessEngine.paragraph("Synced line \(variant)."))
        case .prependParagraph:
            blocks.insert(HarnessEngine.paragraph("Remote \(variant)"), at: 0)
        case .replaceFirstBlock:
            if blocks.isEmpty {
                blocks = [HarnessEngine.paragraph("Replaced \(variant)")]
            } else {
                blocks[0] = HarnessEngine.paragraph("Replaced \(variant)")
            }
        case .dropLastBlock:
            if blocks.count > 1 {
                blocks.removeLast()
            } else {
                blocks.append(HarnessEngine.paragraph("Synced line \(variant)."))
            }
        case .startingDocument:
            let documents = Self.startingDocuments.isEmpty ? HarnessComposerFuzzTests.startingContents() : Self.startingDocuments
            return documents[variant % documents.count]
        case .sameContent:
            return model
        }
        return ChatInputContent(blocks: blocks)
    }
}

/// The candidate sequences a CJK / Korean keyboard sends (each step replaces the marked text).
enum FuzzIME: String, CaseIterable {
    case japanese, korean, pinyin, kana

    var steps: [(text: String, selected: NSRange)] {
        func atEnd(_ text: String) -> (text: String, selected: NSRange) {
            return (text, NSRange(location: (text as NSString).length, length: 0))
        }
        switch self {
        case .japanese: return ["k", "か", "かn", "かん", "かんj", "かんじ", "漢字"].map(atEnd)
        case .korean: return ["ㅎ", "하", "한", "한ㄱ", "한그", "한글"].map(atEnd)
        // Pinyin: the keyboard keeps the unconverted tail marked with a selected sub-range.
        case .pinyin: return [atEnd("zhong"), ("zhong guo", NSRange(location: 9, length: 0)),
                              ("中guo", NSRange(location: 1, length: 3)), atEnd("中国")]
        case .kana: return ["a", "あ", "あr", "あり", "ありg", "ありが", "ありがと", "ありがとう"].map(atEnd)
        }
    }
}

/// How a composition ends: the keyboard's commit (`unmarkText`), `insertText` of the final candidate
/// (some keyboards commit that way), or a cancel (the marked text set to "" then unmarked).
enum FuzzCommit: String, CaseIterable {
    case unmark, insertFinal, cancel
}

/// The hardware arrow-key actions UIKit performs on the first responder for ←/→/↑/↓ with ⌥ and ⌘.
enum FuzzKeyMove {
    static let actions = ["_moveLeft:withHistory:", "_moveRight:withHistory:", "_moveUp:withHistory:", "_moveDown:withHistory:",
                          "_moveToStartOfWord:withHistory:", "_moveToEndOfWord:withHistory:",
                          "_moveToStartOfLine:withHistory:", "_moveToEndOfLine:withHistory:",
                          "_moveToStartOfParagraph:withHistory:", "_moveToEndOfParagraph:withHistory:",
                          "_moveToStartOfDocument:withHistory:", "_moveToEndOfDocument:withHistory:"]
    private typealias Function = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> AnyObject?

    /// Performs `name` on `target`; false when the target has no such action.
    @discardableResult
    static func perform(_ name: String, on target: NSObject, extending: Bool) -> Bool {
        let selector = NSSelectorFromString(name)
        guard let method = class_getInstanceMethod(type(of: target), selector) else { return false }
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        _ = function(target, selector, extending, nil)
        return true
    }
}

enum EdgeAction: String, CaseIterable {
    case newline, backspace, letter
}

enum TypeAt: String, CaseIterable {
    case start, inside, end
}

/// The model compared structurally: adjacent runs with equal attributes merged, empty runs dropped.
enum FuzzModel {
    static func normalized(_ content: ChatInputContent) -> ChatInputContent {
        return ChatInputContent(blocks: content.blocks.map(self.normalized))
    }

    static func normalized(_ block: ChatInputBlock) -> ChatInputBlock {
        switch block {
        case var .paragraph(paragraph):
            paragraph.runs = self.merged(paragraph.runs)
            return .paragraph(paragraph)
        case var .code(code):
            code.runs = self.merged(code.runs)
            return .code(code)
        case var .pullQuote(quote):
            quote.runs = self.merged(quote.runs)
            quote.author = self.merged(quote.author)
            return .pullQuote(quote)
        case var .blockQuote(quote):
            quote.content = self.normalized(quote.content)
            quote.author = self.merged(quote.author)
            return .blockQuote(quote)
        case var .table(table):
            table.rows = table.rows.map { row in
                var row = row
                row.cells = row.cells.map { cell in
                    var cell = cell
                    cell.runs = self.merged(cell.runs)
                    return cell
                }
                return row
            }
            return .table(table)
        case var .details(details):
            details.content = self.normalized(details.content)
            details.title = self.merged(details.title)
            return .details(details)
        case var .media(media):
            media.caption = self.merged(media.caption)
            return .media(media)
        default:
            return block
        }
    }

    static func merged(_ runs: [ChatInputRun]) -> [ChatInputRun] {
        // An ATOM (a custom emoji, an inline button, a formula) is one run per occurrence: two adjacent identical
        // custom emoji have equal attributes, and merged they were ONE run of two emoji — a model the editor
        // never makes, which the edit-reload round trip then SENT (it sends the normalised tip) and the composer
        // drew as one emoji (p23, default seed 48, `HarnessAdjacentCustomEmojiRunTests`).
        func isAtom(_ run: ChatInputRun) -> Bool {
            if run.attributes.formula != nil { return true }
            switch run.attributes.entity {
            case .customEmoji?, .button?: return true
            default: return false
            }
        }
        var result: [ChatInputRun] = []
        for run in runs where !run.text.isEmpty {
            if let last = result.last, last.attributes == run.attributes, !isAtom(last), !isAtom(run) {
                result[result.count - 1] = ChatInputRun(text: last.text + run.text, attributes: last.attributes)
            } else {
                result.append(run)
            }
        }
        return result
    }

    /// `content` with every details block that has no body given one empty body paragraph — what the
    /// set path makes of it (`HarnessDetailsBodyCrossDeleteTests`).
    static func fillingEmptyDetailsBodies(_ content: ChatInputContent) -> ChatInputContent {
        return ChatInputContent(blocks: content.blocks.map { block in
            switch block {
            case var .details(details):
                details.content = details.content.blocks.isEmpty
                    ? ChatInputContent(blocks: [HarnessEngine.paragraph("")])
                    : self.fillingEmptyDetailsBodies(details.content)
                return .details(details)
            case var .blockQuote(quote):
                quote.content = self.fillingEmptyDetailsBodies(quote.content)
                return .blockQuote(quote)
            default:
                return block
            }
        })
    }

    /// A compact, readable dump for failure messages.
    static func describe(_ content: ChatInputContent) -> String {
        return content.blocks.map(self.describe).joined(separator: " ")
    }

    static func describe(_ block: ChatInputBlock) -> String {
        func runs(_ runs: [ChatInputRun]) -> String {
            return self.merged(runs).map { run -> String in
                let a = run.attributes
                var tags: [String] = []
                if a.bold { tags.append("b") }
                if a.italic { tags.append("i") }
                if a.monospace { tags.append("m") }
                if a.strikethrough { tags.append("s") }
                if a.underline { tags.append("u") }
                if a.spoiler { tags.append("sp") }
                if a.entity != nil { tags.append("e") }
                let prefix = tags.isEmpty ? "" : "[" + tags.joined(separator: ",") + "]"
                return prefix + fuzzEscaped(run.text)
            }.joined(separator: "+")
        }
        switch block {
        case let .paragraph(paragraph):
            return "[p \(paragraph.style) \(runs(paragraph.runs))]"
        case let .code(code):
            // Escaped like every other string here: the Bazel log drops non-ASCII, so an unescaped
            // "sw漢字" printed as "sw" and read as the language losing its CJK (p11, a false lead).
            return "[code lang=\(code.language.map(fuzzEscaped) ?? "-") \(runs(code.runs))]"
        case let .pullQuote(quote):
            return "[pull \(runs(quote.runs)) author=\(runs(quote.author))]"
        case let .blockQuote(quote):
            return "[quote \(self.describe(quote.content)) author=\(runs(quote.author))]"
        case let .table(table):
            return "[table " + table.rows.map { row in
                "(" + row.cells.map { runs($0.runs) }.joined(separator: " | ") + ")"
            }.joined(separator: " ") + "]"
        case let .details(details):
            return "[details\(details.expanded ? "" : " folded") title=\(runs(details.title)) \(self.describe(details.content))]"
        case let .media(media):
            // p13: compact (the default printed the whole `Media` object graph).
            return "[media \(media.kind) x\(media.items.count) cap=\(runs(media.caption))]"
        case let .buttonRow(row):
            return "[row " + row.buttons.map { runs($0.label) }.joined(separator: "|") + "]"
        default:
            return "[\(block)]"
        }
    }

    /// One line of the engine axis the model predicts.
    enum EngineLine: Equatable {
        case text(String)
        /// A code block's language line. The bridge TRIMS the language on read-back ("an emptied
        /// line means no language", `EngineBlockRole.swift`), so it matches the engine's line trimmed.
        case language(String)
        /// A block/pull quote's author line, present even when empty.
        case author(String)
    }

    /// The text the TEXT route sends for `content`, before the trim and the 4096 split: `plainText`, except that
    /// a folded quote contributes its content (the chat expands it before sending), not its one-space placeholder.
    /// What the panel's length counter must count (p24, `HarnessLengthCounterCodeBlockTests`).
    static func sentPlainText(_ content: ChatInputContent) -> String {
        var lines: [String] = []
        for block in content.blocks {
            switch block {
            case let .paragraph(paragraph): lines.append(paragraph.text)
            case let .code(code): lines.append(code.text)
            case let .pullQuote(quote): lines.append(quote.text)
            case let .blockQuote(quote): lines.append(self.sentPlainText(quote.content))
            case .media, .table, .details, .buttonRow: break
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The model projected onto the engine view's text axis (measured by a probe, 2026-09-23, and
    /// the bridge's documented rules): one line per engine block, joined by `"\n"`; a code block is
    /// its language line then its body; a block quote is its children then its author line; a pull
    /// quote is its body then its author line (each author line only when the bridge emits one);
    /// inside ANY block's text a newline is `U+2028` (`EngineDocumentBridge.engineText` — "the model
    /// keeps \n").
    static func engineLines(_ content: ChatInputContent, droppingEmptyDetailsTitles: Bool = false) -> [EngineLine] {
        func runsText(_ runs: [ChatInputRun]) -> String {
            return runs.map(self.engineText).joined()
        }
        func body(_ text: String) -> String {
            return text.replacingOccurrences(of: "\n", with: "\u{2028}")
        }
        var lines: [EngineLine] = []
        for block in content.blocks {
            switch block {
            case let .paragraph(paragraph):
                lines.append(.text(body(runsText(paragraph.runs))))
            case let .code(code):
                lines.append(.language(code.language ?? ""))
                lines.append(.text(body(code.text)))
            case let .media(media):
                // p13: the ATOM line (one U+FFFC), then — for the captioned kinds — the caption line,
                // present even when the caption is empty (measured by a probe, 2026-09-24).
                lines.append(.text("\u{FFFC}"))
                switch media.kind {
                case .image, .video, .location:
                    lines.append(.text(body(runsText(media.caption))))
                case .audio, .document:
                    break
                }
            case .buttonRow:
                // p13: a button row is ONE attachment character on its own line.
                lines.append(.text("\u{FFFC}"))
            case let .pullQuote(quote):
                lines.append(.text(body(runsText(quote.runs))))
                // Conditional (`EngineDocumentBridge`, "PullQuoteBox.shouldShowAuthor"): an EMPTY
                // pull quote has no author line.
                if !quote.author.isEmpty || !quote.text.isEmpty {
                    lines.append(.author(body(runsText(quote.author))))
                }
            case let .blockQuote(quote):
                lines.append(contentsOf: self.engineLines(quote.content, droppingEmptyDetailsTitles: droppingEmptyDetailsTitles))
                // Conditional too: present when an author is set or anything is quoted, i.e. a child
                // other than an empty body paragraph (`EngineDocumentBridge.isEmptyBodyParagraph`).
                let quoted = quote.content.blocks.contains { child in
                    if case let .paragraph(paragraph) = child {
                        return !(paragraph.style == .body && paragraph.list == nil && paragraph.text.isEmpty)
                    }
                    return true
                }
                if !quote.author.isEmpty || quoted {
                    lines.append(.author(body(runsText(quote.author))))
                }
            case let .table(table):
                // One engine block per cell, row-major (measured by a probe, 2026-09-23).
                for row in table.rows {
                    for cell in row.cells {
                        lines.append(.text(body(runsText(cell.runs))))
                    }
                }
            case let .details(details) where !details.expanded:
                // p17: a FOLDED details is its title line alone (its body is out of the engine).
                lines.append(.text(body(runsText(details.title))))
            case let .details(details) where details.expanded:
                // The title line, then the body's blocks (measured by a probe, 2026-09-23).
                if !(droppingEmptyDetailsTitles && details.title.allSatisfy { $0.text.isEmpty }) {
                    lines.append(.text(body(runsText(details.title))))
                }
                lines.append(contentsOf: self.engineLines(details.content, droppingEmptyDetailsTitles: droppingEmptyDetailsTitles))
            default:
                // Off the text axis in the model (a folded details, media, a button row).
                lines.append(.text("<\(block)>"))
            }
        }
        return lines
    }

    /// A run's text on the ENGINE axis (p13, measured by a probe): a formula (its model text is the
    /// LaTeX source), a custom emoji (its model text is the alt emoji) and an inline button are each
    /// ONE attachment character there. Assumes the harness's formula renderer is installed
    /// (`HarnessEdited.installFormulaRenderer`); without one a formula renders as its LaTeX.
    static func engineText(_ run: ChatInputRun) -> String {
        // Counted, so that two equal adjacent atoms merged into one run still project to two.
        if let latex = run.attributes.formula {
            let count = latex.isEmpty ? 1 : max(1, (run.text as NSString).length / (latex as NSString).length)
            return String(repeating: "\u{FFFC}", count: count)
        }
        switch run.attributes.entity {
        case .customEmoji?, .button?:
            return String(repeating: "\u{FFFC}", count: max(1, run.text.count))
        default:
            return run.text
        }
    }

    static let bareAttachmentSignature = "a bare U+FFFC (no entity) in the model"

    /// p23: every line-break character a one-line field holds (a code language, an author, a details title).
    static func lineBreaksInOneLineFields(_ content: ChatInputContent) -> [(field: String, text: String)] {
        var result: [(field: String, text: String)] = []
        func check(_ text: String, _ field: String) {
            if text.contains(where: { $0.isNewline }) { result.append((field, text)) }
        }
        for block in content.blocks {
            switch block {
            case let .code(code): check(code.language ?? "", "codeLanguage")
            case let .pullQuote(quote): check(quote.author.map(\.text).joined(), "pullQuoteAuthor")
            case let .blockQuote(quote):
                check(quote.author.map(\.text).joined(), "blockQuoteAuthor")
                result.append(contentsOf: self.lineBreaksInOneLineFields(quote.content))
            case let .details(details):
                check(details.title.map(\.text).joined(), "detailsTitle")
                result.append(contentsOf: self.lineBreaksInOneLineFields(details.content))
            default: break
            }
        }
        return result
    }

    /// p23: the text of every run that is inline code AND a mention, date or link.
    static func inlineCodeOverEntities(_ content: ChatInputContent) -> [String] {
        var result: [String] = []
        func scan(_ runs: [ChatInputRun]) {
            for run in runs where run.attributes.monospace {
                switch run.attributes.entity {
                case .mention?, .date?, .url?: result.append(run.text)
                default: break
                }
            }
        }
        for block in content.blocks {
            switch block {
            case let .paragraph(paragraph): scan(paragraph.runs)
            case let .pullQuote(quote): scan(quote.runs); scan(quote.author)
            case let .blockQuote(quote): result.append(contentsOf: self.inlineCodeOverEntities(quote.content)); scan(quote.author)
            case let .details(details): scan(details.title); result.append(contentsOf: self.inlineCodeOverEntities(details.content))
            case let .table(table): for row in table.rows { for cell in row.cells { scan(cell.runs) } }
            case let .media(media): scan(media.caption)
            default: break
            }
        }
        return result
    }

    /// Every run whose text holds U+FFFC with no entity or formula, and the kind of block holding it.
    static func bareAttachments(_ content: ChatInputContent) -> [(container: String, text: String)] {
        var result: [(container: String, text: String)] = []
        func scan(_ runs: [ChatInputRun], _ container: String) {
            for run in runs where run.text.contains("\u{FFFC}") && run.attributes.entity == nil && run.attributes.formula == nil {
                result.append((container, run.text))
            }
        }
        for block in content.blocks {
            switch block {
            case let .paragraph(paragraph): scan(paragraph.runs, "paragraph")
            case let .code(code):
                scan(code.runs, "code")
                // p21: the language is a plain string; a custom emoji inserted there by the chat left a bare
                // U+FFFC in it (`HarnessCustomEmojiIntoCodeLanguageTests`).
                if let language = code.language, language.contains("\u{FFFC}") {
                    result.append(("codeLanguage", language))
                }
            case let .pullQuote(quote): scan(quote.runs, "pullQuote"); scan(quote.author, "author")
            case let .blockQuote(quote):
                result.append(contentsOf: self.bareAttachments(quote.content).map { ("blockQuote>" + $0.container, $0.text) })
                scan(quote.author, "author")
            case let .details(details):
                scan(details.title, "detailsTitle")
                result.append(contentsOf: self.bareAttachments(details.content).map { ("details>" + $0.container, $0.text) })
            case let .table(table):
                for row in table.rows { for cell in row.cells { scan(cell.runs, "cell") } }
            case let .media(media): scan(media.caption, "caption")
            default: break
            }
        }
        return result
    }

    /// Whether the engine view's text is the model's projection (nil) or how it differs.
    static func engineAxisMismatch(_ content: ChatInputContent, engineText: String, droppingEmptyDetailsTitles: Bool = false) -> String? {
        let expected = self.engineLines(content, droppingEmptyDetailsTitles: droppingEmptyDetailsTitles)
        let actual = engineText.components(separatedBy: "\n")
        func render(_ line: EngineLine) -> String {
            switch line {
            case let .text(text): return text
            case let .language(text): return "<lang>" + text
            case let .author(text): return "<author>" + text
            }
        }
        var matches = expected.count == actual.count
        if matches {
            for (line, text) in zip(expected, actual) {
                switch line {
                case let .text(value), let .author(value):
                    matches = matches && value == text
                case let .language(value):
                    // EXACTLY, since the p24 fix wave: the model holds the language line as typed (edge spaces
                    // included); it used to be compared trimmed, which hid an engine / model disagreement
                    // (`HarnessCodeLanguageEdgeWhitespaceTests`).
                    matches = matches && value == text
                }
            }
        }
        if matches {
            return nil
        }
        return "the model projected onto the engine axis \(expected.map(render).map(fuzzEscaped)) != the engine view's lines \(actual.map(fuzzEscaped))"
    }
}

/// One backend under the fuzz. Everything is main-thread and synchronous; `settle` spins the run loop.
protocol FuzzDriver: AnyObject {
    var name: String { get }
    var formats: [FuzzFormat] { get }
    var root: HarnessRootViewController { get }
    var host: HarnessPanelHost { get }
    var node: ChatRichTextInputNode { get }
    var view: UIView { get }
    func arrange(_ content: ChatInputContent)
    func viewText() -> String
    func viewSelection() -> NSRange
    func setViewSelection(_ range: NSRange)
    func insert(_ text: String)
    func deleteBackward()
    func format(_ format: FuzzFormat)
    /// Violations of this backend's per-step invariants (empty when fine).
    func violations() -> [String]
}

extension FuzzDriver {
    func settle(_ seconds: TimeInterval = FuzzConfig.stepSettle) {
        self.root.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        self.root.view.layoutIfNeeded()
    }

    func model() -> ChatInputContent {
        return self.node.currentInputContent().content
    }

    var undoManager: UndoManager? {
        return self.view.undoManager
    }

    /// Invariants shared by both backends.
    func commonViolations() -> [String] {
        var result: [String] = []
        let model = self.model()
        let chat = self.host.interfaceState.interfaceState.effectiveInputState.content
        if chat.plainText != model.plainText {
            result.append("the chat's input state \(fuzzEscaped(chat.plainText)) != the node's model \(fuzzEscaped(model.plainText))")
        } else if FuzzModel.normalized(chat) != FuzzModel.normalized(model) {
            // p20: the chat's copy is what Send reads (`composeInputState.content`), so it must be the node's
            // model in full — structure, formatting and entities — not only its text.
            result.append("the chat's input state (what Send reads) \(FuzzModel.describe(chat)) != the node's model \(FuzzModel.describe(model))")
        }
        let selection = self.node.selectedRange
        if selection.location < 0 || selection.length < 0 || NSMaxRange(selection) > model.length {
            result.append("the node's selection \(selection) is outside the model (length \(model.length))")
        }
        let viewLength = (self.viewText() as NSString).length
        let viewSelection = self.viewSelection()
        if viewSelection.location < 0 || viewSelection.length < 0 || NSMaxRange(viewSelection) > viewLength {
            result.append("the view's selection \(viewSelection) is outside the view's text (length \(viewLength))")
        }
        return result
    }
}

/// `@available` because the engine editor is (its runner simulator is iOS 26.5).
@available(iOS 18.4, *)
final class EngineFuzzDriver: FuzzDriver {
    let name = "engine"
    let formats: [FuzzFormat] = FuzzFormat.allCases
    let root: HarnessRootViewController
    let host: HarnessPanelHost
    let node: ChatRichTextInputNode
    private(set) var view: UIView
    private var input: UIView & UITextInput

    init() throws {
        self.root = try HarnessEngine.root()
        self.root.setBackend(.engine)
        self.host = try XCTUnwrap(self.root.panelHost)
        self.node = try HarnessEngine.node(self.host)
        self.view = try HarnessEngine.textView(in: self.root)
        self.input = try XCTUnwrap(self.view as? (UIView & UITextInput), "precondition: the engine view is not a UITextInput")
        var editor: UIView? = self.view
        while let candidate = editor, !(candidate is RichTextEngineEditorView) {
            editor = candidate.superview
        }
        self.editor = try XCTUnwrap(editor as? RichTextEngineEditorView, "precondition: no RichTextEngineEditorView above the engine view")
    }

    let editor: RichTextEngineEditorView

    /// The engine's own invariants, asked non-fatally: presentation derived from the role, and the
    /// derived views (grids, boxes, markers…) present and placed. In a test process the engine TRAPS
    /// on either at the end of a settle; the fuzz switches that off (`FuzzEngineVerifier`) so a
    /// violation is reported with its op log instead of killing the run.
    func engineVerifierViolations() -> [String] {
        var result: [String] = []
        for index in self.editor.currentRoles.indices {
            let drift = self.editor.presentationDrift(atBlock: index)
            if !drift.isEmpty {
                let text = index < self.editor.engine.attributedBlocks.count ? self.editor.engine.attributedBlocks[index].string : "?"
                result.append("presentation drift at engine block \(index) \(fuzzEscaped(text)) (keys \(drift.joined(separator: ","))), role \(String(describing: self.editor.currentRoles[index]).prefix(160))")
            }
            // p20: storage the composer's model cannot carry (a pasted foreign colour) is drawn and not
            // sent; the drift check cannot see it (`HarnessPastedForeignColourTests`).
            let unrepresentable = self.editor.modelUnrepresentableFields(atBlock: index)
            if !unrepresentable.isEmpty {
                let text = index < self.editor.engine.attributedBlocks.count ? self.editor.engine.attributedBlocks[index].string : "?"
                result.append("storage the model cannot carry at engine block \(index) \(fuzzEscaped(text)): \(unrepresentable.joined(separator: ","))")
            }
        }
        if self.editor.bounds.width > 0 {
            let shortfall = self.editor.derivedViewShortfall() + self.editor.derivedViewPlacementDrift()
            if !shortfall.isEmpty {
                result.append("derived views: \(shortfall.joined(separator: "; "))")
            }
        }
        return result
    }

    func arrange(_ content: ChatInputContent) {
        self.host.setInputContent(content)
        HarnessEngine.settle(self.root, seconds: 0.1)
        _ = self.node.makeInputFirstResponder()
        HarnessEngine.settle(self.root, seconds: 0.1)
    }

    func viewText() -> String {
        guard let range = self.input.textRange(from: self.input.beginningOfDocument, to: self.input.endOfDocument) else {
            return ""
        }
        return self.input.text(in: range) ?? ""
    }

    func viewSelection() -> NSRange {
        guard let range = self.input.selectedTextRange else {
            return NSRange(location: NSNotFound, length: 0)
        }
        let start = self.input.offset(from: self.input.beginningOfDocument, to: range.start)
        let end = self.input.offset(from: self.input.beginningOfDocument, to: range.end)
        return NSRange(location: start, length: end - start)
    }

    func setViewSelection(_ range: NSRange) {
        guard let start = self.input.position(from: self.input.beginningOfDocument, offset: range.location),
              let end = self.input.position(from: self.input.beginningOfDocument, offset: NSMaxRange(range)) else {
            return
        }
        self.input.selectedTextRange = self.input.textRange(from: start, to: end)
    }

    func insert(_ text: String) {
        self.input.insertText(text)
    }

    func deleteBackward() {
        self.input.deleteBackward()
    }

    func format(_ format: FuzzFormat) {
        let action: ChatRichTextFormatAction
        switch format {
        case .bold: action = .bold
        case .italic: action = .italic
        case .monospace: action = .monospace
        case .strikethrough: action = .strikethrough
        case .underline: action = .underline
        case .spoiler: action = .spoiler
        case .quote: action = .quote
        case .code: action = .code
        case .pullQuote: action = .pullQuote
        }
        self.node.performFormatAction(action)
    }

    /// Tab / Shift-Tab as a hardware keyboard delivers it: the editor's key command for the caret's
    /// context when it claims one (list item, table cell, details), else a tab character, which is
    /// what UIKit inserts for an unclaimed Tab.
    func pressTab(shift: Bool) {
        let wanted: UIKeyModifierFlags = shift ? .shift : []
        if let command = self.editor.keyCommands?.first(where: { $0.input == "\t" && $0.modifierFlags == wanted }), let action = command.action {
            _ = self.editor.perform(action, with: command)
        } else if !shift {
            self.input.insertText("\t")
        }
    }

    func violations() -> [String] {
        return FuzzKnownDefect.filter(self.unfilteredViolations() + self.lengthViolations(), model: self.model(), engineText: self.viewText())
    }

    /// p24: on the TEXT route the panel's counter and an edit's length guard count `node.text`; it must count what is
    /// sent: the chat copy's plain text with a folded quote's content (the send expands it). Fixed in the p24 fix wave
    /// (`HarnessLengthCounterCodeBlockTests`). Kept out of `unfilteredViolations`, which regression tests assert empty
    /// on documents the counter has no say about.
    /// (The p24 language-edge check is gone with its defect: the model keeps a language line as typed now, so the
    /// engine-axis check — which compares a language exactly since the p24 fix wave — sees any disagreement.)
    func lengthViolations() -> [String] {
        var result: [String] = []
        let model = self.model()
        let chat = self.chatCopy()
        if !chat.isEmpty, chatComposerSendRoute(content: chat, isNewMessage: true, sendWithoutFormatting: false) != .rich {
            let sent = FuzzModel.sentPlainText(chat)
            if self.node.text.count != sent.count {
                result.append("\(FuzzSignature.lengthIgnoresText): counted \(self.node.text.count), sent text \(sent.count); model \(FuzzModel.describe(model))")
            }
        }
        return result
    }

    func unfilteredViolations() -> [String] {
        var result = self.commonViolations()
        if self.host.liveBackend != .engine {
            result.append("the backend is no longer the engine")
        }
        result.append(contentsOf: self.engineVerifierViolations())
        let model = self.model()
        if let mismatch = FuzzModel.engineAxisMismatch(model, engineText: self.viewText()) {
            result.append("\(mismatch); model \(FuzzModel.describe(model))")
        }
        if let inconsistency = FuzzTextInputConsistency.violation(of: self.input) {
            result.append("\(inconsistency); model \(FuzzModel.describe(model))")
        }
        // p16: an attachment character in the model with no entity or formula behind it is sent as a
        // literal U+FFFC — the model is corrupt (`HarnessPullQuoteFragmentAtomPasteTests`).
        result.append(contentsOf: FuzzModel.bareAttachments(model).map { "\(FuzzModel.bareAttachmentSignature) in \($0.container): \(fuzzEscaped($0.text)); model \(FuzzModel.describe(model))" })
        // p23: a one-line field (a code language, a quote's / pull quote's author, a details title) holds no
        // line break. A "\n" in a language or an author is rendered RAW at the next render and splits the
        // line into two engine blocks: "N engine blocks against N-1 roles" (`HarnessNewlineInOneLineFieldCrashTests`).
        result.append(contentsOf: FuzzModel.lineBreaksInOneLineFields(model).map { "\(FuzzSignature.newlineInOneLineField) (\($0.field)): \(fuzzEscaped($0.text)); model \(FuzzModel.describe(model))" })
        // p23: inline code never shares a run with a mention, date or link (the platform's nesting rule;
        // `HarnessInlineCodeOverEntityTests`).
        result.append(contentsOf: FuzzModel.inlineCodeOverEntities(model).map { "\(FuzzSignature.inlineCodeOverEntity): \(fuzzEscaped($0)); model \(FuzzModel.describe(model))" })
        // p20: what the chat SENDS for this model, loaded back as message editing loads it, is the model
        // (`HarnessSendPath`, modulo its documented canonical form). Every divergence fails; the three
        // filed losses were fixed in the p20 fix wave.
        if let divergence = HarnessSendPath.divergence(self.chatCopy()) {
            result.append(divergence.description)
        }
        return result
    }

    /// The chat's copy of the composer state — what `ChatControllerNode.sendCurrentMessage` reads.
    func chatCopy() -> ChatInputContent {
        return self.host.interfaceState.interfaceState.effectiveInputState.content
    }
}

/// What the keyboard reads: every `UITextInput` answer must agree with every other. UIKit builds the
/// document state it sends the keyboard daemon (context before, selection, context after, and the
/// word/sentence units around the caret) from `text(in:)`, the selection and the tokenizer, so an
/// answer that disagrees is a keyboard-facing defect even when no daemon crashes. Added 2026-09-24
/// while chasing the kbd abort at fuzz seed 15 undo-all 23 (`NSRangeException` in
/// `TIRevisionHistory`); it holds at every step of that seed, so that abort is NOT an inconsistent
/// answer of ours. Its cause was WHEN the selection was read: at a host set's `textDidChange:` it was
/// still the previous document's (fixed; `HarnessInputDelegateContractTests`, findings.md). `UIKeyboardImpl.documentState` is deliberately not compared:
/// measured, a programmatic edit leaves it stale on a stock `UITextView` as well.
enum FuzzTextInputConsistency {
    static func violation(of input: UIView & UITextInput) -> String? {
        let begin = input.beginningOfDocument
        let end = input.endOfDocument
        let total = input.offset(from: begin, to: end)
        guard let all = input.textRange(from: begin, to: end) else { return "text input: no whole-document range" }
        let whole = (input.text(in: all) ?? "") as NSString
        if whole.length != total {
            return "text input: text(in: whole) is \(whole.length) long, the axis \(total)"
        }
        guard let selected = input.selectedTextRange else { return nil }
        let start = input.offset(from: begin, to: selected.start)
        let stop = input.offset(from: begin, to: selected.end)
        if start < 0 || stop > total || start > stop {
            return "text input: selection \(start)..<\(stop) outside 0..<\(total)"
        }
        func substring(_ from: UITextPosition, _ to: UITextPosition, _ label: String) -> String? {
            let lower = input.offset(from: begin, to: from)
            let upper = input.offset(from: begin, to: to)
            guard lower >= 0, upper <= total, lower <= upper else {
                return "text input: \(label) \(lower)..<\(upper) outside 0..<\(total)"
            }
            guard let range = input.textRange(from: from, to: to) else { return nil }
            let text = input.text(in: range) ?? ""
            let expected = whole.substring(with: NSRange(location: lower, length: upper - lower))
            if text != expected {
                return "text input: text(in: \(label) \(lower)..<\(upper)) = \(text.debugDescription), the document has \(expected.debugDescription)"
            }
            return nil
        }
        if let problem = substring(selected.start, selected.end, "selection") { return problem }
        // p19 (2026-09-25): the selection's geometry. A non-empty selection has finite rects with exactly
        // one logical start and one end, and a finite first rect (what the edit menu is placed from).
        // The p19 exemptions (the break after a caption-less atom, a lone soft line break, a range from
        // the start of a right-to-left-mark-led block) retired with their fix (p19 fix wave:
        // `HarnessAtomLineBreakSelectionGeometryTests`, `HarnessSoftLineBreakSelectionGeometryTests`,
        // `HarnessBidiMarkSelectionGeometryTests`).
        if stop > start {
            let blockStart = whole.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: start)).location
            let startBlockOffset = blockStart == NSNotFound ? 0 : blockStart + 1
            // Asked only once the geometry has failed (below): does any non-empty line the selection
            // touches lay out with no extent (its first and last caret at one point)?
            func touchesALineWithNoExtent() -> Bool {
                var lineStart = startBlockOffset
                while lineStart <= stop {
                    let next = whole.range(of: "\n", options: [], range: NSRange(location: lineStart, length: whole.length - lineStart)).location
                    let lineEnd = next == NSNotFound ? whole.length : next
                    if lineEnd > lineStart, let a = input.position(from: begin, offset: lineStart), let b = input.position(from: begin, offset: lineEnd),
                       input.caretRect(for: a).origin == input.caretRect(for: b).origin {
                        return true
                    }
                    if next == NSNotFound { break }
                    lineStart = next + 1
                }
                return false
            }
            do {
                let rects = input.selectionRects(for: selected)
                let first = input.firstRect(for: selected)
                let failed = rects.isEmpty || rects.contains(where: { !$0.rect.minX.isFinite || !$0.rect.minY.isFinite || !$0.rect.height.isFinite })
                    || rects.filter(\.containsStart).count != 1 || rects.filter(\.containsEnd).count != 1
                    || !first.minX.isFinite || !first.minY.isFinite
                // Not a defect of its own: a line with no extent (a block nested so deep in quotes that its
                // column has collapsed — seed 10, 21 levels, every caret in it at one point) has nothing to
                // draw, and the coordinator's all-or-nothing check then discards the whole selection.
                if failed && !touchesALineWithNoExtent() {
                    return "text input: selection \(start)..<\(stop) has no geometry: rects \(rects.map(\.rect)) (starts \(rects.filter(\.containsStart).count), ends \(rects.filter(\.containsEnd).count)), firstRect \(first)"
                }
            }
        }
        // p19: extending the selection's ends by a character, at the document's edges too (extending past
        // one raised in the engine until the p19 fix wave, `HarnessExtendPastDocumentEdgeTests`; a stock
        // text view answers an empty range there).
        for (anchor, offset) in [(selected.start, start), (selected.end, stop)] {
            for direction in [UITextLayoutDirection.left, .right] {
                guard let range = input.characterRange(byExtending: anchor, in: direction) else { continue }
                let a = input.offset(from: begin, to: range.start), b = input.offset(from: begin, to: range.end)
                if a > b || a < 0 || b > total || (a != offset && b != offset) {
                    return "text input: characterRange(byExtending: \(offset), \(direction.rawValue)) = \(a)..<\(b)"
                }
            }
        }
        let tokenizer = input.tokenizer
        for granularity: UITextGranularity in [.character, .word, .sentence, .paragraph, .line] {
            for (anchor, name) in [(selected.start, "start"), (selected.end, "end")] {
                for (direction, dname) in [(UITextStorageDirection.backward, "back"), (.forward, "fwd")] {
                    let d = UITextDirection(rawValue: direction.rawValue)
                    if let boundary = tokenizer.position(from: anchor, toBoundary: granularity, inDirection: d) {
                        let (a, b) = direction == .backward ? (boundary, anchor) : (anchor, boundary)
                        // A stock `UITextView` does this too (p16, `HarnessLineSeparatorTokenizerOracleTests`):
                        // at a line start right after a U+2028 that a vertical move landed on, the line
                        // boundary forward is the separator itself, one before the anchor.
                        let boundaryOffset = input.offset(from: begin, to: boundary)
                        let anchorOffset = input.offset(from: begin, to: anchor)
                        let stockLineSeparatorAnswer = granularity == .line && direction == .forward && boundaryOffset == anchorOffset - 1
                            && boundaryOffset >= 0 && boundaryOffset < whole.length && whole.character(at: boundaryOffset) == 0x2028
                        if !stockLineSeparatorAnswer {
                            if input.compare(a, to: b) == .orderedDescending {
                                return "text input: \(granularity.rawValue) boundary \(dname) from the selection \(name) is on the wrong side"
                            }
                            if let problem = substring(a, b, "\(granularity.rawValue)-\(dname)-\(name)") { return problem }
                        }
                    }
                    if let unit = tokenizer.rangeEnclosingPosition(anchor, with: granularity, inDirection: d),
                       let problem = substring(unit.start, unit.end, "enclosing-\(granularity.rawValue)-\(dname)-\(name)") {
                        return problem
                    }
                }
            }
        }
        return nil
    }
}

/// Presentation drift the fuzz has already reduced and filed, recognised by its exact signature so
/// that the sequence goes on exercising everything else. Every entry names its red regression test;
/// the summary line prints how often each was suppressed. Remove an entry when its test goes green.
/// Sequence-level state for the known-defect filter (p13). Kept apart from `FuzzKnownDefect`, which is
/// iOS 18.4-only, because the sequence driver reads it outside any availability check.
enum FuzzSequenceEnd {
    /// A CORRUPTING known-defect signature seen during the current step: the sequence ends there,
    /// counted, not failed (the document is no longer one whose later violations mean anything new).
    static var endedBy: String?

    static func take() -> String? {
        defer { self.endedBy = nil }
        return self.endedBy
    }
}

/// The text an op-specific violation starts with when it is a filed defect's signature (outside
/// `FuzzKnownDefect` because that enum is iOS 18.4+ and the ops are not). None is filed today: the p15
/// signatures retired with their fixes (2026-09-25), the p17 ones with theirs, the p18 one with its and
/// the p19 one with its (2026-09-25), and their texts are plain violations now.
enum FuzzSignature {
    /// p18, fixed: `HarnessChatInsertStructureTests`.
    static let chatInsertRebuildsStructure = "the chat's emoji-keyboard insert did not do what typing it does"
    /// p17, fixed: `HarnessVerticalMoveAtDocumentEdgeTests`.
    static let keyWalkWrongWay = "a repeated arrow press moved the caret the wrong way"
    /// p17, fixed: `HarnessCompositionAcrossQuoteEndTests`.
    static let compositionLeavesFirstCandidate = "a composition left its first candidate behind"
    static let undoCrossesExternalSet = "undo/redo still offered after an external content set"
    static let detailsWithoutBody = "a details block with no body gained one on a set"
    /// p19, fixed: `HarnessLocalMoveContentLossTests`, `HarnessFragmentPasteIntoTableCellTests` (a move is
    /// Cut + Paste, refused where the destination cannot hold what it carries).
    static let moveLosesContent = "a local move lost content"
    /// p21, fixed: `HarnessUndoSeparatorTypingAttributesTests` — the composition oracle composes twice (once
    /// on the state the op found, once after an undo restored the same document); the two differed when an
    /// undo re-rendered a separator. A plain violation now. (`compositionFromMediaStop`, p21, fixed with
    /// `HarnessCompositionFromMediaStopTests`, is a plain composition-vs-typing mismatch again.)
    static let typingDependsOnUndoHistory = "the same composition over the same document gave a different result after an undo"
    /// p22, fixed: `HarnessRedoDuringCompositionTests`. A plain violation now.
    static let redoDuringComposition = "redo is offered while a composition is open"
    /// p22, fixed: `HarnessFormatOverEmptyLineSelectionTypingTests`. A plain violation now. (The p22 move
    /// signatures — into an author line, into a one-line field — were retired with their fixes,
    /// `HarnessQuoteBodyIntoAuthorRangeTests` / `HarnessFragmentIntoOneLineFieldTests`: such a loss is
    /// `moveLosesContent` again.)
    static let formatDroppedFromEmptyLine = "typing over a selection that starts on a line break dropped the format just applied to it"
    /// p23, fixed: `HarnessNewlineInOneLineFieldCrashTests`. A plain violation now.
    static let newlineInOneLineField = "a one-line field holds a line break"
    /// p23, fixed: `HarnessInlineCodeOverEntityTests`. A plain violation now.
    static let inlineCodeOverEntity = "inline code over an entity"
    /// p24, fixed in its fix wave: `HarnessMentionIntoInlineCodeTests`.
    static let mentionLosesEntity = "the avatar menu's Mention landed without a mention entity"
    /// p24, fixed in its fix wave: `HarnessLengthCounterCodeBlockTests`.
    static let lengthIgnoresText = "the length the panel counts (node.text) is not the text-route text"
    /// p24, fixed in its fix wave: `HarnessUnreportedSetNormalisationTests`.
    static let unreportedSetNormalisation = "a set the editor normalised was not reported to the chat"
    /// p24, fixed in its fix wave: `HarnessAtomInSetCodeBodyTests` (code-body atom) and
    /// `HarnessSetCarriageReturnTests` (CR kept).
    static let setKeepsWhatIsNotSent = "a set left content the send path does not carry"
    /// p24, fixed in its fix wave: `HarnessSetCarriageReturnTests` (a CR in a block broke the tokenizer).
    static let setTextInputInconsistent = "after a set, the text input answers disagree"
}

@available(iOS 18.4, *)
enum FuzzKnownDefect: Hashable {
    // Retired 2026-09-23 with their fixes: pullQuoteFace, inlineCodePresentation,
    // secondaryLineFormat, fallbackFace, linkUnderline; then (twelfth wave) headingFallbackBold,
    // pullQuoteItalicOverCode, tableHeaderItalic, pasteOverPartialTable,
    // detailsSelectionAxis, detailsTitleLost, emptyContainerCopyDropped, detailsAtEndCopyDropped;
    // then (2026-09-24) compositionOverCrossBlockSelection (`HarnessCompositionOverSelectionTests`),
    // compositionAttributesDifferFromTyping (`HarnessCompositionFormattingTests`),
    // compositionJoinsEarlierUndoStep (`HarnessCompositionUndoStepTests`); then (p12 fixes)
    // themeChangeMovesSelection (`HarnessThemeChangeSelectionTests`); then (p13 fixes, 2026-09-24)
    // buttonRowStopText (`HarnessButtonRowStopTypingTests`), atomFormatDrift
    // (`HarnessAtomInlineFormatDriftTests`), compositionAtAtomStop (`HarnessAtomStopCompositionTests`),
    // languageRewrittenOnRender (`HarnessCodeLanguageRedoTests`); then (p15 fixes, 2026-09-25)
    // undoCrossesExternalSet (`HarnessExternalSetUndoTests`), detailsWithoutBody
    // (`HarnessDetailsBodyCrossDeleteTests`), tableRowsLagWidth (`HarnessTableWidthChangeRowHeightTests`),
    // wholeTableToSecondaryLine (`HarnessWholeTableEditIntoSecondaryLineTests`), typingIntoCaption
    // (`HarnessTypingIntoCaptionFormattingTests`), captionEntityEmojiDrift
    // (`HarnessCaptionEntityEmojiDriftTests`); then (p16 fixes, 2026-09-25) checkedItemReturnAtStart
    // (`HarnessChecklistReturnAtStartTests`), wholeLineDeletionRestyles (`HarnessWholeLineDeletionTests`),
    // blockCommandSelectionEnd (`HarnessBlockCommandSelectionEndTests`), pullQuoteAtomPaste
    // (`HarnessPullQuoteFragmentAtomPasteTests`), codeFlattensAtoms and cellReplaceFlattensAtoms
    // (`HarnessAtomFlatteningTests`); then (p17 fixes, 2026-09-25) keyWalkWrongWay
    // (`HarnessVerticalMoveAtDocumentEdgeTests`), compositionLeavesFirstCandidate
    // (`HarnessCompositionAcrossQuoteEndTests`), detailsTrailingEmptyLineCopy
    // (`HarnessDetailsTrailingEmptyLineCopyTests`); then (p18 fixes, 2026-09-25)
    // chatInsertRebuildsStructure (`HarnessChatInsertStructureTests`) and emptyTrailingContainerDuplicated
    // (`HarnessEmptyPullQuoteAtEndPasteTests`); then (p19 fixes, 2026-09-25) moveLosesContent
    // (`HarnessLocalMoveContentLossTests`, `HarnessFragmentPasteIntoTableCellTests`); then (p20 fixes,
    // 2026-10-01) sendPathLoss ×3 (`HarnessSendPathCodeFormattingTests`,
    // `HarnessSendPathBlankLineReloadTests`, `HarnessSendPathFormulaSpoilerTests`), pasteJoinsTypingRun
    // (`HarnessPasteJoinsTypingUndoTests`), pasteAtMediaStop (`HarnessPasteAtMediaStopTests`),
    // noOpMoveRegistersNoStep (`HarnessPullQuoteNoOpMoveUndoTests`); then (p21 fixes, 2026-10-01)
    // customEmojiInCodeLanguage (`HarnessCustomEmojiIntoCodeLanguageTests`), darkThemeEmptyLineTypingColour
    // (`HarnessDarkThemeEmptyLineTypingColourTests`), separatorBeforeQuoteDissolves
    // (`HarnessSeparatorBeforeQuoteDeletionTests`), compositionFromMediaStop
    // (`HarnessCompositionFromMediaStopTests`), typingDependsOnUndoHistory
    // (`HarnessUndoSeparatorTypingAttributesTests`); then (p22 fixes, 2026-10-01) redoDuringComposition
    // (`HarnessRedoDuringCompositionTests`), formatDroppedFromEmptyLine
    // (`HarnessFormatOverEmptyLineSelectionTypingTests`), moveIntoAuthorLosesText
    // (`HarnessQuoteBodyIntoAuthorRangeTests`), moveIntoOneLineFieldLosesText
    // (`HarnessFragmentIntoOneLineFieldTests`); then (p23 fixes, 2026-10-02) newlineInOneLineField
    // (`HarnessNewlineInOneLineFieldCrashTests`), inlineCodeOverEntity (`HarnessInlineCodeOverEntityTests`),
    // linkExtentDependsOnUndoHistory (`HarnessCompositionAfterLinkFromLineEndTests`); then (p24 fixes, 2026-10-02)
    // mentionIntoInlineCodeLosesEntity (`HarnessMentionIntoInlineCodeTests`), lengthIgnoresCodeBlocks
    // (`HarnessLengthCounterCodeBlockTests`), unreportedSetNormalisation (`HarnessUnreportedSetNormalisationTests`),
    // setKeepsWhatIsNotSent (`HarnessAtomInSetCodeBodyTests`, `HarnessSetCarriageReturnTests`),
    // setTextInputInconsistent (`HarnessSetCarriageReturnTests`), languageEdgeWhitespace
    // (`HarnessCodeLanguageEdgeWhitespaceTests`; its per-step check is gone, the axis check covers it). None is open.
    //
    // A new filing adds a case here with its red test and recognises its signature in `filter` /
    // `filterOpViolation`; a CORRUPTING one ends its sequence counted through `note(_:corrupting:)`
    // (`FuzzSequenceEnd`).

    static func noteKnown(_ known: FuzzKnownDefect) {
        self.note(known, corrupting: false)
    }

    static var suppressed: [FuzzKnownDefect: Int] = [:]

    private static func note(_ known: FuzzKnownDefect, corrupting: Bool) {
        self.suppressed[known, default: 0] += 1
        if corrupting, FuzzSequenceEnd.endedBy == nil {
            FuzzSequenceEnd.endedBy = "\(known)"
        }
    }

    /// Removes violations that are a filed defect's signature (counted in `suppressed`). No defect is filed.
    static func filter(_ violations: [String], model: ChatInputContent, engineText: String) -> [String] {
        return violations
    }

    /// Recognises an op-specific violation as a filed defect; nil when it is one (counted), the
    /// violation itself otherwise. No defect is filed.
    static func filterOpViolation(_ violation: String) -> String? {
        return violation
    }
}

/// Turns the engine's end-of-settle verifiers from a TRAP (their behaviour in any test process) into
/// nothing, for the duration of a fuzz run that asks the same questions itself after every step.
@available(iOS 18.4, *)
struct FuzzEngineVerifier {
    private let previous: Bool
    static func nonFatal() -> FuzzEngineVerifier {
        let value = FuzzEngineVerifier(previous: RichTextEngineEditorView.verifiesDerivedPresentation)
        RichTextEngineEditorView.verifiesDerivedPresentation = false
        return value
    }
    private init(previous: Bool) {
        self.previous = previous
    }
    func restore() {
        RichTextEngineEditorView.verifiesDerivedPresentation = self.previous
    }
}


final class HarnessComposerFuzzTests: XCTestCase {
    /// Keyboard-shaped insertions. A multi-line string arrives only by paste.
    static let insertions: [String] = [
        "a", "b", "hello", "the ", " ", " ", ".", ",", "!", "?", "\n", "\n",
        "😀", "👍🏽", "👨‍👩‍👧", "漢字", "日本語 ", "عربي", "مرحبا ", "שלום", "नमस्ते", "ก่อน",
        "e\u{301}", "\u{200F}", "abc עברית 123", "x😀y", "Ab1",
        // The emoji keyboard's clusters (p11): a flag, a skin tone, a ZWJ profession, a keycap, VS16
        // and VS15 presentation, a ZWJ flag.
        "🇺🇦", "👋🏿", "👩🏽‍💻", "1️⃣", "❤️", "☺︎", "🏳️‍🌈",
        // A very long run (typed as one burst, as dictation or a hardware-keyboard paste does).
        String(repeating: "lorem ipsum dolor ", count: 20),
    ]

    /// Pasted plain text, most of it markdown the harness's parser turns into structure.
    static let pastes: [String] = [
        "- one\n- two", "1. first\n2. second", "- [ ] task\n- [x] done", "# Title", "## Sub heading",
        "> quoted line", "```\nlet x = 1\n```", "**bold** and _italic_ text", "l1\nl2\nl3", "plain",
        "- a\n  - nested", "`code` span",
        // The extended mix: a pipe table, a nested quote, a very long paragraph, an author-style line.
        "| a | b |\n|---|---|\n| 1 | 2 |", "| x | y | z |\n|---|---|---|\n| 漢 | 😀 | **b** |",
        "> > nested\n> outer", String(repeating: "Long pasted sentence number one. ", count: 40),
    ]

    static let urls = ["https://telegram.org", "https://t.example/a", ""]

    /// `replay` prints each step before running it (so a trap names it); a reducer turns this off.
    static var replayPrintsSteps = true

    static func startingContents() -> [ChatInputContent] {
        var bold = ChatInputInlineAttributes()
        bold.bold = true
        return [
            HarnessContent.plainText(""),
            HarnessContent.plainText("First paragraph.\nSecond paragraph."),
            ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [
                ChatInputRun(text: "The "), ChatInputRun(text: "quick", attributes: bold), ChatInputRun(text: " brown fox."),
            ]))]),
            ChatInputContent(blocks: [
                HarnessEngine.paragraph("Intro line."),
                .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false)),
            ]),
            ChatInputContent(blocks: [
                HarnessEngine.paragraph("Code below:"),
                .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
            ]),
            ChatInputContent(blocks: [
                HarnessEngine.paragraph("Pull quote next."),
                .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "A pulled line.")])),
            ]),
        ] + Self.extendedStartingContents()
    }

    /// The extended mix's starting documents (2026-09-23): a pull quote and a block quote WITH
    /// authors, a nested quote, a table (with its column specs, as a paste or a draft carries them)
    /// and an expanded details block.
    static func extendedStartingContents() -> [ChatInputContent] {
        func cell(_ text: String) -> ChatInputTableCell {
            return ChatInputTableCell(runs: [ChatInputRun(text: text)])
        }
        let inner = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Deep line.")]), collapsed: false))
        return [
            ChatInputContent(blocks: [
                HarnessEngine.paragraph("Attributed:"),
                .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Words to live by.")], author: [ChatInputRun(text: "Someone")])),
            ]),
            ChatInputContent(blocks: [
                .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted with author.")]), collapsed: false, author: [ChatInputRun(text: "Ann")])),
                HarnessEngine.paragraph("After."),
            ]),
            ChatInputContent(blocks: [
                .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Outer line."), inner]), collapsed: false)),
            ]),
            ChatInputContent(blocks: [
                HarnessEngine.paragraph("Table below:"),
                .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                    ChatInputTableRow(isHeader: true, cells: [cell("Name"), cell("Value")]),
                    ChatInputTableRow(cells: [cell("alpha"), cell("1")]),
                ])),
                HarnessEngine.paragraph("After the table."),
            ]),
            ChatInputContent(blocks: [
                HarnessEngine.paragraph("Details:"),
                .details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Hidden body.")]), title: [ChatInputRun(text: "Summary")], expanded: true)),
            ]),
        ]
    }

    /// The edited-message starting documents (p13, 2026-09-24): the kinds the composer cannot author
    /// and receives only when a rich message is opened for editing, alone and mixed with every
    /// container. Media and custom emoji carry id-only placeholders (nothing loads offline); a formula
    /// renders through the harness's stand-in renderer as one attachment character.
    static func editedStartingContents() -> [ChatInputContent] {
        typealias E = HarnessEdited
        func cell(_ runs: [ChatInputRun]) -> ChatInputTableCell {
            return ChatInputTableCell(runs: runs)
        }
        func bullet(_ runs: [ChatInputRun]) -> ChatInputBlock {
            return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: runs))
        }
        let album = ChatInputBlock.media(ChatInputMedia(items: [
            ChatInputMediaItem(media: E.image(11), kind: .image, naturalSize: ChatInputSize(width: 400.0, height: 300.0)),
            ChatInputMediaItem(media: E.image(12), kind: .image, naturalSize: ChatInputSize(width: 300.0, height: 400.0)),
        ], caption: [E.run("Two "), E.mention("Bo"), E.run(" "), E.emoji()]))
        return [
            ChatInputContent(blocks: [E.paragraph([E.run("Before the photo.")]), E.media(1, caption: "A caption here"), E.paragraph([E.run("After it.")])]),
            ChatInputContent(blocks: [
                E.paragraph([E.run("Sum "), E.formula("a^2+b^2"), E.run(" is "), E.emoji(), E.run(" fine")]),
                E.paragraph([E.run("Hi "), E.mention("Alice"), E.run(" at "), E.date("noon"), E.run(", see "), E.url("the site"), E.run(".")]),
            ]),
            ChatInputContent(blocks: [E.paragraph([E.run("Top line")]), E.paragraph([E.formula("E=mc^2")]), E.paragraph([E.run("End line")])]),
            ChatInputContent(blocks: [E.paragraph([E.run("Tap "), E.pill("Go"), E.run(" now")]), E.buttonRow(["One", "Two"]), E.paragraph([E.run("After the row.")])]),
            ChatInputContent(blocks: [
                .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.mention("Al"), E.run(" said")]), E.media(2, caption: "In a quote")]), collapsed: false)),
                E.paragraph([E.run("out")]),
            ]),
            ChatInputContent(blocks: [E.paragraph([E.run("Listen")]), E.audio(3), album, E.paragraph([E.run("tail")])]),
            ChatInputContent(blocks: [
                E.paragraph([E.run("Mixed "), E.emoji()]),
                .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                    ChatInputTableRow(cells: [cell([E.run("a"), E.emoji()]), cell([E.formula("y"), E.run("b")])]),
                    ChatInputTableRow(cells: [cell([E.mention("M")]), cell([E.pill("P")])]),
                ])),
                .details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("in "), E.formula("z")])]), title: [E.run("T "), E.mention("Mo")], expanded: true)),
                .code(ChatInputCode(language: "swift", runs: [E.run("let x = 1")])),
                bullet([E.run("item "), E.emoji()]),
                bullet([E.run("two")]),
                .pullQuote(ChatInputPullQuote(runs: [E.run("pq "), E.mention("Pa")], author: [E.run("Au")])),
                E.paragraph([E.run("end")]),
            ]),
        ]
    }

    /// Snaps an offset to a composed-character boundary of `text`, as a caret placed by a touch or
    /// arrow key always is (the fuzz never splits a surrogate pair or an emoji sequence).
    static func snap(_ offset: Int, in text: NSString) -> Int {
        if offset <= 0 || offset >= text.length {
            return max(0, min(offset, text.length))
        }
        return text.rangeOfComposedCharacterSequence(at: offset).location
    }

    /// The start and end offset of every engine line (block) of `text`.
    static func lineEdges(_ text: NSString) -> [Int] {
        var edges: [Int] = [0]
        var location = 0
        while location < text.length {
            let range = text.range(of: "\n", options: [], range: NSRange(location: location, length: text.length - location))
            if range.location == NSNotFound {
                break
            }
            edges.append(range.location)
            edges.append(range.location + 1)
            location = range.location + 1
        }
        edges.append(text.length)
        return edges
    }

    /// The next op, drawn from `random` against the driver's CURRENT state (so the sequence replays
    /// only as a whole).
    static func nextOp(_ random: inout FuzzRandom, driver: FuzzDriver) -> FuzzOp {
        let text = driver.viewText() as NSString
        func offset() -> Int {
            return Self.snap(random.int(text.length + 1), in: text)
        }
        func selectionForMenu() -> (Int, Int)?? {
            // The Format menu is offered on a SELECTION only: the live one, or one made first; nil
            // when nothing can be selected.
            if driver.viewSelection().length > 0 {
                return .some(nil)
            }
            let a = offset()
            let b = offset()
            return a == b ? nil : .some((min(a, b), max(a, b)))
        }
        func range() -> (Int, Int)? {
            let a = offset()
            let b = offset()
            return a == b ? nil : (min(a, b), max(a, b))
        }
        let roll = random.int(135)
        switch roll {
        case 0 ..< 20:
            return .insert(random.pick(Self.insertions))
        case 20 ..< 28:
            return .deleteBackward
        case 28 ..< 38:
            let a = offset()
            if random.chance(50) {
                let b = offset()
                return .select(min(a, b), max(a, b))
            }
            return .select(a, a)
        case 38 ..< 48:
            return .edge(random.pick(Self.lineEdges(text)), random.pick(EdgeAction.allCases))
        case 48 ..< 62:
            let format = random.pick(driver.formats)
            if let selecting = selectionForMenu() {
                return .format(format, selecting: selecting)
            }
            return .select(0, 0)
        case 62 ..< 66:
            let url = random.pick(Self.urls)
            if let selecting = selectionForMenu() {
                return .link(url, selecting: selecting)
            }
            return .select(0, 0)
        case 66 ..< 70:
            return .copy
        case 70 ..< 74:
            return .cut
        case 74 ..< 79:
            return .paste
        case 79 ..< 86:
            return .pasteText(random.pick(Self.pastes))
        case 86 ..< 90:
            return .tab(shift: random.chance(40))
        case 90 ..< 96:
            return .undo
        case 96 ..< 100:
            return .redo
        // The extended mix (2026-09-23, eleventh wave).
        case 100 ..< 105:
            guard let range = range() else { return .select(0, 0) }
            let format = random.pick([FuzzFormat.monospace, .spoiler, .monospace, .spoiler, .bold, .italic, .strikethrough, .underline])
            return .typeInFormat(format, range, random.pick(TypeAt.allCases), random.pick(["a", "xy", " ", "漢", "😀", "!"]))
        case 105 ..< 108:
            return .selectAllFormat(random.pick(driver.formats))
        case 108 ..< 113:
            guard let range = range() else { return .select(0, 0) }
            // Inline formats only: a block format changes the engine axis (a code block's language line
            // comes and goes), so the same offsets no longer select the same text on the third pass —
            // a harness artifact, seen at seed 36 of the first extended sweep.
            return .formatThrice(random.pick([FuzzFormat.bold, .italic, .monospace, .strikethrough, .underline, .spoiler]), range)
        case 113 ..< 117:
            return .selfPaste(offset())
        case 117 ..< 120:
            return .send
        // p11 (2026-09-24): IME compositions and hardware arrow-key actions.
        case 120 ..< 129:
            let selecting = random.chance(30) ? range() : nil
            return .compose(random.pick(FuzzIME.allCases), random.pick([FuzzCommit.unmark, .unmark, .insertFinal, .cancel]), selecting: selecting)
        default:
            return .keyMove(random.pick(FuzzKeyMove.actions), extend: random.chance(40))
        }
    }

    /// `UIPasteboard.general.changeCount` right after this process last wrote the pasteboard (its own
    /// arrange string, a Copy / Cut, a `pasteText`). Reading `changeCount` does not read content, so it
    /// never raises the paste prompt.
    static var ownPasteboardChangeCount: Int?

    /// Records that the pasteboard now holds this process's own content.
    static func notePasteboardWritten() {
        Self.ownPasteboardChangeCount = UIPasteboard.general.changeCount
    }

    /// Before a paste: if the pasteboard changed since this process last wrote it (the simulator syncs
    /// the Mac's clipboard, which is foreign content, and reading it raises the "Allow Paste" prompt
    /// that hung seed 92 of the first extended sweep), write a plain string of our own first.
    static func ensureOwnPasteboardContent() {
        if Self.ownPasteboardChangeCount != UIPasteboard.general.changeCount {
            print("FUZZ pasteboard changed outside the test (count \(UIPasteboard.general.changeCount), ours \(Self.ownPasteboardChangeCount.map(String.init) ?? "none")); writing our own content before the paste")
            UIPasteboard.general.string = "pasted"
            Self.notePasteboardWritten()
        }
    }

    /// The model right after the LAST external content set of the sequence — the arrange, a `.send`
    /// that cleared content, or a content-changing `.push`. An external set empties the undo and redo
    /// stacks (stock `UITextView`, legacy; `HarnessExternalSetUndoTests`), so undo-all must stop
    /// EXACTLY here: short of it is a lost step, past it is an undo across the set.
    static var lastExternalSetModel: ChatInputContent?

    /// Executes `op`; returns a violation of an op-specific invariant (`formatThrice`, `send`), else nil.
    @discardableResult
    static func execute(_ op: FuzzOp, on driver: FuzzDriver) -> String? {
        func selectFirst(_ selecting: (Int, Int)?) {
            if let selecting {
                driver.setViewSelection(NSRange(location: selecting.0, length: selecting.1 - selecting.0))
                driver.settle()
            }
        }
        switch op {
        case let .insert(text):
            driver.insert(text)
        case .deleteBackward:
            driver.deleteBackward()
        case let .select(a, b):
            driver.setViewSelection(NSRange(location: a, length: b - a))
        case let .format(format, selecting):
            selectFirst(selecting)
            driver.format(format)
        case let .link(url, selecting):
            selectFirst(selecting)
            driver.root.linkPromptOverride = { _, _ in url }
            driver.host.panel.formatAttributesLink(driver.host.panel)
            driver.settle()
            driver.root.linkPromptOverride = nil
        case .copy:
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
            Self.notePasteboardWritten()
        case .cut:
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            Self.notePasteboardWritten()
        case .paste:
            Self.ensureOwnPasteboardContent()
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
            driver.settle(FuzzConfig.pasteSettle)
        case let .pasteText(text):
            UIPasteboard.general.string = text
            Self.notePasteboardWritten()
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
            driver.settle(FuzzConfig.pasteSettle)
        case let .edge(offset, action):
            driver.setViewSelection(NSRange(location: offset, length: 0))
            driver.settle()
            switch action {
            case .newline:
                driver.insert("\n")
            case .backspace:
                driver.deleteBackward()
            case .letter:
                driver.insert("q")
            }
        case let .tab(shift):
            if #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver {
                engine.pressTab(shift: shift)
            }
        case .undo:
            if driver.undoManager?.canUndo == true {
                driver.undoManager?.undo()
            }
        case .redo:
            if driver.undoManager?.canRedo == true {
                driver.undoManager?.redo()
            }
        case let .typeInFormat(format, range, at, text):
            selectFirst(range)
            driver.format(format)
            driver.settle()
            let viewText = driver.viewText() as NSString
            let caret: Int
            switch at {
            case .start: caret = range.0
            case .inside: caret = Self.snap((range.0 + range.1) / 2, in: viewText)
            case .end: caret = range.1
            }
            driver.setViewSelection(NSRange(location: min(caret, viewText.length), length: 0))
            driver.settle()
            driver.insert(text)
        case let .selectAllFormat(format):
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
            driver.settle()
            if driver.viewSelection().length > 0 {
                driver.format(format)
            }
        case let .formatThrice(format, range):
            var models: [ChatInputContent] = []
            for _ in 0 ..< 3 {
                selectFirst(range)
                driver.format(format)
                driver.settle(0.05)
                models.append(FuzzModel.normalized(driver.model()))
            }
            if models[2] != models[0] {
                return "Format ▸ \(format.rawValue) applied three times on \(range) is not a round trip:\n  after 1st \(FuzzModel.describe(models[0]))\n  after 2nd \(FuzzModel.describe(models[1]))\n  after 3rd \(FuzzModel.describe(models[2]))"
            }
        case let .selfPaste(offset):
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
            driver.settle()
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
            Self.notePasteboardWritten()
            driver.settle()
            let length = (driver.viewText() as NSString).length
            driver.setViewSelection(NSRange(location: min(offset, length), length: 0))
            driver.settle()
            Self.ensureOwnPasteboardContent()
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
            driver.settle(FuzzConfig.pasteSettle)
        case .send:
            // `simulateSend` records only content with plain text (a table-only composer reads as
            // empty, a harness gap); the clear itself is what is under test, so it is always issued.
            // Gated on "plain text or more than one block", as it was, a single container holding no
            // flat text — `[quote [pull ""] author=" "]` — was never cleared, and the check below then
            // reported the "z" typed into the uncleared pull quote as a product defect (twelfth wave,
            // seed 30).
            let beforeSend = driver.model()
            driver.root.simulateSend()
            driver.host.setInputContent(ChatInputContent())
            driver.settle(0.1)
            // An external set only when it changed the content: the node answers a content-equal set
            // as the chat's echo and keeps the stack (an empty composer's Send clears nothing). The node's guard
            // compares RAW content, so an empty paragraph cleared to no blocks is a set (it empties the stack) though
            // both read back alike (p24, default / edited seed 13: undo-all stopped at the clear, the bookkeeping
            // still named the set before it).
            if beforeSend != ChatInputContent() {
                Self.lastExternalSetModel = FuzzModel.normalized(driver.model())
            }
            driver.insert("z")
            driver.settle(0.1)
            let model = driver.model()
            let plain = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "z")]))])
            if FuzzModel.normalized(model) != plain {
                return "typing after Send (a programmatic clear) is not plain: \(FuzzModel.describe(model))"
            }
        case let .compose(ime, commit, selecting):
            return Self.composeViolation(ime, commit, selecting: selecting, on: driver)
        case let .push(kind, variant, selection):
            return Self.pushViolation(kind, variant, selection, on: driver)
        case let .line(kind, a, b):
            return Self.lineOpViolation(kind, a, b, on: driver)
        case let .keyWalk(down, from, presses, extend):
            return Self.keyWalkViolation(down: down, from: from, presses: presses, extend: extend, on: driver)
        case let .structural(kind, a):
            return Self.structuralViolation(kind, a, on: driver)
        case let .chatInsert(text, custom):
            return Self.chatInsertViolation(text, custom: custom, on: driver)
        case let .move(a, b, target):
            return Self.moveViolation(a, b, target, on: driver)
        case let .externalPaste(variant, at):
            return Self.externalPasteViolation(variant, at: at, on: driver)
        case .undoRedo:
            return Self.undoRedoViolation(on: driver)
        case let .environment(kind):
            return Self.environmentViolation(kind, on: driver)
        case let .formatTypeOver(format, range):
            return Self.formatTypeOverViolation(format, range, on: driver)
        case let .oneLineInsert(a, b):
            return Self.oneLineInsertViolation(a, b, on: driver)
        case .chatMention:
            return Self.chatMentionViolation(on: driver)
        case let .normalisingSet(variant):
            return Self.normalisingSetViolation(variant, on: driver)
        case let .keyMove(name, extend):
            let before = FuzzModel.normalized(driver.model())
            FuzzKeyMove.perform(name, on: driver.view, extending: extend)
            driver.settle()
            let after = FuzzModel.normalized(driver.model())
            if after != before {
                return "the arrow-key action \(name) changed the model:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
            }
        }
        return nil
    }

    /// `opViolation` with a filed defect's signature removed (counted in `FuzzKnownDefect.suppressed`).
    static func filteredOpViolation(_ violation: String?) -> String? {
        guard let violation else { return nil }
        if #available(iOS 18.4, *) {
            return FuzzKnownDefect.filterOpViolation(violation)
        }
        return violation
    }

    static func nextChatInsert(_ random: inout FuzzRandom) -> FuzzOp {
        // Static emoji only: typing cannot make a custom emoji, so the typing oracle has no custom twin
        // (the custom path is pinned by `HarnessChatInsertStructureTests.testCustomEmojiKeyboardKeepsAHeading`).
        return .chatInsert(random.pick(["😀", "👍🏽", "❤️"]), custom: false)
    }

    /// A chat-side insert's invariants (p18): it is ONE undo step, and it does what TYPING the same text
    /// at the same selection does (the oracle: undo, re-select, type). The document is left in the typed
    /// state, so the sequence goes on from what the keyboard would have produced.
    static func chatInsertViolation(_ text: String, custom: Bool, on driver: FuzzDriver) -> String? {
        // The emoji keyboard's tap is a later event than the step before it; let the chat's copy of the
        // selection catch up first, as it would (a legacy node's fallback reads that copy).
        driver.settle(0.05)
        let before = FuzzModel.normalized(driver.model())
        let selection = driver.viewSelection()
        guard selection.location != NSNotFound else { return nil }
        let attributed: NSAttributedString
        if custom {
            let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)
            attributed = NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: attribute])
        } else {
            attributed = NSAttributedString(string: text)
        }
        HarnessChatInserts.emojiKeyboard(attributed)(driver.host)
        driver.settle(0.05)
        let viaChat = FuzzModel.normalized(driver.model())
        if viaChat == before {
            return nil
        }
        guard let undoManager = driver.undoManager, undoManager.canUndo else {
            return "the chat's emoji-keyboard insert registered no undo step: \(FuzzModel.describe(viaChat))"
        }
        undoManager.undo()
        driver.settle(0.05)
        let undone = FuzzModel.normalized(driver.model())
        if undone != before {
            return "one undo did not revert the chat's emoji-keyboard insert:\n  before \(FuzzModel.describe(before))\n  undone \(FuzzModel.describe(undone))"
        }
        if custom {
            // No typing twin for a custom emoji: redo must bring the insert back, and the per-step checks
            // judge it.
            guard undoManager.canRedo else { return "the chat's custom-emoji insert left nothing to redo" }
            undoManager.redo()
            driver.settle(0.05)
            let redone = FuzzModel.normalized(driver.model())
            if redone != viaChat {
                return "redo did not bring back the chat's custom-emoji insert:\n  inserted \(FuzzModel.describe(viaChat))\n  redone   \(FuzzModel.describe(redone))"
            }
            return nil
        }
        driver.setViewSelection(selection)
        driver.settle()
        driver.insert(text)
        driver.settle(0.05)
        let typed = FuzzModel.normalized(driver.model())
        if viaChat != typed {
            return FuzzSignature.chatInsertRebuildsStructure + ":\n  chat  \(FuzzModel.describe(viaChat))\n  typed \(FuzzModel.describe(typed))"
        }
        return nil
    }

    static func nextMove(_ random: inout FuzzRandom, driver: FuzzDriver) -> FuzzOp {
        let text = driver.viewText() as NSString
        let a = Self.snap(random.int(text.length + 1), in: text)
        let b = Self.snap(random.int(text.length + 1), in: text)
        let target = Self.snap(random.int(text.length + 1), in: text)
        return .move(min(a, b), max(a, b), target)
    }

    /// Every attachment atom in the model (media units, custom emoji, formulas, inline buttons, rows),
    /// counted: a move relocates content, so it can neither create nor lose one.
    static func atomCount(_ content: ChatInputContent) -> Int {
        // Per ATOM, not per run: equal adjacent runs merge (two custom emoji side by side are one run).
        func runs(_ runs: [ChatInputRun]) -> Int {
            return runs.reduce(0) { total, run in
                if let latex = run.attributes.formula {
                    return total + (latex.isEmpty ? 1 : max(1, (run.text as NSString).length / (latex as NSString).length))
                }
                switch run.attributes.entity {
                case .customEmoji?, .button?: return total + max(1, run.text.count)
                default: return total
                }
            }
        }
        return content.blocks.reduce(0) { total, block in
            switch block {
            case let .paragraph(p): return total + runs(p.runs)
            case let .code(c): return total + runs(c.runs)
            case let .pullQuote(q): return total + runs(q.runs) + runs(q.author)
            case let .blockQuote(q): return total + Self.atomCount(q.content) + runs(q.author)
            case let .details(d): return total + runs(d.title) + Self.atomCount(d.content)
            case let .table(t): return total + t.rows.reduce(0) { $0 + $1.cells.reduce(0) { $0 + runs($1.runs) } }
            case let .media(m): return total + m.items.count + runs(m.caption)
            case .buttonRow: return total + 1
            }
        }
    }

    /// Letters and digits of the engine text, sorted: a move relocates them (spaces and breaks excluded, a
    /// one-line field turning a break into a space). Every line is counted, a code block's LANGUAGE line
    /// included: until the p22 fix wave the language was left out (p19, edited seed 33: a moved piece of a
    /// code block carries its language as METADATA, so a move can add a second language line), which made
    /// text moved INTO a language line read as lost (default / edited seed 27 once such a move was allowed).
    /// Only LOSSES are reported (`lostLetters`), so a language a move adds is a gain and needs no exclusion.
    static func letters(engineTextAfter driver: FuzzDriver) -> String {
        var counts: [Character: Int] = [:]
        for scalar in driver.viewText().unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            counts[Character(scalar), default: 0] += 1
        }
        return String(counts.keys.sorted().flatMap { key in Array(repeating: key, count: Swift.max(0, counts[key] ?? 0)) })
    }

    /// Whether a letter of `before` is missing from `after` (both sorted, from `letters`). p22: a GAIN is not a
    /// loss — a language line a moved code piece brings along is a gain (default seed 27 read the old
    /// language-less count's equality as "a local move lost content").
    static func lostLetters(_ before: String, _ after: String) -> Bool {
        var counts: [Character: Int] = [:]
        for character in after { counts[character, default: 0] += 1 }
        for character in before {
            counts[character, default: 0] -= 1
            if counts[character, default: 0] < 0 { return true }
        }
        return false
    }

    /// A local move's invariants (p19): a refused move changes nothing; an accepted one is ONE undo step
    /// (undo returns to the model before, redo to the model after), and it neither creates nor loses an
    /// attachment atom, nor any letter. (Whether its result equals Cut + Paste of the same range is not
    /// asserted here: since the p19 fix wave a move IS Cut + Paste by construction, the same deletion and
    /// the same paste handlers, pinned by `HarnessLocalMoveSourceJoinTests`.)
    static func moveViolation(_ a: Int, _ b: Int, _ target: Int, on driver: FuzzDriver) -> String? {
        guard #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver, b > a else { return nil }
        let length = (driver.viewText() as NSString).length
        guard b <= length, target <= length, target <= a || target >= b else { return nil }
        let before = FuzzModel.normalized(driver.model())
        let lettersBefore = Self.letters(engineTextAfter: driver)
        driver.setViewSelection(NSRange(location: a, length: b - a))
        driver.settle()
        guard let context = engine.editor.makeTextDragContext() else { return nil }
        let moved = engine.editor.performLocalMove(context, toFlatOffset: target)
        driver.settle()
        let after = FuzzModel.normalized(driver.model())
        guard moved else {
            return after == before ? nil : "a refused move \(a)..<\(b) -> \(target) changed the model:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
        }
        if Self.atomCount(after) != Self.atomCount(before) || Self.lostLetters(lettersBefore, Self.letters(engineTextAfter: driver)) {
            return FuzzSignature.moveLosesContent + " (\(a)..<\(b) -> \(target); atoms \(Self.atomCount(before)) -> \(Self.atomCount(after))):\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
        }
        guard let undoManager = driver.undoManager, undoManager.canUndo else {
            return "the move \(a)..<\(b) -> \(target) registered no undo step"
        }
        undoManager.undo()
        driver.settle()
        let undone = FuzzModel.normalized(driver.model())
        if undone != before {
            return "one undo did not revert the move \(a)..<\(b) -> \(target):\n  before \(FuzzModel.describe(before))\n  undone \(FuzzModel.describe(undone))"
        }
        guard undoManager.canRedo else { return "the move's undo left nothing to redo" }
        undoManager.redo()
        driver.settle()
        let redone = FuzzModel.normalized(driver.model())
        if redone != after {
            return "redo did not bring back the move \(a)..<\(b) -> \(target):\n  after  \(FuzzModel.describe(after))\n  redone \(FuzzModel.describe(redone))"
        }
        return nil
    }

    static func nextExternalPaste(_ random: inout FuzzRandom, driver: FuzzDriver) -> FuzzOp {
        let text = driver.viewText() as NSString
        return .externalPaste(random.int(FuzzExternalPaste.sources.count), at: Self.snap(random.int(text.length + 1), in: text))
    }

    /// An external paste's invariants (p20): at a caret (a paste over a cross-block selection is two undo
    /// steps, filed as `HarnessCrossBlockPasteUndoTests`), it lands, ONE undo returns to the model before it,
    /// and redo to the model after it. The per-step invariants (bare U+FFFC, the send path, the chat's copy)
    /// then judge what it left.
    /// p21: undo once, then redo once. The redo must bring the document back exactly, and the selection is
    /// put back to what it was so the op stream goes on as it would have.
    static func undoRedoViolation(on driver: FuzzDriver) -> String? {
        guard let undoManager = driver.undoManager, undoManager.canUndo else { return nil }
        let before = FuzzModel.normalized(driver.model())
        let selection = driver.viewSelection()
        undoManager.undo()
        driver.settle(0.05)
        let undone = FuzzModel.normalized(driver.model())
        defer {
            driver.setViewSelection(selection)
            driver.settle()
        }
        guard undoManager.canRedo else {
            return "an undo left nothing to redo: \(FuzzModel.describe(undone))"
        }
        undoManager.redo()
        driver.settle(0.05)
        let redone = FuzzModel.normalized(driver.model())
        if redone != before {
            return "undo + redo did not return to the document:\n  before \(FuzzModel.describe(before))\n  undone \(FuzzModel.describe(undone))\n  redone \(FuzzModel.describe(redone))"
        }
        // An undo that changes nothing is NOT checked: a stock text view has them too (type, then
        // Backspace it: one coalesced step with no net change). The one engine-only case found that way —
        // a cancelled composition's no-op step — is `HarnessCancelledCompositionUndoTests`.
        _ = undone
        return nil
    }

    static func nextEnvironment(_ random: inout FuzzRandom) -> FuzzOp {
        return .environment(random.int(4))
    }

    /// p22: a range for `formatTypeOver`; half the time it starts at an EMPTY line (the class
    /// `HarnessFormatOverEmptyLineSelectionTypingTests` found), when the view has one.
    static func nextFormatTypeOver(_ random: inout FuzzRandom, driver: FuzzDriver) -> FuzzOp {
        let text = driver.viewText() as NSString
        let format = random.pick([FuzzFormat.bold, .italic, .strikethrough, .underline])
        let emptyLineStarts = (0 ... text.length).filter { offset in
            (offset == 0 || text.character(at: offset - 1) == 0x0A) && (offset == text.length || text.character(at: offset) == 0x0A)
        }
        let a: Int
        if random.chance(50), !emptyLineStarts.isEmpty {
            a = random.pick(emptyLineStarts)
        } else {
            a = Self.snap(random.int(text.length + 1), in: text)
        }
        let b = Self.snap(min(text.length, a + 1 + random.int(8)), in: text)
        return .formatTypeOver(format, (a, max(a, b)))
    }

    /// p22: Format (an inline trait) over a selection, then type over it. Judged only where the answer is
    /// unambiguous — a document of top-level paragraphs (the view axis is the model's), a selection holding a
    /// plain character: the typed text carries the trait exactly when the selection's text does after the
    /// command (row 134's rule; a stock text view types with the first selected character's attributes,
    /// which the command just formatted).
    static func formatTypeOverViolation(_ format: FuzzFormat, _ range: (Int, Int), on driver: FuzzDriver) -> String? {
        let text = driver.viewText() as NSString
        guard range.1 > range.0, range.1 <= text.length else { return nil }
        driver.setViewSelection(NSRange(location: range.0, length: range.1 - range.0))
        driver.settle()
        driver.format(format)
        driver.settle()
        let formatted = driver.model()
        func trait(_ attributes: ChatInputInlineAttributes) -> Bool {
            switch format {
            case .bold: return attributes.bold
            case .italic: return attributes.italic
            case .strikethrough: return attributes.strikethrough
            default: return attributes.underline
            }
        }
        // The model's paragraphs, flattened onto the view axis, with each character's trait.
        var flat: [(unit: unichar, trait: Bool, plain: Bool)] = []
        var judged = true
        for (index, block) in formatted.blocks.enumerated() {
            guard case let .paragraph(paragraph) = block, paragraph.style == .body else {
                judged = false
                break
            }
            if index > 0 { flat.append((0x0A, false, false)) }
            for run in paragraph.runs {
                let plain = run.attributes.entity == nil && run.attributes.formula == nil && !run.attributes.monospace
                for unit in Array(run.text.utf16) { flat.append((unit, trait(run.attributes), plain && unit != 0xFFFC)) }
            }
        }
        // A character the document does not hold yet, so the run it lands in is unambiguous (an earlier
        // op of this kind may have typed one already).
        guard let typed = ["\u{0416}", "\u{0462}", "\u{0472}", "\u{0474}", "\u{046A}", "\u{0460}", "\u{047A}", "\u{0468}"].first(where: { !formatted.plainText.contains($0) }) else {
            return nil
        }
        driver.insert(typed)
        driver.settle()
        guard judged, flat.count == text.length,
              let first = flat[range.0 ..< range.1].first(where: { $0.plain && $0.unit != 0x0A }) else { return nil }
        guard let run = driver.model().blocks.lazy.compactMap({ block -> ChatInputRun? in
            if case let .paragraph(paragraph) = block { return paragraph.runs.first { $0.text.contains(typed) } }
            return nil
        }).first else {
            return "the text typed over a formatted selection is not in the model: \(FuzzModel.describe(driver.model()))"
        }
        if trait(run.attributes) != first.trait {
            // The p22 class (fixed): the selection's first character is a LINE BREAK (an empty line, or a line's end).
            let startsOnALineBreak = range.0 < flat.count && flat[range.0].unit == 0x0A
            let what = "\(format.rawValue) over \(range.0)..<\(range.1) left the selection \(first.trait ? "with" : "without") it, the typed text \(trait(run.attributes) ? "with" : "without") it: \(FuzzModel.describe(driver.model()))"
            return (startsOnALineBreak ? FuzzSignature.formatDroppedFromEmptyLine + ": " : "typing over a selection straight after a format did not take the selection's format: ") + what
        }
        return nil
    }

    /// p23: text holding a line-break character other than "\n" typed at the end of a one-line field. The field
    /// must take it on one line (the gate's `oneLineFieldText` rule for "\n"); the per-step invariant
    /// (`lineBreaksInOneLineFields`) judges the result, and this op adds the check that nothing else changed
    /// line count: the document still has the blocks it had.
    static func oneLineInsertViolation(_ a: Int, _ b: Int, on driver: FuzzDriver) -> String? {
        guard #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver else { return nil }
        let editor = engine.editor
        let candidates = editor.currentRoles.indices.filter { index in
            switch editor.currentRoles[index].secondaryKind {
            case .codeLanguage?, .pullQuoteAuthor?, .blockQuoteAuthor?, .detailsTitle?: return true
            default: return false
            }
        }
        guard !candidates.isEmpty else { return nil }
        let index = candidates[a % candidates.count]
        let end = editor.flatOffset(ofRoleAt: index) + editor.flatLength(ofRoleAt: index)
        // A caret move away first ends any open typing run, so the insert is an undo step of its own (sweep:
        // default seeds 41 / 60, edited 40 / 41 coalesced it with letters typed into the field before).
        driver.setViewSelection(NSRange(location: end == 0 ? 1 : 0, length: 0))
        driver.settle()
        driver.setViewSelection(NSRange(location: end, length: 0))
        driver.settle()
        let separators = ["\u{2028}", "\u{2029}", "\r", "\u{85}"]
        driver.insert("M" + separators[b % separators.count] + "X")
        driver.settle()
        let found = FuzzModel.lineBreaksInOneLineFields(driver.model())
        guard !found.isEmpty else { return nil }
        // Fixed in the p23 fix wave (`HarnessNewlineInOneLineFieldCrashTests`): the gate flattens every line-break
        // character in a one-line field, the render and the read-back do too, and settle repairs a composition's
        // commit. A line break left is a plain violation.
        return FuzzSignature.newlineInOneLineField + " after an insert of \(fuzzEscaped("M" + separators[b % separators.count] + "X")) (\(found.map { "\($0.field) \(fuzzEscaped($0.text))" })): \(FuzzModel.describe(driver.model()))"
    }

    /// The characters of every mention run (a mention's text), to tell whether an insert added one.
    /// Whether a mention run anywhere in `content` holds `name`.
    static func mentionRunsHold(_ name: String, in content: ChatInputContent) -> Bool {
        func runs(_ runs: [ChatInputRun]) -> Bool {
            return runs.contains { run in
                if case .mention? = run.attributes.entity { return run.text.contains(name) }
                return false
            }
        }
        return content.blocks.contains { block in
            switch block {
            case let .paragraph(p): return runs(p.runs)
            case let .pullQuote(q): return runs(q.runs) || runs(q.author)
            case let .blockQuote(q): return Self.mentionRunsHold(name, in: q.content) || runs(q.author)
            case let .details(d): return runs(d.title) || Self.mentionRunsHold(name, in: d.content)
            case let .table(t): return t.rows.contains { $0.cells.contains { runs($0.runs) } }
            case let .media(m): return runs(m.caption)
            default: return false
            }
        }
    }

    static func mentionText(_ content: ChatInputContent) -> Int {
        func runs(_ runs: [ChatInputRun]) -> Int {
            return runs.reduce(0) { total, run in
                if case .mention? = run.attributes.entity { return total + run.text.count }
                return total
            }
        }
        return content.blocks.reduce(0) { total, block in
            switch block {
            case let .paragraph(p): return total + runs(p.runs)
            case let .pullQuote(q): return total + runs(q.runs) + runs(q.author)
            case let .blockQuote(q): return total + Self.mentionText(q.content) + runs(q.author)
            case let .details(d): return total + runs(d.title) + Self.mentionText(d.content)
            case let .table(t): return total + t.rows.reduce(0) { $0 + $1.cells.reduce(0) { $0 + runs($1.runs) } }
            case let .media(m): return total + runs(m.caption)
            default: return total
            }
        }
    }

    /// p24: the avatar menu's Mention (`chatComposerInsertMention`, as the chat calls it) at the selection. Where the
    /// destination holds runs (not a code body or language), what it inserts is a MENTION, and it is one undo step
    /// that undo and redo round-trip. The document is left with the insert.
    static func chatMentionViolation(on driver: FuzzDriver) -> String? {
        guard #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver else { return nil }
        driver.settle(0.05)
        let selection = driver.viewSelection()
        guard selection.location != NSNotFound else { return nil }
        let before = FuzzModel.normalized(driver.model())
        let editor = engine.editor
        var plainTextOnly = false
        if let index = editor.roleIndex(atFlatOffset: selection.location), index < editor.currentRoles.count {
            let role = editor.currentRoles[index]
            if role.secondaryKind == .codeLanguage { plainTextOnly = true }
            if case .standalone(.code) = role.position { plainTextOnly = true }
        }
        HarnessChatInserts.contextMenuMention(EnginePeer(HarnessPanelHost.chatPeer))(driver.host)
        driver.settle(0.05)
        let after = FuzzModel.normalized(driver.model())
        if after == before {
            return nil
        }
        guard let undoManager = driver.undoManager, undoManager.canUndo else {
            return "the avatar menu's Mention registered no undo step: \(FuzzModel.describe(after))"
        }
        undoManager.undo()
        driver.settle(0.05)
        let undone = FuzzModel.normalized(driver.model())
        if undone != before {
            return "one undo did not revert the avatar menu's Mention:\n  before \(FuzzModel.describe(before))\n  undone \(FuzzModel.describe(undone))"
        }
        guard undoManager.canRedo else { return "the avatar menu's Mention left nothing to redo" }
        undoManager.redo()
        driver.settle(0.05)
        let redone = FuzzModel.normalized(driver.model())
        if redone != after {
            return "redo did not bring back the avatar menu's Mention:\n  after  \(FuzzModel.describe(after))\n  redone \(FuzzModel.describe(redone))"
        }
        // At a caret the mention adds mention text. Over a RANGE the range's own mention text may go with it
        // (and an inserted mention next to text linked to the same peer is one run with it), so the count can
        // fall while the entity landed: there it is enough that a mention run holds the peer's name (p24 fix
        // wave; default seeds 1, 2, 3, 19 — false positives the open known-defect filter had been swallowing).
        let landed = selection.length == 0
            ? Self.mentionText(after) > Self.mentionText(before)
            : Self.mentionRunsHold("Harness", in: after)
        if !plainTextOnly, !landed {
            return FuzzSignature.mentionLosesEntity + " (selection \(selection)):\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
        }
        return nil
    }

    /// p24: the model with a block holding content the editor normalises appended, set from outside as a draft sync
    /// or an edit load is. Invariants: the chat's copy is the node's model once the deferred report has landed
    /// (`unreportedSetNormalisation`), what is held is what the send path carries (`setKeepsWhatIsNotSent`), and every
    /// `UITextInput` answer over the appended block agrees (`FuzzTextInputConsistency` at each caret and over each
    /// line; a CR in a block broke it, `setTextInputInconsistent`). The previous content is then set back (an
    /// external set too), so the op's block never lingers in the document and the sequence goes on. All three were
    /// open known defects in the p24 roam and are plain violations since its fix wave.
    static func normalisingSetViolation(_ variant: Int, on driver: FuzzDriver) -> String? {
        let before = driver.model()
        let beforeLength = (driver.viewText() as NSString).length
        let block = FuzzNormalisingSet.blocks[variant % FuzzNormalisingSet.blocks.count]
        driver.host.setInputContent(ChatInputContent(blocks: before.blocks + [block]))
        driver.settle(0.4)
        defer {
            driver.host.setInputContent(before)
            driver.settle(0.2)
            Self.lastExternalSetModel = FuzzModel.normalized(driver.model())
        }
        let chat = driver.host.interfaceState.interfaceState.effectiveInputState.content
        let model = driver.model()
        if FuzzModel.normalized(chat) != FuzzModel.normalized(model) {
            return FuzzSignature.unreportedSetNormalisation + " (variant \(variant)):\n  chat  \(FuzzModel.describe(chat))\n  model \(FuzzModel.describe(model))"
        }
        if let divergence = HarnessSendPath.divergence(model) {
            return FuzzSignature.setKeepsWhatIsNotSent + " (variant \(variant)): \(divergence.description)"
        }
        if let input = driver.view as? (UIView & UITextInput) {
            let total = (driver.viewText() as NSString).length
            let from = min(beforeLength, total)
            for lower in from ... total {
                for upper in [lower, total] {
                    driver.setViewSelection(NSRange(location: lower, length: upper - lower))
                    if let problem = FuzzTextInputConsistency.violation(of: input) {
                        return FuzzSignature.setTextInputInconsistent + " (variant \(variant), \(lower)..<\(upper)): \(problem); model \(FuzzModel.describe(model))"
                    }
                }
            }
        }
        return nil
    }

    /// p21: a theme or width change mid-sequence leaves the document and the selection as they were.
    static func environmentViolation(_ kind: Int, on driver: FuzzDriver) -> String? {
        let before = FuzzModel.normalized(driver.model())
        let selection = driver.viewSelection()
        Self.applyEnvironment(kind, on: driver)
        let after = FuzzModel.normalized(driver.model())
        if after != before {
            return "an environment change (\(kind)) changed the document:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
        }
        let moved = driver.viewSelection()
        if moved != selection {
            return "an environment change (\(kind)) moved the selection \(selection) -> \(moved)"
        }
        return nil
    }

    static func applyEnvironment(_ kind: Int, on driver: FuzzDriver) {
        switch kind {
        case 0, 1:
            driver.host.updatePresentationInterfaceState { $0.updatedTheme(kind == 0 ? defaultDarkPresentationTheme : defaultPresentationTheme) }
        default:
            let height = driver.root.view.frame.height
            driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: kind == 2 ? 340.0 : 402.0, height: height)
        }
        driver.root.view.setNeedsLayout()
        driver.settle()
    }

    /// Light theme and 402pt, as every sequence's round trips (and the next sequence) assume.
    static func resetEnvironment(_ driver: FuzzDriver) {
        if driver.root.view.frame.width != 402.0 {
            Self.applyEnvironment(3, on: driver)
        }
        Self.applyEnvironment(1, on: driver)
    }

    static func externalPasteViolation(_ variant: Int, at: Int, on driver: FuzzDriver) -> String? {
        let text = driver.viewText() as NSString
        let caret = min(at, text.length)
        driver.setViewSelection(NSRange(location: caret, length: 0))
        driver.settle()
        let before = FuzzModel.normalized(driver.model())
        let beforeText = driver.viewText()
        let source = FuzzExternalPaste.sources[variant % FuzzExternalPaste.sources.count]
        UIPasteboard.general.items = source.items()
        Self.notePasteboardWritten()
        // The engine's own paste reports the moment it lands (`tgid_pasteWillLandHandler`). Waiting for the
        // TEXT to change is not enough since the p20 fix wave: a paste at a unit's stop first mints a body
        // line (a text change), and an HTML import lands ~1 s later (WebKit warms up) — after the op's undo,
        // which then raced the paste (edited seed 17).
        var landed = false
        var restoreLandHandler: (() -> Void)?
        if #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver, source.name.contains("html") {
            let view = engine.editor.engine
            let original = view.tgid_pasteWillLandHandler
            view.tgid_pasteWillLandHandler = {
                landed = true
                original?()
            }
            restoreLandHandler = { view.tgid_pasteWillLandHandler = original }
        }
        defer { restoreLandHandler?() }
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        // An HTML import lands ~1 s late the first time (WebKit warms up, measured p20): wait for it.
        let deadline = Date().addingTimeInterval(3.0)
        driver.settle(FuzzConfig.pasteSettle)
        while (restoreLandHandler != nil ? !landed : driver.viewText() == beforeText) && Date() < deadline {
            driver.settle(0.05)
        }
        driver.settle(0.1)
        let after = FuzzModel.normalized(driver.model())
        if after == before {
            // A destination that holds nothing of it (none known) or a refused paste: nothing to undo.
            return nil
        }
        guard let undoManager = driver.undoManager, undoManager.canUndo else {
            return "the external paste \(source.name) registered no undo step"
        }
        undoManager.undo()
        driver.settle(0.1)
        let undone = FuzzModel.normalized(driver.model())
        if undone != before {
            return "one undo did not revert the external paste \(source.name):\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))\n  undone \(FuzzModel.describe(undone))"
        }
        guard undoManager.canRedo else { return "the external paste's undo left nothing to redo" }
        undoManager.redo()
        driver.settle(0.1)
        let redone = FuzzModel.normalized(driver.model())
        if redone != after {
            return "redo did not bring back the external paste \(source.name):\n  after  \(FuzzModel.describe(after))\n  redone \(FuzzModel.describe(redone))"
        }
        return nil
    }

    static func nextStructural(_ random: inout FuzzRandom) -> FuzzOp {
        return .structural(random.pick(FuzzStructOp.allCases), random.int(64))
    }

    /// A table / details command's invariants (p17): when it changed the document, ONE undo returns to the
    /// model before it and redo to the model after it.
    static func structuralViolation(_ kind: FuzzStructOp, _ a: Int, on driver: FuzzDriver) -> String? {
        guard #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver else { return nil }
        let editor = engine.editor
        let roles = editor.currentRoles
        // Candidate carets: every table cell's start, or every details title's start.
        var candidates: [Int] = []
        for index in roles.indices {
            let isTitle = editor.detailsOwningTitle(atRoleAt: index) != nil
            let isCell = roles[index].tableCellCoordinates != nil
            if kind == .toggleDetails ? isTitle : isCell {
                candidates.append(editor.flatOffset(ofRoleAt: index))
            }
        }
        guard !candidates.isEmpty else { return nil }
        let caret = candidates[a % candidates.count]
        driver.setViewSelection(NSRange(location: caret, length: 0))
        driver.settle()
        let before = FuzzModel.normalized(driver.model())
        let undoManager = driver.undoManager
        switch kind {
        case .rowAbove: editor.insertTableRowAbove()
        case .rowBelow: editor.insertTableRowBelow()
        case .deleteRow: editor.deleteTableRow()
        case .columnLeft: editor.insertTableColumnLeft()
        case .columnRight: editor.insertTableColumnRight()
        case .deleteColumn: editor.deleteTableColumn()
        case .convertToText: editor.convertCurrentTableToText()
        case .deleteTable: editor.deleteTable()
        case .header: editor.toggleSelectionHeader()
        case .toggleDetails:
            let index = editor.roleIndex(atFlatOffset: caret)
            if let index, let details = editor.detailsOwningTitle(atRoleAt: index) {
                editor.toggleDetailsExpanded(id: details.id)
            }
        }
        driver.settle()
        let after = FuzzModel.normalized(driver.model())
        guard after != before else {
            return nil
        }
        guard let undoManager, undoManager.canUndo else {
            return "the \(kind.rawValue) command registered no undo step: \(FuzzModel.describe(after))"
        }
        undoManager.undo()
        driver.settle()
        let undone = FuzzModel.normalized(driver.model())
        if undone != before {
            return "one undo did not revert the \(kind.rawValue) command:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))\n  undone \(FuzzModel.describe(undone))"
        }
        guard undoManager.canRedo else {
            return "the \(kind.rawValue) command's undo left nothing to redo"
        }
        undoManager.redo()
        driver.settle()
        let redone = FuzzModel.normalized(driver.model())
        if redone != after {
            return "redo did not bring back the \(kind.rawValue) command:\n  after  \(FuzzModel.describe(after))\n  redone \(FuzzModel.describe(redone))"
        }
        return nil
    }

    static func nextKeyWalk(_ random: inout FuzzRandom, driver: FuzzDriver) -> FuzzOp {
        let text = driver.viewText() as NSString
        return .keyWalk(down: random.chance(50), from: Self.snap(random.int(text.length + 1), in: text), presses: 2 + random.int(5), extend: random.chance(35))
    }

    /// A repeated-arrow walk's invariants (p17): the model is unchanged, and every press moves the
    /// moving end of the selection (the caret; with ⇧, the end away from the anchor at `from`) in the
    /// key's direction or leaves it where it is — never the other way.
    static func keyWalkViolation(down: Bool, from: Int, presses: Int, extend: Bool, on driver: FuzzDriver) -> String? {
        let before = FuzzModel.normalized(driver.model())
        let length = (driver.viewText() as NSString).length
        driver.setViewSelection(NSRange(location: min(from, length), length: 0))
        driver.settle()
        let action = down ? "_moveDown:withHistory:" : "_moveUp:withHistory:"
        typealias Function = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> AnyObject?
        let selector = NSSelectorFromString(action)
        guard let method = class_getInstanceMethod(type(of: driver.view), selector) else { return nil }
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        var history: AnyObject?
        var trail: [Int] = []
        var moving = min(from, length)
        for _ in 0 ..< presses {
            history = function(driver.view, selector, extend, history)
            driver.settle()
            let selection = driver.viewSelection()
            let next: Int
            if extend {
                next = down ? NSMaxRange(selection) : selection.location
            } else {
                next = selection.location
            }
            trail.append(next)
            if down ? next < moving : next > moving {
                return FuzzSignature.keyWalkWrongWay + " (\(down ? "down" : "up") from \(from), extend \(extend)): \(trail)"
            }
            moving = next
        }
        let after = FuzzModel.normalized(driver.model())
        if after != before {
            return "a repeated arrow walk changed the model:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
        }
        return nil
    }

    static func nextLineOp(_ random: inout FuzzRandom) -> FuzzOp {
        return .line(random.pick(FuzzLineOp.allCases), random.int(64), random.int(3))
    }

    /// The engine-axis offset where top-level block `index` of `content` starts.
    static func topLevelStart(_ content: ChatInputContent, _ index: Int) -> Int {
        let lines = FuzzModel.engineLines(ChatInputContent(blocks: Array(content.blocks.prefix(index))))
        return lines.reduce(0) { total, line in
            switch line {
            case let .text(text), let .language(text), let .author(text):
                return total + (text as NSString).length + 1
            }
        }
    }

    static func topLevelParagraph(_ content: ChatInputContent, _ index: Int) -> ChatInputParagraph? {
        guard content.blocks.indices.contains(index), case let .paragraph(paragraph) = content.blocks[index] else { return nil }
        return paragraph
    }

    /// The `line` op's violation texts (p16; its three defects were fixed 2026-09-25, and these are plain
    /// violations now).
    static let checkedItemReturnSignature = "Return at the start of a checked item moved its check"
    static let wholeLineDeletionSignature = "deleting a whole line changed the line after it"
    static let blockCommandSelectionEndSignature = "a block command over a line selected to the next line's start changed the next line"

    static func lineOpViolation(_ kind: FuzzLineOp, _ a: Int, _ b: Int, on driver: FuzzDriver) -> String? {
        let before = FuzzModel.normalized(driver.model())
        let blocks = before.blocks
        func checklist(_ index: Int, checkedOnly: Bool) -> Bool {
            guard let paragraph = Self.topLevelParagraph(before, index), paragraph.list?.marker == .checklist else { return false }
            return !checkedOnly || (paragraph.list?.checked == true && !paragraph.text.isEmpty)
        }
        func pair(_ index: Int, nextNonEmpty: Bool) -> Bool {
            guard let first = Self.topLevelParagraph(before, index), let next = Self.topLevelParagraph(before, index + 1) else { return false }
            return !first.text.isEmpty && (!nextNonEmpty || !next.text.isEmpty)
        }
        switch kind {
        case .seedChecklist:
            UIPasteboard.general.string = "- [ ] open\n- [x] closed"
            Self.notePasteboardWritten()
            _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
            // p19: wait for the paste, as every paste op does (`FuzzConfig.pasteSettle`). Outside a
            // top-level body paragraph the markdown path declines and UIKit's own paste lands 20-30 ms
            // later; the step's 0.02 s settle then sometimes ended first and the NEXT op (default seed 80
            // step 34: a composition) ran under the paste, which a stock text view does not survive
            // either. Only in a slow process — why seed 80 failed inside a batch and never alone.
            driver.settle(FuzzConfig.pasteSettle)
            return nil
        case .toggleCheck:
            guard #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver else { return nil }
            let candidates = blocks.indices.filter { checklist($0, checkedOnly: false) }
            guard !candidates.isEmpty else { return nil }
            let index = candidates[a % candidates.count]
            guard let role = engine.editor.roleIndex(atFlatOffset: Self.topLevelStart(before, index)) else { return nil }
            engine.editor.toggleChecklistItem(engine.editor.currentRoles[role].blockID)
            driver.settle()
            var expected = before.blocks
            if case var .paragraph(paragraph) = expected[index], let list = paragraph.list {
                paragraph.list = ChatInputListMembership(marker: list.marker, level: list.level, checked: !(list.checked == true))
                expected[index] = .paragraph(paragraph)
            }
            let toggled = FuzzModel.normalized(driver.model())
            if toggled != ChatInputContent(blocks: expected) {
                return "the checkbox tap on block \(index) did not flip exactly its check:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(toggled))"
            }
            guard let undoManager = driver.undoManager, undoManager.canUndo else { return "the checkbox tap registered no undo step" }
            undoManager.undo()
            driver.settle()
            if FuzzModel.normalized(driver.model()) != before {
                return "one undo did not revert the checkbox tap on block \(index): \(FuzzModel.describe(FuzzModel.normalized(driver.model())))"
            }
            undoManager.redo()
            driver.settle()
            if FuzzModel.normalized(driver.model()) != toggled {
                return "redo did not bring back the checkbox tap on block \(index): \(FuzzModel.describe(FuzzModel.normalized(driver.model())))"
            }
            return nil
        case .returnAtItemStart:
            // Not below an EMPTY first item of the list: that is the double-Return TOP exit, which ends
            // the list for the empty item above instead (`decideReturnInListItem`, documented) — the p20
            // fix wave sweep reached it at default seed 61 and the check read the exit as a moved check.
            func isTopExit(_ index: Int) -> Bool {
                guard index > 0, let above = Self.topLevelParagraph(before, index - 1), above.list != nil, above.text.isEmpty else { return false }
                return index < 2 || Self.topLevelParagraph(before, index - 2)?.list == nil
            }
            let candidates = blocks.indices.filter { checklist($0, checkedOnly: true) && !isTopExit($0) }
            guard !candidates.isEmpty else { return nil }
            let index = candidates[a % candidates.count]
            let start = Self.topLevelStart(before, index)
            driver.setViewSelection(NSRange(location: start, length: 0))
            driver.settle()
            driver.insert("\n")
            driver.settle()
            let after = FuzzModel.normalized(driver.model())
            if after.blocks.count > index + 1, after.blocks[index + 1] != blocks[index] {
                return Self.checkedItemReturnSignature + " (block \(index)):\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
            }
            return nil
        case .deleteLine, .boundaryFormat:
            let candidates = blocks.indices.filter { pair($0, nextNonEmpty: kind == .boundaryFormat) }
            guard !candidates.isEmpty else { return nil }
            let index = candidates[a % candidates.count]
            let start = Self.topLevelStart(before, index)
            let next = Self.topLevelStart(before, index + 1)
            driver.setViewSelection(NSRange(location: start, length: next - start))
            driver.settle()
            if kind == .deleteLine {
                driver.deleteBackward()
                driver.settle()
                var expected = blocks
                expected.remove(at: index)
                let after = FuzzModel.normalized(driver.model())
                if after != ChatInputContent(blocks: expected) {
                    return Self.wholeLineDeletionSignature + " (block \(index)):\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
                }
            } else {
                driver.format([FuzzFormat.quote, .code, .pullQuote][b % 3])
                driver.settle()
                let after = FuzzModel.normalized(driver.model())
                if !after.blocks.contains(blocks[index + 1]) {
                    return Self.blockCommandSelectionEndSignature + " (block \(index + 1)):\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))"
                }
            }
            return nil
        }
    }

    /// Draws an external push (p15): its kind, its variant, and a selection on the pushed content's
    /// model flat axis (a caret, a range, or the end), snapped to composed characters.
    static func nextPush(_ random: inout FuzzRandom, driver: FuzzDriver) -> FuzzOp {
        let roll = random.int(100)
        let kind: FuzzPush
        switch roll {
        case 0 ..< 25: kind = .sameContent
        case 25 ..< 40: kind = .appendParagraph
        case 40 ..< 52: kind = .prependParagraph
        case 52 ..< 64: kind = .replaceFirstBlock
        case 64 ..< 76: kind = .dropLastBlock
        default: kind = .startingDocument
        }
        let variant = random.int(64)
        let text = kind.content(from: driver.model(), variant: variant).plainText as NSString
        let a = Self.snap(random.int(text.length + 1), in: text)
        let selection: (Int, Int)
        switch random.int(10) {
        case 0 ..< 5: selection = (a, a)
        case 5 ..< 8:
            let b = Self.snap(random.int(text.length + 1), in: text)
            selection = (min(a, b), max(a, b))
        default: selection = (text.length, text.length)
        }
        return .push(kind, variant, selection)
    }

    /// An external push's invariants (p15):
    /// - a content-changing push lands exactly: the model is the pushed content, and the node's selection
    ///   the pushed one;
    /// - a content-EQUAL push leaves the content, and — the editor being focused — the editor's own
    ///   selection (`echoedSelectionShouldApply`: while focused the editor owns its caret);
    /// - after a content-changing push nothing is left to undo or redo (a stock `UITextView` and the legacy
    ///   composer empty the stack on a set; `HarnessExternalSetUndoTests`, fixed 2026-09-25), and the
    ///   sequence's undo-all stops exactly at the last such set (`lastExternalSetModel`).
    static func pushViolation(_ kind: FuzzPush, _ variant: Int, _ selection: (Int, Int), on driver: FuzzDriver) -> String? {
        let rawBefore = driver.model()
        let before = FuzzModel.normalized(rawBefore)
        let beforeSelection = driver.node.selectedRange
        let content = kind.content(from: rawBefore, variant: variant)
        let range = selection.0 ..< selection.1
        // The external route (`HarnessPanelHost.setInputContent(_:selectionRange:)`), as Send's clear and a
        // draft sync arrive; the interaction's closure is the user's edits' funnel and applies undoably.
        driver.host.setInputContent(content, selectionRange: range)
        driver.settle(0.05)
        let after = FuzzModel.normalized(driver.model())
        let afterSelection = driver.node.selectedRange
        var problems: [String] = []
        let expected = FuzzModel.normalized(content)
        // Raw, as the node's own guard compares: a push equal only modulo run splits is a rebuild.
        let changed = content != rawBefore
        if changed {
            Self.lastExternalSetModel = after
            if after != expected && after == FuzzModel.normalized(FuzzModel.fillingEmptyDetailsBodies(content)) {
                problems.append(FuzzSignature.detailsWithoutBody + ": \(FuzzModel.describe(expected))")
            } else if after != expected {
                problems.append("an external push of \(FuzzModel.describe(expected)) left \(FuzzModel.describe(after))")
            } else if afterSelection != NSRange(location: selection.0, length: selection.1 - selection.0), !Self.holdsAtoms(content) {
                // (With an atom on the axis a model offset inside its span snaps to a boundary by rule,
                // `HarnessAtomComposerAxisTests`; such pushes are not compared.)
                problems.append("an external push with the selection \(selection.0)..<\(selection.1) left the node's selection at \(afterSelection)")
            }
        } else {
            if after != before {
                problems.append("a content-equal push changed the model:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(after))")
            } else if afterSelection != beforeSelection {
                problems.append("a content-equal push moved the focused editor's selection \(beforeSelection) -> \(afterSelection)")
            }
        }
        if changed, let undoManager = driver.undoManager, undoManager.canUndo || undoManager.canRedo {
            problems.append(FuzzSignature.undoCrossesExternalSet + " (canUndo \(undoManager.canUndo), canRedo \(undoManager.canRedo))")
        }
        return problems.isEmpty ? nil : problems.joined(separator: "; ")
    }

    /// Whether `content` holds a run the flat axis maps as one attachment (a formula, a custom emoji, an
    /// inline button), inside any block.
    static func holdsAtoms(_ content: ChatInputContent) -> Bool {
        func atoms(_ runs: [ChatInputRun]) -> Bool {
            return runs.contains { run in
                if run.attributes.formula != nil { return true }
                switch run.attributes.entity {
                case .customEmoji?, .button?: return true
                default: return false
                }
            }
        }
        return content.blocks.contains { block in
            switch block {
            case let .paragraph(paragraph): return atoms(paragraph.runs)
            case let .code(code): return atoms(code.runs)
            case let .pullQuote(quote): return atoms(quote.runs) || atoms(quote.author)
            case let .blockQuote(quote): return Self.holdsAtoms(quote.content) || atoms(quote.author)
            case let .table(table): return table.rows.contains { $0.cells.contains { atoms($0.runs) } }
            case let .details(details): return atoms(details.title) || Self.holdsAtoms(details.content)
            case let .media(media): return atoms(media.caption)
            default: return false
            }
        }
    }

    /// A composition's invariants:
    /// - nothing is left marked after the commit;
    /// - a cancelled composition at a caret leaves the model as it was;
    /// - one undo reverts the whole committed composition (the caret is moved away and back first, so
    ///   the composition cannot legitimately join an open typing run);
    /// - the committed result equals typing the final candidate over the same selection (`insertText`,
    ///   which the surface gate decides). The op leaves the TYPED result in place.
    static func composeViolation(_ ime: FuzzIME, _ commit: FuzzCommit, selecting: (Int, Int)?, on driver: FuzzDriver) -> String? {
        guard let input = driver.view as? (UIView & UITextInput) else {
            return nil
        }
        let viewText = driver.viewText() as NSString
        let selection: NSRange
        if let selecting {
            selection = NSRange(location: selecting.0, length: selecting.1 - selecting.0)
        } else {
            selection = driver.viewSelection()
        }
        guard selection.location != NSNotFound, NSMaxRange(selection) <= viewText.length else {
            return nil
        }
        // Close any open typing run: a caret move ends it.
        driver.setViewSelection(NSRange(location: selection.location == 0 ? viewText.length : 0, length: 0))
        driver.settle()
        driver.setViewSelection(selection)
        driver.settle()
        // An EMPTY document has one caret position, so the move above moved nothing and cannot end
        // the run a preceding Backspace left open — and a composition contiguous with a deletion
        // legitimately continues it (stock's type-backspace-type is one step), so one undo takes
        // back both. Seed 29 (2026-09-24) was exactly that. End the run as a caret move would.
        if viewText.length == 0, #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver {
            engine.editor.endTypingRun()
        }
        let before = FuzzModel.normalized(driver.model())
        // p22: a composition's first marked edit is an edit — a stock text view clears the REDO stack there,
        // and nothing can be redone while the composition is open (`HarnessRedoDuringCompositionTests`).
        // Recorded, not returned at once, so the composition's own checks below still run.
        var redoNote: String?
        for (index, step) in ime.steps.enumerated() {
            input.setMarkedText(step.text, selectedRange: step.selected)
            driver.settle()
            if index == 0, input.markedTextRange != nil, driver.undoManager?.canRedo == true {
                redoNote = FuzzSignature.redoDuringComposition + " (\(ime.rawValue), after \(fuzzEscaped(step.text)))"
            }
        }
        let final = ime.steps.last?.text ?? ""
        switch commit {
        case .unmark:
            input.unmarkText()
        case .insertFinal:
            input.insertText(final)
        case .cancel:
            input.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            input.unmarkText()
        }
        driver.settle(0.05)
        if input.markedTextRange != nil {
            return "a \(ime.rawValue) composition is still marked after .\(commit.rawValue)"
        }
        let composed = FuzzModel.normalized(driver.model())
        if commit == .cancel, selection.length == 0 {
            if composed != before {
                return "a cancelled \(ime.rawValue) composition left the model changed:\n  before \(FuzzModel.describe(before))\n  after  \(FuzzModel.describe(composed))"
            }
            return redoNote
        }
        // A composition that changed nothing — one started over a selection the gate refuses to
        // replace (a table covered only in part), as typing over it changes nothing — has no step of
        // its own to undo; the typing oracle below still has to agree that nothing changes.
        let changedNothing = composed == before
        guard changedNothing || (driver.undoManager?.canUndo ?? false), let undoManager = driver.undoManager else {
            return "a committed \(ime.rawValue) composition registered no undo step: \(FuzzModel.describe(composed))"
        }
        if !changedNothing {
            undoManager.undo()
            driver.settle(0.05)
        }
        let undone = FuzzModel.normalized(driver.model())
        if undone != before {
            return "one undo did not revert the whole \(ime.rawValue) composition (.\(commit.rawValue)):\n  before \(FuzzModel.describe(before))\n  undone \(FuzzModel.describe(undone))"
        }
        // p21: compare like with like. The typing below runs on the state the undo just restored, and an
        // undo restores the MODEL, not every attribute the engine keeps beside it (a separator's typing
        // attributes, `HarnessUndoSeparatorTypingAttributesTests`), so typing there can be attributed
        // differently from typing on the state the composition found (default/edited seed 73: the
        // composition was right, the oracle typed after the undo). So the composition is made AGAIN on the
        // restored state, and THAT one is the oracle's subject; the first one is compared with it, and a
        // difference is the history defect, reported under its own signature.
        var composedOnRestored = composed
        if commit != .cancel, !changedNothing {
            func reselect() {
                driver.setViewSelection(NSRange(location: selection.location == 0 ? viewText.length : 0, length: 0))
                driver.settle()
                driver.setViewSelection(selection)
                driver.settle()
            }
            reselect()
            for step in ime.steps {
                input.setMarkedText(step.text, selectedRange: step.selected)
                driver.settle()
            }
            if commit == .unmark {
                input.unmarkText()
            } else {
                input.insertText(final)
            }
            driver.settle(0.05)
            if input.markedTextRange != nil {
                return "a \(ime.rawValue) composition is still marked after .\(commit.rawValue) (made again after its undo)"
            }
            composedOnRestored = FuzzModel.normalized(driver.model())
            if composedOnRestored != before {
                undoManager.undo()
                driver.settle(0.05)
            }
            let undoneAgain = FuzzModel.normalized(driver.model())
            if undoneAgain != before {
                return "one undo did not revert the whole \(ime.rawValue) composition (.\(commit.rawValue), made again after its undo):\n  before \(FuzzModel.describe(before))\n  undone \(FuzzModel.describe(undoneAgain))"
            }
        }
        // The oracle: what the keyboard's typing does over the same selection — the final candidate
        // typed, or (a cancel over a selection) the selection deleted.
        driver.setViewSelection(selection)
        driver.settle()
        if commit == .cancel {
            // p21: a cancelled composition over a selection is TYPING something and taking it back, not a
            // Backspace over the selection. The two differ by decision: a deletion from a line's start to a
            // later line's start keeps the LATER line's role (p16, `deletesWholeLinesBefore`), while typing —
            // and so a composition — takes the FIRST line's (`tgid_isResolvingCompositionSelection`). Edited
            // seed 35 compared a cancel over whole checklist lines with Backspace and read the decision as a
            // defect. A stock text view gives the same answer both ways.
            driver.insert("x")
            driver.settle()
            driver.deleteBackward()
        } else {
            driver.insert(final)
        }
        driver.settle(0.05)
        let typed = FuzzModel.normalized(driver.model())
        let composedFirst = composed
        if composedOnRestored == typed, composedFirst != composedOnRestored {
            return FuzzSignature.typingDependsOnUndoHistory + " (\(ime.rawValue), .\(commit.rawValue)):\n  first     \(FuzzModel.describe(composedFirst))\n  restored  \(FuzzModel.describe(composedOnRestored))"
        }
        if composedOnRestored != typed, let first = ime.steps.first?.text, commit != .cancel {
            // p17 signature: the composed text is the typed text with the FIRST candidate left in once.
            let typedText = typed.plainText as NSString
            let composedText = composedOnRestored.plainText
            let leftBehind = (0 ... typedText.length).contains { offset in
                typedText.replacingCharacters(in: NSRange(location: offset, length: 0), with: first) == composedText
            }
            if leftBehind {
                return FuzzSignature.compositionLeavesFirstCandidate + " (\(ime.rawValue), .\(commit.rawValue)):\n  composed \(FuzzModel.describe(composedOnRestored))\n  typed    \(FuzzModel.describe(typed))"
            }
        }
        if composedOnRestored != typed {
            // p21: the compact description leaves out list membership, alignment and entity payloads; when it
            // cannot tell the two apart, print the models in full.
            let detail = FuzzModel.describe(composedOnRestored) == FuzzModel.describe(typed) ? "\n  composed (full) \(composedOnRestored.blocks)\n  typed (full)    \(typed.blocks)" : ""
            return "a \(ime.rawValue) composition (.\(commit.rawValue)) did not do what the keyboard's typing does:\n  composed \(FuzzModel.describe(composedOnRestored))\n  typed    \(FuzzModel.describe(typed))" + detail
        }
        return redoNote
    }

    /// The driver's violations, re-read once after a longer settle before they count: the engine
    /// delivers a paste's change notification later than a keystroke's (measured: the chat's state
    /// had the pasted text at 0.1 s, not at 0.03 s), and a violation that heals by itself inside
    /// 0.3 s is timing, not a defect.
    static func settledViolations(_ driver: FuzzDriver) -> [String] {
        let first = driver.violations()
        if first.isEmpty {
            return first
        }
        driver.settle(0.3)
        return driver.violations()
    }

    /// Arranges `start` the way every sequence starts (content set, focus, the process's own
    /// pasteboard content, an empty undo stack).
    static func arrange(_ driver: FuzzDriver, _ start: ChatInputContent) {
        driver.arrange(start)
        // The process's own pasteboard content, written before anything reads it (never read the
        // clipboard first: another process's content raises the paste prompt and hangs the run).
        UIPasteboard.general.string = "pasted"
        Self.notePasteboardWritten()
        driver.undoManager?.removeAllActions()
        driver.settle()
    }

    /// Arranges `start` and executes `ops` with the fuzz's settle, checking nothing: the regression
    /// tests a fuzz failure reduces to assert on the outcome themselves.
    static func perform(_ driver: FuzzDriver, start: ChatInputContent, ops: [FuzzOp]) {
        Self.arrange(driver, start)
        for op in ops {
            Self.execute(op, on: driver)
            driver.settle(0.1)
        }
        driver.settle(0.2)
    }

    /// Replays an explicit op list (a reduced sequence) and returns the first step's violations,
    /// or nil when every step held.
    static func replay(_ driver: FuzzDriver, start: ChatInputContent, ops: [FuzzOp]) -> (step: Int, violations: [String])? {
        Self.arrange(driver, start)
        for (step, op) in ops.enumerated() {
            if Self.replayPrintsSteps {
                print("FUZZ replay step=\(step) \(op)")
            }
            let opViolation = Self.execute(op, on: driver)
            driver.settle()
            let violations = (Self.filteredOpViolation(opViolation).map { [$0] } ?? []) + Self.settledViolations(driver)
            if !violations.isEmpty {
                return (step, violations)
            }
        }
        return nil
    }

    /// Whether `pasted` is `tip` plus the documented trailing empty line a paste ending in a
    /// non-body block at the document end adds (`HarnessContainerCutPasteRoundTripTests`).

    static func equalModuloTrailingLine(_ pasted: ChatInputContent, _ tip: ChatInputContent) -> Bool {
        if pasted == tip {
            return true
        }
        guard pasted.blocks.count == tip.blocks.count + 1, Array(pasted.blocks.dropLast()) == tip.blocks,
              case let .paragraph(last)? = pasted.blocks.last, last.text.isEmpty else {
            return false
        }
        return true
    }

    /// An op (or undo/redo step) that takes over a second is printed as `FUZZ SLOW`: not a failure,
    /// but a lead (a single seed once took 476 s where its siblings take ~6 s).
    /// Dark theme, then back to light, through the panel's own theme path
    /// (`HarnessPanelHost.updatePresentationInterfaceState` + a layout pass). Nil when the document, the
    /// settled invariants and the selection all survived (a filed defect's signature is filtered).
    static func themeRoundTripViolation(_ driver: FuzzDriver, tip: ChatInputContent) -> String? {
        let selection = driver.viewSelection()
        for dark in [true, false] {
            let label = dark ? "dark" : "light"
            driver.host.updatePresentationInterfaceState { $0.updatedTheme(dark ? defaultDarkPresentationTheme : defaultPresentationTheme) }
            driver.root.view.setNeedsLayout()
            driver.settle()
            if let violation = Self.settledViolations(driver).first {
                return "after the change to \(label): \(violation)"
            }
            let model = FuzzModel.normalized(driver.model())
            if model != tip {
                return "the change to \(label) changed the document:\n  tip   \(FuzzModel.describe(tip))\n  after \(FuzzModel.describe(model))"
            }
        }
        let after = driver.viewSelection()
        if after != selection {
            return Self.filteredOpViolation("a theme change moved the selection \(selection) -> \(after)")
        }
        return nil
    }

    /// The widths the resize round trip visits, in order: narrower (portrait on a small phone, Split View),
    /// wider (landscape), then back to the harness's own 402pt. See `resizeRoundTripViolation`.
    static let resizeWidths: [CGFloat] = [300.0, 700.0, 402.0]

    /// A caret rect for every offset of the view's text: the layout, as `UITextInput` reports it.
    static func caretGeometry(_ input: UIView & UITextInput) -> [CGRect] {
        let total = input.offset(from: input.beginningOfDocument, to: input.endOfDocument)
        return (0 ... max(total, 0)).map { offset in
            guard let position = input.position(from: input.beginningOfDocument, offset: offset) else { return .null }
            let rect = input.caretRect(for: position)
            return CGRect(x: (rect.minX * 2.0).rounded() / 2.0, y: (rect.minY * 2.0).rounded() / 2.0, width: (rect.width * 2.0).rounded() / 2.0, height: (rect.height * 2.0).rounded() / 2.0)
        }
    }

    /// Re-lays the panel out at each of `resizeWidths` through the root's own layout driver (the panel's
    /// `updateLayout(width:)`, as a rotation or a Split View change delivers it), settling after each (p14,
    /// 2026-09-24). Nil when, at every width, the settled invariants held, the document equalled `tip` and
    /// the selection was kept, and when, back at 402pt, every caret rect equals the one before the trip (the
    /// layout was recomputed, not left stale or drifted). The drawn cursor lagging a width change by one
    /// run-loop turn is filed separately (`HarnessWidthChangeSelectionDisplayTests`) and not checked here.
    static func resizeRoundTripViolation(_ driver: FuzzDriver, tip: ChatInputContent) -> String? {
        guard let input = driver.view as? (UIView & UITextInput) else {
            return nil
        }
        let selection = driver.viewSelection()
        let before = Self.caretGeometry(input)
        let height = driver.root.view.frame.height
        defer {
            driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: height)
            driver.settle()
        }
        for width in Self.resizeWidths {
            driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            driver.root.view.setNeedsLayout()
            driver.settle()
            if let violation = Self.settledViolations(driver).first {
                return "at width \(Int(width)): \(violation)"
            }
            let model = FuzzModel.normalized(driver.model())
            if model != tip {
                return "the width change to \(Int(width)) changed the document:\n  tip   \(FuzzModel.describe(tip))\n  after \(FuzzModel.describe(model))"
            }
            let after = driver.viewSelection()
            if after != selection {
                return Self.filteredOpViolation("the width change to \(Int(width)) moved the selection \(selection) -> \(after)")
            }
        }
        let back = Self.caretGeometry(input)
        if back != before {
            let differing = zip(before, back).enumerated().filter { $0.element.0 != $0.element.1 }
            let sample = differing.prefix(3).map { "offset \($0.offset): \($0.element.0) -> \($0.element.1)" }.joined(separator: "; ")
            let table = tip.blocks.contains { block in
                if case .table = block { return true }
                if case let .blockQuote(quote) = block { return quote.content.blocks.contains { if case .table = $0 { return true }; return false } }
                return false
            }
            return Self.filteredOpViolation((table ? "(a table in the document) " : "") + "after the width round trip the layout differs at \(differing.count) of \(before.count) offsets (count \(before.count) -> \(back.count)): \(sample)")
        }
        return nil
    }

    /// Drags `[L/4, L/2)` of the engine text (snapped to composed characters) to offset 0 through the
    /// editor's local-move entry point, then undoes once. Nil when the settled invariants held after
    /// the move and the undo returned to `tip` (or when the move was refused, which changes nothing).
    @available(iOS 18.4, *)
    static func localMoveRoundTripViolation(_ driver: EngineFuzzDriver, tip: ChatInputContent) -> String? {
        let text = driver.viewText() as NSString
        guard text.length >= 4, let undoManager = driver.undoManager else {
            return nil
        }
        let lower = Self.snap(text.length / 4, in: text)
        let upper = Self.snap(text.length / 2, in: text)
        guard lower > 0, upper > lower else {
            return nil
        }
        driver.setViewSelection(NSRange(location: lower, length: upper - lower))
        driver.settle()
        guard let context = driver.editor.makeTextDragContext() else {
            return nil
        }
        print("FUZZ local move \(lower)..<\(upper) -> 0")
        let moved = driver.editor.performLocalMove(context, toFlatOffset: 0)
        driver.settle()
        if let violation = Self.settledViolations(driver).first {
            return "after moving \(lower)..<\(upper) to 0: \(violation)"
        }
        let after = FuzzModel.normalized(driver.model())
        guard moved else {
            return after == tip ? nil : "a refused move changed the document:\n  tip   \(FuzzModel.describe(tip))\n  after \(FuzzModel.describe(after))"
        }
        guard undoManager.canUndo else {
            return "the move \(lower)..<\(upper) -> 0 registered no undo step"
        }
        undoManager.undo()
        driver.settle()
        if let violation = Self.settledViolations(driver).first {
            return "after undoing the move: \(violation)"
        }
        let undone = FuzzModel.normalized(driver.model())
        if undone != tip {
            return "one undo did not revert the move \(lower)..<\(upper) -> 0:\n  tip    \(FuzzModel.describe(tip))\n  moved  \(FuzzModel.describe(after))\n  undone \(FuzzModel.describe(undone))"
        }
        return nil
    }

    static func reportIfSlow(_ what: String, tag: String, since began: Date) {
        let elapsed = Date().timeIntervalSince(began)
        if elapsed > 1.0 {
            print("FUZZ SLOW \(tag) \(what): \(String(format: "%.2f", elapsed)) s")
        }
    }

    private func runSequence(_ driver: FuzzDriver, seed: UInt64, contents: [ChatInputContent] = HarnessComposerFuzzTests.startingContents()) -> Bool {
        var random = FuzzRandom(seed: seed)
        let start = contents[random.int(contents.count)]
        FuzzSequenceEnd.endedBy = nil
        if FuzzConfig.environments {
            Self.resetEnvironment(driver)
        }
        Self.arrange(driver, start)

        let startModel = FuzzModel.normalized(driver.model())
        Self.lastExternalSetModel = startModel
        FuzzPush.startingDocuments = contents
        var pushRandom = FuzzRandom(seed: seed ^ 0x5055_5348_5055_5348)
        var lineRandom = FuzzRandom(seed: seed ^ 0x4C49_4E45_4C49_4E45)
        var walkRandom = FuzzRandom(seed: seed ^ 0x5741_4C4B_5741_4C4B)
        var structuralRandom = FuzzRandom(seed: seed ^ 0x5354_5255_5354_5255)
        var chatInsertRandom = FuzzRandom(seed: seed ^ 0x4348_4154_4348_4154)
        var moveRandom = FuzzRandom(seed: seed ^ 0x4D4F_5645_4D4F_5645)
        var externalPasteRandom = FuzzRandom(seed: seed ^ 0x4558_5450_4558_5450)
        var undoRedoRandom = FuzzRandom(seed: seed ^ 0x554E_444F_554E_444F)
        var customInsertRandom = FuzzRandom(seed: seed ^ 0x4355_5354_4355_5354)
        var environmentRandom = FuzzRandom(seed: seed ^ 0x454E_5649_454E_5649)
        var formatTypeOverRandom = FuzzRandom(seed: seed ^ 0x4654_4F56_4654_4F56)
        var oneLineInsertRandom = FuzzRandom(seed: seed ^ 0x4F4E_454C_4F4E_454C)
        var chatMentionRandom = FuzzRandom(seed: seed ^ 0x4D45_4E54_4D45_4E54)
        var normalisingSetRandom = FuzzRandom(seed: seed ^ 0x4E4F_524D_4E4F_524D)
        var log: [FuzzOp] = []
        let tag = "\(driver.name) seed=\(seed)"
        print("FUZZ \(tag) start \(FuzzModel.describe(startModel))")

        /// A corrupting known defect was seen: the sequence ends here, counted, not failed.
        func endedByKnownDefect(_ place: String) -> Bool {
            guard let known = FuzzSequenceEnd.take() else { return false }
            print("FUZZ \(tag) ended \(place) by known defect \(known)")
            return true
        }

        func fail(_ what: String, step: Int) {
            let message = "FUZZ FAILURE \(tag) step=\(step): \(what)\n  start: \(FuzzModel.describe(startModel))\n  ops: [\n    " + log.map { "\($0)," }.joined(separator: "\n    ") + "\n  ]"
            print(message)
            XCTFail(message)
        }

        if let violation = Self.settledViolations(driver).first {
            fail("before any op: \(violation)", step: -1)
            return false
        }
        if endedByKnownDefect("before any op") {
            return true
        }

        let steps = FuzzConfig.steps
        for step in 0 ..< steps {
            // p15: an external push first, now and then, from its own stream; then the step's op, drawn
            // from the document the push left.
            let pushes = FuzzConfig.externalPushes && pushRandom.chance(FuzzConfig.externalPushPercent)
            // p16: a line op next, now and then, from its own stream.
            let lines = FuzzConfig.lineOps && lineRandom.chance(FuzzConfig.lineOpPercent)
            // p17: a repeated-arrow walk next, now and then, from its own stream.
            let walks = FuzzConfig.keyWalks && walkRandom.chance(FuzzConfig.keyWalkPercent)
            let structural = FuzzConfig.structuralOps && structuralRandom.chance(FuzzConfig.structuralPercent)
            let chatInsert = FuzzConfig.chatInserts && chatInsertRandom.chance(FuzzConfig.chatInsertPercent)
            let move = FuzzConfig.moves && moveRandom.chance(FuzzConfig.movePercent)
            let externalPaste = FuzzConfig.externalPastes && externalPasteRandom.chance(FuzzConfig.externalPastePercent)
            let undoRedo = FuzzConfig.undoRedos && undoRedoRandom.chance(FuzzConfig.undoRedoPercent)
            let environment = FuzzConfig.environments && environmentRandom.chance(FuzzConfig.environmentPercent)
            let customInsert = FuzzConfig.customInserts && customInsertRandom.chance(FuzzConfig.customInsertPercent)
            let formatTypeOver = FuzzConfig.formatTypeOvers && formatTypeOverRandom.chance(FuzzConfig.formatTypeOverPercent)
            let oneLineInsert = FuzzConfig.oneLineInserts && oneLineInsertRandom.chance(FuzzConfig.oneLineInsertPercent)
            let chatMention = FuzzConfig.chatMentions && chatMentionRandom.chance(FuzzConfig.chatMentionPercent)
            let normalisingSet = FuzzConfig.normalisingSets && normalisingSetRandom.chance(FuzzConfig.normalisingSetPercent)
            let phases = (pushes ? ["push"] : []) + (lines ? ["line"] : []) + (walks ? ["walk"] : []) + (structural ? ["structural"] : []) + (chatInsert ? ["chatInsert"] : []) + (move ? ["move"] : []) + (externalPaste ? ["externalPaste"] : []) + (environment ? ["environment"] : []) + (customInsert ? ["customInsert"] : []) + (formatTypeOver ? ["formatTypeOver"] : []) + (oneLineInsert ? ["oneLineInsert"] : []) + (chatMention ? ["chatMention"] : []) + (normalisingSet ? ["normalisingSet"] : []) + ["op"] + (undoRedo ? ["undoRedo"] : [])
            for phase in phases {
                let op: FuzzOp
                switch phase {
                case "push": op = Self.nextPush(&pushRandom, driver: driver)
                case "line": op = Self.nextLineOp(&lineRandom)
                case "walk": op = Self.nextKeyWalk(&walkRandom, driver: driver)
                case "structural": op = Self.nextStructural(&structuralRandom)
                case "chatInsert": op = Self.nextChatInsert(&chatInsertRandom)
                case "move": op = Self.nextMove(&moveRandom, driver: driver)
                case "externalPaste": op = Self.nextExternalPaste(&externalPasteRandom, driver: driver)
                case "undoRedo": op = .undoRedo
                case "customInsert": op = .chatInsert("😀", custom: true)
                case "environment": op = Self.nextEnvironment(&environmentRandom)
                case "formatTypeOver": op = Self.nextFormatTypeOver(&formatTypeOverRandom, driver: driver)
                case "oneLineInsert": op = .oneLineInsert(oneLineInsertRandom.int(64), oneLineInsertRandom.int(64))
                case "chatMention": op = .chatMention
                case "normalisingSet": op = .normalisingSet(normalisingSetRandom.int(FuzzNormalisingSet.blocks.count))
                default: op = Self.nextOp(&random, driver: driver)
                }
                log.append(op)
                print("FUZZ \(tag) step=\(step) \(op)")
                let opBegan = Date()
                let opViolation = Self.execute(op, on: driver)
                driver.settle()
                Self.reportIfSlow("step=\(step)", tag: tag, since: opBegan)
                if FuzzConfig.verbose {
                    print("FUZZ \(tag)   -> \(FuzzModel.describe(driver.model())) sel=\(driver.viewSelection()) canUndo=\(driver.undoManager?.canUndo ?? false)")
                }
                let violations = (Self.filteredOpViolation(opViolation).map { [$0] } ?? []) + Self.settledViolations(driver)
                if !violations.isEmpty {
                    fail(violations.joined(separator: "; "), step: step)
                    return false
                }
                if endedByKnownDefect("at step=\(step)") {
                    return true
                }
            }
        }

        // p21: back to light / 402pt before the round trips, which assume them.
        if FuzzConfig.environments {
            Self.resetEnvironment(driver)
            if let violation = Self.settledViolations(driver).first {
                fail("after resetting the environment: \(violation)", step: steps)
                return false
            }
        }
        guard let undoManager = driver.undoManager else {
            return true
        }
        // 1. Undo-all / redo-all. The tip: a sequence can END with redo steps available (it ended on
        // an undo), and redo-all later goes all the way, so first redo everything left.
        func drain(_ label: String, _ available: () -> Bool, _ step: () -> Void) -> Int? {
            var count = 0
            while available() && count < FuzzConfig.undoAllCap {
                print("FUZZ \(tag) \(label) \(count)")
                let stepBegan = Date()
                step()
                driver.settle()
                Self.reportIfSlow("\(label) \(count)", tag: tag, since: stepBegan)
                count += 1
                if let violation = Self.settledViolations(driver).first {
                    fail("during \(label), after \(count): \(violation)", step: steps)
                    return nil
                }
                if FuzzSequenceEnd.endedBy != nil {
                    return nil
                }
            }
            return count
        }
        guard drain("redo-to-tip", { undoManager.canRedo }, { undoManager.redo() }) != nil else { return endedByKnownDefect("during redo-to-tip") }
        let tipModel = FuzzModel.normalized(driver.model())
        guard let undos = drain("undo-all", { undoManager.canUndo }, { undoManager.undo() }) else { return endedByKnownDefect("during undo-all") }
        let undone = FuzzModel.normalized(driver.model())
        // EXACTLY the model the last external set left (the arrange, a Send that cleared, a
        // content-changing push): an external set empties the stack, so undo-all can neither stop short
        // of it (a lost step) nor go past it (an undo across the set — `HarnessExternalSetUndoTests`).
        // It used to accept the start, the last clear or ANY pushed model, which is exactly where an
        // undo reaching across the sets lands, so the check could not see that defect.
        let lastSet = Self.lastExternalSetModel ?? startModel
        if undone != lastSet {
            let crossed = undone == startModel && lastSet != startModel ? " (it crossed an external set back to the start)" : ""
            fail("undo-all (\(undos) undos) did not stop at the last external set\(crossed):\n  set    \(FuzzModel.describe(lastSet))\n  undone \(FuzzModel.describe(undone))\n  start  \(FuzzModel.describe(startModel))\n  tip    \(FuzzModel.describe(tipModel))", step: steps)
            return false
        }
        guard let redos = drain("redo-all", { undoManager.canRedo }, { undoManager.redo() }) else { return endedByKnownDefect("during redo-all") }
        let redone = FuzzModel.normalized(driver.model())
        if redone != tipModel {
            fail("redo-all (\(redos) redos after \(undos) undos) did not return to the tip:\n  tip    \(FuzzModel.describe(tipModel))\n  redone \(FuzzModel.describe(redone))", step: steps)
            return false
        }

        // 2. A theme round trip (p12, 2026-09-24): dark and back, as auto-night or the user's appearance
        // switch delivers one to a composer with content. It consumes no randomness, so every seed's op
        // stream is unchanged. The document and every settled invariant must survive it; the selection
        // must too (`HarnessThemeChangeSelectionTests`).
        if let violation = Self.themeRoundTripViolation(driver, tip: tipModel) {
            fail("during the theme round trip: \(violation)", step: steps)
            return false
        }
        if endedByKnownDefect("during the theme round trip") {
            return true
        }

        // 2a. A width round trip (p14, 2026-09-24): 300, 700, then back to 402pt, as a rotation or Split View
        // delivers it. Deterministic from the tip, so it consumes no randomness and every seed's op stream is
        // unchanged. See `resizeRoundTripViolation`.
        if let violation = Self.resizeRoundTripViolation(driver, tip: tipModel) {
            fail("during the width round trip: \(violation)", step: steps)
            return false
        }
        if endedByKnownDefect("during the width round trip") {
            return true
        }
        print("FUZZ \(tag) width round trip ok")

        // 2b. A local drag-and-drop move (2026-09-24): the middle of the document dragged to its start,
        // then ONE undo. Deterministic from the tip, so it consumes no randomness either. The settled
        // invariants must hold after the move, and one undo must return to the tip.
        if #available(iOS 18.4, *), let engine = driver as? EngineFuzzDriver {
            if let violation = Self.localMoveRoundTripViolation(engine, tip: tipModel) {
                fail("during the local-move round trip: \(violation)", step: steps)
                return false
            }
            if endedByKnownDefect("during the local-move round trip") {
                return true
            }
        }

        // 3. Copy → paste-back of the whole document, then its undo.
        if driver.viewText().isEmpty {
            print("FUZZ \(tag) ok undos=\(undos) redos=\(redos) (empty: no round trip)")
            return true
        }
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        driver.settle()
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        Self.notePasteboardWritten()
        driver.settle()
        Self.ensureOwnPasteboardContent()
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        driver.settle()
        if let violation = Self.settledViolations(driver).first {
            fail("during the copy → paste-back round trip: \(violation)", step: steps)
            return false
        }
        if endedByKnownDefect("during the copy → paste-back round trip") {
            return true
        }
        let pasted = FuzzModel.normalized(driver.model())
        if !Self.equalModuloTrailingLine(pasted, tipModel) {
            fail("copy → paste-back of the whole document changed it:\n  tip    \(FuzzModel.describe(tipModel))\n  pasted \(FuzzModel.describe(pasted))", step: steps)
            return false
        }
        if undoManager.canUndo {
            undoManager.undo()
            driver.settle()
            let unpasted = FuzzModel.normalized(driver.model())
            if unpasted != tipModel {
                fail("undoing the paste-back did not return to the tip:\n  tip      \(FuzzModel.describe(tipModel))\n  unpasted \(FuzzModel.describe(unpasted))", step: steps)
                return false
            }
        }
        // 4. p20: the edit load. The tip, sent as the chat sends it and loaded back into the composer as
        // message editing loads it (an external set), is read back as the reloaded content: the composer
        // shows exactly the message it is editing. Deterministic, consumes no randomness; the external set
        // empties the undo stack, so it is the sequence's last step.
        if let violation = Self.editReloadViolation(driver, tip: tipModel) {
            fail("during the edit-reload round trip: \(violation)", step: steps)
            return false
        }
        print("FUZZ \(tag) ok undos=\(undos) redos=\(redos)")
        return true
    }

    /// Sends `tip` through `HarnessSendPath`, sets the reloaded content into the composer as the edit load
    /// does, and compares what the composer then holds with it (both in the route's canonical form; an
    /// expanded details block with no body gains one on a set, `HarnessDetailsBodyCrossDeleteTests`).
    static func editReloadViolation(_ driver: FuzzDriver, tip: ChatInputContent) -> String? {
        let sent = HarnessSendPath.send(tip)
        guard sent.route != .empty, !sent.markdownConverted, let reloaded = sent.reloaded else {
            return nil
        }
        driver.host.setInputContent(reloaded)
        driver.settle(0.1)
        if let violation = Self.settledViolations(driver).first {
            return "after loading the sent message for editing: \(violation)"
        }
        let expected = HarnessSendPath.canonical(FuzzModel.fillingEmptyDetailsBodies(reloaded), route: sent.route)
        let actual = HarnessSendPath.canonical(driver.model(), route: sent.route)
        if expected != actual {
            return "the composer does not show the message it is editing:\n  reloaded \(HarnessEdited.describe(reloaded))\n  composer \(HarnessEdited.describe(driver.model()))"
        }
        return nil
    }

    func testEngineFuzz() throws {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        try self.runFuzz(contents: Self.startingContents(), label: "")
    }

    /// The same fuzz over EDITED-MESSAGE content (p13, 2026-09-24): starting documents holding media
    /// with captions, an audio atom and an album, inline and standalone formulas, a button row and an
    /// inline button, mentions, dates, links and custom emoji, mixed with a table, a details block, a
    /// quote, code and a list (`editedStartingContents`). A separate method, so the default fuzz's
    /// starting-document draw — and so every default seed's op stream — is unchanged. The harness's
    /// stand-in formula renderer is installed, as the chat installs the real one.
    func testEngineFuzzEditedContent() throws {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        // After the driver is made: making it rebuilds the panel (`setBackend`), which drops a renderer
        // installed before.
        try self.runFuzz(contents: Self.editedStartingContents(), label: " (edited content)", prepare: { driver in
            HarnessEdited.installFormulaRenderer(on: driver.host)
        }, cleanUp: { driver in
            driver.host.panel.formulaRenderer = nil
        })
    }

    /// Seed 34, pinned (p14 fix sweep, 2026-09-24). It failed the WIDTH round trip once the table caret
    /// reveal landed: the host pass after a redo re-created a table measured the caret before the wrapper
    /// had placed the new cells, declined, and left the selection's end off screen, so the round trip's own
    /// passes revealed it and the layout "differed". Fixed by spending the reveal in the wrapper's layout
    /// pass (`placedRunCaretRevealOwed`). A shorter replay of its ops did not reproduce it, so the whole
    /// sequence (the default starting contents, 60 ops and the round trips) is the regression.
    @available(iOS 18.4, *)
    func testEngineFuzzSeed34WidthRoundTrip() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        XCTAssertTrue(self.runSequence(driver, seed: 34), "fuzz seed 34 failed (see the FUZZ FAILURE line above)")
    }

    @available(iOS 18.4, *)
    private func runFuzz(contents: [ChatInputContent], label: String, prepare: (EngineFuzzDriver) -> Void = { _ in }, cleanUp: (EngineFuzzDriver) -> Void = { _ in }) throws {
        let driver = try EngineFuzzDriver()
        prepare(driver)
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            cleanUp(driver)
            _ = driver.node.resignInputFirstResponder()
        }
        FuzzConfig.externalPushes = true
        FuzzConfig.lineOps = true
        FuzzConfig.keyWalks = true
        FuzzConfig.structuralOps = true
        FuzzConfig.chatInserts = true
        FuzzConfig.moves = true
        FuzzConfig.externalPastes = true
        FuzzConfig.undoRedos = true
        FuzzConfig.environments = true
        FuzzConfig.customInserts = true
        FuzzConfig.formatTypeOvers = true
        FuzzConfig.oneLineInserts = true
        FuzzConfig.chatMentions = true
        FuzzConfig.normalisingSets = true
        defer {
            FuzzConfig.normalisingSets = false
            FuzzConfig.chatMentions = false
            FuzzConfig.oneLineInserts = false
            FuzzConfig.formatTypeOvers = false
            FuzzConfig.customInserts = false
            FuzzConfig.undoRedos = false
            FuzzConfig.environments = false
            FuzzConfig.externalPastes = false
            FuzzConfig.moves = false
            FuzzConfig.chatInserts = false
            FuzzConfig.structuralOps = false
            FuzzConfig.externalPushes = false
            FuzzConfig.lineOps = false
            FuzzConfig.keyWalks = false
        }
        let seeds = FuzzConfig.effectiveSeeds
        let began = Date()
        var failures: [UInt64] = []
        for seed in seeds {
            if !self.runSequence(driver, seed: seed, contents: contents) {
                failures.append(seed)
            }
        }
        var known = ""
        if !FuzzKnownDefect.suppressed.isEmpty {
            known = ", known defects suppressed " + FuzzKnownDefect.suppressed.map { "\($0.key) x\($0.value)" }.sorted().joined(separator: " ")
            FuzzKnownDefect.suppressed = [:]
        }
        print("FUZZ SUMMARY \(driver.name)\(label): \(seeds.count) seeds x \(FuzzConfig.steps) ops, failing seeds \(failures)\(known), \(String(format: "%.1f", Date().timeIntervalSince(began))) s")
    }
}

/// p24 (2026-10-02): blocks holding content the editor normalises (or keeps although the send path cannot carry it)
/// on a set, for the `normalisingSet` op. The last two are the p23 kinds, reported since the p23 fix wave (controls).
enum FuzzNormalisingSet {
    static var blocks: [ChatInputBlock] {
        var bold = ChatInputInlineAttributes()
        bold.bold = true
        var monoMention = HarnessEdited.mention("Al").attributes
        monoMention.monospace = true
        return [
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let", attributes: bold), ChatInputRun(text: " x")])),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "x "), HarnessEdited.mention("Al")])),
            .code(ChatInputCode(language: "  swift ", runs: [ChatInputRun(text: "y")])),
            HarnessEngine.paragraph("ls\u{2028}sep"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "e "), HarnessEdited.emoji()])),
            HarnessEngine.paragraph("cr\r\nlf"),
            .code(ChatInputCode(language: "x\ny", runs: [ChatInputRun(text: "z")])),
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "m "), ChatInputRun(text: "Al", attributes: monoMention)])),
            // p24 fix wave: the rest of the line breaks the editor normalises on the way in.
            HarnessEngine.paragraph("ps\u{2029}x"),
            HarnessEngine.paragraph("nl\u{0085}x"),
            HarnessEngine.paragraph("cr\rx"),
        ]
    }
}

/// p20 (2026-09-30): rich content from other apps, for the `externalPaste` op. Each is built in-process
/// and WRITTEN to the pasteboard before a paste (never read first). Since the p20 fix wave the sources
/// also carry an image (RTFD), foreign colours and CR / CRLF line endings, which the engine's paste now
/// drops / takes the destination's / normalises (`HarnessExternalPasteImageAttachmentTests`,
/// `HarnessPastedForeignColourTests`, `HarnessPastedCarriageReturnTests`); the per-step invariants
/// (no bare `U+FFFC`, no storage the model cannot carry) check them.
enum FuzzExternalPaste {
    struct Source {
        let name: String
        let items: () -> [[String: Any]]
    }

    static func rtf(_ text: NSAttributedString, type: NSAttributedString.DocumentType = .rtf) -> Data {
        return (try? text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: type])) ?? Data()
    }

    static func styled() -> NSAttributedString {
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "Hello ", attributes: [.font: UIFont(name: "Georgia", size: 24) ?? UIFont.systemFont(ofSize: 24)]))
        text.append(NSAttributedString(string: "World", attributes: [.font: UIFont.boldSystemFont(ofSize: 30)]))
        text.append(NSAttributedString(string: " "))
        text.append(NSAttributedString(string: "ital", attributes: [.font: UIFont.italicSystemFont(ofSize: 12)]))
        text.append(NSAttributedString(string: " "))
        text.append(NSAttributedString(string: "site", attributes: [.link: URL(string: "https://example.com")!]))
        text.append(NSAttributedString(string: " "))
        text.append(NSAttributedString(string: "under", attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]))
        text.append(NSAttributedString(string: " "))
        text.append(NSAttributedString(string: "struck", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]))
        return text
    }

    /// An image between two words, as an RTFD from Notes / TextEdit carries it.
    static func withImage() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "pic ")
        let attachment = NSTextAttachment()
        attachment.image = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
        }
        text.append(NSAttributedString(attachment: attachment))
        text.append(NSAttributedString(string: " end"))
        return text
    }

    /// A word in a foreign colour on a highlight.
    static func coloured() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "tint ")
        text.append(NSAttributedString(string: "red", attributes: [.foregroundColor: UIColor.red, .backgroundColor: UIColor.yellow]))
        text.append(NSAttributedString(string: " done"))
        return text
    }

    static func multiline() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "Line one\nLine ", attributes: [.font: UIFont.systemFont(ofSize: 20)])
        text.append(NSAttributedString(string: "two", attributes: [.font: UIFont.boldSystemFont(ofSize: 20)]))
        text.append(NSAttributedString(string: "\n\nLine\u{2028}four\tTab\n漢字 مرحبا 😀"))
        return text
    }

    static let html = "<meta charset=\"utf-8\"><p>Para <b>bold</b> <i>it</i> <a href=\"https://example.com\">link</a></p><ul><li>one</li><li>two</li></ul><h1>Head</h1><blockquote>quoted</blockquote><pre>code line</pre><table><tr><td>a</td><td>b</td></tr></table>"

    static let sources: [Source] = [
        Source(name: "rtfStyled", items: { [["public.rtf": rtf(styled())]] }),
        Source(name: "rtfStyled+plain", items: { [["public.rtf": rtf(styled()), "public.utf8-plain-text": styled().string]] }),
        Source(name: "rtfMultiline", items: { [["public.rtf": rtf(multiline()), "public.utf8-plain-text": multiline().string]] }),
        Source(name: "rtfdText", items: { [["com.apple.flat-rtfd": rtf(styled(), type: .rtfd)]] }),
        Source(name: "htmlOnly", items: { [["public.html": html.data(using: .utf8) ?? Data()]] }),
        Source(name: "html+plain", items: { [["public.html": html.data(using: .utf8) ?? Data(), "public.utf8-plain-text": "Para bold it link\none\ntwo"]] }),
        Source(name: "url", items: { [["public.url": URL(string: "https://telegram.org/blog")!, "public.utf8-plain-text": "https://telegram.org/blog"]] }),
        Source(name: "twoTextItems", items: { [["public.utf8-plain-text": "first"], ["public.utf8-plain-text": "second"]] }),
        Source(name: "rtfdImage", items: { [["com.apple.flat-rtfd": rtf(withImage(), type: .rtfd)]] }),
        Source(name: "rtfColoured", items: { [["public.rtf": rtf(coloured())]] }),
        Source(name: "plainCRLF", items: { [["public.utf8-plain-text": "cr\r\nlf\rlone"]] }),
    ]
}
