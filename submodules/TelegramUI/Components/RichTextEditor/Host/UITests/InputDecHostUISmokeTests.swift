import XCTest

/// **The other half of task PORT-PLAN §7.5's question.**
///
/// §7.5's negative branch bundles two tranches: T3 (the ~200 pixel-reading unit methods, which
/// need an app-HOSTED unit target) and T6 (the 196 UI-tier methods, which need an XCUITest target
/// against a launchable app). `IDHostedMarkerPixelExperimentTests` settled T3. This settles T6's
/// precondition — **§9.8's unknown #2, "is there any `ios_ui_test` precedent in this repo at all?",
/// to which the answer was no** — by being one.
///
/// It is deliberately thin. It does not port an upstream UI test; it establishes that an XCUITest
/// target can be built and run in this repo, that the host app launches out of process, and that
/// its editor is reachable through the accessibility tree — the three things a T6 port would
/// otherwise discover the hard way, ten suites in. What it finds about reachability is recorded in
/// the assertions themselves rather than in a comment, so a change of answer is a failure.
final class InputDecHostUISmokeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The app launches out of process and shows its chrome.
    func test_theHostAppLaunchesAndShowsItsArms() {
        let app = XCUIApplication()
        app.launch()

        let arms = app.segmentedControls["host.arm"]
        XCTAssertTrue(arms.waitForExistence(timeout: 20),
                      "the host app did not present its arm control within 20s — it either failed "
                      + "to launch or died during launch. `IDBlockTextView`'s `+load` runs before "
                      + "`main()` and can @throw uncaught; a launch failure here is the first place "
                      + "that would show.")
        XCTAssertTrue(app.buttons["InputDec"].exists, "the InputDec arm is missing")
        XCTAssertTrue(app.buttons["Legacy"].exists, "the Legacy control arm is missing")
        XCTAssertTrue(app.buttons["Raw engine"].exists, "the raw-engine arm is missing")
        XCTAssertTrue(app.buttons["Stock"].exists, "the Stock oracle arm is missing")

        let status = app.staticTexts["host.status"]
        XCTAssertTrue(status.exists, "the status line is missing")
        XCTAssertTrue(status.label.contains("IDDocumentCanvasView"),
                      "the launched app is NOT on the InputDec canvas: \(status.label)")
    }

    /// Typing through the real keyboard, out of process — which is what the whole UI tier is for.
    ///
    /// This is the assertion that says whether tranche T6 can drive the engine at all. If the
    /// canvas is not reachable through the accessibility tree, an XCUITest can render and screenshot
    /// the app but cannot *type* into it, and every autocorrect / IME / keyboard-behaviour suite in
    /// T6 would need a different mechanism (upstream's own `IDHIDEventTestSupport.m` synthesises HID
    /// events for exactly this reason).
    func test_theEngineCanBeTypedIntoThroughTheAccessibilityTree() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.segmentedControls["host.arm"].waitForExistence(timeout: 20))

        let editor = app.otherElements["host.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "the editor container is not in the tree")
        editor.tap()

        // A keyboard appearing is itself the finding: it means the canvas took the responder role
        // out of process, which is the "dead keyboard" defect's inverse and was found by hand once.
        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10),
                      "tapping the editor raised NO keyboard. Tranche T6 cannot drive this engine "
                      + "through XCUITest's typing API; it would need synthesised HID events, the "
                      + "way upstream's IDHIDEventTestSupport.m does.")

        // A marker no seed paragraph contains, so finding it in the dump cannot be a coincidence.
        let marker = "qzx"
        app.typeText(marker)

        // Read the state back through the host's own Dump button rather than through the canvas.
        // The canvas may expose no readable accessibility value — and asserting on a value that is
        // always empty is exactly the vacuous test this programme keeps producing. `Dump` prints the
        // canvas's own `text(in:)` projection into the log view, so this reads the DOCUMENT.
        app.buttons["Dump"].tap()
        let violations = app.textViews["host.violations"]
        XCTAssertTrue(violations.waitForExistence(timeout: 5))
        let dump = try? XCTUnwrap(violations.value as? String)
        XCTAssertNotNil(dump, "the log view exposes no value, so the dump cannot be read back")
        XCTAssertTrue(dump?.contains("canvas text:") == true,
                      "the dump did not reach the canvas projection: \(dump ?? "<nil>")")
        XCTAssertTrue(dump?.contains(marker) == true,
                      "text typed through the REAL KEYBOARD, out of process, did not reach the "
                      + "engine's document. This is the strongest single claim this file makes, and "
                      + "it is the one tranche T6 depends on. dump=\(dump ?? "<nil>")")
    }
}
