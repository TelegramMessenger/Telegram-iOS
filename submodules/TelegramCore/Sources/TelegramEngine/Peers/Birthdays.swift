import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public final class TelegramBirthday: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case day
        case month
        case year
    }
    
    public let day: Int32
    public let month: Int32
    public let year: Int32?
    
    public init(day: Int32, month: Int32, year: Int32?) {
        self.day = day
        self.month = month
        self.year = year
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.day = try container.decode(Int32.self, forKey: .day)
        self.month = try container.decode(Int32.self, forKey: .month)
        self.year = try container.decodeIfPresent(Int32.self, forKey: .year)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.day, forKey: .day)
        try container.encode(self.month, forKey: .month)
        try container.encodeIfPresent(self.year, forKey: .year)
    }
    
    public static func ==(lhs: TelegramBirthday, rhs: TelegramBirthday) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.day != rhs.day {
            return false
        }
        if lhs.month != rhs.month {
            return false
        }
        if lhs.year != rhs.year {
            return false
        }
        
        return true
    }
}

extension TelegramBirthday {
    convenience init(apiBirthday: Api.Birthday) {
        switch apiBirthday {
        case let .birthday(_, day, month, year):
            self.init(
                day: day,
                month: month,
                year: year
            )
        }
    }
    
    var apiBirthday: Api.Birthday {
        var flags: Int32 = 0
        if let _ = self.year {
            flags |= (1 << 0)
        }
        return .birthday(flags: flags, day: self.day, month: self.month, year: self.year)
    }
}

public enum UpdateBirthdayError {
    case generic
    case flood
}

func _internal_updateBirthday(account: Account, birthday: TelegramBirthday?) -> Signal<Never, UpdateBirthdayError> {
    var flags: Int32 = 0
    if let _ = birthday {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.account.updateBirthday(flags: flags, birthday: birthday?.apiBirthday), automaticFloodWait: false)
    |> mapError { error -> UpdateBirthdayError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .flood
        } else {
            return .generic
        }
    }
    |> mapToSignal { result -> Signal<Never, UpdateBirthdayError> in
        return account.postbox.transaction { transaction -> Void in
            if case .boolTrue = result {
                transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
                    let current = current as? CachedUserData ?? CachedUserData()
                    return current.withUpdatedBirthday(birthday)
                })
            }
        }
        |> mapError { _ -> UpdateBirthdayError in }
        |> ignoreValues
    }
}

func managedContactBirthdays(stateManager: AccountStateManager) -> Signal<Never, NoError> {
    let poll = stateManager.network.request(Api.functions.contacts.getBirthdays())
    |> retryRequestIfNotFrozen
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let result else {
            return .complete()
        }
        return stateManager.postbox.transaction { transaction -> Void in
            if case let .contactBirthdays(contactBirthdays, users) = result {
                updatePeers(transaction: transaction, accountPeerId: stateManager.accountPeerId, peers: AccumulatedPeers(users: users))
                
                var birthdays: [EnginePeer.Id: TelegramBirthday] = [:]
                for contactBirthday in contactBirthdays {
                    if case let .contactBirthday(contactId, birthday) = contactBirthday {
                        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(contactId))
                        if peerId == stateManager.accountPeerId {
                            continue
                        }
                        birthdays[peerId] = TelegramBirthday(apiBirthday: birthday)
                    }
                }
                stateManager.modifyContactBirthdays({ _ in
                    return birthdays
                })
            }
        }
        |> ignoreValues
    }
    return (poll |> then(.complete() |> suspendAwareDelay(8.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
