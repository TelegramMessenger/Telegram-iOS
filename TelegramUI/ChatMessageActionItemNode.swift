import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private func backgroundImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context -> Void in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(0x748391, 0.45).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private let titleFont = UIFont.systemFont(ofSize: 13.0)

private let timeoutValues: [(Int32, String)] = [
    (1, "1 second"),
    (2, "2 seconds"),
    (3, "3 seconds"),
    (4, "4 seconds"),
    (5, "5 seconds"),
    (6, "6 seconds"),
    (7, "7 seconds"),
    (8, "8 seconds"),
    (9, "9 seconds"),
    (10, "10 seconds"),
    (11, "11 seconds"),
    (12, "12 seconds"),
    (13, "13 seconds"),
    (14, "14 seconds"),
    (15, "15 seconds"),
    (30, "30 seconds"),
    (1 * 60, "1 minute"),
    (1 * 60 * 60, "1 hour"),
    (24 * 60 * 60, "1 day"),
    (7 * 24 * 60 * 60, "1 week"),
]

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
        
        self.backgroundNode.image = backgroundImage(color: UIColor(0x007ee5))
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
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let layoutConstants = self.layoutConstants
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
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
                        case let .messageAutoremoveTimeoutUpdated(timeout):
                            /*
                             "Notification.MessageLifetimeChanged" = "%1$@ set the self-destruct timer to %2$@";
                             "Notification.MessageLifetimeChangedOutgoing" = "You set the self-destruct timer to %1$@";
                             "Notification.MessageLifetimeRemoved" = "%1$@ disabled the self-destruct timer";
                             "Notification.MessageLifetimeRemovedOutgoing" = "You disabled the self-destruct timer";
                             */
                            if timeout > 0 {
                                var timeValue: String = "\(timeout) s"
                                for (value, text) in timeoutValues {
                                    if value == timeout {
                                        timeValue = text
                                    }
                                }
                                
                                let string: String
                                if item.message.author?.id == item.account.peerId {
                                    string = String(format:  NSLocalizedString("Notification.MessageLifetimeChangedOutgoing", comment: ""), timeValue)
                                } else {
                                    let authorString: String
                                    if let author = messageMainPeer(item.message) {
                                        authorString = author.compactDisplayTitle
                                    } else {
                                        authorString = ""
                                    }
                                    string = String(format:  NSLocalizedString("Notification.MessageLifetimeChanged", comment: ""), authorString, timeValue)
                                }
                                attributedString = NSAttributedString(string: string, font: titleFont, textColor: UIColor.white)
                            } else {
                                let string: String
                                if item.message.author?.id == item.account.peerId {
                                    string = NSLocalizedString("Notification.MessageLifetimeRemovedOutgoing", comment: "")
                                } else {
                                    let authorString: String
                                    if let author = messageMainPeer(item.message) {
                                        authorString = author.compactDisplayTitle
                                    } else {
                                        authorString = ""
                                    }
                                    string = String(format: NSLocalizedString("Notification.MessageLifetimeRemoved", comment: ""), authorString)
                                }
                                attributedString = NSAttributedString(string: string, font: titleFont, textColor: UIColor.white)
                            }
                        default:
                            attributedString = nil
                    }
                    
                    break
                }
            }
            
            let (size, apply) = labelLayout(attributedString, nil, 1, .end, CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let backgroundSize = CGSize(width: size.size.width + 8.0 + 8.0, height: 20.0)
            var layoutInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 20.0), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    let _ = apply()
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.backgroundNode.frame.origin.x + 8.0, y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0) - 1.0), size: size.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}
