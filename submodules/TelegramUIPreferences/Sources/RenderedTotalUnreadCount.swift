import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum RenderedTotalUnreadCountType {
    case raw
    case filtered
}

public func renderedTotalUnreadCount(inAppNotificationSettings: InAppNotificationSettings, transaction: Transaction) -> (Int32, RenderedTotalUnreadCountType) {
    let totalUnreadState = transaction.getTotalUnreadState(groupId: .root)
    return renderedTotalUnreadCount(inAppSettings: inAppNotificationSettings, totalUnreadState: totalUnreadState)
}

public func renderedTotalUnreadCount(inAppSettings: InAppNotificationSettings, totalUnreadState: ChatListTotalUnreadState) -> (Int32, RenderedTotalUnreadCountType) {
    let type: RenderedTotalUnreadCountType
    switch inAppSettings.totalUnreadCountDisplayStyle {
        case .filtered:
            type = .filtered
    }
    return (totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
}

public func getCurrentRenderedTotalUnreadCount(accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox) -> Signal<(Int32, RenderedTotalUnreadCountType), NoError> {
    let counters = postbox.transaction { transaction -> ChatListTotalUnreadState in
        return transaction.getTotalUnreadState(groupId: .root)
    }
    return combineLatest(
        accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        |> take(1),
        counters
    )
    |> map { sharedData, totalReadCounters -> (Int32, RenderedTotalUnreadCountType) in
        let inAppSettings: InAppNotificationSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) {
            inAppSettings = value
        } else {
            inAppSettings = .defaultSettings
        }
        let type: RenderedTotalUnreadCountType
        switch inAppSettings.totalUnreadCountDisplayStyle {
            case .filtered:
                type = .filtered
        }
        return (totalReadCounters.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
    }
}

public func renderedTotalUnreadCount(accountManager: AccountManager<TelegramAccountManagerTypes>, engine: TelegramEngine) -> Signal<(Int32, RenderedTotalUnreadCountType), NoError> {
    return combineLatest(
        accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings]),
        engine.data.subscribe(
            TelegramEngine.EngineData.Item.Messages.TotalReadCounters()
        )
    )
    |> map { sharedData, totalReadCounters -> (Int32, RenderedTotalUnreadCountType) in
        let inAppSettings: InAppNotificationSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) {
            inAppSettings = value
        } else {
            inAppSettings = .defaultSettings
        }
        let type: RenderedTotalUnreadCountType
        switch inAppSettings.totalUnreadCountDisplayStyle {
            case .filtered:
                type = .filtered
        }
        return (totalReadCounters.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs == rhs
    })
}
