import Foundation
import UIKit
import AsyncDisplayKit
import UIKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext

final class ChannelDiscussionGroupActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let channelPeer: Peer
    let groupPeer: Peer
    let strings: PresentationStrings
    
    init(context: AccountContext, channelPeer: Peer, groupPeer: Peer, strings: PresentationStrings) {
        self.context = context
        self.channelPeer = channelPeer
        self.groupPeer = groupPeer
        self.strings = strings
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ChannelDiscussionGroupActionSheetItemNode(theme: theme, context: self.context, channelPeer: self.channelPeer, groupPeer: self.groupPeer, strings: self.strings)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let avatarFont = UIFont(name: ".SFCompactRounded-Semibold", size: 26.0)!

private final class ChannelDiscussionGroupActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let channelAvatarNode: AvatarNode
    private let channelAvatarOverlay: ASImageNode
    private let groupAvatarNode: AvatarNode
    private let textNode: ImmediateTextNode
    
    init(theme: ActionSheetControllerTheme, context: AccountContext, channelPeer: Peer, groupPeer: Peer, strings: PresentationStrings) {
        self.theme = theme
        
        self.channelAvatarNode = AvatarNode(font: avatarFont)
        self.groupAvatarNode = AvatarNode(font: avatarFont)
        self.channelAvatarOverlay = ASImageNode()
        self.channelAvatarOverlay.displayWithoutProcessing = true
        self.channelAvatarOverlay.displaysAsynchronously = false
        self.channelAvatarOverlay.image = generateFilledCircleImage(diameter: 66.0, color: theme.itemBackgroundColor.withAlphaComponent(1.0))
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        
        super.init(theme: theme)
        
        self.addSubnode(self.groupAvatarNode)
        self.addSubnode(self.channelAvatarOverlay)
        self.addSubnode(self.channelAvatarNode)
        self.addSubnode(self.textNode)
        
        self.channelAvatarNode.setPeer(account: context.account, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: channelPeer)
        self.groupAvatarNode.setPeer(account: context.account, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: groupPeer)
        
        let text: (String, [(Int, NSRange)])
        if let channelPeer = channelPeer as? TelegramChannel, let addressName = channelPeer.addressName, !addressName.isEmpty {
            text = strings.Channel_DiscussionGroup_PublicChannelLink(groupPeer.displayTitle, channelPeer.displayTitle)
        } else {
            text = strings.Channel_DiscussionGroup_PrivateChannelLink(groupPeer.displayTitle, channelPeer.displayTitle)
        }
        let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: text.0, font: Font.regular(14.0), textColor: theme.primaryTextColor))
        for (_, range) in text.1 {
            attributedText.addAttribute(.font, value: Font.semibold(14.0), range: range)
        }
        
        self.textNode.attributedText = attributedText
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedSize.width - 20.0, height: .greatestFiniteMagnitude))
        
        let topInset: CGFloat = 16.0
        let avatarSize: CGFloat = 60.0
        let textSpacing: CGFloat = 12.0
        let bottomInset: CGFloat = 15.0
        
        let avatarOverlap: CGFloat = 10.0
        let avatarsWidth = avatarSize * 2.0 - avatarOverlap
        
        let channelAvatarFrame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - avatarsWidth) / 2.0), y: topInset), size: CGSize(width: avatarSize, height: avatarSize))
        self.channelAvatarNode.frame = channelAvatarFrame
        self.groupAvatarNode.frame = channelAvatarFrame.offsetBy(dx: avatarSize - avatarOverlap, dy: 0.0)
        self.channelAvatarOverlay.frame = CGRect(origin: CGPoint(x: channelAvatarFrame.minX - 3.0, y: channelAvatarFrame.minY - 3.0), size: CGSize(width: 66.0, height: 66.0))
        
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + avatarSize + textSpacing), size: textSize)
        
        return CGSize(width: constrainedSize.width, height: topInset + avatarSize + textSpacing + textSize.height + bottomInset)
    }
    
    override func layout() {
        super.layout()
    }
}
