import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func validatedEncryptionConfig(postbox: Postbox, network: Network) -> Signal<SecretChatEncryptionConfig, NoError> {
    return network.request(Api.functions.messages.getDhConfig(version: 0, randomLength: 0))
    |> retryRequest
    |> mapToSignal { result -> Signal<SecretChatEncryptionConfig, NoError> in
        switch result {
            case let .dhConfig(g, p, version, _):
                if !MTCheckIsSafeG(UInt32(g)) {
                    Logger.shared.log("SecretChatEncryptionConfig", "Invalid g")
                    return .complete()
                }
                
                if !MTCheckMod(network.encryptionProvider, p.makeData(), UInt32(g), network.context.keychain) {
                    Logger.shared.log("SecretChatEncryptionConfig", "Invalid p or g")
                    return .complete()
                }
                
                if !MTCheckIsSafePrime(network.encryptionProvider, p.makeData(), network.context.keychain) {
                    Logger.shared.log("SecretChatEncryptionConfig", "Invalid p")
                    return .never()
                }
                return .single(SecretChatEncryptionConfig(g: g, p: MemoryBuffer(p), version: version))
            case .dhConfigNotModified(_):
                assertionFailure()
                return .never()
        }
    }
}
