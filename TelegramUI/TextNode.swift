import Foundation
import AsyncDisplayKit
import Display
import Postbox

private let defaultFont = UIFont.systemFont(ofSize: 15.0)

private final class TextNodeLine {
    let line: CTLine
    let frame: CGRect
    let range: NSRange
    
    init(line: CTLine, frame: CGRect, range: NSRange) {
        self.line = line
        self.frame = frame
        self.range = range
    }
}

enum TextNodeCutoutPosition {
    case TopLeft
    case TopRight
}

struct TextNodeCutout: Equatable {
    let position: TextNodeCutoutPosition
    let size: CGSize
}

func ==(lhs: TextNodeCutout, rhs: TextNodeCutout) -> Bool {
    return lhs.position == rhs.position && lhs.size == rhs.size
}

final class TextNodeLayout: NSObject {
    fileprivate let attributedString: NSAttributedString?
    fileprivate let maximumNumberOfLines: Int
    fileprivate let truncationType: CTLineTruncationType
    fileprivate let backgroundColor: UIColor?
    fileprivate let constrainedSize: CGSize
    fileprivate let alignment: NSTextAlignment
    fileprivate let cutout: TextNodeCutout?
    fileprivate let insets: UIEdgeInsets
    let size: CGSize
    fileprivate let firstLineOffset: CGFloat
    fileprivate let lines: [TextNodeLine]
    
    fileprivate init(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, alignment: NSTextAlignment, cutout: TextNodeCutout?, insets: UIEdgeInsets, size: CGSize, firstLineOffset: CGFloat, lines: [TextNodeLine], backgroundColor: UIColor?) {
        self.attributedString = attributedString
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.alignment = alignment
        self.cutout = cutout
        self.insets = insets
        self.size = size
        self.firstLineOffset = firstLineOffset
        self.lines = lines
        self.backgroundColor = backgroundColor
    }
    
    var numberOfLines: Int {
        return self.lines.count
    }
    
    var trailingLineWidth: CGFloat {
        if let lastLine = self.lines.last {
            return lastLine.frame.width
        } else {
            return 0.0
        }
    }
    
    func attributesAtPoint(_ point: CGPoint) -> (Int, [NSAttributedStringKey: Any])? {
        if let attributedString = self.attributedString {
            let transformedPoint = CGPoint(x: point.x - self.insets.left, y: point.y - self.insets.top)
            for line in self.lines {
                let lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
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
            for line in self.lines {
                let lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
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
    
    func linesRects() -> [CGRect] {
        var rects: [CGRect] = []
        for line in self.lines {
            rects.append(line.frame)
        }
        return rects
    }
    
    func attributeRects(name: String, at index: Int) -> [CGRect]? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedStringKey(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                var rects: [CGRect] = []
                for line in self.lines {
                    let lineRange = NSIntersectionRange(range, line.range)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0.0
                        if lineRange.location != line.range.location {
                            leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        var rightOffset: CGFloat = line.frame.width
                        if lineRange.location + lineRange.length != line.range.length {
                            rightOffset = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                        }
                        let lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                        rects.append(CGRect(origin: CGPoint(x: lineFrame.minX + leftOffset + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: rightOffset - leftOffset, height: lineFrame.size.height)))
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

final class TelegramHashtag {
    let peerName: String?
    let hashtag: String
    
    init(peerName: String?, hashtag: String) {
        self.peerName = peerName
        self.hashtag = hashtag
    }
}

final class TelegramPeerMention {
    let peerId: PeerId
    let mention: String
    
    init(peerId: PeerId, mention: String) {
        self.peerId = peerId
        self.mention = mention
    }
}

final class TextNode: ASDisplayNode {
    static let UrlAttribute = "UrlAttributeT"
    static let TelegramPeerMentionAttribute = "TelegramPeerMention"
    static let TelegramPeerTextMentionAttribute = "TelegramPeerTextMention"
    static let TelegramBotCommandAttribute = "TelegramBotCommand"
    static let TelegramHashtagAttribute = "TelegramHashtag"
    
    private(set) var cachedLayout: TextNodeLayout?
    
    override init() {
        super.init()
        
        self.backgroundColor = UIColor.clear
        self.isOpaque = false
        self.clipsToBounds = false
    }
    
    func attributesAtPoint(_ point: CGPoint) -> (Int, [NSAttributedStringKey: Any])? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.attributesAtPoint(point)
        } else {
            return nil
        }
    }
    
    func attributeRects(name: String, at index: Int) -> [CGRect]? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.attributeRects(name: name, at: index)
        } else {
            return nil
        }
    }
    
    private class func calculateLayout(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, cutout: TextNodeCutout?, insets: UIEdgeInsets) -> TextNodeLayout {
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
            let fontLineSpacing = floor(fontLineHeight * 0.12)
            
            var lines: [TextNodeLine] = []
            
            var maybeTypesetter: CTTypesetter?
            maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
            if maybeTypesetter == nil {
                return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, alignment: alignment, cutout: cutout, insets: insets, size: CGSize(), firstLineOffset: 0.0, lines: [], backgroundColor: backgroundColor)
            }
            
            let typesetter = maybeTypesetter!
            
            var lastLineCharacterIndex: CFIndex = 0
            var layoutSize = CGSize()
            
            var cutoutEnabled = false
            var cutoutMinY: CGFloat = 0.0
            var cutoutMaxY: CGFloat = 0.0
            var cutoutWidth: CGFloat = 0.0
            var cutoutOffset: CGFloat = 0.0
            if let cutout = cutout {
                cutoutMinY = -fontLineSpacing
                cutoutMaxY = cutout.size.height + fontLineSpacing
                cutoutWidth = cutout.size.width
                if case .TopLeft = cutout.position {
                    cutoutOffset = cutoutWidth
                }
                cutoutEnabled = true
            }
            
            let firstLineOffset = floorToScreenPixels(fontLineSpacing * 2.0)
            
            var first = true
            while true {
                var lineConstrainedWidth = constrainedSize.width
                var lineOriginY = floorToScreenPixels(layoutSize.height + fontLineHeight - fontLineSpacing * 2.0)
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
                    
                    let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                    let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight + fontLineSpacing
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length)))
                    
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
                        
                        lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length)))
                    } else {
                        if !lines.isEmpty {
                            layoutSize.height += fontLineSpacing
                        }
                        break
                    }
                }
            }
            
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, alignment: alignment, cutout: cutout, insets: insets, size: CGSize(width: ceil(layoutSize.width) + insets.left + insets.right, height: ceil(layoutSize.height) + insets.top + insets.bottom), firstLineOffset: firstLineOffset, lines: lines, backgroundColor: backgroundColor)
        } else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, alignment: alignment, cutout: cutout, insets: insets, size: CGSize(), firstLineOffset: 0.0, lines: [], backgroundColor: backgroundColor)
        }
    }

    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return self.cachedLayout
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
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
                let lineOffset: CGFloat
                if alignment == .center {
                    lineOffset = floor((bounds.size.width - line.frame.size.width) / 2.0)
                } else {
                    lineOffset = 0.0
                }
                context.textPosition = CGPoint(x: line.frame.origin.x + lineOffset + offset.x, y: line.frame.origin.y + offset.y)
                CTLineDraw(line.line, context)
            }
            
            //CGContextRestoreGState(context)
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        
        context.setBlendMode(.normal)
    }
    
    class func asyncLayout(_ maybeNode: TextNode?) -> (_ attributedString: NSAttributedString?, _ backgroundColor: UIColor?, _ maximumNumberOfLines: Int, _ truncationType: CTLineTruncationType, _ constrainedSize: CGSize, _ alignment: NSTextAlignment, _ cutout: TextNodeCutout?, _ insets: UIEdgeInsets) -> (TextNodeLayout, () -> TextNode) {
        let existingLayout: TextNodeLayout? = maybeNode?.cachedLayout
        
        return { attributedString, backgroundColor, maximumNumberOfLines, truncationType, constrainedSize, alignment, cutout, insets in
            let layout: TextNodeLayout
            
            var updated = false
            if let existingLayout = existingLayout, existingLayout.constrainedSize == constrainedSize && existingLayout.maximumNumberOfLines == maximumNumberOfLines && existingLayout.truncationType == truncationType && existingLayout.cutout == cutout && existingLayout.alignment == alignment {
                let stringMatch: Bool
                
                var colorMatch: Bool = true
                if let backgroundColor = backgroundColor, let previousBackgroundColor = existingLayout.backgroundColor {
                    if !backgroundColor.isEqual(previousBackgroundColor) {
                        colorMatch = false
                    }
                } else if (backgroundColor != nil) != (existingLayout.backgroundColor != nil) {
                    colorMatch = false
                }
                
                if !colorMatch {
                    stringMatch = false
                } else if let existingString = existingLayout.attributedString, let string = attributedString {
                    stringMatch = existingString.isEqual(to: string)
                } else if existingLayout.attributedString == nil && attributedString == nil {
                    stringMatch = true
                } else {
                    stringMatch = false
                }
                
                if stringMatch {
                    layout = existingLayout
                } else {
                    layout = TextNode.calculateLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, alignment: alignment, cutout: cutout, insets: insets)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, alignment: alignment, cutout: cutout, insets: insets)
                updated = true
            }
            
            let node = maybeNode ?? TextNode()
            
            return (layout, {
                node.cachedLayout = layout
                if updated {
                    node.setNeedsDisplay()
                }
                
                return node
            })
        }
    }
}
