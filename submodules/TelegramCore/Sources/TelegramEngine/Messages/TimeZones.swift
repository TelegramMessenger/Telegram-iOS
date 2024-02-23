import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public final class TimeZoneList: Codable, Equatable {
    public final class Item: Codable, Equatable {
        public let id: String
        public let title: String
        public let utcOffset: Int32

        public init(id: String, title: String, utcOffset: Int32) {
            self.id = id
            self.title = title
            self.utcOffset = utcOffset
        }

        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.utcOffset != rhs.utcOffset {
                return false
            }
            return true
        }
    }

    public let items: [Item]
    public let hashValue: Int32

    public init(items: [Item], hashValue: Int32) {
        self.items = items
        self.hashValue = hashValue
    }

    public static func ==(lhs: TimeZoneList, rhs: TimeZoneList) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hashValue != rhs.hashValue {
            return false
        }
        return true
    }
}

func _internal_cachedTimeZoneList(account: Account) -> Signal<TimeZoneList?, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.timezoneList()]))
    return account.postbox.combinedView(keys: [viewKey])
    |> map { views -> TimeZoneList? in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return nil
        }
        guard let value = view.values[PreferencesKeys.timezoneList()]?.get(TimeZoneList.self) else {
            return nil
        }
        return value
    }
}

func _internal_keepCachedTimeZoneListUpdated(account: Account) -> Signal<Never, NoError> {
    let updateSignal = _internal_cachedTimeZoneList(account: account)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        return account.network.request(Api.functions.help.getTimezonesList(hash: list?.hashValue ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.help.TimezonesList?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            
            return account.postbox.transaction { transaction in
                switch result {
                case let .timezonesList(timezones, hash):
                    var items: [TimeZoneList.Item] = []
                    for item in timezones {
                        switch item {
                        case let .timezone(id, name, utcOffset):
                            items.append(TimeZoneList.Item(id: id, title: name, utcOffset: utcOffset))
                        }
                    }
                    transaction.setPreferencesEntry(key: PreferencesKeys.timezoneList(), value: PreferencesEntry(TimeZoneList(items: items, hashValue: hash)))
                case .timezonesListNotModified:
                    break
                }
            }
            |> ignoreValues
        }
    }
    
    return updateSignal
}
