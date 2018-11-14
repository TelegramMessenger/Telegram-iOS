import UserNotifications
import Postbox
import SwiftSignalKit
import TelegramCore

private func reportMemory() {
    // constant
    let MACH_TASK_BASIC_INFO_COUNT = (MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
    
    // prepare parameters
    let name   = mach_task_self_
    let flavor = task_flavor_t(MACH_TASK_BASIC_INFO)
    var size   = mach_msg_type_number_t(MACH_TASK_BASIC_INFO_COUNT)
    
    // allocate pointer to mach_task_basic_info
    let infoPointer = UnsafeMutablePointer<mach_task_basic_info>.allocate(capacity: 1)
    
    // call task_info - note extra UnsafeMutablePointer(...) call
    let kerr = infoPointer.withMemoryRebound(to: Int32.self, capacity: 1, { pointer in
        return task_info(name, flavor, pointer, &size)
    })
    
    // get mach_task_basic_info struct out of pointer
    let info = infoPointer.move()
    
    // deallocate pointer
    infoPointer.deallocate(capacity: 1)
    
    // check return value for success / failure
    if kerr == KERN_SUCCESS {
        NSLog("Memory in use (in MB): \(info.resident_size/1000000)")
    }
}

private struct ResolvedNotificationContent {
    let text: String
    let attachment: UNNotificationAttachment?
}

@objc(NotificationService)
class NotificationService: UNNotificationServiceExtension {
    private let disposable = MetaDisposable()
    
    private var bestEffortContent: UNMutableNotificationContent?
    private var currentContentHandler: ((UNNotificationContent) -> Void)?
    
    var timer: SwiftSignalKit.Timer?
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        contentHandler(request.content)
        
        /*self.timer?.invalidate()
        
        reportMemory()
        
        self.timer = SwiftSignalKit.Timer(timeout: 0.01, repeat: true, completion: {
            reportMemory()
        }, queue: Queue.mainQueue())
        self.timer?.start()
        
        NSLog("before api")
        reportMemory()
        let a = TelegramCore.Api.User.userEmpty(id: 1)
        NSLog("after api \(a)")
        reportMemory()
        
        
        
        if let content = request.content.mutableCopy() as? UNMutableNotificationContent {
            var peerId: PeerId?
            if let fromId = request.content.userInfo["from_id"] {
                var idValue: Int32?
                if let id = fromId as? NSNumber {
                    idValue = Int32(id.intValue)
                } else if let id = fromId as? NSString {
                    idValue = id.intValue
                }
                if let idValue = idValue {
                    if idValue > 0 {
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: idValue)
                    } else {
                        
                    }
                }
            } else if let fromId = request.content.userInfo["chat_id"] {
                var idValue: Int32?
                if let id = fromId as? NSNumber {
                    idValue = Int32(id.intValue)
                } else if let id = fromId as? NSString {
                    idValue = id.intValue
                }
                if let idValue = idValue {
                    if idValue > 0 {
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: idValue)
                    }
                }
            } else if let fromId = request.content.userInfo["channel_id"] {
                var idValue: Int32?
                if let id = fromId as? NSNumber {
                    idValue = Int32(id.intValue)
                } else if let id = fromId as? NSString {
                    idValue = id.intValue
                }
                if let idValue = idValue {
                    if idValue > 0 {
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: idValue)
                    }
                }
            }
            
            var messageId: MessageId?
            if let peerId = peerId, let mid = request.content.userInfo["msg_id"] {
                var idValue: Int32?
                if let id = mid as? NSNumber {
                    idValue = Int32(id.intValue)
                } else if let id = mid as? NSString {
                    idValue = id.intValue
                }
                
                if let idValue = idValue {
                    messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: idValue)
                }
            }
            
            content.body = "[timeout] \(messageId) \(content.body)"
            
            self.bestEffortContent = content
            self.currentContentHandler = contentHandler
            
            var signal: Signal<Void, NoError> = .complete()
            if let messageId = messageId {
                let appBundleIdentifier = Bundle.main.bundleIdentifier!
                guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
                    return
                }
                
                let appGroupName = "group.\(appBundleIdentifier.substring(to: lastDotRange.lowerBound))"
                let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
                
                guard let appGroupUrl = maybeAppGroupUrl else {
                    return
                }
                
                let authorizedAccount = accountWithId(currentAccountId(appGroupPath: appGroupUrl.path), appGroupPath: appGroupUrl.path) |> mapToSignal { account -> Signal<Account, NoError> in
                    switch account {
                        case .left:
                            return .complete()
                        case let .right(authorizedAccount):
                            return .single(authorizedAccount)
                    }
                }
                
                
                signal = (authorizedAccount
                    |> take(1)
                    |> mapToSignal { account -> Signal<Message?, NoError> in
                        setupAccount(account)
                        return downloadMessage(account: account, message: messageId)
                    }
                    |> mapToSignal { message -> Signal<ResolvedNotificationContent?, NoError> in
                        Queue.mainQueue().async {
                            content.body = "[timeout5] \(message) \(content.body)"
                            contentHandler(content)
                        }
                        
                        if let message = message {
                            return .single(ResolvedNotificationContent(text: "R " + message.text, attachment: nil))
                        } else {
                            return .complete()
                        }
                    }
                    |> deliverOnMainQueue
                    |> mapToSignal { [weak self] resolvedContent -> Signal<Void, NoError> in
                        if let strongSelf = self, let resolvedContent = resolvedContent {
                            content.body = resolvedContent.text
                            if let attachment = resolvedContent.attachment {
                                content.attachments = [attachment]
                            }
                            contentHandler(content)
                            strongSelf.bestEffortContent = nil
                        }
                        return .complete()
                    })
                    |> afterDisposed { [weak self] in
                        Queue.mainQueue().async {
                            if let strongSelf = self {
                                if let bestEffortContent = strongSelf.bestEffortContent {
                                    contentHandler(bestEffortContent)
                                }
                            }
                        }
                }
            }
            
            self.disposable.set(signal.start())
        } else {
            contentHandler(request.content)
        }*/
    }
    
    override func serviceExtensionTimeWillExpire() {
        self.disposable.dispose()
        
        if let currentContentHandler = self.currentContentHandler, let bestEffortContent = self.bestEffortContent {
            currentContentHandler(bestEffortContent)
        }
    }
}
