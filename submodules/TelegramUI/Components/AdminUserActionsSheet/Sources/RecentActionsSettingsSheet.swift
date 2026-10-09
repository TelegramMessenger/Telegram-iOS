import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import ResizableSheetComponent
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import ButtonComponent
import PresentationDataUtils
import TelegramStringFormatting
import ListSectionComponent
import ListActionItemComponent
import GlassBarButtonComponent
import BundleIconComponent

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

private struct RecentActionsSettingsSheetState: Equatable {
    var expandedSections: Set<ActionTypeSection>
    var selectedMembersActions: Set<MembersActionType>
    var selectedSettingsActions: Set<SettingsActionType>
    var selectedMessagesActions: Set<MessagesActionType>
    var selectedAdmins: Set<EnginePeer.Id>
}

private final class RecentActionsSettingsContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer
    let adminPeers: [EnginePeer]
    let theme: PresentationTheme
    let sheetState: RecentActionsSettingsSheetState
    let toggleActionTypeSectionSelection: (ActionTypeSection) -> Void
    let toggleActionTypeSectionExpansion: (ActionTypeSection) -> Void
    let toggleActionType: (ActionType) -> Void
    let toggleAdmin: (EnginePeer) -> Void
    let toggleAllAdmins: () -> Void

    init(
        context: AccountContext,
        peer: EnginePeer,
        adminPeers: [EnginePeer],
        theme: PresentationTheme,
        sheetState: RecentActionsSettingsSheetState,
        toggleActionTypeSectionSelection: @escaping (ActionTypeSection) -> Void,
        toggleActionTypeSectionExpansion: @escaping (ActionTypeSection) -> Void,
        toggleActionType: @escaping (ActionType) -> Void,
        toggleAdmin: @escaping (EnginePeer) -> Void,
        toggleAllAdmins: @escaping () -> Void
    ) {
        self.context = context
        self.peer = peer
        self.adminPeers = adminPeers
        self.theme = theme
        self.sheetState = sheetState
        self.toggleActionTypeSectionSelection = toggleActionTypeSectionSelection
        self.toggleActionTypeSectionExpansion = toggleActionTypeSectionExpansion
        self.toggleActionType = toggleActionType
        self.toggleAdmin = toggleAdmin
        self.toggleAllAdmins = toggleAllAdmins
    }

    static func ==(lhs: RecentActionsSettingsContentComponent, rhs: RecentActionsSettingsContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.adminPeers != rhs.adminPeers {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.sheetState != rhs.sheetState {
            return false
        }
        return true
    }

    final class View: UIView {
        private let optionsSection = ComponentView<Empty>()
        private let adminsSection = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: RecentActionsSettingsContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            let theme = component.theme
            let sheetState = component.sheetState
            let sideInset: CGFloat = 16.0

            var isGroup = true
            if case let .channel(channel) = component.peer, case .broadcast = channel.info {
                isGroup = false
            }

            var contentHeight: CGFloat = 76.0 + 15.0

            let actionTypeSectionItem: (ActionTypeSection) -> AnyComponentWithIdentity<Empty> = { actionTypeSection in
                let totalCount: Int
                let selectedCount: Int
                let title: String
                let isExpanded = sheetState.expandedSections.contains(actionTypeSection)

                switch actionTypeSection {
                case .members:
                    totalCount = MembersActionType.allCases.count
                    selectedCount = sheetState.selectedMembersActions.count
                    title = isGroup ? environment.strings.Channel_AdminLogFilter_Section_MembersGroup : environment.strings.Channel_AdminLogFilter_Section_MembersChannel
                case .settings:
                    totalCount = SettingsActionType.allCases.count
                    selectedCount = sheetState.selectedSettingsActions.count
                    title = isGroup ? environment.strings.Channel_AdminLogFilter_Section_SettingsGroup : environment.strings.Channel_AdminLogFilter_Section_SettingsChannel
                case .messages:
                    totalCount = MessagesActionType.allCases.count
                    selectedCount = sheetState.selectedMessagesActions.count
                    title = environment.strings.Channel_AdminLogFilter_Section_Messages
                }

                let itemTitle: AnyComponent<Empty> = AnyComponent(HStack([
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(MediaSectionExpandIndicatorComponent(
                        theme: theme,
                        title: "\(selectedCount)/\(totalCount)",
                        isExpanded: isExpanded
                    )))
                ], spacing: 7.0))

                return AnyComponentWithIdentity(id: actionTypeSection, component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: itemTitle,
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                        isSelected: selectedCount == totalCount,
                        toggle: {
                            component.toggleActionTypeSectionSelection(actionTypeSection)
                        }
                    )),
                    icon: .none,
                    accessory: nil,
                    action: { _ in
                        component.toggleActionTypeSectionExpansion(actionTypeSection)
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
                    selectedActionTypes = Set(sheetState.selectedMembersActions.map(ActionType.members))
                case .settings:
                    sectionId = "settings-sub"
                    actionTypes = SettingsActionType.allCases.map(ActionType.settings)
                    selectedActionTypes = Set(sheetState.selectedSettingsActions.map(ActionType.settings))
                case .messages:
                    sectionId = "messages-sub"
                    actionTypes = MessagesActionType.allCases.map(ActionType.messages)
                    selectedActionTypes = Set(sheetState.selectedMessagesActions.map(ActionType.messages))
                }

                var subItems: [AnyComponentWithIdentity<Empty>] = []
                for actionType in actionTypes {
                    let actionItemTitle: String = actionType.title(isGroup: isGroup, strings: environment.strings)

                    subItems.append(AnyComponentWithIdentity(id: actionType, component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: actionItemTitle,
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                            isSelected: selectedActionTypes.contains(actionType),
                            toggle: {
                                component.toggleActionType(actionType)
                            }
                        )),
                        icon: .none,
                        accessory: .none,
                        action: { _ in
                            component.toggleActionType(actionType)
                        },
                        highlighting: .disabled
                    ))))
                }

                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListSubSectionComponent(
                    theme: theme,
                    leftInset: 62.0,
                    items: subItems
                )))
            }

            var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            for actionTypeSection in ActionTypeSection.allCases {
                optionsSectionItems.append(actionTypeSectionItem(actionTypeSection))
                if sheetState.expandedSections.contains(actionTypeSection) {
                    optionsSectionItems.append(expandedActionTypeSectionItem(actionTypeSection))
                }
            }

            self.optionsSection.parentState = state
            let optionsSectionSize = self.optionsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Channel_AdminLogFilter_FilterActionsTypeTitle,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
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
                    self.addSubview(optionsSectionView)
                }
                transition.setFrame(view: optionsSectionView, frame: optionsSectionFrame)
            }
            contentHeight += optionsSectionSize.height
            contentHeight += 24.0

            var peerItems: [AnyComponentWithIdentity<Empty>] = []
            for peer in component.adminPeers {
                peerItems.append(AnyComponentWithIdentity(id: peer.id, component: AnyComponent(AdminUserActionsPeerComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    baseFontSize: presentationData.listsFontSize.baseDisplaySize,
                    sideInset: 0.0,
                    title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                    peer: peer,
                    selectionState: .editing(isSelected: sheetState.selectedAdmins.contains(peer.id)),
                    action: { peer in
                        component.toggleAdmin(peer)
                    }
                ))))
            }

            var adminsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            adminsSectionItems.append(AnyComponentWithIdentity(id: adminsSectionItems.count, component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Channel_AdminLogFilter_ShowAllAdminsActions,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                    isSelected: sheetState.selectedAdmins.count == component.adminPeers.count,
                    toggle: {
                        component.toggleAllAdmins()
                    }
                )),
                icon: .none,
                accessory: .none,
                action: { _ in
                    component.toggleAllAdmins()
                },
                highlighting: .disabled
            ))))
            adminsSectionItems.append(AnyComponentWithIdentity(id: adminsSectionItems.count, component: AnyComponent(ListSubSectionComponent(
                theme: theme,
                leftInset: 62.0,
                items: peerItems
            ))))

            self.adminsSection.parentState = state
            let adminsSectionSize = self.adminsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Channel_AdminLogFilter_FilterActionsAdminsTitle,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
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
                    self.addSubview(adminsSectionView)
                }
                transition.setFrame(view: adminsSectionView, frame: adminsSectionFrame)
            }
            contentHeight += adminsSectionSize.height
            contentHeight += 106.0

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class RecentActionsSettingsResizableSheetComponent: Component {
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

    static func ==(lhs: RecentActionsSettingsResizableSheetComponent, rhs: RecentActionsSettingsResizableSheetComponent) -> Bool {
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

    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()

        private var component: RecentActionsSettingsResizableSheetComponent?
        private weak var state: EmptyComponentState?
        private var isDismissing: Bool = false

        private var expandedSections = Set<ActionTypeSection>()
        private var selectedMembersActions = Set<MembersActionType>()
        private var selectedSettingsActions = Set<SettingsActionType>()
        private var selectedMessagesActions = Set<MessagesActionType>()
        private var selectedAdmins = Set<EnginePeer.Id>()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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

        func update(component: RecentActionsSettingsResizableSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            let controller = environmentValue.controller
            let theme = environmentValue.theme.withModalBlocksBackground()

            if self.component == nil {
                self.selectedMembersActions = Set(MembersActionType.actionTypesFromFlags(component.initialValue.events))
                self.selectedSettingsActions = Set(SettingsActionType.actionTypesFromFlags(component.initialValue.events))
                self.selectedMessagesActions = Set(MessagesActionType.actionTypesFromFlags(component.initialValue.events))
                self.selectedAdmins = component.initialValue.admins.flatMap { Set($0) } ?? Set(component.adminPeers.map(\.id))
            }

            self.component = component
            self.state = state

            let dismiss: (Bool) -> Void = { [weak self] animated in
                guard let self, !self.isDismissing else {
                    return
                }
                self.isDismissing = true

                let performDismiss: () -> Void = {
                    if let controller = controller() as? RecentActionsSettingsSheet {
                        controller.completePendingDismiss()
                        controller.dismiss(animated: false)
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

            let currentState = RecentActionsSettingsSheetState(
                expandedSections: self.expandedSections,
                selectedMembersActions: self.selectedMembersActions,
                selectedSettingsActions: self.selectedSettingsActions,
                selectedMessagesActions: self.selectedMessagesActions,
                selectedAdmins: self.selectedAdmins
            )

            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(RecentActionsSettingsContentComponent(
                        context: component.context,
                        peer: component.peer,
                        adminPeers: component.adminPeers,
                        theme: theme,
                        sheetState: currentState,
                        toggleActionTypeSectionSelection: { [weak self] actionTypeSection in
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
                        },
                        toggleActionTypeSectionExpansion: { [weak self] actionTypeSection in
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
                        toggleActionType: { [weak self] actionType in
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
                        },
                        toggleAdmin: { [weak self] peer in
                            guard let self else {
                                return
                            }

                            if self.selectedAdmins.contains(peer.id) {
                                self.selectedAdmins.remove(peer.id)
                            } else {
                                self.selectedAdmins.insert(peer.id)
                            }

                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .easeInOut)))
                        },
                        toggleAllAdmins: { [weak self] in
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
                    )),
                    titleItem: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environmentValue.strings.Channel_AdminLogFilter_RecentActionsTitle,
                            font: Font.semibold(17.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
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
                    bottomItem: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environmentValue.strings.Channel_AdminLogFilter_ApplyFilter,
                                badge: 0,
                                textColor: theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: theme.list.itemCheckColors.fillColor
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            let result = self.calculateResult()
                            dismiss(true)
                            component.completion(result)
                        }
                    )),
                    backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
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
                forceUpdate: true,
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
    private var dismissCompletion: (() -> Void)?
    
    public init(context: AccountContext, peer: EnginePeer, adminPeers: [EnginePeer], initialValue: Value, completion: @escaping (Value) -> Void) {
        self.context = context
        
        super.init(context: context, component: RecentActionsSettingsResizableSheetComponent(context: context, peer: peer, adminPeers: adminPeers, initialValue: initialValue, completion: completion), navigationBarAppearance: .none)
        
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
    }

    fileprivate func completePendingDismiss() {
        let dismissCompletion = self.dismissCompletion
        self.dismissCompletion = nil
        dismissCompletion?()
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
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
