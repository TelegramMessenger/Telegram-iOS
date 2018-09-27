import Foundation
import TelegramCore
import Postbox
import AsyncDisplayKit

final class InstantPageUrlItem {
    let url: String
    let webpageId: MediaId?
    
    init(url: String, webpageId: MediaId?) {
        self.url = url
        self.webpageId = webpageId
    }
}

struct InstantPageTextStrikethroughItem {
    let frame: CGRect
}

final class InstantPageTextLine {
    let line: CTLine
    let range: NSRange
    let frame: CGRect
    let strikethroughItems: [InstantPageTextStrikethroughItem]
    let isRTL: Bool
    
    init(line: CTLine, range: NSRange, frame: CGRect, strikethroughItems: [InstantPageTextStrikethroughItem], isRTL: Bool) {
        self.line = line
        self.range = range
        self.frame = frame
        self.strikethroughItems = strikethroughItems
        self.isRTL = isRTL
    }
}

final class InstantPageTextItem: InstantPageItem {
    let attributedString: NSAttributedString
    let lines: [InstantPageTextLine]
    let rtlLineIndices: Set<Int>
    var frame: CGRect
    var alignment: NSTextAlignment = .natural
    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = false
    
    var containsRTL: Bool {
        return !self.rtlLineIndices.isEmpty
    }
    
    init(frame: CGRect, attributedString: NSAttributedString, lines: [InstantPageTextLine]) {
        self.attributedString = attributedString
        self.frame = frame
        self.lines = lines
        var index = 0
        var rtlLineIndices = Set<Int>()
        for line in lines {
            if line.isRTL {
                rtlLineIndices.insert(index)
            }
            index += 1
        }
        self.rtlLineIndices = rtlLineIndices
    }
    
    func drawInTile(context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        context.translateBy(x: self.frame.minX, y: self.frame.minY)
        
        let clipRect = context.boundingBoxOfClipPath
        
        let upperOriginBound = clipRect.minY - 10.0
        let lowerOriginBound = clipRect.maxY + 10.0
        let boundsWidth = self.frame.size.width
        
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            let lineFrame = line.frame
            if lineFrame.maxY < upperOriginBound || lineFrame.minY > lowerOriginBound {
                continue
            }
            
            var lineOrigin = lineFrame.origin
            if self.alignment == .center {
                lineOrigin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            } else if self.alignment == .right {
                lineOrigin.x = boundsWidth - lineFrame.size.width
            } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                lineOrigin.x = boundsWidth - lineFrame.size.width
            }
            
            context.textPosition = CGPoint(x: lineOrigin.x, y: lineOrigin.y + lineFrame.size.height)
            CTLineDraw(line.line, context)
            
            if !line.strikethroughItems.isEmpty {
                for item in line.strikethroughItems {
                    context.fill(CGRect(x: item.frame.minX, y: item.frame.minY + floor((lineFrame.size.height / 2.0) + 1.0), width: item.frame.size.width, height: 1.0))
                }
            }
        }
        
        context.restoreGState()
    }
    
    private func attributesAtPoint(_ point: CGPoint) -> (Int, [NSAttributedStringKey: Any])? {
        let transformedPoint = CGPoint(x: point.x, y: point.y)
        let boundsWidth = self.frame.width
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
            if self.alignment == .center {
                lineFrame.origin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            } else if self.alignment == .right {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
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
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
            if self.alignment == .center {
                lineFrame.origin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            } else if self.alignment == .right {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            }
            
            if lineFrame.insetBy(dx: -5.0, dy: -5.0).contains(transformedPoint) {
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
        return nil
    }
    
    private func attributeRects(name: NSAttributedStringKey, at index: Int) -> [CGRect]? {
        var range = NSRange()
        let _ = self.attributedString.attribute(name, at: index, effectiveRange: &range)
        if range.length != 0 {
            let boundsWidth = self.frame.width
            var rects: [CGRect] = []
            for i in 0 ..< self.lines.count {
                let line = self.lines[i]
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
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
                    if self.alignment == .center {
                        lineFrame.origin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
                    } else if self.alignment == .right {
                        lineFrame.origin.x = boundsWidth - lineFrame.size.width
                    } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                        lineFrame.origin.x = boundsWidth - lineFrame.size.width
                    }
                    
                    rects.append(CGRect(origin: CGPoint(x: lineFrame.minX + leftOffset, y: lineFrame.minY), size: CGSize(width: rightOffset - leftOffset, height: lineFrame.size.height)))
                }
            }
            if !rects.isEmpty {
                return rects
            }
        }
        
        return nil
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        if let (index, dict) = self.attributesAtPoint(point) {
            if let _ = dict[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] {
                if let rects = self.attributeRects(name: NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), at: index) {
                    return rects
                }
            }
        }
        
        return []
    }
    
    func urlAttribute(at point: CGPoint) -> InstantPageUrlItem? {
        if let (_, dict) = self.attributesAtPoint(point) {
            if let url = dict[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
                return url
            }
        }
        return nil
    }
    
    func lineRects() -> [CGRect] {
        let boundsWidth = self.frame.width
        var rects: [CGRect] = []
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
            if self.alignment == .center {
                lineFrame.origin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            } else if self.alignment == .right {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            }
            
            rects.append(lineFrame)
        }
        return rects
    }
    
    func plainText() -> String {
        if let first = self.lines.first, let last = self.lines.last {
            return self.attributedString.attributedSubstring(from: NSMakeRange(first.range.location, last.range.location + last.range.length - first.range.location)).string
        }
        return ""
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void) -> (InstantPageNode & ASDisplayNode)? {
        return nil
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}

func attributedStringForRichText(_ text: RichText, styleStack: InstantPageTextStyleStack, url: InstantPageUrlItem? = nil) -> NSAttributedString {
    switch text {
        case .empty:
            return NSAttributedString(string: "", attributes: styleStack.textAttributes())
        case let .plain(string):
            var attributes = styleStack.textAttributes()
            if let url = url {
                attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] = url
            }
            return NSAttributedString(string: string, attributes: attributes)
        case let .bold(text):
            styleStack.push(.bold)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .italic(text):
            styleStack.push(.italic)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .underline(text):
            styleStack.push(.underline)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .strikethrough(text):
            styleStack.push(.strikethrough)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .fixed(text):
            styleStack.push(.fontFixed(true))
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .url(text, url, webpageId):
            styleStack.push(.underline)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: InstantPageUrlItem(url: url, webpageId: webpageId))
            styleStack.pop()
            return result
        case let .email(text, email):
            styleStack.push(.bold)
            styleStack.push(.underline)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: InstantPageUrlItem(url: "mailto:\(email)", webpageId: nil))
            styleStack.pop()
            styleStack.pop()
            return result
        case let .concat(texts):
            let string = NSMutableAttributedString()
            for text in texts {
                let substring = attributedStringForRichText(text, styleStack: styleStack, url: url)
                string.append(substring)
            }
            return string
    }
}

func layoutTextItemWithString(_ string: NSAttributedString, boundingWidth: CGFloat) -> InstantPageTextItem {
    if string.length == 0 {
        return InstantPageTextItem(frame: CGRect(), attributedString: string, lines: [])
    }
    
    var lines: [InstantPageTextLine] = []
    guard let font = string.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) as? UIFont else {
        return InstantPageTextItem(frame: CGRect(), attributedString: string, lines: [])
    }
    
    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(NSAttributedStringKey(rawValue: InstantPageLineSpacingFactorAttribute), at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }
    
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font.ascender
    let fontDescent = font.descender
    
    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    
    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint()
    
    while true {
        let currentMaxWidth = boundingWidth - currentLineOrigin.x
        let currentLineInset: CGFloat = 0.0
        let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastIndex, Double(currentMaxWidth))
        
        if lineCharacterCount > 0 {
            let line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0)
            
            let trailingWhitespace = CGFloat(CTLineGetTrailingWhitespaceWidth(line))
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil) + Double(currentLineInset))
            
            var strikethroughItems: [InstantPageTextStrikethroughItem] = []
            
            let lineRange = NSMakeRange(lastIndex, lineCharacterCount)
            
            string.enumerateAttribute(NSAttributedStringKey.strikethroughStyle, in: lineRange, options: [], using: { item, range, _ in
                if let item = item {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    
                    strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: currentLineOrigin.x + lowerX, y: currentLineOrigin.y, width: upperX - lowerX, height: fontLineHeight)))
                }
            })
            
            var isRTL = false
            let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
            if glyphRuns.count != 0 {
                let run = glyphRuns[0] as! CTRun
                if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                    isRTL = true
                }
            }
            
            let textLine = InstantPageTextLine(line: line, range: lineRange, frame: CGRect(x: currentLineOrigin.x, y: currentLineOrigin.y, width: lineWidth, height: fontLineHeight), strikethroughItems: strikethroughItems, isRTL: isRTL)
            
            lines.append(textLine)
            
            currentLineOrigin.x = 0.0;
            currentLineOrigin.y += fontLineHeight + fontLineSpacing
            
            lastIndex += lineCharacterCount
        } else {
            break;
        }
    }
    
    var height: CGFloat = 0.0
    if !lines.isEmpty {
        height = lines.last!.frame.maxY
    }
    
    return InstantPageTextItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: height), attributedString: string, lines: lines)
}
