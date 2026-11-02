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

    /// widget-sandbox v0.1.2: a hold is by touch-action, not by what the widget handles. On a button with touch-action:
    /// auto it is the bubble's menu, the widget's touch ends with a pointercancel, and lifting the finger clicks nothing.
    func testALongPressOnAnAutoButtonOpensTheMenu() throws {
        let fixture = try self.launchDoubleTap()
        fixture.button.press(forDuration: 1.2)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        self.attachScreenshot(fixture.app, "after the long press on #button")
        XCTAssertTrue(after.contains("contextMenu fixture/double-tap.html"), after)
        XCTAssertEqual(self.pointerLog("double-tap", in: after), "pointercancel:button", after)
        XCTAssertFalse(after.contains("openLink"), after)
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

    /// A vertical drag is never a widget's (the user, 2026-10-23: "widgets should not be able to prevent vertical
    /// scrolling, ever"): on a part with touch-action: none the list scrolls.
    func testAClaimedVerticalDragScrollsTheChat() throws {
        let fixture = try self.launchDrag()
        fixture.claim.press(forDuration: 0.05, thenDragTo: fixture.claim.withOffset(CGVector(dx: 0.0, dy: 200.0)))
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            (self.listMovement(from: fixture.ready, to: value) ?? 1000.0) > 50.0
        }
        self.attachScreenshot(fixture.app, "after a vertical drag on #claim")
        XCTAssertGreaterThan(self.listMovement(from: fixture.ready, to: after) ?? 1000.0, 50.0, after)
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

    /// widget-sandbox v0.1.2: touch-action: none claims the press's hold too: no menu, and the widget gets contextmenu.
    func testALongPressOnNoneIsTheWidgets() throws {
        let fixture = try self.launchDrag()
        fixture.claim.press(forDuration: 1.2)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("touch-drag", in: $0).contains("contextmenu") }
        Thread.sleep(forTimeInterval: 0.5)
        let settled = self.readout(fixture.app)
        XCTAssertEqual(self.pointerLog("touch-drag", in: settled), "contextmenu:claim", after)
        XCTAssertFalse(settled.contains("contextMenu"), settled)
    }

    /// widget-sandbox v0.1.3 (G2): a vertical drag is the chat's even after a hold the widget won: #claim held 0.7 s (its
    /// contextmenu), then dragged down, scrolls the list and ends the widget's touch.
    func testAHoldThenAVerticalDragOnNoneScrollsTheChat() throws {
        let fixture = try self.launchDrag()
        let widget = try XCTUnwrap(self.bubble("touch-drag.html", in: fixture.ready), fixture.ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let top = widget.centre.dy - (size.count == 2 ? size[1] : 300.0) / 2.0
        let claim = CGPoint(x: widget.centre.dx, y: top + 150.0)
        // The synthesizer moves a finger along its path between offsets: a point at 0.7 s where it went down holds it still.
        let moves = [(claim, 0.7)] + (1 ... 10).map { step in (CGPoint(x: claim.x, y: claim.y + 20.0 * Double(step)), 0.7 + 0.03 * Double(step)) }
        try performFingers([Finger(at: claim, down: 0.0, moves: moves, up: 1.2)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("touch-drag", in: $0).contains("pointercancel") }
        self.attachScreenshot(fixture.app, "after a hold then a vertical drag on #claim")
        XCTAssertGreaterThan(self.listMovement(from: fixture.ready, to: after) ?? 1000.0, 50.0, after)
        XCTAssertEqual(self.pointerLog("touch-drag", in: after), "contextmenu:claim pointercancel:claim", after)
        XCTAssertFalse(after.contains("contextMenu"), after)
    }

    /// widget-sandbox v0.1.2: touch-action: pan-y claims horizontal drags only, so a hold on it is the bubble's menu.
    func testALongPressOnPanYOpensTheMenu() throws {
        let fixture = try self.launchDrag()
        fixture.pany.press(forDuration: 1.2)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        XCTAssertTrue(after.contains("contextMenu fixture/touch-drag.html"), after)
        XCTAssertEqual(self.pointerLog("touch-drag", in: after), "pointercancel:pany", after)
    }

    /// A hold on pan-y after the finger drifted 7 pt sideways (past the 4 pt that begins the widget's claimed drag, within
    /// the policy's 10 px slop) is still the bubble's menu: the widget's recognizer spares the menu's long press until a
    /// drag passes the slop.
    func testAHoldOnPanYAfterASmallSidewaysDriftOpensTheMenu() throws {
        let fixture = try self.launchDrag()
        let widget = try XCTUnwrap(self.bubble("touch-drag.html", in: fixture.ready), fixture.ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let top = widget.centre.dy - (size.count == 2 ? size[1] : 300.0) / 2.0
        let from = CGPoint(x: widget.centre.dx, y: top + 250.0)
        // 7 pt to the right over 0.2 s, then still: the synthesizer moves a finger along its path between points, so a
        // last point at the same place holds it there.
        let moves = (1 ... 7).map { step in (CGPoint(x: from.x + Double(step), y: from.y), 0.05 + 0.03 * Double(step)) } + [(CGPoint(x: from.x + 7.0, y: from.y), 1.4)]
        try performFingers([Finger(at: from, down: 0.0, moves: moves, up: 1.5)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        self.attachScreenshot(fixture.app, "after a hold on #pany that drifted 7 pt")
        XCTAssertTrue(after.contains("contextMenu fixture/touch-drag.html"), after)
        XCTAssertEqual(self.pointerLog("touch-drag", in: after), "pointercancel:pany", after)
    }

    /// widget-sandbox v0.1.2: a press in the widget's leading 20 pt claims nothing, whatever its touch-action, so a
    /// rightward drag from there on #claim is the chat's back swipe (the policy's own check for the strip).
    func testADragFromTheLeadingStripSwipesBack() throws {
        let fixture = try self.launchDrag()
        let widget = try XCTUnwrap(self.bubble("touch-drag.html", in: fixture.ready), fixture.ready)
        let width = widget.size.split(separator: "x").first.flatMap { Double($0) } ?? 300.0
        let strip = fixture.claim.withOffset(CGVector(dx: -width / 2.0 + 10.0, dy: 0.0))
        strip.press(forDuration: 0.05, thenDragTo: strip.withOffset(CGVector(dx: 160.0, dy: 0.0)))
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.split(separator: "\n").contains("back") }
        self.attachScreenshot(fixture.app, "after a drag from #claim's leading strip")
        XCTAssertTrue(after.split(separator: "\n").contains("back"), after)
    }

    /// Review Focus 1: a widget that is touch-action: none all over keeps every hold on it, but its caption is the
    /// bubble's: a hold there opens the menu.
    func testAHoldOnTheCaptionOpensTheMenu() throws {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "hold-none"])
        let ready = self.waitForReadout(app) { $0.contains("hold-none.html") && $0.contains(" widget") && !$0.contains("x160 ") }
        let widget = try XCTUnwrap(self.bubble("hold-none.html", in: ready), ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        let height = size.count == 2 ? size[1] : 120.0
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(widget.centre).press(forDuration: 1.2)
        let held = self.waitForReadout(app, timeout: 5.0) { self.pointerLog("hold-none", in: $0).contains("contextmenu") }
        XCTAssertEqual(self.pointerLog("hold-none", in: held), "contextmenu:surface", held)
        XCTAssertFalse(held.contains("contextMenu"), held)
        // The caption ("fixture/hold-none.html") is the text under the widget.
        origin.withOffset(CGVector(dx: widget.centre.dx - 60.0, dy: widget.centre.dy + height / 2.0 + 14.0)).press(forDuration: 1.2)
        let after = self.waitForReadout(app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        self.attachScreenshot(app, "after the hold on the caption")
        XCTAssertTrue(after.contains("contextMenu fixture/hold-none.html"), after)
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

    /// widget-sandbox v0.1.2: a double tap over the widget is always the widget's, on a part that handles nothing too:
    /// two clicks then a dblclick, and no quick reaction.
    func testADoubleTapOnTheWidgetIsItsOwn() throws {
        let fixture = try self.launchDoubleTap()
        fixture.empty.doubleTap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("double-tap", in: $0).contains("dblclick") }
        Thread.sleep(forTimeInterval: 0.5)
        let settled = self.readout(fixture.app)
        self.attachScreenshot(fixture.app, "after the double tap on #empty")
        XCTAssertEqual(self.pointerLog("double-tap", in: settled), "click:empty click:empty dblclick:empty", after)
        XCTAssertFalse(settled.contains("reaction"), settled)
        XCTAssertFalse(settled.contains("openLink"), settled)
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
    /// two taps (then a dblclick) and no reaction.
    func testADoubleTapOnAButtonIsTwoTaps() throws {
        let fixture = try self.launchDoubleTap()
        fixture.button.doubleTap()
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            value.split(separator: "\n").filter { $0.hasPrefix("openLink") }.count >= 2
        }
        Thread.sleep(forTimeInterval: 0.5)
        let settled = self.readout(fixture.app)
        XCTAssertEqual(settled.split(separator: "\n").filter { $0.hasPrefix("openLink https://example.org/tap") }.count, 2, after)
        XCTAssertEqual(self.pointerLog("double-tap", in: settled), "click:button click:button dblclick:button", settled)
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

    // MARK: resize anchors (widget-sandbox v0.1.3, corpus/resize)

    /// corpus/resize's delivery FAQ (the default anchor, top), the newest post of a chat taller than the screen, at the
    /// chat's bottom: a tap on its first question opens the answer below it, and the FAQ grows upward, the chat staying at
    /// its bottom, as its top stays below the screen's top inset (the user's rule, 2026-10-28).
    func testAtTheBottomTheFaqGrowsUpward() throws {
        let faq = "resize/1-default/01-faq.html"
        let app = self.launch(["-widget-set", "corpus", "-widget-posts", "resize/3-grows-down/03-show-more.html,resize/2-grows-up/02-support-thread.html," + faq])
        self.waitForReadout(app) { $0.contains(faq) && $0.contains(" widget") && !$0.contains("x160 ") }
        self.pumpReadout(app, for: 1.0)
        let before = try XCTUnwrap(self.bubble(faq, in: self.readout(app)), self.readout(app))
        let size = before.size.split(separator: "x").compactMap { Double($0) }
        let height = size.last ?? 0.0
        let top = before.centre.dy - height / 2.0
        let bottom = before.centre.dy + height / 2.0
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.centre.dx, dy: top + 132.0)).tap()
        let grown = self.waitForReadout(app, timeout: 5.0) { value in
            (self.bubble(faq, in: value)?.size.split(separator: "x").compactMap { Double($0) }.last ?? 0.0) > height + 20.0
        }
        self.pumpReadout(app, for: 1.0)
        let after = try XCTUnwrap(self.bubble(faq, in: self.readout(app)), grown)
        self.attachScreenshot(app, "after opening the FAQ's first answer")
        let afterHeight = after.size.split(separator: "x").compactMap { Double($0) }.last ?? 0.0
        XCTAssertGreaterThan(afterHeight, height + 20.0, self.readout(app))
        // The list's top edge is the readout's bottom (the harness's top inset).
        let inset = Double(app.staticTexts["harness.readout"].frame.maxY)
        XCTAssertGreaterThan(top - (afterHeight - height), inset + 1.0, "its growth reaches the top inset at \(inset): before \(before), after \(after)")
        XCTAssertEqual(after.centre.dy + afterHeight / 2.0, bottom, accuracy: 1.0, "before \(before), after \(after)")
    }

    /// A widget's height change during a fling leaves the fling alone: the list's own placement keeps what is on the
    /// screen-bottom side of the bubble, where a scroll target keeping its anchored edge would end the momentum (the
    /// rest of the fling jumped to its destination). The swipe starts on a 300 pt post: `toggle-top` changes height
    /// every 50 ms from that pointerdown while on screen, `touch-drag` stays still; the momentum after the lift (the
    /// readout's `scrollEnded`) must be as long past the one as past the other.
    func testAFlingPastAResizingWidgetKeepsItsMomentum() throws {
        func momentum(swipingOn post: String) throws -> Double {
            let posts = ["fixture/text.html", "fixture/tall-box.html", "fixture/multitouch.html", post, "fixture/storage-counter.html", "fixture/hold-none.html", "fixture/double-tap.html", "fixture/open-link.html"]
            let app = self.launch(["-widget-set", "fixture", "-widget-posts", posts.joined(separator: ","), "-widget-caption", "off"])
            let ready = self.waitForReadout(app) { $0.contains("open-link.html") && $0.contains(" widget") && $0.contains(post) }
            self.pumpReadout(app, for: 1.0)
            let centre = try XCTUnwrap(self.centre(of: post, in: self.readout(app)), ready)
            // 300 pt down at 2000 pt/s, from the post's top part: a fling to the chat's top.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let from = origin.withOffset(CGVector(dx: centre.dx, dy: centre.dy - 100.0))
            from.press(forDuration: 0.01, thenDragTo: from.withOffset(CGVector(dx: 0.0, dy: 300.0)), withVelocity: XCUIGestureVelocity(rawValue: 2000.0), thenHoldForDuration: 0.0)
            let after = self.waitForReadout(app, timeout: 10.0) { $0.contains("scrollEnded ") }
            self.attachScreenshot(app, "after the fling from \(post)")
            let line = try XCTUnwrap(after.split(separator: "\n").last(where: { $0.hasPrefix("scrollEnded ") }), after)
            return try XCTUnwrap(Double(line.dropFirst("scrollEnded ".count)), after)
        }
        let still = try momentum(swipingOn: "fixture/touch-drag.html")
        XCTAssertGreaterThan(still, 0.3, "the swipe does not fling")
        let resizing = try momentum(swipingOn: "fixture/resize/toggle-top.html")
        XCTAssertGreaterThan(resizing, still * 0.75, "the fling's momentum ended early: \(resizing) s against \(still) s")
    }

    // MARK: conformance through the real bubble (CLIENTS.md: press and drag performed as a person would)

    /// The readout's `conformance <path> <json>` line for `path`: the widget's `data-conformance`.
    private func conformance(_ path: String, in readout: String) -> [String: Any]? {
        guard let line = readout.split(separator: "\n").first(where: { $0.hasPrefix("conformance \(path) ") }) else {
            return nil
        }
        let json = line.dropFirst("conformance \(path) ".count)
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }

    /// widget-sandbox v0.2.2's auto/23-gestures-a, its actions performed on the real bubble (a Tier 1 run injects below
    /// it, so the checks only the bubble can satisfy fail there): holds of 700 ms on #none and #auto, double taps on
    /// #nonedbl and #autodbl, then Finish. Every check passes.
    func testAuto23aThroughTheRealBubble() throws {
        try self.runAuto23("auto/23-gestures-a.html") { app, at, _ in
            try at("none").press(forDuration: 0.7)
            try at("auto").press(forDuration: 0.7)
            // The hold on #auto opened the menu; the next touches wait for it to end.
            self.waitForReadout(app, timeout: 5.0) { $0.contains("contextMenuEnded") }
            try at("nonedbl").doubleTap()
            try at("autodbl").doubleTap()
        }
    }

    /// widget-sandbox v0.2.2's auto/23-gestures-b on the real bubble: vertical drags of +60 px in 10 steps on #vnone and
    /// #vpanx (the chat's scroll), drags of +120 px in 10 steps from the pad's leading strip (#edge) and from 60 px in
    /// (#mid), then Finish. Every check passes.
    func testAuto23bThroughTheRealBubble() throws {
        try self.runAuto23("auto/23-gestures-b.html") { app, _, locate in
            for name in ["vnone", "vpanx"] {
                let from = try locate(name)
                let moves = (1 ... 10).map { step in (CGPoint(x: from.x, y: from.y + 6.0 * Double(step)), 0.05 + 0.03 * Double(step)) }
                try performFingers([Finger(at: from, down: 0.0, moves: moves, up: 0.45)], in: app)
            }
            for name in ["edge", "mid"] {
                let from = try locate(name)
                let moves = (1 ... 10).map { step in (CGPoint(x: from.x + 12.0 * Double(step), y: from.y), 0.05 + 0.03 * Double(step)) }
                try performFingers([Finger(at: from, down: 0.0, moves: moves, up: 0.45)], in: app)
            }
        }
    }

    /// One half of auto/23-gestures through the real bubble: `perform` acts, then Finish, then every check must pass.
    /// Each action aims at the latest readout (CLIENTS.md step 6): the widget lists its open checks, so it changes height
    /// as they pass, and the chat scrolls. No caption (the 600 pt widget's long one put its first probes under the
    /// status bar) and auto/22 above it, so the chat is taller than the screen and can scroll.
    private func runAuto23(_ path: String, perform: (XCUIApplication, (String) throws -> XCUICoordinate, (String) throws -> CGPoint) throws -> Void) throws {
        let app = self.launch(["-widget-set", "conformance", "-widget-posts", "auto/22-ua-defaults.html," + path, "-widget-caption", "off"])
        let ready = self.waitForReadout(app) { value in
            (self.conformance(path, in: value)?["status"] as? String) == "awaiting" && value.contains(" widget") && !value.contains("x160 ")
        }
        XCTAssertNotNil(self.conformance(path, in: ready), ready)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        // Where `name`'s centre is now, in the app's coordinates.
        let locate = { (name: String) throws -> CGPoint in
            self.pumpReadout(app, for: 0.4)
            let now = self.readout(app)
            let widget = try XCTUnwrap(self.bubble(path, in: now), now)
            let size = widget.size.split(separator: "x").compactMap { Double($0) }
            let rect = try XCTUnwrap((self.conformance(path, in: now)?["targets"] as? [String: [Double]])?[name], "\(name) not published: \(now)")
            let left = widget.centre.dx - (size.first ?? 0.0) / 2.0
            let top = widget.centre.dy - (size.last ?? 0.0) / 2.0
            return CGPoint(x: left + rect[0] + rect[2] / 2.0, y: top + rect[1] + rect[3] / 2.0)
        }
        let at = { (name: String) throws -> XCUICoordinate in
            let p = try locate(name)
            return origin.withOffset(CGVector(dx: p.x, dy: p.y))
        }
        try perform(app, at, locate)
        try at("finish").tap()
        let after = self.waitForReadout(app, timeout: 25.0) { (self.conformance(path, in: $0)?["status"] as? String) == "done" }
        self.attachScreenshot(app, "after \(path)")
        let checks = try XCTUnwrap(self.conformance(path, in: after)?["checks"] as? [[Any]], after)
        XCTAssertFalse(checks.isEmpty, after)
        for check in checks {
            XCTAssertEqual(check.count > 2 ? check[2] as? String : nil, "pass", "\(check)")
        }
    }

    // MARK: multitouch (fixture/multitouch.html, `performFingers`)

    /// The multitouch fixture laid out with its widget running: #left and #right side by side at its top, 140 × 100 pt
    /// each, #pad under them, 280 × 100 pt; points in the app's (the screen's) coordinates.
    private struct MultitouchFixture {
        let app: XCUIApplication
        let ready: String
        let area: CGRect
        var left: CGPoint { CGPoint(x: self.area.minX + 70.0, y: self.area.minY + 50.0) }
        var right: CGPoint { CGPoint(x: self.area.minX + 210.0, y: self.area.minY + 50.0) }
        var pad: CGPoint { CGPoint(x: self.area.minX + 140.0, y: self.area.minY + 150.0) }
    }

    private func launchMultitouch() throws -> MultitouchFixture {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "multitouch"])
        let ready = self.waitForReadout(app) { $0.contains("multitouch.html") && $0.contains(" widget") && !$0.contains("x160 ") }
        let widget = try XCTUnwrap(self.bubble("multitouch.html", in: ready), ready)
        let size = widget.size.split(separator: "x").compactMap { Double($0) }
        XCTAssertEqual(size.count, 2, ready)
        let width = size.first ?? 0.0
        let height = size.last ?? 0.0
        let area = CGRect(x: widget.centre.dx - width / 2.0, y: widget.centre.dy - height / 2.0, width: width, height: height)
        return MultitouchFixture(app: app, ready: ready, area: area)
    }

    /// The widget's pointer log (the readout's `log <path> <value>` line), "" before it logged anything.
    private func pointerLog(_ path: String, in readout: String) -> String {
        guard let line = readout.split(separator: "\n").first(where: { $0.hasPrefix("log ") && $0.contains(path) }) else {
            return ""
        }
        return line.split(separator: " ", maxSplits: 2).dropFirst(2).first.map(String.init) ?? ""
    }

    /// The harness channel itself: one synthesized finger on a button reaches the widget, and its log reaches the readout.
    func testTheMultitouchFixtureLogsAFinger() throws {
        let fixture = try self.launchMultitouch()
        try performFingers([Finger(at: fixture.left, down: 0.0, up: 0.2)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("multitouch", in: $0) == "down:left:a:P up:left:a:P" }
        self.attachScreenshot(fixture.app, "one finger on #left")
        XCTAssertEqual(self.pointerLog("multitouch", in: after), "down:left:a:P up:left:a:P", after)
    }

    private func hasEvent(_ event: String, in readout: String) -> Bool {
        return readout.split(separator: "\n").contains { $0.hasPrefix(event + " ") }
    }

    /// Multitouch (design §2): each finger on a widget is its own pointer, the first the primary; the chat neither opens
    /// the menu, reacts nor swipes to reply.
    /// Both fingers go down together (a finger that starts later in a record gets a second press from the synthesizer:
    /// see `performFingers`), so which is primary is UIKit's order: exactly one is, and #right lifts first while #left
    /// stays pressed.
    func testTwoFingersOnTwoButtonsAreTwoPointers() throws {
        let fixture = try self.launchMultitouch()
        try performFingers([Finger(at: fixture.left, down: 0.0, up: 0.9), Finger(at: fixture.right, down: 0.0, up: 0.6)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("multitouch", in: $0).split(separator: " ").count == 4 }
        self.attachScreenshot(fixture.app, "two fingers on #left and #right")
        let entries = self.pointerLog("multitouch", in: after).split(separator: " ").map(String.init)
        XCTAssertEqual(entries.count, 4, after)
        XCTAssertEqual(Set(entries.prefix(2).map { $0.split(separator: ":")[1] }), ["left", "right"], after)
        XCTAssertEqual(entries.suffix(2).map { $0.split(separator: ":").prefix(2).joined(separator: ":") }, ["up:right", "up:left"], after)
        XCTAssertEqual(entries.filter { $0.hasSuffix(":P") }.count, 2, "one finger, down and up, is primary: \(after)")
        XCTAssertEqual(Set(entries.map { $0.split(separator: ":")[2] }).count, 2, after)
        for event in ["contextMenu", "reaction", "reply"] {
            XCTAssertFalse(self.hasEvent(event, in: after), after)
        }
    }

    /// Each finger's moves are its own pointer's: two fingers dragging sideways on #left and #right each log a move, one
    /// of them primary (vertically they would scroll the chat).
    func testTwoFingersDraggingMoveAsTwoPointers() throws {
        let fixture = try self.launchMultitouch()
        let left = fixture.left
        let right = fixture.right
        try performFingers([Finger(at: left, down: 0.0, moves: [(CGPoint(x: left.x + 30.0, y: left.y), 0.3)], up: 0.8),
                            Finger(at: right, down: 0.0, moves: [(CGPoint(x: right.x + 30.0, y: right.y), 0.4)], up: 0.8)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            let log = self.pointerLog("multitouch", in: value)
            return log.contains("up:left:") && log.contains("up:right:")
        }
        self.attachScreenshot(fixture.app, "after dragging on #left and #right")
        let moves = self.pointerLog("multitouch", in: after).split(separator: " ").map(String.init).filter { $0.hasPrefix("move:") }
        XCTAssertEqual(Set(moves.map { String($0.split(separator: ":")[1]) }), ["left", "right"], after)
        XCTAssertEqual(Set(moves.map { String($0.split(separator: ":")[2]) }).count, 2, after)
        XCTAssertEqual(moves.filter { $0.hasSuffix(":P") }.count, 1, after)
    }

    /// A first finger on a part the widget does not handle, then a second on a button: the chat lets go of the long press
    /// it was waiting on, and both fingers are the widget's.
    func testASecondFingerOnAButtonTakesTheHoldFromTheMenu() throws {
        let fixture = try self.launchMultitouch()
        try performFingers([Finger(at: fixture.pad, down: 0.0, up: 1.5), Finger(at: fixture.left, down: 0.2, up: 1.5)], in: fixture.app)
        // The synthesizer presses a finger that starts later a second time after its lift (`performFingers`): read the
        // log up to there.
        let expected = "down:left:a:S up:left:a:S"
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("multitouch", in: $0).hasPrefix(expected) }
        self.attachScreenshot(fixture.app, "after holding #pad and #left")
        XCTAssertTrue(self.pointerLog("multitouch", in: after).hasPrefix(expected), after)
        XCTAssertFalse(self.hasEvent("contextMenu", in: after), after)
    }

    /// A finger that slides sideways off its button, past the widget's edge, stays the widget's: its up arrives, never a
    /// cancel, and the bubble does not swipe to reply.
    func testAFingerSlidingOffTheWidgetStaysItsOwn() throws {
        let fixture = try self.launchMultitouch()
        let left = fixture.left
        let moves = [0.45, 0.6, 0.8].enumerated().map { index, time in
            (CGPoint(x: left.x - 30.0 * Double(index + 1), y: left.y), time)
        }
        try performFingers([Finger(at: fixture.right, down: 0.0, up: 1.0), Finger(at: left, down: 0.0, moves: moves, up: 1.0)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            let log = self.pointerLog("multitouch", in: value)
            return log.contains("up:left:") && log.contains("up:right:")
        }
        self.attachScreenshot(fixture.app, "after sliding off #left")
        let log = self.pointerLog("multitouch", in: after)
        XCTAssertTrue(log.contains("up:left:") && log.contains("up:right:"), after)
        XCTAssertFalse(log.contains("cancel"), after)
        XCTAssertFalse(self.hasEvent("reply", in: after), after)
    }

    /// The list began a drag (the readout's `listDrag` event): the chat scrolls.
    private func listDragged(_ readout: String) -> Bool {
        return readout.split(separator: "\n").contains("listDrag")
    }

    /// With two fingers on buttons (the widget took the touches), one dragging vertically still scrolls the chat (a
    /// vertical scroll is never a widget's to stop), and the scroll ends both presses.
    func testTwoFingersOnButtonsLetTheChatScroll() throws {
        let fixture = try self.launchMultitouch()
        let right = fixture.right
        let moves = (1 ... 8).map { step in (CGPoint(x: right.x, y: right.y + 25.0 * Double(step)), 0.3 + 0.08 * Double(step)) }
        try performFingers([Finger(at: fixture.left, down: 0.0, up: 1.5), Finger(at: right, down: 0.0, moves: moves, up: 1.3)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { value in
            let log = self.pointerLog("multitouch", in: value)
            return self.listDragged(value) && log.contains("cancel:left") && log.contains("cancel:right")
        }
        self.attachScreenshot(fixture.app, "after a vertical drag with two fingers on buttons")
        XCTAssertTrue(self.listDragged(after), after)
        let log = self.pointerLog("multitouch", in: after)
        XCTAssertTrue(log.contains("cancel:left") && log.contains("cancel:right"), after)
    }

    /// While the chat drags, a finger that lands on the widget does nothing (the user, 2026-10-23: "The second finger
    /// can't interact with widgets ... in the chat while the first one scrolls"). The second finger lands early in the
    /// drag, while #left is still under it (one post: the list rubber-bands).
    func testAFingerOnTheWidgetWhileTheListScrollsDoesNothing() throws {
        let fixture = try self.launchMultitouch()
        let pad = fixture.pad
        let moves = (1 ... 10).map { step in (CGPoint(x: pad.x, y: pad.y + 20.0 * Double(step)), 0.1 * Double(step)) }
        try performFingers([Finger(at: pad, down: 0.0, moves: moves, up: 1.0), Finger(at: fixture.left, down: 0.15, up: 0.3)], in: fixture.app)
        self.pumpReadout(fixture.app, for: 1.0)
        let after = self.readout(fixture.app)
        self.attachScreenshot(fixture.app, "after the drag")
        XCTAssertEqual(self.pointerLog("multitouch", in: after), "", after)
    }

    /// Lets the readout catch up for `seconds`.
    private func pumpReadout(_ app: XCUIApplication, for seconds: TimeInterval) {
        _ = self.waitForReadout(app, timeout: seconds) { _ in false }
    }

    // MARK: the chat's lock while a widget control is held (the user, 2026-10-23)

    /// A point on the bubble's caption, under the widget.
    private func caption(_ fixture: MultitouchFixture) -> CGPoint {
        return CGPoint(x: fixture.area.minX + 30.0, y: fixture.area.maxY + 14.0)
    }

    /// While #left is held, a long press on the caption opens no menu, and #left is never cancelled.
    func testAHeldButtonKeepsTheCaptionsLongPressFromTheMenu() throws {
        let fixture = try self.launchMultitouch()
        try performFingers([Finger(at: fixture.left, down: 0.0, up: 2.0), Finger(at: self.caption(fixture), down: 0.3, up: 1.5)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("multitouch", in: $0).contains("left:a:P") && self.pointerLog("multitouch", in: $0).contains("up:left") }
        self.attachScreenshot(fixture.app, "after holding #left and the caption")
        XCTAssertEqual(self.pointerLog("multitouch", in: after), "down:left:a:P up:left:a:P", after)
        XCTAssertFalse(self.hasEvent("contextMenu", in: after), after)
    }

    /// A held button that drags (a claimed drag fails what is above it) still keeps the lock.
    func testAHeldButtonThatDragsStillLocksTheChat() throws {
        let fixture = try self.launchMultitouch()
        let left = fixture.left
        try performFingers([Finger(at: left, down: 0.0, moves: [(CGPoint(x: left.x + 20.0, y: left.y), 0.15)], up: 2.0),
                            Finger(at: self.caption(fixture), down: 0.4, up: 1.6)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { self.pointerLog("multitouch", in: $0).contains("up:left") }
        self.attachScreenshot(fixture.app, "after dragging #left and holding the caption")
        XCTAssertEqual(self.pointerLog("multitouch", in: after), "down:left:a:P move:left:a:P up:left:a:P", after)
        XCTAssertFalse(self.hasEvent("contextMenu", in: after), after)
    }

    /// While #left is held, a vertical drag elsewhere in the chat still scrolls it (the lock never stops a vertical
    /// scroll), and the scroll ends #left's press.
    func testAHeldButtonLetsTheChatScroll() throws {
        let fixture = try self.launchMultitouch()
        let start = CGPoint(x: fixture.area.midX, y: fixture.area.minY - 100.0)
        let moves = (1 ... 9).map { step in (CGPoint(x: start.x, y: start.y + 20.0 * Double(step)), 0.3 + 0.1 * Double(step)) }
        try performFingers([Finger(at: fixture.left, down: 0.0, up: 1.5), Finger(at: start, down: 0.3, moves: moves, up: 1.3)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("up:left") || $0.contains("cancel:left") }
        self.attachScreenshot(fixture.app, "after a drag while #left is held")
        XCTAssertTrue(self.listDragged(after), after)
        XCTAssertEqual(self.pointerLog("multitouch", in: after), "down:left:a:P cancel:left:a:P", after)
    }

    /// While #left is held, a swipe from the screen's left edge does not go back.
    func testAHeldButtonKeepsTheBackSwipeOff() throws {
        let fixture = try self.launchMultitouch()
        let start = CGPoint(x: 2.0, y: fixture.area.minY - 100.0)
        let moves = (1 ... 6).map { step in (CGPoint(x: start.x + 25.0 * Double(step), y: start.y), 0.3 + 0.1 * Double(step)) }
        try performFingers([Finger(at: fixture.left, down: 0.0, up: 1.5), Finger(at: start, down: 0.3, moves: moves, up: 1.0)], in: fixture.app)
        let after = self.waitForReadout(fixture.app, timeout: 5.0) { $0.contains("up:left") || $0.contains("cancel:left") }
        self.attachScreenshot(fixture.app, "after an edge swipe while #left is held")
        XCTAssertFalse(self.hasEvent("back", in: after) || after.split(separator: "\n").contains("back"), after)
        XCTAssertEqual(self.pointerLog("multitouch", in: after), "down:left:a:P up:left:a:P", after)
    }

    /// A finger resting on a part the widget does not handle, then one on a button: the bubble's context gesture, failed
    /// when the chat steps back, ends its press rather than holding the bubble shrunk until every finger lifts (its
    /// timer and animation outlive being failed from outside). The readout's `pressed <path> <seconds>` events say how
    /// long each press lasted (a query does not return while the fingers play).
    func testASecondFingerOnAButtonLeavesTheBubbleUnpressed() throws {
        let fixture = try self.launchMultitouch()
        try performFingers([Finger(at: fixture.pad, down: 0.0, up: 3.0), Finger(at: fixture.left, down: 0.2, up: 3.0)], in: fixture.app)
        self.pumpReadout(fixture.app, for: 1.0)
        let after = self.readout(fixture.app)
        self.attachScreenshot(fixture.app, "after the two-finger hold")
        XCTAssertTrue(self.pointerLog("multitouch", in: after).hasPrefix("down:left:a:S up:left:a:S"), after)
        let presses = after.split(separator: "\n").filter { $0.hasPrefix("pressed fixture/multitouch.html ") }.compactMap { Double($0.split(separator: " ").last ?? "") }
        XCTAssertTrue(presses.allSatisfy { $0 < 1.0 }, after)
    }
}
