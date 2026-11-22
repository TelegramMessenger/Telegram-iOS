import Foundation

#if os(iOS) || os(visionOS)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

public struct MTMathRenderedFormula {
    public let image: MTImage
    public let size: CGSize
    public let width: CGFloat
    public let ascent: CGFloat
    public let descent: CGFloat

    public init(image: MTImage, size: CGSize, width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        self.image = image
        self.size = size
        self.width = width
        self.ascent = ascent
        self.descent = descent
    }
}

public enum MTMathRenderer {
    public static func render(latex: String, fontSize: CGFloat, textColor: MTColor, mode: MTMathUILabelMode = .display) -> MTMathRenderedFormula? {
        guard let font = MTFontManager.fontManager.defaultFont?.copy(withSize: fontSize) else {
            return nil
        }

        var error: NSError?
        guard let mathList = MTMathListBuilder.build(fromString: latex, error: &error), error == nil else {
            return nil
        }

        let style: MTLineStyle
        switch mode {
        case .display:
            style = .display
        case .text:
            style = .text
        }

        guard let displayList = MTTypesetter.createLineForMathList(mathList, font: font, style: style) else {
            return nil
        }

        displayList.textColor = textColor

        let width = max(1.0, ceil(displayList.width))
        let height = max(1.0, ceil(displayList.ascent + displayList.descent))
        let size = CGSize(width: width, height: height)
        displayList.position = CGPoint(x: 0.0, y: displayList.descent)

        #if os(iOS) || os(visionOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { rendererContext in
            rendererContext.cgContext.saveGState()
            var transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
            transform = transform.translatedBy(x: 0.0, y: -size.height)
            rendererContext.cgContext.concatenate(transform)
            displayList.draw(rendererContext.cgContext)
            rendererContext.cgContext.restoreGState()
        }
        return MTMathRenderedFormula(image: image, size: size, width: displayList.width, ascent: displayList.ascent, descent: displayList.descent)
        #endif

        #if os(macOS)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }
            context.saveGState()
            displayList.draw(context)
            context.restoreGState()
            return true
        }
        return MTMathRenderedFormula(image: image, size: size, width: displayList.width, ascent: displayList.ascent, descent: displayList.descent)
        #endif
    }
}
