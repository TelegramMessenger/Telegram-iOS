import UIKit
import XCTest
import WalletContext

final class WalletStickerPlacementTests: XCTestCase {
    func testFullCardRejectsBothManualAndAutomaticPlacement() {
        let solver = WalletStickerPlacement(size: CGSize(width: 370, height: 220),
            obstacles: [CGRect(x: 0, y: 0, width: 370, height: 220)], occupants: [])
        XCTAssertNil(solver.drop(near: CGPoint(x: 150, y: 140), scale: 1))
        XCTAssertNil(solver.spread(aim: nil, scale: 1))
    }
    func testSequentialFlightsReserveTheirDestinations() throws {
        let size = CGSize(width: 370, height: 220)
        var occupants: [WalletContext.CardSticker] = []
        for index in 0..<8 {
            let solver = WalletStickerPlacement(size: size,
                obstacles: [CGRect(x: 20, y: 80, width: 220, height: 45), CGRect(x: 280, y: 75, width: 55, height: 50)], occupants: occupants)
            guard let spot = solver.spread(aim: nil, scale: 1) else { break }
            XCTAssertTrue(solver.fits(spot.center, scale: spot.scale))
            XCTAssertGreaterThanOrEqual(spot.scale, WalletStickerPlacement.minimum)
            XCTAssertLessThanOrEqual(spot.scale, WalletStickerPlacement.maximum)
            occupants.append(WalletContext.CardSticker(gift: .init(address: "g\(index)", name: "Gift", kind: .gift),
                x: Double(spot.center.x / size.width), y: Double(spot.center.y / size.height), angle: 0,
                scale: Double(spot.scale), geometryVersion: 1))
        }
        XCTAssertGreaterThan(occupants.count, 2)
    }
    func testNearEdgePlacementRemainsEntirelyInsideCard() throws {
        let solver = WalletStickerPlacement(size: CGSize(width: 370, height: 220), obstacles: [], occupants: [])
        let spot = try XCTUnwrap(solver.drop(near: CGPoint(x: -10, y: 110), scale: 1.1))
        XCTAssertTrue(solver.fits(spot.center, scale: spot.scale))
        XCTAssertGreaterThanOrEqual(spot.center.x, solver.side * spot.scale / 2)
    }
    func testCutoutKeepsExteriorTransparentAndFillsEnclosedHoles() {
        let side = 96
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for y in 22..<74 { for x in 22..<74 where !(38..<58).contains(x) || !(38..<58).contains(y) {
            pixels[(y * side + x) * 4 + 3] = 255
        }}
        XCTAssertTrue(pixels.withUnsafeMutableBufferPointer { walletGiftStickerCutout(bytes: $0.baseAddress!, side: side) })
        XCTAssertEqual(pixels[3], 0)
        XCTAssertEqual(pixels[(48 * side + 48) * 4 + 3], 255)
        XCTAssertEqual(pixels[(30 * side + 30) * 4], 255)
    }
}

final class WalletStickerSpringTests: XCTestCase {
    func testContactPushesCardInwardThenReturnsToRest() {
        let spring = WalletStickerSpring(1, 260, 0.85)
        spring.velocity = -0.28
        spring.step(1 / 60)
        XCTAssertLessThan(spring.value, 1)
        for _ in 0..<300 { spring.step(1 / 60) }
        XCTAssertTrue(spring.resting(0.00002))
        XCTAssertEqual(spring.value, 1, accuracy: 0.00002)
    }
    func testReferenceSpringIsConsistentAcrossRefreshRatesAndAccumulatesImpulses() {
        let a = WalletStickerSpring(0, 170, 0.42)
        let b = WalletStickerSpring(0, 170, 0.42)
        a.velocity = 3.4; b.velocity = 3.4
        for _ in 0..<30 { a.step(1 / 60) }
        for _ in 0..<60 { b.step(1 / 120) }
        XCTAssertEqual(a.value, b.value, accuracy: 0.001)
        let velocity = a.velocity
        a.velocity += 1.4
        XCTAssertEqual(a.velocity, velocity + 1.4, accuracy: 0.00001)
        for _ in 0..<300 { a.step(1 / 60) }
        XCTAssertTrue(a.resting(0.00002))
    }
}

final class WalletCardStyleTransitionTests: XCTestCase {
    func testApplyUsesReferenceEaseOutAndIndependentPatternClock() {
        let frame = WalletCardStyleTransition(fraction: 0.5, removing: false)
        XCTAssertEqual(frame.progress, 0.9375, accuracy: 0.000001)
        XCTAssertEqual(frame.textMix, 1)
        XCTAssertEqual(frame.patternTime, 1)
        let early = WalletCardStyleTransition(fraction: 0.1, removing: false)
        XCTAssertEqual(early.progress, 0.3439, accuracy: 0.000001)
        XCTAssertEqual(early.patternTime, 0.105 / 0.45, accuracy: 0.000001)
        XCTAssertGreaterThan(early.textMix, 0)
        XCTAssertLessThan(early.textMix, 1)
    }
    func testRemovalInhalesThenContractsToOrigin() {
        let size = CGSize(width: 370, height: 220)
        let origin = CGPoint(x: 120, y: 80)
        let early = WalletCardStyleTransition(fraction: 0.3, removing: true)
        XCTAssertEqual(early.progress, 0)
        XCTAssertGreaterThan(early.contraction, 1)
        XCTAssertEqual(early.textMix, 0)
        XCTAssertEqual(early.radius(origin: origin, size: size), WalletCardStyleTransition(fraction: 0, removing: true).radius(origin: origin, size: size), accuracy: 0.000001)
        let late = WalletCardStyleTransition(fraction: 0.8, removing: true)
        XCTAssertGreaterThan(late.progress, 0)
        XCTAssertLessThan(late.contraction, 1)
        let done = WalletCardStyleTransition(fraction: 1, removing: true)
        XCTAssertEqual(done.progress, 1, accuracy: 0.000001)
        XCTAssertEqual(done.radius(origin: origin, size: size), 0, accuracy: 0.000001)
        XCTAssertEqual(done.patternTime, 1)
    }
    func testWaveCoversFarthestCornerAndRestorationIsComplete() {
        let size = CGSize(width: 370, height: 220)
        let frame = WalletCardStyleTransition(fraction: 1, removing: false)
        for origin in [CGPoint.zero, CGPoint(x: 185, y: 110), CGPoint(x: 320, y: 180)] {
            let corners = [CGPoint.zero, CGPoint(x: 370, y: 0), CGPoint(x: 0, y: 220), CGPoint(x: 370, y: 220)]
            let far = corners.map { hypot($0.x-origin.x, $0.y-origin.y) }.max()!
            XCTAssertEqual(frame.radius(origin: origin, size: size), far * 1.05, accuracy: 0.000001)
        }
        XCTAssertEqual(frame.textMix, 1)
        XCTAssertEqual(frame.patternTime, 1)
    }
}
