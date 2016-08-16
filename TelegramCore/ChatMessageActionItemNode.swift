import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox

private func backgroundImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context -> Void in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(0x748391, 0.45).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private let titleFont = UIFont.systemFont(ofSize: 13.0)

class ChatMessageActionItemNode: ChatMessageItemView {
    let labelNode: TextNode
    let backgroundNode: ASImageNode
    
    private let fetchDisposable = MetaDisposable()
    
    required init() {
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.displaysAsynchronously = true
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        super.init(layerBacked: false)
        
        self.backgroundNode.image = backgroundImage(color: UIColor.blue)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func setupItem(_ item: ChatMessageItem) {
        super.setupItem(item)
    }
    
    override func asyncLayout() -> (item: ChatMessageItem, width: CGFloat, mergedTop: Bool, mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, width, mergedTop, mergedBottom in
            var attributedString: NSAttributedString?
            
            for media in item.message.media {
                if let action = media as? TelegramMediaAction {
                    let authorName = item.message.author?.displayTitle ?? ""
                    switch action.action {
                        case .groupCreated:
                            attributedString = NSAttributedString(string: tr(.ChatServiceGroupCreated), font: titleFont, textColor: UIColor.white)
                        case let .addedMembers(peerIds):
                            if peerIds.first == item.message.author?.id {
                                attributedString = NSAttributedString(string: tr(.ChatServiceGroupAddedSelf(authorName)), font: titleFont, textColor: UIColor.white)
                            } else {
                                attributedString = NSAttributedString(string: tr(.ChatServiceGroupAddedMembers(authorName, peerDisplayTitles(peerIds, item.message.peers))), font: titleFont, textColor: UIColor.white)
                            }
                        case let .removedMembers(peerIds):
                            if peerIds.first == item.message.author?.id {
                                attributedString = NSAttributedString(string: tr(.ChatServiceGroupRemovedSelf(authorName)), font: titleFont, textColor: UIColor.white)
                            } else {
                                attributedString = NSAttributedString(string: tr(.ChatServiceGroupRemovedMembers(authorName, peerDisplayTitles(peerIds, item.message.peers))), font: titleFont, textColor: UIColor.white)
                            }
                        case let .photoUpdated(image):
                            if let _ = image {
                                attributedString = NSAttributedString(string: tr(.ChatServiceGroupUpdatedPhoto(authorName)), font: titleFont, textColor: UIColor.white)
                            } else {
                                attributedString = NSAttributedString(string: tr(.ChatServiceGroupRemovedPhoto(authorName)), font: titleFont, textColor: UIColor.white)
                            }
                        case let .titleUpdated(title):
                            attributedString = NSAttributedString(string: tr(.ChatServiceGroupUpdatedTitle(authorName, title)), font: titleFont, textColor: UIColor.white)
                        case .pinnedMessageUpdated:
                            var replyMessageText = ""
                            for attribute in item.message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute, let message = item.message.associatedMessages[attribute.messageId] {
                                    replyMessageText = message.text
                                }
                            }
                            attributedString = NSAttributedString(string: tr(.ChatServiceGroupUpdatedPinnedMessage(authorName, replyMessageText)), font: titleFont, textColor: UIColor.white)
                        case .joinedByLink:
                            attributedString = NSAttributedString(string: tr(.ChatServiceGroupJoinedByLink(authorName)), font: titleFont, textColor: UIColor.white)
                        case .channelMigratedFromGroup, .groupMigratedToChannel:
                            attributedString = NSAttributedString(string: tr(.ChatServiceGroupMigratedToSupergroup), font: titleFont, textColor: UIColor.white)
                        default:
                            attributedString = nil
                    }
                    
                    break
                }
            }
            
            let (size, apply) = labelLayout(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), cutout: nil)
            
            let backgroundSize = CGSize(width: size.size.width + 8.0 + 8.0, height: 20.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 20.0), insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)), { [weak self] animation in
                if let strongSelf = self {
                    let _ = apply()
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.backgroundNode.frame.origin.x + 8.0, y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0) - 1.0), size: size.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        super.animateInsertion(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}
