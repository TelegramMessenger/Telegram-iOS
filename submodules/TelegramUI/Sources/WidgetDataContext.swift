import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import WidgetItems
import TelegramPresentationData
import NotificationsPresentationData
import WidgetKit
import TelegramUIPreferences
import WidgetItemsUtils
import AccountContext
import AppLock

import GeneratedSources

@available(iOSApplicationExtension 14.0, iOS 14.0, *)
private extension SelectFriendsIntent {
    var configurationHash: String {
        var result = "widget"
        if let items = self.friends {
            for item in items {
                if let identifier = item.identifier {
                    result.append("+\(identifier)")
                }
            }
        }
        return result
    }
}

final class WidgetDataContext {
    private var currentAccount: Account?
    private var currentAccountDisposable: Disposable?
    private var widgetPresentationDataDisposable: Disposable?
    private var notificationPresentationDataDisposable: Disposable?
    
    init(basePath: String, activeAccount: Signal<Account?, NoError>, presentationData: Signal<PresentationData, NoError>, appLockContext: AppLockContextImpl) {
        self.currentAccountDisposable = (activeAccount
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs === rhs
        })
        |> mapToSignal { account -> Signal<WidgetData, NoError> in
            guard let account = account else {
                return .single(WidgetData(accountId: 0, content: .empty, unlockedForLockId: nil))
            }
            
            enum CombinedRecentPeers {
                struct Unread {
                    var count: Int32
                    var isMuted: Bool
                }
                
                case disabled
                case peers(peers: [Peer], unread: [PeerId: Unread], messages: [PeerId: WidgetDataPeer.Message])
            }
            
            let updatedAdditionalPeerIds: Signal<(Set<PeerId>, Set<String>), NoError> = Signal { subscriber in
                if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
                    #if arch(arm64) || arch(i386) || arch(x86_64)
                    WidgetCenter.shared.getCurrentConfigurations({ result in
                        var peerIds = Set<PeerId>()
                        var configurationHashes = Set<String>()
                        if case let .success(infos) = result {
                            for info in infos {
                                if let configuration = info.configuration as? SelectFriendsIntent {
                                    if let items = configuration.friends {
                                        for item in items {
                                            guard let identifier = item.identifier, let peerIdValue = Int64(identifier) else {
                                                continue
                                            }
                                            peerIds.insert(PeerId(peerIdValue))
                                        }
                                    }
                                    configurationHashes.insert(configuration.configurationHash)
                                }
                            }
                        }
                        
                        subscriber.putNext((peerIds, configurationHashes))
                        subscriber.putCompletion()
                    })
                    #else
                    subscriber.putNext((Set(), Set()))
                    subscriber.putCompletion()
                    #endif
                } else {
                    subscriber.putNext((Set(), Set()))
                    subscriber.putCompletion()
                }
                
                return EmptyDisposable
            }
            |> runOn(.mainQueue())
            
            let unlockedForLockId: Signal<String?, NoError> = .single(nil)
            
            let sourcePeers: Signal<RecentPeers, NoError> = recentPeers(account: account)
            
            let recent: Signal<CombinedRecentPeers, NoError> = sourcePeers
            |> mapToSignal { recent -> Signal<CombinedRecentPeers, NoError> in
                switch recent {
                    case .disabled:
                        return .single(.disabled)
                    case let .peers(peers):
                        return combineLatest(queue: .mainQueue(), peers.filter { !$0.isDeleted }.map { account.postbox.peerView(id: $0.id)})
                        |> mapToSignal { peerViews -> Signal<CombinedRecentPeers, NoError> in
                            let topMessagesKey: PostboxViewKey = .topChatMessage(peerIds: peerViews.map {
                                $0.peerId
                             })
                            return combineLatest(queue: .mainQueue(),
                                 account.postbox.unreadMessageCountsView(items: peerViews.map {
                                     .peer($0.peerId)
                                 }),
                                 account.postbox.combinedView(keys: [topMessagesKey])
                            )
                            |> map { values, combinedView -> CombinedRecentPeers in
                                var peers: [Peer] = []
                                var unread: [PeerId: CombinedRecentPeers.Unread] = [:]
                                var messages: [PeerId: WidgetDataPeer.Message] = [:]
                                
                                let topMessages = combinedView.views[topMessagesKey] as! TopChatMessageView
                                
                                for peerView in peerViews {
                                    if let peer = peerViewMainPeer(peerView) {
                                        var isMuted: Bool = false
                                        if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                            switch notificationSettings.muteState {
                                                case .muted:
                                                    isMuted = true
                                                default:
                                                    break
                                            }
                                        }
                                        
                                        let unreadCount = values.count(for: .peer(peerView.peerId))
                                        if let unreadCount = unreadCount, unreadCount > 0 {
                                            unread[peerView.peerId] = CombinedRecentPeers.Unread(count: Int32(unreadCount), isMuted: isMuted)
                                        }
                                        
                                        if let message = topMessages.messages[peerView.peerId] {
                                            messages[peerView.peerId] = WidgetDataPeer.Message(message: message)
                                        }
                                        
                                        peers.append(peer)
                                    }
                                }
                                return .peers(peers: peers, unread: unread, messages: messages)
                            }
                        }
                }
            }
            
            let processedRecent = recent
            |> map { _ -> WidgetData in
                return WidgetData(accountId: account.id.int64, content: .peers(WidgetDataPeers(accountPeerId: account.peerId.toInt64(), peers: [], updateTimestamp: Int32(Date().timeIntervalSince1970))), unlockedForLockId: nil)
            }
            |> distinctUntilChanged
            
            let additionalPeerIds = Signal<(Set<PeerId>, Set<String>), NoError>.complete() |> then(updatedAdditionalPeerIds)
            let processedCustom: Signal<WidgetData, NoError> = additionalPeerIds
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                return true
            })
            |> mapToSignal { additionalPeerIds, _ -> Signal<CombinedRecentPeers, NoError> in
                return combineLatest(queue: .mainQueue(), additionalPeerIds.map { account.postbox.peerView(id: $0) })
                |> mapToSignal { peerViews -> Signal<CombinedRecentPeers, NoError> in
                    let topMessagesKey: PostboxViewKey = .topChatMessage(peerIds: peerViews.map {
                        $0.peerId
                     })
                    return combineLatest(queue: .mainQueue(),
                         account.postbox.unreadMessageCountsView(items: peerViews.map {
                             .peer($0.peerId)
                         }),
                         account.postbox.combinedView(keys: [topMessagesKey])
                    )
                    |> map { values, combinedView -> CombinedRecentPeers in
                        var peers: [Peer] = []
                        var unread: [PeerId: CombinedRecentPeers.Unread] = [:]
                        var messages: [PeerId: WidgetDataPeer.Message] = [:]
                        
                        let topMessages = combinedView.views[topMessagesKey] as! TopChatMessageView
                        
                        for peerView in peerViews {
                            if let peer = peerViewMainPeer(peerView) {
                                var isMuted: Bool = false
                                if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                    switch notificationSettings.muteState {
                                        case .muted:
                                            isMuted = true
                                        default:
                                            break
                                    }
                                }
                                
                                let unreadCount = values.count(for: .peer(peerView.peerId))
                                if let unreadCount = unreadCount, unreadCount > 0 {
                                    unread[peerView.peerId] = CombinedRecentPeers.Unread(count: Int32(unreadCount), isMuted: isMuted)
                                }
                                
                                if let message = topMessages.messages[peerView.peerId] {
                                    messages[peerView.peerId] = WidgetDataPeer.Message(message: message)
                                }
                                
                                peers.append(peer)
                            }
                        }
                        return .peers(peers: peers, unread: unread, messages: messages)
                    }
                }
            }
            |> map { result -> WidgetData in
                switch result {
                case .disabled:
                    return WidgetData(accountId: account.id.int64, content: .empty, unlockedForLockId: nil)
                case let .peers(peers, unread, messages):
                    return WidgetData(accountId: account.id.int64, content: .peers(WidgetDataPeers(accountPeerId: account.peerId.toInt64(), peers: peers.compactMap { peer -> WidgetDataPeer? in
                        var name: String = ""
                        var lastName: String?
                        
                        if let user = peer as? TelegramUser {
                            if let firstName = user.firstName {
                                name = firstName
                                lastName = user.lastName
                            } else if let lastName = user.lastName {
                                name = lastName
                            } else if let phone = user.phone, !phone.isEmpty {
                                name = phone
                            }
                        } else {
                            name = peer.debugDisplayTitle
                        }
                        
                        var badge: WidgetDataPeer.Badge?
                        if let unreadValue = unread[peer.id], unreadValue.count > 0 {
                            badge = WidgetDataPeer.Badge(
                                count: Int(unreadValue.count),
                                isMuted: unreadValue.isMuted
                            )
                        }
                        
                        let message = messages[peer.id]
                        
                        return WidgetDataPeer(id: peer.id.toInt64(), name: name, lastName: lastName, letters: peer.displayLetters, avatarPath: smallestImageRepresentation(peer.profileImageRepresentations).flatMap { representation in
                            return account.postbox.mediaBox.resourcePath(representation.resource)
                        }, badge: badge, message: message)
                    }, updateTimestamp: Int32(Date().timeIntervalSince1970))), unlockedForLockId: nil)
                }
            }
            |> distinctUntilChanged
            
            return combineLatest(processedRecent, processedCustom, unlockedForLockId)
            |> map { processedRecent, _, unlockedForLockId -> WidgetData in
                var processedRecent = processedRecent
                processedRecent.unlockedForLockId = unlockedForLockId
                return processedRecent
            }
        }).start(next: { widgetData in
            let path = basePath + "/widget-data"
            if let data = try? JSONEncoder().encode(widgetData) {
                let _ = try? data.write(to: URL(fileURLWithPath: path), options: [.atomic])
            } else {
                let _ = try? FileManager.default.removeItem(atPath: path)
            }
            
            if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
                #if arch(arm64) || arch(i386) || arch(x86_64)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        })
        
        self.widgetPresentationDataDisposable = (presentationData
        |> map { presentationData -> WidgetPresentationData in
            return WidgetPresentationData(applicationLockedString: presentationData.strings.Widget_ApplicationLocked, applicationStartRequiredString: presentationData.strings.Widget_ApplicationStartRequired, widgetGalleryTitle: presentationData.strings.Widget_GalleryTitle, widgetGalleryDescription: presentationData.strings.Widget_GalleryDescription)
        }
        |> distinctUntilChanged).start(next: { value in
            let path = widgetPresentationDataPath(rootPath: basePath)
            if let data = try? JSONEncoder().encode(value) {
                let _ = try? data.write(to: URL(fileURLWithPath: path), options: [.atomic])
            } else {
                let _ = try? FileManager.default.removeItem(atPath: path)
            }
            
            if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
                #if arch(arm64) || arch(i386) || arch(x86_64)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
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
