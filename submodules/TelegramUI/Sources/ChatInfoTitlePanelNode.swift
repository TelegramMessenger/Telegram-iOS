import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ChatPresentationInterfaceState

private enum ChatInfoTitleButton {
    case search
    case info
    case mute
    case unmute
    case call
    case report
    case unarchive
    
    func title(_ strings: PresentationStrings) -> String {
        switch self {
            case .search:
                return strings.Common_Search
            case .info:
                return strings.Conversation_Info
            case .mute:
                return strings.Conversation_TitleMute
            case .unmute:
                return strings.Conversation_TitleUnmute
            case .call:
                return strings.Conversation_Call
            case .report:
                return strings.ReportPeer_Report
            case .unarchive:
                return strings.ChatList_UnarchiveAction
        }
    }
    
    func icon(_ theme: PresentationTheme) -> UIImage? {
        switch self {
            case .search:
                return PresentationResourcesChat.chatTitlePanelSearchImage(theme)
            case .info:
                return PresentationResourcesChat.chatTitlePanelInfoImage(theme)
            case .mute:
                return PresentationResourcesChat.chatTitlePanelMuteImage(theme)
            case .unmute:
                return PresentationResourcesChat.chatTitlePanelUnmuteImage(theme)
            case .call:
                return PresentationResourcesChat.chatTitlePanelCallImage(theme)
            case .report:
                return PresentationResourcesChat.chatTitlePanelReportImage(theme)
            case .unarchive:
                return PresentationResourcesChat.chatTitlePanelUnarchiveImage(theme)
        }
    }
}

private func peerButtons(_ peer: Peer, interfaceState: ChatPresentationInterfaceState) -> [ChatInfoTitleButton] {
    let muteAction: ChatInfoTitleButton
    if interfaceState.peerIsMuted {
        muteAction = .unmute
    } else {
        muteAction = .mute
    }
    
    let infoButton: ChatInfoTitleButton
    if interfaceState.isArchived {
        infoButton = .unarchive
    } else {
        infoButton = .info
    }
    
    if let peer = peer as? TelegramUser {
        var buttons: [ChatInfoTitleButton] = [.search, muteAction]
        if peer.botInfo == nil && interfaceState.callsAvailable {
            buttons.append(.call)
        }
        
        buttons.append(infoButton)
        return buttons
    } else if let _ = peer as? TelegramSecretChat {
        var buttons: [ChatInfoTitleButton] = [.search, muteAction]
        buttons.append(.call)
        buttons.append(.info)
        return buttons
    } else if let channel = peer as? TelegramChannel {
        if channel.flags.contains(.isCreator) || channel.addressName == nil {
            return [.search, muteAction, infoButton]
        } else {
            return [.search, .report, muteAction, infoButton]
        }
    } else if let group = peer as? TelegramGroup {
        if case .creator = group.role {
            return [.search, muteAction, infoButton]
        } else {
            return [.search, muteAction, infoButton]
        }
    } else {
        return [.search, muteAction, infoButton]
    }
}

private let buttonFont = Font.medium(10.0)

private final class ChatInfoTitlePanelButtonNode: HighlightableButtonNode {
    init() {
        super.init()
        
        self.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.displaysAsynchronously = false
        
        self.titleNode.displaysAsynchronously = false
        
        self.laysOutHorizontally = false
    }
    
    func setup(text: String, color: UIColor, icon: UIImage?) {
        self.setTitle(text, with: buttonFont, with: color, for: [])
        self.setImage(icon, for: [])
        if let icon = icon {
            self.contentSpacing = max(0.0, 32.0 - icon.size.height)
        }
    }
}

final class ChatInfoTitlePanelNode: ChatTitleAccessoryPanelNode {
    private var theme: PresentationTheme?

    private let separatorNode: ASDisplayNode
    private var buttons: [(ChatInfoTitleButton, ChatInfoTitlePanelButtonNode)] = []
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()

        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let themeUpdated = self.theme !== interfaceState.theme
        self.theme = interfaceState.theme
        
        let panelHeight: CGFloat = 55.0
        
        if themeUpdated {
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }
        
        let updatedButtons: [ChatInfoTitleButton]
        switch interfaceState.chatLocation {
        case .peer:
            if let peer = interfaceState.renderedPeer?.peer {
                updatedButtons = peerButtons(peer, interfaceState: interfaceState)
            } else {
                updatedButtons = []
            }
        case .replyThread, .feed:
            updatedButtons = []
        }
        
        var buttonsUpdated = false
        if self.buttons.count != updatedButtons.count {
            buttonsUpdated = true
        } else {
            for i in 0 ..< updatedButtons.count {
                if self.buttons[i].0 != updatedButtons[i] {
                    buttonsUpdated = true
                    break
                }
            }
        }
        
        if buttonsUpdated || themeUpdated {
            for (_, buttonNode) in self.buttons {
                buttonNode.removeFromSupernode()
            }
            self.buttons.removeAll()
            for button in updatedButtons {
                let buttonNode = ChatInfoTitlePanelButtonNode()
                buttonNode.laysOutHorizontally = false
                
                buttonNode.setup(text: button.title(interfaceState.strings), color: interfaceState.theme.chat.inputPanel.panelControlAccentColor, icon: button.icon(interfaceState.theme))
                
                buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: [.touchUpInside])
                self.addSubnode(buttonNode)
                self.buttons.append((button, buttonNode))
            }
        }
        
        if !self.buttons.isEmpty {
            let buttonWidth = floor((width - leftInset - rightInset) / CGFloat(self.buttons.count))
            var nextButtonOrigin: CGFloat = leftInset
            for (_, buttonNode) in self.buttons {
                buttonNode.frame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                nextButtonOrigin += buttonWidth
            }
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return LayoutResult(backgroundHeight: panelHeight, insetHeight: panelHeight)
    }
    
    @objc func buttonPressed(_ node: HighlightableButtonNode) {
        for (button, buttonNode) in self.buttons {
            if buttonNode === node {
                switch button {
                    case .info:
                        self.interfaceInteraction?.openPeerInfo()
                    case .mute:
                        self.interfaceInteraction?.togglePeerNotifications()
                    case .unmute:
                        self.interfaceInteraction?.togglePeerNotifications()
                    case .search:
                        self.interfaceInteraction?.beginMessageSearch(.everything, "")
                    case .call:
                        self.interfaceInteraction?.beginCall(false)
                    case .report:
                        self.interfaceInteraction?.reportPeer()
                    case .unarchive:
                        self.interfaceInteraction?.unarchiveChat()
                }
                break
            }
        }
    }
}
