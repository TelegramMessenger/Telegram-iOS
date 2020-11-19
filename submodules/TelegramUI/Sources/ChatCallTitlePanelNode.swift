import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import StickerResources
import PhotoResources
import TelegramStringFormatting
import AnimatedCountLabelNode
import AnimatedNavigationStripeNode
import ContextUI
import RadialStatusNode
import AnimatedAvatarSetNode

final class ChatCallTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    
    private let tapButton: HighlightTrackingButtonNode
    
    private let joinButton: HighlightableButtonNode
    private let joinButtonTitleNode: ImmediateTextNode
    private let joinButtonBackgroundNode: ASImageNode
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let muteIconNode: ASImageNode
    
    private let separatorNode: ASDisplayNode

    private var theme: PresentationTheme?
    private var currentLayout: (CGFloat, CGFloat, CGFloat)?
    
    private var activeGroupCallInfo: ChatActiveGroupCallInfo?

    private let queue = Queue()
    
    init(context: AccountContext) {
        self.context = context
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.joinButton = HighlightableButtonNode()
        self.joinButtonTitleNode = ImmediateTextNode()
        self.joinButtonBackgroundNode = ASImageNode()
        
        self.titleNode = ImmediateTextNode()
        self.textNode = ImmediateTextNode()
        
        self.muteIconNode = ASImageNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.muteIconNode)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.addSubnode(self.tapButton)
        
        self.joinButton.addSubnode(self.joinButtonBackgroundNode)
        self.joinButton.addSubnode(self.joinButtonTitleNode)
        self.addSubnode(self.joinButton)
        self.joinButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        
        self.addSubnode(self.separatorNode)
    }
    
    deinit {
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 50.0
        
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight))
        
        self.activeGroupCallInfo = interfaceState.activeGroupCallInfo
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            
            self.backgroundColor = interfaceState.theme.chat.historyNavigation.fillColor
            self.separatorNode.backgroundColor = interfaceState.theme.chat.historyNavigation.strokeColor
            
            self.joinButtonTitleNode.attributedText = NSAttributedString(string: interfaceState.strings.Channel_JoinChannel.uppercased(), font: Font.semibold(15.0), textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)
            self.joinButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: interfaceState.theme.chat.inputPanel.actionControlFillColor)
            
            //TODO:localize
            self.titleNode.attributedText = NSAttributedString(string: "Voice Chat", font: Font.semibold(15.0), textColor: interfaceState.theme.chat.inputPanel.primaryTextColor)
            self.textNode.attributedText = NSAttributedString(string: "4 members", font: Font.regular(13.0), textColor: interfaceState.theme.chat.inputPanel.secondaryTextColor)
            
            self.muteIconNode.image = PresentationResourcesChat.chatTitleMuteIcon(interfaceState.theme)
        }
        
        
        let joinButtonTitleSize = self.joinButtonTitleNode.updateLayout(CGSize(width: 150.0, height: .greatestFiniteMagnitude))
        let joinButtonSize = CGSize(width: joinButtonTitleSize.width + 20.0, height: 28.0)
        let joinButtonFrame = CGRect(origin: CGPoint(x: width - rightInset - 7.0 - joinButtonSize.width, y: floor((panelHeight - joinButtonSize.height) / 2.0)), size: joinButtonSize)
        transition.updateFrame(node: self.joinButton, frame: joinButtonFrame)
        transition.updateFrame(node: self.joinButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: joinButtonFrame.size))
        transition.updateFrame(node: self.joinButtonTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((joinButtonFrame.width - joinButtonTitleSize.width) / 2.0), y: floorToScreenPixels((joinButtonFrame.height - joinButtonTitleSize.height) / 2.0)), size: joinButtonTitleSize))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: width, height: .greatestFiniteMagnitude))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: 10.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: textSize))
        
        if let image = self.muteIconNode.image {
            transition.updateFrame(node: self.muteIconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + 5.0), size: image.size))
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc private func tapped() {
        guard let interfaceInteraction = self.interfaceInteraction else {
            return
        }
        guard let activeGroupCallInfo = self.activeGroupCallInfo else {
            return
        }
        interfaceInteraction.joinGroupCall(activeGroupCallInfo.activeCall)
    }
}

