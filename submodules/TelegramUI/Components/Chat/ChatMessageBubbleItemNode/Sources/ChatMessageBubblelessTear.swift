import Foundation
import UIKit
import AppBundle

/// Without bubbles: the line along which each torn-paper graphic a bubble tears with (`Chat/Message/BubbleTearUp`,
/// `BubbleTearDown`) passes from paper to gap, one sample per point of its width, as the distance from its top. The
/// graphics tile horizontally, so the line does too. Traced once, on first use.
final class ChatMessageBubblelessTearContours {
    struct Contour {
        let samples: [CGFloat]
        let tileWidth: CGFloat
    }

    static let shared = ChatMessageBubblelessTearContours()

    /// The edge with paper above it, the bottom of the chat above a strip; its graphic is solid along its top.
    let paperAbove: Contour?
    /// The edge with paper below it; its graphic is solid along its bottom.
    let paperBelow: Contour?

    private init() {
        self.paperAbove = ChatMessageBubblelessTearContours.contour(UIImage(bundleImageName: "Chat/Message/BubbleTearUp"), paperAtTop: true)
        self.paperBelow = ChatMessageBubblelessTearContours.contour(UIImage(bundleImageName: "Chat/Message/BubbleTearDown"), paperAtTop: false)
    }

    private static func contour(_ image: UIImage?, paperAtTop: Bool) -> Contour? {
        guard let image, let cgImage = image.cgImage, image.size.width >= 1.0 else {
            return nil
        }
        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        guard pixelWidth > 0 && pixelHeight > 0 else {
            return nil
        }
        let bytesPerRow = pixelWidth * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        let isDrawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(pixelWidth), height: CGFloat(pixelHeight)))
            return true
        }
        guard isDrawn else {
            return nil
        }
        // A bitmap context's first row is the top of what is drawn into it.
        let scale = CGFloat(pixelWidth) / image.size.width
        let columnCount = Int(image.size.width.rounded())
        var samples: [CGFloat] = []
        samples.reserveCapacity(columnCount)
        for column in 0 ..< columnCount {
            let x = min(pixelWidth - 1, Int((CGFloat(column) + 0.5) * scale))
            var boundary: Int
            if paperAtTop {
                boundary = 0
                while boundary < pixelHeight && data[boundary * bytesPerRow + x * 4 + 3] >= 128 {
                    boundary += 1
                }
            } else {
                var row = pixelHeight - 1
                while row >= 0 && data[row * bytesPerRow + x * 4 + 3] >= 128 {
                    row -= 1
                }
                boundary = row + 1
            }
            samples.append(CGFloat(boundary) / scale)
        }
        return Contour(samples: samples, tileWidth: image.size.width)
    }
}

/// Appends one torn edge to `path`, tiled from `minX` to `maxX`, with the top of its graphic at `y`; a straight line
/// `fallbackY` below that when the graphic is missing.
func appendChatMessageBubblelessTearEdge(_ contour: ChatMessageBubblelessTearContours.Contour?, to path: CGMutablePath, y: CGFloat, fallbackY: CGFloat, from minX: CGFloat, to maxX: CGFloat) {
    guard let contour, !contour.samples.isEmpty else {
        path.move(to: CGPoint(x: minX, y: y + fallbackY))
        path.addLine(to: CGPoint(x: maxX, y: y + fallbackY))
        return
    }
    var tileX = floor(minX / contour.tileWidth) * contour.tileWidth
    var isFirst = true
    while tileX < maxX {
        for (index, offset) in contour.samples.enumerated() {
            let x = tileX + CGFloat(index) + 0.5
            if x < minX || x > maxX {
                continue
            }
            let point = CGPoint(x: x, y: y + offset)
            if isFirst {
                path.move(to: point)
                isFirst = false
            } else {
                path.addLine(to: point)
            }
        }
        tileX += contour.tileWidth
    }
}
