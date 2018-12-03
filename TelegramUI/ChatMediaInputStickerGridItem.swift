import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ChatMediaInputStickerGridSection: GridSection {
    let collectionId: ItemCollectionId
    let collectionInfo: StickerPackCollectionInfo?
    let canManagePeerSpecificPack: Bool?
    let interaction: ChatMediaInputNodeInteraction
    let theme: PresentationTheme
    let height: CGFloat = 26.0
    
    var hashValue: Int {
        return self.collectionId.hashValue
    }
    
    init(collectionId: ItemCollectionId, collectionInfo: StickerPackCollectionInfo?, canManagePeerSpecificPack: Bool?, theme: PresentationTheme, interaction: ChatMediaInputNodeInteraction) {
        self.collectionId = collectionId
        self.collectionInfo = collectionInfo
        self.canManagePeerSpecificPack = canManagePeerSpecificPack
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
        return ChatMediaInputStickerGridSectionNode(collectionInfo: self.collectionInfo, canManagePeerSpecificPack: self.canManagePeerSpecificPack, theme: self.theme, interaction: self.interaction)
    }
}

private let sectionTitleFont = Font.medium(12.0)

final class ChatMediaInputStickerGridSectionNode: ASDisplayNode {
    let titleNode: ASTextNode
    let setupNode: HighlightableButtonNode?
    let interaction: ChatMediaInputNodeInteraction
    
    init(collectionInfo: StickerPackCollectionInfo?, canManagePeerSpecificPack: Bool?, theme: PresentationTheme, interaction: ChatMediaInputNodeInteraction) {
        self.interaction = interaction
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        
        if collectionInfo?.id.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, let canManage = canManagePeerSpecificPack, canManage {
            let setupNode = HighlightableButtonNode()
            setupNode.setImage(PresentationResourcesChat.chatInputMediaPanelGridSetupImage(theme), for: [])
            self.setupNode = setupNode
        } else {
            self.setupNode = nil
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
            setupNode.frame = CGRect(origin: CGPoint(x: bounds.width - 12.0 - 16.0, y: 2.0), size: CGSize(width: 16.0, height: 26.0))
        }
    }
    
    @objc private func setupPressed() {
        self.interaction.openPeerSpecificSettings()
    }
}

final class ChatMediaInputStickerGridItem: GridItem {
    let account: Account
    let index: ItemCollectionViewEntryIndex
    let stickerItem: StickerPackItem
    let selected: () -> Void
    let interfaceInteraction: ChatControllerInteraction?
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    let section: GridSection?
    
    init(account: Account, collectionId: ItemCollectionId, stickerPackInfo: StickerPackCollectionInfo?, index: ItemCollectionViewEntryIndex, stickerItem: StickerPackItem, canManagePeerSpecificPack: Bool?, interfaceInteraction: ChatControllerInteraction?, inputNodeInteraction: ChatMediaInputNodeInteraction, theme: PresentationTheme, selected: @escaping () -> Void) {
        self.account = account
        self.index = index
        self.stickerItem = stickerItem
        self.interfaceInteraction = interfaceInteraction
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
            self.section = nil
        } else {
            self.section = ChatMediaInputStickerGridSection(collectionId: collectionId, collectionInfo: stickerPackInfo, canManagePeerSpecificPack: canManagePeerSpecificPack, theme: theme, interaction: inputNodeInteraction)
        }
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ChatMediaInputStickerGridItemNode()
        node.interfaceInteraction = self.interfaceInteraction
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(account: self.account, stickerItem: self.stickerItem)
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
        node.setup(account: self.account, stickerItem: self.stickerItem)
        node.selected = self.selected
    }
}

final class ChatMediaInputStickerGridItemNode: GridItemNode {
    private var currentState: (Account, StickerPackItem, CGSize)?
    private var currentSize: CGSize?
    private let imageNode: TransformImageNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    var interfaceInteraction: ChatControllerInteraction?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var selected: (() -> Void)?
    
    var stickerPackItem: StickerPackItem? {
        return self.currentState?.1
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, stickerItem: StickerPackItem) {
        //self.updateSelectionState(animated: false)
        //self.updateHiddenMedia()
    }
    
    override func updateLayout(item: GridItem, size: CGSize, isVisible: Bool, synchronousLoads: Bool) {
        guard let item = item as? ChatMediaInputStickerGridItem else {
            return
        }
        if self.currentState == nil || self.currentState!.0 !== item.account || self.currentState!.1 != item.stickerItem {
            if let dimensions = item.stickerItem.file.dimensions {
                self.imageNode.setSignal(chatMessageSticker(account: item.account, file: item.stickerItem.file, small: true, synchronousLoad: synchronousLoads && isVisible))
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: item.account, fileReference: stickerPackFileReference(item.stickerItem.file), resource: chatMessageStickerResource(file: item.stickerItem.file, small: true)).start())
                
                self.currentState = (item.account, item.stickerItem, dimensions)
                self.setNeedsLayout()
            }
        }
        
        if self.currentSize != size {
            self.currentSize = size
            
            let sideSize: CGFloat = min(75.0 - 10.0, size.width)
            let boundingSize = CGSize(width: sideSize, height: sideSize)
            
            if let (_, _, mediaDimensions) = self.currentState {
                let imageSize = mediaDimensions.aspectFitted(boundingSize)
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
                self.imageNode.frame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: (size.height - imageSize.height) / 2.0), size: imageSize)
            }
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if self.imageNode.layer.animation(forKey: "opacity") != nil {
            return
        }
        if let interfaceInteraction = self.interfaceInteraction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            interfaceInteraction.sendSticker(.standalone(media: item.file), false)
            self.imageNode.layer.animateAlpha(from: 0.5, to: 1.0, duration: 1.0)
        }
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState, let interaction = self.inputNodeInteraction {
            isPreviewing = interaction.previewedStickerPackItem == .pack(item)
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
