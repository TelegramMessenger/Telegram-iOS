import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore

private enum ChatInfoTitleButton {
    case search
    case info
    case mute
    case unmute
    
    func title(_ strings: PresentationStrings) -> String {
        switch self {
            case .search:
                return strings.Common_Search
            case .info:
                return strings.Conversation_Info
            case .mute:
                return strings.Conversation_Mute
            case .unmute:
                return strings.Conversation_Unmute
        }
    }
}

private func peerButtons(_ peer: Peer) -> [ChatInfoTitleButton] {
    if let _ = peer as? TelegramUser {
        return [.search, .info]
    } else {
        return [.search, .mute]
    }
}

final class ChatInfoTitlePanelNode: ChatTitleAccessoryPanelNode {
    private var theme: PresentationTheme?
    
    private let separatorNode: ASDisplayNode
    private var buttons: [(ChatInfoTitleButton, UIButton)] = []
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let themeUpdated = self.theme !== interfaceState.theme
        self.theme = interfaceState.theme
        
        let panelHeight: CGFloat = 44.0
        
        if themeUpdated {
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
            self.backgroundColor = interfaceState.theme.rootController.navigationBar.backgroundColor
        }
        
        let updatedButtons: [ChatInfoTitleButton]
        if let peer = interfaceState.peer {
            updatedButtons = peerButtons(peer)
        } else {
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
            for (_, view) in self.buttons {
                view.removeFromSuperview()
            }
            self.buttons.removeAll()
            for button in updatedButtons {
                let view = UIButton()
                view.setTitle(button.title(interfaceState.strings), for: [])
                view.titleLabel?.font = Font.regular(17.0)
                view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor, for: [])
                view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(0.7), for: [.highlighted])
                view.addTarget(self, action: #selector(self.buttonPressed(_:)), for: [.touchUpInside])
                self.view.addSubview(view)
                self.buttons.append((button, view))
            }
        }
        
        if !self.buttons.isEmpty {
            let buttonWidth = floor(width / CGFloat(self.buttons.count))
            var nextButtonOrigin: CGFloat = 0.0
            for (_, view) in self.buttons {
                view.frame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                nextButtonOrigin += buttonWidth
            }
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc func buttonPressed(_ view: UIButton) {
        for (button, buttonView) in self.buttons {
            if buttonView === view {
                switch button {
                    case .info:
                        self.interfaceInteraction?.openPeerInfo()
                    case .mute:
                        self.interfaceInteraction?.togglePeerNotifications()
                    case .unmute:
                        self.interfaceInteraction?.togglePeerNotifications()
                    case .search:
                        self.interfaceInteraction?.beginMessageSearch()
                }
                break
            }
        }
    }
}
