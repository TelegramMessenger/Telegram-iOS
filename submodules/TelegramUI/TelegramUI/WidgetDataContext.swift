import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import WidgetItems
import TelegramPresentationData
import NotificationsPresentationData

final class WidgetDataContext {
    private var currentAccount: Account?
    private var currentAccountDisposable: Disposable?
    private var widgetPresentationDataDisposable: Disposable?
    private var notificationPresentationDataDisposable: Disposable?
    
    init(basePath: String, activeAccount: Signal<Account?, NoError>, presentationData: Signal<PresentationData, NoError>) {
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
                        
                        var name: String = ""
                        var lastName: String?
                        
                        if let firstName = user.firstName {
                            name = firstName
                            lastName = user.lastName
                        } else if let lastName = user.lastName {
                            name = lastName
                        } else if let phone = user.phone, !phone.isEmpty {
                            name = phone
                        }
                        
                        return WidgetDataPeer(id: user.id.toInt64(), name: name, lastName: lastName, letters: user.displayLetters, avatarPath: smallestImageRepresentation(user.photo).flatMap { representation in
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
        
        self.widgetPresentationDataDisposable = (presentationData
        |> map { presentationData -> WidgetPresentationData in
            return WidgetPresentationData(applicationLockedString: presentationData.strings.Widget_ApplicationLocked)
        }
        |> distinctUntilChanged).start(next: { value in
            let path = widgetPresentationDataPath(rootPath: basePath)
            if let data = try? JSONEncoder().encode(value) {
                let _ = try? data.write(to: URL(fileURLWithPath: path), options: [.atomic])
            } else {
                let _ = try? FileManager.default.removeItem(atPath: path)
            }
        })
        
        self.notificationPresentationDataDisposable = (presentationData
        |> map { presentationData -> NotificationsPresentationData in
            return NotificationsPresentationData(applicationLockedMessageString: presentationData.strings.PUSH_LOCKED_MESSAGE("").0)
        }
        |> distinctUntilChanged).start(next: { value in
            let path = notificationsPresentationDataPath(rootPath: basePath)
            if let data = try? JSONEncoder().encode(value) {
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
