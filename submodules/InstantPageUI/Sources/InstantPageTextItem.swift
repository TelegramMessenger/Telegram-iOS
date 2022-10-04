import Foundation
import UIKit
import TelegramCore
import Display
import Postbox
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import ContextUI

public final class InstantPageUrlItem: Equatable {
    public let url: String
    public let webpageId: MediaId?
    
    public init(url: String, webpageId: MediaId?) {
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
    let anchorText: NSAttributedString?
    let empty: Bool
}

public struct InstantPageTextRangeRectEdge: Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var height: CGFloat
    
    public init(x: CGFloat, y: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.height = height
    }
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
    let opaqueBackground: Bool
    let medias: [InstantPageMedia] = []
    let anchors: [String: (Int, Bool)]
    let wantsNode: Bool = false
    let separatesTiles: Bool = false
    var selectable: Bool = true
    
    var containsRTL: Bool {
        return !self.rtlLineIndices.isEmpty
    }
    
    init(frame: CGRect, attributedString: NSAttributedString, alignment: NSTextAlignment, opaqueBackground: Bool, lines: [InstantPageTextLine]) {
        self.attributedString = attributedString
        self.alignment = alignment
        self.frame = frame
        self.opaqueBackground = opaqueBackground
        self.lines = lines
        var index = 0
        var rtlLineIndices = Set<Int>()
        var anchors: [String: (Int, Bool)] = [:]
        for line in lines {
            if line.isRTL {
                rtlLineIndices.insert(index)
            }
            for anchor in line.anchorItems {
                anchors[anchor.name] = (index, anchor.empty)
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
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.setFillColor(item.color.cgColor)
                    
                    let height = floor(item.frame.size.height * 2.2)
                    let rect = CGRect(x: itemFrame.minX - 2.0, y: floor(itemFrame.minY + (itemFrame.height - height) / 2.0), width: itemFrame.width + 4.0, height: height)
                    let path = UIBezierPath.init(roundedRect: rect, cornerRadius: 3.0)
                    context.addPath(path.cgPath)
                    context.fillPath()
                }
                context.restoreGState()
            }
            
            if self.opaqueBackground {
                context.setBlendMode(.normal)
            }
            
            let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
            if glyphRuns.count != 0 {
                for run in glyphRuns {
                    let run = run as! CTRun
                    let glyphCount = CTRunGetGlyphCount(run)
                    CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                }
            }
                        
            if self.opaqueBackground {
                context.setBlendMode(.copy)
            }
            
            if !line.strikethroughItems.isEmpty {
                for item in line.strikethroughItems {
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.fill(CGRect(x: itemFrame.minX, y: itemFrame.minY + floor((lineFrame.size.height / 2.0) + 1.0), width: itemFrame.size.width, height: 1.0))
                }
            }
        }
        
        context.restoreGState()
    }
    
    func attributesAtPoint(_ point: CGPoint) -> (Int, [NSAttributedString.Key: Any])? {
        let transformedPoint = CGPoint(x: point.x, y: point.y)
        let boundsWidth = self.frame.width
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            let lineFrame = frameForLine(line, boundingWidth: boundsWidth, alignment: self.alignment)
            if lineFrame.insetBy(dx: -5.0, dy: -5.0).contains(transformedPoint) {
                var index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: transformedPoint.x - lineFrame.minX, y: transformedPoint.y - lineFrame.minY))
                if index == self.attributedString.length {
                    index -= 1
                } else if index != 0 {
                    var glyphStart: CGFloat = 0.0
                    CTLineGetOffsetForStringIndex(line.line, index, &glyphStart)
                    if transformedPoint.x < glyphStart {
                        index -= 1
                    }
                }
                if index >= 0 && index < self.attributedString.length {
                    return (index, self.attributedString.attributes(at: index, effectiveRange: nil))
                }
                break
            }
        }
        return nil
    }
    
    private func attributeRects(name: NSAttributedString.Key, at index: Int) -> [CGRect]? {
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
                    if lineRange.location != line.range.location || line.isRTL {
                        leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                    }
                    var rightOffset: CGFloat = line.frame.width
                    if lineRange.location + lineRange.length != line.range.length || line.isRTL {
                        rightOffset = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                    }
                    let lineFrame = frameForLine(line, boundingWidth: boundsWidth, alignment: self.alignment)
                    let width = abs(rightOffset - leftOffset)
                    if width > 1.0 {
                        rects.append(CGRect(origin: CGPoint(x: lineFrame.minX + (leftOffset < rightOffset ? leftOffset : rightOffset), y: lineFrame.minY), size: CGSize(width: width, height: lineFrame.size.height)))
                    }
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
            if let _ = dict[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                if let rects = self.attributeRects(name: NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), at: index) {
                    return rects.compactMap { rect in
                        if rect.width > 5.0 {
                            return rect.insetBy(dx: 0.0, dy: -3.0)
                        } else {
                            return nil
                        }
                    }
                }
            }
        }
        return []
    }
    
    func urlAttribute(at point: CGPoint) -> InstantPageUrlItem? {
        if let (_, dict) = self.attributesAtPoint(point) {
            if let url = dict[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem {
                return url
            }
        }
        return nil
    }
    
    func rangeRects(in range: NSRange) -> (rects: [CGRect], start: InstantPageTextRangeRectEdge?, end: InstantPageTextRangeRectEdge?)? {
        guard range.length != 0 else {
            return nil
        }
        
        let boundsWidth = self.frame.width
        
        var rects: [(CGRect, CGRect)] = []
        var startEdge: InstantPageTextRangeRectEdge?
        var endEdge: InstantPageTextRangeRectEdge?
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            let lineRange = NSIntersectionRange(range, line.range)
            if lineRange.length != 0 {
                var leftOffset: CGFloat = 0.0
                if lineRange.location != line.range.location || line.isRTL {
                    leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                }
                var rightOffset: CGFloat = line.frame.width
                if lineRange.location + lineRange.length != line.range.upperBound || line.isRTL {
                    var secondaryOffset: CGFloat = 0.0
                    let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                    rightOffset = ceil(rawOffset)
                    if !rawOffset.isEqual(to: secondaryOffset) {
                        rightOffset = ceil(secondaryOffset)
                    }
                }
                
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
                
                let width = max(0.0, abs(rightOffset - leftOffset))
                
                if line.range.contains(range.lowerBound) {
                    let offsetX = floor(CTLineGetOffsetForStringIndex(line.line, range.lowerBound, nil))
                    startEdge = InstantPageTextRangeRectEdge(x: lineFrame.minX + offsetX, y: lineFrame.minY, height: lineFrame.height)
                }
                if line.range.contains(range.upperBound - 1) {
                    let offsetX: CGFloat
                    if line.range.upperBound == range.upperBound {
                        offsetX = lineFrame.maxX
                    } else {
                        var secondaryOffset: CGFloat = 0.0
                        let primaryOffset = floor(CTLineGetOffsetForStringIndex(line.line, range.upperBound - 1, &secondaryOffset))
                        secondaryOffset = floor(secondaryOffset)
                        let nextOffet = floor(CTLineGetOffsetForStringIndex(line.line, range.upperBound, &secondaryOffset))
                        
                        if primaryOffset != secondaryOffset {
                            offsetX = secondaryOffset
                        } else {
                            offsetX = nextOffet
                        }
                    }
                    endEdge = InstantPageTextRangeRectEdge(x: lineFrame.minX + offsetX, y: lineFrame.minY, height: lineFrame.height)
                }
                
                rects.append((lineFrame, CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset), y: lineFrame.minY), size: CGSize(width: width, height: lineFrame.size.height))))
            }
        }
        if !rects.isEmpty, let startEdge = startEdge, let endEdge = endEdge {
            return (rects.map { $1 }, startEdge, endEdge)
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
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
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

final class InstantPageScrollableTextItem: InstantPageScrollableItem {
    var frame: CGRect
    let totalWidth: CGFloat
    let horizontalInset: CGFloat
    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    
    let item: InstantPageTextItem
    let additionalItems: [InstantPageItem]
    let isRTL: Bool
    
    fileprivate init(frame: CGRect, item: InstantPageTextItem, additionalItems: [InstantPageItem], totalWidth: CGFloat, horizontalInset: CGFloat, rtl: Bool) {
        self.frame = frame
        self.item = item
        self.additionalItems = additionalItems
        self.totalWidth = totalWidth
        self.horizontalInset = horizontalInset
        self.isRTL = rtl
    }
    
    var contentSize: CGSize {
        return CGSize(width: self.totalWidth, height: self.frame.height)
    }
    
    func drawInTile(context: CGContext) {
        context.saveGState()
        context.translateBy(x: self.item.frame.minX, y: self.item.frame.minY)
        self.item.drawInTile(context: context)
        context.restoreGState()
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        var additionalNodes: [InstantPageNode] = []
        for item in additionalItems {
            if item.wantsNode {
                if let node = item.node(context: context, strings: strings, nameDisplayOrder: nameDisplayOrder, theme: theme, sourcePeerType: sourcePeerType, openMedia: { _ in }, longPressMedia: { _ in }, activatePinchPreview: nil, pinchPreviewFinished: nil, openPeer: { _ in }, openUrl: { _ in}, updateWebEmbedHeight: { _ in }, updateDetailsExpanded: { _ in }, currentExpandedDetails: nil) {
                    node.frame = item.frame
                    additionalNodes.append(node)
                }
            }
        }
        return InstantPageScrollableNode(item: self, additionalNodes: additionalNodes)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return self.item.matchesAnchor(anchor)
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageScrollableNode {
            return node.item === self
        }
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        let rects = self.item.linkSelectionRects(at: point.offsetBy(dx: -self.item.frame.minX - self.horizontalInset, dy: -self.item.frame.minY))
        return rects.map { $0.offsetBy(dx: self.item.frame.minX + self.horizontalInset, dy: -self.item.frame.minY) }
    }
    
    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        if self.item.selectable, self.item.frame.contains(location.offsetBy(dx: -self.item.frame.minX - self.horizontalInset, dy: -self.item.frame.minY)) {
            return (item, self.item.frame.origin.offsetBy(dx: self.horizontalInset, dy: -self.item.frame.minY))
        }
        return nil
    }
}

func attributedStringForRichText(_ text: RichText, styleStack: InstantPageTextStyleStack, url: InstantPageUrlItem? = nil, boundingWidth: CGFloat? = nil) -> NSAttributedString {
    switch text {
        case .empty:
            return NSAttributedString(string: "", attributes: styleStack.textAttributes())
        case let .plain(string):
            var attributes = styleStack.textAttributes()
            if let url = url {
                attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] = url
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
                let substring = attributedStringForRichText(text, styleStack: styleStack, url: url, boundingWidth: boundingWidth)
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
            var dimensions = dimensions
            if let boundingWidth = boundingWidth {
                dimensions = PixelDimensions(dimensions.cgSize.fittedToWidthOrSmaller(boundingWidth))
            }
            let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
            extentBuffer.initialize(to: RunStruct(ascent: 0.0, descent: 0.0, width: dimensions.cgSize.width))
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
            let attrDictionaryDelegate = [(kCTRunDelegateAttributeName as NSAttributedString.Key): (delegate as Any), NSAttributedString.Key(rawValue: InstantPageMediaIdAttribute): id.id, NSAttributedString.Key(rawValue: InstantPageMediaDimensionsAttribute): dimensions]
            let mutableAttributedString = attributedStringForRichText(.plain(" "), styleStack: styleStack, url: url).mutableCopy() as! NSMutableAttributedString
            mutableAttributedString.addAttributes(attrDictionaryDelegate, range: NSMakeRange(0, mutableAttributedString.length))
            return mutableAttributedString
        case let .anchor(text, name):
            var empty = false
            var text = text
            if case .empty = text {
                empty = true
                text = .plain("\u{200b}")
            }
            let anchorText = !empty ? attributedStringForRichText(text, styleStack: styleStack, url: url) : nil
            styleStack.push(.anchor(name, anchorText, empty))
            let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
            styleStack.pop()
            return result
    }
}

func layoutTextItemWithString(_ string: NSAttributedString, boundingWidth: CGFloat, horizontalInset: CGFloat = 0.0, alignment: NSTextAlignment = .natural, offset: CGPoint, media: [MediaId: Media] = [:], webpage: TelegramMediaWebpage? = nil, minimizeWidth: Bool = false, maxNumberOfLines: Int = 0, opaqueBackground: Bool = false) -> (InstantPageTextItem?, [InstantPageItem], CGSize) {
    if string.length == 0 {
        return (nil, [], CGSize())
    }
    
    var lines: [InstantPageTextLine] = []
    var imageItems: [InstantPageTextImageItem] = []
    var font = string.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) as? UIFont
    if font == nil {
        let range = NSMakeRange(0, string.length)
        string.enumerateAttributes(in: range, options: []) { attributes, range, _ in
            if font == nil, let furtherFont = attributes[NSAttributedString.Key.font] as? UIFont {
                font = furtherFont
            }
        }
    }
    let image = string.attribute(NSAttributedString.Key.init(rawValue: InstantPageMediaIdAttribute), at: 0, effectiveRange: nil)
    guard font != nil || image != nil else {
        return (nil, [], CGSize())
    }
    
    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(NSAttributedString.Key(rawValue: InstantPageLineSpacingFactorAttribute), at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }
    
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font?.ascender ?? 0.0
    let fontDescent = font?.descender ?? 0.0
    
    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    
    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint()

    var hasAnchors = false
    var maxLineWidth: CGFloat = 0.0
    var maxImageHeight: CGFloat = 0.0
    var extraDescent: CGFloat = 0.0
    let text = string.string
    var indexOffset: CFIndex?
    while true {
        var workingLineOrigin = currentLineOrigin
        
        let currentMaxWidth = boundingWidth - workingLineOrigin.x
        var lineCharacterCount: CFIndex
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
                if lineCharacterCount <= 0 {
                    lineCharacterCount = suggestedLineBreak
                }
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
            let substring = string.attributedSubstring(from: lineRange).string
            
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
            
            let hadExtraDescent = extraDescent > 0.0
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
                        if let id = attributes[NSAttributedString.Key.init(rawValue: InstantPageMediaIdAttribute)] as? Int64, let dimensions = attributes[NSAttributedString.Key.init(rawValue: InstantPageMediaDimensionsAttribute)] as? PixelDimensions {
                            var imageFrame = CGRect(origin: CGPoint(), size: dimensions.cgSize)
                            
                            let xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
                            let yOffset = fontLineHeight.isZero ? 0.0 : floorToScreenPixels((fontLineHeight - imageFrame.size.height) / 2.0)
                            imageFrame.origin = imageFrame.origin.offsetBy(dx: workingLineOrigin.x + xOffset, dy: workingLineOrigin.y + yOffset)
                            
                            let minSpacing = fontLineSpacing - 4.0
                            let delta = workingLineOrigin.y - minSpacing - imageFrame.minY - appliedLineOffset
                            if !fontAscent.isZero && delta > 0.0 {
                                workingLineOrigin.y += delta
                                appliedLineOffset += delta
                                imageFrame.origin = imageFrame.origin.offsetBy(dx: 0.0, dy: delta)
                            }
                            if !fontLineHeight.isZero {
                                extraDescent = max(extraDescent, imageFrame.maxY - (workingLineOrigin.y + fontLineHeight + minSpacing))
                            }
                            maxImageHeight = max(maxImageHeight, imageFrame.height)
                            lineImageItems.append(InstantPageTextImageItem(frame: imageFrame, range: range, id: MediaId(namespace: Namespaces.Media.CloudFile, id: id)))
                        }
                    }
                }
            }
            
            if substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lineImageItems.count > 0 {
                extraDescent += max(6.0, fontLineSpacing / 2.0)
            }
            
            if !minimizeWidth && !hadIndexOffset && lineCharacterCount > 1 && lineWidth > currentMaxWidth + 5.0, let imageItem = lineImageItems.last {
                indexOffset = -(lastIndex + lineCharacterCount - imageItem.range.lowerBound)
                continue
            }
            
            var strikethroughItems: [InstantPageTextStrikethroughItem] = []
            var markedItems: [InstantPageTextMarkedItem] = []
            var anchorItems: [InstantPageTextAnchorItem] = []
            
            string.enumerateAttributes(in: lineRange, options: []) { attributes, range, _ in
                if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y, width: abs(upperX - lowerX), height: fontLineHeight)))
                }
                if let color = attributes[NSAttributedString.Key.init(rawValue: InstantPageMarkerColorAttribute)] as? UIColor {
                    var lineHeight = fontLineHeight
                    var delta: CGFloat = 0.0
                    
                    if let offset = attributes[NSAttributedString.Key.baselineOffset] as? CGFloat {
                        lineHeight = floorToScreenPixels(lineHeight * 0.85)
                        delta = offset * 0.6
                    }
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    markedItems.append(InstantPageTextMarkedItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y + delta, width: abs(upperX - lowerX), height: lineHeight), color: color))
                }
                if let item = attributes[NSAttributedString.Key.init(rawValue: InstantPageAnchorAttribute)] as? Dictionary<String, Any>, let name = item["name"] as? String, let empty = item["empty"] as? Bool {
                    anchorItems.append(InstantPageTextAnchorItem(name: name, anchorText: item["text"] as? NSAttributedString, empty: empty))
                }
            }
            
            if !anchorItems.isEmpty {
                hasAnchors = true
            }
            
            if hadExtraDescent && extraDescent > 0 {
                workingLineOrigin.y += fontLineSpacing
            }
            
            let height = !fontLineHeight.isZero ? fontLineHeight : maxImageHeight
            let textLine = InstantPageTextLine(line: line, range: lineRange, frame: CGRect(x: workingLineOrigin.x, y: workingLineOrigin.y, width: lineWidth, height: height), strikethroughItems: strikethroughItems, markedItems: markedItems, imageItems: lineImageItems, anchorItems: anchorItems, isRTL: isRTL)
            
            lines.append(textLine)
            imageItems.append(contentsOf: lineImageItems)
            
            if lineWidth > maxLineWidth {
                maxLineWidth = lineWidth
            }
            
            workingLineOrigin.x = 0.0
            workingLineOrigin.y += fontLineHeight + fontLineSpacing + extraDescent
            currentLineOrigin = workingLineOrigin
            
            lastIndex += lineCharacterCount
            
            if stop {
                break
            }
        } else {
            break
        }
    }
    
    var height: CGFloat = 0.0
    if !lines.isEmpty && !(string.string == "\u{200b}" && hasAnchors) {
        height = lines.last!.frame.maxY + extraDescent
    }
    
    var textWidth = boundingWidth
    var requiresScroll = false
    if !imageItems.isEmpty && maxLineWidth > boundingWidth + 10.0 {
        textWidth = maxLineWidth
        requiresScroll = true
    }
    
    let textItem = InstantPageTextItem(frame: CGRect(x: 0.0, y: 0.0, width: textWidth, height: height), attributedString: string, alignment: alignment, opaqueBackground: opaqueBackground, lines: lines)
    if !requiresScroll {
        textItem.frame = textItem.frame.offsetBy(dx: offset.x, dy: offset.y)
    }
    var items: [InstantPageItem] = []
    if !requiresScroll && (imageItems.isEmpty || string.length > 1) {
        items.append(textItem)
    }
    
    var topInset: CGFloat = 0.0
    var bottomInset: CGFloat = 0.0
    var additionalItems: [InstantPageItem] = []
    if let webpage = webpage {
        let offset = requiresScroll ? CGPoint() : offset
        for line in textItem.lines {
            let lineFrame = frameForLine(line, boundingWidth: boundingWidth, alignment: alignment)
            for imageItem in line.imageItems {
                if let image = media[imageItem.id] as? TelegramMediaFile {
                    let item = InstantPageImageItem(frame: imageItem.frame.offsetBy(dx: lineFrame.minX + offset.x, dy: offset.y), webPage: webpage, media: InstantPageMedia(index: -1, media: image, url: nil, caption: nil, credit: nil), interactive: false, roundCorners: false, fit: false)
                    additionalItems.append(item)
                    
                    if item.frame.minY < topInset {
                        topInset = item.frame.minY
                    }
                    if item.frame.maxY > height {
                        bottomInset = max(bottomInset, item.frame.maxY - height)
                    }
                }
            }
        }
    }
    
    if requiresScroll {
        textItem.frame = textItem.frame.offsetBy(dx: 0.0, dy: abs(topInset))
        for var item in additionalItems {
            item.frame = item.frame.offsetBy(dx: 0.0, dy: abs(topInset))
        }
        
        let scrollableItem = InstantPageScrollableTextItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth + horizontalInset * 2.0, height: height + abs(topInset) + bottomInset), item: textItem, additionalItems: additionalItems, totalWidth: textWidth, horizontalInset: horizontalInset, rtl: textItem.containsRTL)
        items.append(scrollableItem)
    } else {
        items.append(contentsOf: additionalItems)
    }

    return (requiresScroll ? nil : textItem, items, textItem.frame.size)
}
