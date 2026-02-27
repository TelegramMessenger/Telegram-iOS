import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import PresentationDataUtils
import ButtonComponent
import TokenListTextField
import AvatarNode
import LocalizedPeerData
import PeerListItemComponent
import LottieComponent
import TooltipUI
import Markdown
import TelegramStringFormatting
import ListSectionComponent
import ListActionItemComponent
import BundleIconComponent
import GlassBarButtonComponent
import EdgeEffect
import TextFormat
import ListItemSliderSelectorComponent
import CreateExternalMediaStreamScreen

final class LiveStreamSettingsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let stateContext: LiveStreamSettingsScreen.StateContext
    let editCategory: (EngineStoryPrivacy, Bool, Bool, Bool, Int64) -> Void
    let editBlockedPeers: (EngineStoryPrivacy, Bool, Bool, Bool, Int64) -> Void
    let completion: (LiveStreamSettingsScreen.Result) -> Void

    init(
        context: AccountContext,
        stateContext: LiveStreamSettingsScreen.StateContext,
        editCategory: @escaping (EngineStoryPrivacy, Bool, Bool, Bool, Int64) -> Void,
        editBlockedPeers: @escaping (EngineStoryPrivacy, Bool, Bool, Bool, Int64) -> Void,
        completion: @escaping (LiveStreamSettingsScreen.Result) -> Void
    ) {
        self.context = context
        self.stateContext = stateContext
        self.editCategory = editCategory
        self.editBlockedPeers = editBlockedPeers
        self.completion = completion
    }

    static func ==(lhs: LiveStreamSettingsScreenComponent, rhs: LiveStreamSettingsScreenComponent) -> Bool {
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        private let topEdgeEffectView: EdgeEffectView
        private let bottomEdgeEffectView: EdgeEffectView
        
        private let streamAsSection = ComponentView<Empty>()
        private let privacySection = ComponentView<Empty>()
        private let externalStreamSection = ComponentView<Empty>()
        private let settingsSection = ComponentView<Empty>()
        private let paidMessageSection = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        
        private var component: LiveStreamSettingsScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
                
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.topEdgeEffectView = EdgeEffectView()
            self.bottomEdgeEffectView = EdgeEffectView()
                        
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addSubview(self.topEdgeEffectView)
            self.addSubview(self.bottomEdgeEffectView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {

        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.endEditing(true)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
 
        }
        
        fileprivate var credentialsPromise = Promise<GroupCallStreamCredentials>()
        private func presentCreateExternalStream() {
            guard let component = self.component, let controller = self.environment?.controller() as? LiveStreamSettingsScreen else {
                return
            }
            var dismissImpl: (() -> Void)?
            let streamController = CreateExternalMediaStreamScreen(
                context: component.context,
                peerId: component.stateContext.sendAsPeerId ?? component.context.account.peerId,
                credentialsPromise: self.credentialsPromise,
                mode: .create(liveStream: true),
                completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.complete(rtmp: true)
                    dismissImpl?()
                }
            )
            dismissImpl = { [weak controller] in
                guard let controller, let navigationController = controller.navigationController as? NavigationController else {
                    return
                }
                var controllers = navigationController.viewControllers
                controllers = controllers.filter { c in
                    return !(c is LiveStreamSettingsScreen || c is CreateExternalMediaStreamScreen)
                }
                navigationController.setViewControllers(controllers, animated: true)
            }
            controller.push(streamController)
        }
        
        private func presentStreamAsPeer() {
            guard let component = self.component else {
                return
            }
            let stateContext = ShareWithPeersScreen.StateContext(
                context: component.context,
                subject: .peers(peers: component.stateContext.stateValue?.sendAsPeers ?? [], peerId: component.stateContext.sendAsPeerId),
                liveStream: true,
                editing: false
            )
            let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                let peersController = ShareWithPeersScreen(
                    context: component.context,
                    initialPrivacy: EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: []),
                    stateContext: stateContext,
                    completion: { _, _, _, _, _, _, _ in },
                    editCategory: { _, _, _, _ in },
                    editBlockedPeers: { _, _, _, _ in },
                    peerCompletion: { [weak self] peerId in
                        guard let self else {
                            return
                        }
                        
                        self.credentialsPromise.set(component.context.engine.calls.getGroupCallStreamCredentials(peerId: peerId, isLiveStream: true, revokePreviousCredentials: false) |> `catch` { _ -> Signal<GroupCallStreamCredentials, NoError> in return .never() })
                        
                        component.stateContext.sendAsPeerId = peerId
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                )
                if let controller = self.environment?.controller() as? LiveStreamSettingsScreen {
                    controller.dismissAllTooltips()
                    controller.push(peersController)
                }
            })
        }
        
        private func complete(rtmp: Bool) {
            guard let component = self.component else {
                return
            }
            component.completion(
                LiveStreamSettingsScreen.Result(
                    sendAsPeerId: component.stateContext.sendAsPeerId,
                    privacy: component.stateContext.privacy,
                    allowComments: component.stateContext.allowComments,
                    isForwardingDisabled: component.stateContext.isForwardingDisabled,
                    pin: component.stateContext.pin,
                    paidMessageStars: component.stateContext.paidMessageStars,
                    startRtmpStream: rtmp
                )
            )
        }
        
        func update(component: LiveStreamSettingsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            var alphaTransition = transition
            if !transition.animation.isImmediate {
                alphaTransition = alphaTransition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            
            guard let screenState = component.stateContext.stateValue else {
                return CGSize()
            }
            
            if self.component == nil {
                self.credentialsPromise.set(component.context.engine.calls.getGroupCallStreamCredentials(peerId: screenState.sendAsPeerId ?? component.context.account.peerId, isLiveStream: true, revokePreviousCredentials: false) |> `catch` { _ -> Signal<GroupCallStreamCredentials, NoError> in return .never() })
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            if themeUpdated {
                self.backgroundColor = theme.list.blocksBackgroundColor
            }
            
            let footerTextFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let footerBoldTextFont = Font.semibold(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let footerTextColor = theme.list.freeTextColor
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
            
            let effectiveSendAsPeerId = screenState.sendAsPeerId ?? component.context.account.peerId
            if screenState.sendAsPeers.count > 1, let peer = screenState.sendAsPeers.first(where: { $0.id == effectiveSendAsPeerId }) {
                let subtitle: String?
                if case .user = peer {
                    subtitle = environment.strings.VoiceChat_PersonalAccount
                } else {
                    if case let .channel(channel) = peer {
                        if case .broadcast = channel.info {
                            if let count = component.stateContext.stateValue?.participants[peer.id] {
                                subtitle = environment.strings.Conversation_StatusSubscribers(Int32(max(1, count)))
                            } else {
                                subtitle = environment.strings.Channel_Status
                            }
                        } else {
                            if let count = component.stateContext.stateValue?.participants[peer.id] {
                                subtitle = environment.strings.Conversation_StatusMembers(Int32(max(1, count)))
                            } else {
                                subtitle = environment.strings.Group_Status
                            }
                        }
                    } else {
                        subtitle = nil
                    }
                }
                
                let streamAsSectionItems = [AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    PeerListItemComponent(
                        context: component.context,
                        theme: theme,
                        strings: environment.strings,
                        style: .generic,
                        sideInset: 0.0,
                        title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                        peer: peer,
                        subtitle: subtitle.flatMap { PeerListItemComponent.Subtitle(text: $0, color: .neutral) },
                        subtitleAccessory: .none,
                        presence: nil,
                        rightAccessory: screenState.isCustomTarget ? .none : .disclosure,
                        selectionState: .none,
                        hasNext: false,
                        action: screenState.isCustomTarget ? nil : { [weak self] _, _, _ in
                            guard let self else {
                                return
                            }
                            self.presentStreamAsPeer()
                        }
                    )
                ))]
                
                let streamAsSectionHeader = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.LiveStreamSettings_StartLiveAs,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                ))
                
                let streamAsSectionSize = self.streamAsSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: streamAsSectionHeader,
                        footer: nil,
                        items: streamAsSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let streamAsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: streamAsSectionSize)
                if let streamAsSectionView = self.streamAsSection.view as? ListSectionComponent.View {
                    if streamAsSectionView.superview == nil {
                        self.scrollView.addSubview(streamAsSectionView)
                        self.streamAsSection.parentState = state
                    }
                    transition.setFrame(view: streamAsSectionView, frame: streamAsSectionFrame)
                }
                contentHeight += streamAsSectionSize.height
                contentHeight += sectionSpacing
            }
            
            var displayPrivacy = true
            if screenState.sendAsPeerId?.namespace == Namespaces.Peer.CloudChannel {
                displayPrivacy = false
            } else if screenState.call != nil && screenState.isEdit {
                displayPrivacy = false
            }
            
            if displayPrivacy {
                var privacySectionItems: [AnyComponentWithIdentity<Empty>] = []
                
                var categoryItems: [ShareWithPeersScreenComponent.CategoryItem] = []
                
                var everyoneSubtitle = environment.strings.Story_Privacy_ExcludePeople
                if (screenState.savedSelectedPeers[.everyone]?.count ?? 0) > 0 {
                    var peerNamesArray: [String] = []
                    var peersCount = 0
                    if let peerIds = screenState.savedSelectedPeers[.everyone] {
                        peersCount = peerIds.count
                        for peerId in peerIds {
                            if let peer = screenState.peersMap[peerId] {
                                peerNamesArray.append(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))
                            }
                        }
                    }
                    let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
                    if peersCount == 1 {
                        if !peerNames.isEmpty {
                            everyoneSubtitle = environment.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                        } else {
                            everyoneSubtitle = environment.strings.Story_Privacy_ExcludePeopleExcept(1)
                        }
                    } else {
                        if !peerNames.isEmpty {
                            everyoneSubtitle = environment.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                        } else {
                            everyoneSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(Int32(peersCount))
                        }
                    }
                }
                categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                    id: .everyone,
                    title: environment.strings.Story_Privacy_CategoryEveryone,
                    icon: "Media Editor/Privacy/Everyone",
                    iconColor: .blue,
                    actionTitle: everyoneSubtitle
                ))
                                        
                var contactsSubtitle = environment.strings.Story_Privacy_ExcludePeople
                if (screenState.savedSelectedPeers[.contacts]?.count ?? 0) > 0 {
                    var peerNamesArray: [String] = []
                    var peersCount = 0
                    if let peerIds = screenState.savedSelectedPeers[.contacts] {
                        peersCount = peerIds.count
                        for peerId in peerIds {
                            if let peer = screenState.peersMap[peerId] {
                                peerNamesArray.append(peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder))
                            }
                        }
                    }
                    let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
                    if peersCount == 1 {
                        if !peerNames.isEmpty {
                            contactsSubtitle = environment.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                        } else {
                            contactsSubtitle = environment.strings.Story_Privacy_ExcludePeopleExcept(1)
                        }
                    } else {
                        if !peerNames.isEmpty {
                            contactsSubtitle = environment.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                        } else {
                            contactsSubtitle = environment.strings.Story_Privacy_ExcludePeopleExcept(Int32(peersCount))
                        }
                    }
                }
                categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                    id: .contacts,
                    title: environment.strings.Story_Privacy_CategoryContacts,
                    icon: "Media Editor/Privacy/Contacts",
                    iconColor: .violet,
                    actionTitle: contactsSubtitle
                ))
                
                var closeFriendsSubtitle = environment.strings.Story_Privacy_EditList
                if !screenState.closeFriendsPeers.isEmpty {
                    if screenState.closeFriendsPeers.count > 2 {
                        closeFriendsSubtitle = environment.strings.Story_Privacy_People(Int32(screenState.closeFriendsPeers.count))
                    } else {
                        closeFriendsSubtitle = String(screenState.closeFriendsPeers.map { $0.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder) }.joined(separator: ", "))
                    }
                }
                categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                    id: .closeFriends,
                    title: environment.strings.Story_Privacy_CategoryCloseFriends,
                    icon: "Media Editor/Privacy/CloseFriends",
                    iconColor: .green,
                    actionTitle: closeFriendsSubtitle
                ))
                
                var selectedContactsSubtitle = environment.strings.Story_Privacy_Choose
                if (screenState.savedSelectedPeers[.nobody]?.count ?? 0) > 0 {
                    var peerNamesArray: [String] = []
                    var peersCount = 0
                    if let peerIds = screenState.savedSelectedPeers[.nobody] {
                        peersCount = peerIds.count
                        for peerId in peerIds {
                            if let peer = screenState.peersMap[peerId] {
                                peerNamesArray.append(peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder))
                            }
                        }
                    }
                    let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
                    if peersCount == 1 {
                        if !peerNames.isEmpty {
                            selectedContactsSubtitle = peerNames
                        } else {
                            selectedContactsSubtitle = environment.strings.Story_Privacy_People(1)
                        }
                    } else {
                        if !peerNames.isEmpty {
                            selectedContactsSubtitle = peerNames
                        } else {
                            selectedContactsSubtitle = environment.strings.Story_Privacy_People(Int32(peersCount))
                        }
                    }
                }
                categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                    id: .selectedContacts,
                    title: environment.strings.Story_Privacy_CategorySelectedContacts,
                    icon: "Media Editor/Privacy/SelectedUsers",
                    iconColor: .yellow,
                    actionTitle: selectedContactsSubtitle
                ))

                                
                for i in 0 ..< categoryItems.count {
                    let item = categoryItems[i]
                    
                    var isSelected = false
                    switch screenState.privacy.base {
                    case .everyone:
                        isSelected = item.id == .everyone
                    case .contacts:
                        isSelected = item.id == .contacts
                    case .closeFriends:
                        isSelected = item.id == .closeFriends
                    case .nobody:
                        isSelected = item.id == .selectedContacts
                    }
                    
                    privacySectionItems.append(AnyComponentWithIdentity(id: item.id, component: AnyComponent(
                        CategoryListItemComponent(
                            context: component.context,
                            theme: theme,
                            title: item.title,
                            color: item.iconColor,
                            iconName: item.icon,
                            subtitle: item.actionTitle,
                            selectionState: .editing(isSelected:isSelected, isTinted: false),
                            hasNext: i != categoryItems.count - 1,
                            action: { [weak self] in
                                guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() as? LiveStreamSettingsScreen else {
                                    return
                                }
                                if isSelected {
                                } else {
                                    let base: EngineStoryPrivacy.Base
                                    switch item.id {
                                    case .everyone:
                                        base = .everyone
                                    case .contacts:
                                        base = .contacts
                                    case .closeFriends:
                                        base = .closeFriends
                                    case .selectedContacts:
                                        base = .nobody
                                    }
                                    let selectedPeers = component.stateContext.stateValue?.savedSelectedPeers[base] ?? []
                                    
                                    component.stateContext.privacy = EngineStoryPrivacy(base: base, additionallyIncludePeers: selectedPeers)
                                    
                                    let closeFriends = self.component?.stateContext.stateValue?.closeFriendsPeers ?? []
                                    if item.id == .selectedContacts && selectedPeers.isEmpty {
                                        component.editCategory(
                                            EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: []),
                                            screenState.allowComments,
                                            screenState.isForwardingDisabled,
                                            screenState.pin,
                                            screenState.paidMessageStars
                                        )
                                        controller.dismissAllTooltips()
                                        controller.dismiss()
                                    } else if item.id == .closeFriends && closeFriends.isEmpty {
                                        component.editCategory(
                                            EngineStoryPrivacy(base: .closeFriends, additionallyIncludePeers: []),
                                            screenState.allowComments,
                                            screenState.isForwardingDisabled,
                                            screenState.pin,
                                            screenState.paidMessageStars
                                        )
                                        controller.dismissAllTooltips()
                                        controller.dismiss()
                                    }
                                }
                                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .spring)))
                            },
                            secondaryAction: { [weak self] in
                                guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() as? LiveStreamSettingsScreen else {
                                    return
                                }
                                let base: EngineStoryPrivacy.Base
                                switch item.id {
                                case .everyone:
                                    base = .everyone
                                case .contacts:
                                    base = .contacts
                                case .closeFriends:
                                    base = .closeFriends
                                case .selectedContacts:
                                    base = .nobody
                                }
                                let selectedPeers = component.stateContext.stateValue?.savedSelectedPeers[base] ?? []
                                
                                component.editCategory(
                                    EngineStoryPrivacy(base: base, additionallyIncludePeers: selectedPeers),
                                    screenState.allowComments,
                                    screenState.isForwardingDisabled,
                                    screenState.pin,
                                    screenState.paidMessageStars
                                )
                                controller.dismissAllTooltips()
                                controller.dismiss()
                            }
                        )
                    )))
                }
                
                let privacySectionHeader = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.LiveStreamSettings_WhoCanView,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                ))
                
                let privacySectionFooter = AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: strings.LiveStreamSettings_WhoCanViewInfo,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: footerTextFont, textColor: footerTextColor),
                            bold: MarkdownAttributeSet(font: footerBoldTextFont, textColor: footerTextColor),
                            link: MarkdownAttributeSet(font: footerTextFont, textColor: theme.list.itemAccentColor),
                            linkAttribute: { contents in
                                return (TelegramTextAttributes.URL, contents)
                            }
                        )
                    ),
                    maximumNumberOfLines: 0,
                    highlightColor: presentationData.theme.list.itemAccentColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() as? LiveStreamSettingsScreen else {
                            return
                        }
                        component.editBlockedPeers(
                            component.stateContext.privacy,
                            screenState.allowComments,
                            screenState.isForwardingDisabled,
                            screenState.pin,
                            screenState.paidMessageStars
                        )
                        controller.dismissAllTooltips()
                        controller.dismiss()
                    }
                ))
                
                var privacySectionTransition = transition
                if self.privacySection.view == nil {
                    privacySectionTransition = .immediate
                }
                let privacySectionSize = self.privacySection.update(
                    transition: privacySectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: privacySectionHeader,
                        footer: privacySectionFooter,
                        items: privacySectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let privacySectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: privacySectionSize)
                if let privacySectionView = self.privacySection.view as? ListSectionComponent.View {
                    if privacySectionView.superview == nil {
                        self.scrollView.addSubview(privacySectionView)
                        self.privacySection.parentState = state
                        
                        privacySectionView.alpha = 1.0
                        transition.animateAlpha(view: privacySectionView, from: 0.0, to: 1.0)
                    }
                    privacySectionTransition.setFrame(view: privacySectionView, frame: privacySectionFrame)
                }
                contentHeight += privacySectionSize.height
                contentHeight += sectionSpacing
            } else if let privacySectionView = self.privacySection.view as? ListSectionComponent.View {
                transition.setAlpha(view: privacySectionView, alpha: 0.0, completion: { _ in
                    privacySectionView.removeFromSuperview()
                })
            }
            
            if !screenState.isEdit || (screenState.call != nil && screenState.isEdit && screenState.callIsStream) {
                let externalStreamSectionItems = [AnyComponentWithIdentity(id: 0, component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.LiveStreamSettings_ConnectStream, font: Font.regular(presentationData.listsFontSize.baseDisplaySize), textColor: theme.list.itemPrimaryTextColor)))),
                        action: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.presentCreateExternalStream()
                        }
                    )
                ))]
                let externalStreamFooterComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.LiveStreamSettings_ConnectStreamInfo, font: footerTextFont, textColor: footerTextColor)),
                    maximumNumberOfLines: 0
                ))
                
                let externalStreamSectionSize = self.externalStreamSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: externalStreamFooterComponent,
                        items: externalStreamSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let externalStreamSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: externalStreamSectionSize)
                if let externalStreamSectionView = self.externalStreamSection.view as? ListSectionComponent.View {
                    if externalStreamSectionView.superview == nil {
                        self.scrollView.addSubview(externalStreamSectionView)
                        self.externalStreamSection.parentState = state
                    }
                    transition.setFrame(view: externalStreamSectionView, frame: externalStreamSectionFrame)
                }
                contentHeight += externalStreamSectionSize.height
                contentHeight += sectionSpacing
            }
            
            var settingsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            settingsSectionItems.append(AnyComponentWithIdentity(id: "comments", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.LiveStreamSettings_AllowComments,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: screenState.allowComments, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    component.stateContext.allowComments = !component.stateContext.allowComments
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            
            if !(screenState.call != nil && screenState.isEdit) {
                settingsSectionItems.append(AnyComponentWithIdentity(id: "screenshots", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.LiveStreamSettings_AllowScreenshots,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: !screenState.isForwardingDisabled, action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.stateContext.isForwardingDisabled = !component.stateContext.isForwardingDisabled
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                ))))
            }
            
            let settingsSectionSize = self.settingsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: settingsSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let settingsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: settingsSectionSize)
            if let settingsSectionView = self.settingsSection.view {
                if settingsSectionView.superview == nil {
                    self.scrollView.addSubview(settingsSectionView)
                    self.settingsSection.parentState = state
                }
                transition.setFrame(view: settingsSectionView, frame: settingsSectionFrame)
            }
            contentHeight += settingsSectionSize.height
            contentHeight += sectionSpacing
            
            let paidMessageSectionItems = [AnyComponentWithIdentity(id: 0, component: AnyComponent(
                ListItemSliderSelectorComponent(
                    theme: theme,
                    content: .continuous(ListItemSliderSelectorComponent.Continuous(
                        value: Double(screenState.paidMessageStars) / Double(screenState.maxPaidMessageStars),
                        minValue: 0,
                        lowerBoundTitle: "0",
                        upperBoundTitle: "\(presentationStringsFormattedNumber(Int32(clamping: screenState.maxPaidMessageStars), environment.dateTimeFormat.groupingSeparator))",
                        title: screenState.paidMessageStars == 0 ? strings.LiveStreamSettings_PricePerComment_Free : strings.LiveStreamSettings_PricePerComment_Stars(Int32(clamping: screenState.paidMessageStars)),
                        valueUpdated: { [weak self] value in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.stateContext.paidMessageStars = Int64(Double(screenState.maxPaidMessageStars) * value)
                            self.state?.updated(transition: .immediate)
                        }
                    )),
                    preferNative: true
                )
            ))]
            
            if screenState.allowComments {
                let paidMessageSectionHeader = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.LiveStreamSettings_PricePerComment,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 0
                ))
                
                let paidMessageSectionFooterComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.LiveStreamSettings_PricePerCommentInfo, font: footerTextFont, textColor: footerTextColor)),
                    maximumNumberOfLines: 0
                ))
                
                let paidMessageSectionSize = self.paidMessageSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: paidMessageSectionHeader,
                        footer: paidMessageSectionFooterComponent,
                        items: paidMessageSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let paidMessageSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: paidMessageSectionSize)
                if let paidMessageSectionView = self.paidMessageSection.view as? ListSectionComponent.View {
                    if paidMessageSectionView.superview == nil {
                        paidMessageSectionView.alpha = 1.0
                        self.scrollView.addSubview(paidMessageSectionView)
                        self.paidMessageSection.parentState = state
                        transition.animateAlpha(view: paidMessageSectionView, from: 0.0, to: 1.0)
                    }
                    transition.setFrame(view: paidMessageSectionView, frame: paidMessageSectionFrame)
                }
                contentHeight += paidMessageSectionSize.height
            } else if let paidMessageSectionView = self.paidMessageSection.view {
                transition.setAlpha(view: paidMessageSectionView, alpha: 0.0, completion: { _ in
                    paidMessageSectionView.removeFromSuperview()
                })
            }
                        
            let edgeEffectHeight: CGFloat = 80.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: edgeEffectFrame)
            self.topEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            
            let bottomEdgeEffectHeight: CGFloat = 96.0
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomEdgeEffectHeight), size: CGSize(width: availableSize.width, height: bottomEdgeEffectHeight))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            self.bottomEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: transition)
            
            let title: String = screenState.isEdit ? strings.LiveStreamSettings_TitleEdit : strings.LiveStreamSettings_Title
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: title,
                                font: Font.semibold(17.0),
                                textColor: environment.theme.rootController.navigationBar.primaryTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 40.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? LiveStreamSettingsScreen else {
                            return
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            if screenState.isEdit {
                let doneButtonSize = self.doneButton.update(
                    transition: transition,
                    component: AnyComponent(GlassBarButtonComponent(
                        size: barButtonSize,
                        backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                        isDark: environment.theme.overallDarkAppearance,
                        state: .tintedGlass,
                        isEnabled: true,
                        component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                            BundleIconComponent(
                                name: "Navigation/Done",
                                tintColor: environment.theme.list.itemCheckColors.foregroundColor
                            )
                        )),
                        action: { [weak self] _ in
                            guard let self, let component = self.component, let controller = self.environment?.controller() as? LiveStreamSettingsScreen else {
                                return
                            }
                            if case let .edit(_, displayExternalStream, _, _) = component.stateContext.mode {
                                self.complete(rtmp: displayExternalStream)
                            }
                            controller.dismiss()
                        }
                    )),
                    environment: {},
                    containerSize: barButtonSize
                )
                let doneButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 16.0 - doneButtonSize.width, y: 16.0), size: doneButtonSize)
                if let doneButtonView = self.doneButton.view {
                    if doneButtonView.superview == nil {
                        self.addSubview(doneButtonView)
                    }
                    transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
                }
                
                contentHeight += environment.safeInsets.bottom
            } else {
                let actionButtonSize = self.actionButton.update(
                    transition: transition,
                    component: AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: theme.list.itemCheckColors.fillColor,
                                foreground: theme.list.itemCheckColors.foregroundColor,
                                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: "label",
                                component: AnyComponent(ButtonTextContentComponent(
                                    text: strings.LiveStreamSettings_SaveSettings,
                                    badge: 0,
                                    textColor: theme.list.itemCheckColors.foregroundColor,
                                    badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                    badgeForeground: theme.list.itemCheckColors.fillColor,
                                    combinedAlignment: true
                                ))
                            ),
                            isEnabled: true,
                            displaysProgress: false,
                            action: { [weak self] in
                                guard let self, let controller = self.environment?.controller() as? LiveStreamSettingsScreen else {
                                    return
                                }
                                self.complete(rtmp: false)
                                controller.dismiss()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 30.0 * 2.0, height: 52.0)
                )
                
                let bottomPanelHeight = 10.0 + environment.safeInsets.bottom + actionButtonSize.height
                let actionButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - actionButtonSize.width) / 2.0), y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
                if let actionButtonView = self.actionButton.view {
                    if actionButtonView.superview == nil {
                        self.addSubview(actionButtonView)
                    }
                    transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
                }
                
                contentHeight += bottomPanelHeight + sectionSpacing
            }
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
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
            self.ignoreScrolling = false
            
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

public class LiveStreamSettingsScreen: ViewControllerComponentContainer {
    public enum Mode {
        case create(sendAsPeerId: EnginePeer.Id?, isCustomTarget: Bool, privacy: EngineStoryPrivacy, allowComments: Bool, isForwardingDisabled: Bool, pin: Bool, paidMessageStars: Int64)
        case edit(call: PresentationGroupCall, displayExternalStream: Bool, allowComments: Bool, paidMessageStars: Int64)
    }
    
    public struct Result {
        public var sendAsPeerId: EnginePeer.Id?
        public var privacy: EngineStoryPrivacy
        public var allowComments: Bool
        public var isForwardingDisabled: Bool
        public var pin: Bool
        public var paidMessageStars: Int64
        public var startRtmpStream: Bool
    }
    
    public init(
        context: AccountContext,
        stateContext: StateContext,
        editCategory: @escaping (EngineStoryPrivacy, Bool, Bool, Bool, Int64) -> Void,
        editBlockedPeers: @escaping (EngineStoryPrivacy, Bool, Bool, Bool, Int64) -> Void,
        completion: @escaping (Result) -> Void
    ) {
        super.init(context: context, component: LiveStreamSettingsScreenComponent(
            context: context,
            stateContext: stateContext,
            editCategory: editCategory,
            editBlockedPeers: editBlockedPeers,
            completion: completion
        ), navigationBarAppearance: .transparent, theme: .dark)
        
        self.navigationPresentation = .modal
        self._hasGlassStyle = true
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
                
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? LiveStreamSettingsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController { controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
        }
        self.forEachController { controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        }
    }
    
    final class State {
        var call: PresentationGroupCall?
        var isEdit: Bool
        var callIsStream: Bool
        var maxPaidMessageStars: Int64
        var sendAsPeerId: EnginePeer.Id?
        var isCustomTarget: Bool
        var privacy: EngineStoryPrivacy
        var allowComments: Bool
        var isForwardingDisabled: Bool
        var pin: Bool
        var paidMessageStars: Int64
        var sendAsPeers: [EnginePeer]
        var peersMap: [EnginePeer.Id: EnginePeer]
        var savedSelectedPeers: [Stories.Item.Privacy.Base: [EnginePeer.Id]]
        var participants: [EnginePeer.Id: Int]
        var closeFriendsPeers: [EnginePeer]
        var grayListPeers: [EnginePeer]
        
        init(
            call: PresentationGroupCall?,
            isEdit: Bool,
            callIsStream: Bool,
            maxPaidMessageStars: Int64,
            sendAsPeerId: EnginePeer.Id?,
            isCustomTarget: Bool,
            privacy: EngineStoryPrivacy,
            allowComments: Bool,
            isForwardingDisabled: Bool,
            pin: Bool,
            paidMessageStars: Int64,
            sendAsPeers: [EnginePeer],
            peersMap: [EnginePeer.Id: EnginePeer],
            savedSelectedPeers: [Stories.Item.Privacy.Base: [EnginePeer.Id]],
            participants: [EnginePeer.Id: Int],
            closeFriendsPeers: [EnginePeer],
            grayListPeers: [EnginePeer]
        ) {
            self.call = call
            self.isEdit = isEdit
            self.callIsStream = callIsStream
            self.maxPaidMessageStars = maxPaidMessageStars
            self.sendAsPeerId = sendAsPeerId
            self.isCustomTarget = isCustomTarget
            self.privacy = privacy
            self.allowComments = allowComments
            self.isForwardingDisabled = isForwardingDisabled
            self.pin = pin
            self.paidMessageStars = paidMessageStars
            self.sendAsPeers = sendAsPeers
            self.peersMap = peersMap
            self.savedSelectedPeers = savedSelectedPeers
            self.participants = participants
            self.closeFriendsPeers = closeFriendsPeers
            self.grayListPeers = grayListPeers
        }
    }
    
    public final class StateContext {
        let mode: LiveStreamSettingsScreen.Mode
        let blockedPeersContext: BlockedPeersContext?
        
        var stateValue: State?
        private let statePromise = Promise<State>()
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        private var stateDisposable: Disposable?
        
        private let readyPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
        public var ready: Signal<Bool, NoError> {
            return self.readyPromise.get()
        }
        
        var sendAsPeerId: EnginePeer.Id? {
            get {
                return self.stateValue?.sendAsPeerId
            }
            set(value) {
                self.stateValue?.sendAsPeerId = value
            }
        }
        var privacy: EngineStoryPrivacy {
            get {
                return self.stateValue?.privacy ?? EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: [])
            }
            set(value) {
                self.stateValue?.privacy = value
            }
        }
        var allowComments: Bool {
            get {
                return self.stateValue?.allowComments ?? true
            }
            set(value) {
                self.stateValue?.allowComments = value
            }
        }
        var isForwardingDisabled: Bool {
            get {
                return self.stateValue?.isForwardingDisabled ?? false
            }
            set(value) {
                self.stateValue?.isForwardingDisabled = value
            }
        }
        var pin: Bool {
            get {
                return self.stateValue?.pin ?? true
            }
            set(value) {
                self.stateValue?.pin = value
            }
        }
        var paidMessageStars: Int64 {
            get {
                return self.stateValue?.paidMessageStars ?? 0
            }
            set(value) {
                self.stateValue?.paidMessageStars = value
            }
        }
        
        public init(
            context: AccountContext,
            mode: LiveStreamSettingsScreen.Mode,
            initialSelectedPeers: [EngineStoryPrivacy.Base: [EnginePeer.Id]] = [:],
            closeFriends: Signal<[EnginePeer], NoError>,
            adminedChannels: Signal<[EnginePeer], NoError>,
            blockedPeersContext: BlockedPeersContext?
        ) {
            self.mode = mode
            self.blockedPeersContext = blockedPeersContext
            
            let grayListPeers: Signal<[EnginePeer], NoError>
            if let blockedPeersContext {
                grayListPeers = blockedPeersContext.state
                |> map { state -> [EnginePeer] in
                    return state.peers.compactMap { $0.peer.flatMap(EnginePeer.init) }
                }
            } else {
                grayListPeers = .single([])
            }
            
            let savedEveryoneExceptionPeers = peersListStoredState(engine: context.engine, base: .everyone)
            let savedContactsExceptionPeers = peersListStoredState(engine: context.engine, base: .contacts)
            let savedSelectedPeers = peersListStoredState(engine: context.engine, base: .nobody)
            
            let savedPeers = combineLatest(
                savedEveryoneExceptionPeers,
                savedContactsExceptionPeers,
                savedSelectedPeers
            ) |> mapToSignal { everyone, contacts, selected -> Signal<([EnginePeer.Id: EnginePeer], [EnginePeer.Id], [EnginePeer.Id], [EnginePeer.Id]), NoError> in
                var everyone = everyone
                if let initialPeerIds = initialSelectedPeers[.everyone] {
                    everyone = initialPeerIds
                }
                var everyonePeerSignals: [Signal<EnginePeer?, NoError>] = []
                if everyone.count < 3 {
                    for peerId in everyone {
                        everyonePeerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                    }
                }
                
                var contacts = contacts
                if let initialPeerIds = initialSelectedPeers[.contacts] {
                    contacts = initialPeerIds
                }
                var contactsPeerSignals: [Signal<EnginePeer?, NoError>] = []
                if contacts.count < 3 {
                    for peerId in contacts {
                        contactsPeerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                    }
                }
                
                var selected = selected
                if let initialPeerIds = initialSelectedPeers[.nobody] {
                    selected = initialPeerIds
                }
                var selectedPeerSignals: [Signal<EnginePeer?, NoError>] = []
                if selected.count < 3 {
                    for peerId in selected {
                        selectedPeerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                    }
                }
                return combineLatest(
                    combineLatest(everyonePeerSignals),
                    combineLatest(contactsPeerSignals),
                    combineLatest(selectedPeerSignals)
                ) |> map { everyonePeers, contactsPeers, selectedPeers -> ([EnginePeer.Id: EnginePeer], [EnginePeer.Id], [EnginePeer.Id], [EnginePeer.Id]) in
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for peer in everyonePeers {
                        if let peer {
                            peersMap[peer.id] = peer
                        }
                    }
                    for peer in contactsPeers {
                        if let peer {
                            peersMap[peer.id] = peer
                        }
                    }
                    for peer in selectedPeers {
                        if let peer {
                            peersMap[peer.id] = peer
                        }
                    }
                    return (peersMap, everyone, contacts, selected)
                }
            }
            
            let adminedChannelsWithParticipants = adminedChannels
            |> mapToSignal { peers -> Signal<([EnginePeer], [EnginePeer.Id: Optional<Int>]), NoError> in
                return context.engine.data.subscribe(
                    EngineDataMap(peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                )
                |> map { participantCountMap -> ([EnginePeer], [EnginePeer.Id: Optional<Int>]) in
                    return (peers, participantCountMap)
                }
            }
        
            self.stateDisposable = combineLatest(
                queue: Queue.mainQueue(),
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
                adminedChannelsWithParticipants,
                savedPeers,
                closeFriends,
                grayListPeers
            ).start(next: { [weak self] accountPeer, adminedChannelsWithParticipants, savedPeers, closeFriends, grayListPeers in
                guard let self else {
                    return
                }
                
                let (adminedChannels, participantCounts) = adminedChannelsWithParticipants
                var participants: [EnginePeer.Id: Int] = [:]
                for (key, value) in participantCounts {
                    if let value {
                        participants[key] = value
                    }
                }
                
                var sendAsPeers: [EnginePeer] = []
                if let accountPeer {
                    sendAsPeers.append(accountPeer)
                }
                for channel in adminedChannels {
                    if case let .channel(channel) = channel, channel.hasPermission(.postStories) {
                        if !sendAsPeers.contains(where: { $0.id == channel.id }) {
                            sendAsPeers.append(contentsOf: adminedChannels)
                        }
                    }
                }

                let (peersMap, everyonePeers, contactsPeers, selectedPeers) = savedPeers
                var savedSelectedPeers: [Stories.Item.Privacy.Base: [EnginePeer.Id]] = [:]
                savedSelectedPeers[.everyone] = everyonePeers
                savedSelectedPeers[.contacts] = contactsPeers
                savedSelectedPeers[.nobody] = selectedPeers
                
                let call: PresentationGroupCall?
                let isEdit: Bool
                let maxPaidMessageStars: Int64 = 10000
                let sendAsPeerId: EnginePeer.Id?
                let isCustomTarget: Bool
                let privacy: EngineStoryPrivacy
                let allowComments: Bool
                let isForwardingDisabled: Bool
                let pin: Bool
                let paidMessageStars: Int64
                var callIsStream = false
                
                if let current = self.stateValue {
                    call = current.call
                    isEdit = current.isEdit
                    sendAsPeerId = current.sendAsPeerId
                    isCustomTarget = current.isCustomTarget
                    privacy = current.privacy
                    allowComments = current.allowComments
                    isForwardingDisabled = current.isForwardingDisabled
                    pin = current.pin
                    paidMessageStars = current.paidMessageStars
                } else {
                    switch mode {
                    case let .create(sendAsPeerIdValue, isCustomTargetValue, privacyValue, allowCommentsValue, isForwardingDisabledValue, pinValue, paidMessageStarsValue):
                        call = nil
                        isEdit = false
                        sendAsPeerId = sendAsPeerIdValue
                        isCustomTarget = isCustomTargetValue
                        privacy = privacyValue
                        allowComments = allowCommentsValue
                        isForwardingDisabled = isForwardingDisabledValue
                        pin = pinValue
                        paidMessageStars = paidMessageStarsValue
                    case let .edit(callValue, callIsStreamValue, allowCommentsValue, paidMessageStarsValue):
                        call = callValue
                        isEdit = true
                        sendAsPeerId = nil
                        isCustomTarget = false
                        privacy = EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: [])
                        allowComments = allowCommentsValue
                        isForwardingDisabled = false
                        pin = true
                        paidMessageStars = paidMessageStarsValue
                        callIsStream = callIsStreamValue
                    }
                }
                
                let state = State(
                    call: call,
                    isEdit: isEdit,
                    callIsStream: callIsStream,
                    maxPaidMessageStars: maxPaidMessageStars,
                    sendAsPeerId: sendAsPeerId,
                    isCustomTarget: isCustomTarget,
                    privacy: privacy,
                    allowComments: allowComments,
                    isForwardingDisabled: isForwardingDisabled,
                    pin: pin,
                    paidMessageStars: paidMessageStars,
                    sendAsPeers: sendAsPeers,
                    peersMap: peersMap,
                    savedSelectedPeers: savedSelectedPeers,
                    participants: participants,
                    closeFriendsPeers: closeFriends,
                    grayListPeers: grayListPeers
                )
                
                self.stateValue = state
                self.statePromise.set(.single(state))
                
                self.readyPromise.set(true)
            })
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
    }
}

