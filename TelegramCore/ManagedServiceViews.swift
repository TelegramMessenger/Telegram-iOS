import Foundation
import Postbox
import SwiftSignalKit

func managedServiceViews(network: Network, postbox: Postbox, stateManager: StateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let disposable = DisposableSet()
        disposable.add(managedMessageHistoryHoles(network: network, postbox: postbox).start())
        disposable.add(managedChatListHoles(network: network, postbox: postbox).start())
        disposable.add(managedUnsentMessageIndices(network: network, postbox: postbox, stateManager: stateManager).start())
        disposable.add(managedSynchronizePeerReadStates(network: network, postbox: postbox, stateManager: stateManager).start())
        return disposable
    }
}
