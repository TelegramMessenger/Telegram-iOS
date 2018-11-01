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
    return renderedTotalUnreadCount(inAppSettings: inAppSettings, totalUnreadState: totalUnreadState)
}

func renderedTotalUnreadCount(inAppSettings: InAppNotificationSettings, totalUnreadState: ChatListTotalUnreadState) -> (Int32, RenderedTotalUnreadCountType) {
    let type: RenderedTotalUnreadCountType
    switch inAppSettings.totalUnreadCountDisplayStyle {
        case .raw:
            type = .raw
        case .filtered:
            type = .filtered
    }
    return (totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
}

public func renderedTotalUnreadCount(postbox: Postbox) -> Signal<(Int32, RenderedTotalUnreadCountType), NoError> {
    let unreadCountsKey = PostboxViewKey.unreadCounts(items: [.total(nil)])
    let inAppSettingsKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.inAppNotificationSettings]))
    return postbox.combinedView(keys: [unreadCountsKey, inAppSettingsKey])
    |> map { view -> (Int32, RenderedTotalUnreadCountType) in
        let totalUnreadState: ChatListTotalUnreadState
        if let value = view.views[unreadCountsKey] as? UnreadMessageCountsView, let (_, total) = value.total() {
            totalUnreadState = total
        } else {
            totalUnreadState = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
        }
        
        let inAppSettings: InAppNotificationSettings
        if let preferences = view.views[inAppSettingsKey] as? PreferencesView, let value = preferences.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
            inAppSettings = value
        } else {
            inAppSettings = .defaultSettings
        }
        let type: RenderedTotalUnreadCountType
        switch inAppSettings.totalUnreadCountDisplayStyle {
            case .raw:
                type = .raw
            case .filtered:
                type = .filtered
        }
        return (totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs == rhs
    })
}
