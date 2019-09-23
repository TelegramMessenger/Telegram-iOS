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

public struct TonKeychain {
    public let encrypt: (Data) -> Signal<Data?, NoError>
    public let decrypt: (Data) -> Signal<Data?, NoError>
    
    public init(encrypt: @escaping (Data) -> Signal<Data?, NoError>, decrypt: @escaping (Data) -> Signal<Data?, NoError>) {
        self.encrypt = encrypt
        self.decrypt = decrypt
    }
}

private final class TonInstanceImpl {
    private let queue: Queue
    private let basePath: String
    private let config: String
    private let network: Network
    private var instance: TON?
    
    init(queue: Queue, basePath: String, config: String, network: Network) {
        self.queue = queue
        self.basePath = basePath
        self.config = config
        self.network = network
    }
    
    func withInstance(_ f: (TON) -> Void) {
        let instance: TON
        if let current = self.instance {
            instance = current
        } else {
            let network = self.network
            instance = TON(keystoreDirectory: self.basePath + "/ton-keystore", config: self.config, performExternalRequest: { request in
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
    
    public init(basePath: String, config: String, network: Network) {
        self.queue = .mainQueue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return TonInstanceImpl(queue: queue, basePath: basePath, config: config, network: network)
        })
    }
    
    fileprivate func createWallet(keychain: TonKeychain, serverSalt: Data) -> Signal<(WalletInfo, [String]), NoError> {
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
                            guard let encryptedSecretData = encryptedSecretData else {
                                assertionFailure()
                                return
                            }
                            let cancel = ton.export(key, localPassword: serverSalt).start(next: { wordList in
                                guard let wordList = wordList as? [String] else {
                                    assertionFailure()
                                    return
                                }
                                subscriber.putNext((WalletInfo(publicKey: WalletPublicKey(rawValue: key.publicKey), encryptedSecret: EncryptedWalletSecret(rawValue: encryptedSecretData)), wordList))
                                subscriber.putCompletion()
                            })
                        }, error: { _ in
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
    
    fileprivate func importWallet(keychain: TonKeychain, wordList: [String], serverSalt: Data) -> Signal<WalletInfo, ImportWalletError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.importKey(withLocalPassword: serverSalt, mnemonicPassword: Data(), wordList: wordList).start(next: { key in
                        guard let key = key as? TONKey else {
                            subscriber.putError(.generic)
                            subscriber.putCompletion()
                            return
                        }
                        let cancel = keychain.encrypt(key.secret).start(next: { encryptedSecretData in
                            guard let encryptedSecretData = encryptedSecretData else {
                                subscriber.putError(.generic)
                                subscriber.putCompletion()
                                return
                            }
                            subscriber.putNext(WalletInfo(publicKey: WalletPublicKey(rawValue: key.publicKey), encryptedSecret: EncryptedWalletSecret(rawValue: encryptedSecretData)))
                            subscriber.putCompletion()
                        }, error: { _ in
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
    
    fileprivate func walletAddress(publicKey: WalletPublicKey) -> Signal<String, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getTestWalletAccountAddress(withPublicKey: publicKey.rawValue).start(next: { address in
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
    
    fileprivate func testGiverWalletAddress() -> Signal<String, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getTestGiverAddress().start(next: { address in
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
    
    fileprivate func walletBalance(publicKey: WalletPublicKey) -> Signal<WalletBalance, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getTestWalletAccountAddress(withPublicKey: publicKey.rawValue).start(next: { address in
                        guard let address = address as? String else {
                            return
                        }
                        let cancel = ton.getAccountState(withAddress: address).start(next: { state in
                            guard let state = state as? TONAccountState else {
                                return
                            }
                            subscriber.putNext(WalletBalance(rawValue: state.balance))
                        }, error: { _ in
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        disposable.set(ActionDisposable {
                            cancel?.dispose()
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
    
    fileprivate func getGramsFromTestGiver(address: String, amount: Int64) -> Signal<Void, GetGramsFromTestGiverError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                impl.withInstance { ton in
                    let cancel = ton.getTestGiverAccountState().start(next: { state in
                        guard let state = state as? TONAccountState else {
                            subscriber.putError(.generic)
                            return
                        }
                        let cancel = ton.testGiverSendGrams(with: state, accountAddress: address, amount: amount).start(next: { _ in
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: {
                            subscriber.putCompletion()
                        })
                        disposable.set(ActionDisposable {
                            cancel?.dispose()
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
    
    fileprivate func sendGramsFromWallet(keychain: TonKeychain, serverSalt: Data, walletInfo: WalletInfo, fromAddress: String, toAddress: String, amount: Int64) -> Signal<Never, SendGramsFromWalletError> {
        return keychain.decrypt(walletInfo.encryptedSecret.rawValue)
        |> introduceError(SendGramsFromWalletError.self)
        |> mapToSignal { decryptedSecret -> Signal<Never, SendGramsFromWalletError> in
            guard let decryptedSecret = decryptedSecret else {
                return .fail(.secretDecryptionFailed)
            }
            return Signal { subscriber in
                let disposable = MetaDisposable()
                
                self.impl.with { impl in
                    impl.withInstance { ton in
                        let cancel = ton.sendGrams(from: TONKey(publicKey: walletInfo.publicKey.rawValue, secret: decryptedSecret), localPassword: serverSalt, fromAddress: fromAddress, toAddress: toAddress, amount: amount).start(next: { _ in
                            preconditionFailure()
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
    
    fileprivate func walletRestoreWords(walletInfo: WalletInfo, keychain: TonKeychain, serverSalt: Data) -> Signal<[String], WalletRestoreWordsError> {
        return keychain.decrypt(walletInfo.encryptedSecret.rawValue)
        |> introduceError(WalletRestoreWordsError.self)
        |> mapToSignal { decryptedSecret -> Signal<[String], WalletRestoreWordsError> in
            guard let decryptedSecret = decryptedSecret else {
                return .fail(.secretDecryptionFailed)
            }
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
}

public struct WalletPublicKey: Hashable {
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct EncryptedWalletSecret: Hashable {
    public var rawValue: Data
    
    public init(rawValue: Data) {
        self.rawValue = rawValue
    }
}

public struct WalletInfo: PostboxCoding, Equatable {
    public let publicKey: WalletPublicKey
    public let encryptedSecret: EncryptedWalletSecret
    
    public init(publicKey: WalletPublicKey, encryptedSecret: EncryptedWalletSecret) {
        self.publicKey = publicKey
        self.encryptedSecret = encryptedSecret
    }
    
    public init(decoder: PostboxDecoder) {
        self.publicKey = WalletPublicKey(rawValue: decoder.decodeStringForKey("publicKey", orElse: ""))
        self.encryptedSecret = EncryptedWalletSecret(rawValue: decoder.decodeDataForKey("encryptedSecret")!)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.publicKey.rawValue, forKey: "publicKey")
        encoder.encodeData(self.encryptedSecret.rawValue, forKey: "encryptedSecret")
    }
}

public struct WalletCollection: PreferencesEntry {
    public var wallets: [WalletInfo]
    
    public init(wallets: [WalletInfo]) {
        self.wallets = wallets
    }
    
    public init(decoder: PostboxDecoder) {
        self.wallets = decoder.decodeObjectArrayWithDecoderForKey("wallets")
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
        |> introduceError(CreateWalletError.self)
        |> mapToSignal { walletInfo, wordList -> Signal<(WalletInfo, [String]), CreateWalletError> in
            return postbox.transaction { transaction -> (WalletInfo, [String]) in
                transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                    var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                    walletCollection.wallets = [walletInfo]
                    return walletCollection
                })
                return (walletInfo, wordList)
            }
            |> introduceError(CreateWalletError.self)
        }
    }
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
        |> mapToSignal { walletInfo -> Signal<WalletInfo, ImportWalletError> in
            return postbox.transaction { transaction -> WalletInfo in
                transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                    var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                    walletCollection.wallets = [walletInfo]
                    return walletCollection
                })
                return walletInfo
            }
            |> introduceError(ImportWalletError.self)
        }
    }
}

public func debugDeleteWallets(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
            var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
            walletCollection.wallets = []
            return walletCollection
        })
    }
    |> ignoreValues
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

public struct WalletBalance: Hashable {
    public var rawValue: Int64
    
    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }
}

public func walletAddress(publicKey: WalletPublicKey, tonInstance: TonInstance) -> Signal<String, NoError> {
    return tonInstance.walletAddress(publicKey: publicKey)
}

public func testGiverWalletAddress(tonInstance: TonInstance) -> Signal<String, NoError> {
    return tonInstance.testGiverWalletAddress()
}

public func currentWalletBalance(publicKey: WalletPublicKey, tonInstance: TonInstance) -> Signal<WalletBalance, NoError> {
    return tonInstance.walletBalance(publicKey: publicKey)
}

public enum GetGramsFromTestGiverError {
    case generic
}

public func getGramsFromTestGiver(address: String, amount: Int64, tonInstance: TonInstance) -> Signal<Void, GetGramsFromTestGiverError> {
    return tonInstance.getGramsFromTestGiver(address: address, amount: amount)
}

public enum SendGramsFromWalletError {
    case generic
    case secretDecryptionFailed
}

public func sendGramsFromWallet(network: Network, tonInstance: TonInstance, keychain: TonKeychain, walletInfo: WalletInfo, toAddress: String, amount: Int64) -> Signal<Never, SendGramsFromWalletError> {
    return getServerWalletSalt(network: network)
    |> mapError { _ -> SendGramsFromWalletError in
        return .generic
    }
    |> mapToSignal { serverSalt in
        return walletAddress(publicKey: walletInfo.publicKey, tonInstance: tonInstance)
        |> introduceError(SendGramsFromWalletError.self)
        |> mapToSignal { fromAddress in
            return tonInstance.sendGramsFromWallet(keychain: keychain, serverSalt: serverSalt, walletInfo: walletInfo, fromAddress: fromAddress, toAddress: toAddress, amount: amount)
        }
    }
}

public struct WalletTransactionId: Hashable {
    public var lt: Int64
    public var transactionHash: Data
}

private extension WalletTransactionId {
    init(tonTransactionId: TONTransactionId) {
        self.lt = tonTransactionId.lt
        self.transactionHash = tonTransactionId.transactionHash
    }
}

public final class WalletTransactionMessage: Equatable {
    public let value: Int64
    public let source: String
    public let destination: String
    
    init(value: Int64, source: String, destination: String) {
        self.value = value
        self.source = source
        self.destination = destination
    }
    
    public static func ==(lhs: WalletTransactionMessage, rhs: WalletTransactionMessage) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        if lhs.destination != rhs.destination {
            return false;
        }
        return true
    }
}

private extension WalletTransactionMessage {
    convenience init(tonTransactionMessage: TONTransactionMessage) {
        self.init(value: tonTransactionMessage.value, source: tonTransactionMessage.source, destination: tonTransactionMessage.destination)
    }
}

public final class WalletTransaction: Equatable {
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
    let previousIdValue: Signal<WalletTransactionId?, GetWalletTransactionsError>
    if let previousId = previousId {
        previousIdValue = .single(previousId)
    } else {
        previousIdValue = tonInstance.walletLastTransactionId(address: address)
        |> introduceError(GetWalletTransactionsError.self)
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
