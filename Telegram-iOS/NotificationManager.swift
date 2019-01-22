import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import UserNotifications
import TelegramUI

private func notificationKey(_ requestId: NotificationManagedNotificationRequestId) -> String {
    switch requestId {
        case let .messageId(id):
            return "m\(id.peerId.toInt64()):\(id.namespace):\(id.id)"
        case let .globallyUniqueId(id, _):
            return "m\(id)"
    }
}

private let messageNotificationKeyExpr = try? NSRegularExpression(pattern: "m([-\\d]+):([-\\d]+):([-\\d]+)_?", options: [])

enum NotificationManagedNotificationRequestId: Hashable {
    case messageId(MessageId)
    case globallyUniqueId(Int64, PeerId?)
    
    init?(string: String) {
        if string.hasPrefix("m") {
            let matches = messageNotificationKeyExpr!.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
            if let match = matches.first {
                let nsString = string as NSString
                let peerIdString = nsString.substring(with: match.range(at: 1))
                let namespaceString = nsString.substring(with: match.range(at: 2))
                let idString = nsString.substring(with: match.range(at: 3))
                
                guard let peerId = Int64(peerIdString) else {
                    return nil
                }
                guard let namespace = Int32(namespaceString) else {
                    return nil
                }
                guard let id = Int32(idString) else {
                    return nil
                }
                self = .messageId(MessageId(peerId: PeerId(peerId), namespace: namespace, id: id))
                return
            }
        }
        return nil
    }
    
    var hashValue: Int {
        switch self {
            case let .messageId(messageId):
                return messageId.id.hashValue
            case let .globallyUniqueId(id, _):
                return id.hashValue
        }
    }
    
    static func ==(lhs: NotificationManagedNotificationRequestId, rhs: NotificationManagedNotificationRequestId) -> Bool {
        switch lhs {
            case let .messageId(id):
                if case .messageId(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .globallyUniqueId(id, peerId):
                if case .globallyUniqueId(id, peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private func processedSoundName(_ name: String) -> String {
    if name.hasSuffix("m4a") {
        return name
    } else {
        return "\(name).m4a"
    }
}

final class NotificationManager {
    private var processedMessages = Set<MessageId>()
    
    var context: AccountContext? {
        didSet {
            assert(Queue.mainQueue().isCurrent())
            
            if let context = self.context {
                self.notificationMessagesDisposable.set((context.account.stateManager.notificationMessages
                |> deliverOn(Queue.mainQueue())).start(next: { [weak self] messages in
                    guard let strongSelf = self else {
                        return
                    }
                    var list: [([Message], PeerMessageSound, Bool, Bool)] = []
                    for (messageGroup, _, notify) in messages {
                        list.append((messageGroup, .default, !strongSelf.isApplicationLocked, false))
                    }
                    //self?.processNotificationMessages(list, isLocked: strongSelf.isApplicationLocked)
                }))
            } else {
                self.notificationMessagesDisposable.set(nil)
            }
        }
    }
    
    private let notificationCallStateDisposable = MetaDisposable()
    var notificationCall: PresentationCall? {
        didSet {
            if self.notificationCall?.internalId != oldValue?.internalId {
                if let notificationCall = self.notificationCall {
                    let peer = notificationCall.peer
                    let internalId = notificationCall.internalId
                    let isIntegratedWithCallKit = notificationCall.isIntegratedWithCallKit
                    self.notificationCallStateDisposable.set((notificationCall.state
                    |> map { state -> (Peer?, CallSessionInternalId)? in
                        if isIntegratedWithCallKit {
                            return nil
                        }
                        if case .ringing = state {
                            return (peer, internalId)
                        } else {
                            return nil
                        }
                    }
                    |> distinctUntilChanged(isEqual: { $0?.1 == $1?.1 })).start(next: { [weak self] peerAndInternalId in
                        self?.updateNotificationCall(call: peerAndInternalId)
                    }))
                } else {
                    self.notificationCallStateDisposable.set(nil)
                    self.updateNotificationCall(call: nil)
                }
            }
        }
    }
    
    private let notificationMessagesDisposable = MetaDisposable()
    
    private var notificationRequests: [NotificationManagedNotificationRequestId: Double] = [:]
    private var processedRequestIds = Set<NotificationManagedNotificationRequestId>()
    
    var isApplicationInForeground: Bool = false
    var isApplicationLocked: Bool = false
    
    deinit {
        self.notificationMessagesDisposable.dispose()
    }
    
    func enqueueRemoteNotification(title: String, text: String, apnsSound: String?, requestId: NotificationManagedNotificationRequestId, strings: PresentationStrings, accessChallengeData: PostboxAccessChallengeData) {
        if notificationRequests[requestId] == nil && !processedRequestIds.contains(requestId) {
            var isLocked = false
            if isAccessLocked(data: accessChallengeData, at: Int32(CFAbsoluteTimeGetCurrent())) {
                isLocked = true
            }
            
            var userInfo: [AnyHashable: Any]?
            let category: String
            let delay: Bool
            var threadIdentifier: String?
            switch requestId {
                case let .messageId(messageId):
                    if messageId.namespace == Namespaces.Message.Local {
                        delay = false
                    } else {
                        delay = true
                    }
                    userInfo = ["peerId": messageId.peerId.toInt64()]
                    threadIdentifier = "peer_\(messageId.peerId.toInt64())"
                    if messageId.peerId.namespace == Namespaces.Peer.CloudUser || messageId.peerId.namespace == Namespaces.Peer.CloudGroup {
                        category = "withReply"
                    } else {
                        category = "withMute"
                    }
                case let .globallyUniqueId(_, peerId):
                    delay = false
                    category = "secret"
                    if let peerId = peerId {
                        userInfo = ["peerId": peerId.toInt64()]
                        threadIdentifier = "peer_\(peerId.toInt64())"
                    }
            }
            
            if #available(iOS 10.0, *) {
                let content = UNMutableNotificationContent()
                if isLocked {
                    content.body = strings.PUSH_LOCKED_MESSAGE("").0
                } else {
                    if title.isEmpty {
                        content.body = text
                    } else {
                        content.body = "\(title): \(text)"
                    }
                }
                if let apnsSound = apnsSound {
                    if apnsSound == "0" {
                        content.sound = nil
                    } else {
                        content.sound = UNNotificationSound(named: processedSoundName(apnsSound))
                    }
                } else {
                    content.sound = UNNotificationSound(named: "0.m4a")
                }
                if let threadIdentifier = threadIdentifier {
                    content.threadIdentifier = threadIdentifier
                }

                content.categoryIdentifier = category
                if let userInfo = userInfo {
                    content.userInfo = userInfo
                }
                
                let request = UNNotificationRequest(identifier: notificationKey(requestId), content: content, trigger: delay ? UNTimeIntervalNotificationTrigger(timeInterval: 25.0, repeats: false) : nil)
                
                let center = UNUserNotificationCenter.current()
                Logger.shared.log("NotificationManager", "adding \(requestId), delay: \(delay)")
                center.add(request, withCompletionHandler: { error in
                    if let error = error {
                        Logger.shared.log("NotificationManager", "error adding \(requestId), delay: \(delay), error: \(String(describing: error))")
                    }
                })
                
                if delay {
                    notificationRequests[requestId] = CFAbsoluteTimeGetCurrent() + 25.0
                }
            } else {
                let notification = UILocalNotification()
                if isLocked {
                    notification.alertBody = strings.PUSH_LOCKED_MESSAGE("").0
                } else {
                    if #available(iOS 8.2, *) {
                        notification.alertTitle = title
                        notification.alertBody = text
                    } else {
                        if !title.isEmpty {
                            notification.alertBody = title + ": " + text
                        } else {
                            notification.alertBody = text
                        }
                    }
                }
                notification.category = category
                var updatedUserInfo = userInfo ?? [:]
                updatedUserInfo["id"] = notificationKey(requestId)
                notification.userInfo = updatedUserInfo
                if delay {
                    notification.fireDate = Date(timeIntervalSinceNow: 25.0)
                }
                if let apnsSound = apnsSound {
                    if apnsSound == "0" {
                        notification.soundName = nil
                    } else {
                        notification.soundName = processedSoundName(apnsSound)
                    }
                } else {
                    notification.soundName = "0.m4a"
                }
                UIApplication.shared.scheduleLocalNotification(notification)
                
                if delay {
                    notificationRequests[requestId] = CFAbsoluteTimeGetCurrent() + 25.0
                }
            }
        }
    }
    
    func commitRemoteNotification(originalRequestId: NotificationManagedNotificationRequestId?, messageIds: [MessageId]) -> Signal<Void, NoError> {
        if let context = self.context {
            return context.account.postbox.transaction { transaction -> ([(MessageId, [Message], Bool, PeerMessageSound, Bool)], Bool) in
                var isLocked = false
                if isAccessLocked(data: transaction.getAccessChallengeData(), at: Int32(CFAbsoluteTimeGetCurrent())) {
                    isLocked = true
                }
                
                var results: [(MessageId, [Message], Bool, PeerMessageSound, Bool)] = []
                var updatedMessageIds = messageIds
                if let originalRequestId = originalRequestId {
                    switch originalRequestId {
                        case let .messageId(id):
                            if !updatedMessageIds.contains(id) {
                                updatedMessageIds.append(id)
                            }
                        case .globallyUniqueId:
                            break
                    }
                }
                for id in updatedMessageIds {
                    let (messages, notify, sound, displayContents) = messagesForNotification(transaction: transaction, id: id, alwaysReturnMessage: true)
                    
                    if results.contains(where: { result in
                        return result.1.contains(where: { message in
                            return messages.contains(where: {
                                message.id == $0.id
                            })
                        })
                    }) {
                        continue
                    }
                    results.append((id, messages, notify, sound, displayContents))
                }
                return (results, isLocked)
            }
            |> deliverOnMainQueue
            |> beforeNext {
                [weak self] results, isLocked in
                if let strongSelf = self {
                    let delayUntilTimestamp: Int32 = strongSelf.context?.account.stateManager.getDelayNotificatonsUntil() ?? 0
                    
                    for (id, messages, notify, sound, displayContents) in results {
                        let requestId: NotificationManagedNotificationRequestId = .messageId(id)
                        if let message = messages.first, message.id.peerId.namespace != Namespaces.Peer.SecretChat, !strongSelf.processedRequestIds.contains(requestId) {
                            let notificationRequestTimeout = strongSelf.notificationRequests[requestId]
                            if notificationRequestTimeout == nil || CFAbsoluteTimeGetCurrent() < notificationRequestTimeout! {
                                if #available(iOS 10.0, *) {
                                    let center = UNUserNotificationCenter.current()
                                    center.removePendingNotificationRequests(withIdentifiers: [notificationKey(requestId)])
                                } else {
                                    let key = notificationKey(requestId)
                                    if let notifications = UIApplication.shared.scheduledLocalNotifications {
                                        for notification in notifications {
                                            if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                                                if id == key {
                                                    UIApplication.shared.cancelLocalNotification(notification)
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if !strongSelf.processedRequestIds.contains(requestId) {
                                    strongSelf.processedRequestIds.insert(requestId)
                                    
                                    if notify {
                                        var delayMessage = false
                                        if message.timestamp <= delayUntilTimestamp && message.id.peerId.namespace != Namespaces.Peer.SecretChat {
                                            delayMessage = true
                                        }
                                        strongSelf.processNotificationMessages([(messages, sound, displayContents, delayMessage)], isLocked: isLocked)
                                    }
                                }
                            }
                        }
                    }
                }
            } |> map { _ in
                return Void()
            }
        } else {
            return .complete()
        }
    }
    
    private func processNotificationMessages(_ messageList: [([Message], PeerMessageSound, Bool, Bool)], isLocked: Bool) {
        guard let context = self.context else {
            Logger.shared.log("NotificationManager", "context missing")
            return
        }
        let presentationData = (context.currentPresentationData.with { $0 })
        let strings = presentationData.strings
        let nameDisplayOrder = presentationData.nameDisplayOrder
        
        for (messages, sound, initialDisplayContents, delayMessage) in messageList {
            for message in messages {
                self.processedMessages.insert(message.id)
            }
            guard let firstMessage = messages.first else {
                continue
            }
            let displayContents = initialDisplayContents && !isLocked
            
            let requestId: NotificationManagedNotificationRequestId
            if let globallyUniqueId = firstMessage.globallyUniqueId, firstMessage.id.peerId.namespace == Namespaces.Peer.SecretChat {
                requestId = .globallyUniqueId(globallyUniqueId, firstMessage.id.peerId)
            } else {
                requestId = .messageId(firstMessage.id)
            }
            
            let notificationRequestTimeout = notificationRequests[requestId]
            
            if notificationRequestTimeout == nil || CFAbsoluteTimeGetCurrent() < notificationRequestTimeout! {
                if self.isApplicationInForeground {
                    processedRequestIds.insert(requestId)
                    if notificationRequestTimeout != nil {
                        if #available(iOS 10.0, *) {
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationKey(requestId)])
                        } else {
                            let key = notificationKey(requestId)
                            if let notifications = UIApplication.shared.scheduledLocalNotifications {
                                for notification in notifications {
                                    if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                                        if id == key {
                                            UIApplication.shared.cancelLocalNotification(notification)
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    var title: String?
                    var body: String
                    var mediaRepresentations: [TelegramMediaImageRepresentation]?
                    var mediaInfo: [String: Any]? = nil
                    
                    body = firstMessage.text
                    if let peer = messageMainPeer(firstMessage) {
                        var displayAuthor = true
                        if let channel = peer as? TelegramChannel {
                            switch channel.info {
                                case .group:
                                    displayAuthor = true
                                case .broadcast:
                                    displayAuthor = false
                            }
                        } else if let _ = peer as? TelegramUser {
                            displayAuthor = false
                        }
                        
                        if let author = firstMessage.author, displayAuthor {
                            title = author.compactDisplayTitle + "@" + peer.displayTitle
                        } else {
                            title = peer.displayTitle
                        }
                        
                        if messages.count > 1 {
                            if messages[0].forwardInfo != nil {
                                if let author = firstMessage.author, displayAuthor {
                                    let rawText = presentationData.strings.PUSH_CHAT_MESSAGE_FWDS(Int32(messages.count), peer.displayTitle, author.compactDisplayTitle, Int32(messages.count))
                                    if let index = rawText.firstIndex(of: "|") {
                                        title = String(rawText[rawText.startIndex ..< index])
                                        body = String(rawText[rawText.index(after: index)...])
                                    } else {
                                        title = nil
                                        body = rawText
                                    }
                                } else {
                                    let rawText = presentationData.strings.PUSH_MESSAGE_FWDS(Int32(messages.count), peer.displayTitle, Int32(messages.count))
                                    if let index = rawText.firstIndex(of: "|") {
                                        title = String(rawText[rawText.startIndex ..< index])
                                        body = String(rawText[rawText.index(after: index)...])
                                    } else {
                                        title = nil
                                        body = rawText
                                    }
                                }
                            } else if messages[0].groupingKey != nil {
                                var kind = messageContentKind(messages[0], strings: strings, nameDisplayOrder: nameDisplayOrder, accountPeerId: context.account.peerId).key
                                for i in 1 ..< messages.count {
                                    let nextKind = messageContentKind(messages[i], strings: strings, nameDisplayOrder: nameDisplayOrder, accountPeerId: context.account.peerId)
                                    if kind != nextKind.key {
                                        kind = .text
                                        break
                                    }
                                }
                                var isChannel = false
                                var isGroup = false
                                if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel {
                                    if case .broadcast = peer.info {
                                        isChannel = true
                                    } else {
                                        isGroup = true
                                    }
                                } else if firstMessage.id.peerId.namespace == Namespaces.Peer.CloudGroup {
                                    isGroup = true
                                }
                                title = nil
                                if isChannel {
                                    switch kind {
                                        case .image:
                                            let rawText = presentationData.strings.PUSH_CHANNEL_MESSAGE_PHOTOS(Int32(messages.count), peer.displayTitle, Int32(messages.count))
                                            if let index = rawText.firstIndex(of: "|") {
                                                title = String(rawText[rawText.startIndex ..< index])
                                                body = String(rawText[rawText.index(after: index)...])
                                            } else {
                                                title = nil
                                                body = rawText
                                            }
                                        default:
                                            let rawText = presentationData.strings.PUSH_CHANNEL_MESSAGES(Int32(messages.count), peer.displayTitle, Int32(messages.count))
                                            if let index = rawText.firstIndex(of: "|") {
                                                title = String(rawText[rawText.startIndex ..< index])
                                                body = String(rawText[rawText.index(after: index)...])
                                            } else {
                                                title = nil
                                                body = rawText
                                            }
                                    }
                                } else if isGroup, let author = firstMessage.author {
                                    switch kind {
                                        case .image:
                                            let rawText = presentationData.strings.PUSH_CHAT_MESSAGE_PHOTOS(Int32(messages.count), peer.displayTitle, author.compactDisplayTitle, Int32(messages.count))
                                            if let index = rawText.firstIndex(of: "|") {
                                                title = String(rawText[rawText.startIndex ..< index])
                                                body = String(rawText[rawText.index(after: index)...])
                                            } else {
                                                title = nil
                                                body = rawText
                                            }
                                        default:
                                            let rawText = presentationData.strings.PUSH_CHAT_MESSAGES(Int32(messages.count), peer.displayTitle, author.compactDisplayTitle, Int32(messages.count))
                                            if let index = rawText.firstIndex(of: "|") {
                                                title = String(rawText[rawText.startIndex ..< index])
                                                body = String(rawText[rawText.index(after: index)...])
                                            } else {
                                                title = nil
                                                body = rawText
                                            }
                                    }
                                } else {
                                    switch kind {
                                        case .image:
                                            let rawText = presentationData.strings.PUSH_MESSAGE_PHOTOS(Int32(messages.count), peer.displayTitle, Int32(messages.count))
                                            if let index = rawText.firstIndex(of: "|") {
                                                title = String(rawText[rawText.startIndex ..< index])
                                                body = String(rawText[rawText.index(after: index)...])
                                            } else {
                                                title = nil
                                                body = rawText
                                            }
                                        default:
                                            let rawText = presentationData.strings.PUSH_MESSAGES(Int32(messages.count), peer.displayTitle, Int32(messages.count))
                                            if let index = rawText.firstIndex(of: "|") {
                                                title = String(rawText[rawText.startIndex ..< index])
                                                body = String(rawText[rawText.index(after: index)...])
                                            } else {
                                                title = nil
                                                body = rawText
                                            }
                                    }
                                }
                            }
                        }
                    
                        if messages.count == 1 {
                            let additionalPeers = firstMessage.peers
                            var isPin = false
                            for media in messages[0].media {
                                if let action = media as? TelegramMediaAction {
                                    if case .pinnedMessageUpdated = action.action {
                                        isPin = true
                                    }
                                }
                            }
                            
                            if let channel = peer as? TelegramChannel, case .broadcast = channel.info, isPin {
                                title = nil
                            }
                            let chatPeer = RenderedPeer(peerId: firstMessage.id.peerId, peers: additionalPeers)
                            let (_, _, messageText) = chatListItemStrings(strings: strings, nameDisplayOrder: nameDisplayOrder, message: firstMessage, chatPeer: chatPeer, accountPeerId: context.account.peerId)
                            body = messageText
                            
                            loop: for media in firstMessage.media {
                                if let image = media as? TelegramMediaImage {
                                    mediaRepresentations = image.representations
                                    if !firstMessage.containsSecretMedia, let context = self.context, let smallest = smallestImageRepresentation(image.representations), let largest = largestImageRepresentation(image.representations) {
                                        var imageInfo: [String: Any] = [:]
                                        
                                        var thumbnailInfo: [String: Any] = [:]
                                        thumbnailInfo["path"] = context.account.postbox.mediaBox.resourcePath(smallest.resource)
                                        imageInfo["thumbnail"] = thumbnailInfo
                                        
                                        var fullSizeInfo: [String: Any] = [:]
                                        fullSizeInfo["path"] = context.account.postbox.mediaBox.resourcePath(largest.resource)
                                        imageInfo["fullSize"] = fullSizeInfo
                                        
                                        imageInfo["width"] = Int(largest.dimensions.width)
                                        imageInfo["height"] = Int(largest.dimensions.height)
                                        
                                        mediaInfo = ["image": imageInfo]
                                    }
                                    break loop
                                } else if let file = media as? TelegramMediaFile {
                                    if !firstMessage.containsSecretMedia {
                                        //mediaRepresentations = file.previewRepresentations
                                    }
                                    break loop
                                } else if let location = media as? TelegramMediaMap {
                                    if location.liveBroadcastingTimeout != nil {
                                        if let chatMainPeer = chatPeer.chatMainPeer {
                                            if let user = chatMainPeer as? TelegramUser {
                                                body = strings.PUSH_MESSAGE_GEOLIVE(user.displayTitle).0
                                            } else if let _ = chatMainPeer as? TelegramGroup, let author = firstMessage.author {
                                                body = strings.PUSH_MESSAGE_GEOLIVE(author.displayTitle).0
                                            } else if let channel = chatMainPeer as? TelegramChannel {
                                                switch channel.info {
                                                    case .group:
                                                        if let author = firstMessage.author {
                                                            body = strings.PUSH_MESSAGE_GEOLIVE(author.displayTitle).0
                                                        }
                                                    case .broadcast:
                                                         body = strings.PUSH_CHANNEL_MESSAGE_GEOLIVE(chatMainPeer.displayTitle).0
                                                }
                                            }
                                        }
                                        break loop
                                    }
                                }
                            }
                        }
                    } else {
                        body = strings.PUSH_ENCRYPTED_MESSAGE("").0
                    }
                    
                    if isLocked {
                        title = nil
                    }
                    if !displayContents {
                        body = strings.PUSH_ENCRYPTED_MESSAGE("").0
                    }
                    
                    var userInfo: [AnyHashable: Any] = ["peerId": firstMessage.id.peerId.toInt64()]
                    userInfo["messageId.namespace"] = firstMessage.id.namespace
                    userInfo["messageId.id"] = firstMessage.id.id
                    let category: String
                    if displayContents, let peer = firstMessage.peers[firstMessage.id.peerId] {
                        switch peer {
                            case _ as TelegramUser:
                                if let mediaInfo = mediaInfo {
                                    category = "withReplyMedia"
                                    userInfo["mediaInfo"] = mediaInfo
                                } else {
                                    category = "withReply"
                                }
                            case _ as TelegramGroup:
                                if let mediaInfo = mediaInfo {
                                    category = "withReplyMedia"
                                    userInfo["mediaInfo"] = mediaInfo
                                } else {
                                    category = "withReply"
                                }
                            case let channel as TelegramChannel:
                                if case .group = channel.info {
                                    if let mediaInfo = mediaInfo {
                                        category = "withReplyMedia"
                                        userInfo["mediaInfo"] = mediaInfo
                                    } else {
                                        category = "withReply"
                                    }
                                } else {
                                    if let mediaInfo = mediaInfo {
                                        category = "withMuteMedia"
                                        userInfo["mediaInfo"] = mediaInfo
                                    } else {
                                        category = "withMute"
                                    }
                                }
                            default:
                                category = "withMute"
                        }
                    } else {
                        category = "withMute"
                    }
                    
                    if #available(iOS 10.0, *) {
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationKey(requestId)])
                        
                        let content = UNMutableNotificationContent()
                        if let title = title {
                            content.title = title
                        }
                        content.body = body
                        switch sound {
                            case .none:
                                content.sound = nil
                            case .default:
                                content.sound = UNNotificationSound(named: "0.m4a")
                            default:
                                content.sound = UNNotificationSound(named: fileNameForNotificationSound(sound, defaultSound: nil) + ".m4a")
                        }
                        content.categoryIdentifier = category
                        content.userInfo = userInfo
                        
                        content.threadIdentifier = "peer_\(firstMessage.id.peerId.toInt64())"
                        
                        if mediaInfo != nil, let mediaRepresentations = mediaRepresentations {
                            if let context = self.context, let smallest = smallestImageRepresentation(mediaRepresentations) {
                                /*if let path = account.postbox.mediaBox.completedResourcePath(smallest.resource) {
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let tempPath = NSTemporaryDirectory() + "/\(randomId).jpg"
                                    if let _ = try? FileManager.default.copyItem(atPath: path, toPath: tempPath) {
                                        if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: tempPath)) {
                                            content.attachments = [attachment]
                                        }
                                    }
                                }*/
                            }
                        }
                        
                        var trigger: UNTimeIntervalNotificationTrigger?
                        if delayMessage {
                            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 25.0, repeats: false)
                        }
                        let request = UNNotificationRequest(identifier: notificationKey(requestId) + "_", content: content, trigger: trigger)
                        
                        let center = UNUserNotificationCenter.current()
                        Logger.shared.log("NotificationManager", "adding \(requestId), delay: \(delayMessage)")
                        center.add(request, withCompletionHandler: { error in
                            if let error = error {
                                Logger.shared.log("NotificationManager", "error adding \(requestId), delay: \(delayMessage), error: \(String(describing: error))")
                            }
                        })
                        processedRequestIds.insert(requestId)
                    } else {
                        let key = notificationKey(requestId)
                        if let notifications = UIApplication.shared.scheduledLocalNotifications {
                            for notification in notifications {
                                if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                                    if id == key {
                                        UIApplication.shared.cancelLocalNotification(notification)
                                        break
                                    }
                                }
                            }
                        }
                        
                        let notification = UILocalNotification()
                        if #available(iOS 10.0, *) {
                            notification.alertTitle = title
                            notification.alertBody = body
                        } else {
                            if let title = title {
                                notification.alertBody = title + ": " + body
                            } else {
                                notification.alertBody = body
                            }
                        }
                        notification.category = category
                        var updatedUserInfo = userInfo
                        updatedUserInfo["id"] = notificationKey(requestId) + "_"
                        notification.userInfo = userInfo
                        switch sound {
                            case .none:
                                notification.soundName = nil
                            case .default:
                                notification.soundName = "0.m4a"
                            default:
                                notification.soundName = fileNameForNotificationSound(sound, defaultSound: nil) + ".m4a"
                        }
                        
                        UIApplication.shared.presentLocalNotificationNow(notification)
                    }
                }
            } else {
                Logger.shared.log("NotificationManager", "not showing message because of timeout")
            }
            self.notificationRequests.removeValue(forKey: requestId)
        }
    }
    
    private var currentNotificationCall: (peer: Peer?, internalId: CallSessionInternalId)?
    
    private func updateNotificationCall(call: (peer: Peer?, internalId: CallSessionInternalId)?) {
        if let previousCall = currentNotificationCall {
            if #available(iOS 10.0, *) {
                let center = UNUserNotificationCenter.current()
                center.removeDeliveredNotifications(withIdentifiers: ["call_\(previousCall.internalId)"])
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let callId = userInfo["callId"] as? String, callId == String(describing: previousCall.internalId) {
                            UIApplication.shared.cancelLocalNotification(notification)
                        }
                    }
                }
            }
        }
        self.currentNotificationCall = call
        
        guard let context = self.context else {
            return
        }
        let presentationData = context.currentPresentationData.with { $0 }
        if let notificationCall = call {
            if #available(iOS 10.0, *) {
                let content = UNMutableNotificationContent()
                content.body = presentationData.strings.PUSH_PHONE_CALL_REQUEST(notificationCall.peer?.displayTitle ?? "").0
                content.sound = UNNotificationSound(named: "0.m4a")
                content.categoryIdentifier = "incomingCall"
                content.userInfo = [:]
                
                let request = UNNotificationRequest(identifier: "call_\(notificationCall.internalId)", content: content, trigger: nil)
                
                let center = UNUserNotificationCenter.current()
                Logger.shared.log("NotificationManager", "adding call \(notificationCall.internalId)")
                center.add(request, withCompletionHandler: { error in
                    if let error = error {
                        Logger.shared.log("NotificationManager", "error adding call \(notificationCall.internalId), error: \(String(describing: error))")
                    }
                })
                
            } else {
                let notification = UILocalNotification()
                notification.alertBody = presentationData.strings.PUSH_PHONE_CALL_REQUEST(notificationCall.peer?.displayTitle ?? "").0
                notification.category = "incomingCall"
                notification.userInfo = ["callId": String(describing: notificationCall.internalId)]
                notification.soundName = "0.m4a"
                UIApplication.shared.presentLocalNotificationNow(notification)
            }
        }
    }
    
    func presentWatchContinuityNotification(messageId: MessageId) {
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.removeDeliveredNotifications(withIdentifiers: ["watch"])
        } else {
            if let notifications = UIApplication.shared.scheduledLocalNotifications {
                for notification in notifications {
                    if let category = notification.category, category == "watch" {
                        UIApplication.shared.cancelLocalNotification(notification)
                    }
                }
            }
        }
        guard let context = self.context else {
            return
        }
        let presentationData = context.currentPresentationData.with { $0 }
       
        var userInfo: [AnyHashable : Any] = [:]
        userInfo["peerId"] = messageId.peerId.toInt64()
        userInfo["messageId.namespace"] = messageId.namespace
        userInfo["messageId.id"] = messageId.id
        
        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            content.body = presentationData.strings.WatchRemote_NotificationText
            content.sound = UNNotificationSound(named: "0.m4a")
            content.categoryIdentifier = "watch"
            content.userInfo = userInfo
            
            let request = UNNotificationRequest(identifier: "watch", content: content, trigger: nil)
            
            let center = UNUserNotificationCenter.current()
            Logger.shared.log("NotificationManager", "adding watch continuity")
            center.add(request, withCompletionHandler: { error in
                if let error = error {
                    Logger.shared.log("NotificationManager", "error adding watch continuity, error: \(String(describing: error))")
                }
            })
            
        } else {
            let notification = UILocalNotification()
            notification.alertBody = presentationData.strings.WatchRemote_NotificationText
            notification.category = "watch"
            notification.userInfo = userInfo
            notification.soundName = "0.m4a"
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
}
