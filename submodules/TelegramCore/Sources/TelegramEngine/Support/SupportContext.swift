import Foundation
import Postbox
import SwiftSignalKit

public final class SupportContext {
    private struct ChatListLoad {
        var period: Int32
        var till: Int32
    }

    private let currentChatListLoad = Atomic<ChatListLoad?>(value: nil)
    private let chatListLoadTillPromise = ValuePromise<Int32>(ignoreRepeated: true)
    private var settingsDisposable: Disposable?
    private let supportNamePromise = ValuePromise<String>(ignoreRepeated: true)
    private let openChats = Atomic<[(token: Int, peerId: PeerId)]>(value: [])
    private let nextOpenChatToken = Atomic<Int>(value: 0)
    private let openChatPromise = ValuePromise<PeerId?>(nil, ignoreRepeated: true)
    private let receivedDraftsPipe = ValuePipe<[SupportReceivedDraft]>()
    private let occupationsPromise = ValuePromise<[PeerId: SupportOccupation]>([:], ignoreRepeated: true)
    private let chatOrderLaunchResortTaken = Atomic<Bool>(value: false)
    
    func takeChatOrderLaunchResort() -> Bool {
        return !self.chatOrderLaunchResortTaken.swap(true)
    }
    public var supportName: Signal<String, NoError> {
        return self.supportNamePromise.get()
    }
    
    public var chatListLoadTill: Signal<Int32, NoError> {
        return self.chatListLoadTillPromise.get()
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
    }
    
    deinit {
        self.settingsDisposable?.dispose()
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
