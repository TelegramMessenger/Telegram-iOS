import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import LocalizedPeerData

private enum ChatReportPeerTitleButton: Equatable {
    case block
    case addContact(String?)
    case shareMyPhoneNumber
    case reportSpam
    case reportUserSpam
    case reportIrrelevantGeoLocation
    
    func title(strings: PresentationStrings) -> String {
        switch self {
            case .block:
                return strings.Conversation_BlockUser
            case let .addContact(name):
                if let name = name {
                    return strings.Conversation_AddNameToContacts(name).0
                } else {
                    return strings.Conversation_AddToContacts
                }
            case .shareMyPhoneNumber:
                return strings.Conversation_ShareMyPhoneNumber
            case .reportSpam:
                return strings.Conversation_ReportSpamAndLeave
            case .reportUserSpam:
                return strings.Conversation_ReportSpam
            case .reportIrrelevantGeoLocation:
                return strings.Conversation_ReportGroupLocation
        }
    }
}

private func peerButtons(_ state: ChatPresentationInterfaceState) -> [ChatReportPeerTitleButton] {
    var buttons: [ChatReportPeerTitleButton] = []
    if let peer = state.renderedPeer?.chatMainPeer as? TelegramUser, let contactStatus = state.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings {
        if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
            if peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.canReport) {
                if !state.peerIsBlocked {
                    buttons.append(.block)
                }
            }
            if buttons.isEmpty, let phone = peer.phone, !phone.isEmpty {
                buttons.append(.addContact(peer.compactDisplayTitle))
            } else {
                buttons.append(.addContact(nil))
            }
        } else {
            if peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.canReport) {
                if peer.isDeleted {
                    buttons.append(.reportUserSpam)
                } else {
                    if !state.peerIsBlocked {
                        buttons.append(.block)
                    }
                }
            }
        }
        if buttons.isEmpty {
            if peerStatusSettings.contains(.canShareContact) {
                buttons.append(.shareMyPhoneNumber)
            }
        }
    } else if let _ = state.renderedPeer?.chatMainPeer {
        if let contactStatus = state.contactStatus, contactStatus.canReportIrrelevantLocation, let peerStatusSettings = contactStatus.peerStatusSettings, peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
            buttons.append(.reportIrrelevantGeoLocation)
        } else {
            buttons.append(.reportSpam)
        }
    }
    return buttons
}

final class ChatReportPeerTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let separatorNode: ASDisplayNode
    
    private let closeButton: HighlightableButtonNode
    private var buttons: [(ChatReportPeerTitleButton, UIButton)] = []
    
    private var theme: PresentationTheme?
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelEncircledCloseIconImage(interfaceState.theme), for: [])
            self.backgroundColor = interfaceState.theme.chat.historyNavigation.fillColor
            self.separatorNode.backgroundColor = interfaceState.theme.chat.historyNavigation.strokeColor
        }
        
        let panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 14.0 + rightInset
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize))
        
        let updatedButtons: [ChatReportPeerTitleButton]
        if let _ = interfaceState.renderedPeer?.peer {
            updatedButtons = peerButtons(interfaceState)
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
        
        if buttonsUpdated {
            for (_, view) in self.buttons {
                view.removeFromSuperview()
            }
            self.buttons.removeAll()
            for button in updatedButtons {
                let view = UIButton()
                view.setTitle(button.title(strings: interfaceState.strings), for: [])
                view.titleLabel?.font = Font.regular(16.0)
                switch button {
                    case .block, .reportSpam, .reportUserSpam:
                    view.setTitleColor(interfaceState.theme.chat.inputPanel.panelControlDestructiveColor, for: [])
                    view.setTitleColor(interfaceState.theme.chat.inputPanel.panelControlDestructiveColor.withAlphaComponent(0.7), for: [.highlighted])
                    default:
                    view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor, for: [])
                    view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(0.7), for: [.highlighted])
                }
                view.addTarget(self, action: #selector(self.buttonPressed(_:)), for: [.touchUpInside])
                self.view.addSubview(view)
                self.buttons.append((button, view))
            }
        }
        
        if !self.buttons.isEmpty {
            let maxInset = max(contentRightInset, leftInset)
            if self.buttons.count == 1 {
                let buttonWidth = floor((width - maxInset * 2.0) / CGFloat(self.buttons.count))
                var nextButtonOrigin: CGFloat = maxInset
                for (_, view) in self.buttons {
                    view.frame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                    nextButtonOrigin += buttonWidth
                }
            } else {
                let additionalRightInset: CGFloat = 36.0
                let areaWidth = width - maxInset * 2.0 - additionalRightInset
                let maxButtonWidth = floor(areaWidth / CGFloat(self.buttons.count))
                let buttonSizes = self.buttons.map { button -> CGFloat in
                    return button.1.sizeThatFits(CGSize(width: maxButtonWidth, height: 100.0)).width
                }
                let buttonsWidth = buttonSizes.reduce(0.0, +)
                let maxButtonSpacing = floor((areaWidth - buttonsWidth) / CGFloat(self.buttons.count - 1))
                let buttonSpacing = min(maxButtonSpacing, 110.0)
                let updatedButtonsWidth = buttonsWidth + CGFloat(self.buttons.count - 1) * buttonSpacing
                var nextButtonOrigin = maxInset + floor((areaWidth - updatedButtonsWidth) / 2.0)
                
                let buttonWidth = floor(updatedButtonsWidth / CGFloat(self.buttons.count))
                for (_, view) in self.buttons {
                    view.frame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                    nextButtonOrigin += buttonWidth
                }
            }
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc func buttonPressed(_ view: UIButton) {
        for (button, buttonView) in self.buttons {
            if buttonView === view {
                switch button {
                    case .shareMyPhoneNumber:
                        self.interfaceInteraction?.shareAccountContact()
                    case .block, .reportSpam, .reportUserSpam:
                        self.interfaceInteraction?.reportPeer()
                    case .addContact:
                        self.interfaceInteraction?.presentPeerContact()
                    case .reportIrrelevantGeoLocation:
                        self.interfaceInteraction?.reportPeerIrrelevantGeoLocation()
                }
                break
            }
        }
    }
    
    @objc func closePressed() {
        self.interfaceInteraction?.dismissReportPeer()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.closeButton.hitTest(CGPoint(x: point.x - self.closeButton.frame.minX, y: point.y - self.closeButton.frame.minY), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
