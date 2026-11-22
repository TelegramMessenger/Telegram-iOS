import XCTest
@testable import QrStudioScreen

final class QrStudioColorTests: XCTestCase {
    func testOklabRoundTrip() {
        for rgb: UInt32 in [0x9662D4, 0x2F5FC6, 0xFFC36A, 0x3E4553, 0xFFFFFF, 0x000000] {
            let color = QrStudioColor(rgb: rgb)
            let (l, a, b) = color.oklab
            let back = QrStudioColor(oklab: l, a, b)
            XCTAssertEqual(back.r, color.r, accuracy: 0.002)
            XCTAssertEqual(back.g, color.g, accuracy: 0.002)
            XCTAssertEqual(back.b, color.b, accuracy: 0.002)
        }
    }

    func testInkLuminanceIsCappedForEveryPalette() {
        let palettes = [QrStudioPalette.fallback, QrStudioPalette.profile(id: 0, center: 0xe0a364, edge: 0xc4725d), QrStudioPalette.profile(id: 1, center: 0x6ec2b7, edge: 0x4891ad), QrStudioPalette.profile(id: 2, center: 0x2c2c2e, edge: 0x1c1c1e)]
        for palette in palettes {
            XCTAssertEqual(palette.colors.count, 9, palette.name)
            XCTAssertLessThanOrEqual(palette.ink.luminance, 0.205, palette.name)
        }
    }

    func testInkKeepsHue() {
        let source = QrStudioColor(rgb: 0xFFC36A)
        let (_, a0, b0) = source.oklab
        let (_, a1, b1) = source.ink.oklab
        var delta = abs(atan2(b0, a0) - atan2(b1, a1))
        if delta > .pi { delta = 2 * .pi - delta }
        XCTAssertLessThan(delta, 0.06)
    }

    func testInkOfGreyStaysGrey() {
        let ink = QrStudioColor(rgb: 0xB8BCC4).ink
        let (_, a, b) = ink.oklab
        XCTAssertLessThan((a * a + b * b).squareRoot(), 0.03)
        XCTAssertLessThanOrEqual(ink.luminance, 0.205)
    }

    func testMixLabEndpoints() {
        let x = QrStudioColor(rgb: 0x9662D4), y = QrStudioColor(rgb: 0x1E7E66)
        XCTAssertEqual(QrStudioColor.mixLab(x, y, 0).rgb, x.rgb)
        XCTAssertEqual(QrStudioColor.mixLab(x, y, 1).rgb, y.rgb)
    }

    func testSwatchPixels() {
        let palette = QrStudioPalette.fallback
        let side = 33
        let pixels = qrStudioSwatchPixels(colors: palette.colors, side: side)
        XCTAssertEqual(pixels.count, side * side * 4)
        XCTAssertEqual(pixels[3], 0)
        XCTAssertEqual(pixels[(side * side - 1) * 4 + 3], 0)
        let center = ((side / 2) * side + side / 2) * 4
        XCTAssertEqual(pixels[center + 3], 255)
        let expected = palette.colors[4]
        XCTAssertEqual(Double(pixels[center]) / 255.0, Double(expected.r), accuracy: 0.02)
        XCTAssertEqual(Double(pixels[center + 1]) / 255.0, Double(expected.g), accuracy: 0.02)
        XCTAssertEqual(Double(pixels[center + 2]) / 255.0, Double(expected.b), accuracy: 0.02)
    }

    func testSwatchPixelsRejectsShortPalette() {
        XCTAssertTrue(qrStudioSwatchPixels(colors: [], side: 8).isEmpty)
    }
}
