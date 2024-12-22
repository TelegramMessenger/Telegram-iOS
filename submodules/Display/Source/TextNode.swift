import Foundation
import UIKit
import AsyncDisplayKit
import CoreText
import AppBundle

private let defaultFont = UIFont.systemFont(ofSize: 15.0)

private let quoteIcon: UIImage = {
    return UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon")!.precomposed()
}()

private let codeIcon: UIImage = {
    return UIImage(bundleImageName: "Chat/Message/TextCodeIcon")!.precomposed()
}()

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

private final class TextNodeAttachment {
    let range: NSRange
    let frame: CGRect
    let attachment: UIImage
    
    init(range: NSRange, frame: CGRect, attachment: UIImage) {
        self.range = range
        self.frame = frame
        self.attachment = attachment
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

public final class TextNodeBlockQuoteData: NSObject {
    public enum Kind: Equatable {
        case quote
        case code(language: String?)
    }
    
    public let kind: Kind
    public let title: NSAttributedString?
    public let color: UIColor
    public let secondaryColor: UIColor?
    public let tertiaryColor: UIColor?
    public let backgroundColor: UIColor
    public let isCollapsible: Bool
    
    public init(kind: Kind, title: NSAttributedString?, color: UIColor, secondaryColor: UIColor?, tertiaryColor: UIColor?, backgroundColor: UIColor, isCollapsible: Bool) {
        self.kind = kind
        self.title = title
        self.color = color
        self.secondaryColor = secondaryColor
        self.tertiaryColor = tertiaryColor
        self.backgroundColor = backgroundColor
        self.isCollapsible = isCollapsible
        
        super.init()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TextNodeBlockQuoteData else {
            return false
        }
        
        if self.kind != other.kind {
            return false
        }
        if let lhsTitle = self.title, let rhsTitle = other.title {
            if !lhsTitle.isEqual(to: rhsTitle) {
                return false
            }
        } else if (self.title == nil) != (other.title == nil) {
            return false
        }
        if !self.color.isEqual(other.color) {
            return false
        }
        if let lhsSecondaryColor = self.secondaryColor, let rhsSecondaryColor = other.secondaryColor {
            if !lhsSecondaryColor.isEqual(rhsSecondaryColor) {
                return false
            }
        } else if (self.secondaryColor == nil) != (other.secondaryColor == nil) {
            return false
        }
        if let lhsTertiaryColor = self.tertiaryColor, let rhsTertiaryColor = other.tertiaryColor {
            if !lhsTertiaryColor.isEqual(rhsTertiaryColor) {
                return false
            }
        } else if (self.tertiaryColor == nil) != (other.tertiaryColor == nil) {
            return false
        }
        
        return true
    }
}

private final class TextNodeLine {
    let line: CTLine
    var frame: CGRect
    let ascent: CGFloat
    let descent: CGFloat
    let range: NSRange?
    let isRTL: Bool
    var strikethroughs: [TextNodeStrikethrough]
    var underlines: [TextNodeStrikethrough]
    var spoilers: [TextNodeSpoiler]
    var spoilerWords: [TextNodeSpoiler]
    var embeddedItems: [TextNodeEmbeddedItem]
    var attachments: [TextNodeAttachment]
    let additionalTrailingLine: (CTLine, Double)?
    
    init(line: CTLine, frame: CGRect, ascent: CGFloat, descent: CGFloat, range: NSRange?, isRTL: Bool, strikethroughs: [TextNodeStrikethrough], underlines: [TextNodeStrikethrough], spoilers: [TextNodeSpoiler], spoilerWords: [TextNodeSpoiler], embeddedItems: [TextNodeEmbeddedItem], attachments: [TextNodeAttachment], additionalTrailingLine: (CTLine, Double)?) {
        self.line = line
        self.frame = frame
        self.ascent = ascent
        self.descent = descent
        self.range = range
        self.isRTL = isRTL
        self.strikethroughs = strikethroughs
        self.underlines = underlines
        self.spoilers = spoilers
        self.spoilerWords = spoilerWords
        self.embeddedItems = embeddedItems
        self.attachments = attachments
        self.additionalTrailingLine = additionalTrailingLine
    }
}

private final class TextNodeBlockQuote {
    let frame: CGRect
    let data: TextNodeBlockQuoteData
    let tintColor: UIColor
    let secondaryTintColor: UIColor?
    let tertiaryTintColor: UIColor?
    let backgroundColor: UIColor
    
    init(frame: CGRect, data: TextNodeBlockQuoteData, tintColor: UIColor, secondaryTintColor: UIColor?, tertiaryTintColor: UIColor?, backgroundColor: UIColor) {
        self.frame = frame
        self.data = data
        self.tintColor = tintColor
        self.secondaryTintColor = secondaryTintColor
        self.tertiaryTintColor = tertiaryTintColor
        self.backgroundColor = backgroundColor
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

private let drawUnderlinesManually: Bool = {
    if #available(iOS 18.0, *) {
        return true
    } else {
        return false
    }
}()

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
    public let textShadowBlur: CGFloat?
    public let textStroke: (UIColor, CGFloat)?
    public let displaySpoilers: Bool
    public let displayEmbeddedItemsUnderSpoilers: Bool
    public let customTruncationToken: NSAttributedString?
    
    public init(
        attributedString: NSAttributedString?,
        backgroundColor: UIColor? = nil,
        minimumNumberOfLines: Int = 0,
        maximumNumberOfLines: Int,
        truncationType: CTLineTruncationType,
        constrainedSize: CGSize,
        alignment: NSTextAlignment = .natural,
        verticalAlignment: TextVerticalAlignment = .top,
        lineSpacing: CGFloat = 0.12,
        cutout: TextNodeCutout? = nil,
        insets: UIEdgeInsets = UIEdgeInsets(),
        lineColor: UIColor? = nil,
        textShadowColor: UIColor? = nil,
        textShadowBlur: CGFloat? = nil,
        textStroke: (UIColor, CGFloat)? = nil,
        displaySpoilers: Bool = false,
        displayEmbeddedItemsUnderSpoilers: Bool = false,
        customTruncationToken: NSAttributedString? = nil
    ) {
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
        self.textShadowBlur = textShadowBlur
        self.textStroke = textStroke
        self.displaySpoilers = displaySpoilers
        self.displayEmbeddedItemsUnderSpoilers = displayEmbeddedItemsUnderSpoilers
        self.customTruncationToken = customTruncationToken
    }
    
    public func withAttributedString(_ attributedString: NSAttributedString?) -> TextNodeLayoutArguments {
        return TextNodeLayoutArguments(
            attributedString: attributedString,
            backgroundColor: self.backgroundColor,
            minimumNumberOfLines: self.minimumNumberOfLines,
            maximumNumberOfLines: self.maximumNumberOfLines,
            truncationType: self.truncationType,
            constrainedSize: self.constrainedSize,
            alignment: self.alignment,
            verticalAlignment: self.verticalAlignment,
            lineSpacing: self.lineSpacing,
            cutout: self.cutout,
            insets: self.insets,
            lineColor: self.lineColor,
            textShadowColor: self.textShadowColor,
            textShadowBlur: self.textShadowBlur,
            textStroke: self.textStroke,
            displaySpoilers: self.displaySpoilers,
            displayEmbeddedItemsUnderSpoilers: self.displayEmbeddedItemsUnderSpoilers,
            customTruncationToken: self.customTruncationToken
        )
    }
}

public final class TextNodeLayout: NSObject {
    public final class EmbeddedItem: Equatable {
        public let range: NSRange
        public let rect: CGRect
        public let value: AnyHashable
        public let textColor: UIColor
        
        public init(range: NSRange, rect: CGRect, value: AnyHashable, textColor: UIColor) {
            self.range = range
            self.rect = rect
            self.value = value
            self.textColor = textColor
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
            if lhs.textColor != rhs.textColor {
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
    fileprivate let textShadowBlur: CGFloat?
    fileprivate let textStroke: (UIColor, CGFloat)?
    fileprivate let displaySpoilers: Bool
    public let hasRTL: Bool
    public let spoilers: [(NSRange, CGRect)]
    public let spoilerWords: [(NSRange, CGRect)]
    public let embeddedItems: [TextNodeLayout.EmbeddedItem]
    
    fileprivate init(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: CGSize, explicitAlignment: NSTextAlignment, resolvedAlignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacing: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, size: CGSize, rawTextSize: CGSize, truncated: Bool, firstLineOffset: CGFloat, lines: [TextNodeLine], blockQuotes: [TextNodeBlockQuote], backgroundColor: UIColor?, lineColor: UIColor?, textShadowColor: UIColor?, textShadowBlur: CGFloat?, textStroke: (UIColor, CGFloat)?, displaySpoilers: Bool) {
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
        self.textShadowBlur = textShadowBlur
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
            case .right:
                lineFrame = CGRect(origin: CGPoint(x: size.width - line.frame.size.width, y: line.frame.minY), size: line.frame.size)
            default:
                lineFrame = displayLineFrame(frame: line.frame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: size), cutout: cutout)
            }
            
            spoilers.append(contentsOf: line.spoilers.map { ( $0.range, $0.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)) })
            spoilerWords.append(contentsOf: line.spoilerWords.map { ( $0.range, $0.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)) })
            for embeddedItem in line.embeddedItems {
                var textColor: UIColor?
                if let attributedString = attributedString, embeddedItem.range.location < attributedString.length {
                    if let color = attributedString.attribute(.foregroundColor, at: embeddedItem.range.location, effectiveRange: nil) as? UIColor {
                        textColor = color
                    }
                    if textColor == nil {
                        if let color = attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor {
                            textColor = color
                        }
                    }
                }
                embeddedItems.append(TextNodeLayout.EmbeddedItem(range: embeddedItem.range, rect: embeddedItem.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY), value: embeddedItem.item, textColor: textColor ?? .black))
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
            var width = lastLine.frame.maxX
            
            for blockQuote in self.blockQuotes {
                if lastLine.frame.intersects(blockQuote.frame) {
                    width = max(width, ceil(blockQuote.frame.maxX) + 2.0)
                }
            }
            return width
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
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
                    switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    case .right:
                        lineFrame.origin.x = self.size.width - lineFrame.size.width
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
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
                switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    case .right:
                        lineFrame.origin.x = self.size.width - lineFrame.size.width
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
                        if let range = line.range, index < range.location + range.length {
                            return (index, attributedString.attributes(at: index, effectiveRange: nil))
                        }
                    }
                    break
                }
            }
            lineIndex = -1
            for line in self.lines {
                lineIndex += 1
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
                switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural:
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                    case .right:
                        lineFrame.origin.x = self.size.width - lineFrame.size.width
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
                        if let range = line.range, index < range.location + range.length {
                            return (index, attributedString.attributes(at: index, effectiveRange: nil))
                        }
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
                guard let rangeValue = line.range else {
                    continue
                }
                let lineRange = NSIntersectionRange(range, rangeValue)
                if lineRange.length != 0 {
                    var leftOffset: CGFloat = 0.0
                    if lineRange.location != rangeValue.location {
                        leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                    }
                    var rightOffset: CGFloat = line.frame.width
                    if lineRange.location + lineRange.length != rangeValue.length {
                        var secondaryOffset: CGFloat = 0.0
                        let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                        rightOffset = ceil(rawOffset)
                        if !rawOffset.isEqual(to: secondaryOffset) {
                            rightOffset = ceil(secondaryOffset)
                        }
                    }
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
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
    
    public func attributeSubstringWithRange(name: String, index: Int) -> (String, String, NSRange)? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedString.Key(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                return ((attributedString.string as NSString).substring(with: range), attributedString.string, range)
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
                    guard let rangeValue = line.range else {
                        continue
                    }
                    let lineRange = NSIntersectionRange(range, rangeValue)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0.0
                        if lineRange.location != rangeValue.location {
                            leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        var rightOffset: CGFloat = line.frame.width
                        if lineRange.location + lineRange.length != rangeValue.length {
                            var secondaryOffset: CGFloat = 0.0
                            let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                            rightOffset = ceil(rawOffset)
                            if !rawOffset.isEqual(to: secondaryOffset) {
                                rightOffset = ceil(secondaryOffset)
                            }
                        }
                        
                        var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
                        switch self.resolvedAlignment {
                            case .center:
                                lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                            case .natural:
                                lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                            case .right:
                                lineFrame.origin.x = self.size.width - lineFrame.size.width
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
                    guard let rangeValue = line.range else {
                        continue
                    }
                    let lineRange = NSIntersectionRange(range, rangeValue)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0.0
                        if lineRange.location != rangeValue.location || line.isRTL {
                            leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        var rightOffset: CGFloat = line.frame.width
                        if lineRange.location + lineRange.length != rangeValue.length || line.isRTL {
                            var secondaryOffset: CGFloat = 0.0
                            let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                            rightOffset = ceil(rawOffset)
                            if !rawOffset.isEqual(to: secondaryOffset) {
                                rightOffset = ceil(secondaryOffset)
                            }
                        }
                        var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
                        
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
            guard let rangeValue = line.range else {
                continue
            }
            let lineRange = NSIntersectionRange(range, rangeValue)
            if lineRange.length != 0 {
                var leftOffset: CGFloat = 0.0
                if lineRange.location != rangeValue.location || line.isRTL {
                    leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                }
                var rightOffset: CGFloat = line.frame.width
                if lineRange.location + lineRange.length != rangeValue.upperBound || line.isRTL {
                    var secondaryOffset: CGFloat = 0.0
                    let rawOffset = CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, &secondaryOffset)
                    rightOffset = ceil(rawOffset)
                    if !rawOffset.isEqual(to: secondaryOffset) {
                        rightOffset = ceil(secondaryOffset)
                    }
                }
                var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y - line.frame.size.height + line.descent), size: line.frame.size)
                
                lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                
                let width = max(0.0, abs(rightOffset - leftOffset))
                
                if rangeValue.contains(range.lowerBound) {
                    let offsetX = floor(CTLineGetOffsetForStringIndex(line.line, range.lowerBound, nil))
                    startEdge = TextRangeRectEdge(x: lineFrame.minX + offsetX, y: lineFrame.minY, height: lineFrame.height)
                }
                if rangeValue.contains(range.upperBound - 1) {
                    let offsetX: CGFloat
                    if rangeValue.upperBound == range.upperBound {
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
        if !rects.isEmpty, var startEdge = startEdge, var endEdge = endEdge {
            startEdge.x += self.insets.left
            startEdge.y += self.insets.top
            endEdge.x += self.insets.left
            endEdge.y += self.insets.top
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

private func addSpoiler(line: TextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int) {
    var secondaryLeftOffset: CGFloat = 0.0
    let rawLeftOffset = CTLineGetOffsetForStringIndex(line.line, startIndex, &secondaryLeftOffset)
    var leftOffset = floor(rawLeftOffset)
    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
        leftOffset = floor(secondaryLeftOffset)
    }
    
    var secondaryRightOffset: CGFloat = 0.0
    let rawRightOffset = CTLineGetOffsetForStringIndex(line.line, endIndex, &secondaryRightOffset)
    var rightOffset = ceil(rawRightOffset)
    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
        rightOffset = ceil(secondaryRightOffset)
    }
    
    line.spoilers.append(TextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset), height: ascent + descent)))
}

private func addSpoilerWord(line: TextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
    var secondaryLeftOffset: CGFloat = 0.0
    let rawLeftOffset = CTLineGetOffsetForStringIndex(line.line, startIndex, &secondaryLeftOffset)
    var leftOffset = floor(rawLeftOffset)
    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
        leftOffset = floor(secondaryLeftOffset)
    }
    
    var secondaryRightOffset: CGFloat = 0.0
    let rawRightOffset = CTLineGetOffsetForStringIndex(line.line, endIndex, &secondaryRightOffset)
    var rightOffset = ceil(rawRightOffset)
    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
        rightOffset = ceil(secondaryRightOffset)
    }
    
    line.spoilerWords.append(TextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent)))
}

private func addEmbeddedItem(item: AnyHashable, line: TextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
    var secondaryLeftOffset: CGFloat = 0.0
    let rawLeftOffset = CTLineGetOffsetForStringIndex(line.line, startIndex, &secondaryLeftOffset)
    var leftOffset = floor(rawLeftOffset)
    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
        leftOffset = floor(secondaryLeftOffset)
    }
    
    var secondaryRightOffset: CGFloat = 0.0
    let rawRightOffset = CTLineGetOffsetForStringIndex(line.line, endIndex, &secondaryRightOffset)
    var rightOffset = ceil(rawRightOffset)
    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
        rightOffset = ceil(secondaryRightOffset)
    }
    
    line.embeddedItems.append(TextNodeEmbeddedItem(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent), item: item))
}

private func addAttachment(attachment: UIImage, line: TextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
    var secondaryLeftOffset: CGFloat = 0.0
    let rawLeftOffset = CTLineGetOffsetForStringIndex(line.line, startIndex, &secondaryLeftOffset)
    var leftOffset = floor(rawLeftOffset)
    if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
        leftOffset = floor(secondaryLeftOffset)
    }
    
    var secondaryRightOffset: CGFloat = 0.0
    let rawRightOffset = CTLineGetOffsetForStringIndex(line.line, endIndex, &secondaryRightOffset)
    var rightOffset = ceil(rawRightOffset)
    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
        rightOffset = ceil(secondaryRightOffset)
    }
    
    line.attachments.append(TextNodeAttachment(range: NSMakeRange(startIndex, endIndex - startIndex), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent), attachment: attachment))
}

public protocol TextNodeProtocol: ASDisplayNode {
    var currentText: NSAttributedString? { get }
    func textRangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)?
    func attributesAtPoint(_ point: CGPoint, orNearest: Bool) -> (Int, [NSAttributedString.Key: Any])?
}

open class TextNode: ASDisplayNode, TextNodeProtocol {
    public struct RenderContentTypes: OptionSet {
        public var rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let text = RenderContentTypes(rawValue: 1 << 0)
        public static let emoji = RenderContentTypes(rawValue: 1 << 1)
        
        public static let all: RenderContentTypes = [.text, .emoji]
    }
    
    final class DrawingParameters: NSObject {
        let cachedLayout: TextNodeLayout?
        let renderContentTypes: RenderContentTypes
        
        init(cachedLayout: TextNodeLayout?, renderContentTypes: RenderContentTypes) {
            self.cachedLayout = cachedLayout
            self.renderContentTypes = renderContentTypes
            
            super.init()
        }
    }
    
    public internal(set) var cachedLayout: TextNodeLayout?
    public var renderContentTypes: RenderContentTypes = .all
    
    public var currentText: NSAttributedString? {
        return self.cachedLayout?.attributedString
    }
    
    public func textRangeRects(in range: NSRange) -> (rects: [CGRect], start: TextRangeRectEdge, end: TextRangeRectEdge)? {
        return self.cachedLayout?.rangeRects(in: range)
    }
    
    override public init() {
        super.init()
        
        self.backgroundColor = UIColor.clear
        self.isOpaque = false
        self.clipsToBounds = false
    }
    
    override open func didLoad() {
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
    
    public func attributeSubstringWithRange(name: String, index: Int) -> (String, String, NSRange)? {
        return self.cachedLayout?.attributeSubstringWithRange(name: name, index: index)
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
    
    private static func calculateLayoutV2(
        attributedString: NSAttributedString,
        minimumNumberOfLines: Int,
        maximumNumberOfLines: Int,
        truncationType: CTLineTruncationType,
        backgroundColor: UIColor?,
        constrainedSize: CGSize,
        alignment: NSTextAlignment,
        verticalAlignment: TextVerticalAlignment,
        lineSpacingFactor: CGFloat,
        cutout: TextNodeCutout?,
        insets: UIEdgeInsets,
        lineColor: UIColor?,
        textShadowColor: UIColor?,
        textShadowBlur: CGFloat?,
        textStroke: (UIColor, CGFloat)?,
        displaySpoilers: Bool,
        displayEmbeddedItemsUnderSpoilers: Bool,
        customTruncationToken: NSAttributedString?
    ) -> TextNodeLayout {
        let blockQuoteLeftInset: CGFloat = 9.0
        let blockQuoteRightInset: CGFloat = 0.0
        let blockQuoteIconInset: CGFloat = 7.0
        
        struct StringSegment {
            let title: NSAttributedString?
            let substring: NSAttributedString
            let firstCharacterOffset: Int
            let blockQuote: TextNodeBlockQuoteData?
            let tintColor: UIColor?
            let secondaryTintColor: UIColor?
            let tertiaryTintColor: UIColor?
        }
        var stringSegments: [StringSegment] = []
        
        let rawWholeString = attributedString.string as NSString
        let wholeStringLength = rawWholeString.length
        
        var segmentCharacterOffset = 0
        while true {
            var found = false
            attributedString.enumerateAttribute(NSAttributedString.Key("Attribute__Blockquote"), in: NSRange(location: segmentCharacterOffset, length: wholeStringLength - segmentCharacterOffset), using: { value, effectiveRange, stop in
                found = true
                stop.pointee = ObjCBool(true)
                
                if segmentCharacterOffset != effectiveRange.location {
                    stringSegments.append(StringSegment(
                        title: nil,
                        substring: attributedString.attributedSubstring(from: NSRange(
                            location: segmentCharacterOffset,
                            length: effectiveRange.location - segmentCharacterOffset
                        )),
                        firstCharacterOffset: segmentCharacterOffset,
                        blockQuote: nil,
                        tintColor: nil,
                        secondaryTintColor: nil,
                        tertiaryTintColor: nil
                    ))
                }
                
                if let value = value as? TextNodeBlockQuoteData {
                    if effectiveRange.length != 0 {
                        stringSegments.append(StringSegment(
                            title: value.title,
                            substring: attributedString.attributedSubstring(from: effectiveRange),
                            firstCharacterOffset: effectiveRange.location,
                            blockQuote: value,
                            tintColor: value.color,
                            secondaryTintColor: value.secondaryColor,
                            tertiaryTintColor: value.tertiaryColor
                        ))
                    }
                    segmentCharacterOffset = effectiveRange.location + effectiveRange.length
                    if segmentCharacterOffset < wholeStringLength && rawWholeString.character(at: segmentCharacterOffset) == 0x0a {
                        segmentCharacterOffset += 1
                    }
                } else {
                    stringSegments.append(StringSegment(
                        title: nil,
                        substring: attributedString.attributedSubstring(from: effectiveRange),
                        firstCharacterOffset: effectiveRange.location,
                        blockQuote: nil,
                        tintColor: nil,
                        secondaryTintColor: nil,
                        tertiaryTintColor: nil
                    ))
                    segmentCharacterOffset = effectiveRange.location + effectiveRange.length
                }
            })
            if !found {
                if segmentCharacterOffset != wholeStringLength {
                    stringSegments.append(StringSegment(
                        title: nil,
                        substring: attributedString.attributedSubstring(from: NSRange(
                            location: segmentCharacterOffset,
                            length: wholeStringLength - segmentCharacterOffset
                        )),
                        firstCharacterOffset: segmentCharacterOffset,
                        blockQuote: nil,
                        tintColor: nil,
                        secondaryTintColor: nil,
                        tertiaryTintColor: nil
                    ))
                }
                
                break
            }
        }
        
        struct CalculatedSegment {
            var titleLine: TextNodeLine?
            var lines: [TextNodeLine] = []
            var tintColor: UIColor?
            var secondaryTintColor: UIColor?
            var tertiaryTintColor: UIColor?
            var blockQuote: TextNodeBlockQuoteData?
            var additionalWidth: CGFloat = 0.0
        }
        
        var calculatedSegments: [CalculatedSegment] = []
        
        for segment in stringSegments {
            var calculatedSegment = CalculatedSegment()
            calculatedSegment.blockQuote = segment.blockQuote
            calculatedSegment.tintColor = segment.tintColor
            calculatedSegment.secondaryTintColor = segment.secondaryTintColor
            calculatedSegment.tertiaryTintColor = segment.tertiaryTintColor
            
            let rawSubstring = segment.substring.string as NSString
            let substringLength = rawSubstring.length
            
            let segmentTypesetterString = attributedString.attributedSubstring(from: NSRange(location: 0, length: segment.firstCharacterOffset + substringLength))
            let typesetter = CTTypesetterCreateWithAttributedString(segmentTypesetterString as CFAttributedString)
            
            var currentLineStartIndex = segment.firstCharacterOffset
            let segmentEndIndex = segment.firstCharacterOffset + substringLength
            
            var constrainedSegmentWidth = constrainedSize.width
            var additionalOffsetX: CGFloat = 0.0
            if segment.blockQuote != nil {
                additionalOffsetX += blockQuoteLeftInset
                constrainedSegmentWidth -= additionalOffsetX + blockQuoteLeftInset + blockQuoteRightInset
                calculatedSegment.additionalWidth += blockQuoteLeftInset + blockQuoteRightInset
            }
            
            var additionalSegmentRightInset: CGFloat = 0.0
            if let blockQuote = segment.blockQuote {
                switch blockQuote.kind {
                case .quote:
                    additionalSegmentRightInset = blockQuoteIconInset
                case .code:
                    if segment.title != nil {
                        additionalSegmentRightInset = blockQuoteIconInset
                    }
                }
            }
            
            if let title = segment.title {
                let rawTitleLine = CTLineCreateWithAttributedString(title)
                if let titleLine = CTLineCreateTruncatedLine(rawTitleLine, constrainedSegmentWidth - additionalSegmentRightInset, .end, nil) {
                    var lineAscent: CGFloat = 0.0
                    var lineDescent: CGFloat = 0.0
                    let lineWidth = CTLineGetTypographicBounds(titleLine, &lineAscent, &lineDescent, nil)
                    calculatedSegment.titleLine = TextNodeLine(
                        line: titleLine,
                        frame: CGRect(origin: CGPoint(x: additionalOffsetX, y: 0.0), size: CGSize(width: lineWidth + additionalSegmentRightInset, height: lineAscent + lineDescent)),
                        ascent: lineAscent,
                        descent: lineDescent,
                        range: nil,
                        isRTL: false,
                        strikethroughs: [],
                        underlines: [],
                        spoilers: [],
                        spoilerWords: [],
                        embeddedItems: [],
                        attachments: [],
                        additionalTrailingLine: nil
                    )
                    additionalSegmentRightInset = 0.0
                }
            }
            
            while true {
                let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, currentLineStartIndex, constrainedSegmentWidth - additionalSegmentRightInset)
                
                if lineCharacterCount != 0 {
                    let line = CTTypesetterCreateLine(typesetter, CFRange(location: currentLineStartIndex, length: lineCharacterCount))
                    var lineAscent: CGFloat = 0.0
                    var lineDescent: CGFloat = 0.0
                    var lineWidth = CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, nil)
                    lineWidth = min(lineWidth, constrainedSegmentWidth - additionalSegmentRightInset)
                    
                    var isRTL = false
                    let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                    if glyphRuns.count != 0 {
                        let run = glyphRuns[0] as! CTRun
                        if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                        }
                    }
                    
                    calculatedSegment.lines.append(TextNodeLine(
                        line: line,
                        frame: CGRect(origin: CGPoint(x: additionalOffsetX, y: 0.0), size: CGSize(width: lineWidth + additionalSegmentRightInset, height: lineAscent + lineDescent)),
                        ascent: lineAscent,
                        descent: lineDescent,
                        range: NSRange(location: currentLineStartIndex, length: lineCharacterCount),
                        isRTL: isRTL && segment.blockQuote == nil,
                        strikethroughs: [],
                        underlines: [],
                        spoilers: [],
                        spoilerWords: [],
                        embeddedItems: [],
                        attachments: [],
                        additionalTrailingLine: nil
                    ))
                }
                
                additionalSegmentRightInset = 0.0
                
                currentLineStartIndex += lineCharacterCount
                
                if currentLineStartIndex >= segmentEndIndex {
                    break
                }
            }
            
            calculatedSegments.append(calculatedSegment)
        }
        
        var size = CGSize()
        let isTruncated = false
        
        for segment in calculatedSegments {
            if let titleLine = segment.titleLine {
                size.width = max(size.width, titleLine.frame.origin.x + titleLine.frame.width + segment.additionalWidth)
            }
            for line in segment.lines {
                size.width = max(size.width, line.frame.origin.x + line.frame.width + segment.additionalWidth)
            }
        }
        
        var lines: [TextNodeLine] = []
        
        var blockQuotes: [TextNodeBlockQuote] = []
        
        for i in 0 ..< calculatedSegments.count {
            let segment = calculatedSegments[i]
            if i != 0 {
                if segment.blockQuote != nil {
                    size.height += 6.0
                }
            } else {
                if segment.blockQuote != nil {
                    size.height += 7.0
                }
            }
            
            let blockMinY = size.height - insets.bottom
            var blockWidth: CGFloat = 0.0
            
            if let titleLine = segment.titleLine {
                titleLine.frame = CGRect(origin: CGPoint(x: titleLine.frame.origin.x, y: -insets.bottom + size.height + titleLine.frame.size.height), size: titleLine.frame.size)
                titleLine.frame.size.width += max(0.0, segment.additionalWidth - 2.0)
                size.height += titleLine.frame.height + titleLine.frame.height * lineSpacingFactor
                blockWidth = max(blockWidth, titleLine.frame.origin.x + titleLine.frame.width)
                
                lines.append(titleLine)
            }
            
            for line in segment.lines {
                line.frame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: -insets.bottom + size.height + line.frame.size.height), size: line.frame.size)
                line.frame.size.width += max(0.0, segment.additionalWidth - 2.0)
                size.height += line.frame.height + line.frame.height * lineSpacingFactor
                blockWidth = max(blockWidth, line.frame.origin.x + line.frame.width)
                
                if let range = line.range {
                    attributedString.enumerateAttributes(in: range, options: []) { attributes, range, _ in
                        if attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(line.line, &ascent, &descent, nil)
                            
                            var startIndex: Int?
                            var currentIndex: Int?
                            
                            let nsString = (attributedString.string as NSString)
                            nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                                if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                                    if let currentStartIndex = startIndex {
                                        startIndex = nil
                                        let endIndex = range.location
                                        addSpoilerWord(line: line, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex)
                                    }
                                } else if startIndex == nil {
                                    startIndex = range.location
                                }
                                currentIndex = range.location + range.length
                            }
                            
                            if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                                startIndex = nil
                                let endIndex = currentIndex
                                addSpoilerWord(line: line, ascent: ascent, descent: descent, startIndex: currentStartIndex, endIndex: endIndex, rightInset: 0.0)
                            }
                            
                            addSpoiler(line: line, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                        } else if let _ = attributes[NSAttributedString.Key.strikethroughStyle] {
                            let lowerX = floor(CTLineGetOffsetForStringIndex(line.line, range.location, nil))
                            let upperX = ceil(CTLineGetOffsetForStringIndex(line.line, range.location + range.length, nil))
                            let x = lowerX < upperX ? lowerX : upperX
                            line.strikethroughs.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: line.frame.height)))
                        }
                        
                        if let embeddedItem = (attributes[NSAttributedString.Key(rawValue: "TelegramEmbeddedItem")] as? AnyHashable ?? attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable) {
                            if displayEmbeddedItemsUnderSpoilers || (attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] == nil && attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] == nil) {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(line.line, &ascent, &descent, nil)
                                
                                addEmbeddedItem(item: embeddedItem, line: line, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            }
                        }
                        
                        if let attachment = attributes[NSAttributedString.Key.attachment] as? UIImage {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(line.line, &ascent, &descent, nil)
                            
                            addAttachment(attachment: attachment, line: line, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                        }
                    }
                }
                
                lines.append(line)
            }
            
            let blockMaxY = size.height - insets.bottom
            
            if i != calculatedSegments.count - 1 {
                if segment.blockQuote != nil {
                    size.height += 8.0
                }
            } else {
                if segment.blockQuote != nil {
                    size.height += 6.0
                }
            }
            
            if let blockQuote = segment.blockQuote, let tintColor = segment.tintColor {
                blockQuotes.append(TextNodeBlockQuote(frame: CGRect(origin: CGPoint(x: 0.0, y: blockMinY - 2.0), size: CGSize(width: blockWidth, height: blockMaxY - (blockMinY - 2.0) + 4.0)), data: blockQuote, tintColor: tintColor, secondaryTintColor: segment.secondaryTintColor, tertiaryTintColor: segment.tertiaryTintColor, backgroundColor: blockQuote.backgroundColor))
            }
        }
        
        size.width = ceil(size.width)
        size.height = ceil(size.height)
        
        let rawTextSize = size
        size.width += insets.left + insets.right
        size.height += insets.top + insets.bottom
        
        return TextNodeLayout(
            attributedString: attributedString,
            maximumNumberOfLines: maximumNumberOfLines,
            truncationType: truncationType,
            constrainedSize: constrainedSize,
            explicitAlignment: alignment,
            resolvedAlignment: alignment,
            verticalAlignment: verticalAlignment,
            lineSpacing: lineSpacingFactor,
            cutout: cutout,
            insets: insets,
            size: size,
            rawTextSize: rawTextSize,
            truncated: isTruncated,
            firstLineOffset: lines.first?.descent ?? 0.0,
            lines: lines,
            blockQuotes: blockQuotes,
            backgroundColor: backgroundColor,
            lineColor: lineColor,
            textShadowColor: textShadowColor,
            textShadowBlur: textShadowBlur,
            textStroke: textStroke,
            displaySpoilers: displaySpoilers
        )
    }
    
    static func calculateLayout(attributedString: NSAttributedString?, minimumNumberOfLines: Int, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacingFactor: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, lineColor: UIColor?, textShadowColor: UIColor?, textShadowBlur: CGFloat?, textStroke: (UIColor, CGFloat)?, displaySpoilers: Bool, displayEmbeddedItemsUnderSpoilers: Bool, customTruncationToken: NSAttributedString?) -> TextNodeLayout {
        guard let attributedString else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: alignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, lines: [], blockQuotes: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displaySpoilers: displaySpoilers)
        }
        
        var found = false
        attributedString.enumerateAttribute(NSAttributedString.Key("Attribute__Blockquote"), in: NSRange(location: 0, length: attributedString.length), using: { value, effectiveRange, _ in
            if let _ = value as? TextNodeBlockQuoteData {
                found = true
            }
        })
        
        if found {
            return calculateLayoutV2(attributedString: attributedString, minimumNumberOfLines: minimumNumberOfLines, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, alignment: alignment, verticalAlignment: verticalAlignment, lineSpacingFactor: lineSpacingFactor, cutout: cutout, insets: insets, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displaySpoilers: displaySpoilers, displayEmbeddedItemsUnderSpoilers: displayEmbeddedItemsUnderSpoilers, customTruncationToken: customTruncationToken)
        }
        
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
        let blockQuotes: [TextNodeBlockQuote] = []
        
        var maybeTypesetter: CTTypesetter?
        maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
        if maybeTypesetter == nil {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: resolvedAlignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, lines: [], blockQuotes: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displaySpoilers: displaySpoilers)
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
            var underlines: [TextNodeStrikethrough] = []
            var spoilers: [TextNodeSpoiler] = []
            var spoilerWords: [TextNodeSpoiler] = []
            var embeddedItems: [TextNodeEmbeddedItem] = []
            var attachments: [TextNodeAttachment] = []
            
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
            
            func addAttachment(attachment: UIImage, line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, isAtEndOfTheLine: Bool, rightInset: CGFloat = 0.0) {
                var secondaryLeftOffset: CGFloat = 0.0
                let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                var leftOffset = floor(rawLeftOffset)
                if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                    leftOffset = floor(secondaryLeftOffset)
                }
                
                var rightOffset: CGFloat = leftOffset
                if isAtEndOfTheLine {
                    let rawRightOffset = CTLineGetTypographicBounds(line, nil, nil, nil)
                    rightOffset = floor(rawRightOffset)
                } else {
                    var secondaryRightOffset: CGFloat = 0.0
                    let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                    rightOffset = ceil(rawRightOffset)
                    if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                        rightOffset = ceil(secondaryRightOffset)
                    }
                }
                
                attachments.append(TextNodeAttachment(range: NSMakeRange(startIndex, endIndex - startIndex), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent), attachment: attachment))
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
                
                var didClipLinebreak = false
                var lineRange = CFRange(location: lastLineCharacterIndex, length: stringLength - lastLineCharacterIndex)
                let nsString = (attributedString.string as NSString)
                for i in lineRange.location ..< (lineRange.location + lineRange.length) {
                    if nsString.character(at: i) == 0x0a {
                        lineRange.length = max(0, i - lineRange.location)
                        didClipLinebreak = true
                        break
                    }
                }
                
                var brokenLineRange = CFRange(location: lastLineCharacterIndex, length: lineCharacterCount)
                if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                    brokenLineRange.length = attributedString.length - brokenLineRange.location
                }
                if lineRange.length == 0 && !didClipLinebreak {
                    break
                }
                
                let coreTextLine: CTLine
                let originalLine = CTTypesetterCreateLineWithOffset(typesetter, lineRange, 0.0)
                
                var lineConstrainedSize = constrainedSize
                lineConstrainedSize.width += lineConstrainedWidthDelta
                if bottomCutoutEnabled {
                    lineConstrainedSize.width -= bottomCutoutSize.width
                }
                
                let truncatedTokenString: NSAttributedString
                if let customTruncationToken {
                    if lineRange.length == 0 && customTruncationToken.string.hasPrefix("\u{2026} ") {
                        truncatedTokenString = customTruncationToken.attributedSubstring(from: NSRange(location: 2, length: customTruncationToken.length - 2))
                    } else {
                        truncatedTokenString = customTruncationToken
                    }
                } else {
                    var truncationTokenAttributes: [NSAttributedString.Key : AnyObject] = [:]
                    truncationTokenAttributes[NSAttributedString.Key.font] = font
                    truncationTokenAttributes[NSAttributedString.Key(rawValue:  kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                    let tokenString = "\u{2026}"
                    
                    truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                }
                let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                let truncationTokenWidth = CTLineGetTypographicBounds(truncationToken, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(truncationToken)
                
                var effectiveLineRange = brokenLineRange
                var additionalTrailingLine: (CTLine, Double)?
                
                var measureFitWidth = CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine)
                if customTruncationToken != nil && lineRange.location + lineRange.length < attributedString.length {
                    measureFitWidth += truncationTokenWidth
                }
                
                if lineRange.length == 0 || measureFitWidth < Double(lineConstrainedSize.width) {
                    if didClipLinebreak {
                        if lineRange.length == 0 {
                            coreTextLine = CTLineCreateWithAttributedString(NSAttributedString())
                        } else {
                            coreTextLine = originalLine
                        }
                        additionalTrailingLine = (truncationToken, truncationTokenWidth)
                        
                        truncated = true
                    } else {
                        coreTextLine = originalLine
                    }
                } else {
                    if customTruncationToken != nil {
                        let coreTextLine1 = CTLineCreateTruncatedLine(originalLine, max(1.0, Double(lineConstrainedSize.width)), truncationType, truncationToken) ?? truncationToken
                        let runs = (CTLineGetGlyphRuns(coreTextLine1) as [AnyObject]) as! [CTRun]
                        var hasTruncationToken = false
                        for run in runs {
                            let runRange = CTRunGetStringRange(run)
                            if runRange.location + runRange.length >= nsString.length {
                                hasTruncationToken = true
                                break
                            }
                        }
                        
                        if hasTruncationToken {
                            coreTextLine = coreTextLine1
                        } else {
                            let coreTextLine2 = CTLineCreateTruncatedLine(originalLine, max(1.0, Double(lineConstrainedSize.width) - truncationTokenWidth), truncationType, truncationToken) ?? truncationToken
                            coreTextLine = coreTextLine2
                        }
                    } else {
                        coreTextLine = CTLineCreateTruncatedLine(originalLine, max(1.0, Double(lineConstrainedSize.width)), truncationType, truncationToken) ?? truncationToken
                    }
                    let runs = (CTLineGetGlyphRuns(coreTextLine) as [AnyObject]) as! [CTRun]
                    for run in runs {
                        let runAttributes: NSDictionary = CTRunGetAttributes(run)
                        if let _ = runAttributes["CTForegroundColorFromContext"] {
                            brokenLineRange.length = CTRunGetStringRange(run).location - brokenLineRange.location
                            break
                        }
                    }
                    if customTruncationToken != nil {
                        assert(true)
                    }
                    effectiveLineRange = CFRange(location: effectiveLineRange.location, length: 0)
                    for run in runs {
                        let runRange = CTRunGetStringRange(run)
                        if runRange.location + runRange.length > brokenLineRange.location + brokenLineRange.length {
                            continue
                        }
                        effectiveLineRange.length = max(effectiveLineRange.length, (runRange.location + runRange.length) - effectiveLineRange.location)
                    }
                    
                    if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                        brokenLineRange.length = attributedString.length - brokenLineRange.location
                    }
                    if effectiveLineRange.location + effectiveLineRange.length > attributedString.length {
                        effectiveLineRange.length = attributedString.length - effectiveLineRange.location
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
                        } else if let _ = attributes[NSAttributedString.Key.underlineStyle] {
                            let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                            let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                            let x = lowerX < upperX ? lowerX : upperX
                            underlines.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                        } else if let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle {
                            headIndent = paragraphStyle.headIndent
                        }
                        
                        if let embeddedItem = (attributes[NSAttributedString.Key(rawValue: "TelegramEmbeddedItem")] as? AnyHashable ?? attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable) {
                            if displayEmbeddedItemsUnderSpoilers || (attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] == nil && attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] == nil) {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                
                                addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            }
                        }
                        
                        if let attachment = attributes[NSAttributedString.Key.attachment] as? UIImage {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                            
                            addAttachment(attachment: attachment, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: max(range.location, min(lineRange.location + lineRange.length, range.location + range.length)), isAtEndOfTheLine: range.location + range.length >= lineRange.location + lineRange.length - 1)
                        }
                    }
                }
                
                var lineAscent: CGFloat = 0.0
                var lineDescent: CGFloat = 0.0
                let lineWidth = min(lineConstrainedSize.width, ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, &lineAscent, &lineDescent, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine))))
                let lineFrame = CGRect(x: lineCutoutOffset + headIndent, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                layoutSize.height += fontLineHeight + fontLineSpacing
                
                if let (_, additionalTrailingLineWidth) = additionalTrailingLine {
                    lineAdditionalWidth += additionalTrailingLineWidth
                }
                
                layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                
                var isRTL = false
                let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                if glyphRuns.count != 0 {
                    let run = glyphRuns[0] as! CTRun
                    if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                        isRTL = true
                    }
                }
                
                lines.append(TextNodeLine(
                    line: coreTextLine,
                    frame: lineFrame,
                    ascent: lineAscent,
                    descent: lineDescent,
                    range: NSMakeRange(effectiveLineRange.location, effectiveLineRange.length),
                    isRTL: isRTL,
                    strikethroughs: strikethroughs,
                    underlines: underlines,
                    spoilers: spoilers,
                    spoilerWords: spoilerWords,
                    embeddedItems: embeddedItems,
                    attachments: attachments,
                    additionalTrailingLine: additionalTrailingLine
                ))
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
                        } else if let _ = attributes[NSAttributedString.Key.underlineStyle] {
                            let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                            let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                            let x = lowerX < upperX ? lowerX : upperX
                            underlines.append(TextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                        } else if let paragraphStyle = attributes[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle {
                            headIndent = paragraphStyle.headIndent
                        }
                        
                        if let embeddedItem = (attributes[NSAttributedString.Key(rawValue: "TelegramEmbeddedItem")] as? AnyHashable ?? attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable) {
                            if displayEmbeddedItemsUnderSpoilers || (attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] == nil && attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] == nil) {
                                var ascent: CGFloat = 0.0
                                var descent: CGFloat = 0.0
                                CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                
                                addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                            }
                        }
                        
                        if let attachment = attributes[NSAttributedString.Key.attachment] as? UIImage {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                            
                            addAttachment(attachment: attachment, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: max(range.location, min(lineRange.location + lineRange.length, range.location + range.length)), isAtEndOfTheLine: range.location + range.length >= lineRange.location + lineRange.length - 1)
                        }
                    }
                    
                    var lineAscent: CGFloat = 0.0
                    var lineDescent: CGFloat = 0.0
                    let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, &lineAscent, &lineDescent, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                    let lineFrame = CGRect(x: lineCutoutOffset + headIndent, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth + headIndent)
                    
                    var isRTL = false
                    let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                    if glyphRuns.count != 0 {
                        let run = glyphRuns[0] as! CTRun
                        if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                        }
                    }
                    
                    lines.append(TextNodeLine(
                        line: coreTextLine,
                        frame: lineFrame,
                        ascent: lineAscent,
                        descent: lineDescent,
                        range: NSMakeRange(lineRange.location, lineRange.length),
                        isRTL: isRTL,
                        strikethroughs: strikethroughs,
                        underlines: underlines,
                        spoilers: spoilers,
                        spoilerWords: spoilerWords,
                        embeddedItems: embeddedItems,
                        attachments: attachments,
                        additionalTrailingLine: nil
                    ))
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
        
        return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: resolvedAlignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(width: ceil(layoutSize.width) + insets.left + insets.right, height: ceil(layoutSize.height) + insets.top + insets.bottom), rawTextSize: CGSize(width: ceil(rawLayoutSize.width) + insets.left + insets.right, height: ceil(rawLayoutSize.height) + insets.top + insets.bottom), truncated: truncated, firstLineOffset: firstLineOffset, lines: lines, blockQuotes: blockQuotes, backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displaySpoilers: displaySpoilers)
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return DrawingParameters(cachedLayout: self.cachedLayout, renderContentTypes: self.renderContentTypes)
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
        
        var blendMode: CGBlendMode = .normal
        
        var renderContentTypes: RenderContentTypes = .all
        if let parameters = parameters as? DrawingParameters {
            renderContentTypes = parameters.renderContentTypes
        }
        
        var clearRects: [CGRect] = []
        if let layout = (parameters as? DrawingParameters)?.cachedLayout {
            if !isRasterizing || layout.backgroundColor != nil {
                context.setBlendMode(.copy)
                blendMode = .copy
                
                context.setFillColor((layout.backgroundColor ?? UIColor.clear).cgColor)
                context.fill(bounds)
                
                context.setBlendMode(.normal)
                blendMode = .normal
            }
            
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
            
            if !layout.lines.isEmpty {
                offset.y += layout.lines[0].descent
            }
            
            for blockQuote in layout.blockQuotes {
                let radius: CGFloat = 4.0
                let lineWidth: CGFloat = 3.0
                
                var blockFrame = blockQuote.frame.offsetBy(dx: offset.x + 2.0, dy: offset.y)
                if blockFrame.origin.x + blockFrame.size.width > bounds.width - layout.insets.right - 2.0 - 30.0 {
                    blockFrame.size.width = bounds.width - layout.insets.right - blockFrame.origin.x - 2.0
                }
                blockFrame.size.width += 4.0
                blockFrame.origin.x -= 2.0
                
                context.setFillColor(blockQuote.backgroundColor.cgColor)
                context.addPath(UIBezierPath(roundedRect: blockFrame, cornerRadius: radius).cgPath)
                context.fillPath()
                
                context.setFillColor(blockQuote.tintColor.cgColor)
                
                switch blockQuote.data.kind {
                case .quote:
                    let quoteRect = CGRect(origin: CGPoint(x: blockFrame.maxX - 4.0 - quoteIcon.size.width, y: blockFrame.minY + 4.0), size: quoteIcon.size)
                    context.saveGState()
                    context.translateBy(x: quoteRect.midX, y: quoteRect.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -quoteRect.midX, y: -quoteRect.midY)
                    context.clip(to: quoteRect, mask: quoteIcon.cgImage!)
                    context.fill(quoteRect)
                    context.restoreGState()
                    context.resetClip()
                case .code:
                    if blockQuote.data.title != nil {
                        let quoteRect = CGRect(origin: CGPoint(x: blockFrame.maxX - 4.0 - codeIcon.size.width, y: blockFrame.minY + 4.0), size: codeIcon.size)
                        context.saveGState()
                        context.translateBy(x: quoteRect.midX, y: quoteRect.midY)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.translateBy(x: -quoteRect.midX, y: -quoteRect.midY)
                        context.clip(to: quoteRect, mask: codeIcon.cgImage!)
                        context.fill(quoteRect)
                        context.restoreGState()
                        context.resetClip()
                    }
                }
                
                let lineFrame = CGRect(origin: CGPoint(x: blockFrame.minX, y: blockFrame.minY), size: CGSize(width: lineWidth, height: blockFrame.height))
                context.move(to: CGPoint(x: lineFrame.minX, y: lineFrame.minY + radius))
                context.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.minY), tangent2End: CGPoint(x: lineFrame.minX + radius, y: lineFrame.minY), radius: radius)
                context.addLine(to: CGPoint(x: lineFrame.minX + radius, y: lineFrame.maxY))
                context.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY), tangent2End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY - radius), radius: radius)
                context.closePath()
                context.clip()
                
                if let secondaryTintColor = blockQuote.secondaryTintColor {
                    let isMonochrome = secondaryTintColor.alpha == 0.0
                    
                    let tertiaryTintColor = blockQuote.tertiaryTintColor
                    let dashHeight: CGFloat = tertiaryTintColor != nil ? 6.0 : 9.0
                    
                    do {
                        context.saveGState()
                        
                        let dashOffset: CGFloat
                        if let _ = tertiaryTintColor {
                            dashOffset = isMonochrome ? -7.0 : 5.0
                        } else {
                            dashOffset = isMonochrome ? -4.0 : 5.0
                        }
                        
                        if isMonochrome {
                            context.setFillColor(blockQuote.tintColor.withMultipliedAlpha(0.2).cgColor)
                            context.fill(lineFrame)
                            context.setFillColor(blockQuote.tintColor.cgColor)
                        } else {
                            context.setFillColor(blockQuote.tintColor.cgColor)
                            context.fill(lineFrame)
                            context.setFillColor(secondaryTintColor.cgColor)
                        }
                        
                        if let _ = tertiaryTintColor {
                            context.translateBy(x: 0.0, y: dashHeight)
                        }
                        
                        func drawDashes() {
                            context.translateBy(x: blockFrame.minX, y: blockFrame.minY + dashOffset)
                            
                            var offset = 0.0
                            while offset < blockFrame.height {
                                context.move(to: CGPoint(x: 0.0, y: 3.0))
                                context.addLine(to: CGPoint(x: lineWidth, y: 0.0))
                                context.addLine(to: CGPoint(x: lineWidth, y: dashHeight))
                                context.addLine(to: CGPoint(x: 0.0, y: dashHeight + 3.0))
                                context.closePath()
                                context.fillPath()
                                
                                context.translateBy(x: 0.0, y: 18.0)
                                offset += 18.0
                            }
                        }
                        
                        drawDashes()
                        context.restoreGState()
                        
                        if let tertiaryTintColor {
                            context.saveGState()
                            if isMonochrome {
                                context.setFillColor(blockQuote.tintColor.withAlphaComponent(0.4).cgColor)
                            } else {
                                context.setFillColor(tertiaryTintColor.cgColor)
                            }
                            drawDashes()
                            context.restoreGState()
                        }
                    }
                } else {
                    context.setFillColor(blockQuote.tintColor.cgColor)
                    context.setBlendMode(.copy)
                    context.fill(lineFrame)
                    context.setBlendMode(.normal)
                }
                
                context.resetClip()
            }
            
            if let textShadowColor = layout.textShadowColor {
                context.setTextDrawingMode(.fill)
                context.setShadow(offset: layout.textShadowBlur != nil ? .zero : CGSize(width: 0.0, height: 1.0), blur: layout.textShadowBlur ?? 0.0, color: textShadowColor.cgColor)
            }
            
            if let (textStrokeColor, textStrokeWidth) = layout.textStroke {
                context.setBlendMode(.normal)
                blendMode = .normal
                
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
                } else if alignment == .right {
                    lineFrame.origin.x = offset.x + (bounds.size.width - lineFrame.width)
                }
                
                //context.setStrokeColor(UIColor.red.cgColor)
                //context.stroke(lineFrame.offsetBy(dx: 0.0, dy: -lineFrame.height))
                
                lineFrame.origin.y += -line.descent
                
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
                    let hasAttachments = !line.attachments.isEmpty
                    for run in glyphRuns {
                        let run = run as! CTRun
                        let glyphCount = CTRunGetGlyphCount(run)
                        let attributes = CTRunGetAttributes(run) as NSDictionary
                        if attributes["Attribute__EmbeddedItem"] != nil {
                            continue
                        }
                        
                        if renderContentTypes != .all {
                            if let font = attributes["NSFont"] as? UIFont, font.fontName.contains("ColorEmoji") {
                                if !renderContentTypes.contains(.emoji) {
                                    continue
                                }
                            } else {
                                if !renderContentTypes.contains(.text) {
                                    continue
                                }
                            }
                        }
                        
                        var fixDoubleEmoji = false
                        if glyphCount == 2, let font = attributes["NSFont"] as? UIFont, font.fontName.contains("ColorEmoji"), let string = layout.attributedString {
                            let range = CTRunGetStringRange(run)
                            
                            if range.location < string.length && (range.location + range.length) <= string.length {
                                let substring = string.attributedSubstring(from: NSMakeRange(range.location, range.length)).string
                                
                                let heart = Unicode.Scalar(0x2764)!
                                let man = Unicode.Scalar(0x1F468)!
                                let woman = Unicode.Scalar(0x1F469)!
                                let leftHand = Unicode.Scalar(0x1FAF1)!
                                let rightHand = Unicode.Scalar(0x1FAF2)!
                                
                                if substring.unicodeScalars.contains(heart) && (substring.unicodeScalars.contains(man) || substring.unicodeScalars.contains(woman)) {
                                    fixDoubleEmoji = true
                                } else if substring.unicodeScalars.contains(leftHand) && substring.unicodeScalars.contains(rightHand) {
                                    fixDoubleEmoji = true
                                }
                            }
                        }
                        
                        if fixDoubleEmoji {
                            context.setBlendMode(.normal)
                        }
                        
                        if hasAttachments {
                            let stringRange = CTRunGetStringRange(run)
                            if line.attachments.contains(where: { $0.range.contains(stringRange.location) }) {
                            } else {
                                CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                            }
                        } else {
                            CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                        }
                        
                        if fixDoubleEmoji {
                            context.setBlendMode(blendMode)
                        }
                    }
                }
                
                for attachment in line.attachments {
                    let image = attachment.attachment
                    var textColor: UIColor?
                    layout.attributedString?.enumerateAttributes(in: attachment.range, options: []) { attributes, range, _ in
                        if let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                            textColor = color
                        }
                    }
                    if image.renderingMode == .alwaysOriginal {
                        let imageRect = CGRect(origin: CGPoint(x: attachment.frame.midX - image.size.width * 0.5, y: attachment.frame.midY - image.size.height * 0.5 + 1.0), size: image.size).offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                        context.translateBy(x: imageRect.midX, y: imageRect.midY)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                        context.draw(image.cgImage!, in: imageRect)
                        context.translateBy(x: imageRect.midX, y: imageRect.midY)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                    } else if let textColor {
                        if let tintedImage = generateTintedImage(image: image, color: textColor) {
                            let imageRect = CGRect(origin: CGPoint(x: attachment.frame.midX - tintedImage.size.width * 0.5, y: attachment.frame.midY - tintedImage.size.height * 0.5 + 1.0), size: tintedImage.size).offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                            context.translateBy(x: imageRect.midX, y: imageRect.midY)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                            context.draw(tintedImage.cgImage!, in: imageRect)
                            context.translateBy(x: imageRect.midX, y: imageRect.midY)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                        }
                    }
                }
                
                if drawUnderlinesManually {
                    if !line.underlines.isEmpty {
                        for strikethrough in line.underlines {
                            guard let lineRange = line.range else {
                                continue
                            }
                            var textColor: UIColor?
                            layout.attributedString?.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                                if range == strikethrough.range, let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                    textColor = color
                                }
                            }
                            if let textColor = textColor {
                                context.setFillColor(textColor.cgColor)
                            }
                            let frame = strikethrough.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                            context.fill(CGRect(x: frame.minX, y: frame.minY + 1.0, width: frame.width, height: 1.0))
                        }
                    }
                }
                if !line.strikethroughs.isEmpty {
                    for strikethrough in line.strikethroughs {
                        guard let lineRange = line.range else {
                            continue
                        }
                        var textColor: UIColor?
                        layout.attributedString?.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
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
                
                if let (additionalTrailingLine, _) = line.additionalTrailingLine {
                    context.textPosition = CGPoint(x: lineFrame.maxX, y: lineFrame.minY)
                    
                    let glyphRuns = CTLineGetGlyphRuns(additionalTrailingLine) as NSArray
                    if glyphRuns.count != 0 {
                        for run in glyphRuns {
                            let run = run as! CTRun
                            let glyphCount = CTRunGetGlyphCount(run)
                            let attributes = CTRunGetAttributes(run) as NSDictionary
                            if attributes["Attribute__EmbeddedItem"] != nil {
                                continue
                            }
                            
                            var fixDoubleEmoji = false
                            if glyphCount == 2, let font = attributes["NSFont"] as? UIFont, font.fontName.contains("ColorEmoji"), let string = layout.attributedString {
                                let range = CTRunGetStringRange(run)
                                
                                if range.location < string.length && (range.location + range.length) <= string.length {
                                    let substring = string.attributedSubstring(from: NSMakeRange(range.location, range.length)).string
                                    
                                    let heart = Unicode.Scalar(0x2764)!
                                    let man = Unicode.Scalar(0x1F468)!
                                    let woman = Unicode.Scalar(0x1F469)!
                                    let leftHand = Unicode.Scalar(0x1FAF1)!
                                    let rightHand = Unicode.Scalar(0x1FAF2)!
                                    
                                    if substring.unicodeScalars.contains(heart) && (substring.unicodeScalars.contains(man) || substring.unicodeScalars.contains(woman)) {
                                        fixDoubleEmoji = true
                                    } else if substring.unicodeScalars.contains(leftHand) && substring.unicodeScalars.contains(rightHand) {
                                        fixDoubleEmoji = true
                                    }
                                }
                            }
                            
                            if fixDoubleEmoji {
                                context.setBlendMode(.normal)
                            }
                            CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                            if fixDoubleEmoji {
                                context.setBlendMode(blendMode)
                            }
                        }
                    }
                }
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
                    layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textShadowBlur: arguments.textShadowBlur, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers, displayEmbeddedItemsUnderSpoilers: arguments.displayEmbeddedItemsUnderSpoilers, customTruncationToken: arguments.customTruncationToken)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textShadowBlur: arguments.textShadowBlur, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers, displayEmbeddedItemsUnderSpoilers: arguments.displayEmbeddedItemsUnderSpoilers, customTruncationToken: arguments.customTruncationToken)
                updated = true
            }
            
            let node = maybeNode ?? TextNode()
            
            return (layout, {
                node.cachedLayout = layout
                if updated {
                    if layout.size.width.isZero || layout.size.height.isZero {
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
    
    private class func calculateLayout(attributedString: NSAttributedString?, minimumNumberOfLines: Int, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacingFactor: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, lineColor: UIColor?, textShadowColor: UIColor?, textShadowBlur: CGFloat?, textStroke: (UIColor, CGFloat)?, displaySpoilers: Bool) -> TextNodeLayout {
        return TextNode.calculateLayout(attributedString: attributedString, minimumNumberOfLines: minimumNumberOfLines, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, alignment: alignment, verticalAlignment: verticalAlignment, lineSpacingFactor: lineSpacingFactor, cutout: cutout, insets: insets, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displaySpoilers: displaySpoilers, displayEmbeddedItemsUnderSpoilers: false, customTruncationToken: nil)
    }
    
    public override func draw(_ rect: CGRect) {
        let layout = self.cachedLayout
        
        let context = UIGraphicsGetCurrentContext()!
        
        context.setAllowsAntialiasing(true)
        
        context.setAllowsFontSmoothing(false)
        context.setShouldSmoothFonts(false)
        
        context.setAllowsFontSubpixelPositioning(false)
        context.setShouldSubpixelPositionFonts(false)
        
        context.setAllowsFontSubpixelQuantization(true)
        context.setShouldSubpixelQuantizeFonts(true)
        
        TextNode.draw(rect, withParameters: TextNode.DrawingParameters(cachedLayout: layout, renderContentTypes: .all), isCancelled: { false }, isRasterizing: false)
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
                    layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textShadowBlur: arguments.textShadowBlur, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers, displayEmbeddedItemsUnderSpoilers: arguments.displayEmbeddedItemsUnderSpoilers, customTruncationToken: arguments.customTruncationToken)
                    updated = true
                }
            } else {
                layout = TextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textShadowBlur: arguments.textShadowBlur, textStroke: arguments.textStroke, displaySpoilers: arguments.displaySpoilers, displayEmbeddedItemsUnderSpoilers: arguments.displayEmbeddedItemsUnderSpoilers, customTruncationToken: arguments.customTruncationToken)
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
