import Foundation
import AsyncDisplayKit
import CoreText

private let defaultFont = UIFont.systemFont(ofSize: 15.0)

private final class TextNodeLine {
    let line: CTLine
    let frame: CGRect
    let range: NSRange
    let isRTL: Bool
    
    init(line: CTLine, frame: CGRect, range: NSRange, isRTL: Bool) {
        self.line = line
        self.frame = frame
        self.range = range
        self.isRTL = isRTL
    }
}

public enum TextNodeCutoutPosition {
    case TopLeft
    case TopRight
    case BottomRight
}

public struct TextNodeCutout: Equatable {
    public var topLeft: CGSize?
    public var topRight: CGSize?
    public var bottomRight: CGSize?
    
    public init(topLeft: CGSize? = nil, topRight: CGSize? = nil, bottomRight: CGSize? = nil) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
    }
}

private func displayLineFrame(frame: CGRect, isRTL: Bool, boundingRect: CGRect, cutout: TextNodeCutout?) -> CGRect {
    if frame.width.isEqual(to: boundingRect.width) {
        return frame
    }
    var lineFrame = frame
    let intersectionFrame = lineFrame.offsetBy(dx: 0.0, dy: -lineFrame.height)
    if isRTL {
        lineFrame.origin.x = max(0.0, floor(boundingRect.width - lineFrame.size.width))
        if let topRight = cutout?.topRight {
            let topRightRect = CGRect(origin: CGPoint(x: boundingRect.width - topRight.width, y: 0.0), size: topRight)
            if intersectionFrame.intersects(topRightRect) {
                lineFrame.origin.x -= topRight.width
                return lineFrame
            }
        }
        if let bottomRight = cutout?.bottomRight {
            let bottomRightRect = CGRect(origin: CGPoint(x: boundingRect.width - bottomRight.width, y: boundingRect.height - bottomRight.height), size: bottomRight)
            if intersectionFrame.intersects(bottomRightRect) {
                lineFrame.origin.x -= bottomRight.width
                return lineFrame
            }
        }
    }
    return lineFrame
}

public final class TextNodeLayoutArguments {
    public let attributedString: NSAttributedString?
    public let backgroundColor: UIColor?
    public let maximumNumberOfLines: Int
    public let truncationType: CTLineTruncationType
    public let constrainedSize: CGSize
    public let alignment: NSTextAlignment
    public let lineSpacing: CGFloat
    public let cutout: TextNodeCutout?
    public let insets: UIEdgeInsets
    
    public init(attributedString: NSAttributedString?, backgroundColor: UIColor? = nil, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, alignment: NSTextAlignment = .natural, lineSpacing: CGFloat = 0.12, cutout: TextNodeCutout? = nil, insets: UIEdgeInsets = UIEdgeInsets()) {
        self.attributedString = attributedString
        self.backgroundColor = backgroundColor
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.cutout = cutout
        self.insets = insets
    }
}

public final class TextNodeLayout: NSObject {
    fileprivate let attributedString: NSAttributedString?
    fileprivate let maximumNumberOfLines: Int
    fileprivate let truncationType: CTLineTruncationType
    fileprivate let backgroundColor: UIColor?
    fileprivate let constrainedSize: CGSize
    fileprivate let alignment: NSTextAlignment
    fileprivate let lineSpacing: CGFloat
    fileprivate let cutout: TextNodeCutout?
    fileprivate let insets: UIEdgeInsets
    public let size: CGSize
    fileprivate let firstLineOffset: CGFloat
    fileprivate let lines: [TextNodeLine]
    public let hasRTL: Bool
    
    fileprivate init(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, alignment: NSTextAlignment, lineSpacing: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, size: CGSize, firstLineOffset: CGFloat, lines: [TextNodeLine], backgroundColor: UIColor?) {
        self.attributedString = attributedString
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.cutout = cutout
        self.insets = insets
        self.size = size
        self.firstLineOffset = firstLineOffset
        self.lines = lines
        self.backgroundColor = backgroundColor
        var hasRTL = false
        for line in lines {
            if line.isRTL {
                hasRTL = true
            }
        }
        self.hasRTL = hasRTL
    }
    
    public var numberOfLines: Int {
        return self.lines.count
    }
    
    public var trailingLineWidth: CGFloat {
        if let lastLine = self.lines.last {
            return lastLine.frame.width
        } else {
            return 0.0
        }
    }
    
    public func attributesAtPoint(_ point: CGPoint) -> (Int, [NSAttributedStringKey: Any])? {
        if let attributedString = self.attributedString {
            let transformedPoint = CGPoint(x: point.x - self.insets.left, y: point.y - self.insets.top)
            var lineIndex = -1
            for line in self.lines {
                lineIndex += 1
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                switch self.alignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        if line.isRTL {
                            lineFrame.origin.x = self.size.width - lineFrame.size.width
                        }
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    default:
                        break
                }
                if lineFrame.contains(transformedPoint) {
                    var index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: transformedPoint.x - lineFrame.minX, y: transformedPoint.y - lineFrame.minY))
                    if index == attributedString.length {
                        index -= 1
                    } else if index != 0 {
                        var glyphStart: CGFloat = 0.0
                        CTLineGetOffsetForStringIndex(line.line, index, &glyphStart)
                        if transformedPoint.x < glyphStart {
                            index -= 1
                        }
                    }
                    if index >= 0 && index < attributedString.length {
                        return (index, attributedString.attributes(at: index, effectiveRange: nil))
                    }
                    break
                }
            }
            lineIndex = -1
            for line in self.lines {
                lineIndex += 1
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                switch self.alignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        if line.isRTL {
                            lineFrame.origin.x = floor(self.size.width - lineFrame.size.width)
                        }
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    default:
                        break
                }
                if lineFrame.offsetBy(dx: 0.0, dy: -lineFrame.size.height).insetBy(dx: -3.0, dy: -3.0).contains(transformedPoint) {
                    var index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: transformedPoint.x - lineFrame.minX, y: transformedPoint.y - lineFrame.minY))
                    if index == attributedString.length {
                        index -= 1
                    } else if index != 0 {
                        var glyphStart: CGFloat = 0.0
                        CTLineGetOffsetForStringIndex(line.line, index, &glyphStart)
                        if transformedPoint.x < glyphStart {
                            index -= 1
                        }
                    }
                    if index >= 0 && index < attributedString.length {
                        return (index, attributedString.attributes(at: index, effectiveRange: nil))
                    }
                    break
                }
            }
        }
        return nil
    }
    
    public func linesRects() -> [CGRect] {
        var rects: [CGRect] = []
        for line in self.lines {
            rects.append(line.frame)
        }
        return rects
    }
    
    public func attributeSubstring(name: String, index: Int) -> String? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedStringKey(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                return (attributedString.string as NSString).substring(with: range)
            }
        }
        return nil
    }
    
    public func lineAndAttributeRects(name: String, at index: Int) -> [(CGRect, CGRect)]? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedStringKey(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                var rects: [(CGRect, CGRect)] = []
                for line in self.lines {
                    let lineRange = NSIntersectionRange(range, line.range)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0.0
                        if lineRange.location != line.range.location {
                            leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        var rightOffset: CGFloat = line.frame.width
                        if lineRange.location + lineRange.length != line.range.length {
                            var secondaryOffset: CGFloat = 0.0
                            let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                            rightOffset = ceil(rawOffset)
                            if !rawOffset.isEqual(to: secondaryOffset) {
                                rightOffset = ceil(secondaryOffset)
                            }
                        }
                        var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                        
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                        
                        rects.append((lineFrame, CGRect(origin: CGPoint(x: lineFrame.minX + leftOffset + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: rightOffset - leftOffset, height: lineFrame.size.height))))
                    }
                }
                if !rects.isEmpty {
                    return rects
                }
            }
        }
        return nil
    }
}

public class TextNode: ASDisplayNode {
    public private(set) var cachedLayout: TextNodeLayout?
    
    override public init() {
        super.init()
        
        self.backgroundColor = UIColor.clear
        self.isOpaque = false
        self.clipsToBounds = false
    }
    
    public func attributesAtPoint(_ point: CGPoint) -> (Int, [NSAttributedStringKey: Any])? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.attributesAtPoint(point)
        } else {
            return nil
        }
    }
    
    public func attributeSubstring(name: String, index: Int) -> String? {
        return self.cachedLayout?.attributeSubstring(name: name, index: index)
    }
    
    public func attributeRects(name: String, at index: Int) -> [CGRect]? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.lineAndAttributeRects(name: name, at: index)?.map { $0.1 }
        } else {
            return nil
        }
    }
    
    public func lineAndAttributeRects(name: String, at index: Int) -> [(CGRect, CGRect)]? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.lineAndAttributeRects(name: name, at: index)
        } else {
            return nil
        }
    }
    
    private class func calculateLayout(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, lineSpacingFactor: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets) -> TextNodeLayout {
        if let attributedString = attributedString {
            let stringLength = attributedString.length
            
            let font: CTFont
            if stringLength != 0 {
                if let stringFont = attributedString.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) {
                    font = stringFont as! CTFont
                } else {
                    font = defaultFont
                }
            } else {
                font = defaultFont
            }
            
            let fontAscent = CTFontGetAscent(font)
            let fontDescent = CTFontGetDescent(font)
            let fontLineHeight = floor(fontAscent + fontDescent)
            let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
            
            var lines: [TextNodeLine] = []
            
            var maybeTypesetter: CTTypesetter?
            maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
            if maybeTypesetter == nil {
                return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, alignment: alignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), firstLineOffset: 0.0, lines: [], backgroundColor: backgroundColor)
            }
            
            let typesetter = maybeTypesetter!
            
            var lastLineCharacterIndex: CFIndex = 0
            var layoutSize = CGSize()
            
            var cutoutEnabled = false
            var cutoutMinY: CGFloat = 0.0
            var cutoutMaxY: CGFloat = 0.0
            var cutoutWidth: CGFloat = 0.0
            var cutoutOffset: CGFloat = 0.0
            
            var bottomCutoutEnabled = false
            var bottomCutoutSize = CGSize()
            
            if let topLeft = cutout?.topLeft {
                cutoutMinY = -fontLineSpacing
                cutoutMaxY = topLeft.height + fontLineSpacing
                cutoutWidth = topLeft.width
                cutoutOffset = cutoutWidth
                cutoutEnabled = true
            } else if let topRight = cutout?.topRight {
                cutoutMinY = -fontLineSpacing
                cutoutMaxY = topRight.height + fontLineSpacing
                cutoutWidth = topRight.width
                cutoutEnabled = true
            }
            
            if let bottomRight = cutout?.bottomRight {
                bottomCutoutSize = bottomRight
                bottomCutoutEnabled = true
            }
            
            let firstLineOffset = floorToScreenPixels(fontDescent)
            
            var first = true
            while true {
                var lineConstrainedWidth = constrainedSize.width
                var lineOriginY = floorToScreenPixels(layoutSize.height + fontAscent)
                if !first {
                    lineOriginY += fontLineSpacing
                }
                var lineCutoutOffset: CGFloat = 0.0
                var lineAdditionalWidth: CGFloat = 0.0
                
                if cutoutEnabled {
                    if lineOriginY - fontLineHeight < cutoutMaxY && lineOriginY + fontLineHeight > cutoutMinY {
                        lineConstrainedWidth = max(1.0, lineConstrainedWidth - cutoutWidth)
                        lineCutoutOffset = cutoutOffset
                        lineAdditionalWidth = cutoutWidth
                    }
                }
                
                let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastLineCharacterIndex, Double(lineConstrainedWidth))
                
                var isLastLine = false
                if maximumNumberOfLines != 0 && lines.count == maximumNumberOfLines - 1 && lineCharacterCount > 0 {
                    isLastLine = true
                } else if layoutSize.height + (fontLineSpacing + fontLineHeight) * 2.0 > constrainedSize.height {
                    isLastLine = true
                }
                
                if isLastLine {
                    if first {
                        first = false
                    } else {
                        layoutSize.height += fontLineSpacing
                    }
                    
                    let lineRange = CFRange(location: lastLineCharacterIndex, length: stringLength - lastLineCharacterIndex)
                    
                    if lineRange.length == 0 {
                        break
                    }
                    
                    let coreTextLine: CTLine
                    
                    let originalLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 0.0)
                    
                    if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(constrainedSize.width) {
                        coreTextLine = originalLine
                    } else {
                        var truncationTokenAttributes: [NSAttributedStringKey : AnyObject] = [:]
                        truncationTokenAttributes[NSAttributedStringKey.font] = font
                        truncationTokenAttributes[NSAttributedStringKey(rawValue:  kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                        let tokenString = "\u{2026}"
                        let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                        let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                        
                        coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(constrainedSize.width), truncationType, truncationToken) ?? truncationToken
                    }
                    
                    let lineWidth = min(constrainedSize.width, ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine))))
                    let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight + fontLineSpacing
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    var isRTL = false
                    let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                    if glyphRuns.count != 0 {
                        let run = glyphRuns[0] as! CTRun
                        if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                        }
                    }
                    
                    lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), isRTL: isRTL))
                    
                    break
                } else {
                    if lineCharacterCount > 0 {
                        if first {
                            first = false
                        } else {
                            layoutSize.height += fontLineSpacing
                        }
                        
                        let lineRange = CFRangeMake(lastLineCharacterIndex, lineCharacterCount)
                        let coreTextLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 100.0)
                        lastLineCharacterIndex += lineCharacterCount
                        
                        let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                        let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                        layoutSize.height += fontLineHeight
                        layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                        
                        var isRTL = false
                        let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                        if glyphRuns.count != 0 {
                            let run = glyphRuns[0] as! CTRun
                            if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                                isRTL = true
                            }
                        }
                        
                        lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), isRTL: isRTL))
                    } else {
                        if !lines.isEmpty {
                            layoutSize.height += fontLineSpacing
                        }
                        break
                    }
                }
            }
            
            if !lines.isEmpty && bottomCutoutEnabled {
                let proposedWidth = lines[lines.count - 1].frame.width + bottomCutoutSize.width
                if proposedWidth > layoutSize.width {
                    if proposedWidth < constrainedSize.width {
                        layoutSize.width = proposedWidth
                    } else {
                        layoutSize.height += bottomCutoutSize.height
                    }
                }
            }
            
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, alignment: alignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(width: ceil(layoutSize.width) + insets.left + insets.right, height: ceil(layoutSize.height) + insets.top + insets.bottom), firstLineOffset: firstLineOffset, lines: lines, backgroundColor: backgroundColor)
        } else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, alignment: alignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), firstLineOffset: 0.0, lines: [], backgroundColor: backgroundColor)
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return self.cachedLayout
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        if isCancelled() {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()!
        
        context.setAllowsAntialiasing(true)
        
        context.setAllowsFontSmoothing(false)
        context.setShouldSmoothFonts(false)
        
        context.setAllowsFontSubpixelPositioning(false)
        context.setShouldSubpixelPositionFonts(false)
        
        context.setAllowsFontSubpixelQuantization(true)
        context.setShouldSubpixelQuantizeFonts(true)
        
        if let layout = parameters as? TextNodeLayout {
            if !isRasterizing || layout.backgroundColor != nil {
                context.setBlendMode(.copy)
                context.setFillColor((layout.backgroundColor ?? UIColor.clear).cgColor)
                context.fill(bounds)
            }
            
            let textMatrix = context.textMatrix
            let textPosition = context.textPosition
            //CGContextSaveGState(context)
            
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            //let clipRect = CGContextGetClipBoundingBox(context)
            
            let alignment = layout.alignment
            let offset = CGPoint(x: layout.insets.left, y: layout.insets.top)
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                
                var lineFrame = line.frame
                lineFrame.origin.y += offset.y
                
                if alignment == .center {
                    lineFrame.origin.x = offset.x + floor((bounds.size.width - lineFrame.width) / 2.0)
                } else if alignment == .natural, line.isRTL {
                    lineFrame.origin.x = offset.x + floor(bounds.size.width - lineFrame.width)
                    
                    lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: bounds.size), cutout: layout.cutout)
                }
                context.textPosition = CGPoint(x: lineFrame.minX, y: lineFrame.minY)
                CTLineDraw(line.line, context)
            }
            
            //CGContextRestoreGState(context)
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        
        context.setBlendMode(.normal)
    }
    
    public static func asyncLayout(_ maybeNode: TextNode?) -> (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode) {
        let existingLayout: TextNodeLayout? = maybeNode?.cachedLayout
        
        return { arguments in
            let layout: TextNodeLayout
            
            var updated = false
            if let existingLayout = existingLayout, existingLayout.constrainedSize == arguments.constrainedSize && existingLayout.maximumNumberOfLines == arguments.maximumNumberOfLines && existingLayout.truncationType == arguments.truncationType && existingLayout.cutout == arguments.cutout && existingLayout.alignment == arguments.alignment && existingLayout.lineSpacing.isEqual(to: arguments.lineSpacing) {
                let stringMatch: Bool
                
                var colorMatch: Bool = true
                if let backgroundColor = arguments.backgroundColor, let previousBackgroundColor = existingLayout.backgroundColor {
                    if !backgroundColor.isEqual(previousBackgroundColor) {
                        colorMatch = false
                    }
                } else if (arguments.backgroundColor != nil) != (existingLayout.backgroundColor != nil) {
                    colorMatch = false
                }
                
                if !colorMatch {
                    stringMatch = false
                } else if let existingString = existingLayout.attributedString, let string = arguments.attributedString {
                    stringMatch = existingString.isEqual(to: string)
                } else if existingLayout.attributedString == nil && arguments.attributedString == nil {
                    stringMatch = true
                } else {
                    stringMatch = false
                }
                
                if stringMatch {
                    layout = existingLayout
                } else {
                    layout = TextNode.calculateLayout(attributedString: arguments.attributedString, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: arguments.attributedString, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets)
                updated = true
            }
            
            let node = maybeNode ?? TextNode()
            
            return (layout, {
                node.cachedLayout = layout
                if updated {
                    if layout.size.width.isZero && layout.size.height.isZero {
                        node.contents = nil
                    }
                    node.setNeedsDisplay()
                }
                
                return node
            })
        }
    }
}
