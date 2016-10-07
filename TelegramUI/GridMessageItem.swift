import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox

private func mediaForMessage(_ message: Message) -> Media? {
    for media in message.media {
        if let media = media as? TelegramMediaImage {
            return media
        } else if let file = media as? TelegramMediaFile {
            if file.mimeType.hasPrefix("audio/") {
                return nil
            } else if !file.isVideo && file.mimeType.hasPrefix("video/") {
                return file
            } else {
                return file
            }
        }
    }
    return nil
}

final class GridMessageItem: GridItem {
    private let account: Account
    private let message: Message
    private let controllerInteraction: ChatControllerInteraction
    
    init(account: Account, message: Message, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.message = message
        self.controllerInteraction = controllerInteraction
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = GridMessageItemNode()
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, media: media, messageId: self.message.id, controllerInteraction: self.controllerInteraction)
        }
        return node
    }
}

final class GridMessageItemNode: GridItemNode {
    private var currentState: (Account, Media, CGSize)?
    private let imageNode: TransformImageNode
    private var messageId: MessageId?
    private var controllerInteraction: ChatControllerInteraction?
    
    private var selectionNode: GridMessageSelectionNode?
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, media: Media, messageId: MessageId, controllerInteraction: ChatControllerInteraction) {
        if self.currentState == nil || self.currentState!.0 !== account || !self.currentState!.1.isEqual(media) {
            var mediaDimensions: CGSize?
            if let image = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions {
                mediaDimensions = largestSize
                self.imageNode.setSignal(account: account, signal: mediaGridMessagePhoto(account: account, photo: image), dispatchOnDisplayLink: true)
            }
            
            if let mediaDimensions = mediaDimensions {
                self.currentState = (account, media, mediaDimensions)
                self.setNeedsLayout()
            }
        }
        
        self.messageId = messageId
        self.controllerInteraction = controllerInteraction
        
        self.updateSelectionState(animated: false)
        self.updateHiddenMedia()
    }
    
    override func layout() {
        super.layout()
        
        let imageFrame = self.bounds.insetBy(dx: 1.0, dy: 1.0)
        self.imageNode.frame = imageFrame
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets()))()
        }
        
        self.selectionNode?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
    
    func updateSelectionState(animated: Bool) {
        if let messageId = self.messageId, let controllerInteraction = self.controllerInteraction {
            if let selectionState = controllerInteraction.selectionState {
                var selected = selectionState.selectedIds.contains(messageId)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let selectionNode = GridMessageSelectionNode(toggle: { [weak self] in
                        if let strongSelf = self, let messageId = strongSelf.messageId {
                            strongSelf.controllerInteraction?.toggleMessageSelection(messageId)
                        }
                    })
                    
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    self.addSubnode(selectionNode)
                    self.selectionNode = selectionNode
                    selectionNode.updateSelected(selected, animated: false)
                    if animated {
                        selectionNode.animateIn()
                    }
                }
            } else {
                if let selectionNode = self.selectionNode {
                    self.selectionNode = nil
                    if animated {
                        selectionNode.animateOut { [weak selectionNode] in
                            selectionNode?.removeFromSupernode()
                        }
                    } else {
                        selectionNode.removeFromSupernode()
                    }
                }
            }
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        if self.messageId == id {
            return self.imageNode
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia() {
        if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, controllerInteraction.hiddenMedia[messageId] != nil {
            self.imageNode.isHidden = true
        } else {
            self.imageNode.isHidden = false
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, case .ended = recognizer.state {
            controllerInteraction.openMessage(messageId)
        }
    }
}
