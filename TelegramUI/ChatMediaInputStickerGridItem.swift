import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ChatMediaInputStickerGridSection: GridSection {
    let collectionId: ItemCollectionId
    let collectionInfo: StickerPackCollectionInfo?
    let height: CGFloat = 26.0
    
    var hashValue: Int {
        return self.collectionId.hashValue
    }
    
    init(collectionId: ItemCollectionId, collectionInfo: StickerPackCollectionInfo?) {
        self.collectionId = collectionId
        self.collectionInfo = collectionInfo
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? ChatMediaInputStickerGridSection {
            return self.collectionId == to.collectionId
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return ChatMediaInputStickerGridSectionNode(collectionInfo: self.collectionInfo)
    }
}

private let sectionTitleFont = Font.medium(12.0)

final class ChatMediaInputStickerGridSectionNode: ASDisplayNode {
    let titleNode: ASTextNode
    
    init(collectionInfo: StickerPackCollectionInfo?) {
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: collectionInfo?.title.uppercased() ?? "", font: sectionTitleFont, textColor: UIColor(0x9099A2))
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 8.0), size: titleSize)
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
    
    init(account: Account, collectionId: ItemCollectionId, stickerPackInfo: StickerPackCollectionInfo?, index: ItemCollectionViewEntryIndex, stickerItem: StickerPackItem, interfaceInteraction: ChatControllerInteraction?, inputNodeInteraction: ChatMediaInputNodeInteraction, selected: @escaping () -> Void) {
        self.account = account
        self.index = index
        self.stickerItem = stickerItem
        self.interfaceInteraction = interfaceInteraction
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        self.section = ChatMediaInputStickerGridSection(collectionId: collectionId, collectionInfo: stickerPackInfo)
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
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
    private let imageNode: TransformImageNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var interfaceInteraction: ChatControllerInteraction?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var selected: (() -> Void)?
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, stickerItem: StickerPackItem) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != stickerItem {
            if let dimensions = stickerItem.file.dimensions {
                self.imageNode.setSignal(account: account, signal: chatMessageSticker(account: account, file: stickerItem.file, small: true))
                self.stickerFetchedDisposable.set(fileInteractiveFetched(account: account, file: stickerItem.file).start())
                
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
        let boundingSize = bounds.insetBy(dx: 6.0, dy: 6.0).size
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
        }
    }
    
    /*func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        if self.messageId == id {
            return self.imageNode
        } else {
            return nil
        }
    }*/
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let interfaceInteraction = self.interfaceInteraction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            interfaceInteraction.sendSticker(item.file)
        }
        /*if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, case .ended = recognizer.state {
            controllerInteraction.openMessage(messageId)
        }*/
    }
}
