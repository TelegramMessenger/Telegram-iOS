import Foundation
import UserNotifications

@available(iOSApplicationExtension 10.0, *)
@objc(NotificationService)
final class NotificationService: UNNotificationServiceExtension {
    private let impl: NotificationServiceImpl
    
    override init() {
        var completion: ((Int32) -> Void)?
        self.impl = NotificationServiceImpl(countIncomingMessage: { rootPath, accountId, encryptionParameters, peerId, messageId in
            SyncProviderImpl.addIncomingMessage(withRootPath: rootPath, accountId: accountId, encryptionParameters: encryptionParameters, peerId: peerId, messageId: messageId, completion: { count in
                completion?(count)
            })
        }, isLocked: { rootPath in
            return SyncProviderImpl.isLocked(withRootPath: rootPath)
        }, lockedMessageText: { rootPath in
            return SyncProviderImpl.lockedMessageText(withRootPath: rootPath)
        })
        
        super.init()
        
        completion = { [weak self] count in
            self?.impl.updateUnreadCount(count)
        }
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.impl.didReceive(request, withContentHandler: contentHandler)
    }
    
    override func serviceExtensionTimeWillExpire() {
        self.impl.serviceExtensionTimeWillExpire()
    }
}
