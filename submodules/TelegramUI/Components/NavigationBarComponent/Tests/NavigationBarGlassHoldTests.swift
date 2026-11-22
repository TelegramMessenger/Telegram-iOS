import XCTest
import UIKit
@testable import NavigationBarComponent

final class NavigationBarGlassHoldTests: XCTestCase {
    private var scheduled: [(delay: Double, action: () -> Void)] = []

    private func makeHold() -> NavigationBarGlassHold {
        let hold = NavigationBarGlassHold(schedule: { [weak self] delay, action in
            self?.scheduled.append((delay, action))
        })
        hold.durationFactor = { 1.0 }
        return hold
    }

    private func content(_ title: String) -> NavigationBarComponent.Content {
        return NavigationBarComponent.Content(title: .text(title), back: .back, leftButton: nil, rightButtons: [], backPressed: {})
    }

    // The transition's glass is asked to hand over once, then the hold ends.
    func test_interrupt_asksOnce_andReleases() {
        let hold = self.makeHold()
        var asks = 0
        hold.hold(true, interrupted: { asks += 1 }, content: nil, rowFrame: CGRect())
        XCTAssertTrue(hold.isHeld)
        hold.interrupt()
        hold.interrupt()
        XCTAssertEqual(asks, 1)
        XCTAssertFalse(hold.isHeld)
    }

    // A bar laid out with other content or another row frame hands over; the same layout does not.
    func test_aChangedLayout_interrupts() {
        let hold = self.makeHold()
        let content = self.content("A")
        hold.hold(true, interrupted: {}, content: content, rowFrame: CGRect(x: 0.0, y: 10.0, width: 390.0, height: 44.0))
        hold.barLaidOut(content: content, rowFrame: CGRect(x: 0.0, y: 10.0, width: 390.0, height: 44.0))
        XCTAssertTrue(hold.isHeld)
        hold.barLaidOut(content: self.content("B"), rowFrame: CGRect(x: 0.0, y: 10.0, width: 390.0, height: 44.0))
        XCTAssertFalse(hold.isHeld)
    }

    private func pill(x: CGFloat, signature: AnyHashable = "chat") -> NavigationBarTransitionTitlePill {
        return NavigationBarTransitionTitlePill(frame: CGRect(x: x, y: 64.0, width: 178.0, height: 44.0), signature: signature, lendContent: { UIView() })
    }

    // A layout that only moves the title's pill (the chat header re-centred under the glass) keeps the hold and asks
    // the glass to follow it, once per move; the same pill again asks nothing.
    func test_aMovedTitlePill_isFollowed_notHandedOver() {
        let hold = self.makeHold()
        var interruptions = 0
        var moves = 0
        hold.hold(true, interrupted: { interruptions += 1 }, titlePillMoved: { moves += 1 }, content: nil, rowFrame: CGRect(), titlePill: self.pill(x: 100.0))
        hold.titlePillLaidOut(self.pill(x: 100.0))
        XCTAssertEqual(moves, 0)
        hold.titlePillLaidOut(self.pill(x: 112.0))
        XCTAssertEqual(moves, 1)
        hold.titlePillLaidOut(self.pill(x: 112.0))
        XCTAssertEqual(moves, 1)
        XCTAssertEqual(interruptions, 0)
        XCTAssertTrue(hold.isHeld)
        hold.interrupt()
        hold.titlePillLaidOut(self.pill(x: 120.0))
        XCTAssertEqual(moves, 1, "not after the hold")
    }

    // A pill the glass cannot follow hands over: one that appears or goes (the glass draws none, or one the bar no
    // longer has), another title view's (the glass shows the old one's contents), or any change when nobody follows.
    func test_aTitlePillTheGlassCannotFollow_handsOver() {
        let cases: [(held: NavigationBarTransitionTitlePill?, laidOut: NavigationBarTransitionTitlePill?, follows: Bool)] = [
            (nil, self.pill(x: 112.0), true),
            (self.pill(x: 112.0), nil, true),
            (self.pill(x: 112.0), self.pill(x: 112.0, signature: "another"), true),
            (self.pill(x: 100.0), self.pill(x: 112.0), false)
        ]
        for (index, entry) in cases.enumerated() {
            let hold = self.makeHold()
            var interruptions = 0
            var moves = 0
            hold.hold(true, interrupted: { interruptions += 1 }, titlePillMoved: entry.follows ? { moves += 1 } : nil, content: nil, rowFrame: CGRect(), titlePill: entry.held)
            hold.titlePillLaidOut(entry.laidOut)
            XCTAssertEqual(interruptions, 1, "case \(index)")
            XCTAssertEqual(moves, 0, "case \(index)")
            XCTAssertFalse(hold.isHeld, "case \(index)")
        }
    }

    // A hold nobody ends releases itself after 1.6 s times the duration factor.
    func test_aHoldNobodyEnds_releasesAfterItsCap() {
        let hold = self.makeHold()
        hold.durationFactor = { 2.0 }
        hold.hold(true, interrupted: {}, content: nil, rowFrame: CGRect())
        XCTAssertEqual(self.scheduled.last?.delay ?? 0.0, 3.2, accuracy: 1e-9)
        self.scheduled.last?.action()
        XCTAssertFalse(hold.isHeld)
    }

    // A cap scheduled for an earlier hold does not end a later one.
    func test_anOldCap_doesNotEndANewHold() {
        let hold = self.makeHold()
        hold.hold(true, interrupted: {}, content: nil, rowFrame: CGRect())
        let oldCap = self.scheduled.last?.action
        hold.hold(false, interrupted: nil, content: nil, rowFrame: CGRect())
        hold.hold(true, interrupted: {}, content: nil, rowFrame: CGRect())
        oldCap?()
        XCTAssertTrue(hold.isHeld)
    }

    // A bar that leaves the screen without returning in the same turn (another tab) hands over; one that leaves and
    // comes back at once (a finished swipe re-adds the screen) keeps the hold.
    func test_leavingTheHierarchy_handsOverUnlessItComesBack() {
        let hold = self.makeHold()
        hold.hold(true, interrupted: {}, content: nil, rowFrame: CGRect())
        hold.barLeftHierarchy()
        hold.barEnteredHierarchy()
        for entry in self.scheduled where entry.delay == 0.0 {
            entry.action()
        }
        self.scheduled.removeAll(where: { $0.delay == 0.0 })
        XCTAssertTrue(hold.isHeld)
        hold.barLeftHierarchy()
        self.scheduled.first(where: { $0.delay == 0.0 })?.action()
        XCTAssertFalse(hold.isHeld)
    }

    // `changed` reports every change of `isHeld`, so a bar re-applies its glass visibility.
    func test_changed_reportsEveryChange() {
        let hold = self.makeHold()
        var changes: [Bool] = []
        hold.changed = { [weak hold] in
            changes.append(hold?.isHeld ?? false)
        }
        hold.hold(true, interrupted: {}, content: nil, rowFrame: CGRect())
        hold.interrupt()
        XCTAssertEqual(changes, [true, false])
    }

    // While the header is lifted its list's scroll is held; the last offer is applied at put-back.
    func test_liftedScrollGate_holdsTheLastOffer() {
        var gate = NavigationBarLiftedScrollGate()
        XCTAssertTrue(gate.offer(10.0))
        gate.isClosed = true
        XCTAssertFalse(gate.offer(20.0))
        XCTAssertFalse(gate.offer(30.0))
        XCTAssertEqual(gate.open(currentOffset: 30.0), 30.0)
        XCTAssertFalse(gate.isClosed)
        XCTAssertNil(gate.open(currentOffset: 30.0))
    }

    // A layout the bar was given while lifted, with no scroll after it (a new title, a button change), is applied at
    // put-back at the current offset; with nothing asked for, put-back applies nothing.
    func test_liftedScrollGate_appliesALayoutAskedForWhileClosed() {
        var gate = NavigationBarLiftedScrollGate()
        gate.isClosed = true
        XCTAssertNil(gate.open(currentOffset: 12.0))
        gate.isClosed = true
        gate.noteLayout()
        XCTAssertEqual(gate.open(currentOffset: 12.0), 12.0)
        gate.noteLayout()
        XCTAssertNil(gate.open(currentOffset: 12.0), "a layout while open is the bar's own business")
    }

    // The capsules show the content the bar shows: the secondary one (an inline forum) from halfway in.
    func test_visibleContent_switchesAtHalfway() {
        let primary = self.content("Chats")
        let secondary = self.content("Forum")
        XCTAssertTrue(NavigationBarComponent.visibleContent(primary: primary, secondary: secondary, secondaryTransition: 0.49) === primary)
        XCTAssertTrue(NavigationBarComponent.visibleContent(primary: primary, secondary: secondary, secondaryTransition: 0.5) === secondary)
        XCTAssertTrue(NavigationBarComponent.visibleContent(primary: primary, secondary: nil, secondaryTransition: 1.0) === primary)
    }
}
