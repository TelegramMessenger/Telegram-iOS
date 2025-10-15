import Foundation
import UIKit
import Photos
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import BackButtonComponent
import ListSectionComponent
import ListActionItemComponent
import ListTextFieldItemComponent
import BundleIconComponent
import LottieComponent
import Markdown
import PeerListItemComponent
import AvatarNode

private let checkIcon: UIImage = {
    return generateImage(CGSize(width: 12.0, height: 10.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.98)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.translateBy(x: 1.0, y: 1.0)
        
        let _ = try? drawSvgPath(context, path: "M0.215053763,4.36080467 L3.31621263,7.70466293 L3.31621263,7.70466293 C3.35339229,7.74475231 3.41603123,7.74711109 3.45612061,7.70993143 C3.45920681,7.70706923 3.46210733,7.70401312 3.46480451,7.70078171 L9.89247312,0 S ")
    })!.withRenderingMode(.alwaysTemplate)
}()

final class ChatbotSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: ChatbotSetupScreen.InitialData

    init(
        context: AccountContext,
        initialData: ChatbotSetupScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }

    static func ==(lhs: ChatbotSetupScreenComponent, rhs: ChatbotSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct BotResolutionState: Equatable {
        enum State: Equatable {
            case searching
            case notFound
            case found(peer: EnginePeer, isInstalled: Bool)
        }
        
        var query: String
        var state: State
        
        init(query: String, state: State) {
            self.query = query
            self.state = state
        }
    }
    
    struct AdditionalPeerList {
        enum Category: Int {
            case newChats = 0
            case existingChats = 1
            case contacts = 2
            case nonContacts = 3
        }
        
        struct Peer {
            var peer: EnginePeer
            var isContact: Bool
            
            init(peer: EnginePeer, isContact: Bool) {
                self.peer = peer
                self.isContact = isContact
            }
        }
        
        var categories: Set<Category>
        var peers: [Peer]
        var excludePeers: [Peer]
        
        init(categories: Set<Category>, peers: [Peer], excludePeers: [Peer]) {
            self.categories = categories
            self.peers = peers
            self.excludePeers = excludePeers
        }
    }
    
    final class Permission {
        var id: String
        var key: TelegramBusinessBotRights?
        var title: String
        var value: Bool?
        var enabled: Bool
        var subpermissions: [Permission]?
        var expanded: Bool?
        
        init(
            id: String,
            key: TelegramBusinessBotRights? = nil,
            title: String,
            value: Bool? = nil,
            enabled: Bool = true,
            subpermissions: [Permission]? = nil,
            expanded: Bool? = nil
        ) {
            self.id = id
            self.key = key
            self.title = title
            self.value = value
            self.enabled = enabled
            self.subpermissions = subpermissions
            self.expanded = expanded
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let nameSection = ComponentView<Empty>()
        private let accessSection = ComponentView<Empty>()
        private let excludedSection = ComponentView<Empty>()
        private let excludedUsersSection = ComponentView<Empty>()
        private let permissionsSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: ChatbotSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var chevronImage: UIImage?
        private let textFieldTag = NSObject()
        
        private var botResolutionState: BotResolutionState?
        private var botResolutionDisposable: Disposable?
        private var resetQueryText: String?
        
        private var hasAccessToAllChatsByDefault: Bool = true
        private var additionalPeerList = AdditionalPeerList(
            categories: Set(),
            peers: [],
            excludePeers: []
        )
        
        private var permissions: [Permission] = []
        private var botRights: TelegramBusinessBotRights = []
        
        private var temporaryEnabledPermissions = Set<String>()
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component else {
                return true
            }
            
            var mappedCategories: TelegramBusinessRecipients.Categories = []
            if self.additionalPeerList.categories.contains(.existingChats) {
                mappedCategories.insert(.existingChats)
            }
            if self.additionalPeerList.categories.contains(.newChats) {
                mappedCategories.insert(.newChats)
            }
            if self.additionalPeerList.categories.contains(.contacts) {
                mappedCategories.insert(.contacts)
            }
            if self.additionalPeerList.categories.contains(.nonContacts) {
                mappedCategories.insert(.nonContacts)
            }
            let recipients = TelegramBusinessRecipients(
                categories: mappedCategories,
                additionalPeers: Set(self.additionalPeerList.peers.map(\.peer.id)),
                excludePeers: Set(self.additionalPeerList.excludePeers.map(\.peer.id)),
                exclude: self.hasAccessToAllChatsByDefault
            )
            
            if let botResolutionState = self.botResolutionState, case let .found(peer, isInstalled) = botResolutionState.state, isInstalled {
                let _ = component.context.engine.accountData.setAccountConnectedBot(bot: TelegramAccountConnectedBot(
                    id: peer.id,
                    recipients: recipients,
                    rights: self.botRights
                )).startStandalone()
            } else {
                let _ = component.context.engine.accountData.setAccountConnectedBot(bot: nil).startStandalone()
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: ComponentTransition) {
            let navigationRevealOffsetY: CGFloat = 0.0
            
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentOffset.y - navigationRevealOffsetY) / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: 1.0)
            }
        }
        
        private func updateBotQuery(query: String) {
            guard let component = self.component else {
                return
            }
            
            if !query.isEmpty {
                if self.botResolutionState?.query != query {
                    let previousState = self.botResolutionState?.state
                    let updatedState: BotResolutionState.State
                    if let current = self.botResolutionState?.state, case .found = current {
                        updatedState = current
                    } else {
                        updatedState = .searching
                    }
                    self.botResolutionState = BotResolutionState(
                        query: query,
                        state: updatedState
                    )
                    self.botResolutionDisposable?.dispose()
                    
                    if previousState != self.botResolutionState?.state {
                        self.state?.updated(transition: .spring(duration: 0.35))
                    }
                    
                    var cleanQuery = query
                    if let url = URL(string: cleanQuery), url.host == "t.me" {
                        if url.pathComponents.count > 1 {
                            cleanQuery = url.pathComponents[1]
                        }
                    } else if let url = URL(string: "https://\(cleanQuery)"), url.host == "t.me" {
                        if url.pathComponents.count > 1 {
                            cleanQuery = url.pathComponents[1]
                        }
                    }
                    
                    self.botResolutionDisposable = (component.context.engine.peers.resolvePeerByName(name: cleanQuery, referrer: nil)
                    |> delay(0.4, queue: .mainQueue())
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let self else {
                            return
                        }
                        switch result {
                        case .progress:
                            break
                        case let .result(peer):
                            let previousState = self.botResolutionState?.state
                            if let peer, case let .user(user) = peer, user.botInfo != nil {
                                self.botResolutionState?.state = .found(peer: peer, isInstalled: false)
                            } else {
                                self.botResolutionState?.state = .notFound
                            }
                            if previousState != self.botResolutionState?.state {
                                self.state?.updated(transition: .spring(duration: 0.35))
                            }
                        }
                    })
                }
            } else {
                if let botResolutionDisposable = self.botResolutionDisposable {
                    self.botResolutionDisposable = nil
                    botResolutionDisposable.dispose()
                }
                if self.botResolutionState != nil {
                    self.botResolutionState = nil
                    self.state?.updated(transition: .spring(duration: 0.35))
                }
            }
        }
        
        private func openAdditionalPeerListSetup(isExclude: Bool) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            var mappedPeerList = BusinessRecipientListScreenComponent.PeerList(categories: Set(), peers: [])
            if !isExclude {
                for category in self.additionalPeerList.categories {
                    switch category {
                    case .existingChats:
                        mappedPeerList.categories.insert(.existingChats)
                    case .newChats:
                        mappedPeerList.categories.insert(.newChats)
                    case .contacts:
                        mappedPeerList.categories.insert(.contacts)
                    case .nonContacts:
                        mappedPeerList.categories.insert(.nonContacts)
                    }
                }
            }
            if isExclude {
                for peer in self.additionalPeerList.excludePeers {
                    mappedPeerList.peers.append(BusinessRecipientListScreenComponent.PeerList.Peer(
                        peer: peer.peer,
                        isContact: peer.isContact
                    ))
                }
            } else {
                for peer in self.additionalPeerList.peers {
                    mappedPeerList.peers.append(BusinessRecipientListScreenComponent.PeerList.Peer(
                        peer: peer.peer,
                        isContact: peer.isContact
                    ))
                }
            }
            
            let mode: BusinessRecipientListScreen.Mode
            if isExclude {
                mode = .excludeUsers
            } else {
                if self.hasAccessToAllChatsByDefault {
                    mode = .excludeExceptions
                } else {
                    mode = .includeExceptions
                }
            }
            
            if mappedPeerList.categories.isEmpty && mappedPeerList.peers.isEmpty {
                let controller = BusinessRecipientListScreenComponent.View.makePeerListSetupScreen(
                    context: component.context,
                    mode: mode,
                    initialPeerList: mappedPeerList,
                    completion: { [weak self] peerList in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        environment.controller()?.push(BusinessRecipientListScreen(
                            context: component.context,
                            peerList: peerList,
                            mode: mode,
                            update: { [weak self] updatedPeerList in
                                guard let self else {
                                    return
                                }
                                
                                switch mode {
                                case .excludeExceptions, .includeExceptions:
                                    self.additionalPeerList.peers.removeAll()
                                    for peer in updatedPeerList.peers {
                                        self.additionalPeerList.peers.append(AdditionalPeerList.Peer(
                                            peer: peer.peer,
                                            isContact: peer.isContact
                                        ))
                                        
                                        self.additionalPeerList.excludePeers.removeAll(where: { $0.peer.id == peer.peer.id })
                                    }
                                    self.additionalPeerList.categories.removeAll()
                                    for category in updatedPeerList.categories {
                                        switch category {
                                        case .existingChats:
                                            self.additionalPeerList.categories.insert(.existingChats)
                                        case .newChats:
                                            self.additionalPeerList.categories.insert(.newChats)
                                        case .contacts:
                                            self.additionalPeerList.categories.insert(.contacts)
                                        case .nonContacts:
                                            self.additionalPeerList.categories.insert(.nonContacts)
                                        }
                                    }
                                case .excludeUsers:
                                    for peer in updatedPeerList.peers {
                                        self.additionalPeerList.excludePeers.append(AdditionalPeerList.Peer(
                                            peer: peer.peer,
                                            isContact: peer.isContact
                                        ))
                                        
                                        self.additionalPeerList.peers.removeAll(where: { $0.peer.id == peer.peer.id })
                                    }
                                }
                                
                                self.state?.updated(transition: .immediate)
                            }
                        ))
                    }
                )
                environment.controller()?.push(controller)
            } else {
                environment.controller()?.push(BusinessRecipientListScreen(
                    context: component.context,
                    peerList: mappedPeerList,
                    mode: mode,
                    update: { [weak self] updatedPeerList in
                        guard let self else {
                            return
                        }
                        
                        switch mode {
                        case .excludeExceptions, .includeExceptions:
                            self.additionalPeerList.peers.removeAll()
                            for peer in updatedPeerList.peers {
                                self.additionalPeerList.peers.append(AdditionalPeerList.Peer(
                                    peer: peer.peer,
                                    isContact: peer.isContact
                                ))
                                
                                self.additionalPeerList.excludePeers.removeAll(where: { $0.peer.id == peer.peer.id })
                            }
                            self.additionalPeerList.categories.removeAll()
                            for category in updatedPeerList.categories {
                                switch category {
                                case .existingChats:
                                    self.additionalPeerList.categories.insert(.existingChats)
                                case .newChats:
                                    self.additionalPeerList.categories.insert(.newChats)
                                case .contacts:
                                    self.additionalPeerList.categories.insert(.contacts)
                                case .nonContacts:
                                    self.additionalPeerList.categories.insert(.nonContacts)
                                }
                            }
                        case .excludeUsers:
                            for peer in updatedPeerList.peers {
                                self.additionalPeerList.excludePeers.append(AdditionalPeerList.Peer(
                                    peer: peer.peer,
                                    isContact: peer.isContact
                                ))
                                
                                self.additionalPeerList.peers.removeAll(where: { $0.peer.id == peer.peer.id })
                            }
                        }
                        
                        self.state?.updated(transition: .immediate)
                    }
                ))
            }
        }
        
        private func presentStarGiftsWarningIfNeeded(_ key: TelegramBusinessBotRights, completion: @escaping (Bool) -> Void) -> Bool {
            guard let component = self.component, let environment = self.environment, let botResolutionState = self.botResolutionState, case let .found(peer, _) = botResolutionState.state, let controller = environment.controller() else {
                return false
            }
            
            if !key.contains(.transferAndUpgradeGifts) && !key.contains(.transferStars) && !key.contains(.editUsername) {
                completion(true)
                return false
            } else {
                let botUsername = "@\(peer.addressName ?? "")"
                let text: String
                if key.contains(.editUsername) {
                    text = environment.strings.ChatbotSetup_Gift_Warning_UsernameText(botUsername).string
                } else if key == .transferAndUpgradeGifts {
                    text = environment.strings.ChatbotSetup_Gift_Warning_GiftsText(botUsername).string
                } else if key == .transferStars {
                    text = environment.strings.ChatbotSetup_Gift_Warning_StarsText(botUsername).string
                } else {
                    text = environment.strings.ChatbotSetup_Gift_Warning_CombinedText(botUsername).string
                }
                let alertController = textAlertController(context: component.context, title: environment.strings.ChatbotSetup_Gift_Warning_Title, text: text, actions: [
                    TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {
                        completion(false)
                    }),
                    TextAlertAction(type: .defaultAction, title: environment.strings.ChatbotSetup_Gift_Warning_Proceed, action: {
                        completion(true)
                    })
                ], parseMarkdown: true)
                alertController.dismissed = { byOutsideTap in
                    if byOutsideTap {
                        completion(false)
                    }
                }
                controller.present(alertController, in: .window(.root))
                return true
            }
        }
        
        func update(component: ChatbotSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            if self.component == nil {
                if let bot = component.initialData.bot, let botPeer = component.initialData.botPeer, let addressName = botPeer.addressName {
                    self.botResolutionState = BotResolutionState(query: addressName, state: .found(peer: botPeer, isInstalled: true))
                    self.resetQueryText = addressName.lowercased()
                    
                    self.botRights = bot.rights
                                        
                    let initialRecipients = bot.recipients
                    
                    var mappedCategories = Set<AdditionalPeerList.Category>()
                    if initialRecipients.categories.contains(.existingChats) {
                        mappedCategories.insert(.existingChats)
                    }
                    if initialRecipients.categories.contains(.newChats) {
                        mappedCategories.insert(.newChats)
                    }
                    if initialRecipients.categories.contains(.contacts) {
                        mappedCategories.insert(.contacts)
                    }
                    if initialRecipients.categories.contains(.nonContacts) {
                        mappedCategories.insert(.nonContacts)
                    }
                    
                    var additionalPeers: [AdditionalPeerList.Peer] = []
                    for peerId in initialRecipients.additionalPeers {
                        if let peer = component.initialData.additionalPeers[peerId] {
                            additionalPeers.append(peer)
                        }
                    }
                    
                    var excludePeers: [AdditionalPeerList.Peer] = []
                    for peerId in initialRecipients.excludePeers {
                        if let peer = component.initialData.additionalPeers[peerId] {
                            excludePeers.append(peer)
                        }
                    }
                    
                    self.additionalPeerList = AdditionalPeerList(
                        categories: mappedCategories,
                        peers: additionalPeers,
                        excludePeers: excludePeers
                    )
                    
                    self.hasAccessToAllChatsByDefault = initialRecipients.exclude
                }
                
                self.permissions = [
                    Permission(id: "message", title: environment.strings.ChatbotSetup_Rights_ManageMessages, subpermissions: [
                        Permission(id: "read", title: environment.strings.ChatbotSetup_Rights_ReadMessages, value: true, enabled: false),
                        Permission(id: "reply", key: .reply, title: environment.strings.ChatbotSetup_Rights_ReplyToMessages),
                        Permission(id: "mark", key: .readMessages, title: environment.strings.ChatbotSetup_Rights_MarkAsRead),
                        Permission(id: "deleteSent", key: .deleteSentMessages, title: environment.strings.ChatbotSetup_Rights_DeleteSentMessages),
                        Permission(id: "deleteReceived", key: .deleteReceivedMessages, title: environment.strings.ChatbotSetup_Rights_DeleteReceivedMessages)
                    ], expanded: false),
                    Permission(id: "profile", title: environment.strings.ChatbotSetup_Rights_ManageProfile, subpermissions: [
                        Permission(id: "name", key: .editName, title: environment.strings.ChatbotSetup_Rights_EditName),
                        Permission(id: "bio", key: .editBio, title: environment.strings.ChatbotSetup_Rights_EditBio),
                        Permission(id: "avatar", key: .editProfilePhoto, title: environment.strings.ChatbotSetup_Rights_EditProfilePhoto),
                        Permission(id: "username", key: .editUsername,  title: environment.strings.ChatbotSetup_Rights_EditUsername)
                    ], expanded: false),
                    Permission(id: "gifts", title: environment.strings.ChatbotSetup_Rights_ManageGiftsAndStars, subpermissions: [
                        Permission(id: "view", key: .viewGifts, title: environment.strings.ChatbotSetup_Rights_ViewGifts),
                        Permission(id: "sell", key: .sellGifts, title: environment.strings.ChatbotSetup_Rights_SellGifts),
                        Permission(id: "settings", key: .changeGiftSettings, title: environment.strings.ChatbotSetup_Rights_ChangeGiftSettings),
                        Permission(id: "transfer", key: .transferAndUpgradeGifts, title: environment.strings.ChatbotSetup_Rights_TransferAndUpgradeGifts),
                        Permission(id: "transferStars", key: .transferStars, title: environment.strings.ChatbotSetup_Rights_TransferStars)
                    ], expanded: false),
                    Permission(id: "stories", key: .manageStories, title: environment.strings.ChatbotSetup_Rights_ManageStories)
                ]
            }
                        
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.ChatbotSetup_TitleItem, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            let _ = bottomContentInset
            let _ = sectionSpacing
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "BotEmoji"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight + 8.0), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.scrollView.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            contentHeight += 129.0
            
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.ChatbotSetup_Text, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { attributes in
                    return ("URL", "")
                }), textAlignment: .center
            ))
            if self.chevronImage == nil {
                self.chevronImage = UIImage(bundleImageName: "Settings/TextArrowRight")
            }
            if let range = subtitleString.string.range(of: ">"), let chevronImage = self.chevronImage {
                subtitleString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: subtitleString.string))
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(subtitleString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.25,
                    highlightColor: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        component.context.sharedContext.applicationBindings.openUrl(environment.strings.ChatbotSetup_TextLink)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollView.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            contentHeight += 27.0
            
            let resetQueryText = self.resetQueryText
            self.resetQueryText = nil
            var nameSectionItems: [AnyComponentWithIdentity<Empty>] = []
            nameSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListTextFieldItemComponent(
                theme: environment.theme,
                initialText: "",
                resetText: resetQueryText.flatMap { ListTextFieldItemComponent.ResetText(value: $0) },
                placeholder: environment.strings.ChatbotSetup_BotSearchPlaceholder,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                updated: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.updateBotQuery(query: value)
                },
                tag: self.textFieldTag
            ))))
            if let botResolutionState = self.botResolutionState {
                let mappedContent: ChatbotSearchResultItemComponent.Content
                switch botResolutionState.state {
                case .searching:
                    mappedContent = .searching
                case .notFound:
                    mappedContent = .notFound
                case let .found(peer, isInstalled):
                    mappedContent = .found(peer: peer, isInstalled: isInstalled)
                }
                nameSectionItems.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ChatbotSearchResultItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    content: mappedContent,
                    installAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.endEditing(true)
                        
                        if var botResolutionState = self.botResolutionState, case let .found(peer, isInstalled) = botResolutionState.state, !isInstalled {
                            if case let .user(user) = peer, let botInfo = user.botInfo, botInfo.flags.contains(.isBusiness) {
                                botResolutionState.state = .found(peer: peer, isInstalled: true)
                                self.botResolutionState = botResolutionState
                                self.botRights = [.reply, .readMessages, .deleteSentMessages, .deleteReceivedMessages]
                                self.state?.updated(transition: .spring(duration: 0.3))
                            } else {
                                self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.ChatbotSetup_ErrorBotNotBusinessCapable, actions: [
                                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                    })
                                ]), in: .window(.root))
                            }
                        }
                    },
                    removeAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let botResolutionState = self.botResolutionState, case let .found(_, isInstalled) = botResolutionState.state, isInstalled {
                            self.botResolutionState = nil
                            if let botResolutionDisposable = self.botResolutionDisposable {
                                self.botResolutionDisposable = nil
                                botResolutionDisposable.dispose()
                            }
                            
                            if let textFieldView = self.nameSection.findTaggedView(tag: self.textFieldTag) as? ListTextFieldItemComponent.View {
                                textFieldView.setText(text: "", updateState: false)
                            }
                            self.state?.updated(transition: .spring(duration: 0.3))
                        }
                    }
                ))))
            }
            
            let nameSectionSize = self.nameSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChatbotSetup_BotSectionFooter,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: nameSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let nameSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: nameSectionSize)
            if let nameSectionView = self.nameSection.view {
                if nameSectionView.superview == nil {
                    self.scrollView.addSubview(nameSectionView)
                }
                transition.setFrame(view: nameSectionView, frame: nameSectionFrame)
            }
            contentHeight += nameSectionSize.height
            contentHeight += sectionSpacing
            
            let accessSectionSize = self.accessSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChatbotSetup_RecipientsSectionHeader,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.BusinessMessageSetup_RecipientsOptionAllExcept,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                                image: checkIcon,
                                tintColor: !self.hasAccessToAllChatsByDefault ? .clear : environment.theme.list.itemAccentColor,
                                contentMode: .center
                            ))), false),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                if !self.hasAccessToAllChatsByDefault {
                                    self.hasAccessToAllChatsByDefault = true
                                    self.additionalPeerList.categories.removeAll()
                                    self.additionalPeerList.peers.removeAll()
                                    self.state?.updated(transition: .immediate)
                                }
                            }
                        ))),
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.BusinessMessageSetup_RecipientsOptionOnly,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                                image: checkIcon,
                                tintColor: self.hasAccessToAllChatsByDefault ? .clear : environment.theme.list.itemAccentColor,
                                contentMode: .center
                            ))), false),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                if self.hasAccessToAllChatsByDefault {
                                    self.hasAccessToAllChatsByDefault = false
                                    self.additionalPeerList.categories.removeAll()
                                    self.additionalPeerList.peers.removeAll()
                                    self.state?.updated(transition: .immediate)
                                }
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let accessSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: accessSectionSize)
            if let accessSectionView = self.accessSection.view {
                if accessSectionView.superview == nil {
                    self.scrollView.addSubview(accessSectionView)
                }
                transition.setFrame(view: accessSectionView, frame: accessSectionFrame)
            }
            contentHeight += accessSectionSize.height
            contentHeight += sectionSpacing
            
            let categoriesAndUsersItemCount = self.additionalPeerList.categories.count + self.additionalPeerList.peers.count
            let excludedSectionValue: String
            if categoriesAndUsersItemCount == 0 {
                excludedSectionValue = environment.strings.ChatbotSetup_RecipientSummary_ValueEmpty
            } else {
                excludedSectionValue = environment.strings.ChatbotSetup_RecipientSummary_ValueItems(Int32(categoriesAndUsersItemCount))
            }
            
            let excludedUsersItemCount = self.additionalPeerList.excludePeers.count
            let excludedUsersValue: String
            if excludedUsersItemCount == 0 {
                excludedUsersValue = environment.strings.ChatbotSetup_RecipientSummary_ValueEmpty
            } else {
                excludedUsersValue = environment.strings.ChatbotSetup_RecipientSummary_ValueItems(Int32(excludedUsersItemCount))
            }
            
            var excludedSectionItems: [AnyComponentWithIdentity<Empty>] = []
            excludedSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.hasAccessToAllChatsByDefault ? environment.strings.ChatbotSetup_RecipientSummary_ExcludedChatsItem : environment.strings.ChatbotSetup_RecipientSummary_IncludedChatsItem,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: nil,
                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: excludedSectionValue,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )))),
                accessory: .arrow,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.openAdditionalPeerListSetup(isExclude: false)
                }
            ))))
            
            let excludedSectionSize = self.excludedSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: self.hasAccessToAllChatsByDefault ? environment.strings.ChatbotSetup_Recipients_ExcludedSectionFooter : environment.strings.ChatbotSetup_Recipients_IncludedSectionFooter,
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.itemAccentColor),
                                linkAttribute: { _ in
                                    return nil
                                }
                            )
                        ),
                        maximumNumberOfLines: 0
                    )),
                    items: excludedSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let excludedSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: excludedSectionSize)
            if let excludedSectionView = self.excludedSection.view {
                if excludedSectionView.superview == nil {
                    self.scrollView.addSubview(excludedSectionView)
                }
                transition.setFrame(view: excludedSectionView, frame: excludedSectionFrame)
            }
            contentHeight += excludedSectionSize.height
            contentHeight += sectionSpacing
            
            var excludedUsersContentHeight: CGFloat = 0.0
            var excludedUsersSectionItems: [AnyComponentWithIdentity<Empty>] = []
            excludedUsersSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChatbotSetup_RecipientSummary_ExcludedChatsItem,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: nil,
                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: excludedUsersValue,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )))),
                accessory: .arrow,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.openAdditionalPeerListSetup(isExclude: true)
                }
            ))))
            let excludedUsersSectionSize = self.excludedUsersSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: environment.strings.ChatbotSetup_Recipients_ExcludedSectionFooter,
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.freeTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: environment.theme.list.itemAccentColor),
                                linkAttribute: { _ in
                                    return nil
                                }
                            )
                        ),
                        maximumNumberOfLines: 0
                    )),
                    items: excludedUsersSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let excludedUsersSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + excludedUsersContentHeight), size: excludedSectionSize)
            if let excludedUsersSectionView = self.excludedUsersSection.view {
                if excludedUsersSectionView.superview == nil {
                    self.scrollView.addSubview(excludedUsersSectionView)
                }
                transition.setFrame(view: excludedUsersSectionView, frame: excludedUsersSectionFrame)
                transition.setAlpha(view: excludedUsersSectionView, alpha: !self.hasAccessToAllChatsByDefault ? 1.0 : 0.0)
            }
            excludedUsersContentHeight += excludedUsersSectionSize.height
            excludedUsersContentHeight += sectionSpacing
            if !self.hasAccessToAllChatsByDefault {
                contentHeight += excludedUsersContentHeight
            }
            
            if case .found(_, true) = self.botResolutionState?.state {
                var permissionsItems: [AnyComponentWithIdentity<Empty>] = []
                for permission in self.permissions {
                    var value: Bool
                    if let key = permission.key {
                        value = self.botRights.contains(key)
                    } else {
                        value = permission.value == true
                    }
                    
                    var titleItems: [AnyComponentWithIdentity<Empty>] = []
                    titleItems.append(
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: permission.title,
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    
                    if let subpermissions = permission.subpermissions {
                        value = true
                        var selectedCount = 0
                        for subpermission in subpermissions {
                            if let key = subpermission.key {
                                if self.botRights.contains(key) {
                                    selectedCount += 1
                                } else {
                                    value = false
                                }
                            } else if subpermission.value == true {
                                selectedCount += 1
                            }
                        }
                        if self.temporaryEnabledPermissions.contains(permission.id) {
                            value = true
                        }
                        
                        titleItems.append(
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: "\(selectedCount)/\(subpermissions.count)",
                                    font: Font.with(size: presentationData.listsFontSize.baseDisplaySize / 17.0 * 13.0, design: .round, weight: .semibold),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )))
                        )
                        titleItems.append(
                            AnyComponentWithIdentity(id: AnyHashable(2), component: AnyComponent(BundleIconComponent(
                                name: "Item List/ExpandingItemVerticalRegularArrow",
                                tintColor: environment.theme.list.itemPrimaryTextColor,
                                flipVertically: permission.expanded == true
                            )))
                        )
                    }
                    permissionsItems.append(
                        AnyComponentWithIdentity(id: permission.id, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(HStack(titleItems, spacing: 6.0)),
                            accessory: .toggle(ListActionItemComponent.Toggle(style: .icons, isOn: value, action: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                if let subpermissions = permission.subpermissions {
                                    if value {
                                        var combinedKey: TelegramBusinessBotRights = []
                                        for subpermission in subpermissions {
                                            if subpermission.enabled, let key = subpermission.key {
                                                combinedKey.insert(key)
                                            }
                                        }
                                        self.temporaryEnabledPermissions.insert(permission.id)
                                       
                                        let presentedWarning = self.presentStarGiftsWarningIfNeeded(combinedKey, completion: { [weak self] value in
                                            guard let self else {
                                                return
                                            }
                                            if value {
                                                self.botRights.insert(combinedKey)
                                            }
                                            self.temporaryEnabledPermissions.remove(permission.id)
                                            self.state?.updated(transition: .spring(duration: 0.4))
                                        })
                                        
                                        if !presentedWarning {
                                            self.state?.updated(transition: .spring(duration: 0.4))
                                        }
                                    } else {
                                        for subpermission in subpermissions {
                                            if subpermission.enabled, let key = subpermission.key {
                                                if value {
                                                } else {
                                                    self.botRights.remove(key)
                                                }
                                            }
                                        }
                                    }
                                } else if let key = permission.key {
                                    if value {
                                        self.botRights.insert(key)
                                    } else {
                                        self.botRights.remove(key)
                                    }
                                }
                                self.state?.updated(transition: .spring(duration: 0.4))
                            })),
                            action: permission.subpermissions != nil ? { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                var scrollToBottom = false
                                if let expanded = permission.expanded {
                                    permission.expanded = !expanded
                                    if !expanded {
                                        scrollToBottom = true
                                    }
                                }
                                self.state?.updated(transition: .spring(duration: 0.4))
                                if scrollToBottom {
                                    self.scrollView.setContentOffset(CGPoint(x: 0.0, y: self.scrollView.contentSize.height - self.scrollView.bounds.height), animated: true)
                                }
                            } : nil
                        )))
                    )
                    
                    if let subpermissions = permission.subpermissions, permission.expanded == true {
                        for subpermission in subpermissions {
                            var value = false
                            if let key = subpermission.key {
                                value = self.botRights.contains(key)
                            } else if subpermission.value == true {
                                value = true
                            }
                            
                            permissionsItems.append(
                                AnyComponentWithIdentity(id: subpermission.id, component: AnyComponent(ListActionItemComponent(
                                    theme: environment.theme,
                                    title: AnyComponent(VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: subpermission.title,
                                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                                textColor: environment.theme.list.itemPrimaryTextColor
                                            )),
                                            maximumNumberOfLines: 1
                                        ))),
                                    ], alignment: .left, spacing: 2.0)),
                                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(isSelected: value, isEnabled: subpermission.enabled, toggle: nil)),
                                    accessory: nil,
                                    action: subpermission.enabled ? { [weak self] _ in
                                        guard let self else {
                                            return
                                        }
                                        if let key = subpermission.key {
                                            if !value {
                                                let _ = self.presentStarGiftsWarningIfNeeded(key, completion: { [weak self] value in
                                                    guard let self else {
                                                        return
                                                    }
                                                    if value {
                                                        self.botRights.insert(key)
                                                    }
                                                    self.state?.updated(transition: .spring(duration: 0.4))
                                                })
                                            } else {
                                                self.botRights.remove(key)
                                            }
                                        }
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    } : nil
                                )))
                            )
                        }
                        //permissionsItems.append(AnyComponentWithIdentity(id: "\(permission.id)_sub", component: AnyComponent(VStack(stackItems, spacing: 0.0))))
                    }
                }
                
                var permissionsTransition = transition
                if self.permissionsSection.view?.superview == nil {
                    permissionsTransition = .immediate
                }
                
                let permissionsSectionSize = self.permissionsSection.update(
                    transition: permissionsTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.ChatbotSetup_PermissionsSectionHeader,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.ChatbotSetup_PermissionsSectionFooter,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: permissionsItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let permissionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: permissionsSectionSize)
                if let permissionsSectionView = self.permissionsSection.view {
                    if permissionsSectionView.superview == nil {
                        self.scrollView.addSubview(permissionsSectionView)
                        
                        permissionsSectionView.alpha = 1.0
                        transition.animateAlpha(view: permissionsSectionView, from: 0.0, to: 1.0)
                    }
                    permissionsTransition.setFrame(view: permissionsSectionView, frame: permissionsSectionFrame)
                }
                contentHeight += permissionsSectionSize.height
            } else if let permissionsSectionView = self.permissionsSection.view {
                transition.setAlpha(view: permissionsSectionView, alpha: 0.0, completion: { _ in
                    permissionsSectionView.removeFromSuperview()
                })
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ChatbotSetupScreen: ViewControllerComponentContainer {
    public final class InitialData: ChatbotSetupScreenInitialData {
        fileprivate let bot: TelegramAccountConnectedBot?
        fileprivate let botPeer: EnginePeer?
        fileprivate let additionalPeers: [EnginePeer.Id: ChatbotSetupScreenComponent.AdditionalPeerList.Peer]
        
        fileprivate init(
            bot: TelegramAccountConnectedBot?,
            botPeer: EnginePeer?,
            additionalPeers: [EnginePeer.Id: ChatbotSetupScreenComponent.AdditionalPeerList.Peer]
        ) {
            self.bot = bot
            self.botPeer = botPeer
            self.additionalPeers = additionalPeers
        }
    }
    
    private let context: AccountContext
    
    public init(context: AccountContext, initialData: InitialData) {
        self.context = context
        
        super.init(context: context, component: ChatbotSetupScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? ChatbotSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? ChatbotSetupScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public static func initialData(context: AccountContext) -> Signal<ChatbotSetupScreenInitialData, NoError> {
        return context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.BusinessConnectedBot(id: context.account.peerId)
        )
        |> mapToSignal { connectedBot -> Signal<ChatbotSetupScreenInitialData, NoError> in
            guard let connectedBot else {
                return .single(
                    InitialData(
                        bot: nil,
                        botPeer: nil,
                        additionalPeers: [:]
                    )
                )
            }
            
            var additionalPeerIds = Set<EnginePeer.Id>()
            additionalPeerIds.formUnion(connectedBot.recipients.additionalPeers)
            additionalPeerIds.formUnion(connectedBot.recipients.excludePeers)
            
            return context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: connectedBot.id),
                EngineDataMap(additionalPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))),
                EngineDataMap(additionalPeerIds.map(TelegramEngine.EngineData.Item.Peer.IsContact.init(id:)))
            )
            |> map { botPeer, peers, isContacts -> ChatbotSetupScreenInitialData in
                var additionalPeers: [EnginePeer.Id: ChatbotSetupScreenComponent.AdditionalPeerList.Peer] = [:]
                for id in additionalPeerIds {
                    guard let peer = peers[id], let peer else {
                        continue
                    }
                    additionalPeers[id] = ChatbotSetupScreenComponent.AdditionalPeerList.Peer(
                        peer: peer,
                        isContact: isContacts[id] ?? false
                    )
                }
                
                return InitialData(
                    bot: connectedBot,
                    botPeer: botPeer,
                    additionalPeers: additionalPeers
                )
            }
        }
    }
}
