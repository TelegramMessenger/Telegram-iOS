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
