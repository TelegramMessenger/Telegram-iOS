import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import TelegramCore
import AccountContext
import ListSectionComponent
import ListActionItemComponent
import PeerListItemComponent
import ViewControllerComponent
import BundleIconComponent
import AvatarNode
import SwiftSignalKit

final class BusinessRecipientListScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: BusinessRecipientListScreen.InitialData
    let mode: BusinessRecipientListScreen.Mode
    let update: (BusinessRecipientListScreenComponent.PeerList) -> Void

    init(
        context: AccountContext,
        initialData: BusinessRecipientListScreen.InitialData,
        mode: BusinessRecipientListScreen.Mode,
        update: @escaping (BusinessRecipientListScreenComponent.PeerList) -> Void
    ) {
        self.context = context
        self.initialData = initialData
        self.mode = mode
        self.update = update
    }

    static func ==(lhs: BusinessRecipientListScreenComponent, rhs: BusinessRecipientListScreenComponent) -> Bool {
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
    
    struct PeerList {
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
        
        init(categories: Set<Category>, peers: [Peer]) {
            self.categories = categories
            self.peers = peers
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let excludedSection = ComponentView<Empty>()
        private let clearSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: BusinessRecipientListScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var peerList = PeerList(
            categories: Set(),
            peers: []
        )
        
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
            
            component.update(self.peerList)
            
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
        
        static func makePeerListSetupScreen(context: AccountContext, mode: BusinessRecipientListScreen.Mode, initialPeerList: BusinessRecipientListScreenComponent.PeerList, completion: @escaping (BusinessRecipientListScreenComponent.PeerList) -> Void) -> ViewController {
            let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
            
            enum AdditionalCategoryId: Int {
                case existingChats
                case newChats
                case contacts
                case nonContacts
            }
            
            let hasAccessToAllChatsByDefault: Bool
            let isExclude: Bool
            switch mode {
            case .excludeExceptions:
                hasAccessToAllChatsByDefault = true
                isExclude = false
            case .includeExceptions:
                hasAccessToAllChatsByDefault = false
                isExclude = false
            case .excludeUsers:
                hasAccessToAllChatsByDefault = false
                isExclude = true
            }
            
            let additionalCategories: [ChatListNodeAdditionalCategory]
            var selectedCategories = Set<Int>()
            if isExclude {
                additionalCategories = []
            } else {
                additionalCategories = [
                    ChatListNodeAdditionalCategory(
                        id: hasAccessToAllChatsByDefault ? AdditionalCategoryId.existingChats.rawValue : AdditionalCategoryId.newChats.rawValue,
                        icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: hasAccessToAllChatsByDefault ? "Chat List/Filters/Chats" : "Chat List/Filters/NewChats"), color: .white), cornerRadius: 12.0, color: .purple),
                        smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: hasAccessToAllChatsByDefault ? "Chat List/Filters/Chats" : "Chat List/Filters/NewChats"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .purple),
                        title: hasAccessToAllChatsByDefault ? presentationData.strings.BusinessMessageSetup_Recipients_CategoryExistingChats : presentationData.strings.BusinessMessageSetup_Recipients_CategoryNewChats
                    ),
                    ChatListNodeAdditionalCategory(
                        id: AdditionalCategoryId.contacts.rawValue,
                        icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Contact"), color: .white), cornerRadius: 12.0, color: .blue),
                        smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Contact"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .blue),
                        title: presentationData.strings.BusinessMessageSetup_Recipients_CategoryContacts
                    ),
                    ChatListNodeAdditionalCategory(
                        id: AdditionalCategoryId.nonContacts.rawValue,
                        icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), cornerRadius: 12.0, color: .yellow),
                        smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .yellow),
                        title: presentationData.strings.BusinessMessageSetup_Recipients_CategoryNonContacts
                    )
                ]
            }
            if !isExclude {
                for category in initialPeerList.categories {
                    switch category {
                    case .existingChats:
                        selectedCategories.insert(AdditionalCategoryId.existingChats.rawValue)
                    case .newChats:
                        selectedCategories.insert(AdditionalCategoryId.newChats.rawValue)
                    case .contacts:
                        selectedCategories.insert(AdditionalCategoryId.contacts.rawValue)
                    case .nonContacts:
                        selectedCategories.insert(AdditionalCategoryId.nonContacts.rawValue)
                    }
                }
            }
            
            let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
                title: presentationData.strings.ChatbotSetup_Recipients_SelectionTitle,
                searchPlaceholder: presentationData.strings.ChatListFilter_AddChatsSearchPlaceholder,
                selectedChats: Set(initialPeerList.peers.map(\.peer.id)),
                additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories),
                chatListFilters: nil,
                onlyUsers: true
            )), filters: [], alwaysEnabled: true, limit: 100, reachedLimit: { _ in
            }))
            controller.navigationPresentation = .modal
            
            let _ = (controller.result
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak controller] result in
                guard case let .result(rawPeerIds, additionalCategoryIds) = result else {
                    controller?.dismiss()
                    return
                }
                
                let peerIds = rawPeerIds.compactMap { id -> EnginePeer.Id? in
                    switch id {
                    case let .peer(id):
                        return id
                    case .deviceContact:
                        return nil
                    }
                }
                
                let _ = (context.engine.data.get(
                    EngineDataMap(
                        peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
                    ),
                    EngineDataMap(
                        peerIds.map(TelegramEngine.EngineData.Item.Peer.IsContact.init(id:))
                    )
                )
                |> deliverOnMainQueue).start(next: { peerMap, isContactMap in
                    var peerList = BusinessRecipientListScreenComponent.PeerList(categories: Set(), peers: [])
                    
                    if !isExclude {
                        let mappedCategories = additionalCategoryIds.compactMap { item -> PeerList.Category? in
                            switch item {
                            case AdditionalCategoryId.existingChats.rawValue:
                                return .existingChats
                            case AdditionalCategoryId.newChats.rawValue:
                                return .newChats
                            case AdditionalCategoryId.contacts.rawValue:
                                return .contacts
                            case AdditionalCategoryId.nonContacts.rawValue:
                                return .nonContacts
                            default:
                                return nil
                            }
                        }
                        
                        peerList.categories = Set(mappedCategories)
                        
                        peerList.peers.removeAll()
                        for id in peerIds {
                            guard let maybePeer = peerMap[id], let peer = maybePeer else {
                                continue
                            }
                            peerList.peers.append(PeerList.Peer(
                                peer: peer,
                                isContact: isContactMap[id] ?? false
                            ))
                        }
                        peerList.peers.sort(by: { lhs, rhs in
                            return lhs.peer.debugDisplayTitle < rhs.peer.debugDisplayTitle
                        })
                    } else {
                        peerList.peers.removeAll()
                        for id in peerIds {
                            guard let maybePeer = peerMap[id], let peer = maybePeer else {
                                continue
                            }
                            peerList.peers.append(PeerList.Peer(
                                peer: peer,
                                isContact: isContactMap[id] ?? false
                            ))
                        }
                        peerList.peers.sort(by: { lhs, rhs in
                            return lhs.peer.debugDisplayTitle < rhs.peer.debugDisplayTitle
                        })
                    }
                    
                    controller?.dismiss()
                    completion(peerList)
                })
            })
            
            return controller
        }
        
        private func openPeerListSetup() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = BusinessRecipientListScreenComponent.View.makePeerListSetupScreen(
                context: component.context,
                mode: component.mode,
                initialPeerList: self.peerList,
                completion: { [weak self] peerList in
                    guard let self else {
                        return
                    }
                    self.peerList = peerList
                    self.state?.updated(transition: .immediate)
                }
            )
            environment.controller()?.push(controller)
        }
        
        func update(component: BusinessRecipientListScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.peerList = component.initialData.peerList
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition = transition.animation.isImmediate ? transition : .easeInOut(duration: 0.25)
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let title: String
            switch component.mode {
            case .excludeExceptions, .excludeUsers:
                title = environment.strings.ChatbotSetup_Recipients_ExcludedListTitle
            case .includeExceptions:
                title = environment.strings.ChatbotSetup_Recipients_IncludedListTitle
            }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            contentHeight += 16.0
            
            var excludedSectionItems: [AnyComponentWithIdentity<Empty>] = []
            excludedSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.ChatbotSetup_Recipients_AddUsers,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: .custom(AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                    name: "Chat List/AddIcon",
                    tintColor: environment.theme.list.itemAccentColor
                ))), false),
                accessory: nil,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.openPeerListSetup()
                }
            ))))
            for category in self.peerList.categories.sorted(by: { $0.rawValue < $1.rawValue }) {
                let title: String
                let icon: String
                let color: AvatarBackgroundColor
                switch category {
                case .newChats:
                    title = environment.strings.BusinessMessageSetup_Recipients_CategoryNewChats
                    icon = "Chat List/Filters/NewChats"
                    color = .purple
                case .existingChats:
                    title = environment.strings.BusinessMessageSetup_Recipients_CategoryExistingChats
                    icon = "Chat List/Filters/Chats"
                    color = .purple
                case .contacts:
                    title = environment.strings.BusinessMessageSetup_Recipients_CategoryContacts
                    icon = "Chat List/Filters/Contact"
                    color = .blue
                case .nonContacts:
                    title = environment.strings.BusinessMessageSetup_Recipients_CategoryNonContacts
                    icon = "Chat List/Filters/User"
                    color = .yellow
                }
                excludedSectionItems.append(AnyComponentWithIdentity(id: category, component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .generic,
                    sideInset: 0.0,
                    title: title,
                    avatar: PeerListItemComponent.Avatar(
                        icon: icon,
                        color: color,
                        clipStyle: .roundedRect
                    ),
                    peer: nil,
                    subtitle: nil,
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .none,
                    hasNext: false,
                    action: { peer, _, _ in
                    },
                    inlineActions: PeerListItemComponent.InlineActionsState(
                        actions: [PeerListItemComponent.InlineAction(
                            id: AnyHashable(0),
                            title: environment.strings.Common_Delete,
                            color: .destructive,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                
                                self.peerList.categories.remove(category)
                                self.state?.updated(transition: .spring(duration: 0.4))
                                
                                if self.peerList.categories.isEmpty && self.peerList.peers.isEmpty {
                                    let _ = self.attemptNavigation(complete: {})
                                    self.environment?.controller()?.dismiss()
                                }
                            }
                        )]
                    )
                ))))
            }
            for peer in self.peerList.peers {
                excludedSectionItems.append(AnyComponentWithIdentity(id: peer.peer.id, component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .generic,
                    sideInset: 0.0,
                    title: peer.peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                    peer: peer.peer,
                    subtitle: PeerListItemComponent.Subtitle(text: peer.isContact ? environment.strings.ChatList_PeerTypeContact : environment.strings.ChatList_PeerTypeNonContactUser, color: .neutral),
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .none,
                    hasNext: false,
                    action: { peer, _, _ in
                    },
                    inlineActions: PeerListItemComponent.InlineActionsState(
                        actions: [PeerListItemComponent.InlineAction(
                            id: AnyHashable(0),
                            title: environment.strings.Common_Delete,
                            color: .destructive,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.peerList.peers.removeAll(where: { $0.peer.id == peer.peer.id })
                                self.state?.updated(transition: .spring(duration: 0.4))
                                
                                if self.peerList.categories.isEmpty && self.peerList.peers.isEmpty {
                                    let _ = self.attemptNavigation(complete: {})
                                    self.environment?.controller()?.dismiss()
                                }
                            }
                        )]
                    )
                ))))
            }
            
            let excludedSectionSize = self.excludedSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
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
            
            let clearSectionSize = self.clearSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: environment.strings.ChatbotSetup_Recipients_RemoveAll,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemDestructiveColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .center, spacing: 2.0, fillWidth: true)),
                        leftIcon: nil,
                        icon: nil,
                        accessory: .none,
                        action: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.peerList.categories.removeAll()
                            self.peerList.peers.removeAll()
                            
                            self.state?.updated(transition: .spring(duration: 0.4))
                            
                            if self.peerList.categories.isEmpty && self.peerList.peers.isEmpty {
                                let _ = self.attemptNavigation(complete: {})
                                self.environment?.controller()?.dismiss()
                            }
                        }
                    )))]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let clearSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: clearSectionSize)
            if let clearSectionView = self.clearSection.view {
                if clearSectionView.superview == nil {
                    self.scrollView.addSubview(clearSectionView)
                }
                transition.setFrame(view: clearSectionView, frame: clearSectionFrame)
                alphaTransition.setAlpha(view: clearSectionView, alpha: (self.peerList.categories.isEmpty && self.peerList.peers.isEmpty) ? 0.0 : 1.0)
            }
            if !self.peerList.categories.isEmpty || !self.peerList.peers.isEmpty {
                contentHeight += clearSectionSize.height
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

final class BusinessRecipientListScreen: ViewControllerComponentContainer {
    final class InitialData {
        fileprivate let peerList: BusinessRecipientListScreenComponent.PeerList
        
        fileprivate init(
            peerList: BusinessRecipientListScreenComponent.PeerList
        ) {
            self.peerList = peerList
        }
    }
    
    enum Mode {
        case includeExceptions
        case excludeExceptions
        case excludeUsers
    }
    
    private let context: AccountContext
    
    init(context: AccountContext, peerList: BusinessRecipientListScreenComponent.PeerList, mode: Mode, update: @escaping (BusinessRecipientListScreenComponent.PeerList) -> Void) {
        self.context = context
        
        super.init(context: context, component: BusinessRecipientListScreenComponent(
            context: context,
            initialData: InitialData(peerList: peerList),
            mode: mode,
            update: update
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessRecipientListScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessRecipientListScreenComponent.View else {
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
}
