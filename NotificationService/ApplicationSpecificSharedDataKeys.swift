import Foundation
import ValueBox

private func applicationSpecificSharedDataKey(_ value: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: value + 1000)
    return key
}

private enum ApplicationSpecificSharedDataKeyValues: Int32 {
    case inAppNotificationSettings = 0
}

public struct ApplicationSpecificSharedDataKeys {
    public static let inAppNotificationSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.inAppNotificationSettings.rawValue)
}
