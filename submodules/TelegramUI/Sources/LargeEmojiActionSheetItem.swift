import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import MediaResources
import StickerResources
import ShimmerEffect

public final class LargeEmojiActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let text: String
    let fitz: String?
    let file: TelegramMediaFile
    
    public init(context: AccountContext, text: String, fitz: String?, file: TelegramMediaFile) {
        self.context = context
        self.text = text
        self.fitz = fitz
        self.file = file
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return LargeEmojiActionSheetItemNode(theme: theme, context: self.context, text: self.text, fitz: self.fitz, file: self.file)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class LargeEmojiActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private var placeholderNode: StickerShimmerEffectNode
    private let imageNode: TransformImageNode
    private let animationNode: AnimatedStickerNode
    private let textNode: ImmediateTextNode
    
    private let accessibilityArea: AccessibilityAreaNode
    
    private let disposable = MetaDisposable()
    
    private var setupTimestamp: Double?
    
    init(theme: ActionSheetControllerTheme, context: AccountContext, text: String, fitz: String?, file: TelegramMediaFile) {
        self.theme = theme
        
        let textFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.displaysAsynchronously = false
        
        var fitzModifier: EmojiFitzModifier?
        if let fitz = fitz {
            fitzModifier = EmojiFitzModifier(emoji: fitz)
        }
        self.animationNode = AnimatedStickerNode()
        self.animationNode.setup(source: AnimatedStickerResourceSource(account: context.account, resource: file.resource, fitzModifier: fitzModifier), width: 192, height: 192, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.hasSeparator = true
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.accessibilityArea)
       
        let attributedText = NSAttributedString(string: text, font: textFont, textColor: theme.secondaryTextColor)
        self.textNode.attributedText = attributedText
            
        self.accessibilityArea.accessibilityLabel = attributedText.string
        self.accessibilityArea.accessibilityTraits = .staticText
        
        let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
        self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: context.account.postbox, file: file, small: false, size: dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0)), fitzModifier: fitzModifier, thumbnail: false, synchronousLoad: true), attemptSynchronously: true)
        self.disposable.set(freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file)).start())
        
        self.setupTimestamp = CACurrentMediaTime()
        
        self.animationNode.started = { [weak self] in
            if let strongSelf = self {
                strongSelf.imageNode.alpha = 0.0
                
                let current = CACurrentMediaTime()
                if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                    if !strongSelf.placeholderNode.alpha.isZero {
                        strongSelf.animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        strongSelf.removePlaceholder(animated: true)
                    }
                } else {
                    strongSelf.removePlaceholder(animated: false)
                }
            }
        }
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                if firstTime && !strongSelf.placeholderNode.isEmpty {
                    strongSelf.imageNode.alpha = 0.0
                } else {
                    if strongSelf.setupTimestamp == nil {
                        strongSelf.removePlaceholder(animated: true)
                    }
                }
                firstTime = false
            }
        }
        
        if let immediateThumbnailData = file.immediateThumbnailData {
            self.placeholderNode.update(backgroundColor: nil, foregroundColor: theme.secondaryTextColor.blitOver(theme.itemBackgroundColor, alpha: 0.55), shimmeringColor: theme.itemBackgroundColor.withAlphaComponent(0.4), data: immediateThumbnailData, size: CGSize(width: 96.0, height: 96.0), imageSize: dimensions.cgSize)
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        let _ = self.animationNode.playIfNeeded()
    }
    
    private func removePlaceholder(animated: Bool) {
        self.placeholderNode.alpha = 0.0
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 120.0, height: .greatestFiniteMagnitude))
        
        let topInset: CGFloat = 26.0
        let textSpacing: CGFloat = 17.0
        let bottomInset: CGFloat = 15.0
        
        let iconSize = CGSize(width: 96.0, height: 96.0)
        self.animationNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - iconSize.width) / 2.0), y: topInset), size: iconSize)
        self.animationNode.updateLayout(size: iconSize)
        self.placeholderNode.frame = self.animationNode.frame
                
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + iconSize.height + textSpacing), size: textSize)
        
        let size = CGSize(width: constrainedSize.width, height: topInset + iconSize.height + textSpacing + textSize.height + bottomInset)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: self.placeholderNode.frame.minX, y: self.placeholderNode.frame.minY), size: self.placeholderNode.frame.size), within: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
