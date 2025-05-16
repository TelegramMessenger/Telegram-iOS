import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramStringFormatting
import ChatPresentationInterfaceState
import TelegramPresentationData
import ChatInputPanelNode
import AccountContext

final class ChatRestrictedInputPanelNode: ChatInputPanelNode {
    private let buttonNode: HighlightTrackingButtonNode
    private let textNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private var iconView: UIImageView?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 2
        self.textNode.textAlignment = .center
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.textAlignment = .center
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let self {
                if highlighted {
                    self.iconView?.layer.removeAnimation(forKey: "opacity")
                    self.iconView?.alpha = 0.4
                    self.textNode.layer.removeAnimation(forKey: "opacity")
                    self.textNode.alpha = 0.4
                    self.subtitleNode.layer.removeAnimation(forKey: "opacity")
                    self.subtitleNode.alpha = 0.4
                } else {
                    self.iconView?.alpha = 1.0
                    self.iconView?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    self.textNode.alpha = 1.0
                    self.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    self.subtitleNode.alpha = 1.0
                    self.subtitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.interfaceInteraction?.openBoostToUnrestrict()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        var bannedPermission: (Int32, Bool)?
        if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel {
            if let value = channel.hasBannedPermission(.banSendText) {
                bannedPermission = value
            } else if !channel.hasPermission(.sendSomething) {
                bannedPermission = (Int32.max, false)
            }
        } else if let group = interfaceState.renderedPeer?.peer as? TelegramGroup {
            if !group.hasPermission(.sendSomething) {
                bannedPermission = (Int32.max, false)
            }
        }
        
        var iconImage: UIImage?
        var iconSpacing: CGFloat = 4.0
        var isUserInteractionEnabled = false
        
        var accountFreezeConfiguration: AccountFreezeConfiguration?
        if let context = self.context {
            accountFreezeConfiguration = AccountFreezeConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        }
        if let channel = interfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, channel.isMonoForum {
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelForumModeReplyText, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        } else if let _ = accountFreezeConfiguration?.freezeUntilDate {
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelFrozenAccount_Title, font: Font.semibold(15.0), textColor: interfaceState.theme.list.itemDestructiveColor)
            self.subtitleNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelFrozenAccount_Text, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            isUserInteractionEnabled = true
        } else if case let .replyThread(message) = interfaceState.chatLocation, message.peerId == self.context?.account.peerId {
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelStatusAuthorHidden, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        } else if let threadData = interfaceState.threadData, threadData.isClosed {
            iconImage = PresentationResourcesChat.chatPanelLockIcon(interfaceState.theme)
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelTopicClosedText, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        } else if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum, case .peer = interfaceState.chatLocation {
            if let replyMessage = interfaceState.replyMessage, let threadInfo = replyMessage.associatedThreadInfo {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_TopicIsClosedLabel(threadInfo.title).string, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelForumModeReplyText, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            }
        } else if let (untilDate, personal) = bannedPermission {
            if personal && untilDate != 0 && untilDate != Int32.max {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RestrictedTextTimed(stringForFullDate(timestamp: untilDate, strings: interfaceState.strings, dateTimeFormat: interfaceState.dateTimeFormat)).string, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else if personal {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RestrictedText, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else {
                if (self.presentationInterfaceState?.boostsToUnrestrict ?? 0) > 0 {
                    iconSpacing = 0.0
                    iconImage = PresentationResourcesChat.chatPanelBoostIcon(interfaceState.theme)
                    self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_BoostToUnrestrictText, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.panelControlAccentColor)
                    isUserInteractionEnabled = true
                } else {
                    self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_DefaultRestrictedText, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
                }
            }
        } else if case let .customChatContents(customChatContents) = interfaceState.subject {
            let displayCount: Int
            switch customChatContents.kind {
            case .hashTagSearch:
                displayCount = 0
            case .quickReplyMessageInput:
                displayCount = customChatContents.messageLimit ?? 20
            case .businessLinkSetup:
                displayCount = 0
            }
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_QuickReplyMessageLimitReachedText(Int32(displayCount)), font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        }
        self.buttonNode.isUserInteractionEnabled = isUserInteractionEnabled
        
        let panelHeight = defaultHeight(metrics: metrics)
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightInset - 8.0 * 2.0, height: panelHeight))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: width - leftInset - rightInset - 8.0 * 2.0, height: panelHeight))
        
        var originX: CGFloat = leftInset + floor((width - leftInset - rightInset - textSize.width) / 2.0)
        
        if let iconImage {
            let iconView: UIImageView
            if let current = self.iconView {
                iconView = current
            } else {
                iconView = UIImageView()
                self.iconView = iconView
                self.view.addSubview(iconView)
            }
            iconView.image = iconImage
            
            let totalWidth = textSize.width + iconImage.size.width + iconSpacing
            iconView.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - totalWidth) / 2.0), y: floor((panelHeight - textSize.height) / 2.0) + UIScreenPixel + floorToScreenPixels((textSize.height - iconImage.size.height) / 2.0)), size: iconImage.size)
            
            originX += iconImage.size.width + iconSpacing
        } else if let iconView = self.iconView {
            self.iconView = nil
            iconView.removeFromSuperview()
        }
        
        var combinedHeight: CGFloat = textSize.height
        if subtitleSize.height > 0.0 {
            combinedHeight += subtitleSize.height + 2.0
        }
        let textFrame = CGRect(origin: CGPoint(x: originX, y: floor((panelHeight - combinedHeight) / 2.0)), size: textSize)
        self.textNode.frame = textFrame
        
        let subtitleFrame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - subtitleSize.width) / 2.0), y: floor((panelHeight + combinedHeight) / 2.0) - subtitleSize.height), size: subtitleSize)
        self.subtitleNode.frame = subtitleFrame
        
        let combinedFrame = textFrame.union(subtitleFrame)
        self.buttonNode.frame = combinedFrame.insetBy(dx: -8.0, dy: -12.0)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
