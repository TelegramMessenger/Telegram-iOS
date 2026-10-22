import XCTest

/// Tier 2: real touches on the real chat bubbles, read back through `harness.readout`.
final class WidgetHarnessUITests: XCTestCase {
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// The readout is a label: a static text whose value is the whole readout.
    private func readout(_ app: XCUIApplication) -> String {
        let element = app.staticTexts["harness.readout"]
        guard element.exists else {
            return ""
        }
        return (element.value as? String) ?? ""
    }

    /// Waits until the readout satisfies `condition`, for at most `timeout` seconds; returns the last readout.
    @discardableResult
    private func waitForReadout(_ app: XCUIApplication, timeout: TimeInterval = 20.0, _ condition: (String) -> Bool) -> String {
        let deadline = Date(timeIntervalSinceNow: timeout)
        var value = self.readout(app)
        while !condition(value) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
            value = self.readout(app)
        }
        return value
    }

    /// The centre of the first bubble whose line contains `path`, in the app's coordinates.
    private func centre(of path: String, in readout: String) -> CGVector? {
        guard let line = readout.split(separator: "\n").first(where: { $0.hasPrefix("bubble ") && $0.contains(path) }),
              let at = line.split(separator: " ").first(where: { $0.hasPrefix("@") }) else {
            return nil
        }
        let numbers = at.dropFirst().split(separator: ",").compactMap { Double($0) }
        return numbers.count == 2 ? CGVector(dx: numbers[0], dy: numbers[1]) : nil
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    func testATapOnAWidgetButtonOpensTheLinkPrompt() throws {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "open-link"])
        let ready = self.waitForReadout(app) { $0.contains("open-link.html") && $0.contains(" widget") }
        let point = try XCTUnwrap(self.centre(of: "open-link", in: ready), ready)
        app.coordinate(withNormalizedOffset: .zero).withOffset(point).press(forDuration: 0.1)
        let after = self.waitForReadout(app, timeout: 5.0) { $0.contains("openLink https://example.org/harness") }
        XCTAssertTrue(after.contains("openLink https://example.org/harness"), after)
        XCTAssertFalse(after.contains("(not concealed)"), after)
    }

    /// A long press on something the widget handles is the widget's, as on a message button (the user, 2026-10-22; sdk-v1
    /// §5.5 gives every long press to the bubble): no context menu, and lifting the finger clicks.
    func testALongPressOnAButtonIsTheWidgets() throws {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "open-link"])
        let ready = self.waitForReadout(app) { $0.contains("open-link.html") && $0.contains(" widget") }
        let point = try XCTUnwrap(self.centre(of: "open-link", in: ready), ready)
        app.coordinate(withNormalizedOffset: .zero).withOffset(point).press(forDuration: 1.2)
        let after = self.waitForReadout(app, timeout: 5.0) { $0.contains("openLink") }
        self.attachScreenshot(app, "after the long press")
        XCTAssertTrue(after.contains("openLink https://example.org/harness"), after)
        XCTAssertFalse(after.contains("contextMenu"), after)
    }

    /// A bubble line's size (`<w>x<h>`) and centre for `path`.
    private func bubble(_ path: String, in readout: String) -> (size: String, centre: CGVector)? {
        guard let line = readout.split(separator: "\n").first(where: { $0.hasPrefix("bubble ") && $0.contains(path) }),
              let centre = self.centre(of: path, in: readout) else {
            return nil
        }
        let fields = line.split(separator: " ")
        return fields.count > 3 ? (String(fields[3]), centre) : nil
    }

    /// The drag fixture (the last post, so on screen at the chat's newest end) laid out with its widget running: #free is
    /// its top 100 pt, #claim (touch-action: none) the next 100 pt, #pany (touch-action: pan-y) the last 100 pt.
    private struct DragFixture {
        let app: XCUIApplication
        let ready: String
        let free: XCUICoordinate
        let claim: XCUICoordinate
        let pany: XCUICoordinate
    }

    private func launchDrag() throws -> DragFixture {
        let app = self.launch(["-widget-set", "fixture"])
        let ready = self.waitForReadout(app) { $0.contains("touch-drag.html") && $0.contains(" widget") }
        let widget = try XCTUnwrap(self.bubble("touch-drag.html", in: ready), ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let top = widget.centre.dy - (size.count == 2 ? size[1] : 300.0) / 2.0
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let point = { (offset: Double) in origin.withOffset(CGVector(dx: widget.centre.dx, dy: top + offset)) }
        return DragFixture(app: app, ready: ready, free: point(50.0), claim: point(150.0), pany: point(250.0))
    }

    /// Waits for the drag fixture's widget to report a size other than it had in `before` (its first pointermove), at most
    /// 5 s; returns the last readout.
    private func waitForDragFixtureToGrow(_ app: XCUIApplication, from before: String) -> String {
        let size = self.bubble("touch-drag.html", in: before)?.size
        return self.waitForReadout(app, timeout: 5.0) { value in
            self.bubble("touch-drag.html", in: value).map { $0.size != size } ?? false
        }
    }

    /// How far the bubble above the drag fixture's (text.html) moved between two readouts: the list's scroll.
    private func listMovement(from before: String, to after: String) -> Double? {
        guard let a = self.centre(of: "fixture/text.html", in: before), let b = self.centre(of: "fixture/text.html", in: after) else {
            return nil
        }
        return abs(Double(b.dy - a.dy))
    }

    /// sdk-v1 §5.5: a drag on a part of a widget that claims nothing is the chat's. Vertically the list scrolls.
    func testAVerticalDragOnAWidgetScrollsTheChat() throws {
        let fixture = try self.launchDrag()
        let before = try XCTUnwrap(self.bubble("touch-drag.html", in: fixture.ready), fixture.ready)
        // Downwards, to older messages: the chat opens at its newest end.
        fixture.free.press(forDuration: 0.05, thenDragTo: fixture.free.withOffset(CGVector(dx: 0.0, dy: 200.0)))
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            guard let moved = self.bubble("touch-drag.html", in: value) else {
                return true
            }
            return abs(moved.centre.dy - before.centre.dy) > 50.0
        }
        self.attachScreenshot(fixture.app, "after a vertical drag on #free")
        let moved = self.bubble("touch-drag.html", in: after)
        XCTAssertTrue(moved == nil || abs(moved!.centre.dy - before.centre.dy) > 50.0, after)
    }

    /// sdk-v1 §5.5: horizontally, a drag on a part of a widget that claims nothing swipes the bubble to reply. The
    /// bubble's long press is armed over a widget, and the swipe beginning must take the touch from it (the menu opened
    /// mid-swipe on the CoreList chat until the swipe cancelled the long press).
    func testAHorizontalDragOnAWidgetSwipesToReply() throws {
        let fixture = try self.launchDrag()
        fixture.free.press(forDuration: 0.05, thenDragTo: fixture.free.withOffset(CGVector(dx: -160.0, dy: 0.0)))
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("reply fixture/touch-drag.html") }
        self.attachScreenshot(fixture.app, "after a horizontal drag on #free")
        XCTAssertTrue(after.contains("reply fixture/touch-drag.html"), after)
        XCTAssertFalse(after.contains("contextMenu"), after)
    }

    /// sdk-v1 §5.5: to the right, a drag on a part that claims nothing is the chat's back swipe (the root's stand-in).
    func testARightwardDragOnAWidgetSwipesBack() throws {
        let fixture = try self.launchDrag()
        fixture.free.press(forDuration: 0.05, thenDragTo: fixture.free.withOffset(CGVector(dx: 160.0, dy: 0.0)))
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.split(separator: "\n").contains("back") }
        XCTAssertTrue(after.split(separator: "\n").contains("back"), after)
    }

    /// sdk-v1 §5.5: touch-action: none claims both axes. A vertical drag is the widget's (its first pointermove grows it)
    /// and the list holds still.
    func testAClaimedVerticalDragHoldsTheList() throws {
        let fixture = try self.launchDrag()
        fixture.claim.press(forDuration: 0.05, thenDragTo: fixture.claim.withOffset(CGVector(dx: 0.0, dy: 150.0)))
        let after = self.waitForDragFixtureToGrow(fixture.app, from: fixture.ready)
        self.attachScreenshot(fixture.app, "after a vertical drag on #claim")
        XCTAssertNotEqual(self.bubble("touch-drag.html", in: after)?.size, self.bubble("touch-drag.html", in: fixture.ready)?.size, after)
        let movement = try XCTUnwrap(self.listMovement(from: fixture.ready, to: after), after)
        XCTAssertLessThan(movement, 30.0, after)
        XCTAssertFalse(after.contains("contextMenu"), after)
    }

    /// sdk-v1 §5.5: horizontally, a claimed drag is the widget's too: neither swipe-to-reply nor the back swipe takes it.
    func testAClaimedHorizontalDragIsTheWidgets() throws {
        let fixture = try self.launchDrag()
        fixture.claim.press(forDuration: 0.05, thenDragTo: fixture.claim.withOffset(CGVector(dx: 160.0, dy: 0.0)))
        let afterRight = self.waitForDragFixtureToGrow(fixture.app, from: fixture.ready)
        XCTAssertNotEqual(self.bubble("touch-drag.html", in: afterRight)?.size, self.bubble("touch-drag.html", in: fixture.ready)?.size, afterRight)
        fixture.claim.press(forDuration: 0.05, thenDragTo: fixture.claim.withOffset(CGVector(dx: -160.0, dy: 0.0)))
        Thread.sleep(forTimeInterval: 1.0)
        let after = self.readout(fixture.app)
        self.attachScreenshot(fixture.app, "after horizontal drags on #claim")
        XCTAssertFalse(after.split(separator: "\n").contains("back"), after)
        XCTAssertFalse(after.contains("reply fixture/touch-drag.html"), after)
        XCTAssertFalse(after.contains("contextMenu"), after)
    }

    /// A slow drag reaches the back swipe's 2 pt before the widget's own drag begins (4 pt), so the back swipe must already
    /// know the press's claim when the touch goes down, which is before the widget's recognizer sees it.
    func testASlowClaimedDragDoesNotSwipeBack() throws {
        let fixture = try self.launchDrag()
        fixture.claim.press(forDuration: 0.05, thenDragTo: fixture.claim.withOffset(CGVector(dx: 120.0, dy: 0.0)), withVelocity: XCUIGestureVelocity(40.0), thenHoldForDuration: 0.1)
        let after = self.waitForDragFixtureToGrow(fixture.app, from: fixture.ready)
        self.attachScreenshot(fixture.app, "after a slow drag on #claim")
        XCTAssertNotEqual(self.bubble("touch-drag.html", in: after)?.size, self.bubble("touch-drag.html", in: fixture.ready)?.size, after)
        XCTAssertFalse(after.split(separator: "\n").contains("back"), after)
    }

    /// sdk-v1 §5.5: touch-action: pan-y claims horizontal drags only: a horizontal drag is the widget's, a vertical one
    /// scrolls the list.
    func testAPanYPartTakesOnlyHorizontalDrags() throws {
        let fixture = try self.launchDrag()
        fixture.pany.press(forDuration: 0.05, thenDragTo: fixture.pany.withOffset(CGVector(dx: -160.0, dy: 0.0)))
        let afterHorizontal = self.waitForDragFixtureToGrow(fixture.app, from: fixture.ready)
        XCTAssertNotEqual(self.bubble("touch-drag.html", in: afterHorizontal)?.size, self.bubble("touch-drag.html", in: fixture.ready)?.size, afterHorizontal)
        Thread.sleep(forTimeInterval: 1.0)
        let settled = self.readout(fixture.app)
        XCTAssertFalse(settled.contains("reply fixture/touch-drag.html"), settled)
        let pany = try XCTUnwrap(self.bubble("touch-drag.html", in: settled), settled)
        let size = pany.size.split(separator: "x").compactMap { Double($0) }
        let point = fixture.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: pany.centre.dx, dy: pany.centre.dy - (size.count == 2 ? size[1] : 310.0) / 2.0 + 250.0))
        point.press(forDuration: 0.05, thenDragTo: point.withOffset(CGVector(dx: 0.0, dy: 200.0)))
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            (self.listMovement(from: settled, to: value) ?? 1000.0) > 50.0
        }
        self.attachScreenshot(fixture.app, "after a vertical drag on #pany")
        XCTAssertGreaterThan(self.listMovement(from: settled, to: after) ?? 1000.0, 50.0, after)
    }

    /// A part that claims drags is one the widget handles: holding it before dragging opens no menu.
    func testALongPressOnAClaimedPartIsTheWidgets() throws {
        let fixture = try self.launchDrag()
        fixture.claim.press(forDuration: 1.2)
        Thread.sleep(forTimeInterval: 1.0)
        let after = self.readout(fixture.app)
        XCTAssertFalse(after.contains("contextMenu"), after)
    }

    /// The double-tap fixture laid out with its widget running: #button is its top 100 pt, #empty the next 100 pt.
    private func launchDoubleTap() throws -> (app: XCUIApplication, button: XCUICoordinate, empty: XCUICoordinate) {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "double-tap"])
        let ready = self.waitForReadout(app) { $0.contains("double-tap.html") && $0.contains(" widget") }
        let widget = try XCTUnwrap(self.bubble("double-tap.html", in: ready), ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let top = widget.centre.dy - (size.count == 2 ? size[1] : 200.0) / 2.0
        let origin = app.coordinate(withNormalizedOffset: .zero)
        return (app, origin.withOffset(CGVector(dx: widget.centre.dx, dy: top + 50.0)),
                origin.withOffset(CGVector(dx: widget.centre.dx, dy: top + 150.0)))
    }

    /// sdk-v1 §5.5: a double tap on a part of a widget that handles nothing is the bubble's quick reaction.
    func testADoubleTapOnAnEmptyPartIsTheBubblesReaction() throws {
        let fixture = try self.launchDoubleTap()
        fixture.empty.doubleTap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("reaction fixture/double-tap.html") }
        self.attachScreenshot(fixture.app, "after the double tap")
        XCTAssertTrue(after.contains("reaction fixture/double-tap.html"), after)
        XCTAssertFalse(after.contains("openLink"), after)
    }

    /// Where the widget handles nothing, a long press is the bubble's context menu, and lifting the finger after it opened
    /// clicks nothing.
    func testALongPressOnAnEmptyPartOpensTheMenu() throws {
        let fixture = try self.launchDoubleTap()
        fixture.empty.press(forDuration: 1.2)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        self.attachScreenshot(fixture.app, "after the long press")
        XCTAssertTrue(after.contains("contextMenu fixture/double-tap.html"), after.replacingOccurrences(of: "\n", with: " | "))
        XCTAssertFalse(after.contains("openLink"), after)
    }

    /// On something the widget handles each tap is the widget's at once, as on a message button: a double tap there is
    /// two taps and no reaction.
    func testADoubleTapOnAButtonIsTwoTaps() throws {
        let fixture = try self.launchDoubleTap()
        fixture.button.doubleTap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            value.split(separator: "\n").filter { $0.hasPrefix("openLink") }.count >= 2
        }
        Thread.sleep(forTimeInterval: 0.5)
        let settled = self.readout(fixture.app)
        XCTAssertEqual(settled.split(separator: "\n").filter { $0.hasPrefix("openLink https://example.org/tap") }.count, 2, after)
        XCTAssertFalse(settled.contains("reaction"), settled)
    }

    /// The selection fixture, launched with the stand-in menu held open, and the widget's top-left in the app's
    /// coordinates (each of its rows is 40 px tall, its 20 px line at the top; `#empty` starts at 200).
    private func launchSelection(_ extra: [String] = [], caption: Bool = false) throws -> (app: XCUIApplication, origin: XCUICoordinate) {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "selection", "-harness-menu", "hold"] + (caption ? [] : ["-widget-caption", "off"]) + extra)
        // Past the 160 pt placeholder: the widget has reported its height, so the bubble sits where it will stay.
        let ready = self.waitForReadout(app) { $0.contains("selection.html") && $0.contains(" widget") && !$0.contains("x160 ") }
        let widget = try XCTUnwrap(self.bubble("selection.html", in: ready), ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let width = size.count == 2 ? size[0] : 300.0
        let height = size.count == 2 ? size[1] : 260.0
        let origin = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: widget.centre.dx - width / 2.0, dy: widget.centre.dy - height / 2.0))
        return (app, origin)
    }

    private func at(_ origin: XCUICoordinate, _ x: Double, _ y: Double) -> XCUICoordinate {
        return origin.withOffset(CGVector(dx: x, dy: y))
    }

    /// Lifts the selection fixture's bubble through the held menu's Open (the long press that does it in the chat has
    /// tests of its own) and returns the readout once the menu is open.
    @discardableResult
    private func lift(_ app: XCUIApplication) -> String {
        app.buttons["harness.openMenu"].tap()
        return self.waitForReadout(app, timeout: 5.0) { $0.contains("contextMenu fixture/selection.html") }
    }

    /// The held stand-in menu stays open until its End button.
    func testTheHeldMenuStaysOpenAndEnds() throws {
        let fixture = try self.launchSelection()
        self.lift(fixture.app)
        let opened = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenu fixture/selection.html") }
        XCTAssertTrue(opened.contains("contextMenu fixture/selection.html"), opened)
        Thread.sleep(forTimeInterval: 3.0)
        XCTAssertFalse(self.readout(fixture.app).contains("contextMenuEnded"))
        fixture.app.buttons["harness.endMenu"].tap()
        let ended = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenuEnded fixture/selection.html") }
        XCTAssertTrue(ended.contains("contextMenuEnded fixture/selection.html"), ended)
    }

    /// Lifts the bubble and holds on the selection fixture's `(x, y)` long enough to begin a selection there.
    private func liftAndHold(_ fixture: (app: XCUIApplication, origin: XCUICoordinate), _ x: Double, _ y: Double) {
        self.lift(fixture.app)
        // The selectable text arrives a moment after the lift (the export is never waited for).
        Thread.sleep(forTimeInterval: 0.5)
        self.at(fixture.origin, x, y).press(forDuration: 0.6)
    }

    private func copied(_ readout: String) -> [String] {
        return readout.split(separator: "\n").filter { $0.hasPrefix("copy ") }.map(String.init)
    }

    /// sdk-v1 §5.10, as in a rich message: in the lifted bubble a hold on text the widget marked selectable selects that
    /// word, the menu offers Copy (and Select All), and Copy copies the word.
    func testAHoldOnSelectableTextSelectsAWordAndCopies() throws {
        let fixture = try self.launchSelection()
        self.liftAndHold(fixture, 70.0, 10.0)
        let menu = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenu") }
        self.attachScreenshot(fixture.app, "a word selected")
        XCTAssertTrue(menu.contains("selectionMenu Copy,Select All"), menu)
        fixture.app.buttons["harness.menu.Copy"].tap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("copy ") }
        XCTAssertEqual(self.copied(after), ["copy these"], after)
    }

    func testSelectAllCopiesTheWholeSelectableText() throws {
        let fixture = try self.launchSelection()
        self.liftAndHold(fixture, 70.0, 10.0)
        _ = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenu Copy,Select All") }
        fixture.app.buttons["harness.menu.Select All"].tap()
        _ = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenu Copy\n") || $0.hasSuffix("selectionMenu Copy") }
        fixture.app.buttons["harness.menu.Copy"].tap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("copy ") }
        let copy = try XCTUnwrap(self.copied(after).first, after)
        XCTAssertTrue(copy.hasPrefix("copy Select these bold words here\\n"), copy)
        XCTAssertTrue(copy.hasSuffix("\\nsliding"), copy)
        XCTAssertFalse(copy.contains("skipped"), copy)
        XCTAssertFalse(copy.contains("Not this one"), copy)
    }

    func testAHoldOnUnselectableTextSelectsNothing() throws {
        let fixture = try self.launchSelection()
        self.liftAndHold(fixture, 30.0, 50.0)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(self.readout(fixture.app).contains("selectionMenu"), self.readout(fixture.app))
    }

    /// Copy is the only action, so where the chat forbids copying nothing selects.
    func testCopyProtectionMeansNoSelection() throws {
        let fixture = try self.launchSelection(["-harness-copy-protected", "on"])
        self.liftAndHold(fixture, 70.0, 10.0)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(self.readout(fixture.app).contains("selectionMenu"), self.readout(fixture.app))
    }

    /// The widget keeps running while the bubble is lifted (the user, 2026-10-22): #count ticks beside the selection, which
    /// holds.
    func testTheCounterTicksAndTheSelectionHolds() throws {
        let fixture = try self.launchSelection()
        self.liftAndHold(fixture, 70.0, 10.0)
        _ = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenu") }
        Thread.sleep(forTimeInterval: 1.0)
        fixture.app.buttons["harness.menu.Copy"].tap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("copy ") }
        XCTAssertEqual(self.copied(after), ["copy these"], after)
    }

    /// A selection on a word moving under a transform animation follows it.
    func testASlidingWordKeepsItsHighlight() throws {
        let fixture = try self.launchSelection()
        self.liftAndHold(fixture, 50.0, 170.0)
        _ = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenu") }
        Thread.sleep(forTimeInterval: 0.5)
        self.attachScreenshot(fixture.app, "the sliding word's highlight")
        fixture.app.buttons["harness.menu.Copy"].tap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("copy ") }
        XCTAssertEqual(self.copied(after), ["copy sliding"], after)
    }

    /// Lifted, the widget takes no input; once the menu has closed, nothing is left over the widget and its button clicks.
    func testTheLiftedWidgetsButtonDoesNothing() throws {
        let fixture = try self.launchSelection()
        self.lift(fixture.app)
        Thread.sleep(forTimeInterval: 0.5)
        self.at(fixture.origin, 100.0, 100.0).tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(self.readout(fixture.app).contains("openLink"), self.readout(fixture.app))
        fixture.app.buttons["harness.endMenu"].tap()
        _ = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        self.at(fixture.origin, 100.0, 100.0).tap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("openLink") }
        XCTAssertTrue(after.contains("openLink https://example.org/sel"), after)
    }

    /// One selection at a time in a bubble: starting one in the widget dismisses the caption's (and its menu).
    func testAWidgetSelectionClearsTheCaptions() throws {
        let fixture = try self.launchSelection(caption: true)
        let ready = self.readout(fixture.app)
        let widget = try XCTUnwrap(self.bubble("selection.html", in: ready), ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let height = size.count == 2 ? size[1] : 260.0
        self.lift(fixture.app)
        Thread.sleep(forTimeInterval: 0.5)
        // The caption ("fixture/selection.html") is the text under the widget.
        self.at(fixture.origin, 40.0, height + 14.0).press(forDuration: 0.6)
        let captionMenu = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenu") }
        XCTAssertTrue(captionMenu.contains("selectionMenu"), captionMenu)
        self.at(fixture.origin, 70.0, 10.0).press(forDuration: 0.6)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("selectionMenuDismissed") }
        XCTAssertTrue(after.contains("selectionMenuDismissed"), after)
        fixture.app.buttons["harness.menu.Copy"].tap()
        let copied = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("copy ") }
        XCTAssertEqual(self.copied(copied), ["copy these"], copied)
    }

    /// Every long press on an empty part opens the menu (K3, 2026-10-22: none did). The bubble asks about the press
    /// again while it is held, and its press animation has moved the finger's point in the widget by then (1.3 pt in
    /// the harness): the question must still find the press it is about.
    ///
    /// Which of the touch's recognizers hears it first is UIKit's and varied between launches: the bubble's context
    /// gesture, first, asked about a press nothing had started yet (2 of 8 first presses after a launch, measured). So
    /// three launches, three presses each.
    func testEveryLongPressOnAnEmptyPartOpensTheMenu() throws {
        for launch in 0 ..< 3 {
            let fixture = try self.launchDoubleTap()
            for i in 0 ..< 3 {
                fixture.empty.press(forDuration: 1.2)
                let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.components(separatedBy: "contextMenuEnded").count - 1 > i }
                XCTAssertEqual(after.components(separatedBy: "contextMenu fixture/double-tap.html").count - 1, i + 1, "launch \(launch + 1), press \(i + 1): " + after.replacingOccurrences(of: "\n", with: " | "))
                Thread.sleep(forTimeInterval: 0.3)
            }
            XCTAssertFalse(self.readout(fixture.app).contains("openLink"), self.readout(fixture.app))
            fixture.app.terminate()
        }
    }

    func testTheKillSwitchPillAndItsCaption() {
        let app = self.launch(["-widget-kill-switch", "on", "-widget-post", "visual/01-boxes"])
        let value = self.waitForReadout(app) { $0.contains(" pill") }
        self.attachScreenshot(app, "kill switch engaged")
        let bubbles = value.split(separator: "\n").filter { $0.hasPrefix("bubble ") }
        XCTAssertFalse(bubbles.isEmpty, value)
        for line in bubbles {
            XCTAssertTrue(line.contains(" pill +caption"), String(line))
        }
    }

    func testTheConformanceSetLoadsInOrder() {
        for theme in ["light", "dark"] {
            let app = self.launch(["-widget-set", "conformance", "-harness-theme", theme])
            let value = self.waitForReadout(app) { $0.contains(" widget") }
            self.attachScreenshot(app, "conformance set, \(theme)")
            XCTAssertTrue(value.contains("bubble 0 "), value)
            app.terminate()
        }
    }
}
