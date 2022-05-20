import Foundation
import UIKit
import AsyncDisplayKit
import CoreText

private let defaultFont = UIFont.systemFont(ofSize: 15.0)

private final class TextNodeStrikethrough {
    let range: NSRange
    let frame: CGRect
    
    init(range: NSRange, frame: CGRect) {
        self.range = range
        self.frame = frame
    }
}

private final class TextNodeSpoiler {
    let range: NSRange
    let frame: CGRect
    
    init(range: NSRange, frame: CGRect) {
        self.range = range
        self.frame = frame
    }
}


private final class TextNodeEmbeddedItem {
    let range: NSRange
    let frame: CGRect
    let item: AnyHashable
    
    init(range: NSRange, frame: CGRect, item: AnyHashable) {
        self.range = range
        self.frame = frame
        self.item = item
    }
}

public struct TextRangeRectEdge: Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var height: CGFloat
    
    public init(x: CGFloat, y: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.height = height
    }
}

private final class TextNodeLine {
    let line: CTLine
    let frame: CGRect
    let range: NSRange
    let isRTL: Bool
    let strikethroughs: [TextNodeStrikethrough]
    let spoilers: [TextNodeSpoiler]
    let spoilerWords: [TextNodeSpoiler]
    let embeddedItems: [TextNodeEmbeddedItem]
    
    init(line: CTLine, frame: CGRect, range: NSRange, isRTL: Bool, strikethroughs: [TextNodeStrikethrough], spoilers: [TextNodeSpoiler], spoilerWords: [TextNodeSpoiler], embeddedItems: [TextNodeEmbeddedItem]) {
        self.line = line
        self.frame = frame
        self.range = range
        self.isRTL = isRTL
        self.strikethroughs = strikethroughs
        self.spoilers = spoilers
        self.spoilerWords = spoilerWords
        self.embeddedItems = embeddedItems
    }
}

private final class TextNodeBlockQuote {
    let frame: CGRect
    
    init(frame: CGRect) {
        self.frame = frame
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

public enum TextVerticalAlignment {
    case top
    case middle
    case bottom
}

public final class TextNodeLayoutArguments {
    public let attributedString: NSAttributedString?
    public let backgroundColor: UIColor?
    public let minimumNumberOfLines: Int
    public let maximumNumberOfLines: Int
    public let truncationType: CTLineTruncationType
    public let constrainedSize: CGSize
    public let alignment: NSTextAlignment
    public let verticalAlignment: TextVerticalAlignment
    public let lineSpacing: CGFloat
    public let cutout: TextNodeCutout?
    public let insets: UIEdgeInsets
    public let lineColor: UIColor?
    public let textShadowColor: UIColor?
    public let textStroke: (UIColor, CGFloat)?
    public let displaySpoilers: Bool
    
    public init(attributedString: NSAttributedString?, backgroundColor: UIColor? = nil, minimumNumberOfLines: Int = 0, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, alignment: NSTextAlignment = .natural, verticalAlignment: TextVerticalAlignment = .top, lineSpacing: CGFloat = 0.12, cutout: TextNodeCutout? = nil, insets: UIEdgeInsets = UIEdgeInsets(), lineColor: UIColor? = nil, textShadowColor: UIColor? = nil, textStroke: (UIColor, CGFloat)? = nil, displaySpoilers: Bool = false) {
        self.attributedString = attributedString
        self.backgroundColor = backgroundColor
        self.minimumNumberOfLines = minimumNumberOfLines
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.alignment = alignment
        self.verticalAlignment = verticalAlignment
        self.lineSpacing = lineSpacing
        self.cutout = cutout
        self.insets = insets
        self.lineColor = lineColor
        self.textShadowColor = textShadowColor
        self.textStroke = textStroke
        self.displaySpoilers = displaySpoilers
    }
}

public final class TextNodeLayout: NSObject {
    public final class EmbeddedItem: Equatable {
        public let range: NSRange
        public let rect: CGRect
        public let value: AnyHashable
        
        public init(range: NSRange, rect: CGRect, value: AnyHashable) {
            self.range = range
            self.rect = rect
            self.value = value
        }
        
        public static func ==(lhs: EmbeddedItem, rhs: EmbeddedItem) -> Bool {
            if lhs.range != rhs.range {
                return false
            }
            if lhs.rect != rhs.rect {
                return false
            }
            if lhs.value != rhs.value {
                return false
            }
            return true
        }
    }
    
    public let attributedString: NSAttributedString?
    fileprivate let maximumNumberOfLines: Int
    fileprivate let truncationType: CTLineTruncationType
    fileprivate let backgroundColor: UIColor?
    fileprivate let constrainedSize: CGSize
    fileprivate let explicitAlignment: NSTextAlignment
    fileprivate let resolvedAlignment: NSTextAlignment
    fileprivate let verticalAlignment: TextVerticalAlignment
    fileprivate let lineSpacing: CGFloat
    fileprivate let cutout: TextNodeCutout?
    public let insets: UIEdgeInsets
    public let size: CGSize
    public let rawTextSize: CGSize
    public let truncated: Bool
    fileprivate let firstLineOffset: CGFloat
    fileprivate let lines: [TextNodeLine]
    fileprivate let blockQuotes: [TextNodeBlockQuote]
    fileprivate let lineColor: UIColor?
    fileprivate let textShadowColor: UIColor?
    fileprivate let textStroke: (UIColor, CGFloat)?
    fileprivate let displaySpoilers: Bool
    public let hasRTL: Bool
    public let spoilers: [(NSRange, CGRect)]
    public let spoilerWords: [(NSRange, CGRect)]
    public let embeddedItems: [TextNodeLayout.EmbeddedItem]
    
    fileprivate init(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, explicitAlignment: NSTextAlignment, resolvedAlignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacing: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, size: CGSize, rawTextSize: CGSize, truncated: Bool, firstLineOffset: CGFloat, lines: [TextNodeLine], blockQuotes: [TextNodeBlockQuote], backgroundColor: UIColor?, lineColor: UIColor?, textShadowColor: UIColor?, textStroke: (UIColor, CGFloat)?, displaySpoilers: Bool) {
        self.attributedString = attributedString
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.explicitAlignment = explicitAlignment
        self.resolvedAlignment = resolvedAlignment
        self.verticalAlignment = verticalAlignment
        self.lineSpacing = lineSpacing
        self.cutout = cutout
        self.insets = insets
        self.size = size
        self.rawTextSize = rawTextSize
        self.truncated = truncated
        self.firstLineOffset = firstLineOffset
        self.lines = lines
        self.blockQuotes = blockQuotes
        self.backgroundColor = backgroundColor
        self.lineColor = lineColor
        self.textShadowColor = textShadowColor
        self.textStroke = textStroke
        self.displaySpoilers = displaySpoilers
        var hasRTL = false
        var spoilers: [(NSRange, CGRect)] = []
        var spoilerWords: [(NSRange, CGRect)] = []
        var embeddedItems: [TextNodeLayout.EmbeddedItem] = []
        for line in lines {
            if line.isRTL {
                hasRTL = true
            }
            
            let lineFrame: CGRect
            switch self.resolvedAlignment {
            case .center:
                lineFrame = CGRect(origin: CGPoint(x: floor((size.width - line.frame.size.width) / 2.0), y: line.frame.minY), size: line.frame.size)
            default:
                lineFrame = displayLineFrame(frame: line.frame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: size), cutout: cutout)
            }
            
            spoilers.append(contentsOf: line.spoilers.map { ( $0.range, $0.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)) })
            spoilerWords.append(contentsOf: line.spoilerWords.map { ( $0.range, $0.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)) })
            for embeddedItem in line.embeddedItems {
                embeddedItems.append(TextNodeLayout.EmbeddedItem(range: embeddedItem.range, rect: embeddedItem.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY), value: embeddedItem.item))
            }
        }
        self.hasRTL = hasRTL
        self.spoilers = spoilers
        self.spoilerWords = spoilerWords
        self.embeddedItems = embeddedItems
    }
    
    public func areLinesEqual(to other: TextNodeLayout) -> Bool {
        if self.lines.count != other.lines.count {
            return false
        }
        for i in 0 ..< self.lines.count {
            if !self.lines[i].frame.equalTo(other.lines[i].frame) {
                return false
            }
            if self.lines[i].isRTL != other.lines[i].isRTL {
                return false
            }
            if self.lines[i].range != other.lines[i].range {
                return false
            }
            let lhsRuns = CTLineGetGlyphRuns(self.lines[i].line) as NSArray
            let rhsRuns = CTLineGetGlyphRuns(other.lines[i].line) as NSArray
            
            if lhsRuns.count != rhsRuns.count {
                return false
            }
            
            for j in 0 ..< lhsRuns.count {
                let lhsRun = lhsRuns[j] as! CTRun
                let rhsRun = rhsRuns[j] as! CTRun
                let lhsGlyphCount = CTRunGetGlyphCount(lhsRun)
                let rhsGlyphCount = CTRunGetGlyphCount(rhsRun)
                if lhsGlyphCount != rhsGlyphCount {
                    return false
                }
                
                for k in 0 ..< lhsGlyphCount {
                    var lhsGlyph = CGGlyph()
                    var rhsGlyph = CGGlyph()
                    CTRunGetGlyphs(lhsRun, CFRangeMake(k, 1), &lhsGlyph)
                    CTRunGetGlyphs(rhsRun, CFRangeMake(k, 1), &rhsGlyph)
                    if lhsGlyph != rhsGlyph {
                        return false
                    }
                }
            }
        }
        return true
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

    public var trailingLineIsRTL: Bool {
        if let lastLine = self.lines.last {
            return lastLine.isRTL
        } else {
            return false
        }
    }
    
    public func attributesAtPoint(_ point: CGPoint, orNearest: Bool) -> (Int, [NSAttributedString.Key: Any])? {
        if let attributedString = self.attributedString {
            let transformedPoint = CGPoint(x: point.x - self.insets.left, y: point.y - self.insets.top)
            if orNearest {
                var lineIndex = -1
                var closestLine: (Int, CGRect, CGFloat)?
                for line in self.lines {
                    lineIndex += 1
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                    switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    default:
                        break
                    }
                    
                    let currentDistance = (lineFrame.center.y - point.y) * (lineFrame.center.y - point.y)
                    if let current = closestLine {
                        if current.2 > currentDistance {
                            closestLine = (lineIndex, lineFrame, currentDistance)
                        }
                    } else {
                        closestLine = (lineIndex, lineFrame, currentDistance)
                    }
                }
                
                if let (index, lineFrame, _) = closestLine {
                    let line = self.lines[index]
                    
                    let lineRange = CTLineGetStringRange(line.line)
                    var index: Int
                    if transformedPoint.x <= lineFrame.minX {
                        index = lineRange.location
                    } else if transformedPoint.x >= lineFrame.maxX {
                        index = lineRange.location + lineRange.length
                    } else {
                        index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: transformedPoint.x - lineFrame.minX, y: floor(lineFrame.height / 2.0)))
                        if index != 0 {
                            var glyphStart: CGFloat = 0.0
                            CTLineGetOffsetForStringIndex(line.line, index, &glyphStart)
                            if transformedPoint.x < glyphStart {
                                var closestLowerIndex: Int?
                                let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                                if glyphRuns.count != 0 {
                                    for run in glyphRuns {
                                        let run = run as! CTRun
                                        let glyphCount = CTRunGetGlyphCount(run)
                                        for i in 0 ..< glyphCount {
                                            var glyphIndex: CFIndex = 0
                                            CTRunGetStringIndices(run, CFRangeMake(i, 1), &glyphIndex)
                                            if glyphIndex < index {
                                                if let closestLowerIndexValue = closestLowerIndex {
                                                    if closestLowerIndexValue < glyphIndex {
                                                        closestLowerIndex = glyphIndex
                                                    }
                                                } else {
                                                    closestLowerIndex = glyphIndex
                                                }
                                            }
                                        }
                                    }
                                }
                                if let closestLowerIndex = closestLowerIndex {
                                    index = closestLowerIndex
                                }
                            }
                        }
                    }
                    return (index, [:])
                }
            }
            var lineIndex = -1
            for line in self.lines {
                lineIndex += 1
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    default:
                        break
                }
                if lineFrame.contains(transformedPoint) {
                    var index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: transformedPoint.x - lineFrame.minX, y: transformedPoint.y - lineFrame.minY))
                    if index == attributedString.length {
                        var closestLowerIndex: Int?
                        let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                        if glyphRuns.count != 0 {
                            for run in glyphRuns {
                                let run = run as! CTRun
                                let glyphCount = CTRunGetGlyphCount(run)
                                for i in 0 ..< glyphCount {
                                    var glyphIndex: CFIndex = 0
                                    CTRunGetStringIndices(run, CFRangeMake(i, 1), &glyphIndex)
                                    if glyphIndex < index {
                                        if let closestLowerIndexValue = closestLowerIndex {
                                            if closestLowerIndexValue < glyphIndex {
                                                closestLowerIndex = glyphIndex
                                            }
                                        } else {
                                            closestLowerIndex = glyphIndex
                                        }
                                    }
                                }
                            }
                        }
                        if let closestLowerIndex = closestLowerIndex {
                            index = closestLowerIndex
                        }
                    } else if index != 0 {
                        var glyphStart: CGFloat = 0.0
                        CTLineGetOffsetForStringIndex(line.line, index, &glyphStart)
                        if transformedPoint.x < glyphStart {
                            var closestLowerIndex: Int?
                            let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                            if glyphRuns.count != 0 {
                                for run in glyphRuns {
                                    let run = run as! CTRun
                                    let glyphCount = CTRunGetGlyphCount(run)
                                    for i in 0 ..< glyphCount {
                                        var glyphIndex: CFIndex = 0
                                        CTRunGetStringIndices(run, CFRangeMake(i, 1), &glyphIndex)
                                        if glyphIndex < index {
                                            if let closestLowerIndexValue = closestLowerIndex {
                                                if closestLowerIndexValue < glyphIndex {
                                                    closestLowerIndex = glyphIndex
                                                }
                                            } else {
                                                closestLowerIndex = glyphIndex
                                            }
                                        }
                                    }
                                }
                            }
                            if let closestLowerIndex = closestLowerIndex {
                                index = closestLowerIndex
                            }
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
                switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    default:
                        break
                }
                if lineFrame.offsetBy(dx: 0.0, dy: -lineFrame.size.height).insetBy(dx: -3.0, dy: -3.0).contains(transformedPoint) {
                    var index = CTLineGetStringIndexForPosition(line.line, CGPoint(x: transformedPoint.x - lineFrame.minX, y: transformedPoint.y - lineFrame.minY))
                    if index == attributedString.length {
                        var closestLowerIndex: Int?
                        let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                        if glyphRuns.count != 0 {
                            for run in glyphRuns {
                                let run = run as! CTRun
                                let glyphCount = CTRunGetGlyphCount(run)
                                for i in 0 ..< glyphCount {
                                    var glyphIndex: CFIndex = 0
                                    CTRunGetStringIndices(run, CFRangeMake(i, 1), &glyphIndex)
                                    if glyphIndex < index {
                                        if let closestLowerIndexValue = closestLowerIndex {
                                            if closestLowerIndexValue < glyphIndex {
                                                closestLowerIndex = glyphIndex
                                            }
                                        } else {
                                            closestLowerIndex = glyphIndex
                                        }
                                    }
                                }
                            }
                        }
                        if let closestLowerIndex = closestLowerIndex {
                            index = closestLowerIndex
                        }
                    } else if index != 0 {
                        var glyphStart: CGFloat = 0.0
                        CTLineGetOffsetForStringIndex(line.line, index, &glyphStart)
                        if transformedPoint.x < glyphStart {
                            var closestLowerIndex: Int?
                            let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                            if glyphRuns.count != 0 {
                                for run in glyphRuns {
                                    let run = run as! CTRun
                                    let glyphCount = CTRunGetGlyphCount(run)
                                    for i in 0 ..< glyphCount {
                                        var glyphIndex: CFIndex = 0
                                        CTRunGetStringIndices(run, CFRangeMake(i, 1), &glyphIndex)
                                        if glyphIndex < index {
                                            if let closestLowerIndexValue = closestLowerIndex {
                                                if closestLowerIndexValue < glyphIndex {
                                                    closestLowerIndex = glyphIndex
                                                }
                                            } else {
                                                closestLowerIndex = glyphIndex
                                            }
                                        }
                                    }
                                }
                            }
                            if let closestLowerIndex = closestLowerIndex {
                                index = closestLowerIndex
                            }
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
    
    public func textRangesRects(text: String) -> [[CGRect]] {
        guard let attributedString = self.attributedString else {
            return []
        }
        
        let (ranges, searchText) = findSubstringRanges(in: attributedString.string, query: text)

        var result: [[CGRect]] = []
        for stringRange in ranges {
            var rects: [CGRect] = []
            let range = NSRange(stringRange, in: searchText)
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
                    
                    let width = abs(rightOffset - leftOffset)
                    rects.append(CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset) + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: width, height: lineFrame.size.height)))
                }
            }
            if !rects.isEmpty {
                result.append(rects)
            }
        }
        return result
    }
    
    public func attributeSubstring(name: String, index: Int) -> (String, String)? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedString.Key(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                return ((attributedString.string as NSString).substring(with: range), attributedString.string)
            }
        }
        return nil
    }
    
    public func allAttributeRects(name: String) -> [(Any, CGRect)] {
        guard let attributedString = self.attributedString else {
            return []
        }
        var result: [(Any, CGRect)] = []
        attributedString.enumerateAttribute(NSAttributedString.Key(rawValue: name), in: NSRange(location: 0, length: attributedString.length), options: []) { (value, range, _) in
            if let value = value, range.length != 0 {
                var coveringRect = CGRect()
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
                        switch self.resolvedAlignment {
                            case .center:
                                lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                            case .natural:
                                lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                            default:
                                break
                        }
                        
                        let rect = CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset) + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: abs(rightOffset - leftOffset), height: lineFrame.size.height))
                        if coveringRect.isEmpty {
                            coveringRect = rect
                        } else {
                            coveringRect = coveringRect.union(rect)
                        }
                    }
                }
                if !coveringRect.isEmpty {
                    result.append((value, coveringRect))
                }
            }
        }
        return result
    }
    
    public func lineAndAttributeRects(name: String, at index: Int) -> [(CGRect, CGRect)]? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedString.Key(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                var rects: [(CGRect, CGRect)] = []
                for line in self.lines {
                    let lineRange = NSIntersectionRange(range, line.range)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0.0
                        if lineRange.location != line.range.location || line.isRTL {
                            leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        var rightOffset: CGFloat = line.frame.width
                        if lineRange.location + lineRange.length != line.range.length || line.isRTL {
                            var secondaryOffset: CGFloat = 0.0
                            let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                            rightOffset = ceil(rawOffset)
                            if !rawOffset.isEqual(to: secondaryOffset) {
                                rightOffset = ceil(secondaryOffset)
                            }
                        }
                        var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                        
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                        
                        let width = abs(rightOffset - leftOffset)
                        if width > 1.0 {
                            rects.append((lineFrame, CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset) + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: width, height: lineFrame.size.height))))
                        }
                    }
                }
                if !rects.isEmpty {
                    return rects
                }
            }
        }
        return nil
    }
    
    public func rangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        guard let _ = self.attributedString, range.length != 0 else {
            return nil
        }
        var rects: [(CGRect, CGRect)] = []
        var startEdge: TextRangeRectEdge?
        var endEdge: TextRangeRectEdge?
        for line in self.lines {
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
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + self.firstLineOffset), size: line.frame.size)
                
                lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                
                let width = max(0.0, abs(rightOffset - leftOffset))
                
                if line.range.contains(range.lowerBound) {
                    let offsetX = floor(CTLineGetOffsetForStringIndex(line.line, range.lowerBound, nil))
                    startEdge = TextRangeRectEdge(x: lineFrame.minX + offsetX, y: lineFrame.minY, height: lineFrame.height)
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
                    endEdge = TextRangeRectEdge(x: lineFrame.minX + offsetX, y: lineFrame.minY, height: lineFrame.height)
                }
                
                rects.append((lineFrame, CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset) + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: width, height: lineFrame.size.height))))
            }
        }
        if !rects.isEmpty, let startEdge = startEdge, let endEdge = endEdge {
            return (rects.map { $1 }, startEdge, endEdge)
        }
        return nil
    }
}

private final class TextAccessibilityOverlayElement: UIAccessibilityElement {
    private let url: String
    private let openUrl: (String) -> Void
    
    init(accessibilityContainer: Any, url: String, openUrl: @escaping (String) -> Void) {
        self.url = url
        self.openUrl = openUrl
        
        super.init(accessibilityContainer: accessibilityContainer)
    }
    
    override func accessibilityActivate() -> Bool {
        self.openUrl(self.url)
        return true
    }
}

private final class TextAccessibilityOverlayNodeView: UIView {
    fileprivate var cachedLayout: TextNodeLayout? {
        didSet {
            self.currentAccessibilityNodes?.forEach({ $0.removeFromSupernode() })
            self.currentAccessibilityNodes = nil
        }
    }
    fileprivate let openUrl: (String) -> Void
    
    private var currentAccessibilityNodes: [AccessibilityAreaNode]?
    
    override var accessibilityElements: [Any]? {
        get {
            if let _ = self.currentAccessibilityNodes {
                return nil
            }
            guard let cachedLayout = self.cachedLayout else {
                return nil
            }
            let urlAttributesAndRects = cachedLayout.allAttributeRects(name: "UrlAttributeT")
            
            var urlElements: [AccessibilityAreaNode] = []
            for (value, rect) in urlAttributesAndRects {
                let element = AccessibilityAreaNode()
                element.accessibilityLabel = value as? String ?? ""
                element.frame = rect
                element.accessibilityTraits = .link
                element.activate = { [weak self] in
                    self?.openUrl(value as? String ?? "")
                    return true
                }
                self.addSubnode(element)
                urlElements.append(element)
            }
            self.currentAccessibilityNodes = urlElements
            return nil
        } set(value) {
        }
    }
    
    init(openUrl: @escaping (String) -> Void) {
        self.openUrl = openUrl
        
        super.init(frame: CGRect())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public final class TextAccessibilityOverlayNode: ASDisplayNode {
    public var cachedLayout: TextNodeLayout? {
        didSet {
            if self.isNodeLoaded {
                (self.view as? TextAccessibilityOverlayNodeView)?.cachedLayout = self.cachedLayout
            }
        }
    }
    
    public var openUrl: ((String) -> Void)?
    
    override public init() {
        super.init()
        
        self.isOpaque = false
        self.backgroundColor = nil
        
        let openUrl: (String) -> Void = { [weak self] url in
            self?.openUrl?(url)
        }
        
        self.isAccessibilityElement = false
        
        self.setViewBlock({
            return TextAccessibilityOverlayNodeView(openUrl: openUrl)
        })
    }
    
    override public func didLoad() {
        super.didLoad()
        
        (self.view as? TextAccessibilityOverlayNodeView)?.cachedLayout = self.cachedLayout
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

public class TextNode: ASDisplayNode {
    public internal(set) var cachedLayout: TextNodeLayout?
    
    override public init() {
        super.init()
        
        self.backgroundColor = UIColor.clear
        self.isOpaque = false
        self.clipsToBounds = false
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    public func attributesAtPoint(_ point: CGPoint, orNearest: Bool = false) -> (Int, [NSAttributedString.Key: Any])? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.attributesAtPoint(point, orNearest: orNearest)
        } else {
            return nil
        }
    }
    
    public func textRangesRects(text: String) -> [[CGRect]] {
        return self.cachedLayout?.textRangesRects(text: text) ?? []
    }
    
    public func attributeSubstring(name: String, index: Int) -> (String, String)? {
        return self.cachedLayout?.attributeSubstring(name: name, index: index)
    }
    
    public func attributeRects(name: String, at index: Int) -> [CGRect]? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.lineAndAttributeRects(name: name, at: index)?.map { $0.1 }
        } else {
            return nil
        }
    }
    
    public func rangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.rangeRects(in: range)
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
    
    static func calculateLayout(attributedString: NSAttributedString?, minimumNumberOfLines: Int, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacingFactor: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, lineColor: UIColor?, textShadowColor: UIColor?, textStroke: (UIColor, CGFloat)?, displaySpoilers: Bool) -> TextNodeLayout {
        if let attributedString = attributedString {
            let stringLength = attributedString.length
            
            let font: CTFont
            let resolvedAlignment: NSTextAlignment
            
            if stringLength != 0 {
                if let stringFont = attributedString.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) {
                    font = stringFont as! CTFont
                } else {
                    font = defaultFont
                }
                if alignment == .center {
                    resolvedAlignment = .center
                } else {
                    if let paragraphStyle = attributedString.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                        resolvedAlignment = paragraphStyle.alignment
                    } else {
                        resolvedAlignment = alignment
                    }
                }
            } else {
                font = defaultFont
                resolvedAlignment = alignment
            }
            
            let fontAscent = CTFontGetAscent(font)
            let fontDescent = CTFontGetDescent(font)
            let fontLineHeight = floor(fontAscent + fontDescent)
            let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
            
            var lines: [TextNodeLine] = []
            var blockQuotes: [TextNodeBlockQuote] = []
            
            var maybeTypesetter: CTTypesetter?
            maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
            if maybeTypesetter == nil {
                return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: resolvedAlignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, lines: [], blockQuotes: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textStroke: textStroke, displaySpoilers: displaySpoilers)
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
            
            var truncated = false
            var first = true
            while true {
                var strikethroughs: [TextNodeStrikethrough] = []
                var spoilers: [TextNodeSpoiler] = []
                var spoilerWords: [TextNodeSpoiler] = []
                var embeddedItems: [TextNodeEmbeddedItem] = []
                
                var lineConstrainedWidth = constrainedSize.width
                var lineConstrainedWidthDelta: CGFloat = 0.0
                var lineOriginY = floorToScreenPixels(layoutSize.height + fontAscent)
                if !first {
                    lineOriginY += fontLineSpacing
                }
                var lineCutoutOffset: CGFloat = 0.0
                var lineAdditionalWidth: CGFloat = 0.0
                
                if cutoutEnabled {
                    if lineOriginY - fontLineHeight < cutoutMaxY && lineOriginY + fontLineHeight > cutoutMinY {
                        lineConstrainedWidth = max(1.0, lineConstrainedWidth - cutoutWidth)
                        lineConstrainedWidthDelta = -cutoutWidth
                        lineCutoutOffset = cutoutOffset
                        lineAdditionalWidth = cutoutWidth
                    }
                }
                
                let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastLineCharacterIndex, Double(lineConstrainedWidth))
                
                func addSpoiler(line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int) {
                    var secondaryLeftOffset: CGFloat = 0.0
                    let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                    var leftOffset = floor(rawLeftOffset)
                    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                        leftOffset = floor(secondaryLeftOffset)
                    }
                    
                    var secondaryRightOffset: CGFloat = 0.0
                    let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                    var rightOffset = ceil(rawRightOffset)
                    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                        rightOffset = ceil(secondaryRightOffset)
                    }
                    
                    spoilers.append(TextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset), height: ascent + descent)))
                }
                
                func addSpoilerWord(line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
                    var secondaryLeftOffset: CGFloat = 0.0
                    let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                    var leftOffset = floor(rawLeftOffset)
                    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                        leftOffset = floor(secondaryLeftOffset)
                    }
                    
                    var secondaryRightOffset: CGFloat = 0.0
                    let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                    var rightOffset = ceil(rawRightOffset)
                    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                        rightOffset = ceil(secondaryRightOffset)
                    }
                    
                    spoilerWords.append(TextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent)))
                }
                
                func addEmbeddedItem(item: AnyHashable, line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
                    var secondaryLeftOffset: CGFloat = 0.0
                    let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                    var leftOffset = floor(rawLeftOffset)
                    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                        leftOffset = floor(secondaryLeftOffset)
                    }
                    
                    var secondaryRightOffset: CGFloat = 0.0
                    let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                    var rightOffset = ceil(rawRightOffset)
                    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                        rightOffset = ceil(secondaryRightOffset)
                    }
                    
                    embeddedItems.append(TextNodeEmbeddedItem(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent), item: item))
                }
                
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
                    var brokenLineRange = CFRange(location: lastLineCharacterIndex, length: lineCharacterCount)
                    if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                        brokenLineRange.length = attributedString.length - brokenLineRange.location
                    }
                    if lineRange.length == 0 {
                        break
                    }
                    
                    let coreTextLine: CTLine
                    let originalLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 0.0)
                    
                    var lineConstrainedSize = constrainedSize
                    lineConstrainedSize.width += lineConstrainedWidthDelta
                    if bottomCutoutEnabled {
                        lineConstrainedSize.width -= bottomCutoutSize.width
                    }
                    
                    if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(lineConstrainedSize.width) {
                        coreTextLine = originalLine
                    } else {
                        var truncationTokenAttributes: [NSAttributedString.Key : AnyObject] = [:]
                        truncationTokenAttributes[NSAttributedString.Key.font] = font
                        truncationTokenAttributes[NSAttributedString.Key(rawValue:  kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                        let tokenString = "\u{2026}"
                        let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                        let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                       
                        coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(lineConstrainedSize.width), truncationType, truncationToken) ?? truncationToken
                        let runs = (CTLineGetGlyphRuns(coreTextLine) as [AnyObject]) as! [CTRun]
                        for run in runs {
                            let runAttributes: NSDictionary = CTRunGetAttributes(run)
                            if let _ = runAttributes["CTForegroundColorFromContext"] {
                                brokenLineRange.length = CTRunGetStringRange(run).location
                                break
                            }
                        }
                        if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                            brokenLineRange.length = attributedString.length - brokenLineRange.location
                        }
                        truncated = true
                    }
                    
                    var headIndent: CGFloat = 0.0
                    if brokenLineRange.location >= 0 && brokenLineRange.length > 0 && brokenLineRange.location + brokenLineRange.length <= attributedString.length {
                        attributedString.enumerateAttributes(in: NSMakeRange(brokenLineRange.location, brokenLineRange.length), options: []) { attributes, range, _ in
                            if attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                
                                var startIndex: Int?
                                var currentIndex: Int?
                                
                                let nsString = (attributedString.string as NSString)
                                nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                                    if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                                        if let currentStartIndex = startIndex {
                                            startIndex = nil
                                            let endIndex = range.location
                                            addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                        }
                                    } else if startIndex == nil {
                                        startIndex = range.location
                                    }
                                    currentIndex = range.location + range.length
                                }
                                
                                if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                                    startIndex = nil
                                    let endIndex = currentIndex
                                    addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex, rightInset: truncated ? 12.0 : 0.0)
                                }
                                
                                addSpoiler(line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            } else if let embeddedItem = (attributes[NSAttributedString.Key(rawValue: "TelegramEmbeddedItem")] as? AnyHashable ?? attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable) {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                
                                addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            } else if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                                let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                                let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                                let x = lowerX < upperX ? lowerX : upperX
                                strikethroughs.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                            } else if let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle {
                                headIndent = paragraphStyle.headIndent
                            }
                        }
                    }
                    
                    let lineWidth = min(lineConstrainedSize.width, ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine))))
                    let lineFrame = CGRect(x: lineCutoutOffset + headIndent, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight + fontLineSpacing
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    if headIndent > 0.0 {
                        blockQuotes.append(TextNodeBlockQuote(frame: lineFrame))
                    }
                    
                    var isRTL = false
                    let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                    if glyphRuns.count != 0 {
                        let run = glyphRuns[0] as! CTRun
                        if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                        }
                    }
                    
                    lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), isRTL: isRTL, strikethroughs: strikethroughs, spoilers: spoilers, spoilerWords: spoilerWords, embeddedItems: embeddedItems))
                    break
                } else {
                    if lineCharacterCount > 0 {
                        if first {
                            first = false
                        } else {
                            layoutSize.height += fontLineSpacing
                        }
                        
                        var lineRange = CFRangeMake(lastLineCharacterIndex, lineCharacterCount)
                        if lineRange.location + lineRange.length > attributedString.length {
                            lineRange.length = attributedString.length - lineRange.location
                        }
                        if lineRange.length < 0 {
                            break
                        }

                        let coreTextLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 100.0)
                        lastLineCharacterIndex += lineCharacterCount
                        
                        var headIndent: CGFloat = 0.0
                        attributedString.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                            if attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                                                
                                var startIndex: Int?
                                var currentIndex: Int?
                                
                                let nsString = (attributedString.string as NSString)
                                nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                                    if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                                        if let currentStartIndex = startIndex {
                                            startIndex = nil
                                            let endIndex = range.location
                                            addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                        }
                                    } else if startIndex == nil {
                                        startIndex = range.location
                                    }
                                    currentIndex = range.location + range.length
                                }
                                
                                if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                                    startIndex = nil
                                    let endIndex = currentIndex
                                    addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                }
                                
                                addSpoiler(line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            } else if let embeddedItem = (attributes[NSAttributedString.Key(rawValue: "TelegramEmbeddedItem")] as? AnyHashable ?? attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable) {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                
                                addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            } else if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                                let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                                let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                                let x = lowerX < upperX ? lowerX : upperX
                                strikethroughs.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                            } else if let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle {
                                headIndent = paragraphStyle.headIndent
                            }
                        }
                        
                        let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                        let lineFrame = CGRect(x: lineCutoutOffset + headIndent, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                        layoutSize.height += fontLineHeight
                        layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                        
                        if headIndent > 0.0 {
                            blockQuotes.append(TextNodeBlockQuote(frame: lineFrame))
                        }
                        
                        var isRTL = false
                        let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                        if glyphRuns.count != 0 {
                            let run = glyphRuns[0] as! CTRun
                            if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                                isRTL = true
                            }
                        }
                        
                        lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), isRTL: isRTL, strikethroughs: strikethroughs, spoilers: spoilers, spoilerWords: spoilerWords, embeddedItems: embeddedItems))
                    } else {
                        if !lines.isEmpty {
                            layoutSize.height += fontLineSpacing
                        }
                        break
                    }
                }
            }
            
            let rawLayoutSize = layoutSize
            if !lines.isEmpty && bottomCutoutEnabled {
                let proposedWidth = lines[lines.count - 1].frame.width + bottomCutoutSize.width
                if proposedWidth > layoutSize.width {
                    if proposedWidth <= constrainedSize.width + .ulpOfOne {
                        layoutSize.width = proposedWidth
                    } else {
                        layoutSize.height += bottomCutoutSize.height
                    }
                }
            }
            
            if lines.count < minimumNumberOfLines {
                var lineCount = lines.count
                while lineCount < minimumNumberOfLines {
                    if lineCount != 0 {
                        layoutSize.height += fontLineSpacing
                    }
                    layoutSize.height += fontLineHeight
                    lineCount += 1
                }
            }
            
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: resolvedAlignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(width: ceil(layoutSize.width) + insets.left + insets.right, height: ceil(layoutSize.height) + insets.top + insets.bottom), rawTextSize: CGSize(width: ceil(rawLayoutSize.width) + insets.left + insets.right, height: ceil(rawLayoutSize.height) + insets.top + insets.bottom), truncated: truncated, firstLineOffset: firstLineOffset, lines: lines, blockQuotes: blockQuotes, backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textStroke: textStroke, displaySpoilers: displaySpoilers)
        } else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: alignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, lines: [], blockQuotes: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textStroke: textStroke, displaySpoilers: displaySpoilers)
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
        
        var clearRects: [CGRect] = []
        if let layout = parameters as? TextNodeLayout {
            if !isRasterizing || layout.backgroundColor != nil {
                context.setBlendMode(.copy)
                context.setFillColor((layout.backgroundColor ?? UIColor.clear).cgColor)
                context.fill(bounds)
            }
            
            if let textShadowColor = layout.textShadowColor {
                context.setTextDrawingMode(.fill)
                context.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: 0.0, color: textShadowColor.cgColor)
            }
            
            if let (textStrokeColor, textStrokeWidth) = layout.textStroke {
                context.setBlendMode(.normal)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setStrokeColor(textStrokeColor.cgColor)
                context.setFillColor(textStrokeColor.cgColor)
                context.setLineWidth(textStrokeWidth)
                context.setTextDrawingMode(.fillStroke)
            }
            
            let textMatrix = context.textMatrix
            let textPosition = context.textPosition
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            let alignment = layout.resolvedAlignment
            var offset = CGPoint(x: layout.insets.left, y: layout.insets.top)
            switch layout.verticalAlignment {
                case .top:
                    break
                case .middle:
                    offset.y = floor((bounds.height - layout.size.height) / 2.0) + layout.insets.top
                case .bottom:
                    offset.y = floor(bounds.height - layout.size.height) + layout.insets.top
            }
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                
                var lineFrame = line.frame
                lineFrame.origin.y += offset.y
                
                if alignment == .center {
                    lineFrame.origin.x = offset.x + floor((bounds.size.width - lineFrame.width) / 2.0)
                } else if alignment == .natural {
                    if line.isRTL {
                        lineFrame.origin.x = offset.x + floor(bounds.size.width - lineFrame.width)
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: bounds.size), cutout: layout.cutout)
                    } else {
                        lineFrame.origin.x += offset.x
                    }
                }
                context.textPosition = CGPoint(x: lineFrame.minX, y: lineFrame.minY)
                
                if layout.displaySpoilers && !line.spoilers.isEmpty {
                    context.saveGState()
                    var clipRects: [CGRect] = []
                    for spoiler in line.spoilerWords {
                        var spoilerClipRect = spoiler.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY - UIScreenPixel)
                        spoilerClipRect.size.height += 1.0 + UIScreenPixel
                        clipRects.append(spoilerClipRect)
                    }
                    context.clip(to: clipRects)
                }
                    
                let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                if glyphRuns.count != 0 {
                    for run in glyphRuns {
                        let run = run as! CTRun
                        let glyphCount = CTRunGetGlyphCount(run)
                        CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                    }
                }
                
                if !line.strikethroughs.isEmpty {
                    for strikethrough in line.strikethroughs {
                        var textColor: UIColor?
                        layout.attributedString?.enumerateAttributes(in: NSMakeRange(line.range.location, line.range.length), options: []) { attributes, range, _ in
                            if range == strikethrough.range, let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                textColor = color
                            }
                        }
                        if let textColor = textColor {
                            context.setFillColor(textColor.cgColor)
                        }
                        let frame = strikethrough.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                        context.fill(CGRect(x: frame.minX, y: frame.minY - 5.0, width: frame.width, height: 1.0))
                    }
                }
                
                if !line.spoilers.isEmpty {
                    if layout.displaySpoilers {
                        context.restoreGState()
                    } else {
                        for spoiler in line.spoilerWords {
                            var spoilerClearRect = spoiler.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY - UIScreenPixel)
                            spoilerClearRect.size.height += 1.0 + UIScreenPixel
                            clearRects.append(spoilerClearRect)
                        }
                    }
                }
            }
            
            var blockQuoteFrames: [CGRect] = []
            var currentBlockQuoteFrame: CGRect?
            for blockQuote in layout.blockQuotes {
                if let frame = currentBlockQuoteFrame {
                    if blockQuote.frame.minY - frame.maxY < 20.0 {
                        currentBlockQuoteFrame = frame.union(blockQuote.frame)
                    } else {
                        blockQuoteFrames.append(frame)
                        currentBlockQuoteFrame = frame
                    }
                } else {
                    currentBlockQuoteFrame = blockQuote.frame
                }
            }
            
            if let frame = currentBlockQuoteFrame {
                blockQuoteFrames.append(frame)
            }
            
            for frame in blockQuoteFrames {
                if let lineColor = layout.lineColor {
                    context.setFillColor(lineColor.cgColor)
                }
                let rect = UIBezierPath(roundedRect: CGRect(x: frame.minX - 9.0, y: frame.minY - 14.0, width: 2.0, height: frame.height), cornerRadius: 1.0)
                context.addPath(rect.cgPath)
                context.fillPath()
            }
            
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        
        context.setBlendMode(.normal)
        
        for rect in clearRects {
            context.clear(rect)
        }
    }
    
    public static func asyncLayout(_ maybeNode: TextNode?) -> (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode) {
        let existingLayout: TextNodeLayout? = maybeNode?.cachedLayout
        
        return { arguments in
            let layout: TextNodeLayout
            
            var updated = false
            if let existingLayout = existingLayout, existingLayout.constrainedSize == arguments.constrainedSize && existingLayout.maximumNumberOfLines == arguments.maximumNumberOfLines && existingLayout.truncationType == arguments.truncationType && existingLayout.cutout == arguments.cutout && existingLayout.explicitAlignment == arguments.alignment && existingLayout.lineSpacing.isEqual(to: arguments.lineSpacing) {
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
                    layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers)
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

open class TextView: UIView {
    public internal(set) var cachedLayout: TextNodeLayout?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.clear
        self.isOpaque = false
        self.clipsToBounds = false
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func attributesAtPoint(_ point: CGPoint, orNearest: Bool = false) -> (Int, [NSAttributedString.Key: Any])? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.attributesAtPoint(point, orNearest: orNearest)
        } else {
            return nil
        }
    }
    
    public func textRangesRects(text: String) -> [[CGRect]] {
        return self.cachedLayout?.textRangesRects(text: text) ?? []
    }
    
    public func attributeSubstring(name: String, index: Int) -> (String, String)? {
        return self.cachedLayout?.attributeSubstring(name: name, index: index)
    }
    
    public func attributeRects(name: String, at index: Int) -> [CGRect]? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.lineAndAttributeRects(name: name, at: index)?.map { $0.1 }
        } else {
            return nil
        }
    }
    
    public func rangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        if let cachedLayout = self.cachedLayout {
            return cachedLayout.rangeRects(in: range)
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
    
    private class func calculateLayout(attributedString: NSAttributedString?, minimumNumberOfLines: Int, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacingFactor: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, lineColor: UIColor?, textShadowColor: UIColor?, textStroke: (UIColor, CGFloat)?, displaySpoilers: Bool) -> TextNodeLayout {
        if let attributedString = attributedString {
            let stringLength = attributedString.length
            
            let font: CTFont
            let resolvedAlignment: NSTextAlignment
            
            if stringLength != 0 {
                if let stringFont = attributedString.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) {
                    font = stringFont as! CTFont
                } else {
                    font = defaultFont
                }
                if alignment == .center {
                    resolvedAlignment = .center
                } else {
                    if let paragraphStyle = attributedString.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                        resolvedAlignment = paragraphStyle.alignment
                    } else {
                        resolvedAlignment = alignment
                    }
                }
            } else {
                font = defaultFont
                resolvedAlignment = alignment
            }
            
            let fontAscent = CTFontGetAscent(font)
            let fontDescent = CTFontGetDescent(font)
            let fontLineHeight = floor(fontAscent + fontDescent)
            let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
            
            var lines: [TextNodeLine] = []
            var blockQuotes: [TextNodeBlockQuote] = []
            
            var maybeTypesetter: CTTypesetter?
            maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
            if maybeTypesetter == nil {
                return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: resolvedAlignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, lines: [], blockQuotes: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textStroke: textStroke, displaySpoilers: displaySpoilers)
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
            
            var truncated = false
            var first = true
            while true {
                var strikethroughs: [TextNodeStrikethrough] = []
                var spoilers: [TextNodeSpoiler] = []
                var spoilerWords: [TextNodeSpoiler] = []
                
                var lineConstrainedWidth = constrainedSize.width
                var lineConstrainedWidthDelta: CGFloat = 0.0
                var lineOriginY = floorToScreenPixels(layoutSize.height + fontAscent)
                if !first {
                    lineOriginY += fontLineSpacing
                }
                var lineCutoutOffset: CGFloat = 0.0
                var lineAdditionalWidth: CGFloat = 0.0
                
                if cutoutEnabled {
                    if lineOriginY - fontLineHeight < cutoutMaxY && lineOriginY + fontLineHeight > cutoutMinY {
                        lineConstrainedWidth = max(1.0, lineConstrainedWidth - cutoutWidth)
                        lineConstrainedWidthDelta = -cutoutWidth
                        lineCutoutOffset = cutoutOffset
                        lineAdditionalWidth = cutoutWidth
                    }
                }
                
                let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastLineCharacterIndex, Double(lineConstrainedWidth))
                
                func addSpoiler(line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int) {
                    var secondaryLeftOffset: CGFloat = 0.0
                    let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                    var leftOffset = floor(rawLeftOffset)
                    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                        leftOffset = floor(secondaryLeftOffset)
                    }
                    
                    var secondaryRightOffset: CGFloat = 0.0
                    let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                    var rightOffset = ceil(rawRightOffset)
                    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                        rightOffset = ceil(secondaryRightOffset)
                    }
                    
                    spoilers.append(TextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset), height: ascent + descent)))
                }
                
                func addSpoilerWord(line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
                    var secondaryLeftOffset: CGFloat = 0.0
                    let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                    var leftOffset = floor(rawLeftOffset)
                    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                        leftOffset = floor(secondaryLeftOffset)
                    }
                    
                    var secondaryRightOffset: CGFloat = 0.0
                    let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                    var rightOffset = ceil(rawRightOffset)
                    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                        rightOffset = ceil(secondaryRightOffset)
                    }
                    
                    spoilerWords.append(TextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent)))
                }
                
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
                    var brokenLineRange = CFRange(location: lastLineCharacterIndex, length: lineCharacterCount)
                    if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                        brokenLineRange.length = attributedString.length - brokenLineRange.location
                    }
                    if lineRange.length == 0 {
                        break
                    }
                    
                    let coreTextLine: CTLine
                    let originalLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 0.0)
                    
                    var lineConstrainedSize = constrainedSize
                    lineConstrainedSize.width += lineConstrainedWidthDelta
                    if bottomCutoutEnabled {
                        lineConstrainedSize.width -= bottomCutoutSize.width
                    }
                    
                    if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(lineConstrainedSize.width) {
                        coreTextLine = originalLine
                    } else {
                        var truncationTokenAttributes: [NSAttributedString.Key : AnyObject] = [:]
                        truncationTokenAttributes[NSAttributedString.Key.font] = font
                        truncationTokenAttributes[NSAttributedString.Key(rawValue:  kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                        let tokenString = "\u{2026}"
                        let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                        let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                       
                        coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(lineConstrainedSize.width), truncationType, truncationToken) ?? truncationToken
                        let runs = (CTLineGetGlyphRuns(coreTextLine) as [AnyObject]) as! [CTRun]
                        for run in runs {
                            let runAttributes: NSDictionary = CTRunGetAttributes(run)
                            if let _ = runAttributes["CTForegroundColorFromContext"] {
                                brokenLineRange.length = CTRunGetStringRange(run).location
                                break
                            }
                        }
                        if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                            brokenLineRange.length = attributedString.length - brokenLineRange.location
                        }
                        truncated = true
                    }
                    
                    var headIndent: CGFloat = 0.0
                    if brokenLineRange.location >= 0 && brokenLineRange.length > 0 && brokenLineRange.location + brokenLineRange.length <= attributedString.length {
                        attributedString.enumerateAttributes(in: NSMakeRange(brokenLineRange.location, brokenLineRange.length), options: []) { attributes, range, _ in
                            if attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                
                                var startIndex: Int?
                                var currentIndex: Int?
                                
                                let nsString = (attributedString.string as NSString)
                                nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                                    if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                                        if let currentStartIndex = startIndex {
                                            startIndex = nil
                                            let endIndex = range.location
                                            addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                        }
                                    } else if startIndex == nil {
                                        startIndex = range.location
                                    }
                                    currentIndex = range.location + range.length
                                }
                                
                                if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                                    startIndex = nil
                                    let endIndex = currentIndex
                                    addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex, rightInset: truncated ? 12.0 : 0.0)
                                }
                                
                                addSpoiler(line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            } else if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                                let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                                let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                                let x = lowerX < upperX ? lowerX : upperX
                                strikethroughs.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                            } else if let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle {
                                headIndent = paragraphStyle.headIndent
                                
                            }
                        }
                    }
                    
                    let lineWidth = min(lineConstrainedSize.width, ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine))))
                    let lineFrame = CGRect(x: lineCutoutOffset + headIndent, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight + fontLineSpacing
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    if headIndent > 0.0 {
                        blockQuotes.append(TextNodeBlockQuote(frame: lineFrame))
                    }
                    
                    var isRTL = false
                    let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                    if glyphRuns.count != 0 {
                        let run = glyphRuns[0] as! CTRun
                        if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                        }
                    }
                    
                    lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), isRTL: isRTL, strikethroughs: strikethroughs, spoilers: spoilers, spoilerWords: spoilerWords, embeddedItems: []))
                    break
                } else {
                    if lineCharacterCount > 0 {
                        if first {
                            first = false
                        } else {
                            layoutSize.height += fontLineSpacing
                        }
                        
                        var lineRange = CFRangeMake(lastLineCharacterIndex, lineCharacterCount)
                        if lineRange.location + lineRange.length > attributedString.length {
                            lineRange.length = attributedString.length - lineRange.location
                        }
                        if lineRange.length < 0 {
                            break
                        }

                        let coreTextLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 100.0)
                        lastLineCharacterIndex += lineCharacterCount
                        
                        var headIndent: CGFloat = 0.0
                        attributedString.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                            if attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                                                
                                var startIndex: Int?
                                var currentIndex: Int?
                                
                                let nsString = (attributedString.string as NSString)
                                nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                                    if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                                        if let currentStartIndex = startIndex {
                                            startIndex = nil
                                            let endIndex = range.location
                                            addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                        }
                                    } else if startIndex == nil {
                                        startIndex = range.location
                                    }
                                    currentIndex = range.location + range.length
                                }
                                
                                if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                                    startIndex = nil
                                    let endIndex = currentIndex
                                    addSpoilerWord(line: coreTextLine, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                }
                                
                                addSpoiler(line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            } else if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                                let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                                let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                                let x = lowerX < upperX ? lowerX : upperX
                                strikethroughs.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                            } else if let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle {
                                headIndent = paragraphStyle.headIndent
                            }
                        }
                        
                        let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                        let lineFrame = CGRect(x: lineCutoutOffset + headIndent, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                        layoutSize.height += fontLineHeight
                        layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                        
                        if headIndent > 0.0 {
                            blockQuotes.append(TextNodeBlockQuote(frame: lineFrame))
                        }
                        
                        var isRTL = false
                        let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                        if glyphRuns.count != 0 {
                            let run = glyphRuns[0] as! CTRun
                            if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                                isRTL = true
                            }
                        }
                        
                        lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), isRTL: isRTL, strikethroughs: strikethroughs, spoilers: spoilers, spoilerWords: spoilerWords, embeddedItems: []))
                    } else {
                        if !lines.isEmpty {
                            layoutSize.height += fontLineSpacing
                        }
                        break
                    }
                }
            }
            
            let rawLayoutSize = layoutSize
            if !lines.isEmpty && bottomCutoutEnabled {
                let proposedWidth = lines[lines.count - 1].frame.width + bottomCutoutSize.width
                if proposedWidth > layoutSize.width {
                    if proposedWidth <= constrainedSize.width + .ulpOfOne {
                        layoutSize.width = proposedWidth
                    } else {
                        layoutSize.height += bottomCutoutSize.height
                    }
                }
            }
            
            if lines.count < minimumNumberOfLines {
                var lineCount = lines.count
                while lineCount < minimumNumberOfLines {
                    if lineCount != 0 {
                        layoutSize.height += fontLineSpacing
                    }
                    layoutSize.height += fontLineHeight
                    lineCount += 1
                }
            }
            
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: resolvedAlignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(width: ceil(layoutSize.width) + insets.left + insets.right, height: ceil(layoutSize.height) + insets.top + insets.bottom), rawTextSize: CGSize(width: ceil(rawLayoutSize.width) + insets.left + insets.right, height: ceil(rawLayoutSize.height) + insets.top + insets.bottom), truncated: truncated, firstLineOffset: firstLineOffset, lines: lines, blockQuotes: blockQuotes, backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textStroke: textStroke, displaySpoilers: displaySpoilers)
        } else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: alignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, lines: [], blockQuotes: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textStroke: textStroke, displaySpoilers: displaySpoilers)
        }
    }
    
    public override func draw(_ rect: CGRect) {
        let bounds = self.bounds
        let layout = self.cachedLayout
        
        let context = UIGraphicsGetCurrentContext()!
        
        context.setAllowsAntialiasing(true)
        
        context.setAllowsFontSmoothing(false)
        context.setShouldSmoothFonts(false)
        
        context.setAllowsFontSubpixelPositioning(false)
        context.setShouldSubpixelPositionFonts(false)
        
        context.setAllowsFontSubpixelQuantization(true)
        context.setShouldSubpixelQuantizeFonts(true)
        
        var clearRects: [CGRect] = []
        if let layout = layout {
            if layout.backgroundColor != nil {
                context.setBlendMode(.copy)
                context.setFillColor((layout.backgroundColor ?? UIColor.clear).cgColor)
                context.fill(bounds)
            }
            
            if let textShadowColor = layout.textShadowColor {
                context.setTextDrawingMode(.fill)
                context.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: 0.0, color: textShadowColor.cgColor)
            }
            
            if let (textStrokeColor, textStrokeWidth) = layout.textStroke {
                context.setBlendMode(.normal)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setStrokeColor(textStrokeColor.cgColor)
                context.setFillColor(textStrokeColor.cgColor)
                context.setLineWidth(textStrokeWidth)
                context.setTextDrawingMode(.fillStroke)
            }
            
            let textMatrix = context.textMatrix
            let textPosition = context.textPosition
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            let alignment = layout.resolvedAlignment
            var offset = CGPoint(x: layout.insets.left, y: layout.insets.top)
            switch layout.verticalAlignment {
                case .top:
                    break
                case .middle:
                    offset.y = floor((bounds.height - layout.size.height) / 2.0) + layout.insets.top
                case .bottom:
                    offset.y = floor(bounds.height - layout.size.height) + layout.insets.top
            }
            
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
                
                if layout.displaySpoilers && !line.spoilers.isEmpty {
                    context.saveGState()
                    var clipRects: [CGRect] = []
                    for spoiler in line.spoilerWords {
                        var spoilerClipRect = spoiler.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY - UIScreenPixel)
                        spoilerClipRect.size.height += 1.0 + UIScreenPixel
                        clipRects.append(spoilerClipRect)
                    }
                    context.clip(to: clipRects)
                }
                    
                let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                if glyphRuns.count != 0 {
                    for run in glyphRuns {
                        let run = run as! CTRun
                        let glyphCount = CTRunGetGlyphCount(run)
                        CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                    }
                }
                
                if !line.strikethroughs.isEmpty {
                    for strikethrough in line.strikethroughs {
                        var textColor: UIColor?
                        layout.attributedString?.enumerateAttributes(in: NSMakeRange(line.range.location, line.range.length), options: []) { attributes, range, _ in
                            if range == strikethrough.range, let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                textColor = color
                            }
                        }
                        if let textColor = textColor {
                            context.setFillColor(textColor.cgColor)
                        }
                        let frame = strikethrough.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                        context.fill(CGRect(x: frame.minX, y: frame.minY - 5.0, width: frame.width, height: 1.0))
                    }
                }
                
                if !line.spoilers.isEmpty {
                    if layout.displaySpoilers {
                        context.restoreGState()
                    } else {
                        for spoiler in line.spoilerWords {
                            var spoilerClearRect = spoiler.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY - UIScreenPixel)
                            spoilerClearRect.size.height += 1.0 + UIScreenPixel
                            clearRects.append(spoilerClearRect)
                        }
                    }
                }
            }
            
            var blockQuoteFrames: [CGRect] = []
            var currentBlockQuoteFrame: CGRect?
            for blockQuote in layout.blockQuotes {
                if let frame = currentBlockQuoteFrame {
                    if blockQuote.frame.minY - frame.maxY < 20.0 {
                        currentBlockQuoteFrame = frame.union(blockQuote.frame)
                    } else {
                        blockQuoteFrames.append(frame)
                        currentBlockQuoteFrame = frame
                    }
                } else {
                    currentBlockQuoteFrame = blockQuote.frame
                }
            }
            
            if let frame = currentBlockQuoteFrame {
                blockQuoteFrames.append(frame)
            }
            
            for frame in blockQuoteFrames {
                if let lineColor = layout.lineColor {
                    context.setFillColor(lineColor.cgColor)
                }
                let rect = UIBezierPath(roundedRect: CGRect(x: frame.minX - 9.0, y: frame.minY - 14.0, width: 2.0, height: frame.height), cornerRadius: 1.0)
                context.addPath(rect.cgPath)
                context.fillPath()
            }
            
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        
        context.setBlendMode(.normal)
        
        for rect in clearRects {
            context.clear(rect)
        }
    }
    
    public static func asyncLayout(_ maybeView: TextView?) -> (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextView) {
        let existingLayout: TextNodeLayout? = maybeView?.cachedLayout
        
        return { arguments in
            let layout: TextNodeLayout
            
            var updated = false
            if let existingLayout = existingLayout, existingLayout.constrainedSize == arguments.constrainedSize && existingLayout.maximumNumberOfLines == arguments.maximumNumberOfLines && existingLayout.truncationType == arguments.truncationType && existingLayout.cutout == arguments.cutout && existingLayout.explicitAlignment == arguments.alignment && existingLayout.lineSpacing.isEqual(to: arguments.lineSpacing) {
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
                    layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers)
                updated = true
            }
            
            let view = maybeView ?? TextView()
            
            return (layout, {
                view.cachedLayout = layout
                if updated {
                    if layout.size.width.isZero && layout.size.height.isZero {
                        view.layer.contents = nil
                    }
                    view.setNeedsDisplay()
                }
                
                return view
            })
        }
    }
}
