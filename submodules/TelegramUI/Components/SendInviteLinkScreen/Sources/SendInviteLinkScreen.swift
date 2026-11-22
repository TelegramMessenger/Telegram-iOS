import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import TelegramPresentationData
import AccountContext
import TelegramCore
import ResizableSheetComponent
import PresentationDataUtils
import Markdown
import UndoUI
import AnimatedAvatarSetNode
import AvatarNode
import TelegramStringFormatting
import ChatMessagePaymentAlertController
import ResizableSheetComponent
import ButtonComponent
import BundleIconComponent
import GlassBarButtonComponent
import MultilineTextComponent

private func sendInviteLinkHasInviteSection(subject: SendInviteLinkScreenSubject, peers: [TelegramForbiddenInvitePeer]) -> Bool {
    let premiumRestrictedUsers = peers.filter { peer in
        return peer.canInviteWithPremium
    }
    
    switch subject {
    case let .chat(_, link):
        if premiumRestrictedUsers.count == peers.count && link == nil {
            return false
        } else if link != nil && !premiumRestrictedUsers.isEmpty && peers.allSatisfy({ $0.premiumRequiredToContact }) {
            return false
        } else {
            return true
        }
    case .groupCall:
        return true
    }
}

private final class SendInviteLinkContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: SendInviteLinkScreenSubject
    let peers: [TelegramForbiddenInvitePeer]
    let peerPresences: [EnginePeer.Id: EnginePeer.Presence]
    let selectedItems: Set<EnginePeer.Id>
    let theme: PresentationTheme
    let toggleSelection: (EnginePeer.Id) -> Void
    let openPremium: () -> Void
    
    init(
        context: AccountContext,
        subject: SendInviteLinkScreenSubject,
        peers: [TelegramForbiddenInvitePeer],
        peerPresences: [EnginePeer.Id: EnginePeer.Presence],
        selectedItems: Set<EnginePeer.Id>,
        theme: PresentationTheme,
        toggleSelection: @escaping (EnginePeer.Id) -> Void,
        openPremium: @escaping () -> Void
    ) {
        self.context = context
        self.subject = subject
        self.peers = peers
        self.peerPresences = peerPresences
        self.selectedItems = selectedItems
        self.theme = theme
        self.toggleSelection = toggleSelection
        self.openPremium = openPremium
    }
    
    static func ==(lhs: SendInviteLinkContentComponent, rhs: SendInviteLinkContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.peerPresences != rhs.peerPresences {
            return false
        }
        if lhs.selectedItems != rhs.selectedItems {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var avatarsNode: AnimatedAvatarSetNode?
        private let avatarsContext = AnimatedAvatarSetContext()
        
        private var premiumTitle: ComponentView<Empty>?
        private var premiumText: ComponentView<Empty>?
        private var premiumButton: ComponentView<Empty>?
        private var premiumSeparatorLeft: SimpleLayer?
        private var premiumSeparatorRight: SimpleLayer?
        private var premiumSeparatorText: ComponentView<Empty>?
        
        private var title: ComponentView<Empty>?
        private var descriptionText: ComponentView<Empty>?
        
        private let itemContainerView: UIView
        private var items: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var component: SendInviteLinkContentComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 26.0
            
            super.init(frame: frame)
            
            self.addSubview(self.itemContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SendInviteLinkContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let theme = component.theme
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 16.0
            self.itemContainerView.backgroundColor = theme.list.itemBlocksBackgroundColor
            
            let premiumRestrictedUsers = component.peers.filter { peer in
                return peer.canInviteWithPremium
            }
            let hasInviteSection = sendInviteLinkHasInviteSection(subject: component.subject, peers: component.peers)
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 120.0
            
            let avatarsNode: AnimatedAvatarSetNode
            if let current = self.avatarsNode {
                avatarsNode = current
            } else {
                avatarsNode = AnimatedAvatarSetNode()
                self.avatarsNode = avatarsNode
                self.addSubview(avatarsNode.view)
            }
            
            let avatarPeers: [EnginePeer]
            if !premiumRestrictedUsers.isEmpty {
                avatarPeers = premiumRestrictedUsers.map(\.peer)
            } else {
                avatarPeers = component.peers.map(\.peer)
            }
            let avatarsContent = self.avatarsContext.update(peers: avatarPeers.count <= 3 ? avatarPeers : Array(avatarPeers.prefix(upTo: 3)), animated: false)
            let avatarsSize = avatarsNode.update(
                context: component.context,
                content: avatarsContent,
                itemSize: CGSize(width: 64.0, height: 64.0),
                customSpacing: 30.0,
                font: avatarPlaceholderFont(size: 28.0),
                animated: false,
                synchronousLoad: true
            )
            let avatarsFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - avatarsSize.width) * 0.5), y: 48.0), size: avatarsSize)
            transition.setFrame(view: avatarsNode.view, frame: avatarsFrame)
            
            if !premiumRestrictedUsers.isEmpty {
                var premiumItemsTransition = transition
                
                let premiumTitle: ComponentView<Empty>
                if let current = self.premiumTitle {
                    premiumTitle = current
                } else {
                    premiumTitle = ComponentView()
                    self.premiumTitle = premiumTitle
                    premiumItemsTransition = premiumItemsTransition.withAnimation(.none)
                }
                
                let premiumText: ComponentView<Empty>
                if let current = self.premiumText {
                    premiumText = current
                } else {
                    premiumText = ComponentView()
                    self.premiumText = premiumText
                }
                
                let premiumButton: ComponentView<Empty>
                if let current = self.premiumButton {
                    premiumButton = current
                } else {
                    premiumButton = ComponentView()
                    self.premiumButton = premiumButton
                }
                
                let premiumTitleSize = premiumTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.SendInviteLink_TitleUpgradeToPremium, font: Font.semibold(24.0), textColor: theme.list.itemPrimaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let premiumTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - premiumTitleSize.width) * 0.5), y: contentHeight), size: premiumTitleSize)
                if let premiumTitleView = premiumTitle.view {
                    if premiumTitleView.superview == nil {
                        self.addSubview(premiumTitleView)
                    }
                    transition.setFrame(view: premiumTitleView, frame: premiumTitleFrame)
                }
                
                contentHeight += premiumTitleSize.height
                contentHeight += 8.0
                
                let text: String
                switch component.subject {
                case let .chat(peer, _):
                    if premiumRestrictedUsers.count == 1 {
                        if case let .channel(channel) = peer, case .broadcast = channel.info {
                            text = environment.strings.SendInviteLink_ChannelTextContactsAndPremiumOneUser(premiumRestrictedUsers[0].peer.compactDisplayTitle).string
                        } else {
                            text = environment.strings.SendInviteLink_TextContactsAndPremiumOneUser(premiumRestrictedUsers[0].peer.compactDisplayTitle).string
                        }
                    } else {
                        let extraCount = premiumRestrictedUsers.count - 3
                        var peersTextArray: [String] = []
                        for i in 0 ..< min(3, premiumRestrictedUsers.count) {
                            peersTextArray.append("**\(premiumRestrictedUsers[i].peer.compactDisplayTitle)**")
                        }
                        
                        var peersText = ""
                        if #available(iOS 13.0, *) {
                            let listFormatter = ListFormatter()
                            listFormatter.locale = localeWithStrings(environment.strings)
                            if let value = listFormatter.string(from: peersTextArray) {
                                peersText = value
                            }
                        }
                        if peersText.isEmpty {
                            for i in 0 ..< peersTextArray.count {
                                if i != 0 {
                                    peersText.append(", ")
                                }
                                peersText.append(peersTextArray[i])
                            }
                        }
                        
                        if extraCount >= 1 {
                            if case let .channel(channel) = peer, case .broadcast = channel.info {
                                text = environment.strings.SendInviteLink_ChannelTextContactsAndPremiumMultipleUsers(Int32(extraCount)).replacingOccurrences(of: "{user_list}", with: peersText)
                            } else {
                                text = environment.strings.SendInviteLink_TextContactsAndPremiumMultipleUsers(Int32(extraCount)).replacingOccurrences(of: "{user_list}", with: peersText)
                            }
                        } else {
                            if case let .channel(channel) = peer, case .broadcast = channel.info {
                                text = environment.strings.SendInviteLink_ChannelTextContactsAndPremiumOneUser(peersText).string
                            } else {
                                text = environment.strings.SendInviteLink_TextContactsAndPremiumOneUser(peersText).string
                            }
                        }
                    }
                case .groupCall:
                    if premiumRestrictedUsers.count == 1 {
                        text = environment.strings.SendInviteLink_TextCallsRestrictedOneUser(premiumRestrictedUsers[0].peer.compactDisplayTitle).string
                    } else {
                        let extraCount = premiumRestrictedUsers.count - 3
                        var peersTextArray: [String] = []
                        for i in 0 ..< min(3, premiumRestrictedUsers.count) {
                            peersTextArray.append("**\(premiumRestrictedUsers[i].peer.compactDisplayTitle)**")
                        }
                        
                        var peersText = ""
                        if #available(iOS 13.0, *) {
                            let listFormatter = ListFormatter()
                            listFormatter.locale = localeWithStrings(environment.strings)
                            if let value = listFormatter.string(from: peersTextArray) {
                                peersText = value
                            }
                        }
                        if peersText.isEmpty {
                            for i in 0 ..< peersTextArray.count {
                                if i != 0 {
                                    peersText.append(", ")
                                }
                                peersText.append(peersTextArray[i])
                            }
                        }
                        
                        if extraCount >= 1 {
                            text = environment.strings.SendInviteLink_TextCallsRestrictedMultipleUsers(Int32(extraCount)).replacingOccurrences(of: "{user_list}", with: peersText)
                        } else {
                            text = environment.strings.SendInviteLink_TextCallsRestrictedOneUser(peersText).string
                        }
                    }
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.list.itemPrimaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)
                
                let premiumTextSize = premiumText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: text, attributes: MarkdownAttributes(
                            body: body,
                            bold: bold,
                            link: body,
                            linkAttribute: { _ in nil }
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
                )
                let premiumTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - premiumTextSize.width) * 0.5), y: contentHeight), size: premiumTextSize)
                if let premiumTextView = premiumText.view {
                    if premiumTextView.superview == nil {
                        self.addSubview(premiumTextView)
                    }
                    transition.setFrame(view: premiumTextView, frame: premiumTextFrame)
                }
                
                contentHeight += premiumTextSize.height
                contentHeight += 22.0
                
                let premiumButtonGradientColors = [
                    UIColor(rgb: 0x0077ff),
                    UIColor(rgb: 0x6b93ff),
                    UIColor(rgb: 0x8878ff),
                    UIColor(rgb: 0xe46ace)
                ]
                let premiumButtonSize = premiumButton.update(
                    transition: premiumItemsTransition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: premiumButtonGradientColors[0],
                            foreground: .white,
                            pressedColor: premiumButtonGradientColors[0],
                            isShimmering: false,
                            gradient: ButtonComponent.Background.Gradient(colors: premiumButtonGradientColors)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(environment.strings.SendInviteLink_SubscribeToPremiumButton),
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environment.strings.SendInviteLink_SubscribeToPremiumButton,
                                badge: 0,
                                textColor: .white,
                                badgeBackground: .white,
                                badgeForeground: premiumButtonGradientColors[0]
                            ))
                        ),
                        action: {
                            component.openPremium()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 52.0)
                )
                let premiumButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: premiumButtonSize)
                if let premiumButtonView = premiumButton.view {
                    if premiumButtonView.superview == nil {
                        self.addSubview(premiumButtonView)
                    }
                    premiumItemsTransition.setFrame(view: premiumButtonView, frame: premiumButtonFrame)
                }
                contentHeight += premiumButtonSize.height
                
                if hasInviteSection {
                    let premiumSeparatorText: ComponentView<Empty>
                    if let current = self.premiumSeparatorText {
                        premiumSeparatorText = current
                    } else {
                        premiumSeparatorText = ComponentView()
                        self.premiumSeparatorText = premiumSeparatorText
                    }
                    
                    let premiumSeparatorLeft: SimpleLayer
                    if let current = self.premiumSeparatorLeft {
                        premiumSeparatorLeft = current
                    } else {
                        premiumSeparatorLeft = SimpleLayer()
                        self.premiumSeparatorLeft = premiumSeparatorLeft
                        self.layer.addSublayer(premiumSeparatorLeft)
                    }
                    
                    let premiumSeparatorRight: SimpleLayer
                    if let current = self.premiumSeparatorRight {
                        premiumSeparatorRight = current
                    } else {
                        premiumSeparatorRight = SimpleLayer()
                        self.premiumSeparatorRight = premiumSeparatorRight
                        self.layer.addSublayer(premiumSeparatorRight)
                    }
                    
                    premiumSeparatorLeft.backgroundColor = theme.list.itemPlainSeparatorColor.cgColor
                    premiumSeparatorRight.backgroundColor = theme.list.itemPlainSeparatorColor.cgColor
                    
                    contentHeight += 19.0
                    
                    let premiumSeparatorTextSize = premiumSeparatorText.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.SendInviteLink_PremiumOrSendSectionSeparator, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor))
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                    )
                    let premiumSeparatorTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - premiumSeparatorTextSize.width) * 0.5), y: contentHeight), size: premiumSeparatorTextSize)
                    if let premiumSeparatorTextView = premiumSeparatorText.view {
                        if premiumSeparatorTextView.superview == nil {
                            self.addSubview(premiumSeparatorTextView)
                        }
                        transition.setFrame(view: premiumSeparatorTextView, frame: premiumSeparatorTextFrame)
                    }
                    
                    let separatorWidth: CGFloat = 72.0
                    let separatorSpacing: CGFloat = 10.0
                    transition.setFrame(layer: premiumSeparatorLeft, frame: CGRect(origin: CGPoint(x: premiumSeparatorTextFrame.minX - separatorSpacing - separatorWidth, y: premiumSeparatorTextFrame.midY + 1.0), size: CGSize(width: separatorWidth, height: UIScreenPixel)))
                    transition.setFrame(layer: premiumSeparatorRight, frame: CGRect(origin: CGPoint(x: premiumSeparatorTextFrame.maxX + separatorSpacing, y: premiumSeparatorTextFrame.midY + 1.0), size: CGSize(width: separatorWidth, height: UIScreenPixel)))
                    
                    contentHeight += 31.0
                } else {
                    if let premiumSeparatorLeft = self.premiumSeparatorLeft {
                        self.premiumSeparatorLeft = nil
                        premiumSeparatorLeft.removeFromSuperlayer()
                    }
                    if let premiumSeparatorRight = self.premiumSeparatorRight {
                        self.premiumSeparatorRight = nil
                        premiumSeparatorRight.removeFromSuperlayer()
                    }
                    if let premiumSeparatorText = self.premiumSeparatorText {
                        self.premiumSeparatorText = nil
                        premiumSeparatorText.view?.removeFromSuperview()
                    }
                    
                    contentHeight += 14.0
                }
            } else {
                if let premiumTitle = self.premiumTitle {
                    self.premiumTitle = nil
                    premiumTitle.view?.removeFromSuperview()
                }
                if let premiumText = self.premiumText {
                    self.premiumText = nil
                    premiumText.view?.removeFromSuperview()
                }
                if let premiumButton = self.premiumButton {
                    self.premiumButton = nil
                    premiumButton.view?.removeFromSuperview()
                }
            }
            
            if hasInviteSection {
                let title: ComponentView<Empty>
                if let current = self.title {
                    title = current
                } else {
                    title = ComponentView()
                    self.title = title
                }
                
                let descriptionText: ComponentView<Empty>
                if let current = self.descriptionText {
                    descriptionText = current
                } else {
                    descriptionText = ComponentView()
                    self.descriptionText = descriptionText
                }
                
                let titleText: String
                switch component.subject {
                case let .chat(_, link):
                    titleText = link != nil ? environment.strings.SendInviteLink_InviteTitle : environment.strings.SendInviteLink_LinkUnavailableTitle
                case .groupCall:
                    titleText = environment.strings.SendInviteLink_InviteTitle
                }
                
                let titleSize = title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleText, font: Font.semibold(24.0), textColor: theme.list.itemPrimaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
                if let titleView = title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: titleFrame)
                }
                
                contentHeight += titleSize.height
                contentHeight += 8.0
                
                let text: String
                switch component.subject {
                case let .chat(_, link):
                    if !premiumRestrictedUsers.isEmpty {
                        if link != nil {
                            text = environment.strings.SendInviteLink_TextSendInviteLink
                        } else if component.peers.count == 1 {
                            text = environment.strings.SendInviteLink_TextUnavailableSingleUser(component.peers[0].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)).string
                        } else {
                            text = environment.strings.SendInviteLink_TextUnavailableMultipleUsers(Int32(component.peers.count))
                        }
                    } else if link != nil {
                        if component.peers.count == 1 {
                            text = environment.strings.SendInviteLink_TextAvailableSingleUser(component.peers[0].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)).string
                        } else {
                            text = environment.strings.SendInviteLink_TextAvailableMultipleUsers(Int32(component.peers.count))
                        }
                    } else if component.peers.count == 1 {
                        text = environment.strings.SendInviteLink_TextUnavailableSingleUser(component.peers[0].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)).string
                    } else {
                        text = environment.strings.SendInviteLink_TextUnavailableMultipleUsers(Int32(component.peers.count))
                    }
                case let .groupCall(groupCall):
                    switch groupCall {
                    case .create:
                        if component.peers.count == 1 {
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            text = environment.strings.SendInviteLink_TextCallsRestrictedSendOneInviteLink(component.peers[0].peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder)).string
                        } else {
                            text = environment.strings.SendInviteLink_TextCallsRestrictedSendInviteLink
                        }
                    case .existing:
                        text = environment.strings.SendInviteLink_TextCallsRestrictedSendInviteLink
                    }
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: theme.list.itemPrimaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: theme.list.itemPrimaryTextColor)
                
                let descriptionTextSize = descriptionText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: text, attributes: MarkdownAttributes(
                            body: body,
                            bold: bold,
                            link: body,
                            linkAttribute: { _ in nil }
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
                )
                let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
                if let descriptionTextView = descriptionText.view {
                    if descriptionTextView.superview == nil {
                        self.addSubview(descriptionTextView)
                    }
                    transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
                }
                
                contentHeight += descriptionTextFrame.height
                contentHeight += 22.0
                
                var itemsHeight: CGFloat = 0.0
                var validIds: [AnyHashable] = []
                if case .chat = component.subject {
                    for i in 0 ..< component.peers.count {
                        let peer = component.peers[i]
                        let id = AnyHashable(peer.peer.id)
                        validIds.append(id)
                        
                        let item: ComponentView<Empty>
                        var itemTransition = transition
                        if let current = self.items[id] {
                            item = current
                        } else {
                            itemTransition = .immediate
                            item = ComponentView()
                            self.items[id] = item
                        }
                        
                        let canBeSelected: Bool
                        switch component.subject {
                        case let .chat(_, link):
                            canBeSelected = link != nil && !peer.premiumRequiredToContact
                        case .groupCall:
                            canBeSelected = true
                        }
                        
                        let itemSubtitle: PeerListItemComponent.Subtitle
                        if peer.premiumRequiredToContact {
                            itemSubtitle = .text(text: environment.strings.SendInviteLink_StatusAvailableToPremiumOnly, icon: .lock)
                        } else {
                            itemSubtitle = .presence(component.peerPresences[peer.peer.id])
                        }
                        
                        let itemSize = item.update(
                            transition: itemTransition,
                            component: AnyComponent(PeerListItemComponent(
                                context: component.context,
                                theme: theme,
                                strings: environment.strings,
                                sideInset: 0.0,
                                title: peer.peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                                subtitle: itemSubtitle,
                                peer: peer.peer,
                                selectionState: !canBeSelected ? .none : .editing(isSelected: component.selectedItems.contains(peer.peer.id)),
                                hasNext: i != component.peers.count - 1,
                                action: { peer in
                                    if canBeSelected {
                                        component.toggleSelection(peer.id)
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                        )
                        let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)
                        if let itemView = item.view {
                            if itemView.superview == nil {
                                self.itemContainerView.addSubview(itemView)
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                        
                        itemsHeight += itemSize.height
                    }
                }
                
                var removeIds: [AnyHashable] = []
                for (id, item) in self.items {
                    if !validIds.contains(id) {
                        removeIds.append(id)
                        item.view?.removeFromSuperview()
                    }
                }
                for id in removeIds {
                    self.items.removeValue(forKey: id)
                }
                
                transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: itemsHeight)))
                
                if itemsHeight != 0.0 {
                    contentHeight += itemsHeight
                    contentHeight += 24.0
                } else {
                    contentHeight += 4.0
                }
                
                contentHeight += 84.0
            } else {
                if let title = self.title {
                    self.title = nil
                    title.view?.removeFromSuperview()
                }
                if let descriptionText = self.descriptionText {
                    self.descriptionText = nil
                    descriptionText.view?.removeFromSuperview()
                }
                
                for (_, item) in self.items {
                    item.view?.removeFromSuperview()
                }
                self.items.removeAll()
                transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: 0.0)))
                
                contentHeight += 24.0 + environment.safeInsets.bottom
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SendInviteLinkActionButtonComponent: Component {
    let theme: PresentationTheme
    let title: String
    let badge: Int?
    let displaysProgress: Bool
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        title: String,
        badge: Int?,
        displaysProgress: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.badge = badge
        self.displaysProgress = displaysProgress
        self.action = action
    }
    
    static func ==(lhs: SendInviteLinkActionButtonComponent, rhs: SendInviteLinkActionButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        if lhs.displaysProgress != rhs.displaysProgress {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let button = ComponentView<Empty>()
        private var component: SendInviteLinkActionButtonComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SendInviteLinkActionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let content: AnyComponentWithIdentity<Empty>
            if let badge = component.badge {
                content = AnyComponentWithIdentity(id: "badge-\(component.title)-\(badge)", component: AnyComponent(ButtonTextContentComponent(
                    text: component.title,
                    badge: badge,
                    textColor: component.theme.list.itemCheckColors.foregroundColor,
                    badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                    badgeForeground: component.theme.list.itemCheckColors.fillColor
                )))
            } else {
                content = AnyComponentWithIdentity(id: "title-\(component.title)", component: AnyComponent(Text(
                    text: component.title,
                    font: Font.semibold(17.0),
                    color: component.theme.list.itemCheckColors.foregroundColor
                )))
            }
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: content,
                    isEnabled: true,
                    displaysProgress: component.displaysProgress,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.action()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(origin: .zero, size: buttonSize))
            }
            
            return buttonSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class SendInviteLinkScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: SendInviteLinkScreenSubject
    let peers: [TelegramForbiddenInvitePeer]
    let peerPresences: [EnginePeer.Id: EnginePeer.Presence]
    let sendPaidMessageStars: [EnginePeer.Id: StarsAmount]
    
    init(
        context: AccountContext,
        subject: SendInviteLinkScreenSubject,
        peers: [TelegramForbiddenInvitePeer],
        peerPresences: [EnginePeer.Id: EnginePeer.Presence],
        sendPaidMessageStars: [EnginePeer.Id: StarsAmount]
    ) {
        self.context = context
        self.subject = subject
        self.peers = peers
        self.peerPresences = peerPresences
        self.sendPaidMessageStars = sendPaidMessageStars
    }
    
    static func ==(lhs: SendInviteLinkScreenComponent, rhs: SendInviteLinkScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.peerPresences != rhs.peerPresences {
            return false
        }
        if lhs.sendPaidMessageStars != rhs.sendPaidMessageStars {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()
        
        private var selectedItems = Set<EnginePeer.Id>()
        private var didInitializeSelection = false
        private var isInProgress = false
        private var isDismissing = false
        
        private var component: SendInviteLinkScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var createCallDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.createCallDisposable?.dispose()
        }
        
        private func dismiss(controller: @escaping () -> ViewController?, animated: Bool) {
            guard !self.isDismissing else {
                return
            }
            self.isDismissing = true
            
            let performDismiss: () -> Void = {
                if let controller = controller() as? SendInviteLinkScreen {
                    controller.completePendingDismiss()
                    controller.dismiss(animated: false)
                } else {
                    controller()?.dismiss(animated: false)
                }
            }
            
            if animated {
                self.animateOut.invoke(Action { _ in
                    performDismiss()
                })
            } else {
                performDismiss()
            }
        }
        
        private func presentPaidMessageAlertIfNeeded(peers: [EngineRenderedPeer], requiresStars: [EnginePeer.Id: StarsAmount], completion: @escaping () -> Void) {
            guard let component = self.component else {
                completion()
                return
            }
            var totalAmount: StarsAmount = .zero
            for peer in peers {
                if let amount = requiresStars[peer.peerId] {
                    totalAmount = totalAmount + amount
                }
            }
            if totalAmount.value > 0 {
                let controller = chatMessagePaymentAlertController(
                    context: component.context,
                    presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                    updatedPresentationData: nil,
                    peers: peers,
                    count: 1,
                    amount: totalAmount,
                    totalAmount: totalAmount,
                    hasCheck: false,
                    navigationController: self.environment?.controller()?.navigationController as? NavigationController,
                    completion: { _ in
                        completion()
                    }
                )
                self.environment?.controller()?.present(controller, in: .window(.root))
            } else {
                completion()
            }
        }
        
        private func sendInviteLink(link: String, selectedPeers: [TelegramForbiddenInvitePeer], completion: (() -> Void)? = nil) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            self.presentPaidMessageAlertIfNeeded(
                peers: selectedPeers.map { EngineRenderedPeer(peer: $0.peer) },
                requiresStars: component.sendPaidMessageStars,
                completion: { [weak self] in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    
                    for peerId in Array(self.selectedItems) {
                        var messageAttributes: [EngineMessage.Attribute] = []
                        if let sendPaidMessageStars = component.sendPaidMessageStars[peerId] {
                            messageAttributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
                        }
                        let _ = enqueueMessages(account: component.context.account, peerId: peerId, messages: [.message(text: link, attributes: messageAttributes, inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
                    }
                    
                    let text: String
                    if selectedPeers.count == 1 {
                        text = environment.strings.Conversation_ShareLinkTooltip_Chat_One(selectedPeers[0].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: "")).string
                    } else if selectedPeers.count == 2 {
                        text = environment.strings.Conversation_ShareLinkTooltip_TwoChats_One(selectedPeers[0].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: ""), selectedPeers[1].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: "")).string
                    } else {
                        text = environment.strings.Conversation_ShareLinkTooltip_ManyChats_One(selectedPeers[0].peer.displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: ""), "\(selectedPeers.count - 1)").string
                    }
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    controller.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: false, text: text), elevatedLayout: false, action: { _ in return false }), in: .window(.root))
                    
                    completion?()
                }
            )
        }
        
        private func performMainAction() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            
            let link: String?
            switch component.subject {
            case let .chat(_, linkValue):
                link = linkValue
            case let .groupCall(groupCall):
                switch groupCall {
                case .create:
                    self.isInProgress = true
                    self.state?.updated(transition: .immediate)
                    
                    self.createCallDisposable = (component.context.engine.calls.createConferenceCall()
                    |> deliverOnMainQueue).startStrict(next: { [weak self] call in
                        guard let self, let component = self.component, let controller = self.environment?.controller() else {
                            return
                        }
                        
                        if self.selectedItems.isEmpty {
                            controller.dismiss()
                        } else {
                            let link = call.link
                            let selectedPeers = component.peers.filter { self.selectedItems.contains($0.peer.id) }
                            self.sendInviteLink(link: link, selectedPeers: selectedPeers, completion: { [weak self] in
                                guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                    return
                                }
                                let navigationController = controller.navigationController as? NavigationController
                                let context = component.context
                                controller.dismiss(completion: { [weak navigationController] in
                                    if let navigationController, let peer = selectedPeers.first?.peer {
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                            navigationController: navigationController,
                                            context: context,
                                            chatLocation: .peer(peer)
                                        ))
                                    }
                                })
                            })
                        }
                    })
                    return
                case let .existing(linkValue):
                    link = linkValue
                }
            }
            
            if self.selectedItems.isEmpty {
                controller.dismiss()
            } else if let link {
                let selectedPeers = component.peers.filter { self.selectedItems.contains($0.peer.id) }
                self.sendInviteLink(link: link, selectedPeers: selectedPeers, completion: { [weak self] in
                    self?.environment?.controller()?.dismiss()
                })
            } else {
                controller.dismiss()
            }
        }
        
        func update(component: SendInviteLinkScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            if !self.didInitializeSelection {
                self.didInitializeSelection = true
                for peer in component.peers {
                    switch component.subject {
                    case let .chat(_, link):
                        if link != nil && !peer.premiumRequiredToContact {
                            self.selectedItems.insert(peer.peer.id)
                        }
                    case .groupCall:
                        self.selectedItems.insert(peer.peer.id)
                    }
                }
            }
            
            self.component = component
            self.state = state
            
            let environmentValue = environment[EnvironmentType.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme.withModalBlocksBackground()
            let hasInviteSection = sendInviteLinkHasInviteSection(subject: component.subject, peers: component.peers)
            
            let dismiss: (Bool) -> Void = { [weak self] animated in
                self?.dismiss(controller: controller, animated: animated)
            }
            
            let actionTitle: String
            let actionBadge: Int?
            switch component.subject {
            case let .chat(_, link):
                if link != nil {
                    actionTitle = self.selectedItems.isEmpty ? environmentValue.strings.SendInviteLink_ActionSkip : environmentValue.strings.SendInviteLink_ActionInvite
                } else {
                    actionTitle = environmentValue.strings.SendInviteLink_ActionClose
                }
                actionBadge = (self.selectedItems.isEmpty || link == nil) ? nil : self.selectedItems.count
            case .groupCall:
                actionTitle = environmentValue.strings.SendInviteLink_ActionInvite
                actionBadge = nil
            }
            
            let bottomItem: AnyComponent<Empty>?
            if hasInviteSection {
                bottomItem = AnyComponent(SendInviteLinkActionButtonComponent(
                    theme: theme,
                    title: actionTitle,
                    badge: actionBadge,
                    displaysProgress: self.isInProgress,
                    action: { [weak self] in
                        self?.performMainAction()
                    }
                ))
            } else {
                bottomItem = nil
            }
            
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SendInviteLinkContentComponent(
                        context: component.context,
                        subject: component.subject,
                        peers: component.peers,
                        peerPresences: component.peerPresences,
                        selectedItems: self.selectedItems,
                        theme: theme,
                        toggleSelection: { [weak self] peerId in
                            guard let self else {
                                return
                            }
                            if self.selectedItems.contains(peerId) {
                                self.selectedItems.remove(peerId)
                            } else {
                                self.selectedItems.insert(peerId)
                            }
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                        },
                        openPremium: { [weak self] in
                            guard let self, let component = self.component, let controller = self.environment?.controller() else {
                                return
                            }
                            let navigationController = controller.navigationController as? NavigationController
                            controller.dismiss()
                            let premiumController = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .settings, forceDark: false, dismissed: nil)
                            navigationController?.pushViewController(premiumController)
                        }
                    )),
                    titleItem: nil,
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: nil,
                    hasTopEdgeEffect: false,
                    bottomItem: bottomItem,
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                    defaultHeight: 540.0,
                    animateOut: self.animateOut
                )),
                environment: {
                    environmentValue
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environmentValue.statusBarHeight,
                        safeInsets: environmentValue.safeInsets,
                        inputHeight: 0.0,
                        metrics: environmentValue.metrics,
                        deviceMetrics: environmentValue.deviceMetrics,
                        isDisplaying: environmentValue.isVisible,
                        isCentered: environmentValue.presentsFloatingPanels,
                        screenSize: availableSize,
                        regularMetricsSize: nil,
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                containerSize: availableSize
            )
            self.sheet.parentState = state
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


public class SendInviteLinkScreen: ViewControllerComponentContainer {
    private var isDismissed: Bool = false
    private var dismissCompletion: (() -> Void)?
    
    private var presenceDisposable: Disposable?
    
    public init(context: AccountContext, subject: SendInviteLinkScreenSubject, peers: [TelegramForbiddenInvitePeer], theme: PresentationTheme? = nil) {
        super.init(
            context: context,
            component: SendInviteLinkScreenComponent(
                context: context,
                subject: subject,
                peers: peers,
                peerPresences: [:],
                sendPaidMessageStars: [:]
            ),
            navigationBarAppearance: .none,
            theme: theme.flatMap { .custom($0) } ?? .default
        )
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        
        self.presenceDisposable = (context.engine.data.subscribe(
            EngineDataMap(
                peers.map(\.peer.id).map(TelegramEngine.EngineData.Item.Peer.Presence.init(id:))
            ),
            EngineDataMap(
                peers.map(\.peer.id).map(TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars.init(id:))
            )
        )
        |> deliverOnMainQueue).start(next: { [weak self] presences, sendPaidMessageStars in
            guard let self else {
                return
            }
            var parsedPresences: [EnginePeer.Id: EnginePeer.Presence] = [:]
            for (id, presence) in presences {
                if let presence {
                    parsedPresences[id] = presence
                }
            }
            var parsedSendPaidMessageStars: [EnginePeer.Id: StarsAmount] = [:]
            for (id, sendPaidMessageStars) in sendPaidMessageStars {
                if let sendPaidMessageStars {
                    parsedSendPaidMessageStars[id] = sendPaidMessageStars
                }
            }
            self.updateComponent(
                component: AnyComponent(SendInviteLinkScreenComponent(
                    context: context,
                    subject: subject,
                    peers: peers,
                    peerPresences: parsedPresences,
                    sendPaidMessageStars: parsedSendPaidMessageStars
                )),
                transition: .immediate
            )
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presenceDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    func completePendingDismiss() {
        let dismissCompletion = self.dismissCompletion
        self.dismissCompletion = nil
        dismissCompletion?()
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            self.dismissCompletion = completion
            
            if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
                view.dismissAnimated()
            } else {
                self.completePendingDismiss()
                self.dismiss(animated: false)
            }
        }
    }
}
