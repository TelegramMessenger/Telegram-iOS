import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramPresentationData
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect

enum ChatMediaInputStickerGridSectionAccessory {
    case none
    case setup
    case clear
}

final class ChatMediaInputStickerGridSection: GridSection {
    let collectionId: ItemCollectionId
    let collectionInfo: StickerPackCollectionInfo?
    let accessory: ChatMediaInputStickerGridSectionAccessory
    let interaction: ChatMediaInputNodeInteraction
    let theme: PresentationTheme
    let height: CGFloat = 26.0
    
    var hashValue: Int {
        return self.collectionId.hashValue
    }
    
    init(collectionId: ItemCollectionId, collectionInfo: StickerPackCollectionInfo?, accessory: ChatMediaInputStickerGridSectionAccessory, theme: PresentationTheme, interaction: ChatMediaInputNodeInteraction) {
        self.collectionId = collectionId
        self.collectionInfo = collectionInfo
        self.accessory = accessory
        self.theme = theme
        self.interaction = interaction
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? ChatMediaInputStickerGridSection {
            return self.collectionId == to.collectionId && self.theme === to.theme
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return ChatMediaInputStickerGridSectionNode(collectionInfo: self.collectionInfo, accessory: self.accessory, theme: self.theme, interaction: self.interaction)
    }
}

private let sectionTitleFont = Font.medium(12.0)

final class ChatMediaInputStickerGridSectionNode: ASDisplayNode {
    let titleNode: ASTextNode
    let setupNode: HighlightableButtonNode?
    let interaction: ChatMediaInputNodeInteraction
    let accessory: ChatMediaInputStickerGridSectionAccessory
    
    init(collectionInfo: StickerPackCollectionInfo?, accessory: ChatMediaInputStickerGridSectionAccessory, theme: PresentationTheme, interaction: ChatMediaInputNodeInteraction) {
        self.interaction = interaction
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.accessory = accessory
        
        switch accessory {
            case .none:
                self.setupNode = nil
            case .setup:
                let setupNode = HighlightableButtonNode()
                setupNode.setImage(PresentationResourcesChat.chatInputMediaPanelGridSetupImage(theme), for: [])
                self.setupNode = setupNode
            case .clear:
                let setupNode = HighlightableButtonNode()
                setupNode.setImage(PresentationResourcesChat.chatInputMediaPanelGridDismissImage(theme, color: theme.chat.inputMediaPanel.stickersSectionTextColor), for: [])
                self.setupNode = setupNode
        }
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: collectionInfo?.title.uppercased() ?? "", font: sectionTitleFont, textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        
        self.setupNode.flatMap(self.addSubnode)
        self.setupNode?.addTarget(self, action: #selector(self.setupPressed), forControlEvents: .touchUpInside)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 9.0), size: titleSize)
        
        if let setupNode = self.setupNode {
            setupNode.frame = CGRect(origin: CGPoint(x: bounds.width - 12.0 - 16.0, y: 3.0), size: CGSize(width: 16.0, height: 26.0))
        }
    }
    
    @objc private func setupPressed() {
        switch self.accessory {
            case .setup:
                self.interaction.openPeerSpecificSettings()
            case .clear:
                self.interaction.clearRecentlyUsedStickers()
            default:
                break
        }
    }
}

final class ChatMediaInputStickerGridItem: GridItem {
    let account: Account
    let index: ItemCollectionViewEntryIndex
    let stickerItem: StickerPackItem
    let selected: () -> Void
    let interfaceInteraction: ChatControllerInteraction?
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    let theme: PresentationTheme
    let large: Bool
    let isLocked: Bool
    
    let section: GridSection?
    
    init(account: Account, collectionId: ItemCollectionId, stickerPackInfo: StickerPackCollectionInfo?, index: ItemCollectionViewEntryIndex, stickerItem: StickerPackItem, canManagePeerSpecificPack: Bool?, interfaceInteraction: ChatControllerInteraction?, inputNodeInteraction: ChatMediaInputNodeInteraction, hasAccessory: Bool, theme: PresentationTheme, large: Bool = false, isLocked: Bool = false, selected: @escaping () -> Void) {
        self.account = account
        self.index = index
        self.stickerItem = stickerItem
        self.interfaceInteraction = interfaceInteraction
        self.inputNodeInteraction = inputNodeInteraction
        self.theme = theme
        self.large = large
        self.isLocked = isLocked
        self.selected = selected
        if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
            self.section = nil
        } else {
            let accessory: ChatMediaInputStickerGridSectionAccessory
            if hasAccessory && stickerPackInfo?.id.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, let canManage = canManagePeerSpecificPack, canManage {
                accessory = .setup
            } else if hasAccessory && stickerPackInfo?.id.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                accessory = .clear
            } else {
                accessory = .none
            }
            self.section = ChatMediaInputStickerGridSection(collectionId: collectionId, collectionInfo: stickerPackInfo, accessory: accessory, theme: theme, interaction: inputNodeInteraction)
        }
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ChatMediaInputStickerGridItemNode()
        node.interfaceInteraction = self.interfaceInteraction
        node.inputNodeInteraction = self.inputNodeInteraction
        node.selected = self.selected
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ChatMediaInputStickerGridItemNode else {
            assertionFailure()
            return
        }
        node.interfaceInteraction = self.interfaceInteraction
        node.inputNodeInteraction = self.inputNodeInteraction
        node.selected = self.selected
    }
}

final class ChatMediaInputStickerGridItemNode: GridItemNode {
    private var currentState: (Account, StickerPackItem, CGSize)?
    private var currentSize: CGSize?
    let imageNode: TransformImageNode
    private(set) var animationNode: AnimatedStickerNode?
    private(set) var placeholderNode: StickerShimmerEffectNode?
    
    private var lockBackground: UIVisualEffectView?
    private var lockTintView: UIView?
    private var lockIconNode: ASImageNode?
    var isLocked: Bool?
    
    private var didSetUpAnimationNode = false
    private var item: ChatMediaInputStickerGridItem?
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    override var isVisibleInGrid: Bool {
        didSet {
            self.updateVisibility()
        }
    }
    
    private var isPanelVisible = false
    private var isPlaying = false
    
    var interfaceInteraction: ChatControllerInteraction?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var selected: (() -> Void)?
    
    var stickerPackItem: StickerPackItem? {
        return self.currentState?.1
    }
    
    override init() {
        self.imageNode = TransformImageNode()
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
    
    override func updateLayout(item: GridItem, size: CGSize, isVisible: Bool, synchronousLoads: Bool) {
        guard let item = item as? ChatMediaInputStickerGridItem else {
            return
        }
        
        let sideSize: CGFloat = size.width - 10.0
        let boundingSize = CGSize(width: sideSize, height: sideSize)
        
        self.item = item
                        
        if self.currentState == nil || self.currentState!.0 !== item.account || self.currentState!.1 != item.stickerItem || self.isLocked != item.isLocked {
            if !item.inputNodeInteraction.displayStickerPlaceholder {
                self.removePlaceholder(animated: false)
            }
            
            if let dimensions = item.stickerItem.file.dimensions {
                if item.stickerItem.file.isAnimatedSticker || item.stickerItem.file.isVideoSticker {
                    if self.animationNode == nil {
                        let animationNode = DefaultAnimatedStickerNodeImpl()
                        animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
                        self.animationNode = animationNode
                        animationNode.started = { [weak self] in
                            self?.imageNode.isHidden = true
                        }
                        if let placeholderNode = self.placeholderNode {
                            self.insertSubnode(animationNode, belowSubnode: placeholderNode)
                        } else {
                            self.addSubnode(animationNode)
                        }
                    }
                    let dimensions = item.stickerItem.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedSize = item.large ? CGSize(width: 384.0, height: 384.0) : CGSize(width: 160.0, height: 160.0)
                    if item.stickerItem.file.isVideoSticker {
                        self.imageNode.setSignal(chatMessageSticker(account: item.account, file: item.stickerItem.file, small: false, synchronousLoad: synchronousLoads && isVisible))
                    } else {
                        self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.account.postbox, file: item.stickerItem.file, small: false, size: dimensions.cgSize.aspectFitted(fittedSize)))
                    }
                    self.updateVisibility()
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: item.account, fileReference: stickerPackFileReference(item.stickerItem.file), resource: item.stickerItem.file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                        self.imageNode.isHidden = false
                        self.didSetUpAnimationNode = false
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: item.account, file: item.stickerItem.file, small: !item.large, synchronousLoad: synchronousLoads && isVisible))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: item.account, fileReference: stickerPackFileReference(item.stickerItem.file), resource: chatMessageStickerResource(file: item.stickerItem.file, small: !item.large)).start())
                }
                
                self.currentState = (item.account, item.stickerItem, dimensions.cgSize)
                self.setNeedsLayout()
            }
            
            self.isLocked = item.isLocked
            
            if item.isLocked {
                let lockBackground: UIVisualEffectView
                let lockIconNode: ASImageNode
                if let currentBackground = self.lockBackground, let currentIcon = self.lockIconNode {
                    lockBackground = currentBackground
                    lockIconNode = currentIcon
                } else {
                    let effect: UIBlurEffect
                    if #available(iOS 10.0, *) {
                        effect = UIBlurEffect(style: .regular)
                    } else {
                        effect = UIBlurEffect(style: .light)
                    }
                    lockBackground = UIVisualEffectView(effect: effect)
                    lockBackground.clipsToBounds = true
                    lockBackground.isUserInteractionEnabled = false
                    lockIconNode = ASImageNode()
                    lockIconNode.displaysAsynchronously = false
                    lockIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/SmallLock"), color: .white)
                    
                    let lockTintView = UIView()
                    lockTintView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.15)
                    lockBackground.contentView.addSubview(lockTintView)
                    
                    self.lockBackground = lockBackground
                    self.lockTintView = lockTintView
                    self.lockIconNode = lockIconNode
                    
                    self.view.addSubview(lockBackground)
                    self.addSubnode(lockIconNode)
                }
            } else if let lockBackground = self.lockBackground, let lockTintView = self.lockTintView, let lockIconNode = self.lockIconNode {
                self.lockBackground = nil
                self.lockTintView = nil
                self.lockIconNode = nil
                lockBackground.removeFromSuperview()
                lockTintView.removeFromSuperview()
                lockIconNode.removeFromSupernode()
            }
        }
        
        if self.currentSize != size {
            self.currentSize = size
            
            if let (_, _, mediaDimensions) = self.currentState {
                let imageSize = mediaDimensions.aspectFitted(boundingSize)
                let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                if self.imageNode.supernode === self {
                    self.imageNode.frame = imageFrame
                }
                if let animationNode = self.animationNode {
                    if animationNode.supernode === self {
                        animationNode.frame = imageFrame
                    }
                    animationNode.updateLayout(size: imageSize)
                }
            }
        }
        
        if let placeholderNode = self.placeholderNode {
            let placeholderFrame = CGRect(origin: CGPoint(x: floor((size.width - boundingSize.width) / 2.0), y: floor((size.height - boundingSize.height) / 2.0)), size: boundingSize)
            if placeholderNode.supernode === self {
                placeholderNode.frame = placeholderFrame
            }
            
            let theme = item.theme
            placeholderNode.update(backgroundColor: theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0), foregroundColor: theme.chat.inputMediaPanel.stickersSectionTextColor.blitOver(theme.chat.inputMediaPanel.stickersBackgroundColor, alpha: 0.15), shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.3), data: item.stickerItem.file.immediateThumbnailData, size: placeholderFrame.size)
        }
        
        if let lockBackground = self.lockBackground, let lockTintView = self.lockTintView, let lockIconNode = self.lockIconNode {
            let lockSize = CGSize(width: 24.0, height: 24.0)
            let lockBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - lockSize.width) / 2.0), y: size.height - lockSize.height - 2.0), size: lockSize)
            lockBackground.frame = lockBackgroundFrame
            lockBackground.layer.cornerRadius = lockSize.width / 2.0
            if #available(iOS 13.0, *) {
                lockBackground.layer.cornerCurve = .circular
            }
            lockTintView.frame = CGRect(origin: CGPoint(), size: lockBackgroundFrame.size)
            if let icon = lockIconNode.image {
                lockIconNode.frame = CGRect(origin: CGPoint(x: lockBackgroundFrame.minX + floorToScreenPixels((lockBackgroundFrame.width - icon.size.width) / 2.0), y: lockBackgroundFrame.minY + floorToScreenPixels((lockBackgroundFrame.height - icon.size.height) / 2.0)), size: icon.size)
            }
        }
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        if let placeholderNode = self.placeholderNode {
            placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: absoluteRect.minX + placeholderNode.frame.minX, y: absoluteRect.minY + placeholderNode.frame.minY), size: placeholderNode.frame.size), within: containerSize)
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if self.imageNode.layer.animation(forKey: "opacity") != nil {
            return
        }
        if let interfaceInteraction = self.interfaceInteraction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            if let isLocked = self.isLocked, isLocked {
            } else {
                let _ = interfaceInteraction.sendSticker(.standalone(media: item.file), false, false, nil, false, self.view, self.bounds, nil, [])
                self.imageNode.layer.animateAlpha(from: 0.5, to: 1.0, duration: 1.0)
            }
        }
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
    }
    
    func updateIsPanelVisible(_ isPanelVisible: Bool) {
        if self.isPanelVisible != isPanelVisible {
            self.isPanelVisible = isPanelVisible
            self.updateVisibility()
        }
    }
    
    func updateVisibility() {
        guard let item = self.item else {
            return
        }
        let isPlaying = self.isPanelVisible && self.isVisibleInGrid && (item.interfaceInteraction?.stickerSettings.loopAnimatedStickers ?? true)
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            self.animationNode?.visibility = isPlaying
            
            if let item = self.item, isPlaying, !self.didSetUpAnimationNode {
                self.didSetUpAnimationNode = true
                
                if let animationNode = self.animationNode {
                    let dimensions = item.stickerItem.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fitSize = item.large ? CGSize(width: 384.0, height: 384.0) : CGSize(width: 160.0, height: 160.0)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(fitSize)
                    animationNode.setup(source: AnimatedStickerResourceSource(account: item.account, resource: item.stickerItem.file.resource, isVideo: item.stickerItem.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .cached)
                }
            }
        }
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState, let interaction = self.inputNodeInteraction {
            isPreviewing = interaction.previewedStickerPackItem == .pack(item.file)
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
