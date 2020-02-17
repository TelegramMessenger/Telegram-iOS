import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import OverlayStatusController
import AccountContext
import PresentationDataUtils
import AccountUtils

func openEditSettings(context: AccountContext, accountsAndPeers: Signal<((Account, Peer)?, [(Account, Peer, Int32)]), NoError>, focusOnItemTag: EditSettingsEntryTag? = nil, presentController: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void) -> Disposable {
    let openEditingDisposable = MetaDisposable()
    var cancelImpl: (() -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let progressSignal = Signal<Never, NoError> { subscriber in
        let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
            cancelImpl?()
        }))
        presentController(controller, nil)
        return ActionDisposable { [weak controller] in
            Queue.mainQueue().async() {
                controller?.dismiss()
            }
        }
    }
    |> runOn(Queue.mainQueue())
    |> delay(0.15, queue: Queue.mainQueue())
    let progressDisposable = progressSignal.start()
    
    let peerKey: PostboxViewKey = .peer(peerId: context.account.peerId, components: [])
    let cachedDataKey: PostboxViewKey = .cachedPeerData(peerId: context.account.peerId)
    let signal = (combineLatest(accountsAndPeers |> take(1), context.account.postbox.combinedView(keys: [peerKey, cachedDataKey]))
    |> mapToSignal { accountsAndPeers, view -> Signal<(TelegramUser, CachedUserData, Bool), NoError> in
        guard let cachedDataView = view.views[cachedDataKey] as? CachedPeerDataView, let cachedData = cachedDataView.cachedPeerData as? CachedUserData else {
            return .complete()
        }
        guard let peerView = view.views[peerKey] as? PeerView, let peer = peerView.peers[context.account.peerId] as? TelegramUser else {
            return .complete()
        }
        return .single((peer, cachedData, accountsAndPeers.1.count + 1 < maximumNumberOfAccounts))
    }
    |> take(1))
    |> afterDisposed {
        Queue.mainQueue().async {
            progressDisposable.dispose()
        }
    }
    cancelImpl = {
        openEditingDisposable.set(nil)
    }
    openEditingDisposable.set((signal
    |> deliverOnMainQueue).start(next: { peer, cachedData, canAddAccounts in
        pushController(editSettingsController(context: context, currentName: .personName(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phone: ""), currentBioText: cachedData.about ?? "", accountManager: context.sharedContext.accountManager, canAddAccounts: canAddAccounts, focusOnItemTag: focusOnItemTag))
    }))
    return openEditingDisposable
}
