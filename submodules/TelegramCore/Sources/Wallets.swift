import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi

public enum GetServerWalletSaltError {
    case generic
}

public func getServerWalletSalt(network: Network) -> Signal<Data, GetServerWalletSaltError> {
    return network.request(Api.functions.wallet.getKeySecretSalt(revoke: .boolFalse))
    |> mapError { _ -> GetServerWalletSaltError in
        return .generic
    }
    |> map { result -> Data in
        switch result {
        case let .secretSalt(salt):
            return salt.makeData()
        }
    }
}

public enum WalletProxyRequestError {
    case generic(Int32, String)
}

public func walletProxyRequest(network: Network, data: Data) -> Signal<Data, WalletProxyRequestError> {
    return network.request(Api.functions.wallet.sendLiteRequest(body: Buffer(data: data)))
    |> mapError { error -> WalletProxyRequestError in
        return .generic(error.errorCode, error.errorDescription)
    }
    |> map { result -> Data in
        switch result {
        case let .liteResponse(response):
            return response.makeData()
        }
    }
}
