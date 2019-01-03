import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatRestrictedInputPanelNode: ChatInputPanelNode {
    private let textNode: ImmediateTextNode
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 2
        self.textNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.textNode)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        if let renderedPeer = interfaceState.renderedPeer, let channel = renderedPeer.peer as? TelegramChannel, let bannedRights = channel.bannedRights {
            if bannedRights.untilDate != 0 && bannedRights.untilDate != Int32.max {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RestrictedTextTimed(stringForFullDate(timestamp: bannedRights.untilDate, strings: interfaceState.strings, dateTimeFormat: interfaceState.dateTimeFormat)).0, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else if bannedRights.personal {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_RestrictedText, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            } else {
                self.textNode.attributedText = NSAttributedString(string: interfaceState.strings.Conversation_DefaultRestrictedText, font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            }
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightInset - 8.0 * 2.0, height: panelHeight))
        
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - textSize.width) / 2.0), y: floor((panelHeight - textSize.height) / 2.0)), size: textSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
