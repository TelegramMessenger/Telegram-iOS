#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `RichTextInputEventRecorder` (used by the never-notifies-the-delegate test) is `@available(iOS 16.0, *)`,
/// so the whole class carries that floor — a plain superset restriction on a suite that otherwise only
/// exercises the `iOS 13.0` client/canvas.
@available(iOS 16.0, *)
@MainActor
final class TelegramAnnotationInputClientTests: XCTestCase {
    private func makeClient(_ texts: [String] = ["hello wrold today"], width: CGFloat = 300)
        -> (DocumentCanvasView, TelegramAnnotationInputClient) {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 400); v.layoutIfNeeded()
        return (v, TelegramAnnotationInputClient(canvas: v))
    }

    // MARK: annotatedSubstring

    /// Delegates verbatim to the existing controller-facing callback — no new translation.
    func test_annotatedSubstringMatchesTheExistingClientCallback() {
        let (v, c) = makeClient(["Alpha Beta"])
        let s = v.boxes[0].textStart
        let range = NSRange(location: s, length: 5)
        let witnessRange = v.nativeTextRange(forGlobalLocation: s, length: 5)!
        let witness = v.annotatedSubstring(for: witnessRange)
        let viaClient = c.annotatedSubstring(in: range, revision: v.documentRevision)
        XCTAssertEqual(viaClient?.string, witness?.string)
        XCTAssertEqual(viaClient?.string, "Alpha")
    }

    /// TASK H2 — **this test's expectation is INVERTED, deliberately, and the inversion is the fix.**
    ///
    /// It used to assert `XCTAssertNil(...)` for a stale revision, pinning a hard
    /// `guard revision == canvas.documentRevision` on every member of this client. That gate has no
    /// counterpart upstream: `IDRichTextLayoutController.m:1369-1374` CLIPS an incoming range into
    /// the document as it currently stands and has no staleness concept at all. It also rejected
    /// precisely the deliveries it existed to protect — a correction annotation is by nature
    /// delivered AFTER the replacement that bumped the revision, and the revision it is compared
    /// against is read RAW off the incoming range, deliberately un-rebased
    /// (`TGRichTextInputDecLayoutController.m:151-162`). Recorded as G2 row F5 / suspect 3.
    ///
    /// The safety the gate appeared to provide is provided by the clamps that have to be there
    /// anyway — see this client's own header. Nothing here can write outside the current document.
    func test_aStaleRevisionIsNoLongerRejected_itClipsIntoTheCurrentDocument() {
        let (v, c) = makeClient(["Alpha"])
        let s = v.boxes[0].textStart
        XCTAssertEqual(c.annotatedSubstring(in: NSRange(location: s, length: 1),
                                            revision: v.documentRevision &- 1)?.string, "A")
        // The clamp, not the gate, is what keeps a stale range safe. A range past the end of the
        // document cannot WRITE anything: `clampedSpellRegionLocal` refuses it, at any revision.
        // (The read above answers `""` for such a range and always has — `annotatedSubstring` is
        // `text(in:) ?? ""` — which is a pre-existing shape this task did not change.)
        XCTAssertFalse(c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                                       range: NSRange(location: v.documentSizeValue + 50, length: 3),
                                       revision: v.documentRevision &- 1))
        XCTAssertNil(v.spellResults[BlockID("p0")])
    }

    // MARK: addAnnotation / annotationValue / removeAnnotation

    /// Presence first: flag "wrold" as `.spelling`, confirm the block's `spellResults` entry actually
    /// gained the LOCAL range before anything else is asserted.
    func test_addAnnotationFlagsTheRangeInSpellResults() {
        let (v, c) = makeClient(["hello wrold today"])
        let blockID = BlockID("p0")
        let s = v.boxes[0].textStart
        let wrongWordGlobal = NSRange(location: s + 6, length: 5)   // "wrold", region-local {6,5}
        XCTAssertNil(v.spellResults[blockID], "no annotation must exist yet, or the gain below is vacuous")

        let ok = c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                                 range: wrongWordGlobal, revision: v.documentRevision)
        XCTAssertTrue(ok)
        let entry = v.spellResults[blockID]
        XCTAssertNotNil(entry, "spellResults must gain an entry for the owning block")
        XCTAssertTrue(entry!.ranges.contains { $0.range == NSRange(location: 6, length: 5) && $0.style == .spelling })
    }

    func test_removeAnnotationClearsIt() {
        let (v, c) = makeClient(["hello wrold today"])
        let blockID = BlockID("p0")
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        XCTAssertTrue(c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                                      range: wordGlobal, revision: v.documentRevision))
        XCTAssertTrue(v.spellResults[blockID]?.ranges.contains { $0.range == NSRange(location: 6, length: 5) } ?? false,
                     "the flag must actually be present, or the clearing assertion below is vacuous")

        let ok = c.removeAnnotation(key: "spelling", range: wordGlobal, revision: v.documentRevision)
        XCTAssertTrue(ok)
        XCTAssertFalse(v.spellResults[blockID]?.ranges.contains { $0.range == NSRange(location: 6, length: 5) } ?? false)
    }

    func test_annotationsDoNotBumpTheDocumentRevision() {
        let (v, c) = makeClient(["hello wrold today"])
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        let revisionBefore = v.documentRevision
        c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                        range: wordGlobal, revision: v.documentRevision)
        c.removeAnnotation(key: "spelling", range: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(v.documentRevision, revisionBefore, "annotation ops must never move the document content revision")
    }

    func test_annotationsBumpTheLayoutGeneration_soRenderingIsInvalidated() {
        let (v, c) = makeClient(["hello wrold today"])
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        let before = v.layoutGeneration
        c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                        range: wordGlobal, revision: v.documentRevision)
        XCTAssertGreaterThan(v.layoutGeneration, before, "a successful annotation must bump layoutGeneration")
    }

    /// TASK H2 — inverted for the reason recorded on
    /// `test_aStaleRevisionIsNoLongerRejected_itClipsIntoTheCurrentDocument` above. A correction flag
    /// arrives one revision late by construction; rejecting it is rejecting the flag.
    func test_addAnnotationAtAStaleRevisionNowLands() {
        let (v, c) = makeClient(["hello wrold today"])
        let blockID = BlockID("p0")
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        let layoutBefore = v.layoutGeneration

        let ok = c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                                 range: wordGlobal, revision: v.documentRevision &- 1)
        XCTAssertTrue(ok)
        XCTAssertTrue(v.spellResults[blockID]?.ranges.contains {
            $0.range == NSRange(location: 6, length: 5) && $0.style == .spelling
        } ?? false)
        XCTAssertNotEqual(v.layoutGeneration, layoutBefore)
    }

    /// TASK H2 — G1/G2's ranked suspect 1: `addAnnotation` used to require a Swift
    /// `DocumentCanvasView.SpellStyle` value, which the layout controller never sends, so it was a
    /// constant `false`. It now classifies the payload the controller ACTUALLY sends — a boxed
    /// integer under the private display-style key — through the canvas's own classifier.
    func test_addAnnotationClassifiesTheBoxedDisplayStyleTheControllerActuallySends() {
        let (v, c) = makeClient(["hello wrold today"])
        let blockID = BlockID("p0")
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)

        let ok = c.addAnnotation(key: DocumentCanvasView.displayStyleKey.rawValue,
                                 value: NSNumber(value: 2),
                                 range: wordGlobal, revision: v.documentRevision)
        XCTAssertTrue(ok, "a boxed display style is the payload the controller sends; refusing it is "
                      + "the whole of suspect 1")
        XCTAssertTrue(v.spellResults[blockID]?.ranges.contains {
            $0.range == NSRange(location: 6, length: 5) && $0.style == .spelling
        } ?? false)
    }

    /// The negative half of the test above — without it, "we accept the controller's payload" would
    /// be indistinguishable from "we accept anything", and a genuinely unrelated annotation key
    /// would silently paint a spelling underline.
    func test_addAnnotationStillRefusesAPayloadThatDenotesNoMarker() {
        let (v, c) = makeClient(["hello wrold today"])
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        XCTAssertFalse(c.addAnnotation(key: "nonsense-key", value: "nonsense-value",
                                       range: wordGlobal, revision: v.documentRevision))
        XCTAssertNil(v.spellResults[BlockID("p0")])
    }

    /// TASK H2 — G1/G2's ranked suspect 2: `addRenderingAttributes` whitelisted two keys that are
    /// not the underline, so the ONE delivery shape upstream's end-to-end test names — bare
    /// `NSUnderlineStyle` / `NSUnderlineColor` temporary rendering attributes — fell through to
    /// `return false`. It now reaches `spellResults`, which is what this renderer's underline
    /// overlay draws from.
    func test_addRenderingAttributesAcceptsTheTemporaryUnderlineMarker() {
        let (v, c) = makeClient(["hello wrold today"])
        let blockID = BlockID("p0")
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)

        let ok = c.addRenderingAttributes([.underlineStyle: NSNumber(value: NSUnderlineStyle.thick.rawValue),
                                           .underlineColor: UIColor.red],
                                          range: wordGlobal, revision: v.documentRevision)
        XCTAssertTrue(ok)
        XCTAssertTrue(v.spellResults[blockID]?.ranges.contains {
            $0.range == NSRange(location: 6, length: 5) && $0.style == .spelling
        } ?? false)

        // …and removal is symmetric, which the two-key whitelist never was.
        XCTAssertTrue(c.removeRenderingAttributes([.underlineStyle], range: wordGlobal,
                                                  revision: v.documentRevision))
        XCTAssertTrue(v.spellResults[blockID]?.ranges.isEmpty ?? true)
    }

    /// The marker never reaches the canonical document model — the invariant upstream asserts
    /// alongside its pixel test (`XCTAssertNil(canonical[NSUnderlineStyleAttributeName])`) and the
    /// one that matters most: a marker written into the model would travel into the message the
    /// user sends.
    func test_theTemporaryUnderlineMarkerNeverEntersTheDocumentModel() {
        let (v, c) = makeClient(["hello wrold today"])
        let s = v.boxes[0].textStart
        XCTAssertTrue(c.addRenderingAttributes([.underlineStyle: NSNumber(value: 1)],
                                               range: NSRange(location: s + 6, length: 5),
                                               revision: v.documentRevision))
        let underlinedInModel = v.currentParagraphs().contains { paragraph in
            paragraph.runs.contains { $0.attributes.underline }
        }
        XCTAssertFalse(underlinedInModel, "the spelling marker must never reach canonical storage")
    }

    func test_annotationValueForAnUnknownKeyIsNil() {
        let (v, c) = makeClient(["hello world today"])   // no misspelling seeded
        let s = v.boxes[0].textStart
        let value = c.annotationValue(for: "nonsense-key", at: .downstream(s + 6), revision: v.documentRevision)
        XCTAssertNil(value)
    }

    func test_annotationValueReadsBackTheStoredStyle() {
        let (v, c) = makeClient(["hello wrold today"])
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        XCTAssertTrue(c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                                      range: wordGlobal, revision: v.documentRevision))
        let value = c.annotationValue(for: "spelling", at: .downstream(s + 7), revision: v.documentRevision)
        XCTAssertEqual(value as? DocumentCanvasView.SpellStyle, .spelling)
    }

    // MARK: addRenderingAttributes / removeRenderingAttributes

    func test_addRenderingAttributesAcceptsOnlyTheTwoRecognizedKeys() {
        let (v, c) = makeClient(["Alpha Beta"])
        let s = v.boxes[0].textStart
        let region = v.allLeafRegions()[0]

        let ghostBefore = region.layout.renderVersion
        let ghostOK = c.addRenderingAttributes([.richTextInputGhostForeground: UIColor.gray],
                                               range: NSRange(location: s, length: 2), revision: v.documentRevision)
        XCTAssertTrue(ghostOK)
        XCTAssertNotEqual(region.layout.renderVersion, ghostBefore,
                          "ghost foreground must actually reach the layout engine, or this is a stub")

        let spoilerBefore = region.layout.renderVersion
        let spoilerOK = c.addRenderingAttributes([.richTextInputSpoilerHidden: true],
                                                  range: NSRange(location: s + 3, length: 2), revision: v.documentRevision)
        XCTAssertTrue(spoilerOK)
        XCTAssertNotEqual(region.layout.renderVersion, spoilerBefore,
                          "spoiler-hidden must actually reach the layout engine, or this is a stub")

        let foreignBefore = region.layout.renderVersion
        let foreignOK = c.addRenderingAttributes([.foregroundColor: UIColor.red],
                                                  range: NSRange(location: s, length: 2), revision: v.documentRevision)
        XCTAssertFalse(foreignOK, "an unrecognized key must be refused, not silently applied")
        XCTAssertEqual(region.layout.renderVersion, foreignBefore, "a refused call must not touch the layout engine")
    }

    func test_removeRenderingAttributesUndoesTheGhostForeground() {
        let (v, c) = makeClient(["Alpha Beta"])
        let s = v.boxes[0].textStart
        let region = v.allLeafRegions()[0]

        let before = region.layout.renderVersion
        XCTAssertTrue(c.addRenderingAttributes([.richTextInputGhostForeground: UIColor.gray],
                                               range: NSRange(location: s, length: 2), revision: v.documentRevision))
        let afterAdd = region.layout.renderVersion
        XCTAssertNotEqual(afterAdd, before, "the ghost must actually be applied, or the undo assertion below is vacuous")

        let ok = c.removeRenderingAttributes([.richTextInputGhostForeground],
                                             range: NSRange(location: s, length: 2), revision: v.documentRevision)
        XCTAssertTrue(ok)
        // `setGhostForeground` bumps `renderVersion` on every call (add or clear) — a second, distinct bump
        // proves the underlying engine call was actually made a second time (the clear), which is the
        // strongest signal available: the applied color itself is engine-private state this seam does not expose.
        XCTAssertNotEqual(region.layout.renderVersion, afterAdd, "removing must invoke the engine again to clear it")
    }

    /// Symmetric with `test_addRenderingAttributesAcceptsOnlyTheTwoRecognizedKeys`'s foreign-key case:
    /// a refused call must not reach the layout engine either. `setGhostForeground` bumps `renderVersion`
    /// UNCONDITIONALLY on both set AND clear (`BlockLayout.swift:305-312`), so an unchanged `renderVersion`
    /// is real evidence no engine call was made, not just a coincidence of the assertion's shape.
    func test_removeRenderingAttributesRejectsAnUnrecognizedKey() {
        let (v, c) = makeClient(["Alpha Beta"])
        let s = v.boxes[0].textStart
        let region = v.allLeafRegions()[0]
        let before = region.layout.renderVersion

        let ok = c.removeRenderingAttributes([.foregroundColor], range: NSRange(location: s, length: 2),
                                             revision: v.documentRevision)
        XCTAssertFalse(ok)
        XCTAssertEqual(region.layout.renderVersion, before, "a refused call must not touch the layout engine")
    }

    // MARK: invalidateTemporaryAttributes

    func test_invalidateTemporaryAttributesMarksTheUnderlineOverlaysDirty() {
        let (v, c) = makeClient(["Alpha Beta"])
        v.selectionHighlight.layer.displayIfNeeded()
        XCTAssertFalse(v.selectionHighlight.layer.needsDisplay(),
                      "setup must leave no pending redraw, or the assertion below is vacuous")

        let s = v.boxes[0].textStart
        c.invalidateTemporaryAttributes(in: NSRange(location: s, length: 1), revision: v.documentRevision)
        XCTAssertTrue(v.selectionHighlight.layer.needsDisplay(),
                     "invalidateTemporaryAttributes must mark the underline overlay dirty")
    }

    // MARK: never touches selection or the input delegate

    /// Snapshots `(anchor, head)` across every member — none of the seven may move it.
    func test_annotationClientNeverChangesTheSelection() {
        let (v, c) = makeClient(["hello wrold today"])
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s + 2, head: s + 2)
        let wordGlobal = NSRange(location: s + 6, length: 5)

        func selection() -> [Int] { [v.anchor, v.head] }
        let expected = selection()

        _ = c.annotatedSubstring(in: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
        _ = c.annotationValue(for: "spelling", at: .downstream(s + 7), revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
        c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                       range: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
        c.addRenderingAttributes([.richTextInputGhostForeground: UIColor.gray], range: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
        c.removeRenderingAttributes([.richTextInputGhostForeground], range: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
        c.invalidateTemporaryAttributes(in: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
        c.removeAnnotation(key: "spelling", range: wordGlobal, revision: v.documentRevision)
        XCTAssertEqual(selection(), expected)
    }

    /// Attaches the shared golden-trace recorder as the canvas's `UITextInputDelegate` (and the four
    /// canvas hooks) and asserts NONE of the seven members produce a single recorded event — the
    /// annotation client must never call `UITextInputDelegate` nor any content/selection notification.
    func test_annotationClientNeverSendsDelegateNotifications() {
        let (v, c) = makeClient(["hello wrold today"])
        let recorder = RichTextInputEventRecorder()
        recorder.attach(canvas: v)
        recorder.reset()
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)

        _ = c.annotatedSubstring(in: wordGlobal, revision: v.documentRevision)
        _ = c.annotationValue(for: "spelling", at: .downstream(s + 7), revision: v.documentRevision)
        c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                       range: wordGlobal, revision: v.documentRevision)
        c.addRenderingAttributes([.richTextInputGhostForeground: UIColor.gray], range: wordGlobal, revision: v.documentRevision)
        c.removeRenderingAttributes([.richTextInputGhostForeground], range: wordGlobal, revision: v.documentRevision)
        c.invalidateTemporaryAttributes(in: wordGlobal, revision: v.documentRevision)
        c.removeAnnotation(key: "spelling", range: wordGlobal, revision: v.documentRevision)

        XCTAssertTrue(recorder.events.isEmpty,
                      "the annotation client must never notify the delegate or fire a content/selection hook:\n\(recorder.trace())")
    }

    // MARK: D17 — annotation ranges are a side table edits do NOT shift (deliberate, pinned)

    /// Pins deviation D17 (`DCV:486-488`): the flagged range is stored in REGION-LOCAL UTF-16 and is
    /// never rebased when an earlier edit in the same region shifts the real text. This asserts TODAY'S
    /// wrong-looking behavior ON PURPOSE — do not "fix" this test by making the range track the edit;
    /// that is exactly the behavior change D17 forbids for this seam.
    func test_annotationRangesDoNotShiftAcrossAnEdit() {
        let (v, c) = makeClient(["hello wrold today"])
        let blockID = BlockID("p0")
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)   // "wrold", region-local {6,5}
        XCTAssertTrue(c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                                      range: wordGlobal, revision: v.documentRevision))
        XCTAssertTrue(v.spellResults[blockID]?.ranges.contains { $0.range == NSRange(location: 6, length: 5) } ?? false,
                     "the flag must actually be present at {6,5}, or the pin below is vacuous")

        // A real edit BEFORE the flagged word that would shift it under a correct (rebasing) implementation.
        v.setSelectionForTesting(anchor: s, head: s)
        v.insertText("XX ")   // "XX hello wrold today" — "wrold" is now 3 UTF-16 units further along

        // DCV:486-488: the side table does NOT shift. The stored range is STILL {6,5} — now pointing at
        // "hel" + part of "lo " rather than "wrold". This is the accepted staleness, not a bug to fix here.
        XCTAssertTrue(v.spellResults[blockID]?.ranges.contains { $0.range == NSRange(location: 6, length: 5) } ?? false,
                     "D17: the stored range must stay put at the OLD offset even though the real text moved")
    }

    // MARK: D29 — the annotation client emits no presentation invalidation

    @MainActor
    private final class InvalidationRecorder: RichTextInputPresentationClient {
        private(set) var invalidations: [RichTextInputPresentationInvalidation] = []
        let containerView = UIView()
        var interactionContainerView: UIView { containerView }
        var visibleBounds: CGRect { .zero }
        func apply(_ snapshot: RichTextInputPresentationSnapshot) {}
        func invalidate(_ invalidation: RichTextInputPresentationInvalidation) { invalidations.append(invalidation) }
        func requestReveal(_ target: RichTextInputRevealTarget, animated: Bool) {}
        func dismissEditMenu(reason: RichTextInputEditMenuDismissReason) {}
        func tearDownPresentation() {}
    }

    /// Pins deviation D29. The spec wants a successful visual change to invalidate `.annotations` or
    /// `.spelling` through the backend's presentation client. This client emits NONE — it bumps
    /// `layoutGeneration` and calls `setNeedsSpellUnderlineDisplay()` directly on the canvas it already
    /// holds, exactly like the legacy path always has. There is no invalidation bus between the
    /// annotation client and the presentation client today, and routing one through would add an
    /// observable presentation pass that does not exist.
    ///
    /// HONEST NOTE on what `recorder.invalidations.isEmpty` actually proves: it is a STRUCTURAL
    /// guarantee, not a runtime one. `TelegramAnnotationInputClient.init(canvas:)` takes no
    /// `RichTextInputPresentationClient`, and nothing on `DocumentCanvasView` holds or forwards to one
    /// (grepped: zero hits for `presentationClient` under `Canvas/` or `InputBackend/Clients/`) — so no
    /// change to any of the seven method bodies could ever make this recorder non-empty; the client has
    /// no reference through which to reach it. This test therefore DOCUMENTS the absence of an
    /// invalidation channel rather than GUARDING against one being wired up later — it can only go red
    /// via a compile-breaking signature change (e.g. `init` gaining a presentation-client parameter), at
    /// which point it needs rewriting anyway, not a silent regression catch. The `layoutGeneration`
    /// half below IS a real, checked behavioral assertion (a genuine visual-invalidation probe) —
    /// only the `invalidations.isEmpty` half is the documentation-not-guard case.
    func test_annotationClientEmitsNoPresentationInvalidation() {
        let (v, c) = makeClient(["hello wrold today"])
        let recorder = InvalidationRecorder()
        let s = v.boxes[0].textStart
        let wordGlobal = NSRange(location: s + 6, length: 5)
        let layoutBefore = v.layoutGeneration

        _ = c.annotatedSubstring(in: wordGlobal, revision: v.documentRevision)
        _ = c.annotationValue(for: "spelling", at: .downstream(s + 7), revision: v.documentRevision)
        c.addAnnotation(key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
                       range: wordGlobal, revision: v.documentRevision)
        c.addRenderingAttributes([.richTextInputGhostForeground: UIColor.gray], range: wordGlobal, revision: v.documentRevision)
        c.removeRenderingAttributes([.richTextInputGhostForeground], range: wordGlobal, revision: v.documentRevision)
        c.invalidateTemporaryAttributes(in: wordGlobal, revision: v.documentRevision)
        c.removeAnnotation(key: "spelling", range: wordGlobal, revision: v.documentRevision)

        XCTAssertGreaterThan(v.layoutGeneration, layoutBefore,
                             "the probe must actually cause visual invalidation (layoutGeneration must move), or D29 is untested")
        // Structurally guaranteed, not runtime-guarded: `recorder` is never wired to `c`/`v` by any
        // production path, so this half documents the absence of a channel rather than guarding one.
        XCTAssertTrue(recorder.invalidations.isEmpty, "D29: the annotation client must emit zero presentation invalidations")
        withExtendedLifetime((v, c)) {}
    }
}
#endif
