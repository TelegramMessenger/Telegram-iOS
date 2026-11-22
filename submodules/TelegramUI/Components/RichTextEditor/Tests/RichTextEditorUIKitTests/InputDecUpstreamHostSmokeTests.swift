#if canImport(UIKit)
import XCTest
import UIKit
import CryptoKit
import RichTextInputDecUpstream

/// PHASE 1's EXIT CRITERION, and nothing more than that.
///
/// The claim under test is deliberately narrow: **upstream InputDec's real host exists in this tree,
/// stands up its whole object graph, becomes first responder, and accepts typed text.** Not that it
/// is integrated with Telegram's composer, not that it is wired to production, not that it is
/// feature-complete. `Sources/RichTextInputDecUpstream/PROVENANCE.md` says what came across and what
/// did not.
///
/// Why this test is worth its length: for the whole preceding programme this tree hosted a
/// *reconstruction* of InputDec inferred from its behavior kernel, and five rounds of hands-on
/// testing each found a fresh defect — a caret crash, a dead keyboard, a segfaulting backspace —
/// because ten call sites compiled cleanly and silently did nothing. So this test is written to fail
/// loudly at each construction step rather than to assert one aggregate at the end: if
/// `IDBlockTextView` were to come up half-built, the graph would still answer `hasText` plausibly.
///
/// It exercises the ported engine DIRECTLY. There is no adapter and no Telegram canvas in the path —
/// `RichTextEditorView` stays `.legacy` and `ExperimentalUISettings.inputDecTextBackend` stays
/// `false`; nothing here changes what a normal build does.
// `IDBlockTextView` and its collaborators are API_AVAILABLE(ios(18.4)) — the host app's iOS 15
// deployment floor forced that gate, since the class declares six properties in newer UIKit types
// with no annotations of their own. The gate is invisible to the Bazel app build, which does not
// compile this test target, so this annotation is what keeps the SwiftPM suite honest about it.
@available(iOS 18.4, *)
final class InputDecUpstreamHostSmokeTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeHost(_ strings: [String]) -> IDBlockTextView {
        // Upstream constructs its own test hosts exactly this way
        // (InputDec/Tests/IDBlockTextViewTests.m:325-342): a font and a colour on every block,
        // because IDBlockTextView seeds its typing attributes from the document defaults.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17.0),
            .foregroundColor: UIColor.label,
        ]
        let blocks = strings.map { NSAttributedString(string: $0, attributes: attributes) }
        let view = IDBlockTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                   attributedBlocks: blocks)
        view.isEditable = true
        view.isSelectable = true
        window.addSubview(view)
        view.layoutIfNeeded()
        return view
    }

    /// The whole graph stands up: the document, the canonical text storage adapter, the block stack,
    /// the rich-text layout controller, and the private input controller behind them.
    func test_theHostConstructsAndProjectsItsDocument() {
        let view = makeHost(["Hello"])

        XCTAssertEqual(view.attributedBlocks.count, 1)
        XCTAssertEqual(view.attributedBlocks[0].string, "Hello")
        // `text` is the CANONICAL projection (IDCanonicalTextProjection), not a block's string —
        // a dense axis with one "\n" per block boundary. With one block the two coincide, which is
        // why the two-block case below is the one that actually proves the axis.
        XCTAssertEqual(view.text, "Hello")

        // The UITextInput surface is live, and its positions are real objects rather than the
        // plausible nils that a half-built graph would hand back.
        let start = view.beginningOfDocument
        let end = view.endOfDocument
        XCTAssertEqual(view.offset(from: start, to: end), 5)
        XCTAssertEqual(view.text(in: view.textRange(from: start, to: end)!), "Hello")
        XCTAssertNotNil(view.tokenizer)
    }

    /// The dense canonical axis — the property PORT-PLAN §2.3.3 identifies as the fix for the
    /// position-defect class that surfaced three times wearing three symptoms. Our own reconstruction
    /// had a SPARSE axis whose `beginningOfDocument` was raw 1 rather than 0 and which had an
    /// unrenderable slot between regions (`Tests/DifferentialSupport/include/IDTelegramCharacterAxis.h`).
    /// Upstream's is a plain character count with a single "\n" per block boundary.
    func test_theCanonicalAxisIsDenseAcrossBlockBoundaries() {
        let view = makeHost(["ab", "cd"])

        XCTAssertEqual(view.text, "ab\ncd")
        XCTAssertEqual(view.offset(from: view.beginningOfDocument, to: view.endOfDocument), 5)

        // Every offset in [0, 5] must mint a position, including the boundary slot at 2.
        for offset in 0...5 {
            XCTAssertNotNil(view.position(from: view.beginningOfDocument, offset: offset),
                            "no position at canonical offset \(offset) — the axis has a hole")
        }
        let boundary = view.position(from: view.beginningOfDocument, offset: 2)!
        XCTAssertEqual(view.compare(boundary, to: view.beginningOfDocument), .orderedDescending)
        XCTAssertEqual(view.compare(boundary, to: view.endOfDocument), .orderedAscending)
    }

    /// **The phase-1 exit criterion.** First responder, then a typed character, then the document
    /// contains it.
    func test_theHostBecomesFirstResponderAndAcceptsTypedText() {
        let view = makeHost(["Hello"])

        XCTAssertTrue(view.canBecomeFirstResponder)
        XCTAssertTrue(view.becomeFirstResponder())
        XCTAssertTrue(view.isFirstResponder)

        // Type at the end of the document, the way the keyboard does.
        view.selectedTextRange = view.textRange(from: view.endOfDocument, to: view.endOfDocument)
        XCTAssertTrue(view.hasText)
        view.insertText("!")

        XCTAssertEqual(view.attributedBlocks[0].string, "Hello!",
                       "the typed character did not reach the DOCUMENT — the host accepted it and dropped it")
        XCTAssertEqual(view.text, "Hello!")
        XCTAssertEqual(view.offset(from: view.beginningOfDocument, to: view.endOfDocument), 6)

        // The caret followed the insertion rather than staying put.
        let caret = view.selectedTextRange
        XCTAssertNotNil(caret)
        XCTAssertEqual(view.offset(from: view.beginningOfDocument, to: caret!.start), 6)
        XCTAssertTrue(caret!.isEmpty)
    }

    /// Typing more than one character, and deleting — because a host can accept exactly one insertion
    /// and then desynchronise its storage adapter from its block document, which is a failure shape
    /// a single `insertText` cannot see.
    func test_typingAndDeletingStayInSyncWithTheDocument() {
        let view = makeHost(["ab"])
        XCTAssertTrue(view.becomeFirstResponder())
        view.selectedTextRange = view.textRange(from: view.endOfDocument, to: view.endOfDocument)

        for character in ["c", "d", "e"] {
            view.insertText(character)
        }
        XCTAssertEqual(view.attributedBlocks[0].string, "abcde")

        view.deleteBackward()
        XCTAssertEqual(view.attributedBlocks[0].string, "abcd")
        XCTAssertEqual(view.text, "abcd")
        XCTAssertEqual(view.offset(from: view.beginningOfDocument, to: view.endOfDocument), 4)
        XCTAssertTrue(view.hasText)
    }

    /// The vendored behavior kernel and the ported engine are two separate modules whose archives
    /// link into ONE image, and one class name collided: `IDInteractionABISpec`, defined both in the
    /// ported `IDPrivateUIKit.m` and in the vendor-owned carve `TGRichTextInputDecHostPreflight.m`
    /// that was cut out of that very file. Because both land in the same image it is a duplicate
    /// `_OBJC_CLASS_$_` symbol at LINK time — the build simply fails — which is why deviation 2
    /// renames one side with `objc_runtime_name`. (An earlier version of this comment claimed the
    /// opposite, that it would fail quietly at runtime. It would not; it never links.)
    ///
    /// The link error means this test cannot exist unless the rename already worked, so what it adds
    /// is narrower and worth stating: that the rename landed on the PORT's class and left the
    /// vendored one alone. Both must still be present, under their two different names.
    func test_thePortedEngineDoesNotShadowTheVendoredKernelsCarvedClass() {
        XCTAssertNotNil(NSClassFromString("IDUpstreamInteractionABISpec"),
                        "the ported IDPrivateUIKit's ABI-spec class is missing its runtime rename")
        XCTAssertNotNil(NSClassFromString("IDInteractionABISpec"),
                        "the vendored carve's class disappeared — the rename was applied to the wrong side")
    }

    // MARK: - The runtime contract gate

    /// **This is the test that stops every other test in this file from being vacuous.**
    ///
    /// `IDBlockTextView`'s reference construction path begins with `requireCompatibleRuntime`, which
    /// walks `IDRequiredContracts()` — built from a manifest upstream reads as a bundle RESOURCE.
    /// That resource does not exist anywhere in this tree, so before deviation 5 the lookup returned
    /// nil, the dictionary degraded to `@{}`, and the loop iterated **zero** rows: the gate passed
    /// because it had nothing to check, on all ten capabilities. Every "the host stood up" result
    /// in this file was collected with upstream's own safety check silently switched off.
    ///
    /// `compatibilityReport` prints the count it actually preflighted, so the vacuity is directly
    /// observable. Asserting it is non-zero is what makes the other four tests mean something.
    func test_theRuntimeContractGateActuallyChecksSomething() {
        let report = IDPrivateUIKit.compatibilityReport
        let marker = "Required selector contracts preflighted: "
        guard let range = report.range(of: marker) else {
            return XCTFail("compatibilityReport no longer prints the preflight count:\n\(report)")
        }
        let digits = report[range.upperBound...].prefix { $0.isNumber }
        guard let count = Int(digits) else {
            return XCTFail("could not read the preflight count:\n\(report)")
        }
        XCTAssertGreaterThan(count, 0,
            "the runtime gate is iterating ZERO contracts — it passes because it checks nothing")

        // Pinned, not merely non-zero. 140 is derived from the embedded manifest by upstream's own
        // rule (IDRequiredContracts: the `capabilities` + `referenceOnly` members, minus kind
        // "protocol", keeping `required` == true) — 180 members, 179 contracts, 140 required. A
        // pin catches the regression a `> 0` cannot: re-pointing this at the transformed manifest
        // next door leaves the count above zero while silently dropping referenceOnly's 53 rows.
        XCTAssertEqual(count, 140)
        XCTAssertTrue(IDPrivateUIKit.isCompatible,
                      "required contracts are missing on this OS:\n\(report)")
    }

    /// The manifest the gate reads must be upstream's OWN, not the transformed copy next door.
    ///
    /// `Generated/TGRichTextInputDecContractData.m` is the same manifest put through the export
    /// script, which rewrites 50 member `class` bindings onto Telegram stand-in classes and empties
    /// `referenceOnly`. One of those rewrites —
    /// `inputController.keyboardDeletePreflight`, `IDBlockTextView` → `TGRichTextInputDecCanvasABIWitness`
    /// — sits inside the exact capability the input-controller preflight reads, so feeding the gate
    /// the transformed data would validate `keyboardInputShouldDelete:` on a class the ported engine
    /// never instantiates. It would pass, for the wrong reason. That is this programme's signature
    /// failure and the reason the port carries the pristine bytes instead.
    func test_theGateReadsUpstreamsOwnManifestAndNotTheRewrittenOne() {
        let data = TGRichTextInputDecUpstreamPristineContractJSON()

        // Byte-for-byte upstream. This hash is `Vendor/VENDOR.md`'s "pristine manifest SHA-256",
        // so a hand-edit to the generated blob fails here.
        XCTAssertEqual(data.count, 118_270)
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                       "a60bb026db345de4c487b45661f97f41e05c1270d1d2c7f5f58d5d92b5440e43")

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("the embedded manifest does not parse")
        }

        // referenceOnly survives — the export script drops all 53 of these rows.
        let referenceOnly = root["referenceOnly"] as? [String: Any] ?? [:]
        let referenceOnlyMembers = referenceOnly.values
            .compactMap { ($0 as? [String: Any])?["members"] as? [[String: Any]] }
            .reduce(0) { $0 + $1.count }
        XCTAssertEqual(referenceOnlyMembers, 53, "referenceOnly was emptied — this is the export copy")

        // And the binding the rewrite would have moved still names the real host.
        let capabilities = root["capabilities"] as? [String: Any] ?? [:]
        let inputController = capabilities["inputController"] as? [String: Any] ?? [:]
        let members = inputController["members"] as? [[String: Any]] ?? []
        let preflight = members.first { $0["identifier"] as? String == "inputController.keyboardDeletePreflight" }
        XCTAssertEqual(preflight?["class"] as? String, "IDBlockTextView",
            "keyboardDeletePreflight is bound to a stand-in class — the gate would validate the wrong object")
        XCTAssertEqual(preflight?["name"] as? String, "keyboardInputShouldDelete:")
    }

    /// The anchor exists so the module carries a symbol on macOS, where all 78 ported files compile
    /// to nothing. Its literal answer is not interesting; that it RESOLVES is.
    func test_thePortedModuleIsLinked() {
        XCTAssertGreaterThan(TGRichTextInputDecUpstreamPortedFileCount(), 0)
    }
}
#endif
