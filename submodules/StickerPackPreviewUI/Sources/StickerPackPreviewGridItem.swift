import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import TelegramPresentationData
import ShimmerEffect

final class StickerPackPreviewInteraction {
    var previewedItem: StickerPreviewPeekItem?
    var playAnimatedStickers: Bool
    
    init(playAnimatedStickers: Bool) {
        self.playAnimatedStickers = playAnimatedStickers
    }
}

final class StickerPackPreviewGridItem: GridItem {
    let account: Account
    let stickerItem: StickerPackItem?
    let interaction: StickerPackPreviewInteraction
    let theme: PresentationTheme
    let isEmpty: Bool
    
    let section: GridSection? = nil
    
    init(account: Account, stickerItem: StickerPackItem?, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, isEmpty: Bool) {
        self.account = account
        self.stickerItem = stickerItem
        self.interaction = interaction
        self.theme = theme
        self.isEmpty = isEmpty
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPackPreviewGridItemNode()
        node.setup(account: self.account, stickerItem: self.stickerItem, interaction: self.interaction, theme: self.theme, isEmpty: self.isEmpty)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPackPreviewGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, stickerItem: self.stickerItem, interaction: self.interaction, theme: self.theme, isEmpty: self.isEmpty)
    }
}

private let textFont = Font.regular(20.0)

final class StickerPackPreviewGridItemNode: GridItemNode {
    private var currentState: (Account, StickerPackItem?)?
    private var isEmpty: Bool?
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    private var placeholderNode: StickerShimmerEffectNode
    
    private var theme: PresentationTheme?
    
    override var isVisibleInGrid: Bool {
        didSet {
            let visibility = self.isVisibleInGrid && (self.interaction?.playAnimatedStickers ?? true)
            if visibility && self.setupTimestamp == nil {
                self.setupTimestamp = CACurrentMediaTime()
            }
            if let animationNode = self.animationNode {
                animationNode.visibility = visibility
            }
        }
    }
    
    private var currentIsPreviewing = false
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var interaction: StickerPackPreviewInteraction?
    
    var selected: (() -> Void)?
    
    var stickerPackItem: StickerPackItem? {
        return self.currentState?.1
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.placeholderNode)
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            
            if image != nil {
                if let stickerItem = strongSelf.currentState?.1 {
                    if stickerItem.file.isVideoSticker || stickerItem.file.isAnimatedSticker {
                        strongSelf.removePlaceholder(animated: !firstTime)
                    } else {
                        let current = CACurrentMediaTime()
                        if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                            strongSelf.removePlaceholder(animated: true)
                        } else {
                            strongSelf.removePlaceholder(animated: false)
                        }
                    }
                }
                firstTime = false
            }
        }
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        guard self.placeholderNode.alpha != 0 else {
            return
        }
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.allowsGroupOpacity = true
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
                self?.placeholderNode.allowsGroupOpacity = false
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    private var setupTimestamp: Double?
    func setup(account: Account, stickerItem: StickerPackItem?, interaction: StickerPackPreviewInteraction, theme: PresentationTheme, isEmpty: Bool) {
        self.interaction = interaction
        self.theme = theme
        
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != stickerItem || self.isEmpty != isEmpty {
            if let stickerItem = stickerItem {
                let visibility = self.isVisibleInGrid && self.interaction?.playAnimatedStickers ?? true
                if visibility && self.setupTimestamp == nil {
                    self.setupTimestamp = CACurrentMediaTime()
                }
                
                if stickerItem.file.isAnimatedSticker || stickerItem.file.isVideoSticker {
                    let dimensions = stickerItem.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    if stickerItem.file.isVideoSticker {
                        self.imageNode.setSignal(chatMessageSticker(account: account, file: stickerItem.file, small: true))
                    } else {
                        self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: account.postbox, file: stickerItem.file, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))))
                    }
                    
                    if self.animationNode == nil {
                        let animationNode = AnimatedStickerNode()
                        self.animationNode = animationNode
                        self.insertSubnode(animationNode, aboveSubnode: self.imageNode)
                        animationNode.started = { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            self?.imageNode.isHidden = true
                            
                            let current = CACurrentMediaTime()
                            if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                                if !strongSelf.placeholderNode.alpha.isZero {
                                    strongSelf.removePlaceholder(animated: true)
                                }
                            } else {
                                strongSelf.removePlaceholder(animated: false)
                            }
                        }
                    }
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                    self.animationNode?.setup(source: AnimatedStickerResourceSource(account: account, resource: stickerItem.file.resource, isVideo: stickerItem.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .cached)
                    
                    self.animationNode?.visibility = visibility
                                        
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(stickerItem.file), resource: stickerItem.file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: account, file: stickerItem.file, small: true))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(stickerItem.file), resource: chatMessageStickerResource(file: stickerItem.file, small: true)).start())
                }
            } else {
                if isEmpty {
                    if !self.placeholderNode.alpha.isZero {
                        self.placeholderNode.alpha = 0.0
                        self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                } else {
                    self.placeholderNode.alpha = 1.0
                }
            }
            self.currentState = (account, stickerItem)
            self.setNeedsLayout()
        }
        self.isEmpty = isEmpty
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundsSide = min(bounds.size.width - 14.0, bounds.size.height - 14.0)
        let boundingSize = CGSize(width: boundsSide, height: boundsSide)
                
        if let (_, item) = self.currentState {
            if let item = item, let dimensions = item.file.dimensions?.cgSize {
                let imageSize = dimensions.aspectFitted(boundingSize)
                let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.frame = imageFrame
                if let animationNode = self.animationNode {
                    animationNode.frame = imageFrame
                    animationNode.updateLayout(size: imageSize)
                }
            }
        }
        
        let imageFrame = self.imageNode.frame
            
        let placeholderFrame = imageFrame
        self.placeholderNode.frame = imageFrame
    
        if let theme = self.theme, let (_, stickerItem) = self.currentState, let item = stickerItem {
            self.placeholderNode.update(backgroundColor: theme.list.itemBlocksBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), data: item.file.immediateThumbnailData, size: placeholderFrame.size)
        }
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        self.placeholderNode.updateAbsoluteRect(absoluteRect, within: containerSize)
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, maybeItem) = self.currentState, let interaction = self.interaction, let item = maybeItem {
            isPreviewing = interaction.previewedItem == .pack(item)
        }
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing
            
            if isPreviewing {
                self.layer.sublayerTransform = CATransform3DMakeScale(0.8, 0.8, 1.0)
                if animated {
                    self.layer.animateSpring(from: 1.0 as NSNumber, to: 0.8 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.4)
                }
            } else {
                self.layer.sublayerTransform = CATransform3DIdentity
                if animated {
                    self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5)
                }
            }
        }
    }
}

