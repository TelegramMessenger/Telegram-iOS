#if canImport(UIKit)
import XCTest
import UIKit
import QuartzCore
@testable import RichTextEditorUIKit

final class SpoilerDustViewTests: XCTestCase {
    func test_init_doesNotCrash_andIsNonInteractive() {
        let v = SpoilerDustView()
        XCTAssertFalse(v.isUserInteractionEnabled)
        XCTAssertFalse(v.isRevealed)
    }

    func test_realSpeckleAsset_isBundled() {
        // Telegram's actual 4x4 particle texture must ship in the UIKit resource bundle — it's what makes the
        // dust read as fine shimmer instead of coarse blobs. A missing resource silently falls back to a dot.
        XCTAssertNotNil(SpoilerDustView.bundledSpeckleForTesting,
                        "textSpeckle_Normal.png must be bundled via Package.swift resources")
    }

    func test_emitterBehaviorPrivateAPI_isAvailable() {
        // Canary: if a future OS removes the private CAEmitterBehavior, fail here (not silently in the UI).
        let behavior = CAEmitterCell.createEmitterBehavior(type: "simpleAttractor")
        XCTAssertNotNil(behavior)
    }

    func test_update_setsEmitterGeometryAndBirthRate() {
        let v = SpoilerDustView()
        v.update(size: CGSize(width: 100, height: 20), color: .label,
                 lineRects: [CGRect(x: 0, y: 0, width: 100, height: 20)],
                 wordRects: [CGRect(x: 0, y: 0, width: 40, height: 20), CGRect(x: 50, y: 0, width: 40, height: 20)])
        XCTAssertEqual(v.emitterLayerForTesting.frame.size, CGSize(width: 100, height: 20))
        XCTAssertGreaterThan(v.emitterLayerForTesting.birthRateForCellForTesting, 0)
    }

    func test_dissolve_marksRevealed_andRemovesOnCompletion() {
        let host = UIView()
        let v = SpoilerDustView()
        v.update(size: CGSize(width: 100, height: 20), color: .label,
                 lineRects: [CGRect(x: 0, y: 0, width: 100, height: 20)], wordRects: [CGRect(x: 0, y: 0, width: 100, height: 20)])
        host.addSubview(v)
        let done = expectation(description: "removed")
        v.dissolve(explodingAt: CGPoint(x: 10, y: 10)) { done.fulfill() }
        XCTAssertTrue(v.isRevealed)
        wait(for: [done], timeout: 2.0)
        XCTAssertNil(v.superview)
    }

    func test_pointInside_onlyHitsLineRects_whenHidden() {
        let v = SpoilerDustView()
        v.update(size: CGSize(width: 100, height: 20), color: .label,
                 lineRects: [CGRect(x: 0, y: 0, width: 40, height: 20)], wordRects: [CGRect(x: 0, y: 0, width: 40, height: 20)])
        XCTAssertTrue(v.point(inside: CGPoint(x: 10, y: 10), with: nil))
        XCTAssertFalse(v.point(inside: CGPoint(x: 80, y: 10), with: nil))
    }

    func test_dissolve_isIdempotent_secondCallCompletesSynchronously() {
        let v = SpoilerDustView()
        v.update(size: CGSize(width: 50, height: 20), color: .label,
                 lineRects: [CGRect(x: 0, y: 0, width: 50, height: 20)], wordRects: [CGRect(x: 0, y: 0, width: 50, height: 20)])
        v.dissolve(explodingAt: nil) {}
        var secondFired = false
        v.dissolve(explodingAt: nil) { secondFired = true }   // already revealed → completion fires synchronously
        XCTAssertTrue(secondFired)
    }
}
#endif
