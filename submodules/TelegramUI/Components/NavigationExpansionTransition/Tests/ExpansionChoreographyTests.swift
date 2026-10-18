import XCTest
import UIKit
import Display
@testable import NavigationExpansionTransition

final class ExpansionChoreographyTests: XCTestCase {
    private func choreography(_ path: ExpansionPath = .origin) -> ExpansionChoreography {
        return ExpansionChoreography(geometry: makeExpansionGeometry(), path: path, duration: 0.55)
    }

    // At 0 everything is where the lower screen has it: the card is the pill, the circle is the avatar capsule.
    func test_atZero_cardIsThePill_circleIsTheCapsule() {
        let g = makeExpansionGeometry()
        let frame = self.choreography().frame(ExpansionClock(time: 0.0, isOpening: true), press: .none)
        XCTAssertEqual(frame.card, g.origin)
        XCTAssertEqual(frame.cardCornerRadii, CornerRadii(uniform: 22.0))
        XCTAssertEqual(frame.circle, g.companion)
        XCTAssertEqual(frame.photo?.width ?? 0.0, 38.0, accuracy: 1e-9)
        XCTAssertEqual(frame.photo?.midX ?? 0.0, g.companion!.midX, accuracy: 1e-9)
    }

    // At 1 the card is the screen with its corners and the circle sits on the profile's avatar, ring gone. (The
    // geometry tests take the frame without the circle's knock, which Task 4 adds and checks on its own.)
    func test_atOne_cardIsTheScreen_circleIsTheAvatar() {
        let g = makeExpansionGeometry()
        let frame = self.choreography().frame(ExpansionClock(time: 1.0, isOpening: true), press: .none, wobble: 0.0)
        XCTAssertEqual(frame.card, CGRect(origin: CGPoint(), size: g.screenSize))
        XCTAssertEqual(frame.cardCornerRadii, CornerRadii(uniform: 62.0))
        XCTAssertEqual(frame.circle?.width ?? 0.0, 100.0, accuracy: 1e-9)
        XCTAssertEqual(frame.circle?.midX ?? 0.0, g.avatar!.midX, accuracy: 1e-9)
        XCTAssertEqual(frame.circle?.midY ?? 0.0, g.avatar!.midY, accuracy: 1e-9)
        XCTAssertEqual(frame.photo, g.avatar)
    }

    // A screen whose corners differ (iPhone Duo's cover screen): the card still starts as the pill, a capsule in every
    // corner, and ends with each of the screen's own corners; on the way a hinge corner turns from the one into the other.
    func test_differingScreenCorners_cardStartsAsThePill_endsWithTheScreensCorners() {
        let c = ExpansionChoreography(geometry: makeExpansionGeometry(screenCornerRadii: duoCoverScreenCornerRadii), path: .origin, duration: 0.55)
        XCTAssertEqual(c.frame(ExpansionClock(time: 0.0, isOpening: true), press: .none).cardCornerRadii, CornerRadii(uniform: 22.0))
        XCTAssertEqual(c.frame(ExpansionClock(time: 1.0, isOpening: true), press: .none, wobble: 0.0).cardCornerRadii, duoCoverScreenCornerRadii)
        XCTAssertEqual(c.frame(ExpansionClock(time: 0.0, isOpening: false), press: .none).cardCornerRadii, CornerRadii(uniform: 22.0))
        var previous: CGFloat = 59.0
        for time: CGFloat in [0.2, 0.4, 0.6, 0.8] {
            let radii = c.frame(ExpansionClock(time: time, isOpening: true), press: .none, wobble: 0.0).cardCornerRadii
            XCTAssertEqual(radii.topRight, 59.0, accuracy: 1e-9, "t=\(time)")
            XCTAssertEqual(radii.topLeft, radii.bottomLeft, accuracy: 1e-9, "t=\(time)")
            XCTAssertLessThan(radii.topLeft, previous, "t=\(time)")
            XCTAssertGreaterThan(radii.topLeft, 8.0, "t=\(time)")
            previous = radii.topLeft
        }
    }

    func test_photoPath_differingScreenCorners_topCornersAreTheScreens() {
        let c = ExpansionChoreography(geometry: makeExpansionGeometry(screenCornerRadii: duoCoverScreenCornerRadii), path: .photo, duration: 0.55)
        let end = c.frame(ExpansionClock(time: 1.0, isOpening: true), press: .none)
        XCTAssertEqual(end.photoCornerRadii, CornerRadii(topLeft: 8.0, topRight: 59.0, bottomLeft: 0.0, bottomRight: 0.0))
    }

    // The sides and the top lead; the bottom follows the clock linearly (`capsuleRect`, ProfileMorph.swift:1392).
    func test_card_sidesAndTopLead_bottomFollows() {
        let g = makeExpansionGeometry()
        let frame = self.choreography().frame(ExpansionClock(time: 0.5, isOpening: true), press: .none, wobble: 0.0)
        XCTAssertEqual(frame.card.minX, g.origin.minX * (1.0 - 0.7), accuracy: 1e-6)
        XCTAssertEqual(frame.card.minY, g.origin.minY * (1.0 - 0.7), accuracy: 1e-6)
        XCTAssertEqual(frame.card.maxY, g.origin.maxY + (874.0 - g.origin.maxY) * 0.5, accuracy: 1e-6)
    }

    // The circle's arc: x leads (`1 − (1 − t)²`), y lags (`t^2.4`), so it goes in first, then down.
    func test_circle_goesInFirst_thenDown() {
        let g = makeExpansionGeometry()
        let frame = self.choreography().frame(ExpansionClock(time: 0.3, isOpening: true), press: .none)
        let slide: CGFloat = 1.0 - 0.7 * 0.7
        let lift: CGFloat = pow(0.3, 2.4)
        XCTAssertEqual(frame.photo?.midX ?? 0.0, g.companion!.midX + (g.avatar!.midX - g.companion!.midX) * slide, accuracy: 1e-6)
        XCTAssertEqual(frame.photo?.midY ?? 0.0, g.companion!.midY + (g.avatar!.midY - g.companion!.midY) * lift, accuracy: 1e-6)
    }

    // Past 0 (the close's overshoot) the card springs in place around its centre and rises (`bounce`, `rise`).
    func test_belowZero_cardLandsInPlace() {
        let g = makeExpansionGeometry()
        let frame = self.choreography().frame(ExpansionClock(time: -0.04, isOpening: false), press: .none)
        let landing: CGFloat = (100.0 - 38.0) / 38.0
        let scale = 1.0 - landing * 0.04
        XCTAssertEqual(frame.card.width, g.origin.width * scale, accuracy: 1e-6)
        XCTAssertEqual(frame.card.midX, g.origin.midX, accuracy: 1e-6)
        XCTAssertEqual(frame.card.midY, g.origin.midY - 140.0 * 0.04, accuracy: 1e-6)
    }

    // Without a companion the pill still expands; there is no circle.
    func test_noCompanion_noCircle() {
        var g = makeExpansionGeometry()
        g.companion = nil
        let frame = ExpansionChoreography(geometry: g, path: .origin, duration: 0.55).frame(ExpansionClock(time: 0.5, isOpening: true), press: .none)
        XCTAssertNil(frame.circle)
        XCTAssertNil(frame.photo)
    }

    // The drops merge from 30 pt apart, but never sooner than the lower screen's own shapes stand at rest: a pill
    // closer than that to the capsule (a long title, a narrow phone) would join it in a neck at both ends.
    func test_dropMergeSpacing_staysBelowTheRestGap() {
        var g = makeExpansionGeometry()
        XCTAssertEqual(g.dropMergeSpacing, 30.0, accuracy: 1e-9)
        g.origin = CGRect(x: g.companion!.minX - 10.0 - 250.0, y: g.origin.minY, width: 250.0, height: 44.0)
        XCTAssertLessThanOrEqual(g.dropMergeSpacing, 10.0)
        XCTAssertGreaterThan(g.dropMergeSpacing, 0.0)
        g.companion = nil
        XCTAssertEqual(g.dropMergeSpacing, 30.0, accuracy: 1e-9)
    }

    // The circle reaches the pill on opening (gap ≤ 6 pt): found once from the geometry, never on the photo path.
    func test_impactMoment_isWhereTheCircleReachesThePill() {
        let c = self.choreography()
        guard let moment = c.impactMoment else {
            XCTFail("no contact")
            return
        }
        let before = c.frame(ExpansionClock(time: moment - 1.0 / 600.0, isOpening: true), press: .none, wobble: 0.0)
        let at = c.frame(ExpansionClock(time: moment, isOpening: true), press: .none, wobble: 0.0)
        XCTAssertGreaterThan(before.circle!.minX - before.card.maxX, 6.0)
        XCTAssertLessThanOrEqual(at.circle!.minX - at.card.maxX, 6.0)
        XCTAssertNil(self.choreography(.photo).impactMoment)
    }

    // No wobble before contact or on closing; after it the card is knocked left, `−7·e^(−7τ)·sin(26τ)`.
    func test_wobble_onlyAfterContact_whileOpening() {
        let c = self.choreography()
        let moment = c.impactMoment!
        let quiet = c.frame(ExpansionClock(time: moment - 0.01, isOpening: true), press: .none)
        let still = c.frame(ExpansionClock(time: moment - 0.01, isOpening: true), press: .none, wobble: 0.0)
        XCTAssertEqual(quiet.card, still.card)
        let tau: CGFloat = 0.03
        let time = moment + tau / 0.55
        let knocked = c.frame(ExpansionClock(time: time, isOpening: true), press: .none)
        let unknocked = c.frame(ExpansionClock(time: time, isOpening: true), press: .none, wobble: 0.0)
        let expected = -7.0 * exp(-7.0 * tau) * sin(26.0 * tau)
        XCTAssertLessThan(expected, 0.0)
        let fillC = min(max(time, 0.0), 1.0)
        XCTAssertEqual(knocked.card.midX - unknocked.card.midX, expected * (1.0 - fillC * 0.7), accuracy: 1e-6)
        let closing = c.frame(ExpansionClock(time: time, isOpening: false), press: .none)
        let closingStill = c.frame(ExpansionClock(time: time, isOpening: false), press: .none, wobble: 0.0)
        XCTAssertEqual(closing.card, closingStill.card)
    }

    // The knock's oscillation is in clock time, so a trace of it is left at 1 while opening: under 0.5 pt, and none
    // when closing (the card is the screen there, where the hand-over happens).
    func test_wobble_leavesAtMostATraceAtRest() {
        let c = self.choreography()
        let screen = CGRect(origin: CGPoint(), size: makeExpansionGeometry().screenSize)
        let opening = c.frame(ExpansionClock(time: 1.0, isOpening: true), press: .none)
        XCTAssertEqual(opening.card.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(c.frame(ExpansionClock(time: 1.0, isOpening: false), press: .none).card, screen)
    }

    // A press still on the pill lifts the card by 16 pt across and lights it; both fade with the fill.
    func test_press_liftsAndLights_untilTheCardFills() {
        let g = makeExpansionGeometry()
        let c = self.choreography()
        let pressed = c.frame(ExpansionClock(time: 0.0, isOpening: true), press: ExpansionPress(origin: 1.0, companion: 0.0))
        XCTAssertEqual(pressed.card.width, g.origin.width + 16.0, accuracy: 1e-6)
        XCTAssertEqual(pressed.originLight, 1.0, accuracy: 1e-9)
        let filled = c.frame(ExpansionClock(time: 1.0, isOpening: true), press: ExpansionPress(origin: 1.0, companion: 1.0))
        XCTAssertEqual(filled.originLight, 0.0, accuracy: 1e-9)
        XCTAssertEqual(filled.companionLight, 0.0, accuracy: 1e-9)
    }

    // At 0 each label is the source layout, unscaled and whole; at 1 the destination layout.
    func test_labels_runFromTheSourceLayoutToTheDestinationLayout() {
        let g = makeExpansionGeometry()
        let c = self.choreography()
        let start = c.frame(ExpansionClock(time: 0.0, isOpening: true), press: .none)
        // At 1 on the closing clock: no knock's trace (see `test_wobble_leavesAtMostATraceAtRest`).
        let end = c.frame(ExpansionClock(time: 1.0, isOpening: false), press: .none)
        for (i, label) in g.labels.enumerated() {
            XCTAssertEqual(start.labels[i].center.x, label.sourceCenter.x, accuracy: 1e-6)
            XCTAssertEqual(start.labels[i].center.y, label.sourceCenter.y, accuracy: 1e-6)
            XCTAssertEqual(start.labels[i].sourceScale, 1.0, accuracy: 1e-9)
            XCTAssertEqual(start.labels[i].sourceAlpha, 1.0)
            XCTAssertEqual(start.labels[i].destinationAlpha, 0.0)
            XCTAssertEqual(end.labels[i].center.x, label.destinationCenter.x, accuracy: 1e-6)
            XCTAssertEqual(end.labels[i].center.y, label.destinationCenter.y, accuracy: 1e-6)
            XCTAssertEqual(end.labels[i].destinationScale, 1.0, accuracy: 1e-9)
            XCTAssertEqual(end.labels[i].destinationAlpha, 1.0)
            XCTAssertEqual(end.labels[i].sourceAlpha, 0.0)
        }
    }

    // Both layouts are scaled to one common width.
    func test_labels_shareOneWidth() {
        let g = makeExpansionGeometry()
        let frame = self.choreography().frame(ExpansionClock(time: 0.4, isOpening: true), press: .none)
        for (i, label) in g.labels.enumerated() {
            XCTAssertEqual(label.sourceSize.width * frame.labels[i].sourceScale, label.destinationSize.width * frame.labels[i].destinationScale, accuracy: 1e-6)
        }
    }

    // The windows (ProfileMorph.swift:1273-1278, 1311, 1343, 1350, 1560).
    func test_windows_openingAndClosing() {
        let c = self.choreography()
        func at(_ time: CGFloat, _ isOpening: Bool) -> ExpansionFrame {
            return c.frame(ExpansionClock(time: time, isOpening: isOpening), press: .none)
        }
        XCTAssertEqual(at(0.06, true).background, 0.0)
        XCTAssertEqual(at(0.45, true).background, 1.0)
        XCTAssertEqual(at(0.10, true).ink, 0.0)
        XCTAssertEqual(at(0.45, true).ink, 1.0)
        XCTAssertEqual(at(0.25, true).more, 0.0)
        XCTAssertEqual(at(0.60, true).more, 1.0)
        // Closing windows apply to 1 − t: the card stays coloured while it shrinks.
        XCTAssertEqual(at(0.70, false).background, 1.0)
        XCTAssertEqual(at(0.15, false).background, 0.0)
        XCTAssertEqual(at(0.86, false).more, 0.0)
        XCTAssertEqual(at(0.70, true).glass, 1.0)
        XCTAssertEqual(at(0.97, true).glass, 0.0, accuracy: 1e-9)
        XCTAssertEqual(at(0.5, true).tint, 0.55 * 0.5, accuracy: 1e-9)
        XCTAssertEqual(at(0.6, true).pattern, 0.0)
        XCTAssertEqual(at(1.0, true).pattern, 1.0)
        XCTAssertEqual(at(0.45, true).list, 0.0)
        XCTAssertEqual(at(0.90, true).list, 1.0)
        XCTAssertEqual(at(0.99, true).flooded, 0.84375, accuracy: 1e-6)
        XCTAssertEqual(at(1.0, true).flooded, 1.0)
    }

    // Action buttons one by one, 0.04 apart, rising 14 pt from 70 %; on closing all together in the first 0.3.
    func test_appearing_staggeredIn_togetherOut() {
        let c = self.choreography()
        let frame = c.frame(ExpansionClock(time: 0.55, isOpening: true), press: .none)
        XCTAssertGreaterThan(frame.appearing[0].alpha, frame.appearing[1].alpha)
        XCTAssertGreaterThan(frame.appearing[1].alpha, frame.appearing[2].alpha)
        XCTAssertEqual(frame.appearing[3].alpha, 0.0)
        XCTAssertEqual(frame.appearing[3].offset, 14.0)
        XCTAssertEqual(frame.appearing[3].scale, 0.7)
        let closing = c.frame(ExpansionClock(time: 0.85, isOpening: false), press: .none)
        XCTAssertEqual(closing.appearing[0].alpha, closing.appearing[3].alpha)
        XCTAssertEqual(c.frame(ExpansionClock(time: 0.7, isOpening: false), press: .none).appearing[0].alpha, 0.0)
    }

    // The page below the header (its buttons and list) hangs off the status, as the prototype's actions and info card
    // hang off `seenY` (ProfileMorph.swift:964-971, 1506): it stands as far from its resting place as the status does,
    // all the way in and through the spring's overshoot past 1, on either path.
    func test_page_ridesTheStatus_overshootIncluded() {
        let g = makeExpansionGeometry()
        for path in [ExpansionPath.origin, .photo] {
            let c = self.choreography(path)
            let rest = path == .photo ? g.labels[1].photoCenter!.y : g.labels[1].destinationCenter.y
            for time: CGFloat in [0.0, 0.3, 0.6, 0.9, 1.0, 1.03, 1.06] {
                let frame = c.frame(ExpansionClock(time: time, isOpening: true), press: .none)
                XCTAssertEqual(frame.page, frame.labels[1].center.y - rest, accuracy: 1e-6, "\(path) t=\(time)")
            }
            XCTAssertEqual(c.frame(ExpansionClock(time: 0.0, isOpening: true), press: .none).page, g.labels[1].sourceCenter.y - rest, accuracy: 1e-6, "\(path): it starts where the chat's status is")
            XCTAssertEqual(c.frame(ExpansionClock(time: 1.0, isOpening: true), press: .none).page, 0.0, accuracy: 0.5, "\(path): at rest at 1 (a trace of the knock at most)")
            XCTAssertGreaterThan(c.frame(ExpansionClock(time: 1.06, isOpening: true), press: .none).page, 5.0, "\(path): past its place on the overshoot")
        }
        // Like the prototype's, it takes neither the press's lift nor the close's landing, which only the labels have.
        let c = self.choreography()
        let landing = c.frame(ExpansionClock(time: -0.04, isOpening: false), press: .none)
        XCTAssertEqual(landing.page, c.frame(ExpansionClock(time: 0.0, isOpening: false), press: .none).page, accuracy: 1e-6)
        XCTAssertNotEqual(landing.labels[1].center.y - g.labels[1].destinationCenter.y, landing.page, accuracy: 1.0)
        let pressed = c.frame(ExpansionClock(time: 0.2, isOpening: true), press: ExpansionPress(origin: 1.0, companion: 0.0))
        XCTAssertEqual(pressed.page, c.frame(ExpansionClock(time: 0.2, isOpening: true), press: .none).page, accuracy: 1e-6)
    }

    // The photo path ends in the expanded photo: square-cornered at the bottom, the screen's corners at the top.
    func test_photoPath_endsInTheExpandedPhoto() {
        let g = makeExpansionGeometry()
        let c = self.choreography(.photo)
        let end = c.frame(ExpansionClock(time: 1.0, isOpening: true), press: .none)
        XCTAssertEqual(end.photo, g.photo)
        XCTAssertEqual(end.photoCornerRadii, CornerRadii(topLeft: 62.0, topRight: 62.0, bottomLeft: 0.0, bottomRight: 0.0))
        XCTAssertEqual(end.labels[0].center.x, g.labels[0].photoCenter!.x, accuracy: 1e-6)
        XCTAssertEqual(end.labels[0].center.y, g.labels[0].photoCenter!.y, accuracy: 1e-6)
        XCTAssertEqual(end.labels[0].destinationScale, 1.0, accuracy: 1e-9)
    }

    // The growth waits for the gate (opening: (t − 0.05)/0.95) and is geometric: slow, then fast.
    func test_photoPath_growsGeometricallyBehindTheGate() {
        let c = self.choreography(.photo)
        let early = c.frame(ExpansionClock(time: 0.05, isOpening: true), press: .none)
        XCTAssertEqual(early.photo?.width ?? 0.0, 38.0 + (100.0 - 38.0) * 0.05, accuracy: 1e-6, "the gate is shut: still the flying circle")
        let half = c.frame(ExpansionClock(time: 0.525, isOpening: true), press: .none)
        let g = makeExpansionGeometry()
        let circle: CGFloat = 38.0 + (100.0 - 38.0) * 0.525
        let growth = ExpansionCurve.geometric(0.5, ratio: 6.0)
        XCTAssertEqual(half.photo?.width ?? 0.0, circle + (g.photo!.width - circle) * growth, accuracy: 0.5)
    }

    // No wobble on the photo path.
    func test_photoPath_noImpact() {
        XCTAssertNil(self.choreography(.photo).impactMoment)
    }

    /// No element moves more than `bound` points between two of 400 samples from −0.06 to 1.06, on any path and either
    /// direction, and nothing is NaN.
    func test_noJumps_onAnyPath() {
        let g = makeExpansionGeometry()
        for (path, isOpening) in [(ExpansionPath.origin, true), (.origin, false), (.photo, true), (.photo, false)] {
            let c = ExpansionChoreography(geometry: g, path: path, duration: 0.55)
            var previous: ExpansionFrame?
            for i in 0 ... 400 {
                let t = -0.06 + 1.12 * CGFloat(i) / 400.0
                let frame = c.frame(ExpansionClock(time: t, isOpening: isOpening), press: .none)
                let values = [frame.card.minX, frame.card.minY, frame.card.maxX, frame.card.maxY, frame.circle?.midX ?? 0.0, frame.circle?.midY ?? 0.0, frame.photo?.width ?? 0.0, frame.page] + frame.labels.flatMap { [$0.center.x, $0.center.y] }
                XCTAssertFalse(values.contains(where: { $0.isNaN }), "\(path) \(isOpening) t=\(t)")
                if let previous {
                    let before = [previous.card.minX, previous.card.minY, previous.card.maxX, previous.card.maxY, previous.circle?.midX ?? 0.0, previous.circle?.midY ?? 0.0, previous.photo?.width ?? 0.0, previous.page] + previous.labels.flatMap { [$0.center.x, $0.center.y] }
                    for (a, b) in zip(before, values) {
                        XCTAssertLessThan(abs(a - b), 24.0, "\(path) \(isOpening) t=\(t)")
                    }
                    for (p, f) in zip(previous.labels, frame.labels) {
                        XCTAssertGreaterThanOrEqual(f.sourceAlpha + f.destinationAlpha, min(1.0, p.sourceAlpha + p.destinationAlpha) - 0.31, "\(path) t=\(t)")
                    }
                }
                previous = frame
            }
        }
    }
}
