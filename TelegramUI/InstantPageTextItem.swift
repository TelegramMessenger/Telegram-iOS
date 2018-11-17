import Foundation
import TelegramCore
import Display
import Postbox
import AsyncDisplayKit

final class InstantPageUrlItem: Equatable {
    let url: String
    let webpageId: MediaId?
    
    init(url: String, webpageId: MediaId?) {
        self.url = url
        self.webpageId = webpageId
    }
    
    public static func ==(lhs: InstantPageUrlItem, rhs: InstantPageUrlItem) -> Bool {
        return lhs.url == rhs.url && lhs.webpageId == rhs.webpageId
    }
}

struct InstantPageTextMarkedItem {
    let frame: CGRect
    let color: UIColor
}

struct InstantPageTextStrikethroughItem {
    let frame: CGRect
}

struct InstantPageTextImageItem {
    let frame: CGRect
    let range: NSRange
    let id: MediaId
}

struct InstantPageTextAnchorItem {
    let name: String
}

final class InstantPageTextLine {
    let line: CTLine
    let range: NSRange
    let frame: CGRect
    let strikethroughItems: [InstantPageTextStrikethroughItem]
    let markedItems: [InstantPageTextMarkedItem]
    let imageItems: [InstantPageTextImageItem]
    let anchorItems: [InstantPageTextAnchorItem]
    let isRTL: Bool
    
    init(line: CTLine, range: NSRange, frame: CGRect, strikethroughItems: [InstantPageTextStrikethroughItem], markedItems: [InstantPageTextMarkedItem], imageItems: [InstantPageTextImageItem], anchorItems: [InstantPageTextAnchorItem], isRTL: Bool) {
        self.line = line
        self.range = range
        self.frame = frame
        self.strikethroughItems = strikethroughItems
        self.markedItems = markedItems
        self.imageItems = imageItems
        self.anchorItems = anchorItems
        self.isRTL = isRTL
    }
}

private func frameForLine(_ line: InstantPageTextLine, boundingWidth: CGFloat, alignment: NSTextAlignment) -> CGRect {
    var lineFrame = line.frame
    if alignment == .center {
        lineFrame.origin.x = floor((boundingWidth - lineFrame.size.width) / 2.0)
    } else if alignment == .right || (alignment == .natural && line.isRTL) {
        lineFrame.origin.x = boundingWidth - lineFrame.size.width
    }
    return lineFrame
}

final class InstantPageTextItem: InstantPageItem {
    let attributedString: NSAttributedString
    let lines: [InstantPageTextLine]
    let rtlLineIndices: Set<Int>
    var frame: CGRect
    let alignment: NSTextAlignment
    let medias: [InstantPageMedia] = []
    let anchors: [String: Int]
    let wantsNode: Bool = false
    let separatesTiles: Bool = false
    var selectable: Bool = true
    
    var containsRTL: Bool {
        return !self.rtlLineIndices.isEmpty
    }
    
    init(frame: CGRect, attributedString: NSAttributedString, alignment: NSTextAlignment, lines: [InstantPageTextLine]) {
        self.attributedString = attributedString
        self.alignment = alignment
        self.frame = frame
        self.lines = lines
        var index = 0
        var rtlLineIndices = Set<Int>()
        var anchors: [String: Int] = [:]
        for line in lines {
            if line.isRTL {
                rtlLineIndices.insert(index)
            }
            for anchor in line.anchorItems {
                anchors[anchor.name] = index
            }
            index += 1
        }
        self.rtlLineIndices = rtlLineIndices
        self.anchors = anchors
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
            
            let lineFrame = frameForLine(line, boundingWidth: boundsWidth, alignment: self.alignment)
            if lineFrame.maxY < upperOriginBound || lineFrame.minY > lowerOriginBound {
                continue
            }
            
            let lineOrigin = lineFrame.origin
            context.textPosition = CGPoint(x: lineOrigin.x, y: lineOrigin.y + lineFrame.size.height)
            
            if !line.markedItems.isEmpty {
                context.saveGState()
                for item in line.markedItems {
                    context.setFillColor(item.color.cgColor)
                    
                    let height = floor(item.frame.size.height * 2.2)
                    let rect = CGRect(x: item.frame.minX - 2.0, y: floor(item.frame.minY + (item.frame.height - height) / 2.0), width: item.frame.width + 4.0, height: height)
                    let path = UIBezierPath.init(roundedRect: rect, cornerRadius: 3.0)
                    context.addPath(path.cgPath)
                    context.fillPath()
                }
                context.restoreGState()
            }
            
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
            
            let lineFrame = frameForLine(line, boundingWidth: boundsWidth, alignment: self.alignment)
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
                    let lineFrame = frameForLine(line, boundingWidth: boundsWidth, alignment: self.alignment)
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
                    return rects.map { $0.insetBy(dx: 2.0, dy: -3.0) }
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
        var topLeft = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: 0.0)
        var bottomRight = CGPoint()
        
        var lastLineFrame: CGRect?
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            var lineFrame = line.frame
            for imageItem in line.imageItems {
                if imageItem.frame.minY < lineFrame.minY {
                    let delta = lineFrame.minY - imageItem.frame.minY - 2.0
                    lineFrame = CGRect(x: lineFrame.minX, y: lineFrame.minY - delta, width: lineFrame.width, height: lineFrame.height + delta)
                }
                if imageItem.frame.maxY > lineFrame.maxY {
                    let delta = imageItem.frame.maxY - lineFrame.maxY - 2.0
                    lineFrame = CGRect(x: lineFrame.minX, y: lineFrame.minY, width: lineFrame.width, height: lineFrame.height + delta)
                }
            }
            lineFrame = lineFrame.insetBy(dx: 0.0, dy: -4.0)
            if self.alignment == .center {
                lineFrame.origin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            } else if self.alignment == .right {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            }
            
            if lineFrame.minX < topLeft.x {
                topLeft = CGPoint(x: lineFrame.minX, y: topLeft.y)
            }
            if lineFrame.maxX > bottomRight.x {
                bottomRight = CGPoint(x: lineFrame.maxX, y: bottomRight.y)
            }
            
            if self.lines.count > 1 && i == self.lines.count - 1 {
                lastLineFrame = lineFrame
            } else {
                if lineFrame.minY < topLeft.y {
                    topLeft = CGPoint(x: topLeft.x, y: lineFrame.minY)
                }
                if lineFrame.maxY > bottomRight.y {
                    bottomRight = CGPoint(x: bottomRight.x, y: lineFrame.maxY)
                }
            }
        }
        rects.append(CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
        if self.lines.count > 1, var lastLineFrame = lastLineFrame {
            let delta = lastLineFrame.minY - bottomRight.y
            lastLineFrame = CGRect(x: lastLineFrame.minX, y: bottomRight.y, width: lastLineFrame.width, height: lastLineFrame.height + delta)
            rects.append(lastLineFrame)
        }
        
        return rects
    }
    
    func effectiveWidth() -> CGFloat {
        var width: CGFloat = 0.0
        for line in self.lines {
            width = max(width, line.frame.width)
        }
        return ceil(width)
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
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> (InstantPageNode & ASDisplayNode)? {
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
            styleStack.push(.link(webpageId != nil))
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
        case let .subscript(text):
            styleStack.push(.subscript)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .superscript(text):
            styleStack.push(.superscript)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .marked(text):
            styleStack.push(.marker)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
        case let .phone(text, phone):
            styleStack.push(.bold)
            styleStack.push(.underline)
            let result = attributedStringForRichText(text, styleStack: styleStack, url: InstantPageUrlItem(url: "tel:\(phone)", webpageId: nil))
            styleStack.pop()
            styleStack.pop()
            return result
        case let .image(id, dimensions):
            struct RunStruct {
                let ascent: CGFloat
                let descent: CGFloat
                let width: CGFloat
            }
            let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
            extentBuffer.initialize(to: RunStruct(ascent: dimensions.height, descent: 0.0, width: dimensions.width))
            var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (pointer) in
            }, getAscent: { (pointer) -> CGFloat in
                let d = pointer.assumingMemoryBound(to: RunStruct.self)
                return d.pointee.ascent
            }, getDescent: { (pointer) -> CGFloat in
                let d = pointer.assumingMemoryBound(to: RunStruct.self)
                return d.pointee.descent
            }, getWidth: { (pointer) -> CGFloat in
                let d = pointer.assumingMemoryBound(to: RunStruct.self)
                return d.pointee.width
            })
            let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)
            let attrDictionaryDelegate = [(kCTRunDelegateAttributeName as NSAttributedStringKey): (delegate as Any), NSAttributedStringKey(rawValue: InstantPageMediaIdAttribute): id.id]
            return NSAttributedString(string: " ", attributes: attrDictionaryDelegate)
        case let .anchor(text, name):
            styleStack.push(.anchor(name))
            var text = text
            if case .empty = text {
                text = .plain("\u{200b}")
            }
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
    }
}

func layoutTextItemWithString(_ string: NSAttributedString, boundingWidth: CGFloat, alignment: NSTextAlignment = .natural, offset: CGPoint, media: [MediaId: Media] = [:], webpage: TelegramMediaWebpage? = nil, minimizeWidth: Bool = false, maxNumberOfLines: Int = 0) -> (InstantPageTextItem?, [InstantPageItem], CGSize) {
    if string.length == 0 {
        return (nil, [], CGSize())
    }
    
    var lines: [InstantPageTextLine] = []
    var imageItems: [InstantPageTextImageItem] = []
    var font = string.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) as? UIFont
    if font == nil {
        let range = NSMakeRange(0, string.length)
        string.enumerateAttributes(in: range, options: []) { attributes, range, _ in
            if font == nil, let furtherFont = attributes[NSAttributedStringKey.font] as? UIFont {
                font = furtherFont
            }
        }
    }
    let image = string.attribute(NSAttributedStringKey.init(rawValue: InstantPageMediaIdAttribute), at: 0, effectiveRange: nil)
    guard font != nil || image != nil else {
        return (nil, [], CGSize())
    }
    
    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(NSAttributedStringKey(rawValue: InstantPageLineSpacingFactorAttribute), at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }
    
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font?.ascender ?? 0.0
    let fontDescent = font?.descender ?? 0.0
    
    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    
    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint()
    
    var maxImageHeight: CGFloat = 0.0
    var extraDescent: CGFloat = 0.0
    let text = string.string
    var indexOffset: CFIndex?
    while true {
        let currentMaxWidth = boundingWidth - currentLineOrigin.x
        let lineCharacterCount: CFIndex
        var hadIndexOffset = false
        if minimizeWidth {
            var count = 0
            for ch in text.suffix(text.count - lastIndex) {
                count += 1
                if ch == " " || ch == "\n" || ch == "\t" {
                    break
                }
            }
            lineCharacterCount = count
        } else {
            let suggestedLineBreak = CTTypesetterSuggestLineBreak(typesetter, lastIndex, Double(currentMaxWidth))
            if let offset = indexOffset {
                lineCharacterCount = suggestedLineBreak + offset
                indexOffset = nil
                hadIndexOffset = true
            } else {
                lineCharacterCount = suggestedLineBreak
            }
        }
        if lineCharacterCount > 0 {
            var line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0)
            var lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let lineRange = NSMakeRange(lastIndex, lineCharacterCount)
            
            var stop = false
            if maxNumberOfLines > 0 && lines.count == maxNumberOfLines - 1 && lastIndex + lineCharacterCount < string.length {
                let attributes = string.attributes(at: lastIndex + lineCharacterCount - 1, effectiveRange: nil)
                if let truncateString = CFAttributedStringCreate(nil, "\u{2026}" as CFString, attributes as CFDictionary) {
                    let truncateToken = CTLineCreateWithAttributedString(truncateString)
                    let tokenWidth = CGFloat(CTLineGetTypographicBounds(truncateToken, nil, nil, nil) + 3.0)
                    if let truncatedLine = CTLineCreateTruncatedLine(line, Double(lineWidth - tokenWidth), .end, truncateToken) {
                        lineWidth += tokenWidth
                        line = truncatedLine
                    }
                }
                stop = true
            }
            
            var strikethroughItems: [InstantPageTextStrikethroughItem] = []
            var markedItems: [InstantPageTextMarkedItem] = []
            var anchorItems: [InstantPageTextAnchorItem] = []
            
            string.enumerateAttributes(in: lineRange, options: []) { attributes, range, _ in
                if let _ = attributes[NSAttributedStringKey.strikethroughStyle] {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: currentLineOrigin.x + lowerX, y: currentLineOrigin.y, width: upperX - lowerX, height: fontLineHeight)))
                }
                if let color = attributes[NSAttributedStringKey.init(rawValue: InstantPageMarkerColorAttribute)] as? UIColor {
                    var lineHeight = fontLineHeight
                    var delta: CGFloat = 0.0
                    
                    if let offset = attributes[NSAttributedStringKey.baselineOffset] as? CGFloat {
                        lineHeight = floorToScreenPixels(lineHeight * 0.85)
                        delta = offset * 0.6
                    }
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    markedItems.append(InstantPageTextMarkedItem(frame: CGRect(x: currentLineOrigin.x + lowerX, y: currentLineOrigin.y + delta, width: upperX - lowerX, height: lineHeight), color: color))
                }
                if let item = attributes[NSAttributedStringKey.init(rawValue: InstantPageAnchorAttribute)] as? String {
                    anchorItems.append(InstantPageTextAnchorItem(name: item))
                }
            }
            
            extraDescent = 0.0
            var lineImageItems: [InstantPageTextImageItem] = []
            var isRTL = false
            if let glyphRuns = CTLineGetGlyphRuns(line) as? [CTRun], !glyphRuns.isEmpty {
                if let run = glyphRuns.first, CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                    isRTL = true
                }
                
                var appliedLineOffset: CGFloat = 0.0
                for run in glyphRuns {
                    let cfRunRange = CTRunGetStringRange(run)
                    let runRange = NSMakeRange(cfRunRange.location == kCFNotFound ? NSNotFound : cfRunRange.location, cfRunRange.length)
                    string.enumerateAttributes(in: runRange, options: []) { attributes, range, _ in
                        if let id = attributes[NSAttributedStringKey.init(rawValue: InstantPageMediaIdAttribute)] as? Int64 {
                            var imageFrame = CGRect()
                            var ascent: CGFloat = 0
                            imageFrame.size.width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, nil, nil))
                            imageFrame.size.height = ascent
                            
                            let xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
                            let yOffset = fontLineHeight.isZero ? 0.0 : floorToScreenPixels((fontLineHeight - imageFrame.size.height) / 2.0)
                            imageFrame.origin = imageFrame.origin.offsetBy(dx: currentLineOrigin.x + xOffset, dy: currentLineOrigin.y + yOffset)
                            
                            let minSpacing = fontLineSpacing - 3.0
                            let delta = currentLineOrigin.y - minSpacing - imageFrame.minY - appliedLineOffset
                            if !fontAscent.isZero && delta > 0.0 {
                                currentLineOrigin.y += delta
                                appliedLineOffset += delta
                                imageFrame.origin = imageFrame.origin.offsetBy(dx: 0.0, dy: delta)
                            }
                            if !fontLineHeight.isZero {
                                extraDescent = max(extraDescent, imageFrame.maxY - (currentLineOrigin.y + fontLineHeight + minSpacing))
                            }
                            maxImageHeight = max(maxImageHeight, imageFrame.height)
                            lineImageItems.append(InstantPageTextImageItem(frame: imageFrame, range: range, id: MediaId(namespace: Namespaces.Media.CloudFile, id: id)))
                        }
                    }
                }
            }
            
            if !minimizeWidth && !hadIndexOffset && lineCharacterCount > 1 && lineWidth > currentMaxWidth, let imageItem = lineImageItems.last {
                indexOffset = -(lastIndex + lineCharacterCount - imageItem.range.lowerBound)
                continue
            }
            
            let height = !fontLineHeight.isZero ? fontLineHeight : maxImageHeight
            let textLine = InstantPageTextLine(line: line, range: lineRange, frame: CGRect(x: currentLineOrigin.x, y: currentLineOrigin.y, width: lineWidth, height: height), strikethroughItems: strikethroughItems, markedItems: markedItems, imageItems: lineImageItems, anchorItems: anchorItems, isRTL: isRTL)
            
            lines.append(textLine)
            imageItems.append(contentsOf: lineImageItems)
            
            currentLineOrigin.x = 0.0;
            currentLineOrigin.y += fontLineHeight + fontLineSpacing + extraDescent
            
            lastIndex += lineCharacterCount
            
            if stop {
                break
            }
        } else {
            break
        }
    }
    
    var height: CGFloat = 0.0
    if !lines.isEmpty {
        height = lines.last!.frame.maxY + extraDescent
    }
    
    let textItem = InstantPageTextItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: height), attributedString: string, alignment: alignment, lines: lines)
    textItem.frame = textItem.frame.offsetBy(dx: offset.x, dy: offset.y)
    var items: [InstantPageItem] = []
    if imageItems.isEmpty || string.length > 1 {
        items.append(textItem)
    }
    
    if let webpage = webpage {
        for line in textItem.lines {
            let lineFrame = frameForLine(line, boundingWidth: boundingWidth, alignment: alignment)
            for imageItem in line.imageItems {
                if let image = media[imageItem.id] as? TelegramMediaFile {
                    items.append(InstantPageImageItem(frame: imageItem.frame.offsetBy(dx: lineFrame.minX + offset.x, dy: offset.y), webPage: webpage, media: InstantPageMedia(index: -1, media: image, url: nil, caption: nil, credit: nil), interactive: false, roundCorners: false, fit: false))
                }
            }
        }
    }
    
    return (textItem, items, textItem.frame.size)
}
