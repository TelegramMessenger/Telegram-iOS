import XCTest
import UIKit
@testable import CoreListDemo

final class UIKitScrollEngineTests: XCTestCase {

    private func makeEngine(viewport: CGSize = CGSize(width: 390, height: 800))
        -> (UIKitScrollEngine, UIScrollView) {
        let sv = UIScrollView(frame: CGRect(origin: .zero, size: viewport))
        let engine = UIKitScrollEngine(scrollView: sv)
        return (engine, sv)
    }

    func test_contentHost_isScrollView() {
        let (engine, sv) = makeEngine()
        XCTAssertTrue(engine.contentHost === sv)
    }

    func test_setOffset_writesOffset_andSuppressesOnScroll() {
        let (engine, _) = makeEngine()
        engine.setEdges(min: nil, max: nil)   // contentSize = the open canvas, no clamp
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        engine.setOffset(120)
        XCTAssertEqual(engine.offset, 120, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic setOffset must not fire onScroll")
    }

    func test_applyShift_addsToOffset_andSuppressesOnScroll() {
        let (engine, _) = makeEngine()
        engine.setEdges(min: nil, max: nil)
        engine.setOffset(100)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        engine.applyShift(30)
        XCTAssertEqual(engine.offset, 130, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic applyShift must not fire onScroll")
    }

    func test_userScroll_firesOnScroll() {
        let (engine, sv) = makeEngine()
        engine.setEdges(min: nil, max: nil)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        // Simulate a user-driven change (NOT via setOffset) + the delegate callback,
        // exactly how TestableScrollView drives it.
        sv.bounds.origin.y = 250
        engine.scrollViewDidScroll(sv)
        XCTAssertEqual(fired.last, 250)
    }

    func test_setEdges_bothBounded_tallContent_contentSizeIsMaxPlusViewport() {
        let (engine, sv) = makeEngine(viewport: CGSize(width: 390, height: 800))
        engine.setEdges(min: 0, max: 300)       // max scroll offset 300, viewport 800
        XCTAssertEqual(sv.contentSize.height, 1100, accuracy: 0.001)  // 300 + 800
        XCTAssertEqual(sv.contentSize.width, 390, accuracy: 0.001)
    }

    func test_setEdges_bothBounded_shortContent_appliesViewportFloor() {
        let (engine, sv) = makeEngine(viewport: CGSize(width: 390, height: 800))
        engine.setEdges(min: 0, max: -500)      // content shorter than viewport → negative max
        XCTAssertEqual(sv.contentSize.height, 800, accuracy: 0.001)  // floored to viewport
    }

    func test_setEdges_eitherOpen_usesOpenCanvas() {
        let (engine, sv) = makeEngine()
        engine.setEdges(min: 0, max: nil)
        XCTAssertEqual(sv.contentSize.height, 10_000_000, accuracy: 0.001)
        engine.setEdges(min: nil, max: 300)
        XCTAssertEqual(sv.contentSize.height, 10_000_000, accuracy: 0.001)
        engine.setEdges(min: nil, max: nil)
        XCTAssertEqual(sv.contentSize.height, 10_000_000, accuracy: 0.001)
    }

    func test_containerOrigin_parksTopBottomNeither() {
        let (engine, _) = makeEngine()          // viewport 390x800
        let h: CGFloat = 1000
        // Top loaded → glued to 0 (also wins when both edges are loaded, i.e. small content).
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: false), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: true), 0, accuracy: 0.001)
        // Bottom-only → far canvas minus the window height (room above): 10M - h.
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: true), 10_000_000 - h, accuracy: 0.001)
        // Neither → centred in the canvas (room both ways): 10M/2 - h/2.
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: false), 10_000_000 / 2 - h / 2, accuracy: 0.001)
    }
}
