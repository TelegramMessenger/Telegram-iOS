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
import ShimmerEffect
import TelegramPresentationData

final class HorizontalStickerGridItem: GridItem {
    let account: Account
    let file: TelegramMediaFile
    let theme: PresentationTheme
    let isPreviewed: (HorizontalStickerGridItem) -> Bool
    let sendSticker: (FileMediaReference, ASDisplayNode, CGRect) -> Void
    
    let section: GridSection? = nil
    
    init(account: Account, file: TelegramMediaFile, theme: PresentationTheme, isPreviewed: @escaping (HorizontalStickerGridItem) -> Bool, sendSticker: @escaping (FileMediaReference, ASDisplayNode, CGRect) -> Void) {
        self.account = account
        self.file = file
        self.theme = theme
        self.isPreviewed = isPreviewed
        self.sendSticker = sendSticker
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = HorizontalStickerGridItemNode()
        node.setup(account: self.account, item: self)
        node.sendSticker = self.sendSticker
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? HorizontalStickerGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, item: self)
        node.sendSticker = self.sendSticker
    }
}

final class HorizontalStickerGridItemNode: GridItemNode {
    private var currentState: (Account, HorizontalStickerGridItem, CGSize)?
    let imageNode: TransformImageNode
    private(set) var animationNode: AnimatedStickerNode?
    private(set) var placeholderNode: StickerShimmerEffectNode?
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Void)?
    
    private var currentIsPreviewing: Bool = false
    
    private var setupTimestamp: Double?
    
    override var isVisibleInGrid: Bool {
        didSet {
            if oldValue != self.isVisibleInGrid {
                if self.isVisibleInGrid {
                    if self.setupTimestamp == nil {
                        self.setupTimestamp = CACurrentMediaTime()
                    }
                    self.animationNode?.visibility = true
                } else {
                    self.animationNode?.visibility = false
                }
            }
        }
    }
    
    var stickerItem: StickerPackItem? {
        if let (_, item, _) = self.currentState {
            return StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: 0), file: item.file, indexKeys: [])
        } else {
            return nil
        }
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        self.placeholderNode = StickerShimmerEffectNode()
        
        super.init()
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.addSubnode(self.imageNode)
        if let placeholderNode = self.placeholderNode {
            placeholderNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
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
        self.stickerFetchedDisposable.dispose()
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
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, item: HorizontalStickerGridItem) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1.file.id != item.file.id {
            if let dimensions = item.file.dimensions {
                if item.file.isAnimatedSticker || item.file.isVideoSticker {
                    let animationNode: AnimatedStickerNode
                    if let currentAnimationNode = self.animationNode {
                        animationNode = currentAnimationNode
                    } else {
                        animationNode = DefaultAnimatedStickerNodeImpl()
                        animationNode.transform = self.imageNode.transform
                        animationNode.visibility = self.isVisibleInGrid
                        animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
                        if let placeholderNode = self.placeholderNode {
                            self.insertSubnode(animationNode, belowSubnode: placeholderNode)
                        } else {
                            self.addSubnode(animationNode)
                        }
                        self.animationNode = animationNode
                    }
                    
                    let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                    
                    if item.file.isVideoSticker {
                        self.imageNode.setSignal(chatMessageSticker(postbox: account.postbox, file: item.file, small: true, synchronousLoad: false))
                    } else {
                        self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: account.postbox, file: item.file, small: true, size: fittedDimensions, synchronousLoad: false))
                    }
                    animationNode.started = { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.imageNode.alpha = 0.0
                        
                        let current = CACurrentMediaTime()
                        if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                            if let placeholderNode = strongSelf.placeholderNode, !placeholderNode.alpha.isZero {
                                strongSelf.removePlaceholder(animated: true)
                            }
                        } else {
                            strongSelf.removePlaceholder(animated: false)
                        }
                    }
                    animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource, isVideo: item.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .cached)
                    
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: item.file.resource).start())
                } else {
                    self.imageNode.alpha = 1.0
                    self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: true))
                    
                    if let currentAnimationNode = self.animationNode {
                        self.animationNode = nil
                        currentAnimationNode.removeFromSupernode()
                    }
                    
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(item.file), resource: chatMessageStickerResource(file: item.file, small: true)).start())
                }
                
                self.currentState = (account, item, dimensions.cgSize)
                self.setNeedsLayout()
            }
        }
        
        self.updatePreviewing(animated: false)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundingSize = bounds.insetBy(dx: 2.0, dy: 2.0).size
        
        if let placeholderNode = self.placeholderNode {
            placeholderNode.frame = bounds
            
            if let theme = self.currentState?.1.theme, let file = self.currentState?.1.file {
                placeholderNode.update(backgroundColor: theme.list.plainBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor.mixedWith(theme.list.plainBackgroundColor, alpha: 0.4), shimmeringColor: theme.list.mediaPlaceholderColor.withAlphaComponent(0.3), data: file.immediateThumbnailData, size: bounds.size)
            }
        }
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: CGSize(width: imageSize.width, height: imageSize.height))
            self.imageNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: imageSize.width, height: imageSize.height))
            self.imageNode.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
            
            if let animationNode = self.animationNode {
                animationNode.bounds = self.imageNode.bounds
                animationNode.position = self.imageNode.position
                animationNode.updateLayout(size: self.imageNode.bounds.size)
            }
        }
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        if let placeholderNode = self.placeholderNode {
            placeholderNode.updateAbsoluteRect(absoluteRect, within: containerSize)
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let (_, item, _) = self.currentState, case .ended = recognizer.state {
            self.sendSticker?(.standalone(media: item.file), self, self.bounds)
        }
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
    }
    
    func updatePreviewing(animated: Bool) {
        let isPreviewing = false
        
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing

            self.layer.sublayerTransform = CATransform3DIdentity
            if animated {
                self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5)
            }
        }
    }
}
