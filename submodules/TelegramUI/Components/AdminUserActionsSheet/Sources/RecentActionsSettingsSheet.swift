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
import MultilineTextComponent
import ButtonComponent
import PresentationDataUtils
import Markdown
import UndoUI
import TelegramStringFormatting
import ListSectionComponent
import ListActionItemComponent
import PlainButtonComponent

private enum ActionTypeSection: Hashable, CaseIterable {
    case members
    case settings
    case messages
}

private enum MembersActionType: Hashable, CaseIterable {
    case newAdminRights
    case newExceptions
    case newMembers
    case leftMembers
    
    func title(isGroup: Bool, strings: PresentationStrings) -> String {
        switch self {
        case .newAdminRights:
            return strings.Channel_AdminLogFilter_EventsAdminRights
        case .newExceptions:
            return strings.Channel_AdminLogFilter_EventsExceptions
        case .newMembers:
            return isGroup ? strings.Channel_AdminLogFilter_EventsNewMembers : strings.Channel_AdminLogFilter_EventsNewSubscribers
        case .leftMembers:
            return isGroup ? strings.Channel_AdminLogFilter_EventsLeavingGroup : strings.Channel_AdminLogFilter_EventsLeavingChannel
        }
    }
    
    var eventFlags: AdminLogEventsFlags {
        switch self {
        case .newAdminRights:
            return [.promote, .demote]
        case .newExceptions:
            return [.ban, .unban, .kick, .unkick]
        case .newMembers:
            return [.invite, .join]
        case .leftMembers:
            return [.leave]
        }
    }
    
    static func actionTypesFromFlags(_ eventFlags: AdminLogEventsFlags) -> [Self] {
        var actionTypes: [Self] = []
        for actionType in Self.allCases {
            if !actionType.eventFlags.intersection(eventFlags).isEmpty {
                actionTypes.append(actionType)
            }
        }
        return actionTypes
    }
}

private enum SettingsActionType: Hashable, CaseIterable {
    case groupInfo
    case inviteLinks
    case videoChats
    
    func title(isGroup: Bool, strings: PresentationStrings) -> String {
        switch self {
        case .groupInfo:
            return isGroup ? strings.Channel_AdminLogFilter_EventsInfo : strings.Channel_AdminLogFilter_ChannelEventsInfo
        case .inviteLinks:
            return strings.Channel_AdminLogFilter_EventsInviteLinks
        case .videoChats:
            return isGroup ? strings.Channel_AdminLogFilter_EventsCalls : strings.Channel_AdminLogFilter_EventsLiveStreams
        }
    }
    
    var eventFlags: AdminLogEventsFlags {
        switch self {
        case .groupInfo:
            return [.info, .settings, .forums]
        case .inviteLinks:
            return [.invites]
        case .videoChats:
            return [.calls]
        }
    }
    
    static func actionTypesFromFlags(_ eventFlags: AdminLogEventsFlags) -> [Self] {
        var actionTypes: [Self] = []
        for actionType in Self.allCases {
            if !actionType.eventFlags.intersection(eventFlags).isEmpty {
                actionTypes.append(actionType)
            }
        }
        return actionTypes
    }
}

private enum MessagesActionType: Hashable, CaseIterable {
    case deletedMessages
    case editedMessages
    case pinnedMessages
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .deletedMessages:
            return strings.Channel_AdminLogFilter_EventsDeletedMessages
        case .editedMessages:
            return strings.Channel_AdminLogFilter_EventsEditedMessages
        case .pinnedMessages:
            return strings.Channel_AdminLogFilter_EventsPinned
        }
    }
    
    var eventFlags: AdminLogEventsFlags {
        switch self {
        case .deletedMessages:
            return [.deleteMessages]
        case .editedMessages:
            return [.editMessages]
        case .pinnedMessages:
            return [.pinnedMessages]
        }
    }
    
    static func actionTypesFromFlags(_ eventFlags: AdminLogEventsFlags) -> [Self] {
        var actionTypes: [Self] = []
        for actionType in Self.allCases {
            if !actionType.eventFlags.intersection(eventFlags).isEmpty {
                actionTypes.append(actionType)
            }
        }
        return actionTypes
    }
}

private enum ActionType: Hashable {
    case members(MembersActionType)
    case settings(SettingsActionType)
    case messages(MessagesActionType)
    
    func title(isGroup: Bool, strings: PresentationStrings) -> String {
        switch self {
        case let .members(value):
            return value.title(isGroup: isGroup, strings: strings)
        case let .settings(value):
            return value.title(isGroup: isGroup, strings: strings)
        case let .messages(value):
            return value.title(strings: strings)
        }
    }
}

private final class RecentActionsSettingsSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let adminPeers: [EnginePeer]
    let initialValue: RecentActionsSettingsSheet.Value
    let completion: (RecentActionsSettingsSheet.Value) -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        adminPeers: [EnginePeer],
        initialValue: RecentActionsSettingsSheet.Value,
        completion: @escaping (RecentActionsSettingsSheet.Value) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.adminPeers = adminPeers
        self.initialValue = initialValue
        self.completion = completion
    }
    
    static func ==(lhs: RecentActionsSettingsSheetComponent, rhs: RecentActionsSettingsSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.adminPeers != rhs.adminPeers {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationBarSeparator: SimpleLayer
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let leftButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private let optionsSection = ComponentView<Empty>()
        private let adminsSection = ComponentView<Empty>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var ignoreScrolling: Bool = false
        
        private var component: RecentActionsSettingsSheetComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var expandedSections = Set<ActionTypeSection>()
        private var selectedMembersActions = Set<MembersActionType>()
        private var selectedSettingsActions = Set<SettingsActionType>()
        private var selectedMessagesActions = Set<MessagesActionType>()
        private var selectedAdmins = Set<EnginePeer.Id>()
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationBarSeparator = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.addSubview(self.navigationBarContainer)
            
            self.navigationBarContainer.addSubview(self.navigationBackgroundView)
            self.navigationBarContainer.layer.addSublayer(self.navigationBarSeparator)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func calculateResult() -> RecentActionsSettingsSheet.Value {
            var events: AdminLogEventsFlags = []
            var admins: [EnginePeer.Id] = []
            for action in self.selectedMembersActions {
                events.formUnion(action.eventFlags)
            }
            for action in self.selectedSettingsActions {
                events.formUnion(action.eventFlags)
            }
            for action in self.selectedMessagesActions {
                events.formUnion(action.eventFlags)
            }
            for peerId in self.selectedAdmins {
                admins.append(peerId)
            }
            return RecentActionsSettingsSheet.Value(
                events: events,
                admins: admins
            )
        }
        
        private func updateScrolling(isFirstTime: Bool = false, transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            
            let navigationAlpha: CGFloat = 1.0 - max(0.0, min(1.0, (topOffset + 20.0) / 20.0))
            transition.setAlpha(view: self.navigationBackgroundView, alpha: navigationAlpha)
            transition.setAlpha(layer: self.navigationBarSeparator, alpha: navigationAlpha)
            
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let modalStyleOverlayTransition: ContainedViewLayoutTransition
            if isFirstTime {
                modalStyleOverlayTransition = .animated(duration: 0.4, curve: .spring)
            } else {
                modalStyleOverlayTransition = transition.containedViewLayoutTransition
            }
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            if self.isUpdating {
                DispatchQueue.main.async { [weak controller] in
                    guard let controller else {
                        return
                    }
                    controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalStyleOverlayTransition)
                }
            } else {
                controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalStyleOverlayTransition)
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
            
            if let environment = self.environment, let controller = environment.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
        
        func update(component: RecentActionsSettingsSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                     
            var isFirstTime = false
            if self.component == nil {
                isFirstTime = true
                self.selectedMembersActions = Set(MembersActionType.actionTypesFromFlags(component.initialValue.events))
                self.selectedSettingsActions = Set(SettingsActionType.actionTypesFromFlags(component.initialValue.events))
                self.selectedMessagesActions = Set(MessagesActionType.actionTypesFromFlags(component.initialValue.events))
                self.selectedAdmins = component.initialValue.admins.flatMap { Set($0) } ?? Set(component.adminPeers.map(\.id))
            }
            
            var isGroup = true
            if case let .channel(channel) = component.peer, case .broadcast = channel.info {
                isGroup = false
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.blocksBackgroundColor.cgColor
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationBarSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 54.0
            contentHeight += 16.0
            
            let leftButtonSize = self.leftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 44.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let leftButtonFrame = CGRect(origin: CGPoint(x: 16.0 + environment.safeInsets.left, y: 0.0), size: leftButtonSize)
            if let leftButtonView = self.leftButton.view {
                if leftButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(leftButtonView)
                }
                transition.setFrame(view: leftButtonView, frame: leftButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            let clippingY: CGFloat
            
            let actionTypeSectionItem: (ActionTypeSection) -> AnyComponentWithIdentity<Empty> = { actionTypeSection in
                let sectionId: AnyHashable
                let totalCount: Int
                let selectedCount: Int
                let isExpanded: Bool
                let title: String
                
                sectionId = actionTypeSection
                isExpanded = self.expandedSections.contains(actionTypeSection)
                
                switch actionTypeSection {
                case .members:
                    totalCount = MembersActionType.allCases.count
                    selectedCount = self.selectedMembersActions.count
                    title = isGroup ? environment.strings.Channel_AdminLogFilter_Section_MembersGroup : environment.strings.Channel_AdminLogFilter_Section_MembersChannel
                case .settings:
                    totalCount = SettingsActionType.allCases.count
                    selectedCount = self.selectedSettingsActions.count
                    title = isGroup ? environment.strings.Channel_AdminLogFilter_Section_SettingsGroup : environment.strings.Channel_AdminLogFilter_Section_SettingsChannel
                case .messages:
                    totalCount = MessagesActionType.allCases.count
                    selectedCount = self.selectedMessagesActions.count
                    title = environment.strings.Channel_AdminLogFilter_Section_Messages
                }
                
                let itemTitle: AnyComponent<Empty> = AnyComponent(HStack([
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(MediaSectionExpandIndicatorComponent(
                        theme: environment.theme,
                        title: "\(selectedCount)/\(totalCount)",
                        isExpanded: isExpanded
                    )))
                ], spacing: 7.0))
                
                let toggleAction: () -> Void = { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    switch actionTypeSection {
                    case .members:
                        if self.selectedMembersActions.isEmpty {
                            self.selectedMembersActions = Set(MembersActionType.allCases)
                        } else {
                            self.selectedMembersActions.removeAll()
                        }
                    case .settings:
                        if self.selectedSettingsActions.isEmpty {
                            self.selectedSettingsActions = Set(SettingsActionType.allCases)
                        } else {
                            self.selectedSettingsActions.removeAll()
                        }
                    case .messages:
                        if self.selectedMessagesActions.isEmpty {
                            self.selectedMessagesActions = Set(MessagesActionType.allCases)
                        } else {
                            self.selectedMessagesActions.removeAll()
                        }
                    }
                    
                    self.state?.updated(transition: .spring(duration: 0.35))
                }
                
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: itemTitle,
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                        isSelected: selectedCount == totalCount,
                        toggle: {
                            toggleAction()
                        }
                    )),
                    icon: .none,
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if self.expandedSections.contains(actionTypeSection) {
                            self.expandedSections.remove(actionTypeSection)
                        } else {
                            self.expandedSections.insert(actionTypeSection)
                        }
                        
                        self.state?.updated(transition: .spring(duration: 0.35))
                    },
                    highlighting: .disabled
                )))
            }
            
            let expandedActionTypeSectionItem: (ActionTypeSection) -> AnyComponentWithIdentity<Empty> = { actionTypeSection in
                let sectionId: AnyHashable
                let selectedActionTypes: Set<ActionType>
                let actionTypes: [ActionType]
                switch actionTypeSection {
                case .members:
                    sectionId = "members-sub"
                    actionTypes = MembersActionType.allCases.map(ActionType.members)
                    selectedActionTypes = Set(self.selectedMembersActions.map(ActionType.members))
                case .settings:
                    sectionId = "settings-sub"
                    actionTypes = SettingsActionType.allCases.map(ActionType.settings)
                    selectedActionTypes = Set(self.selectedSettingsActions.map(ActionType.settings))
                case .messages:
                    sectionId = "messages-sub"
                    actionTypes = MessagesActionType.allCases.map(ActionType.messages)
                    selectedActionTypes = Set(self.selectedMessagesActions.map(ActionType.messages))
                }
                
                var subItems: [AnyComponentWithIdentity<Empty>] = []
                for actionType in actionTypes {
                    let actionItemTitle: String = actionType.title(isGroup: isGroup, strings: environment.strings)
                    
                    let subItemToggleAction: () -> Void = { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        switch actionType {
                        case let .members(value):
                            if self.selectedMembersActions.contains(value) {
                                self.selectedMembersActions.remove(value)
                            } else {
                                self.selectedMembersActions.insert(value)
                            }
                        case let .settings(value):
                            if self.selectedSettingsActions.contains(value) {
                                self.selectedSettingsActions.remove(value)
                            } else {
                                self.selectedSettingsActions.insert(value)
                            }
                        case let .messages(value):
                            if self.selectedMessagesActions.contains(value) {
                                self.selectedMessagesActions.remove(value)
                            } else {
                                self.selectedMessagesActions.insert(value)
                            }
                        }
                        
                        self.state?.updated(transition: .spring(duration: 0.35))
                    }
                    
                    subItems.append(AnyComponentWithIdentity(id: actionType, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: actionItemTitle,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                            isSelected: selectedActionTypes.contains(actionType),
                            toggle: {
                                subItemToggleAction()
                            }
                        )),
                        icon: .none,
                        accessory: .none,
                        action: { _ in
                            subItemToggleAction()
                        },
                        highlighting: .disabled
                    ))))
                }
                
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListSubSectionComponent(
                    theme: environment.theme,
                    leftInset: 62.0,
                    items: subItems
                )))
            }
            
            let titleString: String = environment.strings.Channel_AdminLogFilter_RecentActionsTitle
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftButtonFrame.maxX * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((54.0 - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let navigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 54.0))
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationBackgroundFrame)
            self.navigationBackgroundView.update(size: navigationBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.navigationBarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            for actionTypeSection in ActionTypeSection.allCases {
                optionsSectionItems.append(actionTypeSectionItem(actionTypeSection))
                if self.expandedSections.contains(actionTypeSection) {
                    optionsSectionItems.append(expandedActionTypeSectionItem(actionTypeSection))
                }
            }
            
            let optionsSectionTransition = transition
            let optionsSectionSize = self.optionsSection.update(
                transition: optionsSectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Channel_AdminLogFilter_FilterActionsTypeTitle,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: optionsSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
            )
            let optionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: optionsSectionSize)
            if let optionsSectionView = self.optionsSection.view {
                if optionsSectionView.superview == nil {
                    self.scrollContentView.addSubview(optionsSectionView)
                    self.optionsSection.parentState = state
                }
                transition.setFrame(view: optionsSectionView, frame: optionsSectionFrame)
            }
            contentHeight += optionsSectionSize.height
            contentHeight += 24.0
            
            var peerItems: [AnyComponentWithIdentity<Empty>] = []
            for peer in component.adminPeers {
                peerItems.append(AnyComponentWithIdentity(id: peer.id, component: AnyComponent(AdminUserActionsPeerComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    baseFontSize: presentationData.listsFontSize.baseDisplaySize,
                    sideInset: 0.0,
                    title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                    peer: peer,
                    selectionState: .editing(isSelected: self.selectedAdmins.contains(peer.id)),
                    action: { [weak self] peer in
                        guard let self else {
                            return
                        }
                        
                        if self.selectedAdmins.contains(peer.id) {
                            self.selectedAdmins.remove(peer.id)
                        } else {
                            self.selectedAdmins.insert(peer.id)
                        }
                        
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .easeInOut)))
                    }
                ))))
            }
            
            var adminsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            let allAdminsToggleAction: () -> Void = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                
                if self.selectedAdmins.isEmpty {
                    self.selectedAdmins = Set(component.adminPeers.map(\.id))
                } else {
                    self.selectedAdmins.removeAll()
                }
                
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .easeInOut)))
            }
            adminsSectionItems.append(AnyComponentWithIdentity(id: adminsSectionItems.count, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Channel_AdminLogFilter_ShowAllAdminsActions,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                    isSelected: self.selectedAdmins.count == component.adminPeers.count,
                    toggle: {
                        allAdminsToggleAction()
                    }
                )),
                icon: .none,
                accessory: .none,
                action: { _ in
                    allAdminsToggleAction()
                },
                highlighting: .disabled
            ))))
            adminsSectionItems.append(AnyComponentWithIdentity(id: adminsSectionItems.count, component: AnyComponent(ListSubSectionComponent(
                theme: environment.theme,
                leftInset: 62.0,
                items: peerItems
            ))))
            let adminsSectionSize = self.adminsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Channel_AdminLogFilter_FilterActionsAdminsTitle,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: adminsSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
            )
            let adminsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: adminsSectionSize)
            if let adminsSectionView = self.adminsSection.view {
                if adminsSectionView.superview == nil {
                    self.scrollContentView.addSubview(adminsSectionView)
                    self.adminsSection.parentState = state
                }
                transition.setFrame(view: adminsSectionView, frame: adminsSectionFrame)
            }
            contentHeight += adminsSectionSize.height
            
            contentHeight += 30.0
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: environment.strings.Channel_AdminLogFilter_ApplyFilter,
                            badge: 0,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                        component.completion(self.calculateResult())
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let bottomPanelHeight = 8.0 + environment.safeInsets.bottom + actionButtonSize.height
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            contentHeight += bottomPanelHeight
            
            clippingY = actionButtonFrame.minY - 24.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - contentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 10.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset), size: CGSize(width: availableSize.width - sideInset * 2.0, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            } else {
                if !previousBounds.isEmpty, !transition.animation.isImmediate {
                    let bounds = self.scrollView.bounds
                    if bounds.maxY != previousBounds.maxY {
                        let offsetY = previousBounds.maxY - bounds.maxY
                        transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                    }
                }
            }
            self.ignoreScrolling = false
            self.updateScrolling(isFirstTime: isFirstTime, transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class RecentActionsSettingsSheet: ViewControllerComponentContainer {
    public final class Value {
        public let events: AdminLogEventsFlags
        public let admins: [EnginePeer.Id]?
        
        public init(events: AdminLogEventsFlags, admins: [EnginePeer.Id]?) {
            self.events = events
            self.admins = admins
        }
    }
    
    private let context: AccountContext
    
    private var isDismissed: Bool = false
    
    public init(context: AccountContext, peer: EnginePeer, adminPeers: [EnginePeer], initialValue: Value, completion: @escaping (Value) -> Void) {
        self.context = context
        
        super.init(context: context, component: RecentActionsSettingsSheetComponent(context: context, peer: peer, adminPeers: adminPeers, initialValue: initialValue, completion: completion), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? RecentActionsSettingsSheetComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? RecentActionsSettingsSheetComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private final class MediaSectionExpandIndicatorComponent: Component {
    let theme: PresentationTheme
    let title: String
    let isExpanded: Bool
    
    init(
        theme: PresentationTheme,
        title: String,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.title = title
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: MediaSectionExpandIndicatorComponent, rhs: MediaSectionExpandIndicatorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let arrowView: UIImageView
        private let title = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.arrowView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.arrowView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: MediaSectionExpandIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let titleArrowSpacing: CGFloat = 1.0
            
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.expandDownArrowImage(component.theme)
            }
            self.arrowView.tintColor = component.theme.list.itemPrimaryTextColor
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 1.0, height: 1.0)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(13.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: titleSize.width + titleArrowSpacing + arrowSize.width, height: titleSize.height)
            
            let titleFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((size.height - titleSize.height) * 0.5)), size: titleSize)
            let arrowFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + titleArrowSpacing, y: floor((size.height - arrowSize.height) * 0.5) + 2.0), size: arrowSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            self.arrowView.center = arrowFrame.center
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DTranslate(CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0), 0.0, component.isExpanded ? 1.0 : -1.0, 0.0))
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
