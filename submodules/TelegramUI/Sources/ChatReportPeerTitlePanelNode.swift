import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import LocalizedPeerData
import TelegramStringFormatting

private enum ChatReportPeerTitleButton: Equatable {
    case block
    case addContact(String?)
    case shareMyPhoneNumber
    case reportSpam
    case reportUserSpam
    case reportIrrelevantGeoLocation
    case unarchive
    
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
            case .unarchive:
                return strings.Conversation_Unarchive
        }
    }
}

private func peerButtons(_ state: ChatPresentationInterfaceState) -> [ChatReportPeerTitleButton] {
    var buttons: [ChatReportPeerTitleButton] = []
    if let peer = state.renderedPeer?.chatMainPeer as? TelegramUser, let contactStatus = state.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings {
        if peerStatusSettings.contains(.autoArchived) {
            if peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.canReport) {
                if peer.isDeleted {
                    buttons.append(.reportUserSpam)
                } else {
                    if !state.peerIsBlocked {
                        buttons.append(.block)
                    }
                }
            }
            
            buttons.append(.unarchive)
        } else if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
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
        } else if let contactStatus = state.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings, peerStatusSettings.contains(.autoArchived) {
            buttons.append(.reportUserSpam)
            buttons.append(.unarchive)
        } else {
            buttons.append(.reportSpam)
        }
    }
    return buttons
}

private final class ChatInfoTitlePanelInviteInfoNode: ASDisplayNode {
    private var theme: PresentationTheme?
    
    private let labelNode: ImmediateTextNode
    private let filledBackgroundFillNode: LinkHighlightingNode
    private let filledBackgroundNode: LinkHighlightingNode
    
    init(openInvitePeer: @escaping () -> Void) {
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.textAlignment = .center
        
        self.filledBackgroundFillNode = LinkHighlightingNode(color: .clear)
        self.filledBackgroundNode = LinkHighlightingNode(color: .clear)
        
        super.init()
        
        self.addSubnode(self.filledBackgroundFillNode)
        self.addSubnode(self.filledBackgroundNode)
        self.addSubnode(self.labelNode)
        
        self.labelNode.highlightAttributeAction = { attributes in
            for (key, _) in attributes {
                if key.rawValue == "_Link" {
                    return key
                }
            }
            return nil
        }
        self.labelNode.tapAttributeAction = { attributes, _ in
            for (key, _) in attributes {
                if key.rawValue == "_Link" {
                    openInvitePeer()
                }
            }
        }
    }
    
    func update(width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, chatPeer: Peer, invitedBy: Peer, transition: ContainedViewLayoutTransition) -> CGFloat {
        let primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
        
        if self.theme !== theme {
            self.theme = theme
            
            self.labelNode.linkHighlightColor = primaryTextColor.withAlphaComponent(0.3)
        }
        
        let topInset: CGFloat = 6.0
        let bottomInset: CGFloat = 6.0
        let sideInset: CGFloat = 16.0
        
        let stringAndRanges: (String, [(Int, NSRange)])
        if let channel = chatPeer as? TelegramChannel, case .broadcast = channel.info {
            stringAndRanges = strings.Conversation_NoticeInvitedByInChannel(invitedBy.compactDisplayTitle)
        } else {
            stringAndRanges = strings.Conversation_NoticeInvitedByInGroup(invitedBy.compactDisplayTitle)
        }
        
        let attributedString = NSMutableAttributedString(string: stringAndRanges.0, font: Font.regular(13.0), textColor: primaryTextColor)
        
        let boldAttributes = [NSAttributedString.Key.font: Font.semibold(13.0), NSAttributedString.Key(rawValue: "_Link"): true as NSNumber]
        for (_, range) in stringAndRanges.1 {
            attributedString.addAttributes(boldAttributes, range: range)
        }
        
        self.labelNode.attributedText = attributedString
        let labelLayout = self.labelNode.updateLayoutFullInfo(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        var labelRects = labelLayout.linesRects()
        if labelRects.count > 1 {
            let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                            labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            labelRects[index].size.width = labelRects[index + j].size.width
                        }
                    }
                }
            }
        }
        for i in 0 ..< labelRects.count {
            labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
            labelRects[i].size.height = 20.0
            labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
        }
        
        let backgroundLayout = self.filledBackgroundNode.asyncLayout()
        let backgroundFillLayout = self.filledBackgroundFillNode.asyncLayout()
        let backgroundApply = backgroundLayout(theme.chat.serviceMessage.components.withDefaultWallpaper.dateFillStatic, labelRects, 10.0, 10.0, 0.0)
        let backgroundFillApply = backgroundFillLayout(theme.chat.serviceMessage.components.withDefaultWallpaper.dateFillFloating, labelRects, 10.0, 10.0, 0.0)
        backgroundApply()
        backgroundFillApply()
        
        let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
        
        let labelFrame = CGRect(origin: CGPoint(x: floor((width - labelLayout.size.width) / 2.0), y: topInset + floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
        self.labelNode.frame = labelFrame
        self.filledBackgroundNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
        self.filledBackgroundFillNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
        
        return topInset + backgroundSize.height + bottomInset
    }
}

private final class ChatInfoTitlePanelPeerNearbyInfoNode: ASDisplayNode {
    private var theme: PresentationTheme?
    
    private let labelNode: ImmediateTextNode
    private let filledBackgroundNode: LinkHighlightingNode
    
    private let openPeersNearby: () -> Void
    
    init(openPeersNearby: @escaping () -> Void) {
        self.openPeersNearby = openPeersNearby
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.textAlignment = .center
        
        self.filledBackgroundNode = LinkHighlightingNode(color: .clear)
        
        super.init()
        
        self.addSubnode(self.filledBackgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        self.openPeersNearby()
    }
    
    func update(width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, chatPeer: Peer, distance: Int32, transition: ContainedViewLayoutTransition) -> CGFloat {
        let primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
        
        if self.theme !== theme {
            self.theme = theme
            
            self.labelNode.linkHighlightColor = primaryTextColor.withAlphaComponent(0.3)
        }
        
        let topInset: CGFloat = 6.0
        let bottomInset: CGFloat = 6.0
        let sideInset: CGFloat = 16.0
        
        let stringAndRanges = strings.Conversation_PeerNearbyDistance(chatPeer.compactDisplayTitle, shortStringForDistance(strings: strings, distance: distance))
        
        let attributedString = NSMutableAttributedString(string: stringAndRanges.0, font: Font.regular(13.0), textColor: primaryTextColor)
        
        let boldAttributes = [NSAttributedString.Key.font: Font.semibold(13.0), NSAttributedString.Key(rawValue: "_Link"): true as NSNumber]
        for (_, range) in stringAndRanges.1.prefix(1) {
            attributedString.addAttributes(boldAttributes, range: range)
        }
        
        self.labelNode.attributedText = attributedString
        let labelLayout = self.labelNode.updateLayoutFullInfo(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        var labelRects = labelLayout.linesRects()
        if labelRects.count > 1 {
            let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                            labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            labelRects[index].size.width = labelRects[index + j].size.width
                        }
                    }
                }
            }
        }
        for i in 0 ..< labelRects.count {
            labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
            labelRects[i].size.height = 20.0
            labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
        }
        
        let backgroundLayout = self.filledBackgroundNode.asyncLayout()
        let serviceColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper)
        let backgroundApply = backgroundLayout(serviceColor.fill, labelRects, 10.0, 10.0, 0.0)
        backgroundApply()
        
        let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
        
        let labelFrame = CGRect(origin: CGPoint(x: floor((width - labelLayout.size.width) / 2.0), y: topInset + floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
        self.labelNode.frame = labelFrame
        self.filledBackgroundNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
        
        return topInset + backgroundSize.height + bottomInset
    }
}

final class ChatReportPeerTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private let closeButton: HighlightableButtonNode
    private var buttons: [(ChatReportPeerTitleButton, UIButton)] = []
    
    private var theme: PresentationTheme?
    
    private var inviteInfoNode: ChatInfoTitlePanelInviteInfoNode?
    private var peerNearbyInfoNode: ChatInfoTitlePanelPeerNearbyInfoNode?
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelEncircledCloseIconImage(interfaceState.theme), for: [])
            self.backgroundNode.backgroundColor = interfaceState.theme.chat.historyNavigation.fillColor
            self.separatorNode.backgroundColor = interfaceState.theme.chat.historyNavigation.strokeColor
        }
        
        var panelHeight: CGFloat = 40.0
        
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
                var areaWidth = width - maxInset * 2.0 - additionalRightInset
                let maxButtonWidth = floor(areaWidth / CGFloat(self.buttons.count))
                let buttonSizes = self.buttons.map { button -> CGFloat in
                    return button.1.sizeThatFits(CGSize(width: maxButtonWidth, height: 100.0)).width
                }
                let buttonsWidth = buttonSizes.reduce(0.0, +)
                if buttonsWidth < areaWidth - 20.0 {
                    areaWidth += additionalRightInset
                }
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
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: panelHeight)))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        var chatPeer: Peer?
        if let renderedPeer = interfaceState.renderedPeer {
            chatPeer = renderedPeer.peers[renderedPeer.peerId]
        }
        if let chatPeer = chatPeer, let invitedBy = interfaceState.contactStatus?.invitedBy {
            var inviteInfoTransition = transition
            let inviteInfoNode: ChatInfoTitlePanelInviteInfoNode
            if let current = self.inviteInfoNode {
                inviteInfoNode = current
            } else {
                inviteInfoTransition = .immediate
                inviteInfoNode = ChatInfoTitlePanelInviteInfoNode(openInvitePeer: { [weak self] in
                    self?.interfaceInteraction?.navigateToProfile(invitedBy.id)
                })
                self.addSubnode(inviteInfoNode)
                self.inviteInfoNode = inviteInfoNode
                inviteInfoNode.alpha = 0.0
                transition.updateAlpha(node: inviteInfoNode, alpha: 1.0)
            }
            
            if let inviteInfoNode = self.inviteInfoNode {
                let inviteHeight = inviteInfoNode.update(width: width, theme: interfaceState.theme, strings: interfaceState.strings, wallpaper: interfaceState.chatWallpaper, chatPeer: chatPeer, invitedBy: invitedBy, transition: inviteInfoTransition)
                inviteInfoTransition.updateFrame(node: inviteInfoNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight), size: CGSize(width: width, height: inviteHeight)))
                panelHeight += inviteHeight
            }
        } else if let inviteInfoNode = self.inviteInfoNode {
            self.inviteInfoNode = nil
            transition.updateAlpha(node: inviteInfoNode, alpha: 0.0, completion: { [weak inviteInfoNode] _ in
                inviteInfoNode?.removeFromSupernode()
            })
        }
        
        if let chatPeer = chatPeer, let distance = interfaceState.contactStatus?.peerStatusSettings?.geoDistance {
            var peerNearbyInfoTransition = transition
            let peerNearbyInfoNode: ChatInfoTitlePanelPeerNearbyInfoNode
            if let current = self.peerNearbyInfoNode {
                peerNearbyInfoNode = current
            } else {
                peerNearbyInfoTransition = .immediate
                peerNearbyInfoNode = ChatInfoTitlePanelPeerNearbyInfoNode(openPeersNearby: { [weak self] in
                    self?.interfaceInteraction?.openPeersNearby()
                })
                self.addSubnode(peerNearbyInfoNode)
                self.peerNearbyInfoNode = peerNearbyInfoNode
                peerNearbyInfoNode.alpha = 0.0
                transition.updateAlpha(node: peerNearbyInfoNode, alpha: 1.0)
            }
            
            if let peerNearbyInfoNode = self.peerNearbyInfoNode {
                let peerNearbyHeight = peerNearbyInfoNode.update(width: width, theme: interfaceState.theme, strings: interfaceState.strings, wallpaper: interfaceState.chatWallpaper, chatPeer: chatPeer, distance: distance, transition: peerNearbyInfoTransition)
                peerNearbyInfoTransition.updateFrame(node: peerNearbyInfoNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight), size: CGSize(width: width, height: peerNearbyHeight)))
                panelHeight += peerNearbyHeight
            }
        } else if let peerNearbyInfoNode = self.peerNearbyInfoNode {
            self.peerNearbyInfoNode = nil
            transition.updateAlpha(node: peerNearbyInfoNode, alpha: 0.0, completion: { [weak peerNearbyInfoNode] _ in
                peerNearbyInfoNode?.removeFromSupernode()
            })
        }
        
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
                    case .unarchive:
                        self.interfaceInteraction?.unarchivePeer()
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
