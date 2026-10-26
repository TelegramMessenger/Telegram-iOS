import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import ButtonComponent
import PresentationDataUtils
import ListSectionComponent
import ListActionItemComponent
import PlainButtonComponent
import ResizableSheetComponent
import GlassBarButtonComponent
import BundleIconComponent
import Markdown
import AlertPeerComponent
import AlertComponent

struct MediaRight: OptionSet, Hashable {
    var rawValue: Int
    
    static let photos = MediaRight(rawValue: 1 << 0)
    static let videos = MediaRight(rawValue: 1 << 1)
    static let stickersAndGifs = MediaRight(rawValue: 1 << 2)
    static let music = MediaRight(rawValue: 1 << 3)
    static let files = MediaRight(rawValue: 1 << 4)
    static let voiceMessages = MediaRight(rawValue: 1 << 5)
    static let videoMessages = MediaRight(rawValue: 1 << 6)
    static let links = MediaRight(rawValue: 1 << 7)
    static let polls = MediaRight(rawValue: 1 << 8)
    static let reactions = MediaRight(rawValue: 1 << 9)
}

extension MediaRight {
    var count: Int {
        var result = 0
        var index = 0
        while index < 31 {
            let currentValue = self.rawValue >> UInt32(index)
            index += 1
            if currentValue == 0 {
                break
            }
            
            if (currentValue & 1) != 0 {
                result += 1
            }
        }
        return result
    }
}

private struct ParticipantRight: OptionSet {
    var rawValue: Int
    
    static let sendMessages = ParticipantRight(rawValue: 1 << 0)
    static let addMembers = ParticipantRight(rawValue: 1 << 2)
    static let pinMessages = ParticipantRight(rawValue: 1 << 3)
    static let changeInfo = ParticipantRight(rawValue: 1 << 4)
}

private func rightsFromBannedRights(_ rights: TelegramChatBannedRightsFlags) -> (participantRights: ParticipantRight, mediaRights: MediaRight) {
    var participantResult: ParticipantRight = [
        .sendMessages,
        .addMembers,
        .pinMessages,
        .changeInfo
    ]
    var mediaResult: MediaRight = [
        .photos,
        .videos,
        .stickersAndGifs,
        .music,
        .files,
        .voiceMessages,
        .videoMessages,
        .links,
        .polls,
        .reactions
    ]
    
    if rights.contains(.banSendText) {
        participantResult.remove(.sendMessages)
    }
    if rights.contains(.banAddMembers) {
        participantResult.remove(.addMembers)
    }
    if rights.contains(.banPinMessages) {
        participantResult.remove(.pinMessages)
    }
    if rights.contains(.banChangeInfo) {
        participantResult.remove(.changeInfo)
    }
    
    if rights.contains(.banSendPhotos) {
        mediaResult.remove(.photos)
    }
    if rights.contains(.banSendVideos) {
        mediaResult.remove(.videos)
    }
    if rights.contains(.banSendStickers) || rights.contains(.banSendGifs) || rights.contains(.banSendGames) || rights.contains(.banSendInline) {
        mediaResult.remove(.stickersAndGifs)
    }
    if rights.contains(.banSendMusic) {
        mediaResult.remove(.music)
    }
    if rights.contains(.banSendFiles) {
        mediaResult.remove(.files)
    }
    if rights.contains(.banSendVoice) {
        mediaResult.remove(.voiceMessages)
    }
    if rights.contains(.banSendInstantVideos) {
        mediaResult.remove(.videoMessages)
    }
    if rights.contains(.banEmbedLinks) {
        mediaResult.remove(.links)
    }
    if rights.contains(.banSendPolls) {
        mediaResult.remove(.polls)
    }
    
    return (participantResult, mediaResult)
}

private func rightFlagsFromRights(participantRights: ParticipantRight, mediaRights: MediaRight) -> TelegramChatBannedRightsFlags {
    var result: TelegramChatBannedRightsFlags = []
    
    if !participantRights.contains(.sendMessages) {
        result.insert(.banSendText)
    }
    if !participantRights.contains(.addMembers) {
        result.insert(.banAddMembers)
    }
    if !participantRights.contains(.pinMessages) {
        result.insert(.banPinMessages)
    }
    if !participantRights.contains(.changeInfo) {
        result.insert(.banChangeInfo)
    }
    
    if !mediaRights.contains(.photos) {
        result.insert(.banSendPhotos)
    }
    if !mediaRights.contains(.videos) {
        result.insert(.banSendVideos)
    }
    if !mediaRights.contains(.stickersAndGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
        result.insert(.banSendInline)
    }
    if !mediaRights.contains(.music) {
        result.insert(.banSendMusic)
    }
    if !mediaRights.contains(.files) {
        result.insert(.banSendFiles)
    }
    if !mediaRights.contains(.voiceMessages) {
        result.insert(.banSendVoice)
    }
    if !mediaRights.contains(.videoMessages) {
        result.insert(.banSendInstantVideos)
    }
    if !mediaRights.contains(.links) {
        result.insert(.banEmbedLinks)
    }
    if !mediaRights.contains(.polls) {
        result.insert(.banSendPolls)
    }
    if !mediaRights.contains(.reactions) {
        result.insert(.banSendReactions)
    }
    
    return result
}

private let allMediaRightItems: [MediaRight] = [
    .photos,
    .videos,
    .stickersAndGifs,
    .music,
    .files,
    .voiceMessages,
    .videoMessages,
    .links,
    .polls,
    .reactions
]

private enum AdminUserActionOptionSection {
    case report
    case deleteAll
    case ban
}

private enum AdminUserDeleteAllOption {
    case messages
    case reactions
}

private enum AdminUserActionConfigItem: Hashable, CaseIterable {
    case sendMessages
    case sendMedia
    case addUsers
    case pinMessages
    case changeInfo
}

private struct AdminUserActionsCommunityBanContext: Equatable {
    let communityId: EnginePeer.Id
    let creatorChatIds: [EnginePeer.Id]
    let joinedChatIds: [EnginePeer.Id]
    let peers: [EnginePeer.Id: EnginePeer]
    let participantCounts: [EnginePeer.Id: Int32]

    var chatCount: Int {
        return Set(self.creatorChatIds + self.joinedChatIds).count
    }
}

private struct AdminUserActionsSheetState: Equatable {
    var isOptionReportExpanded: Bool
    var optionReportSelectedPeers: Set<EnginePeer.Id>
    var isOptionDeleteAllExpanded: Bool
    var optionDeleteAllSelectedPeers: Set<EnginePeer.Id>
    var optionDeleteAllReactionsSelectedPeers: Set<EnginePeer.Id>
    var isOptionBanExpanded: Bool
    var optionBanSelectedPeers: Set<EnginePeer.Id>
    var isConfigurationExpanded: Bool
    var isMediaSectionExpanded: Bool
    var allowedParticipantRights: ParticipantRight
    var allowedMediaRights: MediaRight
    var participantRights: ParticipantRight
    var mediaRights: MediaRight
    var communityBanContext: AdminUserActionsCommunityBanContext?
    var banFromCommunity: Bool
}

private func availableAdminUserActionOptionSections(
    accountPeerId: EnginePeer.Id,
    chatPeer: EnginePeer,
    peers: [RenderedChannelParticipant],
    mode: AdminUserActionsSheet.Mode
) -> [AdminUserActionOptionSection] {
    var result: [AdminUserActionOptionSection] = [.report]
    
    switch mode {
    case .monoforum:
        result.append(.ban)
    case .chat, .chatReaction:
        if case let .channel(channel) = chatPeer {
            if channel.hasPermission(.deleteAllMessages) {
                result.append(.deleteAll)
                
                if channel.hasPermission(.banMembers) {
                    var canBanEveryone = true
                    for peer in peers {
                        if peer.peer.id == accountPeerId {
                            canBanEveryone = false
                            continue
                        }
                        
                        switch peer.participant {
                        case .creator:
                            canBanEveryone = false
                        case let .member(_, _, adminInfo, _, _, _):
                            if let adminInfo {
                                if channel.flags.contains(.isCreator) {
                                } else if adminInfo.promotedBy == accountPeerId {
                                } else {
                                    canBanEveryone = false
                                }
                            }
                        }
                    }
                    
                    if canBanEveryone {
                        result.append(.ban)
                    }
                }
            }
        }
    case .liveStream:
        result.append(.deleteAll)
        result.append(.ban)
    }
    
    return result
}

private func adminUserActionsTitle(
    strings: PresentationStrings,
    mode: AdminUserActionsSheet.Mode,
    peers: [RenderedChannelParticipant],
    selectedDeleteAllPeers: Set<EnginePeer.Id>
) -> String {
    switch mode {
    case .monoforum:
        if let peer = peers.first {
            return strings.Monoforum_DeleteTopic_Title(peer.peer.compactDisplayTitle).string
        } else {
            return strings.Common_Delete
        }
    case let .chat(messageCount, deleteAllMessageCount, _):
        if let deleteAllMessageCount, selectedDeleteAllPeers == Set(peers.map { $0.peer.id }) {
            return strings.Chat_AdminActionSheet_DeleteTitle(Int32(deleteAllMessageCount))
        } else {
            return strings.Chat_AdminActionSheet_DeleteTitle(Int32(messageCount))
        }
    case let .liveStream(messageCount, deleteAllMessageCount, _):
        if let deleteAllMessageCount, selectedDeleteAllPeers == Set(peers.map { $0.peer.id }) {
            return strings.Chat_AdminActionSheet_DeleteTitle(Int32(deleteAllMessageCount))
        } else {
            return strings.Chat_AdminActionSheet_DeleteTitle(Int32(messageCount))
        }
    case .chatReaction:
        return strings.Chat_AdminActionSheet_DeleteReactionTitle
    }
}

private final class AdminUserActionsContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let chatPeer: EnginePeer
    let peers: [RenderedChannelParticipant]
    let mode: AdminUserActionsSheet.Mode
    let theme: PresentationTheme
    let strings: PresentationStrings
    let presentationData: PresentationData
    let sheetState: AdminUserActionsSheetState
    let disableOptionsSectionAnimation: Bool
    let toggleOptionSelection: (AdminUserActionOptionSection) -> Void
    let toggleOptionExpansion: (AdminUserActionOptionSection) -> Void
    let togglePeerSelection: (AdminUserActionOptionSection, EnginePeer) -> Void
    let toggleDeleteAllOptionPeerSelection: (AdminUserDeleteAllOption, EnginePeer) -> Void
    let toggleConfiguration: () -> Void
    let toggleConfigItem: (AdminUserActionConfigItem) -> Void
    let toggleMediaSectionExpansion: () -> Void
    let toggleMediaRight: (MediaRight) -> Void
    let setBanFromCommunity: (Bool) -> Void
    let openCommunity: (EnginePeer.Id) -> Void
    
    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        peers: [RenderedChannelParticipant],
        mode: AdminUserActionsSheet.Mode,
        theme: PresentationTheme,
        strings: PresentationStrings,
        presentationData: PresentationData,
        sheetState: AdminUserActionsSheetState,
        disableOptionsSectionAnimation: Bool,
        toggleOptionSelection: @escaping (AdminUserActionOptionSection) -> Void,
        toggleOptionExpansion: @escaping (AdminUserActionOptionSection) -> Void,
        togglePeerSelection: @escaping (AdminUserActionOptionSection, EnginePeer) -> Void,
        toggleDeleteAllOptionPeerSelection: @escaping (AdminUserDeleteAllOption, EnginePeer) -> Void,
        toggleConfiguration: @escaping () -> Void,
        toggleConfigItem: @escaping (AdminUserActionConfigItem) -> Void,
        toggleMediaSectionExpansion: @escaping () -> Void,
        toggleMediaRight: @escaping (MediaRight) -> Void,
        setBanFromCommunity: @escaping (Bool) -> Void,
        openCommunity: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.peers = peers
        self.mode = mode
        self.theme = theme
        self.strings = strings
        self.presentationData = presentationData
        self.sheetState = sheetState
        self.disableOptionsSectionAnimation = disableOptionsSectionAnimation
        self.toggleOptionSelection = toggleOptionSelection
        self.toggleOptionExpansion = toggleOptionExpansion
        self.togglePeerSelection = togglePeerSelection
        self.toggleDeleteAllOptionPeerSelection = toggleDeleteAllOptionPeerSelection
        self.toggleConfiguration = toggleConfiguration
        self.toggleConfigItem = toggleConfigItem
        self.toggleMediaSectionExpansion = toggleMediaSectionExpansion
        self.toggleMediaRight = toggleMediaRight
        self.setBanFromCommunity = setBanFromCommunity
        self.openCommunity = openCommunity
    }
    
    static func ==(lhs: AdminUserActionsContentComponent, rhs: AdminUserActionsContentComponent) -> Bool {
        return false
    }
    
    final class View: UIView {
        private let optionsSection = ComponentView<Empty>()
        private let optionsFooter = ComponentView<Empty>()
        private let configSection = ComponentView<Empty>()
        private let communityBanSection = ComponentView<Empty>()
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        func update(component: AdminUserActionsContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let sideInset: CGFloat = 16.0
            var contentHeight: CGFloat = 76.0 + 15.0
            
            let availableOptions = availableAdminUserActionOptionSections(
                accountPeerId: component.context.account.peerId,
                chatPeer: component.chatPeer,
                peers: component.peers,
                mode: component.mode
            )
            
            let optionsItem: (AdminUserActionOptionSection) -> AnyComponentWithIdentity<Empty> = { section in
                let sectionId: AnyHashable
                let selectedPeers: Set<EnginePeer.Id>
                var additionalSelectedPeers = Set<EnginePeer.Id>()
                let isExpanded: Bool
                let title: String
                
                switch section {
                case .report:
                    sectionId = "report"
                    selectedPeers = component.sheetState.optionReportSelectedPeers
                    isExpanded = component.sheetState.isOptionReportExpanded
                    title = component.strings.Chat_AdminActionSheet_ReportSpam
                case .deleteAll:
                    sectionId = "delete-all"
                    selectedPeers = component.sheetState.optionDeleteAllSelectedPeers
                    additionalSelectedPeers = component.sheetState.optionDeleteAllReactionsSelectedPeers
                    isExpanded = component.sheetState.isOptionDeleteAllExpanded
                    if component.peers.count == 1 {
                        title = component.strings.Chat_AdminActionSheet_DeleteAllSingle(component.peers[0].peer.compactDisplayTitle).string
                    } else {
                        title = component.strings.Chat_AdminActionSheet_DeleteAllMultiple
                    }
                case .ban:
                    sectionId = "ban"
                    selectedPeers = component.sheetState.optionBanSelectedPeers
                    isExpanded = component.sheetState.isOptionBanExpanded
                    
                    let banTitle: String
                    let restrictTitle: String
                    if component.peers.count == 1 {
                        banTitle = component.strings.Chat_AdminActionSheet_BanSingle(component.peers[0].peer.compactDisplayTitle).string
                        restrictTitle = component.strings.Chat_AdminActionSheet_RestrictSingle(component.peers[0].peer.compactDisplayTitle).string
                    } else {
                        banTitle = component.strings.Chat_AdminActionSheet_BanMultiple
                        restrictTitle = component.strings.Chat_AdminActionSheet_RestrictMultiple
                    }
                    title = component.sheetState.isConfigurationExpanded ? restrictTitle : banTitle
                }
                
                var titleItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                            textColor: component.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )))
                ]
                
                var accessory: ListActionItemComponent.Accessory?
                var isExpandable = false
                if component.peers.count > 1 {
                    let selectedCount = selectedPeers.union(additionalSelectedPeers).count
                    accessory = .custom(ListActionItemComponent.CustomAccessory(
                        component: AnyComponentWithIdentity(id: 0, component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(OptionSectionExpandIndicatorComponent(
                                theme: component.theme,
                                count: selectedCount == 0 ? component.peers.count : selectedCount,
                                isExpanded: isExpanded
                            )),
                            effectAlignment: .center,
                            action: {
                                component.toggleOptionExpansion(section)
                            },
                            animateScale: false
                        ))),
                        insets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 2.0),
                        isInteractive: true
                    ))
                } else if case .deleteAll = section {
                    var count = 0
                    if !selectedPeers.isEmpty {
                        count += 1
                    }
                    if !additionalSelectedPeers.isEmpty {
                        count += 1
                    }
                    titleItems.append(
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(MediaSectionExpandIndicatorComponent(
                            theme: component.theme,
                            title: "\(count)/2",
                            isExpanded: isExpanded
                        )))
                    )
                    isExpandable = true
                }
                
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListActionItemComponent(
                    theme: component.theme,
                    style: .glass,
                    title: AnyComponent(HStack(titleItems, spacing: 7.0)),
                    leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                        isSelected: !selectedPeers.isEmpty || !additionalSelectedPeers.isEmpty,
                        toggle: {
                            component.toggleOptionSelection(section)
                        }
                    )),
                    icon: .none,
                    accessory: accessory,
                    action: { _ in
                        if isExpandable {
                            component.toggleOptionExpansion(section)
                        } else {
                            component.toggleOptionSelection(section)
                        }
                    },
                    highlighting: .disabled
                )))
            }
            
            let expandedPeersItem: (AdminUserActionOptionSection) -> AnyComponentWithIdentity<Empty> = { section in
                let sectionId: AnyHashable
                let selectedPeers: Set<EnginePeer.Id>
                var additionalSelectedPeers = Set<EnginePeer.Id>()
                switch section {
                case .report:
                    sectionId = "report-peers"
                    selectedPeers = component.sheetState.optionReportSelectedPeers
                case .deleteAll:
                    sectionId = "delete-all-peers"
                    selectedPeers = component.sheetState.optionDeleteAllSelectedPeers
                    additionalSelectedPeers = component.sheetState.optionDeleteAllReactionsSelectedPeers
                case .ban:
                    sectionId = "ban-peers"
                    selectedPeers = component.sheetState.optionBanSelectedPeers
                }
                
                var subItems: [AnyComponentWithIdentity<Empty>] = []
                if component.peers.count > 1 {
                    for peer in component.peers {
                        subItems.append(AnyComponentWithIdentity(id: peer.peer.id, component: AnyComponent(AdminUserActionsPeerComponent(
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            baseFontSize: component.presentationData.listsFontSize.baseDisplaySize,
                            sideInset: 0.0,
                            title: peer.peer.displayTitle(strings: component.strings, displayOrder: .firstLast),
                            peer: peer.peer,
                            selectionState: .editing(isSelected: selectedPeers.contains(peer.peer.id) || additionalSelectedPeers.contains(peer.peer.id)),
                            action: { peer in
                                component.togglePeerSelection(section, peer)
                            }
                        ))))
                    }
                } else {
                    subItems.append(
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: component.theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: component.strings.Chat_AdminActionSheet_DeleteAllMessages,
                                    font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                    textColor: component.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                                isSelected: !selectedPeers.isEmpty,
                                toggle: {
                                    component.toggleDeleteAllOptionPeerSelection(.messages, component.peers[0].peer)
                                }
                            )),
                            icon: .none,
                            accessory: nil,
                            action: { _ in
                                component.toggleDeleteAllOptionPeerSelection(.messages, component.peers[0].peer)
                            },
                            highlighting: .disabled
                        )))
                    )
                    subItems.append(
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(ListActionItemComponent(
                            theme: component.theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: component.strings.Chat_AdminActionSheet_DeleteAllReactions,
                                    font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                    textColor: component.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                                isSelected: !additionalSelectedPeers.isEmpty,
                                toggle: {
                                    component.toggleDeleteAllOptionPeerSelection(.reactions, component.peers[0].peer)
                                }
                            )),
                            icon: .none,
                            accessory: nil,
                            action: { _ in
                                component.toggleDeleteAllOptionPeerSelection(.reactions, component.peers[0].peer)
                            },
                            highlighting: .disabled
                        )))
                    )
                }
                
                return AnyComponentWithIdentity(id: sectionId, component: AnyComponent(ListSubSectionComponent(
                    theme: component.theme,
                    leftInset: 43.0,
                    items: subItems
                )))
            }
            
            var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
            for option in availableOptions {
                let isExpanded: Bool
                switch option {
                case .report:
                    isExpanded = component.sheetState.isOptionReportExpanded
                case .deleteAll:
                    isExpanded = component.sheetState.isOptionDeleteAllExpanded
                case .ban:
                    isExpanded = component.sheetState.isOptionBanExpanded
                }
                
                optionsSectionItems.append(optionsItem(option))
                if isExpanded {
                    optionsSectionItems.append(expandedPeersItem(option))
                }
            }
            
            let optionsSectionTransition: ComponentTransition = component.disableOptionsSectionAnimation ? transition.withAnimation(.none) : transition
            let optionsSectionSize = self.optionsSection.update(
                transition: optionsSectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: component.theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.strings.Chat_AdminActionSheet_RestrictSectionHeader,
                            font: Font.regular(component.presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: component.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: optionsSectionItems,
                    isModal: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
            )
            let optionsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: optionsSectionSize)
            self.optionsSection.parentState = state
            if let optionsSectionView = self.optionsSection.view {
                if optionsSectionView.superview == nil {
                    self.addSubview(optionsSectionView)
                }
                transition.setFrame(view: optionsSectionView, frame: optionsSectionFrame)
            }
            contentHeight += optionsSectionSize.height
            
            let partiallyRestrictTitle: String
            let fullyBanTitle: String
            if component.peers.count == 1 {
                partiallyRestrictTitle = component.strings.Chat_AdminActionSheet_RestrictFooterSingle
                fullyBanTitle = component.strings.Chat_AdminActionSheet_BanFooterSingle
            } else {
                partiallyRestrictTitle = component.strings.Chat_AdminActionSheet_RestrictFooterMultiple
                fullyBanTitle = component.strings.Chat_AdminActionSheet_BanFooterMultiple
            }
            
            let optionsFooterSize = self.optionsFooter.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(OptionsSectionFooterComponent(
                        theme: component.theme,
                        text: component.sheetState.isConfigurationExpanded ? fullyBanTitle : partiallyRestrictTitle,
                        fontSize: component.presentationData.listsFontSize.itemListBaseHeaderFontSize,
                        isExpanded: component.sheetState.isConfigurationExpanded
                    )),
                    effectAlignment: .left,
                    contentInsets: UIEdgeInsets(),
                    action: {
                        component.toggleConfiguration()
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            
            var configSectionItems: [AnyComponentWithIdentity<Empty>] = []
            
            if case let .channel(channel) = component.chatPeer, channel.isMonoForum {
            } else if case .liveStream = component.mode {
            } else {
                var allConfigItems: [(AdminUserActionConfigItem, Bool)] = []
                if !component.sheetState.allowedMediaRights.isEmpty || !component.sheetState.allowedParticipantRights.isEmpty {
                    for configItem in AdminUserActionConfigItem.allCases {
                        let isEnabled: Bool
                        switch configItem {
                        case .sendMessages:
                            isEnabled = component.sheetState.allowedParticipantRights.contains(.sendMessages)
                        case .sendMedia:
                            isEnabled = !component.sheetState.allowedMediaRights.isEmpty
                        case .addUsers:
                            isEnabled = component.sheetState.allowedParticipantRights.contains(.addMembers)
                        case .pinMessages:
                            isEnabled = component.sheetState.allowedParticipantRights.contains(.pinMessages)
                        case .changeInfo:
                            isEnabled = component.sheetState.allowedParticipantRights.contains(.changeInfo)
                        }
                        allConfigItems.append((configItem, isEnabled))
                    }
                }
                
                for (configItem, isEnabled) in allConfigItems {
                    let itemTitle: AnyComponent<Empty>
                    let itemValue: Bool
                    switch configItem {
                    case .sendMessages:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.strings.Channel_BanUser_PermissionSendMessages,
                                font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                textColor: component.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = component.sheetState.participantRights.contains(.sendMessages)
                    case .sendMedia:
                        if isEnabled {
                            itemTitle = AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: component.strings.Channel_BanUser_PermissionSendMedia,
                                        font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                        textColor: component.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(MediaSectionExpandIndicatorComponent(
                                    theme: component.theme,
                                    title: "\(component.sheetState.mediaRights.count)/\(component.sheetState.allowedMediaRights.count)",
                                    isExpanded: component.sheetState.isMediaSectionExpanded
                                )))
                            ], spacing: 7.0))
                        } else {
                            itemTitle = AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: component.strings.Channel_BanUser_PermissionSendMedia,
                                    font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                    textColor: component.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))
                        }
                        itemValue = !component.sheetState.mediaRights.isEmpty
                    case .addUsers:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.strings.Channel_BanUser_PermissionAddMembers,
                                font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                textColor: component.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = component.sheetState.participantRights.contains(.addMembers)
                    case .pinMessages:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.strings.Channel_EditAdmin_PermissionPinMessages,
                                font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                textColor: component.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = component.sheetState.participantRights.contains(.pinMessages)
                    case .changeInfo:
                        itemTitle = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: component.strings.Channel_BanUser_PermissionChangeGroupInfo,
                                font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                textColor: component.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                        itemValue = component.sheetState.participantRights.contains(.changeInfo)
                    }
                    
                    configSectionItems.append(AnyComponentWithIdentity(id: configItem, component: AnyComponent(ListActionItemComponent(
                        theme: component.theme,
                        style: .glass,
                        title: itemTitle,
                        accessory: .toggle(ListActionItemComponent.Toggle(
                            style: isEnabled ? .icons : .lock,
                            isOn: itemValue,
                            isInteractive: isEnabled,
                            action: isEnabled ? { _ in
                                component.toggleConfigItem(configItem)
                            } : nil
                        )),
                        action: ((isEnabled && configItem == .sendMedia) || !isEnabled) ? { _ in
                            if !isEnabled {
                                environment.controller()?.present(textAlertController(
                                    context: component.context,
                                    title: nil,
                                    text: component.strings.GroupPermission_PermissionDisabledByDefault,
                                    actions: [
                                        TextAlertAction(type: .defaultAction, title: component.strings.Common_OK, action: {
                                        })
                                    ]
                                ), in: .window(.root))
                            } else {
                                component.toggleMediaSectionExpansion()
                            }
                        } : nil,
                        highlighting: .disabled
                    ))))
                    
                    if isEnabled, case .sendMedia = configItem, component.sheetState.isMediaSectionExpanded {
                        var mediaItems: [AnyComponentWithIdentity<Empty>] = []
                        mediaRightsLoop: for possibleMediaItem in allMediaRightItems {
                            if !component.sheetState.allowedMediaRights.contains(possibleMediaItem) {
                                continue
                            }
                            
                            let mediaItemTitle: String
                            switch possibleMediaItem {
                            case .photos:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendPhoto
                            case .videos:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendVideo
                            case .stickersAndGifs:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendStickersAndGifs
                            case .music:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendMusic
                            case .files:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendFile
                            case .voiceMessages:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendVoiceMessage
                            case .videoMessages:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendVideoMessage
                            case .links:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionEmbedLinks
                            case .polls:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendPolls
                            case .reactions:
                                mediaItemTitle = component.strings.Channel_BanUser_PermissionSendReactions
                            default:
                                continue mediaRightsLoop
                            }
                            
                            mediaItems.append(AnyComponentWithIdentity(id: possibleMediaItem, component: AnyComponent(ListActionItemComponent(
                                theme: component.theme,
                                style: .glass,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: mediaItemTitle,
                                            font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                            textColor: component.theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    )))
                                ], alignment: .left, spacing: 2.0)),
                                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                                    isSelected: component.sheetState.mediaRights.contains(possibleMediaItem),
                                    toggle: {
                                        component.toggleMediaRight(possibleMediaItem)
                                    }
                                )),
                                icon: .none,
                                accessory: .none,
                                action: { _ in
                                    component.toggleMediaRight(possibleMediaItem)
                                },
                                highlighting: .disabled
                            ))))
                        }
                        configSectionItems.append(AnyComponentWithIdentity(id: "media-sub", component: AnyComponent(ListSubSectionComponent(
                            theme: component.theme,
                            leftInset: 0.0,
                            items: mediaItems
                        ))))
                    }
                }
            }
            
            let configSectionSize = self.configSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: component.theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.peers.count == 1 ? component.strings.Chat_AdminActionSheet_PermissionsSectionHeader : component.strings.Chat_AdminActionSheet_PermissionsSectionHeaderMultiple,
                            font: Font.regular(component.presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: component.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: configSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
            )
            let configSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 30.0), size: configSectionSize)
            self.configSection.parentState = state
            if let configSectionView = self.configSection.view {
                if configSectionView.superview == nil {
                    configSectionView.clipsToBounds = true
                    configSectionView.layer.cornerRadius = 11.0
                    self.addSubview(configSectionView)
                }
                let effectiveConfigSectionFrame: CGRect
                if component.sheetState.isConfigurationExpanded {
                    effectiveConfigSectionFrame = configSectionFrame
                } else {
                    effectiveConfigSectionFrame = CGRect(origin: CGPoint(x: configSectionFrame.minX, y: configSectionFrame.minY - 30.0), size: CGSize(width: configSectionFrame.width, height: 0.0))
                }
                transition.setFrame(view: configSectionView, frame: effectiveConfigSectionFrame)
                transition.setAlpha(view: configSectionView, alpha: component.sheetState.isConfigurationExpanded ? 1.0 : 0.0)
            }
            
            if availableOptions.contains(.ban) && !configSectionItems.isEmpty {
                let optionsFooterFrame: CGRect
                if component.sheetState.isConfigurationExpanded {
                    contentHeight += 30.0
                    contentHeight += configSectionSize.height
                    contentHeight += 7.0
                    optionsFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: optionsFooterSize)
                    contentHeight += optionsFooterSize.height
                } else {
                    contentHeight += 7.0
                    optionsFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: optionsFooterSize)
                    contentHeight += optionsFooterSize.height
                }
                self.optionsFooter.parentState = state
                if let optionsFooterView = self.optionsFooter.view {
                    if optionsFooterView.superview == nil {
                        self.addSubview(optionsFooterView)
                    }
                    transition.setFrame(view: optionsFooterView, frame: optionsFooterFrame)
                    transition.setAlpha(view: optionsFooterView, alpha: 1.0)
                }
            } else {
                self.optionsFooter.parentState = state
                if let optionsFooterView = self.optionsFooter.view {
                    if optionsFooterView.superview == nil {
                        self.addSubview(optionsFooterView)
                    }
                    let optionsFooterFrame = CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: optionsFooterSize)
                    transition.setFrame(view: optionsFooterView, frame: optionsFooterFrame)
                    transition.setAlpha(view: optionsFooterView, alpha: 0.0)
                }
            }
            
            if let communityBanContext = component.sheetState.communityBanContext {
                contentHeight += 18.0
                
                var transition = transition
                if self.communityBanSection.view == nil {
                    transition = .immediate
                }

                if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== component.theme {
                    self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: component.theme.list.itemAccentColor)!, component.theme)
                }

                let linkAttributeKey = NSAttributedString.Key(rawValue: "URL")
                let footerAttributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(component.presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: component.theme.list.freeTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(component.presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: component.theme.list.freeTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(component.presentationData.listsFontSize.itemListBaseHeaderFontSize), textColor: component.theme.list.itemAccentColor),
                    linkAttribute: { link in
                        return ("URL", link)
                    }
                )
                let footerRawText = component.strings.Community_AdminActions_Footer(Int32(clamping: communityBanContext.chatCount)).replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                let footerText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(footerRawText, attributes: footerAttributes))
                if let range = footerText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                    footerText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: footerText.string))
                }

                let communityBanSectionSize = self.communityBanSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: component.theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(footerText),
                            maximumNumberOfLines: 0,
                            highlightColor: component.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[linkAttributeKey] {
                                    return linkAttributeKey
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { attributes, _ in
                                guard let link = attributes[linkAttributeKey] as? String, link == "community" else {
                                    return
                                }
                                component.openCommunity(communityBanContext.communityId)
                            }
                        )),
                        items: [
                            AnyComponentWithIdentity(id: "ban", component: AnyComponent(ListActionItemComponent(
                                theme: component.theme,
                                style: .glass,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: component.strings.Community_AdminActions_BanFromCommunity,
                                        font: Font.regular(component.presentationData.listsFontSize.baseDisplaySize),
                                        textColor: component.theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                )),
                                accessory: .toggle(ListActionItemComponent.Toggle(
                                    style: .regular,
                                    isOn: component.sheetState.banFromCommunity,
                                    action: { value in
                                        component.setBanFromCommunity(value)
                                    }
                                )),
                                action: { _ in
                                    component.setBanFromCommunity(!component.sheetState.banFromCommunity)
                                },
                                highlighting: .disabled
                            )))
                        ],
                        isModal: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100000.0)
                )
                let communityBanSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: communityBanSectionSize)
                self.communityBanSection.parentState = state
                if let communityBanSectionView = self.communityBanSection.view {
                    if communityBanSectionView.superview == nil {
                        self.addSubview(communityBanSectionView)
                    }
                    transition.setFrame(view: communityBanSectionView, frame: communityBanSectionFrame)
                    transition.setAlpha(view: communityBanSectionView, alpha: 1.0)
                }
                contentHeight += communityBanSectionSize.height
            } else {
                self.communityBanSection.parentState = state
                if let communityBanSectionView = self.communityBanSection.view {
                    transition.setFrame(view: communityBanSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: 0.0)))
                    transition.setAlpha(view: communityBanSectionView, alpha: 0.0)
                }
            }

            contentHeight += 36.0 + 52.0 + 30.0
            
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

private final class AdminUserActionsSheetComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let chatPeer: EnginePeer
    let peers: [RenderedChannelParticipant]
    let mode: AdminUserActionsSheet.Mode
    
    init(
        context: AccountContext,
        chatPeer: EnginePeer,
        peers: [RenderedChannelParticipant],
        mode: AdminUserActionsSheet.Mode
    ) {
        self.context = context
        self.chatPeer = chatPeer
        self.peers = peers
        self.mode = mode
    }
    
    static func ==(lhs: AdminUserActionsSheetComponent, rhs: AdminUserActionsSheetComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, ResizableSheetComponentEnvironment)>()
        private let animateOut = ActionSlot<Action<Void>>()
        
        private var component: AdminUserActionsSheetComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        private var isDismissing: Bool = false
        
        private var isOptionReportExpanded: Bool = false
        private var optionReportSelectedPeers = Set<EnginePeer.Id>()
        private var isOptionDeleteAllExpanded: Bool = false
        private var optionDeleteAllSelectedPeers = Set<EnginePeer.Id>()
        private var optionDeleteAllReactionsSelectedPeers = Set<EnginePeer.Id>()
        private var isOptionBanExpanded: Bool = false
        private var optionBanSelectedPeers = Set<EnginePeer.Id>()
        
        private var isConfigurationExpanded: Bool = false
        private var isMediaSectionExpanded: Bool = false
        
        private var allowedParticipantRights: ParticipantRight = []
        private var allowedMediaRights: MediaRight = []
        private var participantRights: ParticipantRight = []
        private var mediaRights: MediaRight = []
        private var communityBanContext: AdminUserActionsCommunityBanContext?
        private var banFromCommunity: Bool = false
        private var communityBanContextKey: (communityId: EnginePeer.Id, participantId: EnginePeer.Id)?
        private let communityBanDisposable = MetaDisposable()
        
        private var previousWasConfigurationExpanded: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        deinit {
            self.communityBanDisposable.dispose()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func resetCommunityBanContext() {
            self.communityBanContextKey = nil
            self.communityBanContext = nil
            self.banFromCommunity = false
            self.communityBanDisposable.set(nil)
        }

        private func updateCommunityBanContext(component: AdminUserActionsSheetComponent) {
            guard component.peers.count == 1 else {
                if self.communityBanContextKey != nil || self.communityBanContext != nil || self.banFromCommunity {
                    self.resetCommunityBanContext()
                }
                return
            }
            guard case let .channel(channel) = component.chatPeer, case .group = channel.info, let communityId = channel.linkedCommunityId else {
                if self.communityBanContextKey != nil || self.communityBanContext != nil || self.banFromCommunity {
                    self.resetCommunityBanContext()
                }
                return
            }

            let participantId = component.peers[0].peer.id
            if let communityBanContextKey = self.communityBanContextKey, communityBanContextKey.communityId == communityId, communityBanContextKey.participantId == participantId {
                return
            }

            self.communityBanContextKey = (communityId: communityId, participantId: participantId)
            self.communityBanContext = nil
            self.banFromCommunity = false

            let signal = combineLatest(
                component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: communityId)),
                component.context.engine.peers.fetchChannelParticipant(peerId: communityId, participantId: participantId),
                component.context.engine.peers.communityParticipantJoinedChats(communityId: communityId, participantId: participantId)
            )
            |> mapToSignal { communityPeer, participant, joinedChats -> Signal<(EnginePeer?, ChannelParticipant?, CommunityParticipantJoinedChats, [EnginePeer.Id: Int32]), NoError> in
                if joinedChats.creatorChatIds.isEmpty {
                    return .single((communityPeer, participant, joinedChats, [:]))
                }
                return component.context.engine.data.get(EngineDataMap(
                    joinedChats.creatorChatIds.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init)
                ))
                |> map { participantCountMap -> (EnginePeer?, ChannelParticipant?, CommunityParticipantJoinedChats, [EnginePeer.Id: Int32]) in
                    var participantCounts: [EnginePeer.Id: Int32] = [:]
                    for peerId in joinedChats.creatorChatIds {
                        if let maybeParticipantCount = participantCountMap[peerId], let participantCount = maybeParticipantCount {
                            participantCounts[peerId] = Int32(participantCount)
                        }
                    }
                    return (communityPeer, participant, joinedChats, participantCounts)
                }
            }
            |> deliverOnMainQueue

            self.communityBanDisposable.set(signal.startStrict(next: { [weak self] communityPeer, _, joinedChats, participantCounts in
                guard let self else {
                    return
                }
                guard let communityBanContextKey = self.communityBanContextKey, communityBanContextKey.communityId == communityId, communityBanContextKey.participantId == participantId else {
                    return
                }

                var communityBanContext: AdminUserActionsCommunityBanContext?
                if let communityPeer, case let .community(community) = communityPeer, community.hasPermission(.banUsers) {
                    let isRegularMember = true
//                    if let participant {
//                        switch participant {
//                        case .creator:
//                            isRegularMember = false
//                        case let .member(_, _, adminInfo, _, _, _):
//                            isRegularMember = adminInfo == nil
//                        }
//                    }

                    let chatIds = Set(joinedChats.creatorChatIds + joinedChats.joinedChatIds)
                    if isRegularMember && !chatIds.isEmpty {
                        communityBanContext = AdminUserActionsCommunityBanContext(
                            communityId: communityId,
                            creatorChatIds: joinedChats.creatorChatIds,
                            joinedChatIds: joinedChats.joinedChatIds,
                            peers: joinedChats.peers,
                            participantCounts: participantCounts
                        )
                    }
                }

                self.communityBanContext = communityBanContext
                if communityBanContext == nil {
                    self.banFromCommunity = false
                }
                if !self.isUpdating {
                    self.state?.updated(transition: .spring(duration: 0.35))
                }
            }))
        }
        
        private func calculateMonoforumResult() -> AdminUserActionsSheet.MonoforumResult {
            return AdminUserActionsSheet.MonoforumResult(
                ban: !self.optionBanSelectedPeers.isEmpty,
                reportSpam: !self.optionReportSelectedPeers.isEmpty
            )
        }
        
        private func calculateChatResult() -> AdminUserActionsSheet.ChatResult {
            var reportSpamPeers: [EnginePeer.Id] = []
            var deleteAllFromPeers: [EnginePeer.Id] = []
            var deleteAllReactionsFromPeers: [EnginePeer.Id] = []
            var banPeers: [EnginePeer.Id] = []
            var updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights] = [:]
            
            for id in self.optionReportSelectedPeers.sorted() {
                reportSpamPeers.append(id)
            }
            for id in self.optionDeleteAllSelectedPeers.sorted() {
                deleteAllFromPeers.append(id)
            }
            
            for id in self.optionDeleteAllReactionsSelectedPeers.sorted() {
                deleteAllReactionsFromPeers.append(id)
            }
            
            if !self.isConfigurationExpanded {
                for id in self.optionBanSelectedPeers.sorted() {
                    banPeers.append(id)
                }
            } else {
                let banFlags = rightFlagsFromRights(participantRights: self.participantRights, mediaRights: self.mediaRights)
                let bannedRights = TelegramChatBannedRights(flags: banFlags, untilDate: Int32.max)
                for id in self.optionBanSelectedPeers.sorted() {
                    updateBannedRights[id] = bannedRights
                }
            }
            
            var banFromCommunity: AdminUserActionsSheet.CommunityBanResult?
            if self.banFromCommunity, let communityBanContext = self.communityBanContext, let participantId = self.component?.peers.first?.peer.id {
                banFromCommunity = AdminUserActionsSheet.CommunityBanResult(
                    communityId: communityBanContext.communityId,
                    participantId: participantId
                )
            }

            return AdminUserActionsSheet.ChatResult(
                reportSpamPeers: reportSpamPeers,
                deleteAllFromPeers: deleteAllFromPeers,
                deleteAllReactionsFromPeers: deleteAllReactionsFromPeers,
                banPeers: banPeers,
                updateBannedRights: updateBannedRights,
                banFromCommunity: banFromCommunity
            )
        }
        
        private func calculateLiveStreamResult() -> AdminUserActionsSheet.LiveStreamResult {
            return AdminUserActionsSheet.LiveStreamResult(
                reportSpam: !self.optionReportSelectedPeers.isEmpty,
                deleteAll: !self.optionDeleteAllSelectedPeers.isEmpty,
                ban: !self.optionBanSelectedPeers.isEmpty
            )
        }
        
        func update(component: AdminUserActionsSheetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                let _ = (component.context.account.postbox.peerView(id: component.chatPeer.id)
                |> take(1)).start(next: { [weak self] peerView in
                    guard let self else {
                        return
                    }
                    
                    var selectAll = false
                    if let cachedData = peerView.cachedData as? CachedChannelData {
                        if let memberCount = cachedData.participantsSummary.memberCount, memberCount >= 1000 {
                            selectAll = true
                        } else if case let .known(peerId) = cachedData.linkedDiscussionPeerId, let _ = peerId {
                            selectAll = true
                        }
                    }
                    
                    if selectAll && !"".isEmpty {
                        var selectedPeers = Set<EnginePeer.Id>()
                        for peer in component.peers {
                            selectedPeers.insert(peer.peer.id)
                        }
                        self.optionReportSelectedPeers = selectedPeers
                        self.optionDeleteAllSelectedPeers = selectedPeers
                        self.optionBanSelectedPeers = selectedPeers
                    }
                    
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
                
                var (allowedParticipantRights, allowedMediaRights) = rightsFromBannedRights([])
                if case let .channel(channel) = component.chatPeer {
                    (allowedParticipantRights, allowedMediaRights) = rightsFromBannedRights(channel.defaultBannedRights?.flags ?? [])
                }
                
                var (commonParticipantRights, commonMediaRights) = rightsFromBannedRights([])
                
                loop: for peer in component.peers {
                    var (peerParticipantRights, peerMediaRights) = rightsFromBannedRights([])
                    switch peer.participant {
                    case .creator:
                        allowedParticipantRights = []
                        allowedMediaRights = []
                        break loop
                    case let .member(_, _, adminInfo, banInfo, _, _):
                        if adminInfo != nil {
                            (allowedParticipantRights, allowedMediaRights) = rightsFromBannedRights([])
                            break loop
                        } else if let banInfo {
                            (peerParticipantRights, peerMediaRights) = rightsFromBannedRights(banInfo.rights.flags)
                        }
                    }
                    peerParticipantRights = peerParticipantRights.intersection(allowedParticipantRights)
                    peerMediaRights = peerMediaRights.intersection(allowedMediaRights)
                    
                    commonParticipantRights = commonParticipantRights.intersection(peerParticipantRights)
                    commonMediaRights = commonMediaRights.intersection(peerMediaRights)
                }
                
                commonParticipantRights = commonParticipantRights.intersection(allowedParticipantRights)
                commonMediaRights = commonMediaRights.intersection(allowedMediaRights)
                
                self.allowedParticipantRights = allowedParticipantRights
                self.participantRights = commonParticipantRights
                
                self.allowedMediaRights = allowedMediaRights
                self.mediaRights = commonMediaRights
            }
            
            self.component = component
            self.state = state
            self.updateCommunityBanContext(component: component)
            
            let environmentValue = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environmentValue
            let controller = environmentValue.controller
            let theme = environmentValue.theme.withModalBlocksBackground()
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            let dismiss: (Bool) -> Void = { [weak self] animated in
                guard let self, !self.isDismissing else {
                    return
                }
                self.isDismissing = true
                
                let performDismiss: () -> Void = {
                    if let controller = controller() as? AdminUserActionsSheet {
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
            
            let disableOptionsSectionAnimation = self.previousWasConfigurationExpanded != self.isConfigurationExpanded
            self.previousWasConfigurationExpanded = self.isConfigurationExpanded
            
            let currentState = AdminUserActionsSheetState(
                isOptionReportExpanded: self.isOptionReportExpanded,
                optionReportSelectedPeers: self.optionReportSelectedPeers,
                isOptionDeleteAllExpanded: self.isOptionDeleteAllExpanded,
                optionDeleteAllSelectedPeers: self.optionDeleteAllSelectedPeers,
                optionDeleteAllReactionsSelectedPeers: self.optionDeleteAllReactionsSelectedPeers,
                isOptionBanExpanded: self.isOptionBanExpanded,
                optionBanSelectedPeers: self.optionBanSelectedPeers,
                isConfigurationExpanded: self.isConfigurationExpanded,
                isMediaSectionExpanded: self.isMediaSectionExpanded,
                allowedParticipantRights: self.allowedParticipantRights,
                allowedMediaRights: self.allowedMediaRights,
                participantRights: self.participantRights,
                mediaRights: self.mediaRights,
                communityBanContext: self.communityBanContext,
                banFromCommunity: self.banFromCommunity
            )
            
            let commitMainAction: () -> Void = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                let monoforumResult = self.calculateMonoforumResult()
                let chatResult = self.calculateChatResult()
                let liveStreamResult = self.calculateLiveStreamResult()
                
                dismiss(true)
                
                switch component.mode {
                case let .monoforum(completion):
                    completion(monoforumResult)
                case let .chat(_, _, completion):
                    completion(chatResult)
                case let .liveStream(_, _, completion):
                    completion(liveStreamResult)
                case let .chatReaction(completion):
                    completion(chatResult)
                }
            }

            let performMainAction: () -> Void = { [weak self] in
                guard let self, let component = self.component else {
                    return
                }

                if self.banFromCommunity, let communityBanContext = self.communityBanContext, !communityBanContext.creatorChatIds.isEmpty, let peer = component.peers.first {
                    let warningChatCount = environmentValue.strings.Community_AdminActions_WarningChatCount(Int32(clamping: communityBanContext.creatorChatIds.count))
                    var alertContent: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(
                                AlertTitleComponent(title: environmentValue.strings.Community_AdminActions_WarningTitle)
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: "text",
                            component: AnyComponent(
                                AlertTextComponent(content: .plain(environmentValue.strings.Community_AdminActions_WarningText(peer.peer.compactDisplayTitle, warningChatCount).string))
                            )
                        )
                    ]

                    for creatorChatId in communityBanContext.creatorChatIds {
                        guard let creatorChatPeer = communityBanContext.peers[creatorChatId] else {
                            continue
                        }
                        alertContent.append(AnyComponentWithIdentity(
                            id: AnyHashable(creatorChatId),
                            component: AnyComponent(AlertPeerComponent(
                                context: component.context,
                                peer: creatorChatPeer,
                                memberCount: communityBanContext.participantCounts[creatorChatId]
                            ))
                        ))
                    }

                    let alertScreen = AlertScreen(
                        context: component.context,
                        content: alertContent,
                        actions: [
                            .init(title: environmentValue.strings.Common_Cancel),
                            .init(title: environmentValue.strings.Conversation_ContextMenuBanFull, type: .defaultDestructive, action: {
                                commitMainAction()
                            })
                        ]
                    )

                    environmentValue.controller()?.present(alertScreen, in: .window(.root))
                } else {
                    commitMainAction()
                }
            }
            
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<ViewControllerComponentContainer.Environment>(
                    content: AnyComponent<ViewControllerComponentContainer.Environment>(AdminUserActionsContentComponent(
                        context: component.context,
                        chatPeer: component.chatPeer,
                        peers: component.peers,
                        mode: component.mode,
                        theme: theme,
                        strings: environmentValue.strings,
                        presentationData: presentationData,
                        sheetState: currentState,
                        disableOptionsSectionAnimation: disableOptionsSectionAnimation,
                        toggleOptionSelection: { [weak self] section in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            var selectedPeers: Set<EnginePeer.Id>
                            switch section {
                            case .report:
                                selectedPeers = self.optionReportSelectedPeers
                            case .deleteAll:
                                let allPeerIds = Set(component.peers.map { $0.peer.id })
                                if self.optionDeleteAllSelectedPeers.isEmpty && self.optionDeleteAllReactionsSelectedPeers.isEmpty {
                                    self.optionDeleteAllSelectedPeers = allPeerIds
                                    self.optionDeleteAllReactionsSelectedPeers = allPeerIds
                                } else {
                                    self.optionDeleteAllSelectedPeers.removeAll()
                                    self.optionDeleteAllReactionsSelectedPeers.removeAll()
                                }

                                self.state?.updated(transition: .spring(duration: 0.35))
                                return
                            case .ban:
                                selectedPeers = self.optionBanSelectedPeers
                            }
                            
                            if selectedPeers.isEmpty {
                                for peer in component.peers {
                                    selectedPeers.insert(peer.peer.id)
                                }
                            } else {
                                selectedPeers.removeAll()
                            }
                            
                            switch section {
                            case .report:
                                self.optionReportSelectedPeers = selectedPeers
                            case .deleteAll:
                                self.optionDeleteAllSelectedPeers = selectedPeers
                            case .ban:
                                self.optionBanSelectedPeers = selectedPeers
                                if self.isConfigurationExpanded && self.optionBanSelectedPeers.isEmpty {
                                    self.isConfigurationExpanded = false
                                }
                            }
                            
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        toggleOptionExpansion: { [weak self] section in
                            guard let self else {
                                return
                            }
                            
                            switch section {
                            case .report:
                                self.isOptionReportExpanded = !self.isOptionReportExpanded
                            case .deleteAll:
                                self.isOptionDeleteAllExpanded = !self.isOptionDeleteAllExpanded
                            case .ban:
                                self.isOptionBanExpanded = !self.isOptionBanExpanded
                            }
                            
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        togglePeerSelection: { [weak self] section, peer in
                            guard let self else {
                                return
                            }
                            
                            var selectedPeers: Set<EnginePeer.Id>
                            switch section {
                            case .report:
                                selectedPeers = self.optionReportSelectedPeers
                            case .deleteAll:
                                if self.optionDeleteAllSelectedPeers.contains(peer.id) || self.optionDeleteAllReactionsSelectedPeers.contains(peer.id) {
                                    self.optionDeleteAllSelectedPeers.remove(peer.id)
                                    self.optionDeleteAllReactionsSelectedPeers.remove(peer.id)
                                } else {
                                    self.optionDeleteAllSelectedPeers.insert(peer.id)
                                    self.optionDeleteAllReactionsSelectedPeers.insert(peer.id)
                                }

                                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                                return
                            case .ban:
                                selectedPeers = self.optionBanSelectedPeers
                            }
                            
                            if selectedPeers.contains(peer.id) {
                                selectedPeers.remove(peer.id)
                            } else {
                                selectedPeers.insert(peer.id)
                            }
                            
                            switch section {
                            case .report:
                                self.optionReportSelectedPeers = selectedPeers
                            case .deleteAll:
                                self.optionDeleteAllSelectedPeers = selectedPeers
                            case .ban:
                                self.optionBanSelectedPeers = selectedPeers
                            }
                            
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                        },
                        toggleDeleteAllOptionPeerSelection: { [weak self] option, peer in
                            guard let self else {
                                return
                            }

                            switch option {
                            case .messages:
                                if self.optionDeleteAllSelectedPeers.contains(peer.id) {
                                    self.optionDeleteAllSelectedPeers.remove(peer.id)
                                } else {
                                    self.optionDeleteAllSelectedPeers.insert(peer.id)
                                }
                            case .reactions:
                                if self.optionDeleteAllReactionsSelectedPeers.contains(peer.id) {
                                    self.optionDeleteAllReactionsSelectedPeers.remove(peer.id)
                                } else {
                                    self.optionDeleteAllReactionsSelectedPeers.insert(peer.id)
                                }
                            }

                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                        },
                        toggleConfiguration: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            self.isConfigurationExpanded = !self.isConfigurationExpanded
                            if self.isConfigurationExpanded && self.optionBanSelectedPeers.isEmpty {
                                for peer in component.peers {
                                    self.optionBanSelectedPeers.insert(peer.peer.id)
                                }
                            }
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        toggleConfigItem: { [weak self] configItem in
                            guard let self else {
                                return
                            }
                            
                            switch configItem {
                            case .sendMessages:
                                if self.participantRights.contains(.sendMessages) {
                                    self.participantRights.remove(.sendMessages)
                                } else {
                                    self.participantRights.insert(.sendMessages)
                                }
                            case .sendMedia:
                                if self.mediaRights.isEmpty {
                                    self.mediaRights = self.allowedMediaRights
                                } else {
                                    self.mediaRights = []
                                }
                            case .addUsers:
                                if self.participantRights.contains(.addMembers) {
                                    self.participantRights.remove(.addMembers)
                                } else {
                                    self.participantRights.insert(.addMembers)
                                }
                            case .pinMessages:
                                if self.participantRights.contains(.pinMessages) {
                                    self.participantRights.remove(.pinMessages)
                                } else {
                                    self.participantRights.insert(.pinMessages)
                                }
                            case .changeInfo:
                                if self.participantRights.contains(.changeInfo) {
                                    self.participantRights.remove(.changeInfo)
                                } else {
                                    self.participantRights.insert(.changeInfo)
                                }
                            }
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        toggleMediaSectionExpansion: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.isMediaSectionExpanded = !self.isMediaSectionExpanded
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        toggleMediaRight: { [weak self] mediaRight in
                            guard let self else {
                                return
                            }
                            
                            if self.mediaRights.contains(mediaRight) {
                                self.mediaRights.remove(mediaRight)
                            } else {
                                self.mediaRights.insert(mediaRight)
                            }
                            
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        setBanFromCommunity: { [weak self] value in
                            guard let self else {
                                return
                            }
                            self.banFromCommunity = value
                            self.state?.updated(transition: .spring(duration: 0.35))
                        },
                        openCommunity: { communityId in
                            let controller = component.context.sharedContext.makeCommunityViewScreen(context: component.context, communityId: communityId, mode: .sheet)
                            environmentValue.controller()?.present(controller, in: .window(.root))
                        }
                    )),
                    titleItem: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: adminUserActionsTitle(
                                strings: environmentValue.strings,
                                mode: component.mode,
                                peers: component.peers,
                                selectedDeleteAllPeers: self.optionDeleteAllSelectedPeers
                            ),
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
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                            cornerRadius: 54.0 * 0.5
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(ButtonTextContentComponent(
                                text: environmentValue.strings.Chat_AdminActionSheet_ActionButton,
                                badge: 0,
                                textColor: theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: theme.list.itemCheckColors.fillColor
                            ))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: {
                            performMainAction()
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

public class AdminUserActionsSheet: ViewControllerComponentContainer {
    public enum Mode {
        case chat(messageCount: Int, deleteAllMessageCount: Int?, completion: (ChatResult) -> Void)
        case liveStream(messageCount: Int, deleteAllMessageCount: Int?, completion: (LiveStreamResult) -> Void)
        case monoforum(completion: (MonoforumResult) -> Void)
        case chatReaction(completion: (ChatResult) -> Void)
    }
    
    public struct CommunityBanResult {
        public let communityId: EnginePeer.Id
        public let participantId: EnginePeer.Id

        init(communityId: EnginePeer.Id, participantId: EnginePeer.Id) {
            self.communityId = communityId
            self.participantId = participantId
        }
    }

    public final class ChatResult {
        public let reportSpamPeers: [EnginePeer.Id]
        public let deleteAllFromPeers: [EnginePeer.Id]
        public let deleteAllReactionsFromPeers: [EnginePeer.Id]
        public let banPeers: [EnginePeer.Id]
        public let updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights]
        public let banFromCommunity: CommunityBanResult?
        
        init(reportSpamPeers: [EnginePeer.Id], deleteAllFromPeers: [EnginePeer.Id], deleteAllReactionsFromPeers: [EnginePeer.Id], banPeers: [EnginePeer.Id], updateBannedRights: [EnginePeer.Id: TelegramChatBannedRights], banFromCommunity: CommunityBanResult?) {
            self.reportSpamPeers = reportSpamPeers
            self.deleteAllFromPeers = deleteAllFromPeers
            self.deleteAllReactionsFromPeers = deleteAllReactionsFromPeers
            self.banPeers = banPeers
            self.updateBannedRights = updateBannedRights
            self.banFromCommunity = banFromCommunity
        }
    }
    
    public final class LiveStreamResult {
        public let reportSpam: Bool
        public let deleteAll: Bool
        public let ban: Bool
        
        init(reportSpam: Bool, deleteAll: Bool, ban: Bool) {
            self.reportSpam = reportSpam
            self.deleteAll = deleteAll
            self.ban = ban
        }
    }
    
    public final class MonoforumResult {
        public let ban: Bool
        public let reportSpam: Bool
        
        init(ban: Bool, reportSpam: Bool) {
            self.ban = ban
            self.reportSpam = reportSpam
        }
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    private var dismissCompletion: (() -> Void)?
    
    public init(context: AccountContext, chatPeer: EnginePeer, peers: [RenderedChannelParticipant], mode: Mode, customTheme: PresentationTheme? = nil) {
        self.context = context
        super.init(
            context: context,
            component: AdminUserActionsSheetComponent(context: context, chatPeer: chatPeer, peers: peers, mode: mode),
            navigationBarAppearance: .none,
            theme: customTheme.flatMap({ .custom($0) }) ?? .default
        )
        
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

private let optionExpandUsersIcon: UIImage? = {
    let sourceImage = UIImage(bundleImageName: "Item List/InlineIconUsers")!
    return generateImage(CGSize(width: sourceImage.size.width, height: sourceImage.size.height), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        sourceImage.draw(at: CGPoint(x: 0.0, y: 0.0))
        UIGraphicsPopContext()
    })!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private final class OptionSectionExpandIndicatorComponent: Component {
    let theme: PresentationTheme
    let count: Int
    let isExpanded: Bool
    
    init(
        theme: PresentationTheme,
        count: Int,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.count = count
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: OptionSectionExpandIndicatorComponent, rhs: OptionSectionExpandIndicatorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView: UIImageView
        private let arrowView: UIImageView
        private let count = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.iconView = UIImageView()
            self.arrowView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.iconView)
            self.addSubview(self.arrowView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: OptionSectionExpandIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let countArrowSpacing: CGFloat = 1.0
            let iconCountSpacing: CGFloat = 1.0
            
            if self.iconView.image == nil {
                self.iconView.image = optionExpandUsersIcon
            }
            self.iconView.tintColor = component.theme.list.itemPrimaryTextColor
            let iconSize = self.iconView.image?.size ?? CGSize(width: 12.0, height: 12.0)
            
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.expandDownArrowImage(component.theme)
            }
            self.arrowView.tintColor = component.theme.list.itemPrimaryTextColor
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 1.0, height: 1.0)

            let countSize = self.count.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "\(component.count)", font: Font.semibold(13.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: 60.0, height: availableSize.height)
            
            let arrowFrame = CGRect(origin: CGPoint(x: size.width - arrowSize.width - 12.0, y: floor((size.height - arrowSize.height) * 0.5)), size: arrowSize)
            
            let countFrame = CGRect(origin: CGPoint(x: arrowFrame.minX - countArrowSpacing - countSize.width, y: floor((size.height - countSize.height) * 0.5)), size: countSize)
            
            let iconFrame = CGRect(origin: CGPoint(x: countFrame.minX - iconCountSpacing - iconSize.width, y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            
            if let countView = self.count.view {
                if countView.superview == nil {
                    self.addSubview(countView)
                }
                countView.frame = countFrame
            }
            
            self.arrowView.center = arrowFrame.center
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DTranslate(CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0), 0.0, component.isExpanded ? 1.0 : 0.0, 0.0))
            
            self.iconView.frame = iconFrame
            
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

private final class OptionsSectionFooterComponent: Component {
    let theme: PresentationTheme
    let text: String
    let fontSize: CGFloat
    let isExpanded: Bool
    
    init(
        theme: PresentationTheme,
        text: String,
        fontSize: CGFloat,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.text = text
        self.fontSize = fontSize
        self.isExpanded = isExpanded
    }
    
    static func ==(lhs: OptionsSectionFooterComponent, rhs: OptionsSectionFooterComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let arrowView: UIImageView
        private let textView: ImmediateTextView
        
        override init(frame: CGRect) {
            self.arrowView = UIImageView()
            
            self.textView = ImmediateTextView()
            self.textView.maximumNumberOfLines = 0
            
            super.init(frame: frame)
            
            self.addSubview(self.arrowView)
            self.addSubview(self.textView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: OptionsSectionFooterComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.arrowView.image == nil {
                self.arrowView.image = PresentationResourcesItemList.expandSmallDownArrowImage(component.theme)
            }
            self.arrowView.tintColor = component.theme.list.itemAccentColor
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 1.0, height: 1.0)
            
            let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: component.text, font: Font.regular(component.fontSize), textColor: component.theme.list.itemAccentColor))
            attributedText.append(NSAttributedString(string: ">", font: Font.regular(component.fontSize), textColor: .clear))
            self.textView.attributedText = attributedText
            let textLayout = self.textView.updateLayoutFullInfo(availableSize)
            
            let size = textLayout.size
            let textFrame = CGRect(origin: CGPoint(), size: textLayout.size)
            self.textView.frame = textFrame
            
            var arrowFrame = CGRect()
            if let lineRect = textLayout.linesRects().last {
                arrowFrame = CGRect(origin: CGPoint(x: textFrame.minX + lineRect.maxX - arrowSize.width + 6.0, y: textFrame.minY + lineRect.maxY - lineRect.height - arrowSize.height - 1.0), size: arrowSize)
            }
            
            self.arrowView.center = arrowFrame.center
            self.arrowView.bounds = CGRect(origin: CGPoint(), size: arrowFrame.size)
            transition.setTransform(view: self.arrowView, transform: CATransform3DMakeRotation(component.isExpanded ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0))
            
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
