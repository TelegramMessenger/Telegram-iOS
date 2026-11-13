import Foundation
import Postbox
import SwiftSignalKit

public final class SupportContext {
    private struct ChatListLoad {
        var period: Int32
        var till: Int32
    }

    private enum UserInfoSaveResult {
        case saved
        case failed
        case replaced
    }
    
    private final class UserInfoSave {
        let text: String
        let entities: [MessageTextEntity]
        let result = Promise<UserInfoSaveResult>()
        let disposable = MetaDisposable()
        
        init(text: String, entities: [MessageTextEntity]) {
            self.text = text
            self.entities = entities
        }
    }
    
    private final class UserInfoState {
        var infos: [PeerId: SupportUserInfo] = [:]
        var saves: [PeerId: UserInfoSave] = [:]
    }
    
    private let currentChatListLoad = Atomic<ChatListLoad?>(value: nil)
    private let chatListLoadTillPromise = ValuePromise<Int32>(ignoreRepeated: true)
    private var settingsDisposable: Disposable?
    private var quietSettingsDisposable: Disposable?
    private let automaticMediaDownloadValue = Atomic<Bool>(value: false)
    private let automaticMediaDownloadPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let inAppNotificationsValue = Atomic<Bool>(value: false)
    private let chatListBesideValue = Atomic<SupportChatListBeside>(value: .off)
    private let chatListBesidePromise = ValuePromise<SupportChatListBeside>(.off, ignoreRepeated: true)
    private let shortcutOverridesValue = Atomic<[SupportShortcutOverride]>(value: [])
    private let trailingTagsValue = Atomic<Bool>(value: SupportSettings.default.trailingTags)
    private let collapseMiddleTagsValue = Atomic<Bool>(value: SupportSettings.default.collapseMiddleTags)
    private let hideKeyboardOnSwitchValue = Atomic<Bool>(value: SupportSettings.default.hideKeyboardOnSwitch)
    private let hidesChatsWithoutIncomingMessagesPromise = ValuePromise<Bool>(SupportSettings.default.hideChatsWithoutIncomingMessages, ignoreRepeated: true)
    private let composerFocusSkip = Atomic<(peerId: PeerId, until: Double)?>(value: nil)
    private let supportNamePromise = ValuePromise<String>(ignoreRepeated: true)
    private let userInfoState = Atomic(value: UserInfoState())
    private let userInfoUpdated = ValuePipe<PeerId>()
    private let openChats = Atomic<[(token: Int, peerId: PeerId)]>(value: [])
    private let nextOpenChatToken = Atomic<Int>(value: 0)
    private let openChatPromise = ValuePromise<PeerId?>(nil, ignoreRepeated: true)
    private let receivedDraftsPipe = ValuePipe<[SupportReceivedDraft]>()
    private let occupationsPromise = ValuePromise<[PeerId: SupportOccupation]>([:], ignoreRepeated: true)
    private let chatOrderLaunchResortTaken = Atomic<Bool>(value: false)
    private let searchResults = Atomic<(owner: ObjectIdentifier, peerIds: [PeerId])?>(value: nil)
    private let chatHistory = Atomic<SupportChatHistory>(value: SupportChatHistory())
    private let chatHistoryPeerIdsPromise = ValuePromise<[PeerId]>([], ignoreRepeated: true)
    private let hardwareKeyGate = Atomic<SupportHardwareKeyGate>(value: SupportHardwareKeyGate())
    
    func takeChatOrderLaunchResort() -> Bool {
        return !self.chatOrderLaunchResortTaken.swap(true)
    }
    
    // The chats an open search lists, in order. A send walks these instead of the chat list while they are set.
    public var searchResultPeerIds: [PeerId]? {
        return self.searchResults.with { $0?.peerIds }
    }
    
    public func setSearchResults(peerIds: [PeerId]?, owner: AnyObject) {
        let ownerId = ObjectIdentifier(owner)
        let _ = self.searchResults.modify { current in
            if let peerIds {
                return (ownerId, peerIds)
            }
            return current?.owner == ownerId ? nil : current
        }
    }
    
    var chatHistoryPeerIds: Signal<[PeerId], NoError> {
        return self.chatHistoryPeerIdsPromise.get()
    }

    public func pushChatHistory(peerId: PeerId) {
        let updated = self.chatHistory.modify { current in
            var current = current
            current.push(peerId: peerId)
            return current
        }
        self.chatHistoryPeerIdsPromise.set(updated.peerIds)
    }

    public func selectChatHistory(position: Int, peerId: PeerId) {
        let _ = self.chatHistory.modify { current in
            var current = current
            current.select(position: position, peerId: peerId)
            return current
        }
    }

    public func chatHistoryTarget(steps: Int) -> PeerId? {
        return self.chatHistory.with { $0.target(steps: steps) }
    }

    public func moveChatHistory(steps: Int) {
        let _ = self.chatHistory.modify { current in
            var current = current
            current.move(steps: steps)
            return current
        }
    }

    public func allowsHardwarePress(of key: SupportHardwareKey) -> Bool {
        var result = false
        let _ = self.hardwareKeyGate.modify { current in
            var current = current
            result = current.allowsPress(of: key, at: CFAbsoluteTimeGetCurrent())
            return current
        }
        return result
    }

    public var supportName: Signal<String, NoError> {
        return self.supportNamePromise.get()
    }
    
    public var chatListLoadTill: Signal<Int32, NoError> {
        return self.chatListLoadTillPromise.get()
    }
    
    public var automaticMediaDownload: Signal<Bool, NoError> {
        return self.automaticMediaDownloadPromise.get()
    }
    
    public var currentAutomaticMediaDownload: Bool {
        return self.automaticMediaDownloadValue.with { $0 }
    }
    
    public var currentInAppNotifications: Bool {
        return self.inAppNotificationsValue.with { $0 }
    }
    
    public var chatListBeside: Signal<SupportChatListBeside, NoError> {
        return self.chatListBesidePromise.get()
    }
    
    public var currentChatListBeside: SupportChatListBeside {
        return self.chatListBesideValue.with { $0 }
    }
    
    public var currentShortcutOverrides: [SupportShortcutOverride] {
        return self.shortcutOverridesValue.with { $0 }
    }
    
    public var currentTrailingTags: Bool {
        return self.trailingTagsValue.with { $0 }
    }

    public var currentCollapseMiddleTags: Bool {
        return self.collapseMiddleTagsValue.with { $0 }
    }
    
    public var currentHideKeyboardOnSwitch: Bool {
        return self.hideKeyboardOnSwitchValue.with { $0 }
    }

    public var hidesChatsWithoutIncomingMessages: Signal<Bool, NoError> {
        return self.hidesChatsWithoutIncomingMessagesPromise.get()
    }
    
    // A switch that keeps the keyboard closed: the chat it opens skips the composer focus a support chat takes on open.
    public func skipComposerFocus(peerId: PeerId, now: Double = CFAbsoluteTimeGetCurrent()) {
        let _ = self.composerFocusSkip.swap((peerId, now + 2.0))
    }
    
    public func takeComposerFocusSkip(peerId: PeerId, now: Double = CFAbsoluteTimeGetCurrent()) -> Bool {
        var result = false
        let _ = self.composerFocusSkip.modify { current in
            guard let current, current.peerId == peerId else {
                return current
            }
            result = now < current.until
            return nil
        }
        return result
    }
    
    public func shortcutCombos(_ action: SupportShortcutAction) -> [SupportKeyCombo] {
        return supportShortcutCombos(action, overrides: self.shortcutOverridesValue.with { $0 })
    }
    
    init(settings: Signal<SupportSettings, NoError>) {
        self.settingsDisposable = (settings
        |> map { settings -> Int32 in
            return settings.chatLoadPeriod
        }
        |> distinctUntilChanged).start(next: { [weak self] period in
            guard let self else {
                return
            }
            let till = supportChatListInitialLoadTill(now: Int32(Date().timeIntervalSince1970), period: period)
            let _ = self.currentChatListLoad.swap(ChatListLoad(period: period, till: till))
            self.chatListLoadTillPromise.set(till)
        })
        self.quietSettingsDisposable = settings.start(next: { [weak self] settings in
            guard let self else {
                return
            }
            let _ = self.automaticMediaDownloadValue.swap(settings.automaticMediaDownload)
            let _ = self.inAppNotificationsValue.swap(settings.inAppNotifications)
            let _ = self.chatListBesideValue.swap(settings.chatListBeside)
            let _ = self.shortcutOverridesValue.swap(settings.shortcutOverrides)
            let _ = self.trailingTagsValue.swap(settings.trailingTags)
            let _ = self.collapseMiddleTagsValue.swap(settings.collapseMiddleTags)
            let _ = self.hideKeyboardOnSwitchValue.swap(settings.hideKeyboardOnSwitch)
            self.chatListBesidePromise.set(settings.chatListBeside)
            self.automaticMediaDownloadPromise.set(settings.automaticMediaDownload)
            self.hidesChatsWithoutIncomingMessagesPromise.set(settings.hideChatsWithoutIncomingMessages)
        })
    }
    
    deinit {
        self.settingsDisposable?.dispose()
        self.quietSettingsDisposable?.dispose()
    }
    
    public func loadMoreChats(holeTimestamp: Int32) {
        let load = self.currentChatListLoad.modify { current in
            guard var current else {
                return nil
            }
            current.till = supportChatListLoadTillAfterLoadMore(current: current.till, holeTimestamp: holeTimestamp, period: current.period)
            return current
        }
        if let load {
            self.chatListLoadTillPromise.set(load.till)
        }
    }
    
    func setSupportName(_ name: String) {
        self.supportNamePromise.set(name)
    }
    
    // The most recently opened chat is the one occupied; disposing the result closes it.
    public func openChat(peerId: PeerId) -> Disposable {
        let token = self.nextOpenChatToken.modify { $0 + 1 }
        let current = self.openChats.modify { chats in
            return chats + [(token, peerId)]
        }
        self.openChatPromise.set(current.last?.peerId)
        return ActionDisposable { [weak self] in
            guard let self else {
                return
            }
            let current = self.openChats.modify { chats in
                return chats.filter { $0.token != token }
            }
            self.openChatPromise.set(current.last?.peerId)
        }
    }
    
    var openChat: Signal<PeerId?, NoError> {
        return self.openChatPromise.get()
    }
    
    func addReceivedDrafts(_ drafts: [SupportReceivedDraft]) {
        self.receivedDraftsPipe.putNext(drafts)
    }
    
    var receivedDrafts: Signal<[SupportReceivedDraft], NoError> {
        return self.receivedDraftsPipe.signal()
    }
    
    // Chats other agents hold, until two seconds past their claim.
    public var occupations: Signal<[PeerId: SupportOccupation], NoError> {
        return self.occupationsPromise.get()
    }
    
    func setOccupations(_ occupations: [PeerId: SupportOccupation]) {
        self.occupationsPromise.set(occupations)
    }
    
    public func currentUserInfo(peerId: PeerId) -> SupportUserInfo? {
        return self.userInfoState.with { state in
            return state.infos[peerId]
        }
    }
    
    public func userInfo(peerId: PeerId) -> Signal<SupportUserInfo?, NoError> {
        return (.single(peerId)
        |> then(self.userInfoUpdated.signal()
        |> filter { updatedPeerId in
            return updatedPeerId == peerId
        }))
        |> map { [weak self] _ -> SupportUserInfo? in
            return self?.currentUserInfo(peerId: peerId)
        }
        |> distinctUntilChanged
    }
    
    func applyUserInfo(peerId: PeerId, info: SupportUserInfo?) {
        let changed = self.userInfoState.with { state -> Bool in
            if state.infos[peerId] == info {
                return false
            }
            state.infos[peerId] = info
            return true
        }
        if changed {
            self.userInfoUpdated.putNext(peerId)
        }
    }
    
    func saveUserInfo(peerId: PeerId, text: String, entities: [MessageTextEntity], request: Signal<SupportUserInfo?, SaveSupportUserInfoError>) -> Signal<Never, SaveSupportUserInfoError> {
        let save = UserInfoSave(text: text, entities: entities)
        let (current, replaced) = self.userInfoState.with { state -> (UserInfoSave, UserInfoSave?) in
            if let existing = state.saves[peerId] {
                if existing.text == text && existing.entities == entities {
                    return (existing, nil)
                }
                state.saves[peerId] = save
                return (save, existing)
            }
            state.saves[peerId] = save
            return (save, nil)
        }
        if let replaced {
            replaced.disposable.dispose()
            replaced.result.set(.single(.replaced))
        }
        if current === save {
            save.disposable.set(request.start(next: { [weak self, weak save] info in
                guard let self, let save else {
                    return
                }
                self.finishUserInfoSave(peerId: peerId, save: save)
                self.applyUserInfo(peerId: peerId, info: info)
                save.result.set(.single(.saved))
            }, error: { [weak self, weak save] _ in
                guard let self, let save else {
                    return
                }
                self.finishUserInfoSave(peerId: peerId, save: save)
                save.result.set(.single(.failed))
            }))
        }
        return current.result.get()
        |> take(1)
        |> castError(SaveSupportUserInfoError.self)
        |> mapToSignal { result -> Signal<Never, SaveSupportUserInfoError> in
            switch result {
            case .saved, .replaced:
                return .complete()
            case .failed:
                return .fail(.generic)
            }
        }
    }
    
    private func finishUserInfoSave(peerId: PeerId, save: UserInfoSave) {
        let _ = self.userInfoState.with { state in
            if state.saves[peerId] === save {
                state.saves.removeValue(forKey: peerId)
            }
        }
    }
}

func _internal_supportChatListLoadState(account: Account) -> Signal<SupportChatListLoadState, NoError> {
    guard let supportContext = account.supportContext else {
        return .single(.allLoaded)
    }
    let holeKeys: [PostboxViewKey] = [.allChatListHoles(.root), .allChatListHoles(Namespaces.PeerGroup.archive)]
    return combineLatest(account.postbox.combinedView(keys: holeKeys), supportContext.chatListLoadTill)
    |> map { view, loadTill -> SupportChatListLoadState in
        let holeTimestamps = holeKeys.compactMap { key -> Int32? in
            return (view.views[key] as? AllChatListHolesView)?.latestHole?.index.timestamp
        }
        return supportChatListLoadState(holeTimestamps: holeTimestamps, loadTill: loadTill)
    }
    |> distinctUntilChanged
}
