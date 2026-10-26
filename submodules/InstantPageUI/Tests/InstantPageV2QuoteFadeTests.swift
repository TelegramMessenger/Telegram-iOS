import XCTest
import UIKit
@testable import InstantPageUI

/// The collapsed-quote fade tile, ported from `InteractiveTextComponent`'s `generateBlockMaskImage()`.
///
/// Worth pinning because the tile is written in blend modes — a `.copy` radial that REPLACES the
/// opaque fill, then a `.destinationIn` linear that multiplies alpha over the bottom strip. Get
/// either mode wrong and the result is still a plausible-looking greyscale image; it just masks the
/// wrong pixels, and the only symptom is text that fades where it should not (or does not fade at
/// all) inside a collapsed quote.
final class InstantPageV2QuoteFadeTests: XCTestCase {
    /// Alpha of the mask tile at a point, in top-left-origin image points.
    private func alpha(atX x: Int, y: Int) throws -> Int {
        let image = try XCTUnwrap(instantPageV2QuoteFadeMaskImage.cgImage)
        let width = Int(instantPageV2QuoteFadeTileSize.width)
        let height = Int(instantPageV2QuoteFadeTileSize.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Redrawn at 1x regardless of the device scale the tile was generated at, so the sample
        // coordinates below are plain image points.
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Int(pixels[(y * width + x) * 4 + 3])
    }

    func test_tileIsOpaqueWhereNothingIsCarvedOut() throws {
        // The top-left pixel is load-bearing beyond its own colour: it is the one the nine-part
        // stretch replicates across the whole quote, so a transparent one would mask out the
        // entire quote rather than just its bottom edge.
        XCTAssertEqual(try self.alpha(atX: 2, y: 2), 255, "the stretched top-left pixel must be opaque")
        XCTAssertEqual(try self.alpha(atX: 55, y: 2), 255, "the top-trailing corner is outside the radial hole")
        XCTAssertEqual(try self.alpha(atX: 2, y: 20), 255, "above the bottom strip, away from the hole")
    }

    func test_bottomStripFadesOut() throws {
        let height = Int(instantPageV2QuoteFadeTileSize.height)
        XCTAssertLessThan(try self.alpha(atX: 2, y: height - 1), 16, "the very bottom is transparent")
        XCTAssertGreaterThan(try self.alpha(atX: 2, y: height - 1 - 8), 200, "8pt up, the fade is over")
    }

    /// The hole the expand chevron sits in — centred on the bottom edge, 20pt in from the trailing
    /// side, which is why the tile is 36 + 20 wide.
    func test_chevronHoleIsCarvedOutOfTheTrailingCorner() throws {
        let width = Int(instantPageV2QuoteFadeTileSize.width)
        let height = Int(instantPageV2QuoteFadeTileSize.height)
        XCTAssertLessThan(try self.alpha(atX: width - 20, y: height - 16), 16, "inside the hole")
        XCTAssertEqual(try self.alpha(atX: 2, y: height - 16), 255, "the far side of the tile is untouched by it")
    }

    /// The layer's nine-part slicing must match the image's cap insets, or the tile is scaled instead
    /// of stretched and the fade's height changes with the quote's.
    func test_maskLayerStretchesFromTheTopLeftPixel() {
        let layer = InstantPageV2QuoteFadeMaskLayer()
        XCTAssertEqual(layer.contentsCenter.minX, 0.0, accuracy: 0.0001)
        XCTAssertEqual(layer.contentsCenter.minY, 0.0, accuracy: 0.0001)
        XCTAssertEqual(layer.contentsCenter.width, 1.0 / instantPageV2QuoteFadeTileSize.width, accuracy: 0.0001)
        XCTAssertEqual(layer.contentsCenter.height, 1.0 / instantPageV2QuoteFadeTileSize.height, accuracy: 0.0001)
        XCTAssertNotNil(layer.contents)
    }
}
