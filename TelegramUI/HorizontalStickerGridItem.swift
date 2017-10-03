import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class HorizontalStickerGridItem: GridItem {
    let account: Account
    let file: TelegramMediaFile
    let interfaceInteraction: ChatPanelInterfaceInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, file: TelegramMediaFile, interfaceInteraction: ChatPanelInterfaceInteraction) {
        self.account = account
        self.file = file
        self.interfaceInteraction = interfaceInteraction
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = HorizontalStickerGridItemNode()
        node.setup(account: self.account, file: self.file)
        node.interfaceInteraction = self.interfaceInteraction
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? HorizontalStickerGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, file: self.file)
        node.interfaceInteraction = self.interfaceInteraction
    }
}

final class HorizontalStickerGridItemNode: GridItemNode {
    private var currentState: (Account, TelegramMediaFile, CGSize)?
    private let imageNode: TransformImageNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.imageNode.transform = CATransform3DMakeRotation(CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, file: TelegramMediaFile) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1.id != file.id {
            if let dimensions = file.dimensions {
                self.imageNode.setSignal(account: account, signal: chatMessageSticker(account: account, file: file, small: true))
                self.stickerFetchedDisposable.set(freeMediaFileInteractiveFetched(account: account, file: file).start())
                
                self.currentState = (account, file, dimensions)
                self.setNeedsLayout()
            }
        }
        
        //self.updateSelectionState(animated: false)
        //self.updateHiddenMedia()
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundingSize = bounds.insetBy(dx: 2.0, dy: 2.0).size
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: CGSize(width: imageSize.width, height: imageSize.height))
            self.imageNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: imageSize.width, height: imageSize.height))
            self.imageNode.position = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
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
            interfaceInteraction.sendSticker(item)
        }
        /*if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, case .ended = recognizer.state {
         controllerInteraction.openMessage(messageId)
         }*/
    }
}
