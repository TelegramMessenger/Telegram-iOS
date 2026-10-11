#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// A minimal `RichTextInputHost` whose `hostInputView` is INJECTABLE — unlike the shared
/// `Tests/…/Fakes/FakeInputHost.swift`, which conforms to `LegacyRichTextInputHost` and always
/// constructs its own fixed `legacyCanvas: DocumentCanvasView`. These tests need to swap between
/// a legacy canvas (to prove the wrong-canvas-class throw) and an `IDDocumentCanvasView` (to
/// prove attach succeeds) — a shape `FakeInputHost` cannot provide, and widening it to accept an
/// injected view is not this task's file to edit (`FakeInputLifecycleClient.swift`'s one additive
/// property is the ONLY sanctioned change to a stage-1 fake here).
///
/// Wires the SAME six fakes `FakeInputHost`/`IncompatibleFakeHost` use (`Tests/…/Fakes/*`), so
/// `RichTextInputEventLog`'s cross-client ordering assertions (`.kinds`, `.index(of:)`) work
/// identically. Deliberately `private` and local to this file: it conforms only to the base
/// `RichTextInputHost` (mirrors `IncompatibleFakeHost`'s shape, not `FakeInputHost`'s
/// `LegacyRichTextInputHost` refinement — the ID backend narrows on `IDDocumentCanvasView`, never
/// `LegacyRichTextInputHost`), and no `BackendContractCases` subclass exists for it, so it is
/// out of scope for the source-boundary R10/R11 fixture-construction rules (both scan only
/// `BackendContractCases` descendants — see `InputBackendSourceBoundaryTests.swift`).
@MainActor
@available(iOS 16.0, *)
private final class IDFakeInputHost: RichTextInputHost {
    let log: RichTextInputEventLog
    let hostInputView: UIView

    let fakeDocumentClient: FakeInputDocumentClient
    let fakeGeometryClient: FakeInputGeometryClient
    let fakeAnnotationClient: FakeInputAnnotationClient
    let fakePresentationClient: FakeInputPresentationClient
    let fakeLifecycleClient: FakeInputLifecycleClient
    let fakeCommandClient: FakeInputCommandClient

    init(hostInputView: UIView) {
        let log = RichTextInputEventLog()
        self.log = log
        self.hostInputView = hostInputView
        self.fakeDocumentClient = FakeInputDocumentClient(log: log)
        self.fakeGeometryClient = FakeInputGeometryClient(log: log)
        self.fakeAnnotationClient = FakeInputAnnotationClient(log: log)
        self.fakePresentationClient = FakeInputPresentationClient(log: log)
        self.fakeLifecycleClient = FakeInputLifecycleClient(log: log)
        self.fakeCommandClient = FakeInputCommandClient(log: log)
    }

    var documentClient: any RichTextInputDocumentClient { fakeDocumentClient }
    var geometryClient: any RichTextInputGeometryClient { fakeGeometryClient }
    var annotationClient: any RichTextInputAnnotationClient { fakeAnnotationClient }
    var presentationClient: any RichTextInputPresentationClient { fakePresentationClient }
    var lifecycleClient: any RichTextInputLifecycleClient { fakeLifecycleClient }
    var commandClient: any RichTextInputCommandClient { fakeCommandClient }
}

/// Task C0's attach/detach contract suite for `IDTextEditorBackend`.
///
/// RENAMED BY TASK C3 (2026-08-25): this class was originally `IDBackendAttachDetachTests`
/// (Task C0). Task C3's own Step 7 must create a class of exactly that name — the stage-1
/// `BackendAttachDetachTests` subclass, per Decision 10's "ID<StageOneClassName>" convention
/// shared by all eight contract subclasses — and a same-module top-level class cannot share a
/// name with this one. The two test genuinely different things (this file is ID-backend
/// WHITE-BOX attach mechanics: wrong-canvas-class throw, already-attached preservation, residue
/// freedom, idempotent detach, detach ordering, weak host retention, and the renamed-class
/// resolution proof; the stage-1 suite is the BACKEND-NEUTRAL protocol contract run through the
/// shared fake-client harness), so both suites are kept — this one is renamed rather than
/// deleted or folded in, since folding it into `IDBackendAttachDetachTests: BackendAttachDetachTests`
/// would either lose these ID-specific assertions (that base class's body must name no concrete
/// backend) or violate stage 1's rule that a subclass adds nothing beyond `makeBackend()`. See
/// `task-C3-report.md` for the full reasoning. Gated on `isSupported()`
/// exactly like `IsSupportedTests`/B6's suite (see that file's own doc comment on why this is
/// TRANSITION-SAFE rather than a way to dodge a real failure): `incomingCallbacks` is a single
/// MANDATORY capability whose manifest marks all 47 rows `required`, and this task's Step 3
/// deliberately implements only 5 of them (the connection/teardown group — see
/// `TGRichTextInputDecLayoutController.h`'s Task-C0-scope note), so `isSupported()` is expected to
/// still answer FALSE after this commit lands, and every test below is expected to SKIP on this
/// runtime. See `task-C0-report.md` for the measured answer and the reasoning.
///
/// DEVIATION FROM THE BRIEF: the brief's illustrative Step-1 snippet writes `FakeInputHost(
/// hostInputView:)` and reads `host.lifecycle`/`host.presentation` — names that do not exist on
/// this package's actual `FakeInputHost` (`init(log:)` only, always its own fixed `legacyCanvas`,
/// and the real members are `fakeLifecycleClient`/`fakePresentationClient`). Adapted to
/// `IDFakeInputHost` (above) and the real fake-client property names
/// (`didAttachCallCount`/`publishedStates`/`applyCallCount`/`tearDownCallCount`) — the test
/// INTENT (what each assertion proves) is unchanged from the brief.
@available(iOS 17.0, *)
@MainActor
final class IDBackendAttachAtomicityTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend is not supported on this runtime")
    }

    func test_attachToALegacyCanvas_throwsIncompatibleHost() {
        let host = IDFakeInputHost(hostInputView: DocumentCanvasView())
        let backend = IDTextEditorBackend()
        XCTAssertThrowsError(try backend.attach(to: host)) { error in
            guard case RichTextInputBackendAttachmentError.incompatibleHost = error else {
                return XCTFail("expected .incompatibleHost, got \(error)")
            }
        }
        XCTAssertFalse(backend.isAttached)
    }

    func test_attachSucceedsOnTheIDCanvas_andPublishesInitialState() throws {
        let host = IDFakeInputHost(hostInputView: IDDocumentCanvasView())
        let backend = IDTextEditorBackend()
        try backend.attach(to: host)
        XCTAssertTrue(backend.isAttached)
        XCTAssertEqual(host.fakeLifecycleClient.didAttachCallCount, 1)
        XCTAssertEqual(host.fakeLifecycleClient.publishedStates.count, 1)
    }

    func test_attachTwice_throwsAlreadyAttached_andPreservesTheFirstAttachment() throws {
        let host = IDFakeInputHost(hostInputView: IDDocumentCanvasView())
        let backend = IDTextEditorBackend()
        try backend.attach(to: host)
        XCTAssertThrowsError(try backend.attach(to: host))
        XCTAssertTrue(backend.isAttached)
        XCTAssertEqual(host.fakeLifecycleClient.didAttachCallCount, 1)
    }

    /// Residue is asserted after a failure the ID attach path ACTUALLY HAS. `attach(to:)` has
    /// exactly four failure modes — wrong canvas class, nil manifest, thunk-install failure,
    /// kernel construction failure — and none of them is a host-side flag, so a
    /// `host.failingCapability = "geometry"` would simply attach successfully and the
    /// assertions below would all be false. The wrong-canvas-class throw is the one reachable
    /// without touching the vendored kernel, and it is thrown BEFORE anything is constructed,
    /// which is exactly the atomicity claim being made.
    func test_attachFailureLeavesNoResidue() {
        let idCanvas = IDDocumentCanvasView()
        let host = IDFakeInputHost(hostInputView: DocumentCanvasView())   // not an ID canvas
        let backend = IDTextEditorBackend()
        XCTAssertThrowsError(try backend.attach(to: host))
        XCTAssertFalse(backend.isAttached)
        XCTAssertEqual(host.fakeLifecycleClient.didAttachCallCount, 0)
        XCTAssertEqual(host.fakeLifecycleClient.publishedStates.count, 0)
        XCTAssertEqual(host.fakePresentationClient.applyCallCount, 0)
        XCTAssertEqual(host.fakePresentationClient.tearDownCallCount, 0)
        // No bridge was associated with ANY ID canvas — including one that exists but was
        // never the host's input view.
        XCTAssertNil(TGRichTextInputDecAttachedBridge(idCanvas))
    }

    func test_detachIsIdempotentAndClearsTheAssociatedBridge() throws {
        let canvas = IDDocumentCanvasView()
        let host = IDFakeInputHost(hostInputView: canvas)
        let backend = IDTextEditorBackend()
        try backend.attach(to: host)
        XCTAssertNotNil(TGRichTextInputDecAttachedBridge(canvas))
        backend.detach()
        let eventsAfterFirstDetach = host.log.events.count
        backend.detach()
        XCTAssertEqual(host.log.events.count, eventsAfterFirstDetach)
        XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
        XCTAssertFalse(backend.isAttached)
    }

    func test_detachOrder_matchesTheSpecifiedSequence() throws {
        let host = IDFakeInputHost(hostInputView: IDDocumentCanvasView())
        let backend = IDTextEditorBackend()
        try backend.attach(to: host)
        host.log.reset()
        backend.detach()
        let kinds = host.log.kinds
        XCTAssertEqual(kinds.last, "lifecycleWillDetach",
                       "backendWillDetach must be the last thing detach does")
        XCTAssertLessThan(try XCTUnwrap(host.log.index(of: "presentationTearDown")),
                          try XCTUnwrap(host.log.index(of: "lifecycleWillDetach")))
    }

    func test_backendRetainsHostWeakly() throws {
        var host: IDFakeInputHost? = IDFakeInputHost(hostInputView: IDDocumentCanvasView())
        weak var probe = host   // `weak let` does not compile: weak requires a mutable variable
        let backend = IDTextEditorBackend()
        try backend.attach(to: XCTUnwrap(host))
        backend.detach()
        host = nil
        XCTAssertNil(probe)
    }

    /// The other half of the rename claim. `ContractManifestTests` proved the 47
    /// `incomingCallbacks` rows NAME `TGRichTextInputDecLayoutController`; this proves the class
    /// exists under that name. `IDUIKitCapabilityResolver.evaluateContract:` looks it up with
    /// NSClassFromString and fails the whole MANDATORY capability on nil, so both halves are
    /// required for `isSupported()` ever to answer true — though not SUFFICIENT: the manifest
    /// marks all 47 rows required, and this task implements only 5 (see this file's own
    /// doc comment), so `incomingCallbacks` stays rejected on a different, narrower ground now.
    func test_layoutControllerResolvesUnderTheRenamedManifestName() {
        XCTAssertNotNil(NSClassFromString("TGRichTextInputDecLayoutController"))
    }

    /// The exception guard is not decorative: `activeController` raises on any witness call
    /// after detach (IDUIKitInputControllerCapability.m:228+), and Swift cannot catch it.
    func test_aWitnessCallAfterDetachDoesNotRaise() throws {
        let host = IDFakeInputHost(hostInputView: IDDocumentCanvasView())
        let backend = IDTextEditorBackend()
        try backend.attach(to: host)
        backend.detach()
        // Must return the documented "absent" value, not crash the test process.
        XCTAssertNil(backend.state.markedRange)
        XCTAssertFalse(backend.isAttached)
    }
}
#endif
