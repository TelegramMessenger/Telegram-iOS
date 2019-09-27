import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi
#endif

public struct TonKeychainEncryptedData: Codable, Equatable {
    public let publicKey: Data
    public let data: Data
    
    public init(publicKey: Data, data: Data) {
        self.publicKey = publicKey
        self.data = data
    }
}

public enum TonKeychainEncryptDataError {
    case generic
}

public enum TonKeychainDecryptDataError {
    case generic
    case publicKeyMismatch
}

public struct TonKeychain {
    public let encryptionPublicKey: () -> Signal<Data?, NoError>
    public let encrypt: (Data) -> Signal<TonKeychainEncryptedData, TonKeychainEncryptDataError>
    public let decrypt: (TonKeychainEncryptedData) -> Signal<Data, TonKeychainDecryptDataError>
    
    public init(encryptionPublicKey: @escaping () -> Signal<Data?, NoError>, encrypt: @escaping (Data) -> Signal<TonKeychainEncryptedData, TonKeychainEncryptDataError>, decrypt: @escaping (TonKeychainEncryptedData) -> Signal<Data, TonKeychainDecryptDataError>) {
        self.encryptionPublicKey = encryptionPublicKey
        self.encrypt = encrypt
        self.decrypt = decrypt
    }
}

private final class TonInstanceImpl {
    private let queue: Queue
    private let basePath: String
    private let config: String
    private let blockchainName: String
    private let network: Network
    private var instance: TON?
    
    init(queue: Queue, basePath: String, config: String, blockchainName: String, network: Network) {
        self.queue = queue
        self.basePath = basePath
        self.config = config
        self.blockchainName = blockchainName
        self.network = network
    }
    
    func withInstance(_ f: (TON) -> Void) {
        let instance: TON
        if let current = self.instance {
            instance = current
        } else {
            let network = self.network
            instance = TON(keystoreDirectory: self.basePath + "/ton-keystore", config: self.config, blockchainName: self.blockchainName, performExternalRequest: { request in
                let _ = (network.request(Api.functions.wallet.sendLiteRequest(body: Buffer(data: request.data)))).start(next: { result in
                    switch result {
                    case let .liteResponse(response):
                        request.onResult(response.makeData(), nil)
                    }
                }, error: { error in
                    request.onResult(nil, error.errorDescription)
                })
            })
            self.instance = instance
        }
        f(instance)
    }
}

public final class TonInstance {
    private let queue: Queue
    private let impl: QueueLocalObject<TonInstanceImpl>
    
    public init(basePath: String, config: String, blockchainName: String, network: Network) {
        self.queue = .mainQueue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return TonInstanceImpl(queue: queue, basePath: basePath, config: config, blockchainName: blockchainName, network: network)
        })
    }
    
    fileprivate func exportKey(key: TONKey, serverSalt: Data) -> Signal<[String], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.export(key, localPassword: serverSalt).start(next: { wordList in
                        guard let wordList = wordList as? [String] else {
                            assertionFailure()
                            return
                        }
                        subscriber.putNext(wordList)
                        subscriber.putCompletion()
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    fileprivate func createWallet(keychain: TonKeychain, serverSalt: Data) -> Signal<(WalletInfo, [String]), CreateWalletError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.createKey(withLocalPassword: serverSalt, mnemonicPassword: Data()).start(next: { key in
                        guard let key = key as? TONKey else {
                            assertionFailure()
                            return
                        }
                        let cancel = keychain.encrypt(key.secret).start(next: { encryptedSecretData in
                            let _ = self.exportKey(key: key, serverSalt: serverSalt).start(next: { wordList in
                                subscriber.putNext((WalletInfo(publicKey: WalletPublicKey(rawValue: key.publicKey), encryptedSecret: encryptedSecretData), wordList))
                                subscriber.putCompletion()
                            }, error: { error in
                                subscriber.putError(.generic)
                            })
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: {
                        })
                    }, error: { _ in
                    }, completed: {
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    fileprivate func importWallet(keychain: TonKeychain, wordList: [String], serverSalt: Data) -> Signal<WalletInfo, ImportWalletInternalError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.importKey(withLocalPassword: serverSalt, mnemonicPassword: Data(), wordList: wordList).start(next: { key in
                        guard let key = key as? TONKey else {
                            subscriber.putError(.generic)
                            return
                        }
                        let cancel = keychain.encrypt(key.secret).start(next: { encryptedSecretData in
                            subscriber.putNext(WalletInfo(publicKey: WalletPublicKey(rawValue: key.publicKey), encryptedSecret: encryptedSecretData))
                            subscriber.putCompletion()
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: {
                        })
                    }, error: { _ in
                        subscriber.putError(.generic)
                    }, completed: {
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    fileprivate func walletAddress(publicKey: WalletPublicKey) -> Signal<String, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getWalletAccountAddress(withPublicKey: publicKey.rawValue).start(next: { address in
                        guard let address = address as? String else {
                            return
                        }
                        subscriber.putNext(address)
                        subscriber.putCompletion()
                    }, error: { _ in
                    }, completed: {
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    private func getWalletStateRaw(address: String) -> Signal<TONAccountState, GetWalletStateError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getAccountState(withAddress: address).start(next: { state in
                        guard let state = state as? TONAccountState else {
                            return
                        }
                        subscriber.putNext(state)
                    }, error: { _ in
                        subscriber.putError(.generic)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    fileprivate func getWalletState(address: String) -> Signal<(WalletState, Int64), GetWalletStateError> {
        return self.getWalletStateRaw(address: address)
        |> map { state in
            return (WalletState(balance: state.balance, lastTransactionId: state.lastTransactionId.flatMap(WalletTransactionId.init(tonTransactionId:))), state.syncUtime)
        }
    }
    
    fileprivate func walletLastTransactionId(address: String) -> Signal<WalletTransactionId?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getAccountState(withAddress: address).start(next: { state in
                        guard let state = state as? TONAccountState else {
                            subscriber.putNext(nil)
                            return
                        }
                        subscriber.putNext(state.lastTransactionId.flatMap(WalletTransactionId.init(tonTransactionId:)))
                    }, error: { _ in
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    fileprivate func getWalletTransactions(address: String, previousId: WalletTransactionId) -> Signal<[WalletTransaction], GetWalletTransactionsError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getTransactionList(withAddress: address, lt: previousId.lt, hash: previousId.transactionHash).start(next: { transactions in
                        guard let transactions = transactions as? [TONTransaction] else {
                            subscriber.putError(.generic)
                            return
                        }
                        subscriber.putNext(transactions.map(WalletTransaction.init(tonTransaction:)))
                    }, error: { _ in
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    disposable.set(ActionDisposable {
                        cancel?.dispose()
                    })
                }
            }
            
            return disposable
        }
    }
    
    fileprivate func sendGramsFromWallet(keychain: TonKeychain, serverSalt: Data, walletInfo: WalletInfo, fromAddress: String, toAddress: String, amount: Int64, textMessage: String, randomId: Int64) -> Signal<Never, SendGramsFromWalletError> {
        return keychain.decrypt(walletInfo.encryptedSecret)
        |> mapError { _ -> SendGramsFromWalletError in
            return .secretDecryptionFailed
        }
        |> mapToSignal { decryptedSecret -> Signal<Never, SendGramsFromWalletError> in
            let key = TONKey(publicKey: walletInfo.publicKey.rawValue, secret: decryptedSecret)
            return Signal { subscriber in
                let disposable = MetaDisposable()
                
                self.impl.with { impl in
                    impl.withInstance { ton in
                        let cancel = ton.sendGrams(from: key, localPassword: serverSalt, fromAddress: fromAddress, toAddress: toAddress, amount: amount, textMessage: textMessage, forceIfDestinationNotInitialized: true, timeout: 0, randomId: randomId).start(next: { result in
                            guard let result = result as? TONSendGramsResult else {
                                subscriber.putError(.generic)
                                return
                            }
                            subscriber.putCompletion()
                        }, error: { error in
                            if let error = error as? TONError {
                                if error.text == "Failed to parse account address" {
                                    subscriber.putError(.invalidAddress)
                                } else {
                                    subscriber.putError(.generic)
                                }
                            } else {
                                subscriber.putError(.generic)
                            }
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        disposable.set(ActionDisposable {
                            cancel?.dispose()
                        })
                    }
                }
                
                return disposable
            }
        }
    }
    
    fileprivate func walletRestoreWords(walletInfo: WalletInfo, keychain: TonKeychain, serverSalt: Data) -> Signal<[String], WalletRestoreWordsError> {
        return keychain.decrypt(walletInfo.encryptedSecret)
        |> mapError { _ -> WalletRestoreWordsError in
            return .secretDecryptionFailed
        }
        |> mapToSignal { decryptedSecret -> Signal<[String], WalletRestoreWordsError> in
            return Signal { subscriber in
                let disposable = MetaDisposable()
                
                self.impl.with { impl in
                    impl.withInstance { ton in
                        let cancel = ton.export(TONKey(publicKey: walletInfo.publicKey.rawValue, secret: decryptedSecret), localPassword: serverSalt).start(next: { wordList in
                            guard let wordList = wordList as? [String] else {
                                subscriber.putError(.generic)
                                return
                            }
                            subscriber.putNext(wordList)
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        disposable.set(ActionDisposable {
                            cancel?.dispose()
                        })
                    }
                }
                
                return disposable
            }
        }
    }
    
    fileprivate func deleteLocalWalletData(walletInfo: WalletInfo, keychain: TonKeychain, serverSalt: Data) -> Signal<Never, DeleteLocalWalletDataError> {
        return keychain.decrypt(walletInfo.encryptedSecret)
        |> mapError { _ -> DeleteLocalWalletDataError in
            return .secretDecryptionFailed
        }
        |> mapToSignal { decryptedSecret -> Signal<Never, DeleteLocalWalletDataError> in
            return Signal { subscriber in
                let disposable = MetaDisposable()
                
                self.impl.with { impl in
                    impl.withInstance { ton in
                        let cancel = ton.delete(TONKey(publicKey: walletInfo.publicKey.rawValue, secret: decryptedSecret)).start(next: { _ in
                            assertionFailure()
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        disposable.set(ActionDisposable {
                            cancel?.dispose()
                        })
                    }
                }
                
                return disposable
            }
        }
    }
}

public struct WalletPublicKey: Codable, Hashable {
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct WalletInfo: PostboxCoding, Codable, Equatable {
    public let publicKey: WalletPublicKey
    public let encryptedSecret: TonKeychainEncryptedData
    
    public init(publicKey: WalletPublicKey, encryptedSecret: TonKeychainEncryptedData) {
        self.publicKey = publicKey
        self.encryptedSecret = encryptedSecret
    }
    
    public init(decoder: PostboxDecoder) {
        self.publicKey = WalletPublicKey(rawValue: decoder.decodeStringForKey("publicKey", orElse: ""))
        if let publicKey = decoder.decodeDataForKey("encryptedSecretPublicKey"), let secret = decoder.decodeDataForKey("encryptedSecretData") {
            self.encryptedSecret = TonKeychainEncryptedData(publicKey: publicKey, data: secret)
        } else {
            self.encryptedSecret = TonKeychainEncryptedData(publicKey: Data(), data: Data())
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.publicKey.rawValue, forKey: "publicKey")
        encoder.encodeData(self.encryptedSecret.publicKey, forKey: "encryptedSecretPublicKey")
        encoder.encodeData(self.encryptedSecret.data, forKey: "encryptedSecretData")
    }
}

public struct CombinedWalletState: Codable, Equatable {
    public var walletState: WalletState
    public var timestamp: Int64
    public var topTransactions: [WalletTransaction]
}

public struct WalletStateRecord: PostboxCoding, Equatable {
    public let info: WalletInfo
    public var state: CombinedWalletState?
    
    public init(info: WalletInfo, state: CombinedWalletState?) {
        self.info = info
        self.state = state
    }
    
    public init(decoder: PostboxDecoder) {
        self.info = decoder.decodeDataForKey("info").flatMap { data in
            return try? JSONDecoder().decode(WalletInfo.self, from: data)
        } ?? WalletInfo(publicKey: WalletPublicKey(rawValue: ""), encryptedSecret: TonKeychainEncryptedData(publicKey: Data(), data: Data()))
        self.state = decoder.decodeDataForKey("state").flatMap { data in
            return try? JSONDecoder().decode(CombinedWalletState.self, from: data)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let data = try? JSONEncoder().encode(self.info) {
            encoder.encodeData(data, forKey: "info")
        }
        if let state = self.state, let data = try? JSONEncoder().encode(state) {
            encoder.encodeData(data, forKey: "state")
        } else {
            encoder.encodeNil(forKey: "state")
        }
    }
}

public struct WalletCollection: PreferencesEntry {
    public var wallets: [WalletStateRecord]
    
    public init(wallets: [WalletStateRecord]) {
        self.wallets = wallets
    }
    
    public init(decoder: PostboxDecoder) {
        var wallets: [WalletStateRecord] = decoder.decodeObjectArrayWithDecoderForKey("wallets")
        for i in (0 ..< wallets.count).reversed() {
            if wallets[i].info.publicKey.rawValue.isEmpty {
                wallets.remove(at: i)
            }
        }
        self.wallets = wallets
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.wallets, forKey: "wallets")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let other = to as? WalletCollection else {
            return false
        }
        if self.wallets != other.wallets {
            return false
        }
        return true
    }
}

public func availableWallets(postbox: Postbox) -> Signal<WalletCollection, NoError> {
    return postbox.transaction { transaction -> WalletCollection in
        return (transaction.getPreferencesEntry(key: PreferencesKeys.walletCollection) as? WalletCollection) ?? WalletCollection(wallets: [])
    }
}

public enum CreateWalletError {
    case generic
}

public func createWallet(postbox: Postbox, network: Network, tonInstance: TonInstance, keychain: TonKeychain) -> Signal<(WalletInfo, [String]), CreateWalletError> {
    return getServerWalletSalt(network: network)
    |> mapError { _ -> CreateWalletError in
        return .generic
    }
    |> mapToSignal { serverSalt -> Signal<(WalletInfo, [String]), CreateWalletError> in
        return tonInstance.createWallet(keychain: keychain, serverSalt: serverSalt)
        |> mapToSignal { walletInfo, wordList -> Signal<(WalletInfo, [String]), CreateWalletError> in
            return postbox.transaction { transaction -> (WalletInfo, [String]) in
                transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                    var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                    walletCollection.wallets = [WalletStateRecord(info: walletInfo, state: nil)]
                    return walletCollection
                })
                return (walletInfo, wordList)
            }
            |> castError(CreateWalletError.self)
        }
    }
}

private enum ImportWalletInternalError {
    case generic
}

public enum ImportWalletError {
    case generic
}

public func importWallet(postbox: Postbox, network: Network, tonInstance: TonInstance, keychain: TonKeychain, wordList: [String]) -> Signal<WalletInfo, ImportWalletError> {
    return getServerWalletSalt(network: network)
    |> mapError { _ -> ImportWalletError in
        return .generic
    }
    |> mapToSignal { serverSalt in
        return tonInstance.importWallet(keychain: keychain, wordList: wordList, serverSalt: serverSalt)
        |> `catch` { error -> Signal<WalletInfo, ImportWalletError> in
            switch error {
            case .generic:
                return .fail(.generic)
            }
        }
        |> mapToSignal { walletInfo -> Signal<WalletInfo, ImportWalletError> in
            return postbox.transaction { transaction -> WalletInfo in
                transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                    var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                    walletCollection.wallets = [WalletStateRecord(info: walletInfo, state: nil)]
                    return walletCollection
                })
                return walletInfo
            }
            |> castError(ImportWalletError.self)
        }
    }
}

public enum DeleteLocalWalletDataError {
    case generic
    case secretDecryptionFailed
}

public func deleteLocalWalletData(postbox: Postbox, network: Network, tonInstance: TonInstance, keychain: TonKeychain, walletInfo: WalletInfo) -> Signal<Never, DeleteLocalWalletDataError> {
    return getServerWalletSalt(network: network)
    |> mapError { _ -> DeleteLocalWalletDataError in
        return .generic
    }
    |> mapToSignal { serverSalt -> Signal<Never, DeleteLocalWalletDataError> in
        return tonInstance.deleteLocalWalletData(walletInfo: walletInfo, keychain: keychain, serverSalt: serverSalt)
        |> then(
            postbox.transaction { transaction -> Void in
                transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                    var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                    for i in 0 ..< walletCollection.wallets.count {
                        if walletCollection.wallets[i].info.publicKey == walletInfo.publicKey {
                            walletCollection.wallets.remove(at: i)
                            break
                        }
                    }
                    return walletCollection
                })
            }
            |> castError(DeleteLocalWalletDataError.self)
            |> ignoreValues
        )
    }
}

public enum WalletRestoreWordsError {
    case generic
    case secretDecryptionFailed
}

public func walletRestoreWords(network: Network, walletInfo: WalletInfo, tonInstance: TonInstance, keychain: TonKeychain) -> Signal<[String], WalletRestoreWordsError> {
    return getServerWalletSalt(network: network)
    |> mapError { _ -> WalletRestoreWordsError in
        return .generic
    }
    |> mapToSignal { serverSalt in
        return tonInstance.walletRestoreWords(walletInfo: walletInfo, keychain: keychain, serverSalt: serverSalt)
    }
}

public struct WalletState: Codable, Equatable {
    public let balance: Int64
    public let lastTransactionId: WalletTransactionId?
    
    public init(balance: Int64, lastTransactionId: WalletTransactionId?) {
        self.balance = balance
        self.lastTransactionId = lastTransactionId
    }
}

public func walletAddress(publicKey: WalletPublicKey, tonInstance: TonInstance) -> Signal<String, NoError> {
    return tonInstance.walletAddress(publicKey: publicKey)
}

private enum GetWalletStateError {
    case generic
}

private func getWalletState(address: String, tonInstance: TonInstance) -> Signal<(WalletState, Int64), GetWalletStateError> {
    return tonInstance.getWalletState(address: address)
}

public enum GetCombinedWalletStateError {
    case generic
}

public enum CombinedWalletStateResult {
    case cached(CombinedWalletState?)
    case updated(CombinedWalletState)
}

public func getCombinedWalletState(postbox: Postbox, walletInfo: WalletInfo, tonInstance: TonInstance) -> Signal<CombinedWalletStateResult, GetCombinedWalletStateError> {
    return postbox.transaction { transaction -> CombinedWalletState? in
        let walletCollection = (transaction.getPreferencesEntry(key: PreferencesKeys.walletCollection) as? WalletCollection) ?? WalletCollection(wallets: [])
        for item in walletCollection.wallets {
            if item.info.publicKey == walletInfo.publicKey {
                return item.state
            }
        }
        return nil
    }
    |> castError(GetCombinedWalletStateError.self)
    |> mapToSignal { cachedState -> Signal<CombinedWalletStateResult, GetCombinedWalletStateError> in
        return .single(.cached(cachedState))
        |> then(
            tonInstance.walletAddress(publicKey: walletInfo.publicKey)
            |> castError(GetCombinedWalletStateError.self)
            |> mapToSignal { address -> Signal<CombinedWalletStateResult, GetCombinedWalletStateError> in
                return getWalletState(address: address, tonInstance: tonInstance)
                |> mapError { _ -> GetCombinedWalletStateError in
                    return .generic
                }
                |> mapToSignal { walletState, syncUtime -> Signal<CombinedWalletStateResult, GetCombinedWalletStateError> in
                    let topTransactions: Signal<[WalletTransaction], GetCombinedWalletStateError>
                    if walletState.lastTransactionId == cachedState?.walletState.lastTransactionId {
                        topTransactions = .single(cachedState?.topTransactions ?? [])
                    } else {
                        topTransactions = getWalletTransactions(address: address, previousId: nil, tonInstance: tonInstance)
                        |> mapError { _ -> GetCombinedWalletStateError in
                            return .generic
                        }
                    }
                    return topTransactions
                    |> mapToSignal { topTransactions -> Signal<CombinedWalletStateResult, GetCombinedWalletStateError> in
                        let combinedState = CombinedWalletState(walletState: walletState, timestamp: syncUtime, topTransactions: topTransactions)
                        return postbox.transaction { transaction -> CombinedWalletStateResult in
                            transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                                var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                                for i in 0 ..< walletCollection.wallets.count {
                                    if walletCollection.wallets[i].info.publicKey == walletInfo.publicKey {
                                        walletCollection.wallets[i].state = combinedState
                                    }
                                }
                                return walletCollection
                            })
                            return .updated(combinedState)
                        }
                        |> castError(GetCombinedWalletStateError.self)
                    }
                }
            }
        )
    }
}

public enum SendGramsFromWalletError {
    case generic
    case secretDecryptionFailed
    case invalidAddress
}

public func sendGramsFromWallet(network: Network, tonInstance: TonInstance, keychain: TonKeychain, walletInfo: WalletInfo, toAddress: String, amount: Int64, textMessage: String, randomId: Int64) -> Signal<Never, SendGramsFromWalletError> {
    return getServerWalletSalt(network: network)
    |> mapError { _ -> SendGramsFromWalletError in
        return .generic
    }
    |> mapToSignal { serverSalt in
        return walletAddress(publicKey: walletInfo.publicKey, tonInstance: tonInstance)
        |> castError(SendGramsFromWalletError.self)
        |> mapToSignal { fromAddress in
            return tonInstance.sendGramsFromWallet(keychain: keychain, serverSalt: serverSalt, walletInfo: walletInfo, fromAddress: fromAddress, toAddress: toAddress, amount: amount, textMessage: textMessage, randomId: randomId)
        }
    }
}

public struct WalletTransactionId: Codable, Hashable {
    public var lt: Int64
    public var transactionHash: Data
}

private extension WalletTransactionId {
    init(tonTransactionId: TONTransactionId) {
        self.lt = tonTransactionId.lt
        self.transactionHash = tonTransactionId.transactionHash
    }
}

public final class WalletTransactionMessage: Codable, Equatable {
    public let value: Int64
    public let source: String
    public let destination: String
    public let textMessage: String
    
    init(value: Int64, source: String, destination: String, textMessage: String) {
        self.value = value
        self.source = source
        self.destination = destination
        self.textMessage = textMessage
    }
    
    public static func ==(lhs: WalletTransactionMessage, rhs: WalletTransactionMessage) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        if lhs.destination != rhs.destination {
            return false
        }
        if lhs.textMessage != rhs.textMessage {
            return false
        }
        return true
    }
}

private extension WalletTransactionMessage {
    convenience init(tonTransactionMessage: TONTransactionMessage) {
        self.init(value: tonTransactionMessage.value, source: tonTransactionMessage.source, destination: tonTransactionMessage.destination, textMessage: tonTransactionMessage.textMessage)
    }
}

public final class WalletTransaction: Codable, Equatable {
    public let data: Data
    public let transactionId: WalletTransactionId
    public let timestamp: Int64
    public let fee: Int64
    public let inMessage: WalletTransactionMessage?
    public let outMessages: [WalletTransactionMessage]
    
    public var transferredValue: Int64 {
        var value: Int64 = 0
        if let inMessage = self.inMessage {
            value += inMessage.value
        }
        for message in self.outMessages {
            value -= message.value
        }
        value -= self.fee
        return value
    }
    
    init(data: Data, transactionId: WalletTransactionId, timestamp: Int64, fee: Int64, inMessage: WalletTransactionMessage?, outMessages: [WalletTransactionMessage]) {
        self.data = data
        self.transactionId = transactionId
        self.timestamp = timestamp
        self.fee = fee
        self.inMessage = inMessage
        self.outMessages = outMessages
    }
    
    public static func ==(lhs: WalletTransaction, rhs: WalletTransaction) -> Bool {
        if lhs.data != rhs.data {
            return false
        }
        if lhs.transactionId != rhs.transactionId {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.fee != rhs.fee {
            return false
        }
        if lhs.inMessage != rhs.inMessage {
            return false
        }
        if lhs.outMessages != rhs.outMessages {
            return false
        }
        return true
    }
}

private extension WalletTransaction {
    convenience init(tonTransaction: TONTransaction) {
        self.init(data: tonTransaction.data, transactionId: WalletTransactionId(tonTransactionId: tonTransaction.transactionId), timestamp: tonTransaction.timestamp, fee: tonTransaction.fee, inMessage: tonTransaction.inMessage.flatMap(WalletTransactionMessage.init(tonTransactionMessage:)), outMessages: tonTransaction.outMessages.map(WalletTransactionMessage.init(tonTransactionMessage:)))
    }
}

public enum GetWalletTransactionsError {
    case generic
}

public func getWalletTransactions(address: String, previousId: WalletTransactionId?, tonInstance: TonInstance) -> Signal<[WalletTransaction], GetWalletTransactionsError> {
    return getWalletTransactionsOnce(address: address, previousId: previousId, tonInstance: tonInstance)
    |> mapToSignal { transactions in
        guard let lastTransaction = transactions.last, transactions.count >= 2 else {
            return .single(transactions)
        }
        return getWalletTransactionsOnce(address: address, previousId: lastTransaction.transactionId, tonInstance: tonInstance)
        |> map { additionalTransactions in
            var result = transactions
            var existingIds = Set(result.map { $0.transactionId })
            for transaction in additionalTransactions {
                if !existingIds.contains(transaction.transactionId) {
                    existingIds.insert(transaction.transactionId)
                    result.append(transaction)
                }
            }
            return result
        }
    }
}

private func getWalletTransactionsOnce(address: String, previousId: WalletTransactionId?, tonInstance: TonInstance) -> Signal<[WalletTransaction], GetWalletTransactionsError> {
    let previousIdValue: Signal<WalletTransactionId?, GetWalletTransactionsError>
    if let previousId = previousId {
        previousIdValue = .single(previousId)
    } else {
        previousIdValue = tonInstance.walletLastTransactionId(address: address)
        |> castError(GetWalletTransactionsError.self)
    }
    return previousIdValue
    |> mapToSignal { previousId in
        if let previousId = previousId {
            return tonInstance.getWalletTransactions(address: address, previousId: previousId)
        } else {
            return .single([])
        }
    }
}

public enum GetServerWalletSaltError {
    case generic
}

private func getServerWalletSalt(network: Network) -> Signal<Data, GetServerWalletSaltError> {
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
