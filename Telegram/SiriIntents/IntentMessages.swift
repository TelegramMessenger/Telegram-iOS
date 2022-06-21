import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import Intents

extension MessageId {
    init?(string: String) {
        let components = string.components(separatedBy: "_")
        if components.count == 3, let peerIdValue = Int64(components[0]), let namespaceValue = Int32(components[1]), let idValue = Int32(components[2]) {
            self.init(peerId: PeerId(peerIdValue), namespace: namespaceValue, id: idValue)
        } else {
            return nil
        }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func getMessages(account: Account, ids: [MessageId]) -> Signal<[INMessage], NoError> {
    return account.postbox.transaction { transaction -> [INMessage] in
        var messages: [INMessage] = []
        for id in ids {
            if let message = transaction.getMessage(id).flatMap(messageWithTelegramMessage) {
                messages.append(message)
            }
        }
        return messages.sorted { $0.dateSent!.compare($1.dateSent!) == .orderedDescending }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func unreadMessages(account: Account) -> Signal<[INMessage], NoError> {
    return account.postbox.tailChatListView(groupId: .root, count: 20, summaryComponents: ChatListEntrySummaryComponents())
    |> take(1)
    |> mapToSignal { view -> Signal<[INMessage], NoError> in
        var signals: [Signal<[INMessage], NoError>] = []
        for entry in view.0.entries {
            if case let .MessageEntry(index, _, readState, isMuted, _, _, _, _, _, _) = entry {
                if index.messageIndex.id.peerId.namespace != Namespaces.Peer.CloudUser {
                    continue
                }
                
                var hasUnread = false
                var fixedCombinedReadStates: MessageHistoryViewReadState?
                if let readState = readState {
                    hasUnread = readState.count != 0
                    fixedCombinedReadStates = .peer([index.messageIndex.id.peerId: readState])
                }
                
                if !isMuted && hasUnread {
                    signals.append(account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: index.messageIndex.id.peerId), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, count: 10, fixedCombinedReadStates: fixedCombinedReadStates, topTaggedMessageIdNamespaces: Set(), tagMask: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: .combinedLocation)
                    |> take(1)
                    |> map { view -> [INMessage] in
                        var messages: [INMessage] = []
                        for entry in view.0.entries {
                            var isRead = true
                            if let readState = readState {
                                isRead = readState.isIncomingMessageIndexRead(entry.message.index)
                            }
                            
                            if !isRead {
                                if let message = messageWithTelegramMessage(entry.message) {
                                    messages.append(message)
                                }
                            }
                        }
                        return messages
                    })
                }
            }
        }
        
        if signals.isEmpty {
            return .single([])
        } else {
            return combineLatest(signals)
            |> map { results -> [INMessage] in
                return results.flatMap { $0 }.sorted { $0.dateSent!.compare($1.dateSent!) == .orderedDescending }
            }
        }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
struct CallRecord {
    let identifier: String
    let date: Date
    let caller: INPerson
    let duration: Int32?
    let unseen: Bool
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    var intentCall: INCallRecord {
        return INCallRecord(identifier: self.identifier, dateCreated: self.date, caller: self.caller, callRecordType: .missed, callCapability: .audioCall, callDuration: self.duration.flatMap(Double.init), unseen: self.unseen)
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func missedCalls(account: Account) -> Signal<[CallRecord], NoError> {
    return account.viewTracker.callListView(type: .missed, index: MessageIndex.absoluteUpperBound(), count: 30)
    |> take(1)
    |> map { view -> [CallRecord] in
        var calls: [CallRecord] = []
        for entry in view.entries {
            switch entry {
                case let .message(_, messages):
                    for message in messages {
                        if let call = callWithTelegramMessage(message, account: account) {
                            calls.append(call)
                        }
                    }
                default:
                    break
            }
        }
        return calls.sorted { $0.date.compare($1.date) == .orderedDescending }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private func callWithTelegramMessage(_ telegramMessage: Message, account: Account) -> CallRecord? {
    guard let author = telegramMessage.author, let user = telegramMessage.peers[author.id] as? TelegramUser else {
        return nil
    }
    
    let identifier = "\(telegramMessage.id.peerId.toInt64())_\(telegramMessage.id.namespace)_\(telegramMessage.id.id)"
    let personHandle: INPersonHandle
    if #available(iOSApplicationExtension 10.2, iOS 10.2, *) {
        var type: INPersonHandleType
        var label: INPersonHandleLabel?
        if let username = user.username {
            label = INPersonHandleLabel(rawValue: "@\(username)")
            type = .unknown
        } else if let phone = user.phone {
            label = INPersonHandleLabel(rawValue: formatPhoneNumber(phone))
            type = .phoneNumber
        } else {
            label = nil
            type = .unknown
        }
        personHandle = INPersonHandle(value: user.phone ?? "", type: type, label: label)
    } else {
        personHandle = INPersonHandle(value: user.phone ?? "", type: .phoneNumber)
    }
    
    let caller = INPerson(personHandle: personHandle, nameComponents: nil, displayName: user.nameOrPhone, image: nil, contactIdentifier: nil, customIdentifier: "tg\(user.id.toInt64())")
    let date = Date(timeIntervalSince1970: TimeInterval(telegramMessage.timestamp))
    
    var duration: Int32?
    for media in telegramMessage.media {
        if let action = media as? TelegramMediaAction, case let .phoneCall(_, _, callDuration, _) = action.action {
            duration = callDuration
        }
    }
    
    return CallRecord(identifier: identifier, date: date, caller: caller, duration: duration, unseen: true)
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private func messageWithTelegramMessage(_ telegramMessage: Message) -> INMessage? {
    guard let author = telegramMessage.author, let user = telegramMessage.peers[author.id] as? TelegramUser, user.id.id._internalGetInt64Value() != 777000 else {
        return nil
    }
    
    let identifier = "\(telegramMessage.id.peerId.toInt64())_\(telegramMessage.id.namespace)_\(telegramMessage.id.id)"
    let personHandle: INPersonHandle
    if #available(iOSApplicationExtension 10.2, iOS 10.2, *) {
        var type: INPersonHandleType
        var label: INPersonHandleLabel?
        if let username = user.username {
            label = INPersonHandleLabel(rawValue: "@\(username)")
            type = .unknown
        } else if let phone = user.phone {
            label = INPersonHandleLabel(rawValue: formatPhoneNumber(phone))
            type = .phoneNumber
        } else {
            label = nil
            type = .unknown
        }
        personHandle = INPersonHandle(value: user.phone ?? "", type: type, label: label)
    } else {
        personHandle = INPersonHandle(value: user.phone ?? "", type: .phoneNumber)
    }
    
    let personIdentifier = "tg\(user.id.toInt64())"
    let sender = INPerson(personHandle: personHandle, nameComponents: nil, displayName: user.nameOrPhone, image: nil, contactIdentifier: personIdentifier, customIdentifier: personIdentifier)
    let date = Date(timeIntervalSince1970: TimeInterval(telegramMessage.timestamp))
    
    let message: INMessage
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
        var messageType: INMessageType = .text
        loop: for media in telegramMessage.media {
            if media is TelegramMediaImage {
                messageType = .mediaImage
                break loop
            }
            else if let file = media as? TelegramMediaFile {
                if file.isVideo {
                    messageType = .mediaVideo
                    break loop
                } else if file.isMusic {
                    messageType = .mediaAudio
                    break loop
                } else if file.isVoice {
                    messageType = .mediaAudio
                    break loop
                } else if file.isSticker || file.isAnimatedSticker {
                    messageType = .sticker
                    break loop
                } else if file.isAnimated {
                    messageType = .mediaVideo
                    break loop
                } else if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
                    messageType = .file
                    break loop
                }
            } else if media is TelegramMediaMap {
                messageType = .mediaLocation
                break loop
            } else if media is TelegramMediaContact {
                messageType = .mediaAddressCard
                break loop
            }
        }
        
        if telegramMessage.text.isEmpty && messageType == .text {
            return nil
        }
    
        message = INMessage(identifier: identifier, conversationIdentifier: "\(telegramMessage.id.peerId.toInt64())", content: telegramMessage.text, dateSent: date, sender: sender, recipients: [], groupName: nil, messageType: messageType)
    } else {
        if telegramMessage.text.isEmpty {
            return nil
        }
        message = INMessage(identifier: identifier, content: telegramMessage.text, dateSent: date, sender: sender, recipients: [])
    }
    
    return message
}
