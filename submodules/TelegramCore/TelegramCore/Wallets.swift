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
    private var instance: TON?
    
    init(queue: Queue, basePath: String, config: String) {
        self.queue = queue
        self.basePath = basePath
        self.config = config
    }
    
    func withInstance(_ f: (TON) -> Void) {
        let instance: TON
        if let current = self.instance {
            instance = current
        } else {
            instance = TON(keystoreDirectory: self.basePath + "/ton-keystore", config: self.config)
            self.instance = instance
        }
        f(instance)
    }
}

public final class TonInstance {
    private let queue: Queue
    private let impl: QueueLocalObject<TonInstanceImpl>
    
    public init(basePath: String, config: String) {
        self.queue = .mainQueue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return TonInstanceImpl(queue: queue, basePath: basePath, config: config)
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

public func currentWalletBalance(publicKey: WalletPublicKey, tonInstance: TonInstance) -> Signal<WalletBalance, NoError> {
    return tonInstance.walletBalance(publicKey: publicKey)
}

public enum GetServerWalletSaltError {
    case generic
}

private func getServerWalletSalt(network: Network) -> Signal<Data, GetServerWalletSaltError> {
    #if DEBUG
    return .single(Data())
    #endif
    
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
