import Foundation
import UIKit
import Display
import AsyncDisplayKit
import EmojiTextAttachmentView
import TextFormat
import AccountContext
import AnimationCache
import MultiAnimationRenderer
import TelegramCore

private extension CGRect {
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

private final class InlineStickerItem: Hashable {
    let emoji: ChatTextInputTextCustomEmojiAttribute
    let file: TelegramMediaFile?
    let fontSize: CGFloat
    
    init(emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, fontSize: CGFloat) {
        self.emoji = emoji
        self.file = file
        self.fontSize = fontSize
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(emoji.fileId)
        hasher.combine(self.fontSize)
    }
    
    static func ==(lhs: InlineStickerItem, rhs: InlineStickerItem) -> Bool {
        if lhs.emoji.fileId != rhs.emoji.fileId {
            return false
        }
        if lhs.file?.fileId != rhs.file?.fileId {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        return true
    }
}

private final class RunDelegateData {
    let ascent: CGFloat
    let descent: CGFloat
    let width: CGFloat
    
    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }
}

public final class TextNodeWithEntities {
    public final class Arguments {
        public let context: AccountContext
        public let cache: AnimationCache
        public let renderer: MultiAnimationRenderer
        public let placeholderColor: UIColor
        public let attemptSynchronous: Bool
        
        public init(
            context: AccountContext,
            cache: AnimationCache,
            renderer: MultiAnimationRenderer,
            placeholderColor: UIColor,
            attemptSynchronous: Bool
        ) {
            self.context = context
            self.cache = cache
            self.renderer = renderer
            self.placeholderColor = placeholderColor
            self.attemptSynchronous = attemptSynchronous
        }
        
        public func withUpdatedPlaceholderColor(_ color: UIColor) -> Arguments {
            return Arguments(
                context: self.context,
                cache: self.cache,
                renderer: self.renderer,
                placeholderColor: color,
                attemptSynchronous: self.attemptSynchronous
            )
        }
    }
    
    public let textNode: TextNode
    private var inlineStickerItemLayers: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
    
    public var visibilityRect: CGRect? {
        didSet {
            if !self.inlineStickerItemLayers.isEmpty && oldValue != self.visibilityRect {
                for (_, itemLayer) in self.inlineStickerItemLayers {
                    let isItemVisible: Bool
                    if let visibilityRect = self.visibilityRect {
                        if itemLayer.frame.intersects(visibilityRect) {
                            isItemVisible = true
                        } else {
                            isItemVisible = false
                        }
                    } else {
                        isItemVisible = false
                    }
                    itemLayer.isVisibleForAnimations = isItemVisible
                }
            }
        }
    }
    
    public init() {
        self.textNode = TextNode()
    }
    
    private init(textNode: TextNode) {
        self.textNode = textNode
    }
    
    public static func asyncLayout(_ maybeNode: TextNodeWithEntities?) -> (TextNodeLayoutArguments) -> (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities) {
        let makeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        return { [weak maybeNode] arguments in
            var updatedString: NSAttributedString?
            if let sourceString = arguments.attributedString {
                let string = NSMutableAttributedString(attributedString: sourceString)
                
                var fullRange = NSRange(location: 0, length: string.length)
                while true {
                    var found = false
                    string.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: fullRange, options: [], using: { value, range, stop in
                        if let value = value as? ChatTextInputTextCustomEmojiAttribute, let font = string.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                            let updatedSubstring = NSMutableAttributedString(string: "&")
                            
                            let replacementRange = NSRange(location: 0, length: updatedSubstring.length)
                            updatedSubstring.addAttributes(string.attributes(at: range.location, effectiveRange: nil), range: replacementRange)
                            updatedSubstring.addAttribute(NSAttributedString.Key("Attribute__EmbeddedItem"), value: InlineStickerItem(emoji: value, file: value.file, fontSize: font.pointSize), range: replacementRange)
                            updatedSubstring.addAttribute(originalTextAttributeKey, value: string.attributedSubstring(from: range).string, range: replacementRange)
                            
                            let itemSize = (font.pointSize * 24.0 / 17.0)
                            
                            let runDelegateData = RunDelegateData(
                                ascent: font.ascender,
                                descent: font.descender,
                                width: itemSize
                            )
                            var callbacks = CTRunDelegateCallbacks(
                                version: kCTRunDelegateCurrentVersion,
                                dealloc: { dataRef in
                                    Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                                },
                                getAscent: { dataRef in
                                    let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                                    return data.takeUnretainedValue().ascent
                                },
                                getDescent: { dataRef in
                                    let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                                    return data.takeUnretainedValue().descent
                                },
                                getWidth: { dataRef in
                                    let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                                    return data.takeUnretainedValue().width
                                }
                            )
                            
                            if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                                updatedSubstring.addAttribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), value: runDelegate, range: replacementRange)
                            }
                            
                            string.replaceCharacters(in: range, with: updatedSubstring)
                            let updatedRange = NSRange(location: range.location, length: updatedSubstring.length)
                            
                            found = true
                            stop.pointee = ObjCBool(true)
                            fullRange = NSRange(location: updatedRange.upperBound, length: fullRange.upperBound - range.upperBound)
                        }
                    })
                    if !found {
                        break
                    }
                }
                
                updatedString = string
            }
            
            let (layout, apply) = makeLayout(arguments.withAttributedString(updatedString))
            return (layout, { applyArguments in
                let result = apply()
                
                if let maybeNode = maybeNode {
                    if let applyArguments = applyArguments {
                        maybeNode.updateInlineStickers(context: applyArguments.context, cache: applyArguments.cache, renderer: applyArguments.renderer, textLayout: layout, placeholderColor: applyArguments.placeholderColor, attemptSynchronousLoad: false)
                    }
                    
                    return maybeNode
                } else {
                    let resultNode = TextNodeWithEntities(textNode: result)
                    
                    if let applyArguments = applyArguments {
                        resultNode.updateInlineStickers(context: applyArguments.context, cache: applyArguments.cache, renderer: applyArguments.renderer, textLayout: layout, placeholderColor: applyArguments.placeholderColor, attemptSynchronousLoad: false)
                    }
                    
                    return resultNode
                }
            })
        }
    }
    
    private func isItemVisible(itemRect: CGRect) -> Bool {
        if let visibilityRect = self.visibilityRect {
            return itemRect.intersects(visibilityRect)
        } else {
            return false
        }
    }
    
    private func updateInlineStickers(context: AccountContext, cache: AnimationCache, renderer: MultiAnimationRenderer, textLayout: TextNodeLayout?, placeholderColor: UIColor, attemptSynchronousLoad: Bool) {
        var nextIndexById: [Int64: Int] = [:]
        var validIds: [InlineStickerItemLayer.Key] = []
        
        if let textLayout = textLayout {
            for item in textLayout.embeddedItems {
                if let stickerItem = item.value as? InlineStickerItem {
                    let index: Int
                    if let currentNext = nextIndexById[stickerItem.emoji.fileId] {
                        index = currentNext
                    } else {
                        index = 0
                    }
                    nextIndexById[stickerItem.emoji.fileId] = index + 1
                    let id = InlineStickerItemLayer.Key(id: stickerItem.emoji.fileId, index: index)
                    validIds.append(id)
                    
                    let itemSize = floor(stickerItem.fontSize * 24.0 / 17.0)
                    
                    var itemFrame = CGRect(origin: item.rect.offsetBy(dx: textLayout.insets.left, dy: textLayout.insets.top + 1.0).center, size: CGSize()).insetBy(dx: -itemSize / 2.0, dy: -itemSize / 2.0)
                    itemFrame.origin.x = floorToScreenPixels(itemFrame.origin.x)
                    itemFrame.origin.y = floorToScreenPixels(itemFrame.origin.y)
                    
                    let itemLayer: InlineStickerItemLayer
                    if let current = self.inlineStickerItemLayers[id] {
                        itemLayer = current
                    } else {
                        let pointSize = floor(itemSize * 1.3)
                        itemLayer = InlineStickerItemLayer(context: context, attemptSynchronousLoad: attemptSynchronousLoad, emoji: stickerItem.emoji, file: stickerItem.file, cache: cache, renderer: renderer, placeholderColor: placeholderColor, pointSize: CGSize(width: pointSize, height: pointSize))
                        self.inlineStickerItemLayers[id] = itemLayer
                        self.textNode.layer.addSublayer(itemLayer)
                        
                        itemLayer.isVisibleForAnimations = self.isItemVisible(itemRect: itemFrame)
                    }
                    
                    itemLayer.frame = itemFrame
                }
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in self.inlineStickerItemLayers {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            self.inlineStickerItemLayers.removeValue(forKey: key)
        }
    }
}

public class ImmediateTextNodeWithEntities: TextNode {
    public var attributedText: NSAttributedString?
    public var textAlignment: NSTextAlignment = .natural
    public var verticalAlignment: TextVerticalAlignment = .top
    public var truncationType: CTLineTruncationType = .end
    public var maximumNumberOfLines: Int = 1
    public var lineSpacing: CGFloat = 0.0
    public var insets: UIEdgeInsets = UIEdgeInsets()
    public var textShadowColor: UIColor?
    public var textStroke: (UIColor, CGFloat)?
    public var cutout: TextNodeCutout?
    public var displaySpoilers = false
    
    public var arguments: TextNodeWithEntities.Arguments?
    
    private var inlineStickerItemLayers: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
    
    public var visibility: Bool = false {
        didSet {
            if !self.inlineStickerItemLayers.isEmpty && oldValue != self.visibility {
                for (_, itemLayer) in self.inlineStickerItemLayers {
                    let isItemVisible: Bool = self.visibility
                    itemLayer.isVisibleForAnimations = isItemVisible
                }
            }
        }
    }
    
    public var truncationMode: NSLineBreakMode {
        get {
            switch self.truncationType {
            case .start:
                return .byTruncatingHead
            case .middle:
                return .byTruncatingMiddle
            case .end:
                return .byTruncatingTail
            @unknown default:
                return .byTruncatingTail
            }
        } set(value) {
            switch value {
            case .byTruncatingHead:
                self.truncationType = .start
            case .byTruncatingMiddle:
                self.truncationType = .middle
            case .byTruncatingTail:
                self.truncationType = .end
            default:
                self.truncationType = .end
            }
        }
    }
    
    private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    public var linkHighlightColor: UIColor?
    
    public var trailingLineWidth: CGFloat?
    
    var constrainedSize: CGSize?
    
    public var highlightAttributeAction: (([NSAttributedString.Key: Any]) -> NSAttributedString.Key?)? {
        didSet {
            if self.isNodeLoaded {
                self.updateInteractiveActions()
            }
        }
    }
    
    public var tapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    public var longTapAttributeAction: (([NSAttributedString.Key: Any], Int) -> Void)?
    
    private func processedAttributedText() -> NSAttributedString? {
        var updatedString: NSAttributedString?
        if let sourceString = self.attributedText {
            let string = NSMutableAttributedString(attributedString: sourceString)
            
            let fullRange = NSRange(location: 0, length: string.length)
            string.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: fullRange, options: [], using: { value, range, _ in
                if let value = value as? ChatTextInputTextCustomEmojiAttribute {
                    if let font = string.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                        string.addAttribute(NSAttributedString.Key("Attribute__EmbeddedItem"), value: InlineStickerItem(emoji: value, file: value.file, fontSize: font.pointSize), range: range)
                    }
                }
            })
            
            updatedString = string
        }
        return updatedString
    }
    
    public func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.processedAttributedText(), backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, textShadowColor: self.textShadowColor, textStroke: self.textStroke, displaySpoilers: self.displaySpoilers))
        
        let _ = apply()
        
        if let arguments = self.arguments {
            self.updateInlineStickers(context: arguments.context, cache: arguments.cache, renderer: arguments.renderer, textLayout: layout, placeholderColor: arguments.placeholderColor)
        }
        
        if layout.numberOfLines > 1 {
            self.trailingLineWidth = layout.trailingLineWidth
        } else {
            self.trailingLineWidth = nil
        }
        return layout.size
    }
    
    private func updateInlineStickers(context: AccountContext, cache: AnimationCache, renderer: MultiAnimationRenderer, textLayout: TextNodeLayout?, placeholderColor: UIColor) {
        var nextIndexById: [Int64: Int] = [:]
        var validIds: [InlineStickerItemLayer.Key] = []
        
        if let textLayout = textLayout {
            for item in textLayout.embeddedItems {
                if let stickerItem = item.value as? InlineStickerItem {
                    let index: Int
                    if let currentNext = nextIndexById[stickerItem.emoji.fileId] {
                        index = currentNext
                    } else {
                        index = 0
                    }
                    nextIndexById[stickerItem.emoji.fileId] = index + 1
                    let id = InlineStickerItemLayer.Key(id: stickerItem.emoji.fileId, index: index)
                    validIds.append(id)
                    
                    let itemSize = floor(stickerItem.fontSize * 24.0 / 17.0)
                    
                    let itemFrame = CGRect(origin: item.rect.offsetBy(dx: textLayout.insets.left, dy: textLayout.insets.top + 0.0).center, size: CGSize()).insetBy(dx: -itemSize / 2.0, dy: -itemSize / 2.0)
                    
                    let itemLayer: InlineStickerItemLayer
                    if let current = self.inlineStickerItemLayers[id] {
                        itemLayer = current
                    } else {
                        let pointSize = floor(itemSize * 1.3)
                        itemLayer = InlineStickerItemLayer(context: context, attemptSynchronousLoad: false, emoji: stickerItem.emoji, file: stickerItem.file, cache: cache, renderer: renderer, placeholderColor: placeholderColor, pointSize: CGSize(width: pointSize, height: pointSize))
                        self.inlineStickerItemLayers[id] = itemLayer
                        self.layer.addSublayer(itemLayer)
                        
                        itemLayer.isVisibleForAnimations = self.visibility
                    }
                    
                    itemLayer.frame = itemFrame
                }
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in self.inlineStickerItemLayers {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            self.inlineStickerItemLayers.removeValue(forKey: key)
        }
    }
    
    public func updateLayoutInfo(_ constrainedSize: CGSize) -> ImmediateTextNodeLayoutInfo {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.processedAttributedText(), backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, displaySpoilers: self.displaySpoilers))
        
        let _ = apply()
        
        if let arguments = self.arguments {
            self.updateInlineStickers(context: arguments.context, cache: arguments.cache, renderer: arguments.renderer, textLayout: layout, placeholderColor: arguments.placeholderColor)
        }
        
        return ImmediateTextNodeLayoutInfo(size: layout.size, truncated: layout.truncated, numberOfLines: layout.numberOfLines)
    }
    
    public func updateLayoutFullInfo(_ constrainedSize: CGSize) -> TextNodeLayout {
        self.constrainedSize = constrainedSize
        
        let makeLayout = TextNode.asyncLayout(self)
        let (layout, apply) = makeLayout(TextNodeLayoutArguments(attributedString: self.processedAttributedText(), backgroundColor: nil, maximumNumberOfLines: self.maximumNumberOfLines, truncationType: self.truncationType, constrainedSize: constrainedSize, alignment: self.textAlignment, verticalAlignment: self.verticalAlignment, lineSpacing: self.lineSpacing, cutout: self.cutout, insets: self.insets, displaySpoilers: self.displaySpoilers))
        
        let _ = apply()
        
        if let arguments = self.arguments {
            self.updateInlineStickers(context: arguments.context, cache: arguments.cache, renderer: arguments.renderer, textLayout: layout, placeholderColor: arguments.placeholderColor)
        }
        
        return layout
    }
    
    public func redrawIfPossible() {
        if let constrainedSize = self.constrainedSize {
            let _ = self.updateLayout(constrainedSize)
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.updateInteractiveActions()
    }
    
    private func updateInteractiveActions() {
        if self.highlightAttributeAction != nil {
            if self.tapRecognizer == nil {
                let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
                tapRecognizer.highlight = { [weak self] point in
                    if let strongSelf = self {
                        var rects: [CGRect]?
                        if let point = point {
                            if let (index, attributes) = strongSelf.attributesAtPoint(CGPoint(x: point.x, y: point.y)) {
                                if let selectedAttribute = strongSelf.highlightAttributeAction?(attributes) {
                                    let initialRects = strongSelf.lineAndAttributeRects(name: selectedAttribute.rawValue, at: index)
                                    if let initialRects = initialRects, case .center = strongSelf.textAlignment {
                                        var mappedRects: [CGRect] = []
                                        for i in 0 ..< initialRects.count {
                                            let lineRect = initialRects[i].0
                                            var itemRect = initialRects[i].1
                                            itemRect.origin.x = floor((strongSelf.bounds.size.width - lineRect.width) / 2.0) + itemRect.origin.x
                                            mappedRects.append(itemRect)
                                        }
                                        rects = mappedRects
                                    } else {
                                        rects = strongSelf.attributeRects(name: selectedAttribute.rawValue, at: index)
                                    }
                                }
                            }
                        }
                        
                        if let rects = rects {
                            let linkHighlightingNode: LinkHighlightingNode
                            if let current = strongSelf.linkHighlightingNode {
                                linkHighlightingNode = current
                            } else {
                                linkHighlightingNode = LinkHighlightingNode(color: strongSelf.linkHighlightColor ?? .clear)
                                strongSelf.linkHighlightingNode = linkHighlightingNode
                                strongSelf.addSubnode(linkHighlightingNode)
                            }
                            linkHighlightingNode.frame = strongSelf.bounds
                            linkHighlightingNode.updateRects(rects.map { $0.offsetBy(dx: 0.0, dy: 0.0) })
                        } else if let linkHighlightingNode = strongSelf.linkHighlightingNode {
                            strongSelf.linkHighlightingNode = nil
                            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                                linkHighlightingNode?.removeFromSupernode()
                            })
                        }
                    }
                }
                self.view.addGestureRecognizer(tapRecognizer)
            }
        } else if let tapRecognizer = self.tapRecognizer {
            self.tapRecognizer = nil
            self.view.removeGestureRecognizer(tapRecognizer)
        }
    }
    
    @objc private func tapAction(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let (index, attributes) = self.attributesAtPoint(CGPoint(x: location.x, y: location.y)) {
                                self.tapAttributeAction?(attributes, index)
                            }
                        case .longTap:
                            if let (index, attributes) = self.attributesAtPoint(CGPoint(x: location.x, y: location.y)) {
                                self.longTapAttributeAction?(attributes, index)
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
}
