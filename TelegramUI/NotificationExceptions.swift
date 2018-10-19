import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore


private final class NotificationExceptionArguments {
    let account: Account
    let activateSearch:()->Void
    let changeNotifications: (PeerId, TelegramPeerNotificationSettings) -> Void
    let selectPeer: ()->Void
    init(account: Account, activateSearch:@escaping() -> Void, changeNotifications: @escaping(PeerId, TelegramPeerNotificationSettings) -> Void, selectPeer: @escaping()->Void) {
        self.account = account
        self.activateSearch = activateSearch
        self.changeNotifications = changeNotifications
        self.selectPeer = selectPeer
    }
}

private enum NotificationExceptionEntryId: Hashable {
    case search
    case peerId(Int64)
    
    var hashValue: Int {
        switch self {
        case .search:
            return 0
        case let .peerId(peerId):
            return peerId.hashValue
        }
    }
    
    static func <(lhs: NotificationExceptionEntryId, rhs: NotificationExceptionEntryId) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
    
    static func ==(lhs: NotificationExceptionEntryId, rhs: NotificationExceptionEntryId) -> Bool {
        switch lhs {
        case .search:
            switch rhs {
            case .search:
                return true
            default:
                return false
            }
        case let .peerId(lhsId):
            switch rhs {
            case let .peerId(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        }
    }
}

private enum NotificationExceptionSectionId : ItemListSectionId {
    case general = 0
}

private enum NotificationExceptionEntry : ItemListNodeEntry {
    
    
    var section: ItemListSectionId {
        return NotificationExceptionSectionId.general.rawValue
    }
    
    typealias ItemGenerationArguments = NotificationExceptionArguments
    
    case search(PresentationTheme, PresentationStrings)
    case peer(Int, Peer, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, String, TelegramPeerNotificationSettings)

    
    func item(_ arguments: NotificationExceptionArguments) -> ListViewItem {
        switch self {
        case let .search(theme, strings):
            return NotificationSearchItem(theme: theme, placeholder: strings.Contacts_SearchLabel, activate: {
                arguments.activateSearch()
            })
        case let .peer(_, peer, theme, strings, dateTimeFormat, value, settings):
            return ItemListPeerItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, account: arguments.account, peer: peer, presence: nil, text: .text(value), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, sectionId: self.section, action: {
                arguments.changeNotifications(peer.id, settings)
            }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                
            }, removePeer: { peerId in
                
            }, hasTopStripe: false)
        }
    }
    
    var stableId: NotificationExceptionEntryId {
        switch self {
        case .search:
            return .search
        case let .peer(_, peer, _, _, _, _, _):
            return .peerId(peer.id.toInt64())
        }
    }
    
    static func == (lhs: NotificationExceptionEntry, rhs: NotificationExceptionEntry) -> Bool {
        switch lhs {
        case let .search(lhsTheme, lhsStrings):
            switch rhs {
            case let .search(rhsTheme, rhsStrings):
                return lhsTheme === rhsTheme && lhsStrings === rhsStrings
            default:
                return false
            }
        case let .peer(lhsIndex, lhsPeer, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsValue, lhsSettings):
            switch rhs {
            case let .peer(rhsIndex, rhsPeer, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsValue, rhsSettings):
                return lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsDateTimeFormat == rhsDateTimeFormat && lhsIndex == rhsIndex && lhsPeer.isEqual(rhsPeer) && lhsValue == rhsValue && lhsSettings == rhsSettings
            default:
                return false
            }
        }
    }
    
    static func <(lhs: NotificationExceptionEntry, rhs: NotificationExceptionEntry) -> Bool {
        switch lhs {
        case .search:
            return true
        case let .peer(lhsIndex, _, _, _, _, _, _):
            switch rhs {
            case .search:
                return false
            case let .peer(rhsIndex, _, _, _, _, _, _):
                return lhsIndex < rhsIndex
            }
        }
    }
}



private final class NotificationExceptionState : Equatable {
   
    let mode:NotificationExceptionMode
    let isSearchMode: Bool
    init(mode: NotificationExceptionMode, isSearchMode: Bool = false) {
        self.mode = mode
        self.isSearchMode = isSearchMode
    }
    
    func withUpdatedSearchMode(_ isSearchMode: Bool) -> NotificationExceptionState {
        return NotificationExceptionState.init(mode: mode, isSearchMode: isSearchMode)
    }
    
    func withUpdatedPeerIdSound(_ peerId: PeerId, _ sound: PeerMessageSound) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerIdSound(peerId, sound), isSearchMode: isSearchMode)
    }
    func withUpdatedPeerIdMuteInterval(_ peerId: PeerId, _ muteInterval: Int32?) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerIdMuteInterval(peerId, muteInterval), isSearchMode: isSearchMode)
    }
    
    static func == (lhs: NotificationExceptionState, rhs: NotificationExceptionState) -> Bool {
        return lhs.mode == rhs.mode && lhs.isSearchMode == rhs.isSearchMode
    }
}


public struct NotificationExceptionWrapper : Equatable {
    let settings: TelegramPeerNotificationSettings
    let date: TimeInterval?
    init(settings: TelegramPeerNotificationSettings, date: TimeInterval? = nil) {
        self.settings = settings
        self.date = date
    }
    
    func withUpdatedSettings(_ settings: TelegramPeerNotificationSettings) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: settings, date: self.date)
    }
    
    func updateSettings(_ f: (TelegramPeerNotificationSettings) -> TelegramPeerNotificationSettings) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: f(self.settings), date: self.date)
    }
    
    
    func withUpdatedDate(_ date: TimeInterval) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: self.settings, date: date)
    }
}

public enum NotificationExceptionMode : Equatable {
    public static func == (lhs: NotificationExceptionMode, rhs: NotificationExceptionMode) -> Bool {
        switch lhs {
        case let .users(lhsValue):
            if case let .users(rhsValue) = rhs {
                return lhsValue == rhsValue
            } else {
                return false
            }
        case let .groups(lhsValue):
            if case let .groups(rhsValue) = rhs {
                return lhsValue == rhsValue
            } else {
                return false
            }
        }
    }
    
    case users([PeerId : NotificationExceptionWrapper])
    case groups([PeerId : NotificationExceptionWrapper])
    
    func withUpdatedPeerIdSound(_ peerId: PeerId, _ sound: PeerMessageSound) -> NotificationExceptionMode {
        let apply:([PeerId : NotificationExceptionWrapper], PeerId, PeerMessageSound) -> [PeerId : NotificationExceptionWrapper] = { values, peerId, sound in
            var values = values
            if let value = values[peerId] {
                switch sound {
                case .default:
                    switch value.settings.muteState {
                    case .default:
                        values.removeValue(forKey: peerId)
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedMessageSound(sound)})
                    }
                default:
                    values[peerId] = value.updateSettings({$0.withUpdatedMessageSound(sound)})
                }
            } else {
                switch sound {
                case .default:
                    break
                default:
                    values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .default, messageSound: sound), date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
        case let .groups(values):
            if peerId.namespace != Namespaces.Peer.CloudUser {
                return .groups(apply(values, peerId, sound))
            }
        case let .users(values):
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return .users(apply(values, peerId, sound))
            }
        }
        
        return self
    }
    
    func withUpdatedPeerIdMuteInterval(_ peerId: PeerId, _ muteInterval: Int32?) -> NotificationExceptionMode {
        
        let apply:([PeerId : NotificationExceptionWrapper], PeerId, PeerMuteState) -> [PeerId : NotificationExceptionWrapper] = { values, peerId, muteState in
            var values = values
            if let value = values[peerId] {
                switch muteState {
                case .default:
                    switch value.settings.messageSound {
                    case .default:
                        values.removeValue(forKey: peerId)
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedMuteState(muteState)})
                    }
                default:
                    values[peerId] = value.updateSettings({$0.withUpdatedMuteState(muteState)})
                }
            } else {
                switch muteState {
                case .default:
                    break
                default:
                    values[peerId] = NotificationExceptionWrapper.init(settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: .default), date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        let muteState: PeerMuteState
        if let muteInterval = muteInterval {
            if muteInterval == 0 {
                muteState = .unmuted
            } else {
                let absoluteUntil: Int32
                if muteInterval == Int32.max {
                    absoluteUntil = Int32.max
                } else {
                    absoluteUntil = Int32(Date().timeIntervalSince1970) + muteInterval
                }
                muteState = .muted(until: absoluteUntil)
            }
        } else {
            muteState = .default
        }
        switch self {
        case let .groups(values):
            if peerId.namespace != Namespaces.Peer.CloudUser {
                return .groups(apply(values, peerId, muteState))
            }
        case let .users(values):
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return .users(apply(values, peerId, muteState))
            }
        }
        
        return self
    }
    
    var peerIds: [PeerId] {
        switch self {
        case let .users(settings), let .groups(settings):
            return settings.map {$0.key}
        }
    }
    
    var settings: [PeerId : NotificationExceptionWrapper] {
        switch self {
        case let .users(settings), let .groups(settings):
            return settings
        }
    }
}

private func notificationsExceptionEntries(presentationData: PresentationData, peers: [PeerId : Peer], state: NotificationExceptionState) -> [NotificationExceptionEntry] {
    var entries: [NotificationExceptionEntry] = []
    
    entries.append(.search(presentationData.theme, presentationData.strings))

    
    var index: Int = 0
    for (key, value) in state.mode.settings.sorted(by: { lhs, rhs in
        let lhsName = peers[lhs.key]?.displayTitle ?? ""
        let rhsName = peers[rhs.key]?.displayTitle ?? ""
        
        if let lhsDate = lhs.value.date, let rhsDate = rhs.value.date {
            return lhsDate < rhsDate
        } else if lhs.value.date != nil && rhs.value.date == nil {
            return true
        } else if lhs.value.date == nil && rhs.value.date != nil {
            return false
        }
        
        if let lhsPeer = peers[lhs.key] as? TelegramUser, let rhsPeer = peers[rhs.key] as? TelegramUser {
            if lhsPeer.botInfo != nil && rhsPeer.botInfo == nil {
                return false
            } else if lhsPeer.botInfo == nil && rhsPeer.botInfo != nil {
                return true
            }
        }
        
        return lhsName < rhsName
    }) {
        if let peer = peers[key], !peer.displayTitle.isEmpty {
            var title: String
            switch value.settings.muteState {
            case .muted:
                title = presentationData.strings.Notifications_ExceptionsMuted
            case .unmuted:
                title = presentationData.strings.Notifications_ExceptionsUnmuted
            default:
                title = ""
            }
            switch value.settings.messageSound {
            case .default:
                break
            default:
                title += (title.isEmpty ? "" : ", ") + localizedPeerNotificationSoundString(strings: presentationData.strings, sound: value.settings.messageSound)
            }
            entries.append(.peer(index, peer, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, title, value.settings))
            index += 1
        }
    }
    
    return entries
}

public func notificationExceptionsController(account: Account, mode: NotificationExceptionMode, updatedMode:@escaping(NotificationExceptionMode) -> Void) -> ViewController {
    let statePromise = ValuePromise(NotificationExceptionState(mode: mode), ignoreRepeated: true)
    let stateValue = Atomic(value: NotificationExceptionState(mode: mode))
    let updateState: ((NotificationExceptionState) -> NotificationExceptionState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
        updatedMode(result.mode)
    }
    
    let globalValue: Atomic<GlobalNotificationSettingsSet> = Atomic(value: GlobalNotificationSettingsSet.defaultSettings)
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?

    
    let presentationData = account.telegramApplicationContext.currentPresentationData.modify {$0}
    
    let updatePeerSound: (PeerId, PeerMessageSound) -> Void = { peerId, sound in
        _ = updatePeerNotificationSoundInteractive(account: account, peerId: peerId, sound: sound).start(completed: {
            updateState { value in
                return value.withUpdatedPeerIdSound(peerId, sound)
            }
        })
    }
    
    let updatePeerNotificationInterval:(PeerId, Int32?) -> Void = { peerId, muteInterval in
        _ = updatePeerMuteSetting(account: account, peerId: peerId, muteInterval: muteInterval).start(completed: {
            updateState { value in
                return value.withUpdatedPeerIdMuteInterval(peerId, muteInterval)
            }
        })
    }
    
    var activateSearch:(()->Void)?
    
    
    let arguments = NotificationExceptionArguments(account: account, activateSearch: {
        activateSearch?()
    }, changeNotifications: { peerId, settings in
        
        let globalSettings = globalValue.modify {$0}
        
        let isPrivateChat = peerId.namespace == Namespaces.Peer.CloudUser
        
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: isPrivateChat && globalSettings.privateChats.enabled || !isPrivateChat && globalSettings.groupChats.enabled ? presentationData.strings.UserInfo_NotificationsDefaultEnabled : presentationData.strings.UserInfo_NotificationsDefaultDisabled, color: .accent, action: { [weak actionSheet] in
                updatePeerNotificationInterval(peerId, nil)
                actionSheet?.dismissAnimated()
            }),
            ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsEnable, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                updatePeerNotificationInterval(peerId, 0)
            }),
            ActionSheetButtonItem(title: presentationData.strings.Notification_Mute1h, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                updatePeerNotificationInterval(peerId, 60 * 60)
            }),
            ActionSheetButtonItem(title: presentationData.strings.MuteFor_Days(2), color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                updatePeerNotificationInterval(peerId, 60 * 60 * 24 * 2)
            }),
            ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsDisable, color: .accent, action: { [weak actionSheet] in
                updatePeerNotificationInterval(peerId, Int32.max)
                actionSheet?.dismissAnimated()
            }),
            ActionSheetButtonItem(title: presentationData.strings.Notifications_ExceptionsChangeSound(localizedPeerNotificationSoundString(strings: presentationData.strings, sound: settings.messageSound)).0, color: .accent, action: { [weak actionSheet] in
                let controller = notificationSoundSelectionController(account: account, isModal: true, currentSound: settings.messageSound, defaultSound: isPrivateChat ? globalSettings.privateChats.sound : globalSettings.groupChats.sound, completion: { value in
                    updatePeerSound(peerId, value)
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                actionSheet?.dismissAnimated()
            })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        presentControllerImpl?(actionSheet, nil)
    }, selectPeer: {
        let filter: ChatListNodePeersFilter
        switch mode {
        case .groups:
            filter = [.withoutSecretChats]
        case .users:
            filter = [.withoutSecretChats]
        }
        let controller = PeerSelectionController(account: account, filter: filter, title: presentationData.strings.Notifications_AddExceptionTitle)
        controller.peerSelected = { [weak controller] peerId in
            controller?.dismiss()
            
            let settingsSignal = account.postbox.transaction { transaction in
                return transaction.getPeerNotificationSettings(peerId)
            } |> deliverOnMainQueue
            
            _ = settingsSignal.start(next: { settings in
                if let settings = settings as? TelegramPeerNotificationSettings {
                    let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
                    
                    var items: [ActionSheetButtonItem] = []
                    
                    switch settings.muteState {
                    case .default, .muted:
                        items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsEnable, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            updatePeerNotificationInterval(peerId, 0)
                        }))
                    default:
                        break
                    }
                    
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Notification_Mute1h, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        updatePeerNotificationInterval(peerId, 60 * 60)
                    }))
                    items.append(ActionSheetButtonItem(title: presentationData.strings.MuteFor_Days(2), color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        updatePeerNotificationInterval(peerId, 60 * 60 * 24 * 2)
                    }))
                    
                    switch settings.muteState {
                    case .default, .unmuted:
                        items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsDisable, color: .accent, action: { [weak actionSheet] in
                            updatePeerNotificationInterval(peerId, Int32.max)
                            actionSheet?.dismissAnimated()
                        }))
                    default:
                        break
                    }
                    
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Notifications_ExceptionsChangeSound(localizedPeerNotificationSoundString(strings: presentationData.strings, sound: settings.messageSound)).0, color: .accent, action: { [weak actionSheet] in
                        let controller = notificationSoundSelectionController(account: account, isModal: true, currentSound: settings.messageSound, defaultSound: nil, completion: { value in
                            updatePeerSound(peerId, value)
                        })
                        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        actionSheet?.dismissAnimated()
                    }))
                    
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    presentControllerImpl?(actionSheet, nil)
                }
            })
            
            
            
            
            
        }
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let peersSignal:Signal<[PeerId : Peer], NoError> = statePromise.get() |> mapToSignal { state in
        return account.postbox.transaction { transaction -> [PeerId : Peer] in
            var peers:[PeerId : Peer] = [:]
            for peerId in state.mode.peerIds {
                if let peer = transaction.getPeer(peerId) {
                    peers[peerId] = peer
                }
            }
            return peers
        }
    }
    
    let preferences = account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])

    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), peersSignal, preferences)
        |> map { presentationData, state, peers, prefs -> (ItemListControllerState, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)) in
            
            _ = globalValue.swap((prefs.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings)?.effective ?? GlobalNotificationSettingsSet.defaultSettings)

            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Notifications_ExceptionsTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: nil)
            let listState = ItemListNodeState(entries: notificationsExceptionEntries(presentationData: presentationData, peers: peers, state: state), style: .plain, searchItem: nil)
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = NotificationExceptionsController(account: account, state: signal, addAction: {
        arguments.selectPeer()
    })
    
//    let controller = ItemListController(account: account, state: signal |> afterDisposed {
//       actionsDisposable.dispose()
//    })

    
    activateSearch = { [weak controller] in
//        updateState { state in
//            return state.withUpdatedSearchMode(true)
//        }
        controller?.activateSearch()
    }
    
    
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    return controller
}


 private final class NotificationExceptionsController: ViewController {
    private let account: Account
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    var peerSelected: ((PeerId) -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress != oldValue {
                if self.isNodeLoaded {
                    self.controllerNode.inProgress = self.inProgress
                }
                
                if self.inProgress {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: self.presentationData.theme))
                } else {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
        }
    }
    
    private var controllerNode: NotificationExceptionsControllerNode {
        return super.displayNode as! NotificationExceptionsControllerNode
    }
    
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private let addAction:()->Void
    
    private let state: Signal<(ItemListControllerState, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>
    
    public init(account: Account, state: Signal<(ItemListControllerState, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>, addAction: @escaping()->Void) {
        self.account = account
        self.state = state
        self.addAction = addAction
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
        
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func addExceptionAction() {
        self.addAction()
    }
    
    override public func loadDisplayNode() {
        let image = PresentationResourcesRootController.navigationAddIcon(presentationData.theme)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: UIBarButtonItem.Style.plain, target: self, action: #selector(addExceptionAction))
        
        let nodeState = self.state |> deliverOnMainQueue |> map { ($0.theme, $1) }
        
        self.displayNode = NotificationExceptionsControllerNode(account: self.account, navigationBar: self.navigationBar!, state: nodeState)
        self.displayNode.backgroundColor = .white
        
        self.controllerNode.navigationBar = self.navigationBar
        
        self.controllerNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.controllerNode.requestActivateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.displayNodeDidLoad()
        
        self._ready.set(self.controllerNode.ready)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //  self.controllerNode.animateIn()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
    
    func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.controllerNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.controllerNode.deactivateSearch()
        }
    }
}



private final class NotificationExceptionsControllerNode: ASDisplayNode {
    private let account: Account
    
    var inProgress: Bool = false {
        didSet {
            
        }
    }
    
    var navigationBar: NavigationBar?
    
    
    private let contentNode: ItemListControllerNode<NotificationExceptionEntry>
    
    private var contactListActive = false
    
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var readyValue = Promise<Bool>()
    var ready: Signal<Bool, NoError> {
        return self.readyValue.get()
    }
    
    private let state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>
    
    init(account: Account, navigationBar: NavigationBar, state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>) {
        self.account = account
        self.state = state
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        
        self.contentNode = ItemListControllerNode(navigationBar: navigationBar, updateNavigationOffset: { _ in
            
        }, state: state)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.contentNode)
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    strongSelf.presentationData = presentationData
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
            })
        
        
        
        self.readyValue.set(contentNode.ready)
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.searchDisplayController?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let cleanInsets = layout.insets(options: [])
        
        
        var controlSize = CGSize(width: 0, height:0)
        controlSize.width = min(layout.size.width, max(200.0, controlSize.width))
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        insets.bottom = max(insets.bottom, cleanInsets.bottom)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.contentNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.contentNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        self.contentNode.containerLayoutUpdated(layout, navigationBarHeight: insets.top, transition: transition)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        if self.contentNode.supernode != nil {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.contentNode.listNode.forEachItemNode { node in
                if let node = node as? NotificationSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            if let _ = self.searchDisplayController {
                return
            }
            
            if let placeholderNode = maybePlaceholderNode {
                self.searchDisplayController = SearchDisplayController(theme: self.presentationData.theme, strings: self.presentationData.strings, contentNode: NotificationExceptionsSearchControllerContentNode(account: account, navigationBar: navigationBar, state: self.state), cancel: { [weak self] in
                    self?.requestDeactivateSearch?()
                })
                
                self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                self.searchDisplayController?.activate(insertSubnode: { subnode in
                    self.insertSubnode(subnode, belowSubnode: navigationBar)
                }, placeholder: placeholderNode)
            }
        }
    }
    
    func deactivateSearch() {
        if let searchDisplayController = self.searchDisplayController {
            if self.contentNode.supernode != nil {
                var maybePlaceholderNode: SearchBarPlaceholderNode?
                self.contentNode.listNode.forEachItemNode { node in
                    if let node = node as? NotificationSearchItemNode {
                        maybePlaceholderNode = node.searchBarNode
                    }
                }
                
                searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
                self.searchDisplayController = nil
            }
        }
    }
    
    func scrollToTop() {
        if self.contentNode.supernode != nil {
           // self.contentNode.scrollToPosition(.top)
        }
    }

    
}

private final class NotificationExceptionsSearchControllerContentNode: SearchDisplayControllerContentNode {
    private let account: Account
    
    private let listNode: ItemListControllerNode<NotificationExceptionEntry>
    private let dimNode: ASDisplayNode
    private var validLayout: ContainerViewLayout?
    
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<ChatListPresentationData>
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private let state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>

    
    init(account: Account, navigationBar: NavigationBar, state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>) {
        self.account = account
        self.state = state
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations))
        
        self.listNode = ItemListControllerNode(navigationBar: navigationBar, updateNavigationOffset: { _ in
            
        }, state: searchQuery.get() |> mapToSignal { query in
            return state |> map { values in
                var values = values
                let entries = values.1.0.entries.filter { entry in
                    switch entry {
                    case .search:
                        return false
                    case let .peer(_, peer, _, _, _, _, _):
                        if let query = query {
                            return !peer.displayTitle.components(separatedBy: " ").filter({$0.lowercased().hasPrefix(query.lowercased())}).isEmpty && !query.isEmpty
                        } else {
                            return false
                        }
                    }
                }
                values.1.0 = ItemListNodeState(entries: entries, style: values.1.0.style, focusItemTag: nil, emptyStateItem: nil, searchItem: nil, crossfadeState: false, animateChanges: false)
                return values
            }
        })
        
        
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        super.init()
        
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        self.listNode.isHidden = true
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme {
                        strongSelf.updateTheme(theme: presentationData.theme)
                    }
                }
            })

    }
    
    deinit {
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = theme.chatList.backgroundColor
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
            self.listNode.isHidden = true
        } else {
            self.searchQuery.set(.single(text))
            self.listNode.isHidden = false
        }
        
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.validLayout = layout
        

        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))

        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.containerLayoutUpdated(layout, navigationBarHeight: 28, transition: transition)
    }
    
}
