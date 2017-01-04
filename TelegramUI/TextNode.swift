import Foundation
import AsyncDisplayKit
import Display

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
    fileprivate let cutout: TextNodeCutout?
    let size: CGSize
    fileprivate let lines: [TextNodeLine]
    
    fileprivate init(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, cutout: TextNodeCutout?, size: CGSize, lines: [TextNodeLine], backgroundColor: UIColor?) {
        self.attributedString = attributedString
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.cutout = cutout
        self.size = size
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
    
    func attributesAtPoint(_ point: CGPoint) -> [String: Any] {
        if let attributedString = self.attributedString {
            for line in self.lines {
                let lineFrame = line.frame.offsetBy(dx: 0.0, dy: -line.frame.size.height)
                if lineFrame.contains(point) {
                    let index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: point.x - lineFrame.minX, y: point.y - lineFrame.minY))
                    if index >= 0 && index < attributedString.length {
                        return attributedString.attributes(at: index, effectiveRange: nil)
                    }
                    break
                }
            }
            for line in self.lines {
                let lineFrame = line.frame.offsetBy(dx: 0.0, dy: -line.frame.size.height)
                if lineFrame.offsetBy(dx: 0.0, dy: -lineFrame.size.height).insetBy(dx: -3.0, dy: -3.0).contains(point) {
                    let index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: point.x - lineFrame.minX, y: point.y - lineFrame.minY))
                    if index >= 0 && index < attributedString.length {
                        return attributedString.attributes(at: index, effectiveRange: nil)
                    }
                    break
                }
            }
        }
        return [:]
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
    
    func attributesAtPoint(_ point: CGPoint) -> [String: Any] {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.attributesAtPoint(point)
        } else {
            return [:]
        }
    }
    
    private class func calculateLayout(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, cutout: TextNodeCutout?) -> TextNodeLayout {
        if let attributedString = attributedString {
            let stringLength = attributedString.length
            
            let font: CTFont
            if stringLength != 0 {
                if let stringFont = attributedString.attribute(kCTFontAttributeName as String, at: 0, effectiveRange: nil) {
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
                return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, cutout: cutout, size: CGSize(), lines: [], backgroundColor: backgroundColor)
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
                    if lineOriginY < cutoutMaxY && lineOriginY + fontLineHeight > cutoutMinY {
                        lineConstrainedWidth = max(1.0, lineConstrainedWidth - cutoutWidth)
                        lineCutoutOffset = cutoutOffset
                        lineAdditionalWidth = cutoutWidth
                    }
                }
                
                let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastLineCharacterIndex, Double(lineConstrainedWidth))
                
                if maximumNumberOfLines != 0 && lines.count == maximumNumberOfLines - 1 && lineCharacterCount > 0 {
                    if first {
                        first = false
                    } else {
                        layoutSize.height += fontLineSpacing
                    }
                    
                    let coreTextLine: CTLine
                    
                    let lineRange = CFRange(location: lastLineCharacterIndex, length: stringLength - lastLineCharacterIndex)
                    let originalLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 0.0)
                    
                    if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(constrainedSize.width) {
                        coreTextLine = originalLine
                    } else {
                        var truncationTokenAttributes: [String : AnyObject] = [:]
                        truncationTokenAttributes[kCTFontAttributeName as String] = font
                        truncationTokenAttributes[kCTForegroundColorFromContextAttributeName as String] = true as NSNumber
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
            
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, cutout: cutout, size: CGSize(width: ceil(layoutSize.width), height: ceil(layoutSize.height)), lines: lines, backgroundColor: backgroundColor)
        } else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, cutout: cutout, size: CGSize(), lines: [], backgroundColor: backgroundColor)
        }
    }

    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return self.cachedLayout
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: NSObjectProtocol?, isCancelled: () -> Bool, isRasterizing: Bool) {
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
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                context.textPosition = CGPoint(x: line.frame.origin.x, y: line.frame.origin.y)
                CTLineDraw(line.line, context)
            }
            
            //CGContextRestoreGState(context)
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        
        context.setBlendMode(.normal)
    }
    
    class func asyncLayout(_ maybeNode: TextNode?) -> (_ attributedString: NSAttributedString?, _ backgroundColor: UIColor?, _ maximumNumberOfLines: Int, _ truncationType: CTLineTruncationType, _ constrainedSize: CGSize, _ cutout: TextNodeCutout?) -> (TextNodeLayout, () -> TextNode) {
        let existingLayout: TextNodeLayout? = maybeNode?.cachedLayout
        
        return { attributedString, backgroundColor, maximumNumberOfLines, truncationType, constrainedSize, cutout in
            let layout: TextNodeLayout
            
            var updated = false
            if let existingLayout = existingLayout, existingLayout.constrainedSize == constrainedSize && existingLayout.maximumNumberOfLines == maximumNumberOfLines && existingLayout.truncationType == truncationType && existingLayout.cutout == cutout {
                
                let stringMatch: Bool
                if let existingString = existingLayout.attributedString, let string = attributedString {
                    stringMatch = existingString.isEqual(to: string)
                } else if existingLayout.attributedString == nil && attributedString == nil {
                    stringMatch = true
                } else {
                    stringMatch = false
                }
                
                if stringMatch {
                    layout = existingLayout
                } else {
                    layout = TextNode.calculateLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, cutout: cutout)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, cutout: cutout)
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
