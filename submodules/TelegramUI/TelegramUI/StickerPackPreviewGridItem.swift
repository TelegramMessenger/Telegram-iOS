import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class StickerPackPreviewInteraction {
    var previewedItem: StickerPreviewPeekItem?
    
    let sendSticker: (StickerPackItem) -> Void
    
    init(sendSticker: @escaping (StickerPackItem) -> Void) {
        self.sendSticker = sendSticker
    }
}

final class StickerPackPreviewGridItem: GridItem {
    let account: Account
    let stickerItem: StickerPackItem
    let interaction: StickerPackPreviewInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, stickerItem: StickerPackItem, interaction: StickerPackPreviewInteraction) {
        self.account = account
        self.stickerItem = stickerItem
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPackPreviewGridItemNode()
        node.setup(account: self.account, stickerItem: self.stickerItem, interaction: self.interaction)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPackPreviewGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, stickerItem: self.stickerItem, interaction: self.interaction)
    }
}

private let textFont = Font.regular(20.0)

final class StickerPackPreviewGridItemNode: GridItemNode {
    private var currentState: (Account, StickerPackItem, CGSize)?
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    override var isVisibleInGrid: Bool {
        didSet {
            self.animationNode?.visibility = self.isVisibleInGrid
        }
    }
    
    private let textNode: ASTextNode
    
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
        //self.imageNode.alphaTransitionOnFirstUpdate = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.imageNode)
        //self.addSubnode(self.textNode)
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, stickerItem: StickerPackItem, interaction: StickerPackPreviewInteraction) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != stickerItem {
            var text = ""
            for attribute in stickerItem.file.attributes {
                if case let .Sticker(displayText, _, _) = attribute {
                    text = displayText
                    break
                }
            }
            self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: .black, paragraphAlignment: .right)
            if let dimensions = stickerItem.file.dimensions {
                if stickerItem.file.isAnimatedSticker {
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: account.postbox, file: stickerItem.file, small: false, size: CGSize(width: 160.0, height: 160.0)))
                    
                    if self.animationNode == nil {
                        let animationNode = AnimatedStickerNode()
                        self.animationNode = animationNode
                        self.addSubnode(animationNode)
                        animationNode.started = { [weak self] in
                            self?.imageNode.isHidden = true
                        }
                    }
                    self.animationNode?.setup(account: account, resource: stickerItem.file.resource, width: 160, height: 160, mode: .cached)
                    self.animationNode?.visibility = self.isVisibleInGrid
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
                
                self.currentState = (account, stickerItem, dimensions)
                self.setNeedsLayout()
            }
        }
        
        //self.updateSelectionState(animated: false)
        //self.updateHiddenMedia()
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundsSide = min(bounds.size.width - 14.0, bounds.size.height - 14.0)
        let boundingSize = CGSize(width: boundsSide, height: boundsSide)
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
            if let animationNode = self.animationNode {
                animationNode.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
                animationNode.updateLayout(size: imageSize)
            }
            let boundingFrame =  CGRect(origin: CGPoint(x: floor((bounds.size.width - boundingSize.width) / 2.0), y: (bounds.size.height - boundingSize.height) / 2.0), size: boundingSize)
            let textSize = CGSize(width: 32.0, height: 24.0)
            self.textNode.frame = CGRect(origin: CGPoint(x: boundingFrame.maxX - 1.0 - textSize.width, y: boundingFrame.height + 10.0 - textSize.height), size: textSize)
        }
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let interaction = self.interaction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            interaction.sendSticker(item)
        }
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState, let interaction = self.interaction {
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

