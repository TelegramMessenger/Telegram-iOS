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

private final class WidgetReloadManager {
    private var inForeground = false
    private var inForegroundDisposable: Disposable?
    
    private var isReloadRequested = false
    private var lastBackgroundReload: Double?
    
    init(inForeground: Signal<Bool, NoError>) {
        self.inForegroundDisposable = (inForeground
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.inForeground != value {
                strongSelf.inForeground = value
                if value {
                    strongSelf.performReloadIfNeeded()
                }
            }
        })
    }
    
    deinit {
        self.inForegroundDisposable?.dispose()
    }
    
    func requestReload() {
        self.isReloadRequested = true
        
        if self.inForeground {
            self.performReloadIfNeeded()
        } else {
            let timestamp = CFAbsoluteTimeGetCurrent()
            if let lastBackgroundReloadValue = self.lastBackgroundReload {
                if abs(lastBackgroundReloadValue - timestamp) > 25.0 * 60.0 {
                    self.lastBackgroundReload = timestamp
                    performReloadIfNeeded()
                }
            } else {
                self.lastBackgroundReload = timestamp
                performReloadIfNeeded()
            }
        }
    }
    
    private func performReloadIfNeeded() {
        if !self.isReloadRequested {
            return
        }
        self.isReloadRequested = false
        
        DispatchQueue.global(qos: .background).async {
            if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
                #if arch(arm64) || arch(i386) || arch(x86_64)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }
}

final class WidgetDataContext {
    private let reloadManager: WidgetReloadManager
    
    private var disposable: Disposable?
    private var widgetPresentationDataDisposable: Disposable?
    private var notificationPresentationDataDisposable: Disposable?
    
    init(basePath: String, inForeground: Signal<Bool, NoError>, activeAccounts: Signal<[Account], NoError>, presentationData: Signal<PresentationData, NoError>, appLockContext: AppLockContextImpl) {
        self.reloadManager = WidgetReloadManager(inForeground: inForeground)
        
        let queue = Queue()
        let updatedAdditionalPeerIds: Signal<[AccountRecordId: Set<PeerId>], NoError> = Signal { subscriber in
            if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
                #if arch(arm64) || arch(i386) || arch(x86_64)
                WidgetCenter.shared.getCurrentConfigurations { result in
                    var peerIds: [AccountRecordId: Set<PeerId>] = [:]
                    
                    func processFriend(_ item: Friend) {
                        guard let identifier = item.identifier else {
                            return
                        }
                        guard let index = identifier.firstIndex(of: ":") else {
                            return
                        }
                        guard let accountIdValue = Int64(identifier[identifier.startIndex ..< index]) else {
                            return
                        }
                        guard let peerIdValue = Int64(identifier[identifier.index(after: index)...]) else {
                            return
                        }
                        let accountId = AccountRecordId(rawValue: accountIdValue)
                        let peerId = PeerId(peerIdValue)
                        if peerIds[accountId] == nil {
                            peerIds[accountId] = Set()
                        }
                        peerIds[accountId]?.insert(peerId)
                    }
                    
                    if case let .success(infos) = result {
                        for info in infos {
                            if let configuration = info.configuration as? SelectFriendsIntent {
                                if let items = configuration.friends {
                                    for item in items {
                                        processFriend(item)
                                    }
                                }
                            } else if let configuration = info.configuration as? SelectAvatarFriendsIntent {
                                if let items = configuration.friends {
                                    for item in items {
                                        processFriend(item)
                                    }
                                }
                            }
                        }
                    }
                    
                    subscriber.putNext(peerIds)
                    subscriber.putCompletion()
                }
                #else
                subscriber.putNext([:])
                subscriber.putCompletion()
                #endif
            } else {
                subscriber.putNext([:])
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
        |> runOn(queue)
        |> then(
            Signal<[AccountRecordId: Set<PeerId>], NoError>.complete()
            |> delay(10.0, queue: queue)
        )
        |> restart
        
        self.disposable = (combineLatest(queue: queue,
            updatedAdditionalPeerIds |> distinctUntilChanged,
            activeAccounts |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.count != rhs.count {
                    return false
                }
                for i in 0 ..< lhs.count {
                    if lhs[i] !== rhs[i] {
                        return false
                    }
                }
                return true
            })
        )
        |> mapToSignal { peerIdsByAccount, accounts -> Signal<[WidgetDataPeer], NoError> in
            var accountSignals: [Signal<[WidgetDataPeer], NoError>] = []
            
            for (accountId, peerIds) in peerIdsByAccount {
                var accountValue: Account?
                for value in accounts {
                    if value.id == accountId {
                        accountValue = value
                        break
                    }
                }
                guard let account = accountValue else {
                    continue
                }
                if peerIds.isEmpty {
                    continue
                }
                let topMessagesKey: PostboxViewKey = .topChatMessage(peerIds: Array(peerIds))
                
                accountSignals.append(account.postbox.combinedView(keys: [topMessagesKey])
                |> map { combinedView -> [WidgetDataPeer] in
                    guard let topMessages = combinedView.views[topMessagesKey] as? TopChatMessageView else {
                        return []
                    }
                    var result: [WidgetDataPeer] = []
                    for (peerId, message) in topMessages.messages {
                        result.append(WidgetDataPeer(id: peerId.toInt64(), name: "", lastName: "", letters: [], avatarPath: nil, badge: nil, message: WidgetDataPeer.Message(message: message)))
                    }
                    result.sort(by: { lhs, rhs in
                        return lhs.id < rhs.id
                    })
                    return result
                })
            }
            
            return combineLatest(queue: queue, accountSignals)
            |> map { lists -> [WidgetDataPeer] in
                var result: [WidgetDataPeer] = []
                for list in lists {
                    result.append(contentsOf: list)
                }
                result.sort(by: { lhs, rhs in
                    return lhs.id < rhs.id
                })
                return result
            }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.reloadManager.requestReload()
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
        self.disposable?.dispose()
        self.widgetPresentationDataDisposable?.dispose()
        self.notificationPresentationDataDisposable?.dispose()
    }
}
