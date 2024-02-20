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
import ListItemSliderSelectorComponent
import DateSelectionUI
import PlainButtonComponent
import TelegramStringFormatting
import TimeSelectionActionSheet

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

final class AutomaticBusinessMessageSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: AutomaticBusinessMessageSetupScreen.Mode

    init(
        context: AccountContext,
        mode: AutomaticBusinessMessageSetupScreen.Mode
    ) {
        self.context = context
        self.mode = mode
    }

    static func ==(lhs: AutomaticBusinessMessageSetupScreenComponent, rhs: AutomaticBusinessMessageSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }

        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct AdditionalPeerList {
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
    
    private enum Schedule {
        case always
        case outsideBusinessHours
        case custom
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let navigationTitle = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let generalSection = ComponentView<Empty>()
        private let messagesSection = ComponentView<Empty>()
        private let scheduleSection = ComponentView<Empty>()
        private let customScheduleSection = ComponentView<Empty>()
        private let accessSection = ComponentView<Empty>()
        private let excludedSection = ComponentView<Empty>()
        private let periodSection = ComponentView<Empty>()
        
        private var ignoreScrolling: Bool = false
        private var isUpdating: Bool = false
        
        private var component: AutomaticBusinessMessageSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var isOn: Bool = false
        private var accountPeer: EnginePeer?
        private var messages: [EngineMessage] = []
        
        private var schedule: Schedule = .always
        private var customScheduleStart: Date?
        private var customScheduleEnd: Date?
        
        private var hasAccessToAllChatsByDefault: Bool = true
        private var additionalPeerList = AdditionalPeerList(
            categories: Set(),
            peers: []
        )
        
        private var replyToMessages: Bool = true
        
        private var messagesDisposable: Disposable?
        
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
            self.messagesDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: Transition) {
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
        
        private func openAdditionalPeerListSetup() {
            guard let component = self.component else {
                return
            }
            
            enum AdditionalCategoryId: Int {
                case existingChats
                case newChats
                case contacts
                case nonContacts
            }
            
            let additionalCategories: [ChatListNodeAdditionalCategory] = [
                ChatListNodeAdditionalCategory(
                    id: self.hasAccessToAllChatsByDefault ? AdditionalCategoryId.existingChats.rawValue : AdditionalCategoryId.newChats.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Contact"), color: .white), cornerRadius: 12.0, color: .purple),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Contact"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .purple),
                    title: self.hasAccessToAllChatsByDefault ? "Existing Chats" : "New Chats"
                ),
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.contacts.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), cornerRadius: 12.0, color: .blue),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .blue),
                    title: "Contacts"
                ),
                ChatListNodeAdditionalCategory(
                    id: AdditionalCategoryId.nonContacts.rawValue,
                    icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), cornerRadius: 12.0, color: .yellow),
                    smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .yellow),
                    title: "Non-Contacts"
                )
            ]
            var selectedCategories = Set<Int>()
            for category in self.additionalPeerList.categories {
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
            
            //TODO:localize
            let controller = component.context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: component.context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
                title: self.hasAccessToAllChatsByDefault ? "Exclude Chats" : "Include Chats",
                searchPlaceholder: "Search chats",
                selectedChats: Set(self.additionalPeerList.peers.map(\.peer.id)),
                additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories),
                chatListFilters: nil,
                onlyUsers: true
            )), options: [], filters: [], alwaysEnabled: true, limit: 100, reachedLimit: { _ in
            }))
            controller.navigationPresentation = .modal
            
            let _ = (controller.result
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] result in
                guard let self, let component = self.component, case let .result(rawPeerIds, additionalCategoryIds) = result else {
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
                
                let _ = (component.context.engine.data.get(
                    EngineDataMap(
                        peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
                    ),
                    EngineDataMap(
                        peerIds.map(TelegramEngine.EngineData.Item.Peer.IsContact.init(id:))
                    )
                )
                |> deliverOnMainQueue).start(next: { [weak self] peerMap, isContactMap in
                    guard let self else {
                        return
                    }
                    
                    let mappedCategories = additionalCategoryIds.compactMap { item -> AdditionalPeerList.Category? in
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
                    
                    self.additionalPeerList.categories = Set(mappedCategories)
                    
                    self.additionalPeerList.peers.removeAll()
                    for id in peerIds {
                        guard let maybePeer = peerMap[id], let peer = maybePeer else {
                            continue
                        }
                        self.additionalPeerList.peers.append(AdditionalPeerList.Peer(
                            peer: peer,
                            isContact: isContactMap[id] ?? false
                        ))
                    }
                    self.additionalPeerList.peers.sort(by: { lhs, rhs in
                        return lhs.peer.debugDisplayTitle < rhs.peer.debugDisplayTitle
                    })
                    self.state?.updated(transition: .immediate)
                    
                    controller?.dismiss()
                })
            })
            
            self.environment?.controller()?.push(controller)
        }
        
        private func openMessageList() {
            guard let component = self.component else {
                return
            }
            let contents = AutomaticBusinessMessageSetupChatContents(
                context: component.context,
                messages: self.messages,
                kind: component.mode == .away ? .awayMessageInput : .greetingMessageInput
            )
            let chatController = component.context.sharedContext.makeChatController(
                context: component.context,
                chatLocation: .customChatContents,
                subject: .customChatContents(contents: contents),
                botStart: nil,
                mode: .standard(.default)
            )
            chatController.navigationPresentation = .modal
            self.environment?.controller()?.push(chatController)
            self.messagesDisposable?.dispose()
            self.messagesDisposable = (contents.messages
            |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
                guard let self else {
                    return
                }
                let messages = messages.map(EngineMessage.init)
                if self.messages != messages {
                    self.messages = messages
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        private func openCustomScheduleDateSetup(isStartTime: Bool, isDate: Bool) {
            guard let component = self.component else {
                return
            }
            
            let currentValue: Date = (isStartTime ? self.customScheduleStart : self.customScheduleEnd) ?? Date()
            
            if isDate {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let components = calendar.dateComponents([.year, .month, .day], from: currentValue)
                guard let clippedDate = calendar.date(from: components) else {
                    return
                }
                
                let controller = DateSelectionActionSheetController(
                    context: component.context,
                    title: nil,
                    currentValue: Int32(clippedDate.timeIntervalSince1970),
                    minimumDate: nil,
                    maximumDate: nil,
                    emptyTitle: nil,
                    applyValue: { [weak self] value in
                        guard let self else {
                            return
                        }
                        guard let value else {
                            return
                        }
                        let updatedDate = Date(timeIntervalSince1970: Double(value))
                        let calendar = Calendar.current
                        var updatedComponents = calendar.dateComponents([.year, .month, .day], from: updatedDate)
                        let currentComponents = calendar.dateComponents([.hour, .minute], from: currentValue)
                        updatedComponents.hour = currentComponents.hour
                        updatedComponents.minute = currentComponents.minute
                        guard let updatedClippedDate = calendar.date(from: updatedComponents) else {
                            return
                        }
                        
                        if isStartTime {
                            self.customScheduleStart = updatedClippedDate
                        } else {
                            self.customScheduleEnd = updatedClippedDate
                        }
                        self.state?.updated(transition: .immediate)
                    }
                )
                self.environment?.controller()?.present(controller, in: .window(.root))
            } else {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: currentValue)
                let hour = components.hour ?? 0
                let minute = components.minute ?? 0
                
                let controller = TimeSelectionActionSheet(context: component.context, currentValue: Int32(hour * 60 * 60 + minute * 60), applyValue: { [weak self] value in
                    guard let self else {
                        return
                    }
                    guard let value else {
                        return
                    }
                    
                    let updatedHour = value / (60 * 60)
                    let updatedMinute = (value % (60 * 60)) / 60
                    
                    let calendar = Calendar.current
                    var updatedComponents = calendar.dateComponents([.year, .month, .day], from: currentValue)
                    updatedComponents.hour = Int(updatedHour)
                    updatedComponents.minute = Int(updatedMinute)
                    
                    guard let updatedClippedDate = calendar.date(from: updatedComponents) else {
                        return
                    }
                    
                    if isStartTime {
                        self.customScheduleStart = updatedClippedDate
                    } else {
                        self.customScheduleEnd = updatedClippedDate
                    }
                    self.state?.updated(transition: .immediate)
                })
                self.environment?.controller()?.present(controller, in: .window(.root))
            }
        }
        
        func update(component: AutomaticBusinessMessageSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.accountPeer = peer
                })
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: Transition = transition.animation.isImmediate ? transition : transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            //TODO:localize
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.mode == .greeting ? "Greeting Message" : "Away Message", font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
                    content: LottieComponent.AppBundleContent(name: component.mode == .greeting ? "HandWaveEmoji" : "ZzzEmoji"),
                    loop: true
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight + 2.0), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.scrollView.addSubview(iconView)
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            contentHeight += 129.0
            
            //TODO:localize
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(component.mode == .greeting ? "Greet customers when they message you the first time or after a period of no activity." : "Automatically reply with a message when you are away.", attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { attributes in
                    return ("URL", "")
                }), textAlignment: .center
            ))
            
            //TODO:localize
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(subtitleString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.25,
                    highlightColor: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = component
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
            
            var generalSectionItems: [AnyComponentWithIdentity<Empty>] = []
            generalSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.mode == .greeting ? "Send Greeting Message" : "Send Away Message",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.isOn, action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isOn = !self.isOn
                    self.state?.updated(transition: .spring(duration: 0.4))
                })),
                action: nil
            ))))
            
            //TODO:localize
            let generalSectionSize = self.generalSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: generalSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let generalSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: generalSectionSize)
            if let generalSectionView = self.generalSection.view {
                if generalSectionView.superview == nil {
                    self.scrollView.addSubview(generalSectionView)
                }
                transition.setFrame(view: generalSectionView, frame: generalSectionFrame)
            }
            contentHeight += generalSectionSize.height
            contentHeight += sectionSpacing
            
            var otherSectionsHeight: CGFloat = 0.0
            
            //TODO:localize
            var messagesSectionItems: [AnyComponentWithIdentity<Empty>] = []
            if let topMessage = self.messages.first {
                if let accountPeer = self.accountPeer {
                    messagesSectionItems.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(GreetingMessageListItemComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        accountPeer: accountPeer,
                        message: topMessage,
                        count: self.messages.count,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.openMessageList()
                        }
                    ))))
                }
            } else {
                messagesSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.mode == .greeting ? "Create a Greeting Message" : "Create an Away Message",
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                        name: "Chat List/ComposeIcon",
                        tintColor: environment.theme.list.itemAccentColor
                    ))),
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.openMessageList()
                    }
                ))))
            }
            let messagesSectionSize = self.messagesSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.mode == .greeting ? (self.messages.count > 1 ? "GREETING MESSAGES" : "GREETING MESSAGE") : (self.messages.count > 1 ? "AWAY MESSAGES" : "AWAY MESSAGE"),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: messagesSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let messagesSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight), size: messagesSectionSize)
            if let messagesSectionView = self.messagesSection.view {
                if messagesSectionView.superview == nil {
                    messagesSectionView.layer.allowsGroupOpacity = true
                    self.scrollView.addSubview(messagesSectionView)
                }
                transition.setFrame(view: messagesSectionView, frame: messagesSectionFrame)
                alphaTransition.setAlpha(view: messagesSectionView, alpha: self.isOn ? 1.0 : 0.0)
            }
            otherSectionsHeight += messagesSectionSize.height
            otherSectionsHeight += sectionSpacing
            
            if case .away = component.mode {
                //TODO:localize
                var scheduleSectionItems: [AnyComponentWithIdentity<Empty>] = []
                for i in 0 ..< 3 {
                    let title: String
                    let schedule: Schedule
                    switch i {
                    case 0:
                        title = "Always Send"
                        schedule = .always
                    case 1:
                        title = "Outside of Business Hours"
                        schedule = .outsideBusinessHours
                    default:
                        title = "Custom Schedule"
                        schedule = .custom
                    }
                    let isSelected = self.schedule == schedule
                    scheduleSectionItems.append(AnyComponentWithIdentity(id: scheduleSectionItems.count, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: title,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                            image: checkIcon,
                            tintColor: !isSelected ? .clear : environment.theme.list.itemAccentColor,
                            contentMode: .center
                        ))),
                        accessory: nil,
                        action: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            if self.schedule != schedule {
                                self.schedule = schedule
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    ))))
                }
                let scheduleSectionSize = self.scheduleSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "SCHEDULE",
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: scheduleSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let scheduleSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight), size: scheduleSectionSize)
                if let scheduleSectionView = self.scheduleSection.view {
                    if scheduleSectionView.superview == nil {
                        scheduleSectionView.layer.allowsGroupOpacity = true
                        self.scrollView.addSubview(scheduleSectionView)
                    }
                    transition.setFrame(view: scheduleSectionView, frame: scheduleSectionFrame)
                    alphaTransition.setAlpha(view: scheduleSectionView, alpha: self.isOn ? 1.0 : 0.0)
                }
                otherSectionsHeight += scheduleSectionSize.height
                otherSectionsHeight += sectionSpacing
                
                var customScheduleSectionsHeight: CGFloat = 0.0
                var customScheduleSectionItems: [AnyComponentWithIdentity<Empty>] = []
                for i in 0 ..< 2 {
                    let title: String
                    let itemDate: Date?
                    let isStartTime: Bool
                    switch i {
                    case 0:
                        title = "Start Time"
                        itemDate = self.customScheduleStart
                        isStartTime = true
                    default:
                        title = "End Time"
                        itemDate = self.customScheduleEnd
                        isStartTime = false
                    }
                    
                    var icon: ListActionItemComponent.Icon?
                    var accessory: ListActionItemComponent.Accessory?
                    if let itemDate {
                        let calendar = Calendar.current
                        let hours = calendar.component(.hour, from: itemDate)
                        let minutes = calendar.component(.minute, from: itemDate)
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                        
                        let timeText = stringForShortTimestamp(hours: Int32(hours), minutes: Int32(minutes), dateTimeFormat: presentationData.dateTimeFormat)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.timeStyle = .none
                        dateFormatter.dateStyle = .medium
                        let dateText = stringForCompactDate(timestamp: Int32(itemDate.timeIntervalSince1970), strings: environment.strings, dateTimeFormat: presentationData.dateTimeFormat)
                        
                        icon = ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(PlainButtonComponent(
                                content: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: dateText, font: Font.regular(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                                )),
                                background: AnyComponent(RoundedRectangle(color: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1), cornerRadius: 6.0)),
                                effectAlignment: .center,
                                minSize: nil,
                                contentInsets: UIEdgeInsets(top: 7.0, left: 8.0, bottom: 7.0, right: 8.0),
                                action: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.openCustomScheduleDateSetup(isStartTime: isStartTime, isDate: true)
                                },
                                animateAlpha: true,
                                animateScale: false
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(PlainButtonComponent(
                                content: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: timeText, font: Font.regular(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                                )),
                                background: AnyComponent(RoundedRectangle(color: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1), cornerRadius: 6.0)),
                                effectAlignment: .center,
                                minSize: nil,
                                contentInsets: UIEdgeInsets(top: 7.0, left: 8.0, bottom: 7.0, right: 8.0),
                                action: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.openCustomScheduleDateSetup(isStartTime: isStartTime, isDate: false)
                                },
                                animateAlpha: true,
                                animateScale: false
                            )))
                        ], spacing: 4.0))), insets: .custom(UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)), allowUserInteraction: true)
                    } else {
                        icon = ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Set",
                                font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))))
                        accessory = .arrow
                    }
                    
                    customScheduleSectionItems.append(AnyComponentWithIdentity(id: customScheduleSectionItems.count, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: title,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        icon: icon,
                        accessory: accessory,
                        action: itemDate != nil ? nil : { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.openCustomScheduleDateSetup(isStartTime: isStartTime, isDate: true)
                        }
                    ))))
                }
                let customScheduleSectionSize = self.customScheduleSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: nil,
                        items: customScheduleSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let customScheduleSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight + customScheduleSectionsHeight), size: customScheduleSectionSize)
                if let customScheduleSectionView = self.customScheduleSection.view {
                    if customScheduleSectionView.superview == nil {
                        customScheduleSectionView.layer.allowsGroupOpacity = true
                        self.scrollView.addSubview(customScheduleSectionView)
                    }
                    transition.setFrame(view: customScheduleSectionView, frame: customScheduleSectionFrame)
                    alphaTransition.setAlpha(view: customScheduleSectionView, alpha: (self.isOn && self.schedule == .custom) ? 1.0 : 0.0)
                }
                customScheduleSectionsHeight += customScheduleSectionSize.height
                customScheduleSectionsHeight += sectionSpacing
                
                if self.schedule == .custom {
                    otherSectionsHeight += customScheduleSectionsHeight
                }
            }
                
            //TODO:localize
            let accessSectionSize = self.accessSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "RECIPIENTS",
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
                                        string: "All 1-to-1 Chats Except...",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            leftIcon: AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                                image: checkIcon,
                                tintColor: !self.hasAccessToAllChatsByDefault ? .clear : environment.theme.list.itemAccentColor,
                                contentMode: .center
                            ))),
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
                                        string: "Only Selected Chats",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            leftIcon: AnyComponentWithIdentity(id: 0, component: AnyComponent(Image(
                                image: checkIcon,
                                tintColor: self.hasAccessToAllChatsByDefault ? .clear : environment.theme.list.itemAccentColor,
                                contentMode: .center
                            ))),
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
            let accessSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight), size: accessSectionSize)
            if let accessSectionView = self.accessSection.view {
                if accessSectionView.superview == nil {
                    accessSectionView.layer.allowsGroupOpacity = true
                    self.scrollView.addSubview(accessSectionView)
                }
                transition.setFrame(view: accessSectionView, frame: accessSectionFrame)
                alphaTransition.setAlpha(view: accessSectionView, alpha: self.isOn ? 1.0 : 0.0)
            }
            otherSectionsHeight += accessSectionSize.height
            otherSectionsHeight += sectionSpacing
            
            var excludedSectionItems: [AnyComponentWithIdentity<Empty>] = []
            excludedSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.hasAccessToAllChatsByDefault ? "Exclude Chats..." : "Select Chats...",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                    name: "Chat List/AddIcon",
                    tintColor: environment.theme.list.itemAccentColor
                ))),
                accessory: nil,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.openAdditionalPeerListSetup()
                }
            ))))
            for category in self.additionalPeerList.categories.sorted(by: { $0.rawValue < $1.rawValue }) {
                let title: String
                let icon: String
                let color: AvatarBackgroundColor
                //TODO:localize
                switch category {
                case .newChats:
                    title = "New Chats"
                    icon = "Chat List/Filters/Contact"
                    color = .purple
                case .existingChats:
                    title = "Existing Chats"
                    icon = "Chat List/Filters/Contact"
                    color = .purple
                case .contacts:
                    title = "Contacts"
                    icon = "Chat List/Filters/Contact"
                    color = .blue
                case .nonContacts:
                    title = "Non-Contacts"
                    icon = "Chat List/Filters/Contact"
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
                    }
                ))))
            }
            for peer in self.additionalPeerList.peers {
                excludedSectionItems.append(AnyComponentWithIdentity(id: peer.peer.id, component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .generic,
                    sideInset: 0.0,
                    title: peer.peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                    peer: peer.peer,
                    subtitle: peer.isContact ? "contact" : "non-contact",
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .none,
                    hasNext: false,
                    action: { peer, _, _ in
                    }
                ))))
            }
            
            //TODO:localize
            let excludedSectionSize = self.excludedSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.hasAccessToAllChatsByDefault ? "EXCLUDED CHATS" : "INCLUDED CHATS",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: component.mode == .greeting ? "Choose chats or entire chat categories for sending a greeting message." : "Choose chats or entire chat categories for sending an away message.",
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
            let excludedSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight), size: excludedSectionSize)
            if let excludedSectionView = self.excludedSection.view {
                if excludedSectionView.superview == nil {
                    excludedSectionView.layer.allowsGroupOpacity = true
                    self.scrollView.addSubview(excludedSectionView)
                }
                transition.setFrame(view: excludedSectionView, frame: excludedSectionFrame)
                alphaTransition.setAlpha(view: excludedSectionView, alpha: self.isOn ? 1.0 : 0.0)
            }
            otherSectionsHeight += excludedSectionSize.height
            otherSectionsHeight += sectionSpacing
            
            if case .greeting = component.mode {
                let periodSectionSize = self.periodSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "PERIOD OF NO ACTIVITY",
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Choose how many days should pass after your last interaction with a recipient to send them the greeting in response to their message.",
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemSliderSelectorComponent(
                                theme: environment.theme,
                                values: [
                                    "7 days",
                                    "14 days",
                                    "21 days",
                                    "28 days"
                                ],
                                selectedIndex: 0,
                                selectedIndexUpdated: { [weak self] index in
                                    guard let self else {
                                        return
                                    }
                                    let _ = self
                                }
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let periodSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + otherSectionsHeight), size: periodSectionSize)
                if let periodSectionView = self.periodSection.view {
                    if periodSectionView.superview == nil {
                        periodSectionView.layer.allowsGroupOpacity = true
                        self.scrollView.addSubview(periodSectionView)
                    }
                    transition.setFrame(view: periodSectionView, frame: periodSectionFrame)
                    alphaTransition.setAlpha(view: periodSectionView, alpha: self.isOn ? 1.0 : 0.0)
                }
                otherSectionsHeight += periodSectionSize.height
                otherSectionsHeight += sectionSpacing
            }
            
            if self.isOn {
                contentHeight += otherSectionsHeight
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            self.ignoreScrolling = true
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
            }
            self.ignoreScrolling = false
                        
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class AutomaticBusinessMessageSetupScreen: ViewControllerComponentContainer {
    public enum Mode {
        case greeting
        case away
    }
    
    private let context: AccountContext
    
    public init(context: AccountContext, mode: Mode) {
        self.context = context
        
        super.init(context: context, component: AutomaticBusinessMessageSetupScreenComponent(
            context: context,
            mode: mode
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? AutomaticBusinessMessageSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? AutomaticBusinessMessageSetupScreenComponent.View else {
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
