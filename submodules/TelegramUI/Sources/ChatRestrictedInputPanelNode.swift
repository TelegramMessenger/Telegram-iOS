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

final class ChatRestrictedInputPanelNode: ChatInputPanelNode {
    private let textNode: ImmediateTextNode
    private var iconView: UIImageView?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 2
        self.textNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        let bannedPermission: (Int32, Bool)?
        if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel {
            bannedPermission = channel.hasBannedPermission(.banSendMessages)
        } else if let group = interfaceState.renderedPeer?.peer as? TelegramGroup {
            if group.hasBannedPermission(.banSendMessages) {
                bannedPermission = (Int32.max, false)
            } else {
                bannedPermission = nil
            }
        } else {
            bannedPermission = nil
        }
        
        var iconImage: UIImage?
        
        if let threadData = interfaceState.threadData, threadData.isClosed {
            iconImage = PresentationResourcesChat.chatPanelLockIcon(interfaceState.theme)
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelTopicClosedText, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        } else if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isForum), case .peer = interfaceState.chatLocation {
            self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Chat_PanelForumModeReplyText, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
        } else if let (untilDate, personal) = bannedPermission {
            if personal && untilDate != 0 && untilDate != Int32.max {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RestrictedTextTimed(stringForFullDate(timestamp: untilDate, strings: interfaceState.strings, dateTimeFormat: interfaceState.dateTimeFormat)).string, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else if personal {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RestrictedText, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_DefaultRestrictedText, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            }
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightInset - 8.0 * 2.0, height: panelHeight))
        
        let textFrame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - textSize.width) / 2.0), y: floor((panelHeight - textSize.height) / 2.0)), size: textSize)
        self.textNode.frame = textFrame
        
        if let iconImage = iconImage {
            let iconView: UIImageView
            if let current = self.iconView {
                iconView = current
            } else {
                iconView = UIImageView()
                self.iconView = iconView
                self.view.addSubview(iconView)
            }
            iconView.image = iconImage
            iconView.frame = CGRect(origin: CGPoint(x: textFrame.minX - 4.0 - iconImage.size.width, y: textFrame.minY + UIScreenPixel + floorToScreenPixels((textFrame.height - iconImage.size.height) / 2.0)), size: iconImage.size)
        } else if let iconView = self.iconView {
            self.iconView = nil
            iconView.removeFromSuperview()
        }
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
