import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ProgressNavigationButtonNode
import AccountContext
import AlertUI
import PresentationDataUtils
import ContactListUI
import CounterControllerTitleView
import EditableTokenListNode
import PremiumUI
import UndoUI
import ContextUI

private func peerTokenTitle(accountPeerId: PeerId, peer: Peer, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) -> String {
    if peer.id == accountPeerId {
        return strings.DialogList_SavedMessages
    } else if peer.id.isReplies {
        return strings.DialogList_Replies
    } else {
        return EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
    }
}

class ContactMultiselectionControllerImpl: ViewController, ContactMultiselectionController {
    private let params: ContactMultiselectionControllerParams
    private let context: AccountContext
    private let mode: ContactMultiselectionControllerMode
    private let isPeerEnabled: ((EnginePeer) -> Bool)?
    private let attemptDisabledItemSelection: ((EnginePeer, ChatListDisabledPeerReason) -> Void)?
    
    private let titleView: CounterControllerTitleView
    
    private var contactsNode: ContactMultiselectionControllerNode {
        return self.displayNode as! ContactMultiselectionControllerNode
    }
    
    var dismissed: (() -> Void)?

    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    private var _limitsReady = Promise<Bool>()
    private var _peersReady = Promise<Bool>()
    private var _listReady = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private let _result = Promise<ContactMultiselectionResult>()
    var result: Signal<ContactMultiselectionResult, NoError> {
        return self._result.get()
    }
    
    private var rightNavigationButton: UIBarButtonItem?
    
    var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                if self.displayProgress {
                    let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
                    self.navigationItem.rightBarButtonItem = item
                } else {
                    self.navigationItem.rightBarButtonItem = self.rightNavigationButton
                }
            }
        }
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var limitsConfiguration: LimitsConfiguration?
    private var limitsConfigurationDisposable: Disposable?
    private var initialPeersDisposable: Disposable?
    private let options: Signal<[ContactListAdditionalOption], NoError>
    private let filters: [ContactListFilter]
    private let onlyWriteable: Bool
    private let isGroupInvitation: Bool
    private let limit: Int32?

    public var isCallVideoOptionSelected: Bool {
        guard self.displayNode.isNodeLoaded, let displayNode = self.displayNode as? ContactMultiselectionControllerNode else {
            return false
        }
        return displayNode.isCallVideoOptionSelected
    }
    
    init(_ params: ContactMultiselectionControllerParams) {
        self.params = params
        self.context = params.context
        self.mode = params.mode
        self.isPeerEnabled = params.isPeerEnabled
        self.attemptDisabledItemSelection = params.attemptDisabledItemSelection
        self.options = params.options
        self.filters = params.filters
        self.onlyWriteable = params.onlyWriteable
        self.isGroupInvitation = params.isGroupInvitation
        self.limit = params.limit
        self.presentationData = params.updatedPresentationData?.initial ?? params.context.sharedContext.currentPresentationData.with { $0 }
        
        self.titleView = CounterControllerTitleView(theme: self.presentationData.theme)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.titleView = self.titleView
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = ((params.updatedPresentationData?.signal ?? params.context.sharedContext.presentationData)
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.limitsConfigurationDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.Limits())
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.limitsConfiguration = value._asLimits()
                strongSelf.updateTitle()
                strongSelf._limitsReady.set(.single(true))
            }
        })
        
        switch self.mode {
        case let .chatSelection(chatSelection):
            let selectedChats = chatSelection.selectedChats
            let additionalCategories = chatSelection.additionalCategories
            let _ = (self.context.engine.data.get(
                EngineDataList(
                    selectedChats.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                )
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                guard let strongSelf = self else {
                    return
                }
                let peers = peerList.compactMap { $0 }
                if let additionalCategories = additionalCategories {
                    for i in 0 ..< additionalCategories.categories.count {
                        if additionalCategories.selectedCategories.contains(additionalCategories.categories[i].id) {
                            strongSelf.contactsNode.editableTokens.append(EditableTokenListToken(id: additionalCategories.categories[i].id, title: additionalCategories.categories[i].title, fixedPosition: i, subject: .category(additionalCategories.categories[i].smallIcon)))
                        }
                    }
                }
                strongSelf.contactsNode.editableTokens.append(contentsOf: peers.map { peer -> EditableTokenListToken in
                    return EditableTokenListToken(id: peer.id, title: peerTokenTitle(accountPeerId: params.context.account.peerId, peer: peer._asPeer(), strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder), fixedPosition: nil, subject: .peer(peer))
                })
                strongSelf._peersReady.set(.single(true))
                if strongSelf.isNodeLoaded {
                    strongSelf.requestLayout(transition: .immediate)
                }
                
                strongSelf.updateTitle()
            })
        case let .premiumGifting(birthdays, selectToday, _):
            if let birthdays, selectToday {
                let today = Calendar(identifier: .gregorian).component(.day, from: Date())
                var todayPeers: [EnginePeer.Id] = []
                for (peerId, birthday) in birthdays {
                    if birthday.day == today {
                        todayPeers.append(peerId)
                    }
                }
                
                let _ = (self.context.engine.data.get(
                    EngineDataList(
                        todayPeers.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                    )
                )
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                    guard let strongSelf = self else {
                        return
                    }
                    let peers = peerList.compactMap { $0 }
                    strongSelf.contactsNode.editableTokens.append(contentsOf: peers.map { peer -> EditableTokenListToken in
                        return EditableTokenListToken(id: peer.id, title: peerTokenTitle(accountPeerId: params.context.account.peerId, peer: peer._asPeer(), strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder), fixedPosition: nil, subject: .peer(peer))
                    })
                    strongSelf._peersReady.set(.single(true))
                    if strongSelf.isNodeLoaded {
                        strongSelf.requestLayout(transition: .immediate)
                    }
                })
            } else {
                self._peersReady.set(.single(true))
            }
        default:
            self._peersReady.set(.single(true))
        }
        
        self._ready.set(combineLatest(self._listReady.get(), self._limitsReady.get(), self._peersReady.get()) |> map { $0 && $1 && $2 })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.limitsConfigurationDisposable?.dispose()
        self.initialPeersDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.updateTitle()
        self.contactsNode.updatePresentationData(self.presentationData)
    }
    
    private func updateTitle() {
        var updatedCount: Int = 0
        switch self.contactsNode.contentNode {
        case let .contacts(contactsNode):
            if let selectionState = contactsNode.selectionState {
                updatedCount = selectionState.selectedPeerIndices.count
            }
        case let .chats(chatsNode):
            chatsNode.updateState { state in
                updatedCount = state.selectedPeerIds.count
                return state
            }
            break
        }
        
        switch self.mode {
        case let .groupCreation(isCall):
            let maxCount: Int32
            if isCall {
                maxCount = self.context.userLimits.maxConferenceParticipantCount
            } else {
                maxCount = self.limitsConfiguration?.maxSupergroupMemberCount ?? 5000
            }
            let count: Int
            switch self.contactsNode.contentNode {
            case let .contacts(contactsNode):
                count = contactsNode.selectionState?.selectedPeerIndices.count ?? 0
            case let .chats(chatsNode):
                count = chatsNode.currentState.selectedPeerIds.count
            }
            if isCall && count <= 1 {
                self.titleView.title = CounterControllerTitle(title: self.params.title ?? self.presentationData.strings.Compose_NewGroupTitle, counter: nil)
            } else {
                var count = count
                if isCall {
                    count += 1
                }
                self.titleView.title = CounterControllerTitle(title: self.params.title ?? self.presentationData.strings.Compose_NewGroupTitle, counter: "\(count)/\(maxCount)")
            }
            if self.rightNavigationButton == nil && !isCall {
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
            }
        case let .premiumGifting(_, _, hasActions):
            let maxCount: Int32 = self.limit ?? 10
            var count = 0
            if case let .contacts(contactsNode) = self.contactsNode.contentNode {
                count = contactsNode.selectionState?.selectedPeerIndices.count ?? 0
            }
            self.titleView.title = CounterControllerTitle(title: self.params.title ?? (hasActions ? self.presentationData.strings.Premium_Gift_ContactSelection_Title : self.presentationData.strings.Stars_Purchase_GiftStars), counter: "\(count)/\(maxCount)")
        case .requestedUsersSelection:
            let maxCount: Int32 = self.limit ?? 10
            var count = 0
            if case let .contacts(contactsNode) = self.contactsNode.contentNode {
                count = contactsNode.selectionState?.selectedPeerIndices.count ?? 0
            }
            self.titleView.title = CounterControllerTitle(title: self.params.title ?? self.presentationData.strings.RequestPeer_SelectUsers, counter: "\(count)/\(maxCount)")
        case .channelCreation:
            self.titleView.title = CounterControllerTitle(title: self.params.title ?? self.presentationData.strings.GroupInfo_AddParticipantTitle, counter: "")
            if self.rightNavigationButton == nil {
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
            }
        case .peerSelection:
            self.titleView.title = CounterControllerTitle(title: self.params.title ?? self.presentationData.strings.PrivacyLastSeenSettings_EmpryUsersPlaceholder, counter: "")
            if self.rightNavigationButton == nil {
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
            }
        case let .chatSelection(chatSelection):
            self.titleView.title = CounterControllerTitle(title: self.params.title ?? chatSelection.title, counter: "")
            if self.rightNavigationButton == nil {
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
            }
        }
        
        switch self.mode {
        case .peerSelection, .chatSelection:
            let hasEditableTokens = !self.contactsNode.editableTokens.isEmpty
            self.rightNavigationButton?.isEnabled = updatedCount != 0 || hasEditableTokens || self.params.alwaysEnabled
        case .groupCreation, .channelCreation, .premiumGifting, .requestedUsersSelection:
            self.rightNavigationButton?.isEnabled = true
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ContactMultiselectionControllerNode(navigationBar: self.navigationBar, context: self.context, presentationData: self.presentationData, updatedPresentationData: self.params.updatedPresentationData, mode: self.mode, isPeerEnabled: self.isPeerEnabled, attemptDisabledItemSelection: self.attemptDisabledItemSelection, options: self.options, filters: self.filters, onlyWriteable: self.onlyWriteable, isGroupInvitation: self.isGroupInvitation, limit: self.limit, reachedSelectionLimit: self.params.reachedLimit, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
        switch self.contactsNode.contentNode {
        case let .contacts(contactsNode):
            self._listReady.set(contactsNode.ready)
        case let .chats(chatsNode):
            self._listReady.set(chatsNode.ready)
        }
        
        let accountPeerId = self.context.account.peerId
        
        self.contactsNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        
        let limit = self.limit
        self.contactsNode.openPeer = { [weak self] peer in
            if let strongSelf = self, case let .peer(peer, _, _) = peer {
                var updatedCount: Int?
                var addedToken: EditableTokenListToken?
                var removedTokenId: AnyHashable?
                
                let maxRegularCount: Int32
                if case .groupCreation(true) = strongSelf.mode {
                    maxRegularCount = strongSelf.context.userLimits.maxConferenceParticipantCount
                } else {
                    maxRegularCount = strongSelf.limitsConfiguration?.maxGroupMemberCount ?? 200
                }
                var displayCountAlert = false
                
                var selectionState: ContactListNodeGroupSelectionState?
                let reachedLimit = strongSelf.params.reachedLimit
                switch strongSelf.contactsNode.contentNode {
                case let .contacts(contactsNode):
                    contactsNode.updateSelectionState { state in
                        if let state = state {
                            var updatedState = state.withToggledPeerId(.peer(peer.id))
                            if let limit = limit, updatedState.selectedPeerIndices.count > limit {
                                reachedLimit?(Int32(limit))
                                updatedCount = nil
                                removedTokenId = nil
                                addedToken = nil
                                return state
                            }
                            
                            if updatedState.selectedPeerIndices[.peer(peer.id)] == nil {
                                removedTokenId = peer.id
                            } else {
                                var selectedPeerMap = updatedState.selectedPeerMap
                                selectedPeerMap[.peer(peer.id)] = .peer(peer: peer, isGlobal: false, participantCount: nil)
                                updatedState = updatedState.withSelectedPeerMap(selectedPeerMap)
                                
                                if updatedState.selectedPeerIndices.count >= maxRegularCount {
                                    displayCountAlert = true
                                    updatedState = updatedState.withToggledPeerId(.peer(peer.id))
                                } else {
                                    addedToken = EditableTokenListToken(id: peer.id, title: peerTokenTitle(accountPeerId: accountPeerId, peer: peer, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder), fixedPosition: nil, subject: .peer(EnginePeer(peer)))
                                }
                            }
                            updatedCount = updatedState.selectedPeerIndices.count
                            selectionState = updatedState
                            return updatedState
                        } else {
                            return nil
                        }
                    }
                case let .chats(chatsNode):
                    chatsNode.updateState { initialState in
                        var state = initialState
                        if state.selectedPeerIds.contains(peer.id) {
                            state.selectedPeerIds.remove(peer.id)
                            removedTokenId = peer.id
                        } else {
                            addedToken = EditableTokenListToken(id: peer.id, title: peerTokenTitle(accountPeerId: accountPeerId, peer: peer, strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder), fixedPosition: nil, subject: .peer(EnginePeer(peer)))
                            state.selectedPeerIds.insert(peer.id)
                        }
                        updatedCount = state.selectedPeerIds.count
                        if let limit = limit, let count = updatedCount, count > limit {
                            reachedLimit?(Int32(count))
                            updatedCount = nil
                            removedTokenId = nil
                            addedToken = nil
                            return initialState
                        }
                        var updatedState = ContactListNodeGroupSelectionState()
                        for peerId in state.selectedPeerIds {
                            updatedState = updatedState.withToggledPeerId(.peer(peerId))
                        }
                        selectionState = updatedState
                        return state
                    }
                    break
                }
                if let searchResultsNode = strongSelf.contactsNode.searchResultsNode {
                    searchResultsNode.updateSelectionState { _ in
                        return selectionState
                    }
                }
                
                if let addedToken = addedToken {
                    strongSelf.contactsNode.editableTokens.append(addedToken)
                } else if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                
                let _ = updatedCount
                
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
                
                strongSelf.updateTitle()
                
                if displayCountAlert {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.CreateGroup_SoftUserLimitAlert, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }

        if !self.params.initialSelectedPeers.isEmpty {
            for peer in self.params.initialSelectedPeers {
                self.contactsNode.openPeer?(.peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil))
            }
            /*if case let .contacts(contactsNode) = self.contactsNode.contentNode {
                contactsNode.updateSelectionState { state in
                    var updatedState = state ?? ContactListNodeGroupSelectionState()
                    var selectedPeerMap = updatedState.selectedPeerMap
                    for peer in self.params.initialSelectedPeers {
                        updatedState = updatedState.withToggledPeerId(.peer(peer.id))
                        selectedPeerMap[.peer(peer.id)] = .peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil)
                    }
                    updatedState = updatedState.withSelectedPeerMap(selectedPeerMap)
                    return updatedState
                }
            }*/
        }
        
        self.contactsNode.openPeerMore  = { [weak self] peer, node, gesture in
            guard let self, case let .peer(peer, _, _) = peer, let node = node as? ContextReferenceContentNode else {
                return
            }
            
            let presentationData = self.presentationData
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Premium_Gift_ContactSelection_SendMessage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak self] _, a in
                a(.default)
              
                if let self {
                    self.params.sendMessage?(EnginePeer(peer))
                }
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Premium_Gift_ContactSelection_OpenProfile, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak self] _, a in
                a(.default)

                if let self {
                    self.params.openProfile?(EnginePeer(peer))
                }
            })))
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(ContactContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            self.present(contextController, in: .window(.root))
        }
        
        self.contactsNode.openDisabledPeer = { [weak self] peer, reason in
            guard let self else {
                return
            }
            switch reason {
            case .generic:
                break
            case .premiumRequired:
                self.forEachController { c in
                    if let c = c as? UndoOverlayController {
                        c.dismiss()
                    }
                    return true
                }
                
                var hasAction = false
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                if !premiumConfiguration.isPremiumDisabled {
                    hasAction = true
                }
                
                self.present(UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: nil, text: presentationData.strings.Chat_ToastMessagingRestrictedToPremium_Text(peer.compactDisplayTitle).string, customUndoText: hasAction ? self.presentationData.strings.Chat_ToastMessagingRestrictedToPremium_Action : nil, timeout: nil, linkAction: { _ in
                }), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] action in
                    guard let self else {
                        return false
                    }
                    if case .undo = action {
                        let premiumController = PremiumIntroScreen(context: self.context, source: .settings)
                        self.push(premiumController)
                    }
                    return false
                }), in: .current)
            }
        }
        
        self.contactsNode.removeSelectedPeer = { [weak self] peerId in
            if let strongSelf = self {
                var updatedCount: Int?
                var removedTokenId: AnyHashable?
                
                var selectionState: ContactListNodeGroupSelectionState?
                switch strongSelf.contactsNode.contentNode {
                case let .contacts(contactsNode):
                    contactsNode.updateSelectionState { state in
                        if let state = state {
                            let updatedState = state.withToggledPeerId(peerId)
                            if updatedState.selectedPeerIndices[peerId] == nil {
                                if case let .peer(peerId) = peerId {
                                    removedTokenId = peerId
                                }
                            }
                            updatedCount = updatedState.selectedPeerIndices.count
                            selectionState = updatedState
                            return updatedState
                        } else {
                            return nil
                        }
                    }
                case let .chats(chatsNode):
                    chatsNode.updateState { state in
                        var state = state
                        if case let .peer(peerIdValue) = peerId {
                            if state.selectedPeerIds.contains(peerIdValue) {
                                state.selectedPeerIds.remove(peerIdValue)
                            }
                            removedTokenId = peerIdValue
                        }
                        updatedCount = state.selectedPeerIds.count
                        var updatedState = ContactListNodeGroupSelectionState()
                        for peerId in state.selectedPeerIds {
                            updatedState = updatedState.withToggledPeerId(.peer(peerId))
                        }
                        selectionState = updatedState
                        return state
                    }
                }
                if let searchResultsNode = strongSelf.contactsNode.searchResultsNode {
                    searchResultsNode.updateSelectionState { _ in
                        return selectionState
                    }
                }
                
                if let updatedCount = updatedCount {
                    switch strongSelf.mode {
                        case .groupCreation, .peerSelection, .chatSelection:
                            strongSelf.rightNavigationButton?.isEnabled = updatedCount != 0 || strongSelf.params.alwaysEnabled
                        case .channelCreation, .premiumGifting, .requestedUsersSelection:
                            break
                    }
                    switch strongSelf.mode {
                        case let .groupCreation(isCall):
                            let maxCount: Int32
                            if isCall {
                                maxCount = strongSelf.context.userLimits.maxConferenceParticipantCount
                            } else {
                                maxCount = strongSelf.limitsConfiguration?.maxSupergroupMemberCount ?? 5000
                            }
                            strongSelf.titleView.title = CounterControllerTitle(title: strongSelf.presentationData.strings.Compose_NewGroupTitle, counter: "\(updatedCount)/\(maxCount)")
                        case .premiumGifting:
                            let maxCount: Int32 = strongSelf.limit ?? 10
                            strongSelf.titleView.title = CounterControllerTitle(title: strongSelf.presentationData.strings.Premium_Gift_ContactSelection_Title, counter: "\(updatedCount)/\(maxCount)")
                        case .requestedUsersSelection:
                            let maxCount: Int32 = strongSelf.limit ?? 10
                            strongSelf.titleView.title = CounterControllerTitle(title: strongSelf.presentationData.strings.RequestPeer_SelectUsers, counter: "\(updatedCount)/\(maxCount)")
                        case .peerSelection, .channelCreation, .chatSelection:
                            break
                    }
                }
                
                if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
                
                strongSelf.updateTitle()
            }
        }
        
        self.contactsNode.removeSelectedCategory = { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            var removedTokenId: AnyHashable?
            switch strongSelf.contactsNode.contentNode {
            case .contacts:
                break
            case let .chats(chatsNode):
                chatsNode.updateState { state in
                    var state = state
                    if state.selectedAdditionalCategoryIds.contains(id) {
                        state.selectedAdditionalCategoryIds.remove(id)
                        removedTokenId = id
                    }
                    return state
                }
                if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
            }
            
            strongSelf.updateTitle()
        }
        
        self.contactsNode.additionalCategorySelected = { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            var addedToken: EditableTokenListToken?
            var removedTokenIds: [AnyHashable] = []
            switch strongSelf.contactsNode.contentNode {
            case .contacts:
                break
            case let .chats(chatsNode):
                var categoryToken: EditableTokenListToken?
                if case let .chatSelection(chatSelection) = strongSelf.mode {
                    if let additionalCategories = chatSelection.additionalCategories {
                        for i in 0 ..< additionalCategories.categories.count {
                            if additionalCategories.categories[i].id == id {
                                categoryToken = EditableTokenListToken(id: id, title: additionalCategories.categories[i].title, fixedPosition: i, subject: .category(additionalCategories.categories[i].smallIcon))
                                break
                            }
                        }
                    }
                }
                chatsNode.updateState { state in
                    var state = state
                    if state.selectedAdditionalCategoryIds.contains(id) {
                        state.selectedAdditionalCategoryIds.remove(id)
                        removedTokenIds.append(id)
                    } else {
                        state.selectedAdditionalCategoryIds.insert(id)
                        addedToken = categoryToken
                    }
                    
                    return state
                }
                if let addedToken = addedToken, let insertFixedIndex = addedToken.fixedPosition {
                    var added = false
                    for i in 0 ..< strongSelf.contactsNode.editableTokens.count {
                        if let fixedIndex = strongSelf.contactsNode.editableTokens[i].fixedPosition {
                            if fixedIndex > insertFixedIndex {
                                strongSelf.contactsNode.editableTokens.insert(addedToken, at: i)
                                added = true
                                break
                            }
                        } else {
                            strongSelf.contactsNode.editableTokens.insert(addedToken, at: i)
                            added = true
                            break
                        }
                    }
                    if !added {
                        strongSelf.contactsNode.editableTokens.append(addedToken)
                    }
                    
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return !removedTokenIds.contains(token.id)
                    }
                } else if !removedTokenIds.isEmpty {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return !removedTokenIds.contains(token.id)
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
                
                strongSelf.updateTitle()
            }
        }
        self.contactsNode.complete = { [weak self] in
            if let strongSelf = self {
                var available = true
                if let rightBarButtonItem = strongSelf.navigationItem.rightBarButtonItem {
                    available = rightBarButtonItem.isEnabled
                }
                if available {
                    strongSelf.rightNavigationButtonPressed()
                }
            }
        }
        
        switch self.contactsNode.contentNode {
        case let .contacts(contactsNode):
            contactsNode.deselectedAll = { [weak self] in
                guard let self else {
                    return
                }
                self.contactsNode.editableTokens = []
                self.updateTitle()
                self.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
            }
            contactsNode.updatedSelection = { [weak self] peers, value in
                guard let self else {
                    return
                }
                var tokens = self.contactsNode.editableTokens
                if value {
                    var existingPeerIds = Set<EnginePeer.Id>()
                    for token in tokens {
                        if let peerId = token.id as? EnginePeer.Id {
                            existingPeerIds.insert(peerId)
                        }
                    }
                    for peer in peers {
                        if !existingPeerIds.contains(peer.id) {
                            tokens.append(EditableTokenListToken(id: peer.id, title: peerTokenTitle(accountPeerId: self.context.account.peerId, peer: peer._asPeer(), strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder), fixedPosition: nil, subject: .peer(peer)))
                        }
                    }
                } else {
                    let peerIds = Set(peers.map { AnyHashable($0.id) })
                    tokens = tokens.filter { !peerIds.contains($0.id) }
                }
                self.contactsNode.editableTokens = tokens
                self.updateTitle()
                self.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))

            }
        case .chats:
            break
        }
        
        self.displayNodeDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        switch self.contactsNode.contentNode {
        case let .contacts(contactsNode):
            contactsNode.enableUpdates = true
        case .chats:
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.contactsNode.animateIn()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        switch self.contactsNode.contentNode {
        case let .contacts(contactsNode):
            contactsNode.enableUpdates = false
        case .chats:
            break
        }
    }

    private var suspendNavigationBarLayout: Bool = false
    private var suspendedNavigationBarLayout: ContainerViewLayout?
    private var additionalNavigationBarBackgroundHeight: CGFloat = 0.0

    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: nil, transition: transition)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.suspendNavigationBarLayout = true
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.additionalNavigationBarBackgroundHeight = self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: nil, transition: transition)
        }
    }
    
    @objc func cancelPressed() {
        self._result.set(.single(.none))
        self.dismiss()
    }
    
    @objc func rightNavigationButtonPressed() {
        var peerIds: [ContactListPeerId] = []
        var additionalOptionIds: [Int] = []
        switch self.contactsNode.contentNode {
        case let .contacts(contactsNode):
            contactsNode.updateSelectionState { state in
                if let state = state {
                    peerIds = Array(state.selectedPeerIndices.keys)
                }
                return state
            }
        case let .chats(chatsNode):
            for peerId in chatsNode.currentState.selectedPeerIds {
                peerIds.append(.peer(peerId))
            }
            for optionId in chatsNode.currentState.selectedAdditionalCategoryIds {
                additionalOptionIds.append(optionId)
            }
            additionalOptionIds.sort()
        }
        self._result.set(.single(.result(peerIds: peerIds, additionalOptionIds: additionalOptionIds)))
    }
}

private final class ContactContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
