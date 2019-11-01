import Foundation
import UserNotifications
import SwiftSignalKit

private let queue = Queue()

@available(iOSApplicationExtension 10.0, *)
@objc(NotificationService)
final class NotificationService: UNNotificationServiceExtension {
    private let impl: QueueLocalObject<NotificationServiceImpl>
    
    override init() {
        self.impl = QueueLocalObject(queue: queue, generate: {
            var completion: ((Int32) -> Void)?
            let impl = NotificationServiceImpl(serialDispatch: { f in
                queue.async {
                    f()
                }
            }, countIncomingMessage: { rootPath, accountId, encryptionParameters, peerId, messageId in
                SyncProviderImpl.addIncomingMessage(queue: queue, withRootPath: rootPath, accountId: accountId, encryptionParameters: encryptionParameters, peerId: peerId, messageId: messageId, completion: { count in
                    completion?(count)
                })
            }, isLocked: { rootPath in
                return SyncProviderImpl.isLocked(withRootPath: rootPath)
            }, lockedMessageText: { rootPath in
                return SyncProviderImpl.lockedMessageText(withRootPath: rootPath)
            })
            
            completion = { [weak impl] count in
                queue.async {
                    impl?.updateUnreadCount(count)
                }
            }
            
            return impl
        })
        
        super.init()
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.impl.with { impl in
            impl.didReceive(request, withContentHandler: contentHandler)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        self.impl.with { impl in
            impl.serviceExtensionTimeWillExpire()
        }
    }
}
