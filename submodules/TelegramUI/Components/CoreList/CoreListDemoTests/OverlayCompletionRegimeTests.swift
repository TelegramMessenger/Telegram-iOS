import XCTest
import UIKit
@testable import CoreListDemo

/// Establishes WHICH completion regime the other overlay probes actually exercise.
///
/// `CoreAnimationCompiler.install` opens with `guard emitsAnimations else { return }` — it returns
/// before `CATransaction.setCompletionBlock(completion)`. `VirtualListFixture` defaults to
/// `emitsCA: false` and never supplies an `animationInstaller`, so under test the completion passed
/// to `install` is discarded on the floor.
///
/// Production runs with `emitsAnimations: true`, where the completion is a CATransaction completion
/// block. If carries drain under test anyway, they drain via some path OTHER than
/// `finishViewportGeneration` — which would mean every "eliminated" sequence was only eliminated
/// under a regime that does not match production, and the completion-delivery failure mode is
/// structurally invisible to the suite.
final class OverlayCompletionRegimeTests: XCTestCase {
    func testCarriesDrainWithoutAnyCompletionBeingDelivered() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400),
                                         emitsCA: false)
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        XCTAssertGreaterThan(fixture.viewportCarryViews.count, 0,
                             "expected carries to be parked mid-transition")

        fixture.advance(by: 10)
        fixture.flushScheduler()

        // Record, don't assume. Whatever this shows is the regime the rest of the suite runs under.
        let carriesAfterSettle = fixture.viewportCarryViews.count
        let overlayAfterSettle = fixture.listView.exitOverlay.subviews.count
            + fixture.listView.crossingOverlay.subviews.count
        print("[regime] emitsCA=false → carries after settle: \(carriesAfterSettle), "
              + "overlay subviews: \(overlayAfterSettle)")

        XCTAssertEqual(carriesAfterSettle, 0,
                       "carries survived a full settle with emitsCA=false — the suite's other "
                       + "overlay assertions are measuring a regime where completions never fire")
        XCTAssertEqual(overlayAfterSettle, 0)
    }
}
