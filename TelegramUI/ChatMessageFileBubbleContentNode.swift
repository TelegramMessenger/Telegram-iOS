import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageFileBubbleContentNode: ChatMessageBubbleContentNode {
    private let interactiveFileNode: ChatMessageInteractiveFileNode
    
    private var item: ChatMessageItem?
    
    required init() {
        self.interactiveFileNode = ChatMessageInteractiveFileNode()
        
        super.init()
        
        self.addSubnode(self.interactiveFileNode)
        
        self.interactiveFileNode.activateLocalContent = { [weak self] in
            if let strongSelf = self {
                if let item = strongSelf.item, let controllerInteraction = strongSelf.controllerInteraction {
                    controllerInteraction.openMessage(item.message.id)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let interactiveFileLayout = self.interactiveFileNode.asyncLayout()
        
        return { item, layoutConstants, position, constrainedSize in
            var selectedFile: TelegramMediaFile?
            for media in item.message.media {
                if let telegramFile = media as? TelegramMediaFile {
                    selectedFile = telegramFile
                }
            }
            
            let incoming = item.message.effectivelyIncoming
            let statusType: ChatMessageDateAndStatusType?
            if case .None = position.bottom {
                if incoming {
                    statusType = .BubbleIncoming
                } else {
                    if item.message.flags.contains(.Failed) {
                        statusType = .BubbleOutgoing(.Failed)
                    } else if item.message.flags.isSending {
                        statusType = .BubbleOutgoing(.Sending)
                    } else {
                        statusType = .BubbleOutgoing(.Sent(read: item.read))
                    }
                }
            } else {
                statusType = nil
            }
            
            var automaticDownload = false
            if selectedFile!.isVoice {
                automaticDownload = item.controllerInteraction.automaticMediaDownloadSettings.categories.getVoice(item.message.id.peerId)
            }
            
            let (initialWidth, refineLayout) = interactiveFileLayout(item.account, item.theme, item.strings, item.message, selectedFile!, automaticDownload, item.message.effectivelyIncoming, statusType, CGSize(width: constrainedSize.width, height: constrainedSize.height))
            
            return (initialWidth + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, { constrainedSize in
                let (refinedWidth, finishLayout) = refineLayout(constrainedSize)
                
                return (refinedWidth + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, { boundingWidth in
                    let (fileSize, fileApply) = finishLayout(boundingWidth - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right)
                    
                    return (CGSize(width: fileSize.width + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, height: fileSize.height + layoutConstants.file.bubbleInsets.top + layoutConstants.file.bubbleInsets.bottom), { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            strongSelf.interactiveFileNode.frame = CGRect(origin: CGPoint(x: layoutConstants.file.bubbleInsets.left, y: layoutConstants.file.bubbleInsets.top), size: fileSize)
                            
                            fileApply()
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
