import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import WidgetItems

final class WidgetDataContext {
    private var currentAccount: Account?
    private var currentAccountDisposable: Disposable?
    
    init(basePath: String, activeAccount: Signal<Account?, NoError>) {
        self.currentAccountDisposable = (activeAccount
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs === rhs
        })
        |> mapToSignal { account -> Signal<WidgetData, NoError> in
            guard let account = account else {
                return .single(.notAuthorized)
            }
            return recentPeers(account: account)
            |> map { result -> WidgetData in
                switch result {
                case .disabled:
                    return .disabled
                case let .peers(peers):
                    return .peers(WidgetDataPeers(accountPeerId: account.peerId.toInt64(), peers: peers.compactMap { peer -> WidgetDataPeer? in
                        guard let user = peer as? TelegramUser else {
                            return nil
                        }
                        return WidgetDataPeer(id: user.id.toInt64(), name: user.shortNameOrPhone ?? "", letters: user.displayLetters, avatarPath: smallestImageRepresentation(user.photo).flatMap { representation in
                            return account.postbox.mediaBox.resourcePath(representation.resource)
                        })
                    }))
                }
            }
        }).start(next: { widgetData in
            let path = basePath + "/widget-data"
            if let data = try? JSONEncoder().encode(widgetData) {
                let _ = try? data.write(to: URL(fileURLWithPath: path), options: [.atomic])
            } else {
                let _ = try? FileManager.default.removeItem(atPath: path)
            }
        })
    }
    
    deinit {
        self.currentAccountDisposable?.dispose()
    }
}
