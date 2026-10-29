import XCTest
import UIKit
import StaticGlassBackground

final class StaticGlassBackgroundTests: XCTestCase {
    // Each in-chat shape takes the asset captured for it: reaction pills (30pt) and inline buttons or the comments row
    // (42pt) a capsule, the share button a circle or, with an ad's second button, a vertical capsule. Another height
    // takes the nearest capsule, scaled to it.
    func testShapesPickTheirAssets() {
        XCTAssertEqual(staticGlassAssetChoice(size: CGSize(width: 60.0, height: 30.0), cornerRadius: 15.0), StaticGlassAssetChoice(shape: .capsuleR15, scale: 1.0))
        XCTAssertEqual(staticGlassAssetChoice(size: CGSize(width: 200.0, height: 42.0), cornerRadius: 21.0), StaticGlassAssetChoice(shape: .capsuleR21, scale: 1.0))
        XCTAssertEqual(staticGlassAssetChoice(size: CGSize(width: 30.0, height: 30.0), cornerRadius: 15.0), StaticGlassAssetChoice(shape: .circleR15, scale: 1.0))
        XCTAssertEqual(staticGlassAssetChoice(size: CGSize(width: 30.0, height: 60.0), cornerRadius: 15.0), StaticGlassAssetChoice(shape: .verticalCapsuleR15, scale: 1.0))
        XCTAssertEqual(staticGlassAssetChoice(size: CGSize(width: 80.0, height: 26.0), cornerRadius: 13.0), StaticGlassAssetChoice(shape: .capsuleR15, scale: 26.0 / 30.0))
        XCTAssertEqual(staticGlassAssetChoice(size: CGSize(width: 120.0, height: 40.0), cornerRadius: 20.0), StaticGlassAssetChoice(shape: .capsuleR21, scale: 40.0 / 42.0))
    }

    // A shape narrower than its asset's two ends is cut from them (the left end's half and the right end's half) rather
    // than squeezed, which would distort the ends.
    func testNarrowShapesAreCutFromTheEnds() {
        // capsule r15: ends 90px each with a 3px middle in a 165px frame (scale 3)
        XCTAssertFalse(staticGlassNeedsCutting(shapeWidth: 55.0, assetFrameWidth: 165, scale: 3))
        XCTAssertFalse(staticGlassNeedsCutting(shapeWidth: 54.0, assetFrameWidth: 165, scale: 3))
        XCTAssertTrue(staticGlassNeedsCutting(shapeWidth: 53.5, assetFrameWidth: 165, scale: 3))
        XCTAssertTrue(staticGlassNeedsCutting(shapeWidth: 30.0, assetFrameWidth: 165, scale: 3))
    }

    // The asset format the generator writes: "SGL1", sizes, scale, the shape's frame and the cap insets, then raw DEFLATE
    // of premultiplied RGBA, kept as it is (dark glass is brighter than its alpha).
    func testAssetsParse() throws {
        let pixels: [UInt8] = [37, 37, 37, 15, 0, 0, 0, 0]
        let body = try (Data(pixels) as NSData).compressed(using: .zlib) as Data
        var data = Data("SGL1".utf8)
        for value: UInt16 in [2, 1] {
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init))
        }
        data.append(3)
        for value: UInt16 in [1, 0, 1, 1, 0, 0, 0, 0] {
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init))
        }
        data.append(body)

        let asset = try XCTUnwrap(StaticGlassAssetData(data: data))
        XCTAssertEqual(asset.width, 2)
        XCTAssertEqual(asset.height, 1)
        XCTAssertEqual(asset.scale, 3)
        XCTAssertEqual(asset.frame, CGRect(x: 1.0, y: 0.0, width: 1.0, height: 1.0))
        XCTAssertEqual(asset.capInsets, UIEdgeInsets())
        XCTAssertEqual(Array(asset.pixels), pixels)
        XCTAssertNil(StaticGlassAssetData(data: Data("SGL0".utf8) + data.dropFirst(4)))
    }

    // A styled tint lies over the shape at its alpha, as the glass lays it over its panel: over a white page a
    // primary-blue capsule's interior is 0.15 of the panel's white and 0.85 of the blue.
    func testTintsLieOverTheShape() {
        let panel: [UInt8] = [156, 156, 156, 157]
        let tinted = staticGlassTintedPixel(panel, coverage: 1.0, tint: (0.0, 122.0 / 255.0, 1.0, 0.85))
        let alpha = CGFloat(tinted[3]) / 255.0
        let overWhite = (0 ..< 3).map { Int((CGFloat(tinted[$0]) + (1.0 - alpha) * 255.0).rounded()) }
        XCTAssertEqual(overWhite, [38, 142, 255])
        XCTAssertEqual(staticGlassTintedPixel(panel, coverage: 0.0, tint: (0.0, 122.0 / 255.0, 1.0, 0.85)), panel)
    }
    
    // Tinted glass lightens toward its edge (measured: by 42% at the edge, fading over about 4px at 3x) and, in light
    // mode, reaches 2px past the frame; distances are to the capsule's outline.
    func testTintedRimsLightenTowardTheEdge() {
        let frame = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 30.0)
        XCTAssertEqual(staticGlassCapsuleDistance(CGPoint(x: 30.0, y: 15.0), frame: frame), 15.0, accuracy: 0.001)
        XCTAssertEqual(staticGlassCapsuleDistance(CGPoint(x: 30.0, y: 0.0), frame: frame), 0.0, accuracy: 0.001)
        XCTAssertEqual(staticGlassCapsuleDistance(CGPoint(x: -1.0, y: 15.0), frame: frame), -1.0, accuracy: 0.001)
        XCTAssertEqual(staticGlassCapsuleDistance(CGPoint(x: 2.0, y: 2.0), frame: frame), 15.0 - (13.0 * 13.0 * 2.0).squareRoot(), accuracy: 0.001)
        XCTAssertEqual(staticGlassTintRimGain(distance: 0.0), 0.42, accuracy: 0.001)
        XCTAssertEqual(staticGlassTintRimGain(distance: 0.5), 0.36, accuracy: 0.001)
        XCTAssertEqual(staticGlassTintRimGain(distance: 20.0), 0.0)
        XCTAssertEqual(staticGlassTintOutset(isDark: false), 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(staticGlassTintOutset(isDark: true), 0.0)
    }
    
    // A shape shorter along its run than its asset's two ends is cut from them along that run: a 37pt-wide inline button
    // (seven to a row) takes the vertical capsule, cut across its rows, not squeezed into flattened ends.
    func testNarrowShapesAreCutAlongTheirRun() {
        let column = Data((0 ..< 8).flatMap { row in [UInt8](repeating: UInt8(row * 10), count: 4) })
        let vertical = staticGlassCutPixels(column, width: 1, height: 8, frame: CGRect(x: 0.0, y: 1.0, width: 1.0, height: 6.0), vertical: true, shapeLength: 4)
        XCTAssertEqual(vertical.width, 1)
        XCTAssertEqual(vertical.height, 6)
        XCTAssertEqual(vertical.frame, CGRect(x: 0.0, y: 1.0, width: 1.0, height: 4.0))
        XCTAssertEqual(stride(from: 0, to: vertical.pixels.count, by: 4).map { vertical.pixels[$0] }, [0, 10, 20, 50, 60, 70])
        
        let row = Data((0 ..< 8).flatMap { column in [UInt8](repeating: UInt8(column * 10), count: 4) })
        let horizontal = staticGlassCutPixels(row, width: 8, height: 1, frame: CGRect(x: 1.0, y: 0.0, width: 6.0, height: 1.0), vertical: false, shapeLength: 4)
        XCTAssertEqual(horizontal.width, 6)
        XCTAssertEqual(horizontal.frame, CGRect(x: 1.0, y: 0.0, width: 4.0, height: 1.0))
        XCTAssertEqual(stride(from: 0, to: horizontal.pixels.count, by: 4).map { horizontal.pixels[$0] }, [0, 10, 20, 50, 60, 70])
        
        // 37x42: the vertical capsule scaled to 37pt; 42pt is shorter than its ends (165px less 3 at 3x / 1.23)
        let choice = staticGlassAssetChoice(size: CGSize(width: 37.0, height: 42.0), cornerRadius: 21.0)
        XCTAssertEqual(choice, StaticGlassAssetChoice(shape: .verticalCapsuleR15, scale: 37.0 / 30.0))
        XCTAssertTrue(staticGlassNeedsCutting(shapeWidth: 42.0 / choice.scale, assetFrameWidth: 165, scale: 3))
    }
}
