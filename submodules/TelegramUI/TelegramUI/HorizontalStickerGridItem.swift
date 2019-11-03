import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode

final class HorizontalStickerGridItem: GridItem {
    let account: Account
    let file: TelegramMediaFile
    let stickersInteraction: HorizontalStickersChatContextPanelInteraction
    let interfaceInteraction: ChatPanelInterfaceInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, file: TelegramMediaFile, stickersInteraction: HorizontalStickersChatContextPanelInteraction, interfaceInteraction: ChatPanelInterfaceInteraction) {
        self.account = account
        self.file = file
        self.stickersInteraction = stickersInteraction
        self.interfaceInteraction = interfaceInteraction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = HorizontalStickerGridItemNode()
        node.setup(account: self.account, item: self)
        node.interfaceInteraction = self.interfaceInteraction
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? HorizontalStickerGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, item: self)
        node.interfaceInteraction = self.interfaceInteraction
    }
}

final class HorizontalStickerGridItemNode: GridItemNode {
    private var currentState: (Account, HorizontalStickerGridItem, CGSize)?
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private var currentIsPreviewing: Bool = false
    
    override var isVisibleInGrid: Bool {
        didSet {
            if oldValue != self.isVisibleInGrid {
                if self.isVisibleInGrid {
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
        
        super.init()
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, item: HorizontalStickerGridItem) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1.file.id != item.file.id {
            if let dimensions = item.file.dimensions {
                if item.file.isAnimatedSticker {
                    let animationNode: AnimatedStickerNode
                    if let currentAnimationNode = self.animationNode {
                        animationNode = currentAnimationNode
                    } else {
                        animationNode = AnimatedStickerNode()
                        animationNode.transform = self.imageNode.transform
                        animationNode.visibility = self.isVisibleInGrid
                        animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
                        self.addSubnode(animationNode)
                        self.animationNode = animationNode
                    }
                    animationNode.started = { [weak self] in
                        self?.imageNode.alpha = 0.0
                    }
                    let dimensions = item.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                    animationNode.setup(source: AnimatedStickerResourceSource(account: account, resource: item.file.resource), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .cached)
                    
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
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let interfaceInteraction = self.interfaceInteraction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            interfaceInteraction.sendSticker(.standalone(media: item.file), self, self.bounds)
        }
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState {
            isPreviewing = item.stickersInteraction.previewedStickerItem == self.stickerItem
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
