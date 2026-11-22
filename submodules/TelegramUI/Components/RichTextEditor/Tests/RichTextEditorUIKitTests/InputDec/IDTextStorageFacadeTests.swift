#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Exercises `TGRichTextInputDecTextStorageFacade` directly, against a hand-written fake bridge —
/// NOT `IDTextEditorBackendClientBridge` (which needs a real `attach(to:)`, and therefore a
/// successfully-constructed kernel, which cannot happen on this runtime: `incomingCallbacks` stays
/// mandatory-rejected until Task C14). The façade itself has NO dependency on the kernel at all —
/// only on `bridge: id<TGRichTextInputDecClientBridging>` — so this is a genuine, UNGATED, real
/// runtime exercise of the class's own four overridden `NSTextStorage` primitives, unlike every
/// `IDFakeClientHarness`/`makeBackendHarness(backend: .inputDec)`-based Family-4 test in this
/// package, which is gated on `IDTextEditorBackend.isSupported()` (false on every runtime available
/// here) and therefore compiles but never actually RUNS.
///
/// Each assertion below is written so it would FAIL if the corresponding override were deleted:
/// `NSTextStorage`'s own abstract implementation of `replaceCharactersInRange:withString:` /
/// `setAttributes:range:` / `string` / `attributesAtIndex:effectiveRange:` raises
/// `NSInternalInconsistencyException` ("method only defined for abstract class") rather than
/// returning a value or reaching `bridge` at all, so a missing override traps the process before any
/// assertion below could even run — the strongest possible non-vacuity signal available for an
/// abstract-class override.
@available(iOS 13.0, *)
final class IDTextStorageFacadeTests: XCTestCase {

    /// Records every call and answers a scripted outcome — completely independent of
    /// `IDTextEditorBackend`/the kernel/`attach(to:)`.
    final class FakeFacadeBridge: NSObject, TGRichTextInputDecClientBridging {
        func textStorageFacade() -> NSTextStorage { NSTextStorage() }
        func canvasKeyboardInputShouldDelete() -> Bool { true }

        var applies = true
        var outcomeRevision: UInt64 = 7
        private(set) var receivedRanges: [NSRange] = []
        private(set) var receivedTexts: [String] = []
        private(set) var receivedIntents: [TGRichTextInputDecIntent] = []
        private(set) var receivedExpectedRevisions: [UInt64] = []
        private(set) var callCount = 0

        func prepareAndCommitReplacement(
            in range: NSRange, text: String, intent: TGRichTextInputDecIntent,
            expectedRevision: UInt64,
            outOutcome: UnsafeMutablePointer<TGRichTextInputDecMutationOutcome>) -> Bool {
            callCount += 1
            receivedRanges.append(range)
            receivedTexts.append(text)
            receivedIntents.append(intent)
            receivedExpectedRevisions.append(expectedRevision)
            if applies {
                outOutcome.pointee = TGRichTextInputDecMutationOutcome(
                    revision: outcomeRevision, selectionAnchor: 0, selectionHead: 0)
            }
            return applies
        }
    }

    @MainActor
    func test_replaceCharacters_forwardsRangeTextIntentAndRevision_toTheBridge() {
        let facade = TGRichTextInputDecTextStorageFacade()
        let bridge = FakeFacadeBridge()
        // Rejected: this test is only about what the façade FORWARDS to the bridge, not the
        // resulting mirror mutation (that is `test_anAppliedTransaction_...` below) — an applied
        // transaction against an empty mirror at a non-zero range would be a genuinely out-of-bounds
        // mutation, unrelated to what this test asserts.
        bridge.applies = false
        facade.bridge = bridge
        facade.revision = 3
        facade.currentIntent = .deleteBackward

        facade.replaceCharacters(in: NSRange(location: 2, length: 1), with: "")

        XCTAssertEqual(bridge.callCount, 1)
        XCTAssertEqual(bridge.receivedRanges, [NSRange(location: 2, length: 1)])
        XCTAssertEqual(bridge.receivedTexts, [""])
        XCTAssertEqual(bridge.receivedIntents, [.deleteBackward])
        XCTAssertEqual(bridge.receivedExpectedRevisions, [3])
    }

    /// Would fail if `replaceCharactersInRange:withString:` did not mutate `mirror`, or mutated it
    /// unconditionally rather than gating on `applied`.
    @MainActor
    func test_anAppliedTransaction_mutatesTheMirror_andAdoptsTheOutcomeRevision() {
        let facade = TGRichTextInputDecTextStorageFacade()
        let bridge = FakeFacadeBridge()
        bridge.applies = true
        bridge.outcomeRevision = 42
        facade.bridge = bridge

        facade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "hi")

        XCTAssertEqual(facade.string, "hi")
        XCTAssertEqual(facade.revision, 42)
    }

    /// Would fail if the override applied the mirror mutation before consulting the bridge's
    /// return value, or forgot to leave `revision` untouched on rejection.
    @MainActor
    func test_aRejectedTransaction_leavesTheMirrorAndRevisionUntouched() {
        let facade = TGRichTextInputDecTextStorageFacade()
        let bridge = FakeFacadeBridge()
        bridge.applies = false
        facade.bridge = bridge
        facade.revision = 5

        facade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "hi")

        XCTAssertEqual(facade.string, "")
        XCTAssertEqual(facade.revision, 5)
    }

    /// The single-transaction latch: reset to `.programmatic` regardless of whether the bridge
    /// applied the change. Would fail if the reset were only reached on the `applied` path (an
    /// early `return` before the reset, rather than after it).
    @MainActor
    func test_theIntentLatch_resetsAfterATransaction_appliedOrRejected() {
        let facade = TGRichTextInputDecTextStorageFacade()
        let bridge = FakeFacadeBridge()
        facade.bridge = bridge

        bridge.applies = true
        facade.currentIntent = .insertText
        facade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a")
        XCTAssertEqual(facade.currentIntent, .programmatic)

        bridge.applies = false
        facade.currentIntent = .deleteBackward
        facade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "")
        XCTAssertEqual(facade.currentIntent, .programmatic)
    }

    /// Would fail if `setAttributes:range:` routed through the bridge at all (it must not — see the
    /// façade's own doc comment: attribute-only edits carry no semantic intent Telegram's document
    /// model consumes).
    @MainActor
    func test_setAttributes_neverCallsTheBridge() {
        let facade = TGRichTextInputDecTextStorageFacade()
        let bridge = FakeFacadeBridge()
        facade.bridge = bridge
        facade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "abc")
        XCTAssertEqual(bridge.callCount, 1)

        facade.setAttributes([.foregroundColor: UIColor.red], range: NSRange(location: 0, length: 3))

        XCTAssertEqual(bridge.callCount, 1, "an attribute-only edit must not reach the bridge")
        XCTAssertEqual(facade.attributes(at: 0, effectiveRange: nil)[.foregroundColor] as? UIColor,
                       UIColor.red)
    }

    /// Task D4c — a bridge that also answers the three document-read members
    /// `synchronizeMirrorWithDocumentIfNeeded` consults, so this suite can exercise that method's
    /// two exit paths. `FakeFacadeBridge` above deliberately implements only the two `@required`
    /// members (that is load-bearing for the tests that use it — see
    /// `replaceCharactersInRange:withString:`'s own `respondsToSelector:` note), so this is a
    /// SEPARATE double rather than three more optional members on that one.
    ///
    /// `@objc(documentPlainTextInRange:)` is NOT optional decoration: Swift's implicit `@objc`
    /// inference silently fails for exactly this signature shape on an `@optional` protocol
    /// requirement — the production `IDTextEditorBackendClientBridge` carries the identical
    /// annotation for the identical reason (Task R3's own fix), and without it this double's
    /// `respondsToSelector:` check fails and the whole sync is skipped.
    final class FakeDocumentReadingBridge: NSObject, TGRichTextInputDecClientBridging {
        func textStorageFacade() -> NSTextStorage { NSTextStorage() }
        func canvasKeyboardInputShouldDelete() -> Bool { true }

        var plainText = ""
        var currentRevision: UInt64 = 0

        func documentUTF16Length() -> Int { plainText.utf16.count }
        func documentRevision() -> UInt64 { currentRevision }

        @objc(documentPlainTextInRange:)
        func documentPlainText(inRange range: NSRange) -> String? {
            let utf16 = Array(plainText.utf16)
            let location = min(max(range.location, 0), utf16.count)
            let length = min(range.length, utf16.count - location)
            return String(decoding: utf16[location..<(location + length)], as: UTF16.self)
        }
    }

    /// **The mechanism-level pin for Task D4c's silent-no-op fix, at the smallest layer that can
    /// hold it — and UNGATED, unlike every `isSupported()`-gated `.inputDec` suite.**
    ///
    /// An ATTRIBUTE-ONLY document change (a bold toggle) moves the document revision without moving
    /// a character, so this sync finds `mirror.string` already equal to the document's text and
    /// takes its "already in sync" fast path. That path must still adopt the new revision into
    /// `revision` — the baseline every kernel-driven mutation hands
    /// `prepareAndCommitReplacementInRange:…expectedRevision:`, which the document client compares
    /// for EXACT equality. Before the fix it adopted only the private `_lastSyncedBridgeRevision`
    /// tracker, leaving `revision` one behind, and the next `deleteBackward()`/`setMarkedText`
    /// transaction was rejected `.revisionMismatch` — silently, because
    /// `TelegramLifecycleInputClient.backendDidRejectMutation` has an empty body.
    @MainActor
    func test_anAttributeOnlyRevisionBump_isAdoptedIntoTheMutationBaseline() {
        let facade = TGRichTextInputDecTextStorageFacade()
        let bridge = FakeDocumentReadingBridge()
        bridge.plainText = "AB"
        bridge.currentRevision = 1
        facade.bridge = bridge

        // First read: the mirror is empty, so this takes the CONTENT-DIFFERS rebuild path, which
        // has always adopted the revision. Establishing this first is what makes the assertion
        // below non-vacuous — the bug only shows once the mirror is genuinely in sync.
        XCTAssertEqual(facade.string, "AB")
        XCTAssertEqual(facade.revision, 1)

        // The attribute-only change: revision moves, not one character does.
        bridge.currentRevision = 2

        XCTAssertEqual(facade.string, "AB", "no character moved, so the mirror must not change")
        XCTAssertEqual(facade.revision, 2,
                       "the 'already in sync' path must still adopt the new revision — it is the "
                       + "baseline the next kernel-driven mutation declares, and a stale one is "
                       + "rejected as revisionMismatch with no diagnostic of any kind")
    }

    /// `string`/`attributesAtIndex:effectiveRange:` read through `mirror`. Would fail if either
    /// primitive were missing (abstract-class trap) or read from anywhere else.
    @MainActor
    func test_stringAndAttributesReads_reflectTheMirror() {
        let facade = TGRichTextInputDecTextStorageFacade()
        facade.mirror.replaceCharacters(in: NSRange(location: 0, length: 0), with: "xyz")
        XCTAssertEqual(facade.string, "xyz")
        var range = NSRange(location: 0, length: 0)
        _ = facade.attributes(at: 1, effectiveRange: &range)
        XCTAssertEqual(range, NSRange(location: 0, length: 3))
    }
}
#endif
