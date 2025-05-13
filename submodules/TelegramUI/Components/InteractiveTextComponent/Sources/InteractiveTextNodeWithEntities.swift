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
        public let applyArguments: InteractiveTextNode.ApplyArguments
        
        public init(
            context: AccountContext,
            cache: AnimationCache,
            renderer: MultiAnimationRenderer,
            placeholderColor: UIColor,
            attemptSynchronous: Bool,
            textColor: UIColor,
            spoilerEffectColor: UIColor,
            applyArguments: InteractiveTextNode.ApplyArguments
        ) {
            self.context = context
            self.cache = cache
            self.renderer = renderer
            self.placeholderColor = placeholderColor
            self.attemptSynchronous = attemptSynchronous
            self.textColor = textColor
            self.spoilerEffectColor = spoilerEffectColor
            self.applyArguments = applyArguments
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
                applyArguments: self.applyArguments
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
    private var displayContentsUnderSpoilers: Bool?
    
    private var enableLooping: Bool = true
    
    public private(set) var attributedString: NSAttributedString?
    
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
    
    public static func asyncLayout(_ maybeNode: InteractiveTextNodeWithEntities?) -> (InteractiveTextNodeLayoutArguments) -> (InteractiveTextNodeLayout, (InteractiveTextNodeWithEntities.Arguments) -> InteractiveTextNodeWithEntities) {
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
                let animation: ListViewItemUpdateAnimation = applyArguments.applyArguments.animation
                
                var crossfadeSourceView: UIView?
                if let maybeNode, applyArguments.applyArguments.animation.transition.isAnimated, let animator = applyArguments.applyArguments.animation.animator as? ControlledTransition.LegacyAnimator, animator.transition.isAnimated, maybeNode.textNode.bounds.size != layout.size {
                    crossfadeSourceView = maybeNode.textNode.view.snapshotView(afterScreenUpdates: false)
                }
                
                let result = apply(applyArguments.applyArguments)
                
                if let maybeNode {
                    maybeNode.attributedString = arguments.attributedString
                    
                    maybeNode.updateInteractiveContents(
                        context: applyArguments.context,
                        cache: applyArguments.cache,
                        renderer: applyArguments.renderer,
                        textLayout: layout,
                        placeholderColor: applyArguments.placeholderColor,
                        attemptSynchronousLoad: false,
                        textColor: applyArguments.textColor,
                        spoilerEffectColor: applyArguments.spoilerEffectColor,
                        animation: animation,
                        applyArguments: applyArguments.applyArguments
                    )
                    
                    if let crossfadeSourceView {
                        applyArguments.applyArguments.crossfadeContents?(crossfadeSourceView)
                    }
                    
                    return maybeNode
                } else {
                    let resultNode = InteractiveTextNodeWithEntities(textNode: result)
                    
                    resultNode.attributedString = arguments.attributedString
                    
                    resultNode.updateInteractiveContents(
                        context: applyArguments.context,
                        cache: applyArguments.cache,
                        renderer: applyArguments.renderer,
                        textLayout: layout,
                        placeholderColor: applyArguments.placeholderColor,
                        attemptSynchronousLoad: false,
                        textColor: applyArguments.textColor,
                        spoilerEffectColor: applyArguments.spoilerEffectColor,
                        animation: .None,
                        applyArguments: applyArguments.applyArguments
                    )
                    
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
        animation: ListViewItemUpdateAnimation,
        applyArguments: InteractiveTextNode.ApplyArguments
    ) {
        self.enableLooping = context.sharedContext.energyUsageSettings.loopEmoji
        
        var displayContentsUnderSpoilers = false
        if let textLayout {
            displayContentsUnderSpoilers = textLayout.displayContentsUnderSpoilers
        }
        
        self.displayContentsUnderSpoilers = displayContentsUnderSpoilers
        
        var nextIndexById: [Int64: Int] = [:]
        var validIds: [InlineStickerItemLayer.Key] = []
        
        if let textLayout {
            for i in 0 ..< textLayout.segments.count {
                let segment = textLayout.segments[i]
                guard let segmentLayer = self.textNode.segmentLayer(index: i), let segmentParams = segmentLayer.params else {
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
                        
                        itemFrame.origin.x += segmentParams.item.contentOffset.x
                        itemFrame.origin.y += segmentParams.item.contentOffset.y
                        
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
                            
                            itemLayerData.itemLayer.isVisibleForAnimations = self.enableLooping && self.isItemVisible(itemRect: itemFrame.offsetBy(dx: -segmentParams.item.contentOffset.x, dy: -segmentParams.item.contentOffset.x))
                        }
                        
                        itemLayerTransition.updateAlpha(layer: itemLayerData.itemLayer, alpha: item.isHiddenBySpoiler ? 0.0 : 1.0)
                        
                        itemLayerData.itemLayer.frame = itemFrame
                        itemLayerData.rect = itemFrame.offsetBy(dx: -segmentParams.item.contentOffset.x, dy: -segmentParams.item.contentOffset.y)
                    }
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
    }
}
