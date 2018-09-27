import Foundation
import Postbox
import SwiftSignalKit

public enum RenderedTotalUnreadCountType {
    case raw
    case filtered
}

public func renderedTotalUnreadCount(transaction: Transaction) -> (Int32, RenderedTotalUnreadCountType) {
    let totalUnreadState = transaction.getTotalUnreadState()
    let inAppSettings: InAppNotificationSettings = (transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings) as? InAppNotificationSettings) ?? .defaultSettings
    switch inAppSettings.totalUnreadCountDisplayCategory {
        case .chats:
            switch inAppSettings.totalUnreadCountDisplayStyle {
                case .raw:
                    return (totalUnreadState.absoluteCounters.chatCount, .raw)
                case .filtered:
                    return (totalUnreadState.filteredCounters.chatCount, .filtered)
            }
        case .messages:
            switch inAppSettings.totalUnreadCountDisplayStyle {
                case .raw:
                    return (totalUnreadState.absoluteCounters.messageCount, .raw)
                case .filtered:
                    return (totalUnreadState.filteredCounters.messageCount, .filtered)
            }
    }
}

public func renderedTotalUnreadCount(postbox: Postbox) -> Signal<(Int32, RenderedTotalUnreadCountType), NoError> {
    let unreadCountsKey = PostboxViewKey.unreadCounts(items: [UnreadMessageCountsItem.total(.raw, .chats)])
    let inAppSettingsKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.inAppNotificationSettings]))
    return postbox.combinedView(keys: [unreadCountsKey, inAppSettingsKey])
    |> map { view -> (Int32, RenderedTotalUnreadCountType) in
        var value: Int32 = 0
        var style: TotalUnreadCountDisplayStyle = .filtered
        var categoryType: TotalUnreadCountDisplayCategory = .chats
        if let preferences = view.views[inAppSettingsKey] as? PreferencesView, let inAppSettings = preferences.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
            style = inAppSettings.totalUnreadCountDisplayStyle
            categoryType = inAppSettings.totalUnreadCountDisplayCategory
        }
        let type: RenderedTotalUnreadCountType
        let category: UnreadMessageCountsTotalCategory
        switch style {
            case .raw:
                type = .raw
            case .filtered:
                type = .filtered
        }
        switch categoryType {
            case .chats:
                category = .chats
            case .messages:
                category = .messages
        }
        if let unreadCounts = view.views[unreadCountsKey] as? UnreadMessageCountsView {
            switch style {
                case .raw:
                    value = unreadCounts.count(for: .total(.raw, category)) ?? 0
                case .filtered:
                    value = unreadCounts.count(for: .total(.filtered, category)) ?? 0
            }
        }
        return (value, type)
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs == rhs
    })
}
