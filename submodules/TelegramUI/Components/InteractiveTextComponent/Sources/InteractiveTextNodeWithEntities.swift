import Foundation
import UIKit
import AsyncDisplayKit
import Display
import CoreText
import AppBundle
import ComponentFlow
import TextFormat
import AccountContext
import AnimationCache
import MultiAnimationRenderer
import TelegramCore
import EmojiTextAttachmentView
import InvisibleInkDustNode

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

public final class InteractiveTextNodeWithEntities {
    public final class Arguments {
        public let context: AccountContext
        public let cache: AnimationCache
        public let renderer: MultiAnimationRenderer
        public let placeholderColor: UIColor
        public let attemptSynchronous: Bool
        public let textColor: UIColor
        public let spoilerEffectColor: UIColor
        public let animation: ListViewItemUpdateAnimation
        
        public init(
            context: AccountContext,
            cache: AnimationCache,
            renderer: MultiAnimationRenderer,
            placeholderColor: UIColor,
            attemptSynchronous: Bool,
            textColor: UIColor,
            spoilerEffectColor: UIColor,
            animation: ListViewItemUpdateAnimation
        ) {
            self.context = context
            self.cache = cache
            self.renderer = renderer
            self.placeholderColor = placeholderColor
            self.attemptSynchronous = attemptSynchronous
            self.textColor = textColor
            self.spoilerEffectColor = spoilerEffectColor
            self.animation = animation
        }
        
        public func withUpdatedPlaceholderColor(_ color: UIColor) -> Arguments {
            return Arguments(
                context: self.context,
                cache: self.cache,
                renderer: self.renderer,
                placeholderColor: color,
                attemptSynchronous: self.attemptSynchronous,
                textColor: self.textColor,
                spoilerEffectColor: self.spoilerEffectColor,
                animation: self.animation
            )
        }
    }
    
    private final class InlineStickerItemLayerData {
        let itemLayer: InlineStickerItemLayer
        var rect: CGRect = CGRect()
        
        init(itemLayer: InlineStickerItemLayer) {
            self.itemLayer = itemLayer
        }
    }
    
    public let textNode: InteractiveTextNode
    
    private var inlineStickerItemLayers: [InlineStickerItemLayer.Key: InlineStickerItemLayerData] = [:]
    private var dustEffectNodes: [Int: InvisibleInkDustNode] = [:]
    
    private var enableLooping: Bool = true
    
    public var visibilityRect: CGRect? {
        didSet {
            if !self.inlineStickerItemLayers.isEmpty && oldValue != self.visibilityRect {
                for (_, itemLayerData) in self.inlineStickerItemLayers {
                    let isItemVisible: Bool
                    if let visibilityRect = self.visibilityRect {
                        if itemLayerData.rect.intersects(visibilityRect) {
                            isItemVisible = true
                        } else {
                            isItemVisible = false
                        }
                    } else {
                        isItemVisible = false
                    }
                    itemLayerData.itemLayer.isVisibleForAnimations = self.enableLooping && isItemVisible
                }
            }
        }
    }
    
    public init() {
        self.textNode = InteractiveTextNode()
    }
    
    private init(textNode: InteractiveTextNode) {
        self.textNode = textNode
    }
    
    public static func asyncLayout(_ maybeNode: InteractiveTextNodeWithEntities?) -> (InteractiveTextNodeLayoutArguments) -> (InteractiveTextNodeLayout, (InteractiveTextNodeWithEntities.Arguments?) -> InteractiveTextNodeWithEntities) {
        let makeLayout = InteractiveTextNode.asyncLayout(maybeNode?.textNode)
        return { [weak maybeNode] arguments in
            var updatedString: NSAttributedString?
            if let sourceString = arguments.attributedString {
                let string = NSMutableAttributedString(attributedString: sourceString)
                
                var fullRange = NSRange(location: 0, length: string.length)
                var originalTextId = 0
                while true {
                    var found = false
                    string.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: fullRange, options: [], using: { value, range, stop in
                        if let value = value as? ChatTextInputTextCustomEmojiAttribute, let font = string.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                            let updatedSubstring = NSMutableAttributedString(string: "&")
                            
                            let replacementRange = NSRange(location: 0, length: updatedSubstring.length)
                            updatedSubstring.addAttributes(string.attributes(at: range.location, effectiveRange: nil), range: replacementRange)
                            updatedSubstring.addAttribute(NSAttributedString.Key("Attribute__EmbeddedItem"), value: InlineStickerItem(emoji: value, file: value.file, fontSize: font.pointSize), range: replacementRange)
                            updatedSubstring.addAttribute(originalTextAttributeKey, value: OriginalTextAttribute(id: originalTextId, string: string.attributedSubstring(from: range).string), range: replacementRange)
                            originalTextId += 1
                            
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
                let animation: ListViewItemUpdateAnimation = applyArguments?.animation ?? .None
                
                let result = apply(animation)
                
                if let maybeNode = maybeNode {
                    if let applyArguments = applyArguments {
                        maybeNode.updateInteractiveContents(context: applyArguments.context, cache: applyArguments.cache, renderer: applyArguments.renderer, textLayout: layout, placeholderColor: applyArguments.placeholderColor, attemptSynchronousLoad: false, textColor: applyArguments.textColor, spoilerEffectColor: applyArguments.spoilerEffectColor, animation: animation)
                    }
                    
                    return maybeNode
                } else {
                    let resultNode = InteractiveTextNodeWithEntities(textNode: result)
                    
                    if let applyArguments = applyArguments {
                        resultNode.updateInteractiveContents(context: applyArguments.context, cache: applyArguments.cache, renderer: applyArguments.renderer, textLayout: layout, placeholderColor: applyArguments.placeholderColor, attemptSynchronousLoad: false, textColor: applyArguments.textColor, spoilerEffectColor: applyArguments.spoilerEffectColor, animation: .None)
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
    
    private func updateInteractiveContents(
        context: AccountContext,
        cache: AnimationCache,
        renderer: MultiAnimationRenderer,
        textLayout: InteractiveTextNodeLayout?,
        placeholderColor: UIColor,
        attemptSynchronousLoad: Bool,
        textColor: UIColor,
        spoilerEffectColor: UIColor,
        animation: ListViewItemUpdateAnimation
    ) {
        self.enableLooping = context.sharedContext.energyUsageSettings.loopEmoji
        
        var displayContentsUnderSpoilers = false
        if let textLayout {
            displayContentsUnderSpoilers = textLayout.displayContentsUnderSpoilers
        }
        
        var nextIndexById: [Int64: Int] = [:]
        var validIds: [InlineStickerItemLayer.Key] = []
        
        var validDustEffectIds: [Int] = []
        
        if let textLayout {
            for i in 0 ..< textLayout.segments.count {
                let segment = textLayout.segments[i]
                guard let segmentLayer = self.textNode.segmentLayer(index: i), let segmentItem = segmentLayer.item else {
                    continue
                }
                
                for item in segment.embeddedItems {
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
                        
                        let itemSize = floorToScreenPixels(stickerItem.fontSize * 24.0 / 17.0)
                        
                        var itemFrame = CGRect(origin: item.rect.center, size: CGSize()).insetBy(dx: -itemSize / 2.0, dy: -itemSize / 2.0)
                        itemFrame.origin.x = floorToScreenPixels(itemFrame.origin.x)
                        itemFrame.origin.y = floorToScreenPixels(itemFrame.origin.y)
                        
                        itemFrame.origin.x += segmentItem.contentOffset.x
                        itemFrame.origin.y += segmentItem.contentOffset.y
                        
                        let itemLayerData: InlineStickerItemLayerData
                        var itemLayerTransition = animation.transition
                        if let current = self.inlineStickerItemLayers[id] {
                            itemLayerData = current
                            itemLayerData.itemLayer.dynamicColor = item.textColor
                            
                            if itemLayerData.itemLayer.superlayer !== segmentLayer.renderNode.layer {
                                segmentLayer.addSublayer(itemLayerData.itemLayer)
                            }
                        } else {
                            itemLayerTransition = .immediate
                            let pointSize = floor(itemSize * 1.3)
                            itemLayerData = InlineStickerItemLayerData(itemLayer: InlineStickerItemLayer(context: context, userLocation: .other, attemptSynchronousLoad: attemptSynchronousLoad, emoji: stickerItem.emoji, file: stickerItem.file, cache: cache, renderer: renderer, placeholderColor: placeholderColor, pointSize: CGSize(width: pointSize, height: pointSize), dynamicColor: item.textColor))
                            self.inlineStickerItemLayers[id] = itemLayerData
                            segmentLayer.renderNode.layer.addSublayer(itemLayerData.itemLayer)
                            
                            itemLayerData.itemLayer.isVisibleForAnimations = self.enableLooping && self.isItemVisible(itemRect: itemFrame.offsetBy(dx: -segmentItem.contentOffset.x, dy: -segmentItem.contentOffset.x))
                        }
                        
                        itemLayerTransition.updateAlpha(layer: itemLayerData.itemLayer, alpha: item.isHiddenBySpoiler ? 0.0 : 1.0)
                        
                        itemLayerData.itemLayer.frame = itemFrame
                        itemLayerData.rect = itemFrame.offsetBy(dx: -segmentItem.contentOffset.x, dy: -segmentItem.contentOffset.y)
                    }
                }
                
                if !segment.spoilers.isEmpty {
                    validDustEffectIds.append(i)
                    
                    let dustEffectNode: InvisibleInkDustNode
                    if let current = self.dustEffectNodes[i] {
                        dustEffectNode = current
                        if dustEffectNode.layer.superlayer !== segmentLayer.renderNode.layer {
                            segmentLayer.renderNode.layer.addSublayer(dustEffectNode.layer)
                        }
                    } else {
                        dustEffectNode = InvisibleInkDustNode(textNode: nil, enableAnimations: context.sharedContext.energyUsageSettings.fullTranslucency)
                        self.dustEffectNodes[i] = dustEffectNode
                        segmentLayer.renderNode.layer.addSublayer(dustEffectNode.layer)
                    }
                    let dustNodeFrame = CGRect(origin: CGPoint(), size: segmentItem.size).insetBy(dx: -3.0, dy: -3.0)
                    dustEffectNode.frame = dustNodeFrame
                    dustEffectNode.update(
                        size: dustNodeFrame.size,
                        color: spoilerEffectColor,
                        textColor: textColor,
                        rects: segment.spoilers.map { $0.1.offsetBy(dx: 3.0 + segmentItem.contentOffset.x, dy: segmentItem.contentOffset.y + 3.0).insetBy(dx: 1.0, dy: 1.0) },
                        wordRects: segment.spoilerWords.map { $0.1.offsetBy(dx: segmentItem.contentOffset.x + 3.0, dy: segmentItem.contentOffset.y + 3.0).insetBy(dx: 1.0, dy: 1.0) }
                    )
                    
                    animation.transition.updateAlpha(node: dustEffectNode, alpha: displayContentsUnderSpoilers ? 0.0 : 1.0)
                }
            }
        }
        
        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayerData) in self.inlineStickerItemLayers {
            if !validIds.contains(key) {
                removeKeys.append(key)
                itemLayerData.itemLayer.removeFromSuperlayer()
            }
        }
        for key in removeKeys {
            self.inlineStickerItemLayers.removeValue(forKey: key)
        }
        
        var removeDustEffectIds: [Int] = []
        for (id, dustEffectNode) in self.dustEffectNodes {
            if !validDustEffectIds.contains(id) {
                removeDustEffectIds.append(id)
                dustEffectNode.removeFromSupernode()
            }
        }
        for id in removeDustEffectIds {
            self.dustEffectNodes.removeValue(forKey: id)
        }
    }
}
