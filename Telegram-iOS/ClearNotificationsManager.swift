import Foundation
import SwiftSignalKit
import Postbox

final class ClearNotificationIdsCompletion {
    let f: ([(String, NotificationManagedNotificationRequestId)]) -> Void
    
    init(f: @escaping ([(String, NotificationManagedNotificationRequestId)]) -> Void) {
        self.f = f
    }
}

final class ClearNotificationsManager {
    private let getNotificationIds: (ClearNotificationIdsCompletion) -> Void
    private let getPendingNotificationIds: (ClearNotificationIdsCompletion) -> Void
    private let removeNotificationIds: ([String]) -> Void
    private let removePendingNotificationIds: ([String]) -> Void
    
    private var ids: [PeerId: MessageId] = [:]
    
    private var timer: SwiftSignalKit.Timer?
    
    init(getNotificationIds: @escaping (ClearNotificationIdsCompletion) -> Void, removeNotificationIds: @escaping ([String]) -> Void, getPendingNotificationIds: @escaping (ClearNotificationIdsCompletion) -> Void, removePendingNotificationIds: @escaping ([String]) -> Void) {
        self.getNotificationIds = getNotificationIds
        self.removeNotificationIds = removeNotificationIds
        self.getPendingNotificationIds = getPendingNotificationIds
        self.removePendingNotificationIds = removePendingNotificationIds
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func append(_ id: MessageId) {
        if let current = self.ids[id.peerId] {
            if current < id {
                self.ids[id.peerId] = id
            }
        } else {
            self.ids[id.peerId] = id
        }
        self.timer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
            self?.commitNow()
        }, queue: Queue.mainQueue())
        self.timer = timer
        timer.start()
    }
    
    func commitNow() {
        self.timer?.invalidate()
        self.timer = nil
        
        let ids = self.ids
        self.ids.removeAll()
        
        self.getNotificationIds(ClearNotificationIdsCompletion { [weak self] result in
            Queue.mainQueue().async {
                var removeKeys: [String] = []
                for (identifier, requestId) in result {
                    if case let .messageId(messageId) = requestId {
                        if let maxId = ids[messageId.peerId], messageId <= maxId {
                            removeKeys.append(identifier)
                        }
                    }
                }
                
                if let strongSelf = self, !removeKeys.isEmpty {
                    strongSelf.removeNotificationIds(removeKeys)
                }
            }
        })
        
        self.getPendingNotificationIds(ClearNotificationIdsCompletion { [weak self] result in
            Queue.mainQueue().async {
                var removeKeys: [String] = []
                for (identifier, requestId) in result {
                    if case let .messageId(messageId) = requestId {
                        if let maxId = ids[messageId.peerId], messageId <= maxId {
                            removeKeys.append(identifier)
                        }
                    }
                }
                
                if let strongSelf = self, !removeKeys.isEmpty {
                    strongSelf.removePendingNotificationIds(removeKeys)
                }
            }
        })
    }
}
