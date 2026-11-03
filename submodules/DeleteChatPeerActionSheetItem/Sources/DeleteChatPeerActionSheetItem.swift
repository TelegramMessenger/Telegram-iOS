import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext
import ComponentFlow
import BalancedTextComponent
import MultilineTextComponent

public enum DeleteChatPeerAction {
    case delete
    case deleteAndLeave
    case clearHistory(canClearCache: Bool)
    case clearCache
    case clearCacheSuggestion
    case removeFromGroup
    case removeFromChannel
    case deleteSavedPeer
}

private let avatarFont = avatarPlaceholderFont(size: 26.0)

public final class DeleteChatPeerActionSheetItem: ActionSheetItem {
    let context: AccountContext
    let peer: EnginePeer
    let chatPeer: EnginePeer
    let action: DeleteChatPeerAction
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    let balancedLayout: Bool
    
    public init(context: AccountContext, peer: EnginePeer, chatPeer: EnginePeer, action: DeleteChatPeerAction, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, balancedLayout: Bool = false) {
        self.context = context
        self.peer = peer
        self.chatPeer = chatPeer
        self.action = action
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.balancedLayout = balancedLayout
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return DeleteChatPeerActionSheetItemNode(theme: theme, strings: self.strings, nameOrder: self.nameDisplayOrder, context: self.context, peer: self.peer, chatPeer: self.chatPeer, action: self.action, balancedLayout: self.balancedLayout)
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class DeleteChatPeerActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    private let balancedLayout: Bool
    
    private let avatarNode: AvatarNode
    
    private var text: NSAttributedString?
    private let textView = ComponentView<Empty>()
    
    private let accessibilityArea: AccessibilityAreaNode
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, nameOrder: PresentationPersonNameOrder, context: AccountContext, peer: EnginePeer, chatPeer: EnginePeer, action: DeleteChatPeerAction, balancedLayout: Bool) {
        self.theme = theme
        self.strings = strings
        self.balancedLayout = balancedLayout
        
        let textFont = Font.regular(floor(theme.baseFontSize * 14.0 / 17.0))
        let boldFont = Font.semibold(floor(theme.baseFontSize * 14.0 / 17.0))
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isAccessibilityElement = false
        
        self.accessibilityArea = AccessibilityAreaNode()
        
        super.init(theme: theme)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.accessibilityArea)
        
        var clipStyle: AvatarNodeClipStyle = .round
        if case let .channel(channel) = chatPeer, channel.isMonoForum {
            clipStyle = .bubble
        }
        
        if chatPeer.id == context.account.peerId {
            self.avatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: .savedMessagesIcon, clipStyle: clipStyle)
        } else if chatPeer.id.isReplies {
            self.avatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: .repliesIcon, clipStyle: clipStyle)
        } else if chatPeer.id.isAnonymousSavedMessages {
            self.avatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: .anonymousSavedMessagesIcon(isColored: true), clipStyle: clipStyle)
        } else {
            var overrideImage: AvatarNodeImageOverride?
            if chatPeer.isDeleted {
                overrideImage = .deletedIcon
            }
            self.avatarNode.setPeer(context: context, theme: (context.sharedContext.currentPresentationData.with { $0 }).theme, peer: peer, overrideImage: overrideImage, clipStyle: clipStyle)
        }
        
        var attributedText: NSAttributedString?
        switch action {
        case .clearCache, .clearCacheSuggestion:
            switch action {
            case .clearCache:
                attributedText = NSAttributedString(string: strings.ClearCache_Description, font: textFont, textColor: theme.primaryTextColor)
            case .clearCacheSuggestion:
                attributedText = NSAttributedString(string: strings.ClearCache_FreeSpaceDescription, font: textFont, textColor: theme.primaryTextColor)
            default:
                break
            }
        default:
            var text: PresentationStrings.FormattedString?
            switch action {
            case .delete:
                if peer.id == context.account.peerId {
                    text = PresentationStrings.FormattedString(string: strings.ChatList_DeleteSavedMessagesConfirmation, ranges: [])
                } else if case let .legacyGroup(chatPeer) = peer {
                    text = strings.ChatList_LeaveGroupConfirmation(chatPeer.title)
                } else if case let .channel(chatPeer) = peer {
                    text = strings.ChatList_LeaveGroupConfirmation(chatPeer.title)
                } else if case .secretChat = chatPeer {
                    text = strings.ChatList_DeleteSecretChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                } else {
                    text = strings.ChatList_DeleteChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                }
            case .deleteAndLeave:
                if chatPeer.id == context.account.peerId {
                    text = PresentationStrings.FormattedString(string: strings.ChatList_DeleteSavedMessagesConfirmation, ranges: [])
                } else if case let .legacyGroup(chatPeer) = chatPeer {
                    text = strings.ChatList_DeleteAndLeaveGroupConfirmation(chatPeer.title)
                } else if case .channel = chatPeer {
                    text = strings.ChatList_DeleteAndLeaveGroupConfirmation(peer.compactDisplayTitle)
                } else if case .secretChat = chatPeer {
                    text = strings.ChatList_DeleteSecretChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                } else {
                    text = strings.ChatList_DeleteChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                }
            case .deleteSavedPeer:
                if peer.id == context.account.peerId {
                    text = strings.ChatList_DeleteSavedPeerMyNotesConfirmation(strings.ChatList_DeleteSavedPeerMyNotesConfirmationTitle)
                } else {
                    let peerTitle = peer.displayTitle(strings: strings, displayOrder: nameOrder)
                    text = strings.ChatList_DeleteSavedPeerConfirmation(peerTitle)
                }
            case let .clearHistory(canClearCache):
                if peer.id == context.account.peerId {
                    text = PresentationStrings.FormattedString(string: strings.ChatList_ClearSavedMessagesConfirmation, ranges: [])
                } else if case .user = peer {
                    text = strings.ChatList_ClearChatConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                } else {
                    text = strings.Conversation_DeleteAllMessagesInChat(peer.displayTitle(strings: strings, displayOrder: nameOrder))
                }
                
                if canClearCache {
                    if let textValue = text {
                        text = PresentationStrings.FormattedString(string: textValue.string + "\n\n\(strings.Conversation_AlsoClearCacheTitle)", ranges: textValue.ranges)
                    }
                }
            case .removeFromGroup:
                if case let .channel(channel) = chatPeer, case .broadcast = channel.info {
                    text = strings.LiveStream_RemoveAndBanPeerConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder), chatPeer.displayTitle(strings: strings, displayOrder: nameOrder))
                } else {
                    text = strings.VoiceChat_RemoveAndBanPeerConfirmation(peer.displayTitle(strings: strings, displayOrder: nameOrder), chatPeer.displayTitle(strings: strings, displayOrder: nameOrder))
                }
            case .removeFromChannel:
                text = strings.VoiceChat_RemovePeerConfirmationChannel(peer.displayTitle(strings: strings, displayOrder: nameOrder))
            default:
                break
            }
            if let text = text {
                let formattedAttributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: text.string, font: textFont, textColor: theme.primaryTextColor))
                for range in text.ranges {
                    formattedAttributedText.addAttribute(.font, value: boldFont, range: range.range)
                }
                attributedText = formattedAttributedText
            }
        }
        
        if let attributedText = attributedText {
            self.text = attributedText
            
            self.accessibilityArea.accessibilityLabel = attributedText.string
            self.accessibilityArea.accessibilityTraits = .staticText
        }
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let textComponent: AnyComponent<Empty>
        if self.balancedLayout {
            textComponent = AnyComponent(BalancedTextComponent(
                text: .plain(self.text ?? NSAttributedString()),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            ))
        } else {
            textComponent = AnyComponent(MultilineTextComponent(
                text: .plain(self.text ?? NSAttributedString()),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            ))
        }
        let textSize = self.textView.update(transition: .immediate, component: textComponent, environment: {}, containerSize: CGSize(width: constrainedSize.width - 20.0, height: 1000.0))
        
        let topInset: CGFloat = 16.0
        let avatarSize: CGFloat = 60.0
        let textSpacing: CGFloat = 12.0
        let bottomInset: CGFloat = 15.0
        
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - avatarSize) / 2.0), y: topInset), size: CGSize(width: avatarSize, height: avatarSize))
        
        if let textComponentView = self.textView.view {
            if textComponentView.superview == nil {
                self.view.addSubview(textComponentView)
            }
            textComponentView.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - textSize.width) / 2.0), y: topInset + avatarSize + textSpacing), size: textSize)
        }
        
        let size = CGSize(width: constrainedSize.width, height: topInset + avatarSize + textSpacing + textSize.height + bottomInset)
        self.accessibilityArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
