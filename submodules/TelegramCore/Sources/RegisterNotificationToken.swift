import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

import SyncCore

public enum NotificationTokenType {
    case aps(encrypt: Bool)
    case voip
}

public func unregisterNotificationToken(account: Account, token: Data, type: NotificationTokenType, otherAccountUserIds: [Int32]) -> Signal<Never, NoError> {
    let mappedType: Int32
    switch type {
        case .aps:
            mappedType = 1
        case .voip:
            mappedType = 9
    }
    return account.network.request(Api.functions.account.unregisterDevice(tokenType: mappedType, token: hexString(token), otherUids: otherAccountUserIds))
    |> retryRequest
    |> ignoreValues
}

public func registerNotificationToken(account: Account, token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [Int32], excludeMutedChats: Bool) -> Signal<Never, NoError> {
    return masterNotificationsKey(account: account, ignoreDisabled: false)
    |> mapToSignal { masterKey -> Signal<Never, NoError> in
        let mappedType: Int32
        var keyData = Data()
        switch type {
            case let .aps(encrypt):
                mappedType = 1
                if encrypt {
                    keyData = masterKey.data
                }
            case .voip:
                mappedType = 9
                keyData = masterKey.data
        }
        var flags: Int32 = 0
        if excludeMutedChats {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.account.registerDevice(flags: flags, tokenType: mappedType, token: hexString(token), appSandbox: sandbox ? .boolTrue : .boolFalse, secret: Buffer(data: keyData), otherUids: otherAccountUserIds))
        |> retryRequest
        |> ignoreValues
    }
}
