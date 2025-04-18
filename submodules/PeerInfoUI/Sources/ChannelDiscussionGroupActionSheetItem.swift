import Foundation
import UIKit
import AsyncDisplayKit
import UIKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext

final class ChannelDiscussionGroupActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let channelPeer: Peer
    let groupPeer: Peer
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    
    init(context: AccountContext, channelPeer: Peer, groupPeer: Peer, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) {
        self.context = context
        self.channelPeer = channelPeer
        self.groupPeer = groupPeer
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ChannelDiscussionGroupActionSheetItemNode(theme: theme, context: self.context, channelPeer: self.channelPeer, groupPeer: self.groupPeer, strings: self.strings, nameDisplayOrder: self.nameDisplayOrder)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let avatarFont = avatarPlaceholderFont(size: 26.0)

private final class ChannelDiscussionGroupActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    private let channelAvatarNode: AvatarNode
    private let channelAvatarOverlay: ASImageNode
    private let groupAvatarNode: AvatarNode
    private let textNode: ImmediateTextNode
    
    init(theme: ActionSheetControllerTheme, context: AccountContext, channelPeer: Peer, groupPeer: Peer, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) {
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
        
        self.channelAvatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: EnginePeer(channelPeer))
        self.groupAvatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: EnginePeer(groupPeer))
        
        let text: PresentationStrings.FormattedString
        if let channelPeer = channelPeer as? TelegramChannel, let addressName = channelPeer.addressName, !addressName.isEmpty {
            text = strings.Channel_DiscussionGroup_PublicChannelLink(EnginePeer(groupPeer).displayTitle(strings: strings, displayOrder: nameDisplayOrder), EnginePeer(channelPeer).displayTitle(strings: strings, displayOrder: nameDisplayOrder))
        } else {
            text = strings.Channel_DiscussionGroup_PrivateChannelLink(EnginePeer(groupPeer).displayTitle(strings: strings, displayOrder: nameDisplayOrder), EnginePeer(channelPeer).displayTitle(strings: strings, displayOrder: nameDisplayOrder))
        }
        
        let textFont = Font.regular(floor(theme.baseFontSize * 14.0 / 17.0))
        let boldFont = Font.semibold(floor(theme.baseFontSize * 14.0 / 17.0))
        
        let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: text.string, font: textFont, textColor: theme.primaryTextColor))
        for range in text.ranges {
            attributedText.addAttribute(.font, value: boldFont, range: range.range)
        }
        
        self.textNode.attributedText = attributedText
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
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
        
        let size = CGSize(width: constrainedSize.width, height: topInset + avatarSize + textSpacing + textSize.height + bottomInset)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
