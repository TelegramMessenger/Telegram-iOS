import Foundation
import UIKit
import Display

// Without bubbles the unread separator sits on the plain page without its strip: the gray label with a row of down
// chevrons on each side, a thin stroke that fades out away from the label.
let chatBubblelessSeparatorSize = CGSize(width: 44.0, height: 8.0)
/// Between a row of chevrons and the label.
let chatBubblelessSeparatorSpacing: CGFloat = 14.0
private let chatBubblelessSeparatorLineWidth: CGFloat = 1.33

private struct ChatBubblelessChevronsImageKey: Hashable {
    let color: UInt32
    let alpha: Int
    let leading: Bool
}

// Read and written on the main thread only, where the unread separator applies its layout.
private var chatBubblelessChevronsImages: [ChatBubblelessChevronsImageKey: UIImage] = [:]

/// `leading` is the side left of the label: it fades towards its left edge, the trailing one towards its right.
func chatBubblelessChevronsImage(color: UIColor, leading: Bool) -> UIImage? {
    let key = ChatBubblelessChevronsImageKey(color: color.rgb, alpha: Int(color.alpha * 255.0), leading: leading)
    if let image = chatBubblelessChevronsImages[key] {
        return image
    }
    let image = generateImage(chatBubblelessSeparatorSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let path = CGMutablePath()
        let midY = size.height * 0.5
        let chevronWidth: CGFloat = 7.0
        let chevronHeight: CGFloat = 3.5
        let spacing: CGFloat = 5.0
        let count = Int((size.width + spacing) / (chevronWidth + spacing))
        let totalWidth = CGFloat(count) * chevronWidth + CGFloat(count - 1) * spacing
        var x = floor((size.width - totalWidth) * 0.5)
        for _ in 0 ..< count {
            path.move(to: CGPoint(x: x, y: midY - chevronHeight * 0.5))
            path.addLine(to: CGPoint(x: x + chevronWidth * 0.5, y: midY + chevronHeight * 0.5))
            path.addLine(to: CGPoint(x: x + chevronWidth, y: midY - chevronHeight * 0.5))
            x += chevronWidth + spacing
        }
        
        context.addPath(path)
        context.setLineWidth(chatBubblelessSeparatorLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.replacePathWithStrokedPath()
        context.clip()
        
        let colors = [color.withAlphaComponent(0.0).cgColor, color.cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations) {
            let start = CGPoint(x: leading ? 0.0 : size.width, y: 0.0)
            let end = CGPoint(x: leading ? size.width * 0.75 : size.width * 0.25, y: 0.0)
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsAfterEndLocation])
        }
    })
    if let image {
        chatBubblelessChevronsImages[key] = image
    }
    return image
}
