import Foundation
import Postbox
import SwiftSignalKit

public func renderedTotalUnreadCount(postbox: Postbox) -> Signal<Int32, NoError> {
    let unreadCountsKey = PostboxViewKey.unreadCounts(items: [UnreadMessageCountsItem.total(.raw)])
    let inAppSettingsKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.inAppNotificationSettings]))
    return postbox.combinedView(keys: [unreadCountsKey, inAppSettingsKey])
    |> map { view -> Int32 in
        var value: Int32 = 0
        var style: TotalUnreadCountDisplayStyle = .filtered
        if let preferences = view.views[inAppSettingsKey] as? PreferencesView, let inAppSettings = preferences.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
            style = inAppSettings.totalUnreadCountDisplayStyle
        }
        if let unreadCounts = view.views[unreadCountsKey] as? UnreadMessageCountsView {
            switch style {
                case .raw:
                    value = unreadCounts.count(for: .total(.raw)) ?? 0
                case .filtered:
                    value = unreadCounts.count(for: .total(.filtered)) ?? 0
            }
        }
        return value
    }
    |> distinctUntilChanged
}
