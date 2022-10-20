import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum CreateSecretChatError {
    case generic
    case limitExceeded
}

func _internal_createSecretChat(account: Account, peerId: PeerId) -> Signal<PeerId, CreateSecretChatError> {
    return account.postbox.transaction { transaction -> Signal<PeerId, CreateSecretChatError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            return validatedEncryptionConfig(postbox: account.postbox, network: account.network)
                |> mapError { _ -> CreateSecretChatError in }
                |> mapToSignal { config -> Signal<PeerId, CreateSecretChatError> in
                    let aBytes = malloc(256)!
                    let _ = SecRandomCopyBytes(nil, 256, aBytes.assumingMemoryBound(to: UInt8.self))
                    let a = MemoryBuffer(memory: aBytes, capacity: 256, length: 256, freeWhenDone: true)
                    
                    var gValue: Int32 = config.g.byteSwapped
                    let g = Data(bytes: &gValue, count: 4)
                    let p = config.p.makeData()
                    
                    let aData = a.makeData()
                    let ga = MTExp(account.network.encryptionProvider, g, aData, p)!
                    
                    if !MTCheckIsSafeGAOrB(account.network.encryptionProvider, ga, p) {
                        return .fail(.generic)
                    }
                    
                    return account.network.request(Api.functions.messages.requestEncryption(userId: inputUser, randomId: Int32(bitPattern: arc4random()), gA: Buffer(data: ga)), automaticFloodWait: false)
                        |> mapError { error -> CreateSecretChatError in
                            if error.errorDescription.hasPrefix("FLOOD_WAIT_") {
                                return .limitExceeded
                            } else {
                                return .generic
                            }
                        }
                        |> mapToSignal { result -> Signal<PeerId, CreateSecretChatError> in
                            return account.postbox.transaction { transaction -> PeerId in
                                updateSecretChat(encryptionProvider: account.network.encryptionProvider, accountPeerId: account.peerId, transaction: transaction, mediaBox: account.postbox.mediaBox, chat: result, requestData: SecretChatRequestData(g: config.g, p: config.p, a: a))
                                
                                return result.peerId
                            } |> mapError { _ -> CreateSecretChatError in }
                        }
                }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> CreateSecretChatError in } |> switchToLatest
}
