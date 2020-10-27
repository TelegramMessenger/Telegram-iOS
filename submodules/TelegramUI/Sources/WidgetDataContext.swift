import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import WidgetItems
import TelegramPresentationData
import NotificationsPresentationData
import WidgetKit

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
            
            enum RecentPeers {
                struct Unread {
                    var count: Int32
                    var isMuted: Bool
                }
                
                case disabled
                case peers(peers: [Peer], unread: [PeerId: Unread])
            }
            
            let recent: Signal<RecentPeers, NoError> = recentPeers(account: account)
            |> mapToSignal { recent -> Signal<RecentPeers, NoError> in
                switch recent {
                    case .disabled:
                        return .single(.disabled)
                    case let .peers(peers):
                        return combineLatest(queue: .mainQueue(), peers.filter { !$0.isDeleted }.map { account.postbox.peerView(id: $0.id)}) |> mapToSignal { peerViews -> Signal<RecentPeers, NoError> in
                            return account.postbox.unreadMessageCountsView(items: peerViews.map {
                                .peer($0.peerId)
                            })
                            |> map { values -> RecentPeers in
                                var peers: [Peer] = []
                                var unread: [PeerId: RecentPeers.Unread] = [:]
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
                                            unread[peerView.peerId] = RecentPeers.Unread(count: Int32(unreadCount), isMuted: isMuted)
                                        }
                                        
                                        peers.append(peer)
                                    }
                                }
                                return .peers(peers: peers, unread: unread)
                            }
                        }
                }
            }
            
            return recent
            |> map { result -> WidgetData in
                switch result {
                case .disabled:
                    return .disabled
                case let .peers(peers, unread):
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
                        
                        var badge: WidgetDataPeer.Badge?
                        if let unreadValue = unread[peer.id], unreadValue.count > 0 {
                            badge = WidgetDataPeer.Badge(
                                count: Int(unreadValue.count),
                                isMuted: unreadValue.isMuted
                            )
                        }
                        
                        return WidgetDataPeer(id: user.id.toInt64(), name: name, lastName: lastName, letters: user.displayLetters, avatarPath: smallestImageRepresentation(user.photo).flatMap { representation in
                            return account.postbox.mediaBox.resourcePath(representation.resource)
                        }, badge: badge)
                    }))
                }
            }
            |> distinctUntilChanged
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
