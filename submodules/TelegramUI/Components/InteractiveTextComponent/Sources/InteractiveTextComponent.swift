import Foundation
import UIKit
import AsyncDisplayKit
import Display
import CoreText
import AppBundle
import ComponentFlow
import TextFormat
import MessageInlineBlockBackgroundView
import InvisibleInkDustNode
import EmojiTextAttachmentView

private let defaultFont = UIFont.systemFont(ofSize: 15.0)

private let quoteIcon: UIImage = {
    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon"), color: .white)!
}()

private let codeIcon: UIImage = {
    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/TextCodeIcon"), color: .white)!
}()

private let expandArrowIcon: UIImage = {
    return generateTintedImage(image: UIImage(bundleImageName: "Item List/ExpandingItemVerticalRegularArrow"), color: .white)!
}()

private func generateBlockMaskImage() -> UIImage {
    let size = CGSize(width: 36.0 + 20.0, height: 36.0)
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var locations: [CGFloat] = [0.0, 0.5, 1.0]
        var colors: [CGColor] = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.cgColor]
        
        var gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.setBlendMode(.copy)
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width - 20.0, y: size.height), startRadius: 0.0, endCenter: CGPoint(x: size.width - 20.0, y: size.height), endRadius: 34.0, options: CGGradientDrawingOptions())
        
        locations = [0.0, 0.4, 1.0]
        colors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.cgColor]
        gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.setBlendMode(.destinationIn)
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: 0.0, y: size.height - 8.0), options: CGGradientDrawingOptions())
    })!.resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: size.height - 1.0, right: size.width - 1.0), resizingMode: .stretch)
}

private let expandableBlockMaskImage: UIImage = {
    return generateBlockMaskImage()
}()

private final class InteractiveTextNodeStrikethrough {
    let range: NSRange
    let frame: CGRect
    
    init(range: NSRange, frame: CGRect) {
        self.range = range
        self.frame = frame
    }
}

private final class InteractiveTextNodeSpoiler {
    let range: NSRange
    let frame: CGRect
    
    init(range: NSRange, frame: CGRect) {
        self.range = range
        self.frame = frame
    }
}

private final class InteractiveTextNodeEmbeddedItem {
    let range: NSRange
    let frame: CGRect
    let item: AnyHashable
    let isHiddenBySpoiler: Bool
    
    init(range: NSRange, frame: CGRect, item: AnyHashable, isHiddenBySpoiler: Bool) {
        self.range = range
        self.frame = frame
        self.item = item
        self.isHiddenBySpoiler = isHiddenBySpoiler
    }
}

private final class InteractiveTextNodeAttachment {
    let range: NSRange
    let frame: CGRect
    let attachment: UIImage
    
    init(range: NSRange, frame: CGRect, attachment: UIImage) {
        self.range = range
        self.frame = frame
        self.attachment = attachment
    }
}

private final class InteractiveTextNodeLine {
    let line: CTLine
    let constrainedWidth: CGFloat
    var frame: CGRect
    let intrinsicWidth: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let range: NSRange?
    let isTruncated: Bool
    let isRTL: Bool
    var strikethroughs: [InteractiveTextNodeStrikethrough]
    var underlines: [InteractiveTextNodeStrikethrough]
    var spoilers: [InteractiveTextNodeSpoiler]
    var spoilerWords: [InteractiveTextNodeSpoiler]
    var embeddedItems: [InteractiveTextNodeEmbeddedItem]
    var attachments: [InteractiveTextNodeAttachment]
    let additionalTrailingLine: (CTLine, Double)?
    
    init(line: CTLine, constrainedWidth: CGFloat, frame: CGRect, intrinsicWidth: CGFloat, ascent: CGFloat, descent: CGFloat, range: NSRange?, isTruncated: Bool, isRTL: Bool, strikethroughs: [InteractiveTextNodeStrikethrough], underlines: [InteractiveTextNodeStrikethrough], spoilers: [InteractiveTextNodeSpoiler], spoilerWords: [InteractiveTextNodeSpoiler], embeddedItems: [InteractiveTextNodeEmbeddedItem], attachments: [InteractiveTextNodeAttachment], additionalTrailingLine: (CTLine, Double)?) {
        self.line = line
        self.constrainedWidth = constrainedWidth
        self.frame = frame
        self.intrinsicWidth = intrinsicWidth
        self.ascent = ascent
        self.descent = descent
        self.range = range
        self.isTruncated = isTruncated
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

private final class InteractiveTextNodeBlockQuote {
    let id: Int
    let frame: CGRect
    let data: TextNodeBlockQuoteData
    let tintColor: UIColor
    let secondaryTintColor: UIColor?
    let tertiaryTintColor: UIColor?
    let backgroundColor: UIColor
    let isCollapsed: Bool?
    
    init(id: Int, frame: CGRect, data: TextNodeBlockQuoteData, tintColor: UIColor, secondaryTintColor: UIColor?, tertiaryTintColor: UIColor?, backgroundColor: UIColor, isCollapsed: Bool?) {
        self.id = id
        self.frame = frame
        self.data = data
        self.tintColor = tintColor
        self.secondaryTintColor = secondaryTintColor
        self.tertiaryTintColor = tertiaryTintColor
        self.backgroundColor = backgroundColor
        self.isCollapsed = isCollapsed
    }
}

private func displayLineFrame(frame: CGRect, isRTL: Bool, boundingRect: CGRect, cutout: TextNodeCutout?) -> CGRect {
    if frame.width.isEqual(to: boundingRect.width) {
        return frame
    }
    var lineFrame = frame
    let intersectionFrame = lineFrame.offsetBy(dx: 0.0, dy: 0.0)

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

public final class InteractiveTextNodeSegment {
    fileprivate let lines: [InteractiveTextNodeLine]
    public let visibleLineCount: Int
    fileprivate let tintColor: UIColor?
    fileprivate let secondaryTintColor: UIColor?
    fileprivate let tertiaryTintColor: UIColor?
    fileprivate let blockQuote: InteractiveTextNodeBlockQuote?
    public let hasRTL: Bool
    public let spoilers: [(NSRange, CGRect)]
    public let spoilerWords: [(NSRange, CGRect)]
    public let embeddedItems: [InteractiveTextNodeLayout.EmbeddedItem]
    
    public var hasBlockQuote: Bool {
        return self.blockQuote != nil
    }
    
    fileprivate init(
        lines: [InteractiveTextNodeLine],
        visibleLineCount: Int,
        tintColor: UIColor?,
        secondaryTintColor: UIColor?,
        tertiaryTintColor: UIColor?,
        blockQuote: InteractiveTextNodeBlockQuote?,
        attributedString: NSAttributedString?,
        resolvedAlignment: NSTextAlignment,
        layoutSize: CGSize
    ) {
        self.lines = lines
        self.visibleLineCount = visibleLineCount
        self.tintColor = tintColor
        self.secondaryTintColor = secondaryTintColor
        self.tertiaryTintColor = tertiaryTintColor
        self.blockQuote = blockQuote
        
        var hasRTL = false
        var spoilers: [(NSRange, CGRect)] = []
        var spoilerWords: [(NSRange, CGRect)] = []
        var embeddedItems: [InteractiveTextNodeLayout.EmbeddedItem] = []
        
        for line in self.lines {
            if line.isRTL {
                hasRTL = true
            }
            
            let lineFrame: CGRect
            switch resolvedAlignment {
            case .center:
                lineFrame = CGRect(origin: CGPoint(x: floor((layoutSize.width - line.frame.size.width) / 2.0), y: line.frame.minY), size: line.frame.size)
            case .right:
                lineFrame = CGRect(origin: CGPoint(x: layoutSize.width - line.frame.size.width, y: line.frame.minY), size: line.frame.size)
            default:
                lineFrame = displayLineFrame(frame: line.frame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: layoutSize), cutout: nil)
            }
            
            spoilers.append(contentsOf: line.spoilers.map { ( $0.range, $0.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)) })
            spoilerWords.append(contentsOf: line.spoilerWords.map { ( $0.range, $0.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)) })
            for embeddedItem in line.embeddedItems {
                var textColor: UIColor?
                if let attributedString, embeddedItem.range.location < attributedString.length {
                    if let color = attributedString.attribute(.foregroundColor, at: embeddedItem.range.location, effectiveRange: nil) as? UIColor {
                        textColor = color
                    }
                    if textColor == nil {
                        if let color = attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor {
                            textColor = color
                        }
                    }
                }
                embeddedItems.append(InteractiveTextNodeLayout.EmbeddedItem(range: embeddedItem.range, rect: embeddedItem.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY), value: embeddedItem.item, textColor: textColor ?? .black, isHiddenBySpoiler: embeddedItem.isHiddenBySpoiler))
            }
        }
        
        self.hasRTL = hasRTL
        self.spoilers = spoilers
        self.spoilerWords = spoilerWords
        self.embeddedItems = embeddedItems
    }
}

public final class InteractiveTextNodeLayoutArguments {
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
    public let displayContentsUnderSpoilers: Bool
    public let customTruncationToken: ((UIFont, Bool) -> NSAttributedString?)?
    public let expandedBlocks: Set<Int>
    
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
        displayContentsUnderSpoilers: Bool = false,
        customTruncationToken: ((UIFont, Bool) -> NSAttributedString?)? = nil,
        expandedBlocks: Set<Int> = Set()
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
        self.displayContentsUnderSpoilers = displayContentsUnderSpoilers
        self.customTruncationToken = customTruncationToken
        self.expandedBlocks = expandedBlocks
    }
    
    public func withAttributedString(_ attributedString: NSAttributedString?) -> InteractiveTextNodeLayoutArguments {
        return InteractiveTextNodeLayoutArguments(
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
            displayContentsUnderSpoilers: self.displayContentsUnderSpoilers,
            customTruncationToken: self.customTruncationToken,
            expandedBlocks: self.expandedBlocks
        )
    }
}

public final class InteractiveTextNodeLayout: NSObject {
    public final class EmbeddedItem: Equatable {
        public let range: NSRange
        public let rect: CGRect
        public let value: AnyHashable
        public let textColor: UIColor
        public let isHiddenBySpoiler: Bool
        
        public init(range: NSRange, rect: CGRect, value: AnyHashable, textColor: UIColor, isHiddenBySpoiler: Bool) {
            self.range = range
            self.rect = rect
            self.value = value
            self.textColor = textColor
            self.isHiddenBySpoiler = isHiddenBySpoiler
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
            if lhs.isHiddenBySpoiler != rhs.isHiddenBySpoiler {
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
    public let segments: [InteractiveTextNodeSegment]
    fileprivate let lineColor: UIColor?
    fileprivate let textShadowColor: UIColor?
    fileprivate let textShadowBlur: CGFloat?
    fileprivate let textStroke: (UIColor, CGFloat)?
    public let displayContentsUnderSpoilers: Bool
    fileprivate let expandedBlocks: Set<Int>
    
    fileprivate init(
        attributedString: NSAttributedString?,
        maximumNumberOfLines: Int,
        truncationType: CTLineTruncationType,
        constrainedSize: CGSize,
        explicitAlignment: NSTextAlignment,
        resolvedAlignment: NSTextAlignment,
        verticalAlignment: TextVerticalAlignment,
        lineSpacing: CGFloat,
        cutout: TextNodeCutout?,
        insets: UIEdgeInsets,
        size: CGSize,
        rawTextSize: CGSize,
        truncated: Bool,
        firstLineOffset: CGFloat,
        segments: [InteractiveTextNodeSegment],
        backgroundColor: UIColor?,
        lineColor: UIColor?,
        textShadowColor: UIColor?,
        textShadowBlur: CGFloat?,
        textStroke: (UIColor, CGFloat)?,
        displayContentsUnderSpoilers: Bool,
        expandedBlocks: Set<Int>
    ) {
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
        self.segments = segments
        self.backgroundColor = backgroundColor
        self.lineColor = lineColor
        self.textShadowColor = textShadowColor
        self.textShadowBlur = textShadowBlur
        self.textStroke = textStroke
        self.displayContentsUnderSpoilers = displayContentsUnderSpoilers
        self.expandedBlocks = expandedBlocks
    }
    
    func withUpdatedDisplayContentsUnderSpoilers(_ displayContentsUnderSpoilers: Bool) -> InteractiveTextNodeLayout {
        return InteractiveTextNodeLayout(
            attributedString: self.attributedString,
            maximumNumberOfLines: self.maximumNumberOfLines,
            truncationType: self.truncationType,
            constrainedSize: self.constrainedSize,
            explicitAlignment: self.explicitAlignment,
            resolvedAlignment: self.resolvedAlignment,
            verticalAlignment: self.verticalAlignment,
            lineSpacing: self.lineSpacing,
            cutout: self.cutout,
            insets: self.insets,
            size: self.size,
            rawTextSize: self.rawTextSize,
            truncated: self.truncated,
            firstLineOffset: self.firstLineOffset,
            segments: self.segments,
            backgroundColor: self.backgroundColor,
            lineColor: self.lineColor,
            textShadowColor: self.textShadowColor,
            textShadowBlur: self.textShadowBlur,
            textStroke: self.textStroke,
            displayContentsUnderSpoilers: displayContentsUnderSpoilers,
            expandedBlocks: self.expandedBlocks
        )
    }
    
    public var numberOfLines: Int {
        var result = 0
        for segment in self.segments {
            result += segment.lines.count
        }
        return result
    }
    
    public var trailingLineWidth: CGFloat {
        if let lastSegment = self.segments.last, let lastLine = lastSegment.lines.last {
            var width = lastLine.frame.maxX
            if let additionalTrailingLine = lastLine.additionalTrailingLine {
                width += additionalTrailingLine.1
            }
            
            if let blockQuote = lastSegment.blockQuote {
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
        if let lastSegment = self.segments.last, let lastLine = lastSegment.lines.last {
            return lastLine.isRTL
        } else {
            return false
        }
    }
    
    public func attributesAtPoint(_ point: CGPoint, orNearest: Bool) -> (Int, [NSAttributedString.Key: Any])? {
        if let attributedString = self.attributedString {
            let transformedPoint = CGPoint(x: point.x - self.insets.left, y: point.y - self.insets.top)
            if orNearest {
                var segmentIndex = -1
                var closestLine: ((segment: Int, line: Int), CGRect, CGFloat)?
                for segment in self.segments {
                    segmentIndex += 1
                    var lineIndex = -1
                    for line in segment.lines.prefix(segment.visibleLineCount) {
                        lineIndex += 1
                        var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
                        switch self.resolvedAlignment {
                        case .center:
                            lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                        case .natural, .left:
                            lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                        case .right:
                            lineFrame.origin.x = self.size.width - lineFrame.size.width
                        default:
                            break
                        }
                        
                        let currentDistance = (lineFrame.center.y - point.y) * (lineFrame.center.y - point.y)
                        if let current = closestLine {
                            if current.2 > currentDistance {
                                closestLine = ((segmentIndex, lineIndex), lineFrame, currentDistance)
                            }
                        } else {
                            closestLine = ((segmentIndex, lineIndex), lineFrame, currentDistance)
                        }
                    }
                }
                
                if let (index, lineFrame, _) = closestLine {
                    let line = self.segments[index.segment].lines[index.line]
                    
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
            var segmentIndex = -1
            for segment in self.segments {
                segmentIndex += 1
                var lineIndex = -1
                for line in segment.lines.prefix(segment.visibleLineCount) {
                    lineIndex += 1
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
                    switch self.resolvedAlignment {
                    case .center:
                        lineFrame.origin.x = floor((self.size.width - lineFrame.size.width) / 2.0)
                    case .natural, .left:
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
            }
            
            segmentIndex = -1
            for segment in self.segments {
                segmentIndex += 1
                var lineIndex = -1
                for line in segment.lines.prefix(segment.visibleLineCount) {
                    lineIndex += 1
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
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
        }
        return nil
    }
    
    public func linesRects() -> [CGRect] {
        var rects: [CGRect] = []
        for segment in self.segments {
            for line in segment.lines.prefix(segment.visibleLineCount) {
                rects.append(line.frame)
            }
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
            for segment in self.segments {
                for line in segment.lines.prefix(segment.visibleLineCount) {
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
                        var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
                        lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                        
                        let width = abs(rightOffset - leftOffset)
                        rects.append(CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset) + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: width, height: lineFrame.size.height)))
                    }
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
                for segment in self.segments {
                    for line in segment.lines.prefix(segment.visibleLineCount) {
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
                            
                            var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
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
        }
        return result
    }
    
    public func lineAndAttributeRects(name: String, at index: Int) -> [(CGRect, CGRect)]? {
        if let attributedString = self.attributedString {
            var range = NSRange()
            let _ = attributedString.attribute(NSAttributedString.Key(rawValue: name), at: index, effectiveRange: &range)
            if range.length != 0 {
                var rects: [(CGRect, CGRect)] = []
                for segment in self.segments {
                    for line in segment.lines.prefix(segment.visibleLineCount) {
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
                            var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
                            
                            lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: self.size), cutout: self.cutout)
                            
                            let width = abs(rightOffset - leftOffset)
                            if width > 1.0 {
                                rects.append((lineFrame, CGRect(origin: CGPoint(x: lineFrame.minX + min(leftOffset, rightOffset) + self.insets.left, y: lineFrame.minY + self.insets.top), size: CGSize(width: width, height: lineFrame.size.height))))
                            }
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
        for segment in self.segments {
            for line in segment.lines.prefix(segment.visibleLineCount) {
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
                    var lineFrame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: line.frame.origin.y), size: line.frame.size)
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

private func addSpoiler(line: InteractiveTextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int) {
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
    
    line.spoilers.append(InteractiveTextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: 0.0, width: abs(rightOffset - leftOffset), height: ascent + descent)))
}

private func addSpoilerWord(line: InteractiveTextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
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
    
    line.spoilerWords.append(InteractiveTextNodeSpoiler(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: 0.0, width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent)))
}

private func addEmbeddedItem(item: AnyHashable, isHiddenBySpoiler: Bool, line: InteractiveTextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
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
    
    line.embeddedItems.append(InteractiveTextNodeEmbeddedItem(range: NSMakeRange(startIndex, endIndex - startIndex + 1), frame: CGRect(x: min(leftOffset, rightOffset), y: 0.0, width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent), item: item, isHiddenBySpoiler: isHiddenBySpoiler))
}

private func addAttachment(attachment: UIImage, line: InteractiveTextNodeLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
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
    
    line.attachments.append(InteractiveTextNodeAttachment(range: NSMakeRange(startIndex, endIndex - startIndex), frame: CGRect(x: min(leftOffset, rightOffset), y: descent - (ascent + descent), width: abs(rightOffset - leftOffset) + rightInset, height: ascent + descent), attachment: attachment))
}

open class InteractiveTextNode: ASDisplayNode, TextNodeProtocol, UIGestureRecognizerDelegate {
    public final class ApplyArguments {
        public let animation: ListViewItemUpdateAnimation
        public let spoilerTextColor: UIColor
        public let spoilerEffectColor: UIColor
        public let areContentAnimationsEnabled: Bool
        public let spoilerExpandRect: CGRect?
        public var crossfadeContents: ((UIView) -> Void)?
        
        public init(
            animation: ListViewItemUpdateAnimation,
            spoilerTextColor: UIColor,
            spoilerEffectColor: UIColor,
            areContentAnimationsEnabled: Bool,
            spoilerExpandRect: CGRect?,
            crossfadeContents: ((UIView) -> Void)? = nil
        ) {
            self.animation = animation
            self.spoilerTextColor = spoilerTextColor
            self.spoilerEffectColor = spoilerEffectColor
            self.areContentAnimationsEnabled = areContentAnimationsEnabled
            self.spoilerExpandRect = spoilerExpandRect
            self.crossfadeContents = crossfadeContents
        }
    }
    
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
        let cachedLayout: InteractiveTextNodeLayout?
        let renderContentTypes: RenderContentTypes
        
        init(cachedLayout: InteractiveTextNodeLayout?, renderContentTypes: RenderContentTypes) {
            self.cachedLayout = cachedLayout
            self.renderContentTypes = renderContentTypes
            
            super.init()
        }
    }
    
    public internal(set) var cachedLayout: InteractiveTextNodeLayout?
    public var renderContentTypes: RenderContentTypes = .all
    private var contentItemLayers: [Int: TextContentItemLayer] = [:]
    
    private var isDisplayingContentsUnderSpoilers: Bool?
    
    public var canHandleTapAtPoint: ((CGPoint) -> Bool)?
    public var requestToggleBlockCollapsed: ((Int) -> Void)?
    public var requestDisplayContentsUnderSpoilers: ((CGPoint?) -> Void)?
    private var tapRecognizer: UITapGestureRecognizer?
    
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
    
    public func collapsibleBlockAtPoint(_ point: CGPoint) -> Int? {
        for (_, contentItemLayer) in self.contentItemLayers {
            if !contentItemLayer.frame.contains(point) {
                continue
            }
            if !contentItemLayer.renderNode.frame.offsetBy(dx: contentItemLayer.frame.minX, dy: contentItemLayer.frame.minY).contains(point) {
                continue
            }
            
            guard let params = contentItemLayer.params else {
                continue
            }
            guard let blockQuote = params.item.segment.blockQuote else {
                continue
            }
            if blockQuote.isCollapsed == nil {
                continue
            }
            
            return blockQuote.id
        }
        return nil
    }
    
    func segmentLayer(index: Int) -> TextContentItemLayer? {
        return self.contentItemLayers[index]
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let canHandleTapAtPoint = self.canHandleTapAtPoint else {
            return nil
        }
        if !canHandleTapAtPoint(point) {
            return nil
        }
        
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        return result
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
        displayContentsUnderSpoilers: Bool,
        customTruncationToken: ((UIFont, Bool) -> NSAttributedString?)?,
        expandedBlocks: Set<Int>
    ) -> InteractiveTextNodeLayout {
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
        
        class CalculatedSegment {
            let id: Int?
            var titleLine: InteractiveTextNodeLine?
            var lines: [InteractiveTextNodeLine] = []
            var tintColor: UIColor?
            var secondaryTintColor: UIColor?
            var tertiaryTintColor: UIColor?
            var blockQuote: TextNodeBlockQuoteData?
            var additionalWidth: CGFloat = 0.0
            
            init(id: Int?) {
                self.id = id
            }
        }
        
        var calculatedSegments: [CalculatedSegment] = []
        var remainingLines = maximumNumberOfLines <= 0 ? Int.max : maximumNumberOfLines
        
        var nextBlockIndex = 0
        for segment in stringSegments {
            if remainingLines <= 0 {
                break
            }
            
            var blockIndex: Int?
            var isCollapsed = false
            if let blockQuote = segment.blockQuote {
                let blockIndexValue = nextBlockIndex
                blockIndex = blockIndexValue
                nextBlockIndex += 1
                if blockQuote.isCollapsible {
                    isCollapsed = !expandedBlocks.contains(blockIndexValue)
                }
            }
            
            let rawSubstring = segment.substring.string as NSString
            let substringLength = rawSubstring.length
            
            let segmentTypesetterString = attributedString.attributedSubstring(from: NSRange(location: 0, length: segment.firstCharacterOffset + substringLength))
            let typesetter = CTTypesetterCreateWithAttributedString(segmentTypesetterString as CFAttributedString)
            
            var currentLineStartIndex = segment.firstCharacterOffset
            let segmentEndIndex = segment.firstCharacterOffset + substringLength
            
            let calculatedSegment = CalculatedSegment(id: blockIndex)
            calculatedSegment.blockQuote = segment.blockQuote
            calculatedSegment.tintColor = segment.tintColor
            calculatedSegment.secondaryTintColor = segment.secondaryTintColor
            calculatedSegment.tertiaryTintColor = segment.tertiaryTintColor
            
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
                let constrainedLineWidth = constrainedSegmentWidth - additionalSegmentRightInset
                if let titleLine = CTLineCreateTruncatedLine(rawTitleLine, constrainedLineWidth, .end, nil) {
                    var lineAscent: CGFloat = 0.0
                    var lineDescent: CGFloat = 0.0
                    let lineWidth = CTLineGetTypographicBounds(titleLine, &lineAscent, &lineDescent, nil)
                    calculatedSegment.titleLine = InteractiveTextNodeLine(
                        line: titleLine,
                        constrainedWidth: constrainedLineWidth,
                        frame: CGRect(origin: CGPoint(x: additionalOffsetX, y: 0.0), size: CGSize(width: lineWidth + additionalSegmentRightInset, height: lineAscent + lineDescent)),
                        intrinsicWidth: lineWidth,
                        ascent: lineAscent,
                        descent: lineDescent,
                        range: nil,
                        isTruncated: false,
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
                let constrainedLineWidth = constrainedSegmentWidth - additionalSegmentRightInset
                let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, currentLineStartIndex, constrainedLineWidth)
                
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
                    
                    calculatedSegment.lines.append(InteractiveTextNodeLine(
                        line: line,
                        constrainedWidth: constrainedLineWidth,
                        frame: CGRect(origin: CGPoint(x: additionalOffsetX, y: 0.0), size: CGSize(width: lineWidth + additionalSegmentRightInset, height: lineAscent + lineDescent)),
                        intrinsicWidth: lineWidth,
                        ascent: lineAscent,
                        descent: lineDescent,
                        range: NSRange(location: currentLineStartIndex, length: lineCharacterCount),
                        isTruncated: false,
                        isRTL: isRTL && segment.blockQuote == nil,
                        strikethroughs: [],
                        underlines: [],
                        spoilers: [],
                        spoilerWords: [],
                        embeddedItems: [],
                        attachments: [],
                        additionalTrailingLine: nil
                    ))
                    
                    remainingLines -= 1
                    if remainingLines <= 0 {
                        break
                    }
                }
                
                additionalSegmentRightInset = 0.0
                
                currentLineStartIndex += lineCharacterCount
                
                if currentLineStartIndex >= segmentEndIndex {
                    break
                }
                if remainingLines <= 0 {
                    break
                }
            }
            
            if isCollapsed, calculatedSegment.lines.count > 3 {
                let lastLine = calculatedSegment.lines[2]
                if !lastLine.isTruncated, let lineRange = lastLine.range, let lineFont = attributedString.attribute(.font, at: lineRange.lowerBound, effectiveRange: nil) as? UIFont {
                    var truncationTokenAttributes: [NSAttributedString.Key : AnyObject] = [:]
                    truncationTokenAttributes[NSAttributedString.Key.font] = lineFont
                    truncationTokenAttributes[NSAttributedString.Key(rawValue:  kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                    let tokenString = "\u{2026}"
                    
                    let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                    
                    let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                    
                    var truncationTokenAscent: CGFloat = 0.0
                    var truncationTokenDescent: CGFloat = 0.0
                    let truncationTokenWidth = CTLineGetTypographicBounds(truncationToken, &truncationTokenAscent, &truncationTokenDescent, nil)
                    
                    if let updatedLine = CTLineCreateTruncatedLine(lastLine.line, max(0.0, lastLine.constrainedWidth - truncationTokenWidth), .end, nil) {
                        var lineAscent: CGFloat = 0.0
                        var lineDescent: CGFloat = 0.0
                        var lineWidth = CTLineGetTypographicBounds(updatedLine, &lineAscent, &lineDescent, nil)
                        lineWidth = min(lineWidth, lastLine.constrainedWidth)
                        
                        calculatedSegment.lines[2] = InteractiveTextNodeLine(
                            line: updatedLine,
                            constrainedWidth: lastLine.constrainedWidth,
                            frame: CGRect(origin: lastLine.frame.origin, size: CGSize(width: lineWidth, height: lineAscent + lineDescent)),
                            intrinsicWidth: lineWidth,
                            ascent: lineAscent,
                            descent: lineDescent,
                            range: lastLine.range,
                            isTruncated: true,
                            isRTL: lastLine.isRTL,
                            strikethroughs: [],
                            underlines: [],
                            spoilers: [],
                            spoilerWords: [],
                            embeddedItems: [],
                            attachments: [],
                            additionalTrailingLine: (truncationToken, 0.0)
                        )
                    }
                }
            }
            
            calculatedSegments.append(calculatedSegment)
        }
        
        if remainingLines <= 0, let lastSegment = calculatedSegments.last, let lastLine = lastSegment.lines.last, !lastLine.isTruncated, let lineRange = lastLine.range, let lineFont = attributedString.attribute(.font, at: lineRange.lowerBound, effectiveRange: nil) as? UIFont {
            if let range = lastLine.range, range.upperBound != attributedString.length {
                let truncatedTokenString: NSAttributedString
                if let customTruncationTokenValue = customTruncationToken?(lineFont, lastSegment.blockQuote != nil) {
                    if lineRange.length == 0 && customTruncationTokenValue.string.hasPrefix("\u{2026} ") {
                        truncatedTokenString = customTruncationTokenValue.attributedSubstring(from: NSRange(location: 2, length: customTruncationTokenValue.length - 2))
                    } else {
                        truncatedTokenString = customTruncationTokenValue
                    }
                } else {
                    var truncationTokenAttributes: [NSAttributedString.Key : AnyObject] = [:]
                    truncationTokenAttributes[NSAttributedString.Key.font] = lineFont
                    truncationTokenAttributes[NSAttributedString.Key(rawValue:  kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                    let tokenString = "\u{2026}"
                    
                    truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                }
                
                let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                
                var truncationTokenAscent: CGFloat = 0.0
                var truncationTokenDescent: CGFloat = 0.0
                let truncationTokenWidth = CTLineGetTypographicBounds(truncationToken, &truncationTokenAscent, &truncationTokenDescent, nil)
                
                if let updatedLine = CTLineCreateTruncatedLine(lastLine.line, max(0.0, lastLine.constrainedWidth - truncationTokenWidth), .end, nil) {
                    var lineAscent: CGFloat = 0.0
                    var lineDescent: CGFloat = 0.0
                    var lineWidth = CTLineGetTypographicBounds(updatedLine, &lineAscent, &lineDescent, nil)
                    lineWidth = min(lineWidth, lastLine.constrainedWidth)
                    
                    lastSegment.lines[lastSegment.lines.count - 1] = InteractiveTextNodeLine(
                        line: updatedLine,
                        constrainedWidth: lastLine.constrainedWidth,
                        frame: CGRect(origin: lastLine.frame.origin, size: CGSize(width: lineWidth, height: lineAscent + lineDescent)),
                        intrinsicWidth: lineWidth,
                        ascent: lineAscent,
                        descent: lineDescent,
                        range: lastLine.range,
                        isTruncated: true,
                        isRTL: lastLine.isRTL,
                        strikethroughs: [],
                        underlines: [],
                        spoilers: [],
                        spoilerWords: [],
                        embeddedItems: [],
                        attachments: [],
                        additionalTrailingLine: (truncationToken, truncationTokenWidth)
                    )
                }
            }
        }
        
        var size = CGSize()
        let isTruncated = false
        
        for segment in calculatedSegments {
            if let titleLine = segment.titleLine {
                size.width = max(size.width, titleLine.frame.origin.x + titleLine.frame.width + segment.additionalWidth)
            }
            for line in segment.lines {
                var additionalTrailingWidth: CGFloat = 0.0
                if let additionalTrailingLine = line.additionalTrailingLine {
                    additionalTrailingWidth += CTLineGetTypographicBounds(additionalTrailingLine.0, nil, nil, nil)
                }
                size.width = max(size.width, line.frame.origin.x + line.frame.width + segment.additionalWidth + additionalTrailingWidth)
            }
        }
        
        var segments: [InteractiveTextNodeSegment] = []
        
        var firstLineOffset: CGFloat?
        
        for i in 0 ..< calculatedSegments.count {
            var segmentLines: [InteractiveTextNodeLine] = []
            
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
            
            let blockMinY = size.height
            var blockWidth: CGFloat = 0.0
            
            if let titleLine = segment.titleLine {
                titleLine.frame = CGRect(origin: CGPoint(x: titleLine.frame.origin.x, y: size.height), size: titleLine.frame.size)
                titleLine.frame.size.width += max(0.0, segment.additionalWidth - 2.0)
                size.height += titleLine.frame.height + titleLine.frame.height * lineSpacingFactor
                blockWidth = max(blockWidth, titleLine.frame.origin.x + titleLine.frame.width)
                
                segmentLines.append(titleLine)
            }
            
            let blockIndex = segment.id
            var isCollapsed = false
            if let blockIndex, let blockQuote = segment.blockQuote {
                if blockQuote.isCollapsible {
                    isCollapsed = !expandedBlocks.contains(blockIndex)
                }
            }
            
            var lineCount = 0
            var visibleLineCount = 0
            var segmentHeight: CGFloat = 0.0
            var effectiveSegmentHeight: CGFloat = 0.0
            for i in 0 ..< segment.lines.count {
                let line = segment.lines[i]
                lineCount += 1
                
                if i != 0 {
                    segmentHeight += line.frame.height * lineSpacingFactor
                }
                if isCollapsed && lineCount > 3 {
                } else {
                    effectiveSegmentHeight += line.frame.height * lineSpacingFactor
                }
                
                line.frame = CGRect(origin: CGPoint(x: line.frame.origin.x, y: size.height + segmentHeight), size: line.frame.size)
                line.frame.size.width += max(0.0, segment.additionalWidth)
                
                segmentHeight += line.frame.height
                if isCollapsed && lineCount > 3 {
                } else {
                    effectiveSegmentHeight += line.frame.height
                    visibleLineCount = i + 1
                }
                var additionalTrailingWidth: CGFloat = 0.0
                if let additionalTrailingLine = line.additionalTrailingLine {
                    additionalTrailingWidth += CTLineGetTypographicBounds(additionalTrailingLine.0, nil, nil, nil)
                }
                blockWidth = max(blockWidth, line.frame.origin.x + line.frame.width + additionalTrailingWidth)
                
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
                            line.strikethroughs.append(InteractiveTextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: line.frame.height)))
                        } else if let _ = attributes[NSAttributedString.Key.underlineStyle] {
                            let lowerX = floor(CTLineGetOffsetForStringIndex(line.line, range.location, nil))
                            let upperX = ceil(CTLineGetOffsetForStringIndex(line.line, range.location + range.length, nil))
                            let x = lowerX < upperX ? lowerX : upperX
                            line.underlines.append(InteractiveTextNodeStrikethrough(range: range, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: line.frame.height)))
                        }
                        
                        if let embeddedItem = (attributes[NSAttributedString.Key(rawValue: "TelegramEmbeddedItem")] as? AnyHashable ?? attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable) {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(line.line, &ascent, &descent, nil)
                            
                            var isHiddenBySpoiler = attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil
                            if displayContentsUnderSpoilers {
                                isHiddenBySpoiler = false
                            }
                            
                            addEmbeddedItem(item: embeddedItem, isHiddenBySpoiler: isHiddenBySpoiler, line: line, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                        }
                        
                        if let attachment = attributes[NSAttributedString.Key.attachment] as? UIImage {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(line.line, &ascent, &descent, nil)
                            
                            addAttachment(attachment: attachment, line: line, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                        }
                    }
                }
                
                segmentLines.append(line)
                
                if firstLineOffset == nil, let firstLine = segmentLines.first {
                    firstLineOffset = firstLine.descent
                }
            }
            
            if !isCollapsed, let blockQuote = segment.blockQuote, blockQuote.isCollapsible, !segment.lines.isEmpty {
                let lastLine = segment.lines[segment.lines.count - 1]
                if lastLine.frame.maxX + 16.0 <= constrainedSize.width {
                    lastLine.frame.size.width += 16.0
                    blockWidth = max(blockWidth, lastLine.frame.maxX)
                } else {
                    segmentHeight += 10.0
                    effectiveSegmentHeight += 10.0
                }
            }
            
            segmentHeight = ceil(segmentHeight)
            effectiveSegmentHeight = ceil(effectiveSegmentHeight)
            
            size.height += effectiveSegmentHeight
            let blockMaxY = size.height
            
            if i != calculatedSegments.count - 1 {
                if segment.blockQuote != nil {
                    size.height += 8.0
                }
            } else {
                if segment.blockQuote != nil {
                    size.height += 6.0
                }
            }
            
            var segmentBlockQuote: InteractiveTextNodeBlockQuote?
            if let blockQuote = segment.blockQuote, let tintColor = segment.tintColor, let blockIndex, let firstLine = segment.lines.first, let lastLine = segment.lines.last {
                segmentBlockQuote = InteractiveTextNodeBlockQuote(
                    id: blockIndex,
                    frame: CGRect(
                        origin: CGPoint(x: 0.0, y: blockMinY - floor(firstLine.frame.height * 0.2)),
                        size: CGSize(width: blockWidth, height: blockMaxY - blockMinY + floor(firstLine.frame.height * 0.2) + floor(lastLine.frame.height * 0.15))
                    ),
                    data: blockQuote,
                    tintColor: tintColor,
                    secondaryTintColor: segment.secondaryTintColor,
                    tertiaryTintColor: segment.tertiaryTintColor,
                    backgroundColor: blockQuote.backgroundColor,
                    isCollapsed: (blockQuote.isCollapsible && segmentLines.count > 3) ? isCollapsed : nil
                )
            }
            
            segments.append(InteractiveTextNodeSegment(
                lines: segmentLines,
                visibleLineCount: visibleLineCount,
                tintColor: segment.tintColor,
                secondaryTintColor: segment.secondaryTintColor,
                tertiaryTintColor: segment.tertiaryTintColor,
                blockQuote: segmentBlockQuote,
                attributedString: attributedString,
                resolvedAlignment: alignment,
                layoutSize: size
            ))
        }
        
        size.width = ceil(size.width)
        size.height = ceil(size.height)
        
        let rawTextSize = size
        size.width += insets.left + insets.right
        size.height += insets.top + insets.bottom
        
        return InteractiveTextNodeLayout(
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
            firstLineOffset: firstLineOffset ?? 0.0,
            segments: segments,
            backgroundColor: backgroundColor,
            lineColor: lineColor,
            textShadowColor: textShadowColor,
            textShadowBlur: textShadowBlur,
            textStroke: textStroke,
            displayContentsUnderSpoilers: displayContentsUnderSpoilers,
            expandedBlocks: expandedBlocks
        )
    }
    
    static func calculateLayout(attributedString: NSAttributedString?, minimumNumberOfLines: Int, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: UIColor?, constrainedSize: CGSize, alignment: NSTextAlignment, verticalAlignment: TextVerticalAlignment, lineSpacingFactor: CGFloat, cutout: TextNodeCutout?, insets: UIEdgeInsets, lineColor: UIColor?, textShadowColor: UIColor?, textShadowBlur: CGFloat?, textStroke: (UIColor, CGFloat)?, displayContentsUnderSpoilers: Bool, customTruncationToken: ((UIFont, Bool) -> NSAttributedString?)?, expandedBlocks: Set<Int>) -> InteractiveTextNodeLayout {
        guard let attributedString else {
            return InteractiveTextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, explicitAlignment: alignment, resolvedAlignment: alignment, verticalAlignment: verticalAlignment, lineSpacing: lineSpacingFactor, cutout: cutout, insets: insets, size: CGSize(), rawTextSize: CGSize(), truncated: false, firstLineOffset: 0.0, segments: [], backgroundColor: backgroundColor, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displayContentsUnderSpoilers: displayContentsUnderSpoilers, expandedBlocks: expandedBlocks)
        }
        
        return calculateLayoutV2(attributedString: attributedString, minimumNumberOfLines: minimumNumberOfLines, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, alignment: alignment, verticalAlignment: verticalAlignment, lineSpacingFactor: lineSpacingFactor, cutout: cutout, insets: insets, lineColor: lineColor, textShadowColor: textShadowColor, textShadowBlur: textShadowBlur, textStroke: textStroke, displayContentsUnderSpoilers: displayContentsUnderSpoilers, customTruncationToken: customTruncationToken, expandedBlocks: expandedBlocks)
    }
    
    private func updateContentItems(arguments: ApplyArguments) {
        guard let cachedLayout = self.cachedLayout else {
            return
        }
        
        let animateContents = self.isDisplayingContentsUnderSpoilers != nil && self.isDisplayingContentsUnderSpoilers != cachedLayout.displayContentsUnderSpoilers && arguments.animation.isAnimated
        let synchronous = animateContents
        self.isDisplayingContentsUnderSpoilers = cachedLayout.displayContentsUnderSpoilers
        
        let topLeftOffset = CGPoint(x: cachedLayout.insets.left, y: cachedLayout.insets.top)
        
        var validIds: [Int] = []
        var nextItemId = 0
        for segment in cachedLayout.segments {
            let itemId = nextItemId
            nextItemId += 1
            
            var segmentRect = CGRect()
            for line in segment.lines {
                var lineRect = line.frame
                lineRect.origin.y = topLeftOffset.y + line.frame.minY
                lineRect.origin.x = topLeftOffset.x + line.frame.minX
                
                if let additionalTrailingLine = line.additionalTrailingLine {
                    lineRect.size.width += CTLineGetTypographicBounds(additionalTrailingLine.0, nil, nil, nil)
                }
                
                if segmentRect.isEmpty {
                    segmentRect = lineRect
                } else {
                    segmentRect = segmentRect.union(lineRect)
                }
            }
            
            segmentRect.size.width += cachedLayout.insets.left + cachedLayout.insets.right
            segmentRect.origin.x -= cachedLayout.insets.left
            segmentRect.size.height += cachedLayout.insets.top + cachedLayout.insets.bottom
            segmentRect.origin.y -= cachedLayout.insets.top
            
            segmentRect = segmentRect.integral
            
            let contentItem = TextContentItem(
                id: itemId,
                size: segmentRect.size,
                attributedString: cachedLayout.attributedString,
                textShadowColor: cachedLayout.textShadowColor,
                textShadowBlur: cachedLayout.textShadowBlur,
                textStroke: cachedLayout.textStroke,
                contentOffset: CGPoint(x: -segmentRect.minX + topLeftOffset.x, y: -segmentRect.minY + topLeftOffset.y),
                segment: segment,
                displayContentsUnderSpoilers: cachedLayout.displayContentsUnderSpoilers
            )
            validIds.append(contentItem.id)
            
            let contentItemFrame = CGRect(origin: CGPoint(x: segmentRect.minX, y: segmentRect.minY), size: CGSize(width: contentItem.size.width, height: contentItem.size.height))
            
            var contentItemAnimation = arguments.animation
            let contentItemLayer: TextContentItemLayer
            var itemSpoilerExpandRect: CGRect?
            var itemAnimateContents = animateContents && contentItemAnimation.isAnimated
            if let current = self.contentItemLayers[itemId] {
                contentItemLayer = current
                
                if arguments.animation.isAnimated, let spoilerExpandRect = arguments.spoilerExpandRect {
                    itemSpoilerExpandRect = spoilerExpandRect.offsetBy(dx: -contentItemFrame.minX, dy: -contentItemFrame.minY)
                    itemAnimateContents = true
                }
            } else {
                contentItemAnimation = .None
                contentItemLayer = TextContentItemLayer(displaysAsynchronously: self.displaysAsynchronously)
                self.contentItemLayers[contentItem.id] = contentItemLayer
                self.layer.addSublayer(contentItemLayer)
            }
            
            contentItemLayer.update(
                params: TextContentItemLayer.Params(
                    item: contentItem,
                    spoilerTextColor: arguments.spoilerTextColor,
                    spoilerEffectColor: arguments.spoilerEffectColor,
                    areContentAnimationsEnabled: arguments.areContentAnimationsEnabled
                ),
                animation: contentItemAnimation,
                synchronously: synchronous,
                animateContents: itemAnimateContents,
                spoilerExpandRect: itemSpoilerExpandRect
            )
            
            contentItemAnimation.animator.updateFrame(layer: contentItemLayer, frame: contentItemFrame, completion: nil)
        }
        var removedIds: [Int] = []
        for (id, contentItemLayer) in self.contentItemLayers {
            if !validIds.contains(id) {
                removedIds.append(id)
                contentItemLayer.removeFromSuperlayer()
            }
        }
        for id in removedIds {
            self.contentItemLayers.removeValue(forKey: id)
        }
        
        if !self.contentItemLayers.isEmpty {
            if self.tapRecognizer == nil {
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGesture(_:)))
                self.tapRecognizer = tapRecognizer
                self.view.addGestureRecognizer(tapRecognizer)
                tapRecognizer.delegate = self
            }
        } else if let tapRecognizer = self.tapRecognizer {
            self.tapRecognizer = nil
            self.view.removeGestureRecognizer(tapRecognizer)
        }
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: self.view)
            if let cachedLayout = self.cachedLayout, !cachedLayout.displayContentsUnderSpoilers, let (_, attributes) = self.attributesAtPoint(point) {
                if attributes[NSAttributedString.Key(rawValue: "Attribute__Spoiler")] != nil || attributes[NSAttributedString.Key(rawValue: "TelegramSpoiler")] != nil {
                    self.requestDisplayContentsUnderSpoilers?(point)
                    return
                }
            }
            if let blockId = self.collapsibleBlockAtPoint(point) {
                self.requestToggleBlockCollapsed?(blockId)
            }
        }
    }
    
    public static func asyncLayout(_ maybeNode: InteractiveTextNode?) -> (InteractiveTextNodeLayoutArguments) -> (InteractiveTextNodeLayout, (ApplyArguments) -> InteractiveTextNode) {
        let existingLayout: InteractiveTextNodeLayout? = maybeNode?.cachedLayout
        
        return { arguments in
            var layout: InteractiveTextNodeLayout
            
            if let existingLayout = existingLayout, existingLayout.constrainedSize == arguments.constrainedSize && existingLayout.maximumNumberOfLines == arguments.maximumNumberOfLines && existingLayout.truncationType == arguments.truncationType && existingLayout.cutout == arguments.cutout && existingLayout.explicitAlignment == arguments.alignment && existingLayout.lineSpacing.isEqual(to: arguments.lineSpacing) && existingLayout.expandedBlocks == arguments.expandedBlocks {
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
                    if layout.displayContentsUnderSpoilers != arguments.displayContentsUnderSpoilers {
                        layout = layout.withUpdatedDisplayContentsUnderSpoilers(arguments.displayContentsUnderSpoilers)
                    }
                } else {
                    layout = InteractiveTextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textShadowBlur: arguments.textShadowBlur, textStroke: arguments.textStroke, displayContentsUnderSpoilers: arguments.displayContentsUnderSpoilers, customTruncationToken: arguments.customTruncationToken, expandedBlocks: arguments.expandedBlocks)
                }
            } else {
                layout = InteractiveTextNode.calculateLayout(attributedString: arguments.attributedString, minimumNumberOfLines: arguments.minimumNumberOfLines, maximumNumberOfLines: arguments.maximumNumberOfLines, truncationType: arguments.truncationType, backgroundColor: arguments.backgroundColor, constrainedSize: arguments.constrainedSize, alignment: arguments.alignment, verticalAlignment: arguments.verticalAlignment, lineSpacingFactor: arguments.lineSpacing, cutout: arguments.cutout, insets: arguments.insets, lineColor: arguments.lineColor, textShadowColor: arguments.textShadowColor, textShadowBlur: arguments.textShadowBlur, textStroke: arguments.textStroke, displayContentsUnderSpoilers: arguments.displayContentsUnderSpoilers, customTruncationToken: arguments.customTruncationToken, expandedBlocks: arguments.expandedBlocks)
            }
            
            let node = maybeNode ?? InteractiveTextNode()
            
            return (layout, { arguments in
                if node.cachedLayout !== layout {
                    node.cachedLayout = layout
                    node.updateContentItems(arguments: arguments)
                }
                
                return node
            })
        }
    }
}

final class TextContentItem {
    let id: Int
    let size: CGSize
    let attributedString: NSAttributedString?
    let textShadowColor: UIColor?
    let textShadowBlur: CGFloat?
    let textStroke: (UIColor, CGFloat)?
    let contentOffset: CGPoint
    let segment: InteractiveTextNodeSegment
    let displayContentsUnderSpoilers: Bool
    
    init(
        id: Int,
        size: CGSize,
        attributedString: NSAttributedString?,
        textShadowColor: UIColor?,
        textShadowBlur: CGFloat?,
        textStroke: (UIColor, CGFloat)?,
        contentOffset: CGPoint,
        segment: InteractiveTextNodeSegment,
        displayContentsUnderSpoilers: Bool
    ) {
        self.id = id
        self.size = size
        self.attributedString = attributedString
        self.textShadowColor = textShadowColor
        self.textShadowBlur = textShadowBlur
        self.textStroke = textStroke
        self.contentOffset = contentOffset
        self.segment = segment
        self.displayContentsUnderSpoilers = displayContentsUnderSpoilers
    }
}

private let drawUnderlinesManually: Bool = {
    if #available(iOS 18.0, *) {
        return true
    } else {
        return false
    }
}()

final class TextContentItemLayer: SimpleLayer {
    final class Params {
        let item: TextContentItem
        let spoilerTextColor: UIColor
        let spoilerEffectColor: UIColor
        let areContentAnimationsEnabled: Bool
        
        init(
            item: TextContentItem,
            spoilerTextColor: UIColor,
            spoilerEffectColor: UIColor,
            areContentAnimationsEnabled: Bool
        ) {
            self.item = item
            self.spoilerTextColor = spoilerTextColor
            self.spoilerEffectColor = spoilerEffectColor
            self.areContentAnimationsEnabled = areContentAnimationsEnabled
        }
    }
    
    final class RenderMask {
        let image: UIImage
        let isOpaque: Bool
        let frame: CGRect
        
        init(image: UIImage, isOpaque: Bool, frame: CGRect) {
            self.image = image
            self.isOpaque = isOpaque
            self.frame = frame
        }
    }
    
    fileprivate final class RenderParams: NSObject {
        let size: CGSize
        let item: TextContentItem
        let mask: RenderMask?
        
        init(size: CGSize, item: TextContentItem, mask: RenderMask?) {
            self.size = size
            self.item = item
            self.mask = mask
            
            super.init()
        }
    }
    
    final class RenderNode: ASDisplayNode {
        fileprivate var params: RenderParams?
        
        override init() {
            super.init()
            
            self.isOpaque = false
            self.backgroundColor = nil
            self.layer.masksToBounds = true
            self.layer.contentsGravity = .bottomLeft
            self.layer.contentsScale = UIScreenScale
        }
        
        override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
            return self.params
        }
        
        @objc override static func display(withParameters parameters: Any?, isCancelled isCancelledBlock: () -> Bool) -> UIImage? {
            guard let params = parameters as? RenderParams else {
                return nil
            }
            if isCancelledBlock() {
                return nil
            }
            guard let renderingContext = DrawingContext(size: params.size, opaque: false, clear: true) else {
                return nil
            }
            
            renderingContext.withContext { context in
                UIGraphicsPushContext(context)
                defer {
                    UIGraphicsPopContext()
                }
                
                if let mask = params.mask {
                    context.clip(to: [mask.frame])
                }
                
                context.saveGState()
                
                context.setAllowsAntialiasing(true)
                
                context.setAllowsFontSmoothing(false)
                context.setShouldSmoothFonts(false)
                
                context.setAllowsFontSubpixelPositioning(false)
                context.setShouldSubpixelPositionFonts(false)
                
                context.setAllowsFontSubpixelQuantization(true)
                context.setShouldSubpixelQuantizeFonts(true)
                
                if let textShadowColor = params.item.textShadowColor {
                    context.setTextDrawingMode(.fill)
                    context.setShadow(offset: params.item.textShadowBlur != nil ? .zero : CGSize(width: 0.0, height: 1.0), blur: params.item.textShadowBlur ?? 0.0, color: textShadowColor.cgColor)
                }
                
                if let (textStrokeColor, textStrokeWidth) = params.item.textStroke {
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
                
                let offset = params.item.contentOffset
                let alignment: NSTextAlignment = .left
                
                for i in 0 ..< params.item.segment.lines.count {
                    let line = params.item.segment.lines[i]
                    
                    var lineFrame = line.frame
                    lineFrame.origin.y += offset.y
                    
                    if alignment == .center {
                        lineFrame.origin.x = offset.x + floor((params.size.width - lineFrame.width) / 2.0)
                    } else if alignment == .natural || alignment == .left {
                        if line.isRTL {
                            lineFrame.origin.x = offset.x + floor(params.size.width - lineFrame.width)
                            lineFrame = displayLineFrame(frame: lineFrame, isRTL: line.isRTL, boundingRect: CGRect(origin: CGPoint(), size: params.size), cutout: nil)
                        } else {
                            lineFrame.origin.x += offset.x
                        }
                    } else if alignment == .right {
                        lineFrame.origin.x = offset.x + (params.size.width - lineFrame.width)
                    }
                    
                    context.textPosition = CGPoint(x: lineFrame.minX, y: lineFrame.maxY - line.descent)
                        
                    let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                    
                    if glyphRuns.count != 0 {
                        let hasAttachments = !line.attachments.isEmpty
                        let hasHiddenSpoilers = !params.item.displayContentsUnderSpoilers && !line.spoilers.isEmpty
                        for run in glyphRuns {
                            let run = run as! CTRun
                            let glyphCount = CTRunGetGlyphCount(run)
                            let attributes = CTRunGetAttributes(run) as NSDictionary
                            if attributes["Attribute__EmbeddedItem"] != nil {
                                continue
                            }
                            if hasHiddenSpoilers && (attributes["Attribute__Spoiler"] != nil || attributes["TelegramSpoiler"] != nil) {
                                continue
                            }
                            
                            /*if renderContentTypes != .all {
                                if let font = attributes["NSFont"] as? UIFont, font.fontName.contains("ColorEmoji") {
                                    if !renderContentTypes.contains(.emoji) {
                                        continue
                                    }
                                } else {
                                    if !renderContentTypes.contains(.text) {
                                        continue
                                    }
                                }
                            }*/
                            
                            var fixDoubleEmoji = false
                            if glyphCount == 2, let font = attributes["NSFont"] as? UIFont, font.fontName.contains("ColorEmoji"), let string = params.item.attributedString {
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
                                context.setBlendMode(.normal)
                            }
                        }
                    }
                    
                    for attachment in line.attachments {
                        let image = attachment.attachment
                        var textColor: UIColor?
                        params.item.attributedString?.enumerateAttributes(in: attachment.range, options: []) { attributes, range, _ in
                            if let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                textColor = color
                            }
                        }
                        if let textColor {
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
                        if !line.strikethroughs.isEmpty {
                            for strikethrough in line.strikethroughs {
                                guard let lineRange = line.range else {
                                    continue
                                }
                                var textColor: UIColor?
                                params.item.attributedString?.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                                    if range == strikethrough.range, let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                        textColor = color
                                    }
                                }
                                if let textColor = textColor {
                                    context.setFillColor(textColor.cgColor)
                                }
                                let frame = strikethrough.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                                context.fill(CGRect(x: frame.minX, y: frame.midY, width: frame.width, height: 1.0))
                            }
                        }
                        
                        if !line.underlines.isEmpty {
                            for strikethrough in line.underlines {
                                guard let lineRange = line.range else {
                                    continue
                                }
                                var textColor: UIColor?
                                params.item.attributedString?.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                                    if range == strikethrough.range, let color = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                        textColor = color
                                    }
                                }
                                if let textColor = textColor {
                                    context.setFillColor(textColor.cgColor)
                                }
                                let frame = strikethrough.frame.offsetBy(dx: lineFrame.minX, dy: lineFrame.minY)
                                context.fill(CGRect(x: frame.minX, y: frame.maxY - 2.0, width: frame.width, height: 1.0))
                            }
                        }
                    }
                    
                    if let (additionalTrailingLine, _) = line.additionalTrailingLine {
                        context.textPosition = CGPoint(x: lineFrame.minX + line.intrinsicWidth, y: lineFrame.maxY - line.descent)
                        
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
                                if glyphCount == 2, let font = attributes["NSFont"] as? UIFont, font.fontName.contains("ColorEmoji"), let string = params.item.attributedString {
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
                                    context.setBlendMode(.normal)
                                }
                            }
                        }
                    }
                }
                
                context.textMatrix = textMatrix
                context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
                
                context.setShadow(offset: CGSize(), blur: 0.0)
                context.setAlpha(1.0)
                
                context.restoreGState()
                
                if let mask = params.mask, !mask.isOpaque {
                    mask.image.draw(in: mask.frame, blendMode: .destinationIn, alpha: 1.0)
                }
            }
            
            return renderingContext.generateImage()
        }
    }
    
    private(set) var params: Params?
    
    let renderNode: RenderNode
    private var contentMaskNode: ASImageNode?
    
    private var overlayContentLayer: SimpleLayer?
    private var overlayContentMaskNode: ASImageNode?
    private var spoilerEffectNode: InvisibleInkDustNode?
    
    private var blockBackgroundView: MessageInlineBlockBackgroundView?
    private var quoteTypeIconNode: ASImageNode?
    private var blockExpandArrow: SimpleLayer?
    
    private var currentAnimationId: Int = 0
    private var isAnimating: Bool = false
    private var currentContentMask: RenderMask?
    
    init(displaysAsynchronously: Bool) {
        self.renderNode = RenderNode()
        self.renderNode.displaysAsynchronously = displaysAsynchronously
        
        super.init()
        
        self.addSublayer(self.renderNode.layer)
    }
    
    override init(layer: Any) {
        self.renderNode = RenderNode()
        
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(
        params: Params,
        animation: ListViewItemUpdateAnimation,
        synchronously: Bool,
        animateContents: Bool,
        spoilerExpandRect: CGRect?
    ) {
        self.params = params

        let contentFrame = CGRect(origin: CGPoint(), size: params.item.size)
        var effectiveContentFrame = contentFrame
        var contentMask: RenderMask?
        
        if let blockQuote = params.item.segment.blockQuote {
            let blockBackgroundView: MessageInlineBlockBackgroundView
            if let current = self.blockBackgroundView {
                blockBackgroundView = current
            } else {
                blockBackgroundView = MessageInlineBlockBackgroundView()
                self.blockBackgroundView = blockBackgroundView
                self.insertSublayer(blockBackgroundView.layer, at: 0)
            }
            
            let blockExpandArrow: SimpleLayer
            if let current = self.blockExpandArrow {
                blockExpandArrow = current
            } else {
                blockExpandArrow = SimpleLayer()
                self.blockExpandArrow = blockExpandArrow
                self.addSublayer(blockExpandArrow)
                blockExpandArrow.contents = expandArrowIcon.cgImage
            }
            blockExpandArrow.layerTintColor = blockQuote.tintColor.cgColor
            
            let blockBackgroundFrame = blockQuote.frame.offsetBy(dx: params.item.contentOffset.x, dy: params.item.contentOffset.y)
            
            if animation.isAnimated {
                if blockBackgroundFrame != blockBackgroundView.layer.frame {
                    self.isAnimating = true
                    self.currentAnimationId += 1
                    let animationId = self.currentAnimationId
                    
                    animation.animator.updateFrame(layer: blockBackgroundView.layer, frame: blockBackgroundFrame, completion: { [weak self] completed in
                        guard completed, let self, self.currentAnimationId == animationId, let params = self.params else {
                            return
                        }
                        self.isAnimating = false
                        self.update(
                            params: params,
                            animation: .None,
                            synchronously: true,
                            animateContents: false,
                            spoilerExpandRect: nil
                        )
                    })
                }
            } else {
                blockBackgroundView.layer.frame = blockBackgroundFrame
            }
            blockBackgroundView.update(
                size: blockBackgroundFrame.size,
                isTransparent: false,
                primaryColor: blockQuote.tintColor,
                secondaryColor: blockQuote.secondaryTintColor,
                thirdColor: blockQuote.tertiaryTintColor,
                backgroundColor: nil,
                pattern: nil,
                patternTopRightPosition: nil,
                patternAlpha: 1.0,
                animation: animation
            )
            
            var quoteTypeIcon: UIImage?
            switch blockQuote.data.kind {
            case .code:
                quoteTypeIcon = codeIcon
            case .quote:
                quoteTypeIcon = quoteIcon
            }
            
            if let quoteTypeIcon {
                let quoteTypeIconNode: ASImageNode
                if let current = self.quoteTypeIconNode {
                    quoteTypeIconNode = current
                } else {
                    quoteTypeIconNode = ASImageNode()
                    self.quoteTypeIconNode = quoteTypeIconNode
                    self.addSublayer(quoteTypeIconNode.layer)
                }
                if quoteTypeIconNode.image !== quoteTypeIcon {
                    quoteTypeIconNode.image = quoteTypeIcon
                }
                let quoteTypeIconFrame = CGRect(origin: CGPoint(x: blockBackgroundFrame.maxX - 4.0 - quoteTypeIcon.size.width, y: blockBackgroundFrame.minY + 4.0), size: quoteTypeIcon.size)
                quoteTypeIconNode.layer.layerTintColor = blockQuote.tintColor.cgColor
                animation.animator.updateFrame(layer: quoteTypeIconNode.layer, frame: quoteTypeIconFrame, completion: nil)
            } else if let quoteTypeIconNode = self.quoteTypeIconNode {
                self.quoteTypeIconNode = nil
                quoteTypeIconNode.removeFromSupernode()
            }
            
            if let isCollapsed = blockQuote.isCollapsed {
                let expandArrowFrame = CGRect(origin: CGPoint(x: blockBackgroundFrame.maxX - 6.0 - expandArrowIcon.size.width, y: blockBackgroundFrame.maxY - 3.0 - expandArrowIcon.size.height), size: expandArrowIcon.size)
                animation.animator.updatePosition(layer: blockExpandArrow, position: expandArrowFrame.center, completion: nil)
                animation.animator.updateBounds(layer: blockExpandArrow, bounds: CGRect(origin: CGPoint(), size: expandArrowFrame.size), completion: nil)
                animation.animator.updateTransform(layer: blockExpandArrow, transform: CATransform3DMakeRotation(isCollapsed ? 0.0 : CGFloat.pi, 0.0, 0.0, 1.0), completion: nil)
                
                let contentMaskFrame = CGRect(origin: CGPoint(x: 0.0, y: contentFrame.minY - blockBackgroundFrame.minY), size: CGSize(width: contentFrame.width, height: blockBackgroundFrame.height))
                contentMask = RenderMask(image: expandableBlockMaskImage, isOpaque: !isCollapsed, frame: contentMaskFrame)
                effectiveContentFrame.size.height = ceil(contentMaskFrame.height - contentMaskFrame.minY)
            } else {
                if let blockExpandArrow = self.blockExpandArrow {
                    self.blockExpandArrow = nil
                    blockExpandArrow.removeFromSuperlayer()
                }
            }
        } else {
            if let blockBackgroundView = self.blockBackgroundView {
                self.blockBackgroundView = nil
                blockBackgroundView.removeFromSuperview()
            }
            if let blockExpandArrow = self.blockExpandArrow {
                self.blockExpandArrow = nil
                blockExpandArrow.removeFromSuperlayer()
            }
            if let quoteTypeIconNode = self.quoteTypeIconNode {
                self.quoteTypeIconNode = nil
                quoteTypeIconNode.removeFromSupernode()
            }
            
            if self.isAnimating {
                self.isAnimating = false
                self.currentAnimationId += 1
            }
        }
        
        animation.animator.updateFrame(layer: self.renderNode.layer, frame: effectiveContentFrame, completion: nil)
        
        var staticContentMask = contentMask
        if let contentMask, self.isAnimating {
            staticContentMask = nil
            
            var contentMaskAnimation = animation
            let contentMaskNode: ASImageNode
            if let current = self.contentMaskNode {
                contentMaskNode = current
            } else {
                contentMaskNode = ASImageNode()
                contentMaskNode.isLayerBacked = true
                contentMaskNode.backgroundColor = .clear
                self.contentMaskNode = contentMaskNode
                self.renderNode.layer.mask = contentMaskNode.layer
                
                if let currentContentMask = self.currentContentMask {
                    contentMaskNode.frame = currentContentMask.frame
                } else {
                    contentMaskAnimation = .None
                }
                
                contentMaskNode.image = contentMask.image
            }
            
            contentMaskAnimation.animator.updateBackgroundColor(layer: contentMaskNode.layer, color: contentMask.isOpaque ? UIColor.white : UIColor.clear, completion: nil)
            contentMaskAnimation.animator.updateFrame(layer: contentMaskNode.layer, frame: contentMask.frame, completion: nil)
        } else {
            if let contentMaskNode = self.contentMaskNode {
                self.contentMaskNode = nil
                contentMaskNode.layer.removeFromSuperlayer()
            }
            self.renderNode.layer.mask = nil
        }
        
        if !params.item.segment.spoilers.isEmpty {
            let spoilerEffectNode: InvisibleInkDustNode
            if let current = self.spoilerEffectNode {
                spoilerEffectNode = current
            } else {
                spoilerEffectNode = InvisibleInkDustNode(textNode: nil, enableAnimations: params.areContentAnimationsEnabled)
                self.spoilerEffectNode = spoilerEffectNode
            }
            
            spoilerEffectNode.frame = contentFrame
            spoilerEffectNode.update(
                size: contentFrame.size,
                color: params.spoilerEffectColor,
                textColor: params.spoilerTextColor,
                rects: params.item.segment.spoilers.map { $0.1.offsetBy(dx: 0.0 + params.item.contentOffset.x, dy: params.item.contentOffset.y + 0.0).insetBy(dx: 1.0, dy: 1.0) },
                wordRects: params.item.segment.spoilerWords.map { $0.1.offsetBy(dx: params.item.contentOffset.x + 0.0, dy: params.item.contentOffset.y + 0.0).insetBy(dx: 1.0, dy: 1.0) }
            )
        } else {
            if let spoilerEffectNode = self.spoilerEffectNode {
                self.spoilerEffectNode = nil
                spoilerEffectNode.layer.removeFromSuperlayer()
            }
        }
        
        if self.spoilerEffectNode != nil {
            let overlayContentLayer: SimpleLayer
            if let current = self.overlayContentLayer {
                overlayContentLayer = current
                animation.animator.updateFrame(layer: overlayContentLayer, frame: effectiveContentFrame, completion: nil)
            } else {
                overlayContentLayer = SimpleLayer()
                self.overlayContentLayer = overlayContentLayer
                overlayContentLayer.masksToBounds = true
                self.addSublayer(overlayContentLayer)
                overlayContentLayer.frame = effectiveContentFrame
            }
            
            if let contentMask {
                var overlayContentMaskAnimation = animation
                let overlayContentMaskNode: ASImageNode
                if let current = self.overlayContentMaskNode {
                    overlayContentMaskNode = current
                } else {
                    overlayContentMaskNode = ASImageNode()
                    overlayContentMaskNode.isLayerBacked = true
                    overlayContentMaskNode.backgroundColor = .clear
                    self.overlayContentMaskNode = overlayContentMaskNode
                    overlayContentLayer.mask = overlayContentMaskNode.layer
                    
                    if let currentContentMask = self.currentContentMask {
                        overlayContentMaskNode.frame = currentContentMask.frame
                    } else {
                        overlayContentMaskAnimation = .None
                    }
                    
                    overlayContentMaskNode.image = contentMask.image
                }
                
                overlayContentMaskAnimation.animator.updateBackgroundColor(layer: overlayContentMaskNode.layer, color: contentMask.isOpaque ? UIColor.white : UIColor.clear, completion: nil)
                overlayContentMaskAnimation.animator.updateFrame(layer: overlayContentMaskNode.layer, frame: contentMask.frame, completion: nil)
            } else {
                if let _ = self.overlayContentMaskNode {
                    self.overlayContentMaskNode = nil
                    overlayContentLayer.mask = nil
                }
            }
            
            if let spoilerEffectNode = self.spoilerEffectNode {
                if spoilerEffectNode.layer.superlayer !== overlayContentLayer {
                    overlayContentLayer.addSublayer(spoilerEffectNode.layer)
                }
            }
        } else {
            if let overlayContentLayer = self.overlayContentLayer {
                self.overlayContentLayer = nil
                overlayContentLayer.removeFromSuperlayer()
            }
        }
        
        self.currentContentMask = contentMask
        
        self.renderNode.params = RenderParams(size: contentFrame.size, item: params.item, mask: staticContentMask)
        if synchronously {
            if let spoilerExpandRect, animation.isAnimated {
                let localSpoilerExpandRect = spoilerExpandRect.offsetBy(dx: -self.renderNode.frame.minX, dy: -self.renderNode.frame.minY)
                
                let revealAnimationDuration: CGFloat = 0.55
                
                let revealTransition: ContainedViewLayoutTransition = .animated(duration: revealAnimationDuration, curve: .easeInOut)
                
                let previousContents = self.renderNode.layer.contents
                let copyContentsLayer = SimpleLayer()
                copyContentsLayer.frame = self.renderNode.frame
                copyContentsLayer.contents = previousContents
                copyContentsLayer.masksToBounds = self.renderNode.layer.masksToBounds
                copyContentsLayer.contentsGravity = self.renderNode.layer.contentsGravity
                copyContentsLayer.contentsScale = self.renderNode.layer.contentsScale
                for sublayer in self.renderNode.layer.sublayers ?? [] {
                    let copySublayer = SimpleLayer()
                    copySublayer.contentsScale = sublayer.contentsScale
                    copySublayer.position = sublayer.position
                    copySublayer.bounds = sublayer.bounds
                    copySublayer.transform = sublayer.transform
                    copySublayer.opacity = sublayer.opacity
                    copySublayer.isHidden = sublayer.isHidden
                    
                    if let sublayer = sublayer as? InlineStickerItemLayer {
                        sublayer.mirrorLayer = copySublayer
                    } else {
                        copySublayer.contents = sublayer.contents
                    }
                    
                    copyContentsLayer.addSublayer(copySublayer)
                }
                self.renderNode.layer.superlayer?.insertSublayer(copyContentsLayer, below: self.renderNode.layer)
                
                self.renderNode.displayImmediately()
                
                let rectangularExpandedSide = max(localSpoilerExpandRect.width, localSpoilerExpandRect.height)
                // The gradient starts at 0.7
                let adjustedExpandedSide = ceil(rectangularExpandedSide * 1.3)
                
                let rectangularExpandedRect = CGSize(width: adjustedExpandedSide, height: adjustedExpandedSide).centered(around: spoilerExpandRect.center)
                
                let maskFrame = self.renderNode.bounds
                
                let maskLayer = SimpleLayer()
                maskLayer.masksToBounds = true
                self.renderNode.layer.mask = maskLayer
                maskLayer.frame = maskFrame
                
                animateRadialExpansionMask(maskLayer: maskLayer, expandedRect: rectangularExpandedRect, transition: revealTransition, inverse: false, completion: { [weak self] in
                    guard let self, let params = self.params else {
                        return
                    }
                    self.renderNode.layer.mask = nil
                    self.update(
                        params: params,
                        animation: .None,
                        synchronously: true,
                        animateContents: false,
                        spoilerExpandRect: nil
                    )
                })
                
                let copyMaskLayer = SimpleLayer()
                copyMaskLayer.masksToBounds = true
                copyContentsLayer.mask = copyMaskLayer
                copyMaskLayer.frame = maskFrame
                
                animateRadialExpansionMask(maskLayer: copyMaskLayer, expandedRect: rectangularExpandedRect, transition: revealTransition, inverse: true, completion: { [weak copyContentsLayer] in
                    copyContentsLayer?.removeFromSuperlayer()
                })
                
                if let spoilerEffectNode = self.spoilerEffectNode {
                    let spoilerMaskLayer = SimpleLayer()
                    spoilerMaskLayer.masksToBounds = true
                    spoilerEffectNode.layer.mask = spoilerMaskLayer
                    spoilerMaskLayer.frame = maskFrame
                    
                    let spoilerLocalPosition = self.convert(rectangularExpandedRect.center, to: spoilerEffectNode.layer)
                    spoilerEffectNode.revealWithoutMaskAtLocation(spoilerLocalPosition)
                    
                    animateRadialExpansionMask(maskLayer: spoilerMaskLayer, expandedRect: rectangularExpandedRect, transition: revealTransition, inverse: true, completion: { [weak self] in
                        guard let self, let spoilerEffectNode = self.spoilerEffectNode else {
                            return
                        }
                        spoilerEffectNode.layer.mask = nil
                        spoilerEffectNode.layer.opacity = 0.0
                    })
                }
            } else {
                let previousContents = self.renderNode.layer.contents
                self.renderNode.displayImmediately()
                if animateContents, let previousContents {
                    animation.transition.animateContents(layer: self.renderNode.layer, from: previousContents)
                }
                
                if let spoilerEffectNode = self.spoilerEffectNode {
                    animation.transition.updateAlpha(layer: spoilerEffectNode.layer, alpha: params.item.displayContentsUnderSpoilers ? 0.0 : 1.0)
                }
            }
        } else {
            self.renderNode.setNeedsDisplay()
            
            if let spoilerEffectNode = self.spoilerEffectNode {
                animation.transition.updateAlpha(layer: spoilerEffectNode.layer, alpha: params.item.displayContentsUnderSpoilers ? 0.0 : 1.0)
                spoilerEffectNode.update(revealed: params.item.displayContentsUnderSpoilers, animated: animation.isAnimated)
            }
        }
    }
}

private func animateRadialExpansionMask(maskLayer: CALayer, expandedRect: CGRect, transition: ContainedViewLayoutTransition, inverse: Bool, completion: @escaping () -> Void) {
    let maskGradientLayer = SimpleGradientLayer()
    maskLayer.addSublayer(maskGradientLayer)
    maskGradientLayer.frame = expandedRect
    
    setupSpoilerExpansionMaskGradient(
        gradientLayer: maskGradientLayer,
            centerLocation: CGPoint(
            x: 0.5,
            y: 0.5
        ),
        radius: CGSize(
            width: 0.5,
            height: 0.5
        ),
        inverse: inverse
    )
    
    let minGradientFrame = CGSize(width: 1.0, height: 1.0).centered(around: expandedRect.center)
    
    transition.animateFrame(layer: maskGradientLayer, from: minGradientFrame, delay: 0.1, completion: { _ in
        completion()
    })
    
    if inverse {
        let outerBoundsSourceRect = minGradientFrame.insetBy(dx: 0.5, dy: 0.5)
        let outerBoundsDestinationRect = expandedRect.insetBy(dx: 0.5, dy: 0.5)
        
        for sideIndex in 0 ..< 4 {
            let copyMaskOuterBoundsTopLayer = SimpleLayer()
            copyMaskOuterBoundsTopLayer.backgroundColor = UIColor.white.cgColor
            maskLayer.addSublayer(copyMaskOuterBoundsTopLayer)
            
            let sourceFrame: CGRect
            let destinationFrame: CGRect
            
            // Top, left, bottom, right
            if sideIndex == 0 {
                sourceFrame = CGRect(origin: CGPoint(x: 0.0, y: outerBoundsSourceRect.minY - expandedRect.height), size: expandedRect.size)
                destinationFrame = CGRect(origin: CGPoint(x: 0.0, y: outerBoundsDestinationRect.minY - expandedRect.height), size: expandedRect.size)
            } else if sideIndex == 1 {
                sourceFrame = CGRect(origin: CGPoint(x: outerBoundsSourceRect.minX - expandedRect.width, y: 0.0), size: expandedRect.size)
                destinationFrame = CGRect(origin: CGPoint(x: outerBoundsDestinationRect.minX - expandedRect.width, y: 0.0), size: expandedRect.size)
            } else if sideIndex == 2 {
                sourceFrame = CGRect(origin: CGPoint(x: 0.0, y: outerBoundsSourceRect.maxY), size: expandedRect.size)
                destinationFrame = CGRect(origin: CGPoint(x: 0.0, y: outerBoundsDestinationRect.maxY), size: expandedRect.size)
            } else {
                sourceFrame = CGRect(origin: CGPoint(x: outerBoundsSourceRect.maxX, y: 0.0), size: expandedRect.size)
                destinationFrame = CGRect(origin: CGPoint(x: outerBoundsDestinationRect.maxX, y: 0.0), size: expandedRect.size)
            }
            
            copyMaskOuterBoundsTopLayer.frame = destinationFrame
            transition.animateFrame(layer: copyMaskOuterBoundsTopLayer, from: sourceFrame, delay: 0.1)
        }
    }
}

private func setupSpoilerExpansionMaskGradient(gradientLayer: SimpleGradientLayer, centerLocation: CGPoint, radius: CGSize, inverse: Bool) {
    let startAlpha: CGFloat = inverse ? 0.0 : 1.0
    let endAlpha: CGFloat = inverse ? 1.0 : 0.0
    
    let locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
    let colors: [CGColor] = [
        UIColor(rgb: 0xff0000, alpha: startAlpha).cgColor,
        UIColor(rgb: 0xff0000, alpha: startAlpha).cgColor,
        UIColor(rgb: 0xff0000, alpha: endAlpha).cgColor,
        UIColor(rgb: 0xff0000, alpha: endAlpha).cgColor
    ]
    
    gradientLayer.type = .radial
    gradientLayer.colors = colors
    gradientLayer.locations = locations.map { $0 as NSNumber }
    gradientLayer.startPoint = centerLocation
    
    let endEndPoint = CGPoint(x: (gradientLayer.startPoint.x + radius.width) * 1.0, y: (gradientLayer.startPoint.y + radius.height) * 1.0)
    gradientLayer.endPoint = endEndPoint
}
