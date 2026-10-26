import XCTest
import UIKit
@testable import Display

/// `SplitTintTextView` draws a text in two layers, as `MultiScaleTextNode`'s states do: a tint layer with everything but
/// emoji, in white and coloured by its multiply colour, and an untinted emoji layer. A tint (the chat ↔ profile
/// expansion runs the title's colour on the render server) never reaches emoji.
final class SplitTintTextViewTests: XCTestCase {
    private let text = NSAttributedString(string: "A\u{1F600}", attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
    private let letter = NSRange(location: 0, length: 1)
    private let emoji = NSRange(location: 1, length: 2)

    private func make() -> SplitTintTextView {
        let view = SplitTintTextView()
        view.attributedText = self.text
        let size = view.updateLayout(CGSize(width: 200.0, height: 100.0))
        view.frame = CGRect(origin: CGPoint(), size: size)
        return view
    }

    /// The view's drawing as RGBA bytes at scale 1.
    private func pixels(_ view: UIView) -> (bytes: [UInt8], width: Int, height: Int) {
        let width = Int(ceil(view.bounds.width))
        let height = Int(ceil(view.bounds.height))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.translateBy(x: 0.0, y: CGFloat(height))
            context.scaleBy(x: 1.0, y: -1.0)
            UIGraphicsPushContext(context)
            view.draw(view.bounds)
            UIGraphicsPopContext()
        }
        return (bytes, width, height)
    }

    /// How many pixels inside `rect` are drawn, and how many of those are coloured (not grey).
    private func count(_ image: (bytes: [UInt8], width: Int, height: Int), in rect: CGRect) -> (drawn: Int, coloured: Int) {
        var drawn = 0
        var coloured = 0
        let area = rect.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for y in Int(area.minY) ..< Int(area.maxY) {
            for x in Int(area.minX) ..< Int(area.maxX) {
                let i = (y * image.width + x) * 4
                let (r, g, b, a) = (Int(image.bytes[i]), Int(image.bytes[i + 1]), Int(image.bytes[i + 2]), Int(image.bytes[i + 3]))
                if a > 32 {
                    drawn += 1
                    if max(r, g, b) - min(r, g, b) > 40 {
                        coloured += 1
                    }
                }
            }
        }
        return (drawn, coloured)
    }

    private func rect(_ view: TextView, _ range: NSRange) -> CGRect {
        guard let rects = view.rangeRects(in: range)?.rects, let first = rects.first else {
            XCTFail("no rect for \(range)")
            return CGRect()
        }
        return rects.reduce(first) { $0.union($1) }
    }

    func test_tintLayerDrawsTheTextOnly_emojiLayerTheEmojiOnly() {
        let view = self.make()
        let letterRect = self.rect(view.tintView, self.letter)
        let emojiRect = self.rect(view.tintView, self.emoji)
        XCTAssertFalse(letterRect.intersects(emojiRect.insetBy(dx: 1.0, dy: 1.0)))

        let tint = self.pixels(view.tintView)
        XCTAssertGreaterThan(self.count(tint, in: letterRect).drawn, 10, "the tint layer draws the text")
        XCTAssertEqual(self.count(tint, in: emojiRect).drawn, 0, "the tint layer draws no emoji")

        let emojiLayer = self.pixels(view.emojiView)
        XCTAssertEqual(self.count(emojiLayer, in: letterRect).drawn, 0, "the emoji layer draws no text")
        XCTAssertGreaterThan(self.count(emojiLayer, in: emojiRect).coloured, 10, "the emoji layer draws the emoji in colour")
    }

    func test_textIsWhite_colouredByTheTintLayersMultiplyColour_emojiUntinted() {
        let view = self.make()
        view.textColor = .red
        XCTAssertEqual(view.tintView.layer.layerTintColor.flatMap { UIColor(cgColor: $0) }, .red)
        // A layer's multiply colour is opaque white when unset, which multiplies nothing.
        let emojiTint = view.emojiView.layer.layerTintColor?.components ?? [1.0, 1.0, 1.0, 1.0]
        XCTAssertTrue(emojiTint.allSatisfy { $0 > 0.999 }, "the emoji layer is untinted")
        let tint = self.pixels(view.tintView)
        let letterRect = self.rect(view.tintView, self.letter)
        XCTAssertGreaterThan(self.count(tint, in: letterRect).drawn, 10)
        XCTAssertEqual(self.count(tint, in: letterRect).coloured, 0, "drawn white, so the multiply colour is the colour")
    }
}
