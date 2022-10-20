import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect

private let titleFont = Font.bold(16.0)
private let statusFont = Font.regular(15.0)
private let buttonFont = Font.medium(13.0)

final class TrendingTopItemNode: ASDisplayNode {
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode?
    public private(set) var file: TelegramMediaFile? = nil
    public private(set) var theme: PresentationTheme?
    private var listAppearance = false
    private var itemSize: CGSize?
    private let loadDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    var visibility: Bool = false {
        didSet {
            if oldValue != self.visibility {
                self.animationNode?.visibility = self.visibility
            }
        }
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode?.isUserInteractionEnabled = false
        super.init()
        
        self.addSubnode(self.imageNode)
        if let placeholderNode = self.placeholderNode {
            self.addSubnode(placeholderNode)
        }
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
            }
            firstTime = false
        }
    }
    
    deinit {
        self.loadDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        if let placeholderNode = self.placeholderNode {
            self.placeholderNode = nil
            if !animated {
                placeholderNode.removeFromSupernode()
            } else {
                placeholderNode.allowsGroupOpacity = true
                placeholderNode.alpha = 0.0
                placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak placeholderNode] _ in
                    placeholderNode?.removeFromSupernode()
                    placeholderNode?.allowsGroupOpacity = false
                })
            }
        }
    }
    
    private var absoluteLocation: (CGRect, CGSize)?
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        if let placeholderNode = placeholderNode {
            placeholderNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    func update(theme: PresentationTheme, listAppearance: Bool) {
        self.theme = theme
        self.listAppearance = listAppearance
        
        let backgroundColor: UIColor?
        let foregroundColor: UIColor
        let shimmeringColor: UIColor
        if listAppearance {
            backgroundColor = nil
            foregroundColor = theme.list.itemPlainSeparatorColor.blitOver(theme.list.plainBackgroundColor, alpha: 0.3)
            shimmeringColor = theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4)
        } else {
            let color = theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0)
            backgroundColor = color
            foregroundColor = theme.chat.inputMediaPanel.stickersSectionTextColor.blitOver(color, alpha: 0.15)
            shimmeringColor = theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3)
        }
        
        if let placeholderNode = self.placeholderNode, let file = self.file {
            placeholderNode.update(backgroundColor: backgroundColor, foregroundColor: foregroundColor, shimmeringColor: shimmeringColor, data: file.immediateThumbnailData, size: self.itemSize ?? CGSize(width: 75.0, height: 75.0))
        }
    }
    
    func setup(account: Account, item: StickerPackItem, itemSize: CGSize, synchronousLoads: Bool) {
        self.file = item.file
        self.itemSize = itemSize
        
        if item.file.isAnimatedSticker || item.file.isVideoSticker {
            let animationNode: AnimatedStickerNode
            if let currentAnimationNode = self.animationNode {
                animationNode = currentAnimationNode
            } else {
                animationNode = DefaultAnimatedStickerNodeImpl()
                animationNode.transform = self.imageNode.transform
                animationNode.visibility = self.visibility
                self.animationNode = animationNode
                
                if let placeholderNode = self.placeholderNode {
                    self.insertSubnode(animationNode, belowSubnode: placeholderNode)
                } else {
                    self.addSubnode(animationNode)
                }
            }
            let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
            if item.file.isVideoSticker {
                self.imageNode.setSignal(chatMessageSticker(postbox: account.postbox, file: item.file, small: false, synchronousLoad: synchronousLoads))
            } else {
                self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: account.postbox, file: item.file, small: false, size: fittedDimensions, synchronousLoad: synchronousLoads), attemptSynchronously: synchronousLoads)
            }
            animationNode.started = { [weak self] in
                self?.imageNode.alpha = 0.0
            }
            animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource, isVideo: item.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .cached)
            self.loadDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: item.file.resource).start())
        } else {
            self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: true, synchronousLoad: synchronousLoads), attemptSynchronously: synchronousLoads)
            
            if let currentAnimationNode = self.animationNode {
                self.animationNode = nil
                currentAnimationNode.removeFromSupernode()
            }
            self.loadDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: chatMessageStickerResource(file: item.file, small: true)).start())
        }
    }
    
    func updatePreviewing(animated: Bool, isPreviewing: Bool) {
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing
            
            if isPreviewing {
                if animated {
                    self.layer.animateSpring(from: 1.0 as NSNumber, to: 0.8 as NSNumber, keyPath: "transform.scale", duration: 0.4, removeOnCompletion: false)
                }
            } else {
                self.layer.removeAnimation(forKey: "transform.scale")
                if animated {
                    self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        if let dimensions = self.file?.dimensions, let itemSize = self.itemSize {
            let imageSize = dimensions.cgSize.aspectFitted(itemSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
        }
        
        self.imageNode.frame = self.bounds
        self.animationNode?.updateLayout(size: self.bounds.size)
        
        let size = self.bounds.size
        let boundingSize = size
        
        if let placeholderNode = self.placeholderNode {
            let placeholderFrame = CGRect(origin: CGPoint(x: floor((size.width - boundingSize.width) / 2.0), y: floor((size.height - boundingSize.height) / 2.0)), size: boundingSize)
            placeholderNode.frame = placeholderFrame
            
            if let theme = self.theme {
                self.update(theme: theme, listAppearance: self.listAppearance)
            }
        }
    }
}
