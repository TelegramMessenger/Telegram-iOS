import Foundation
import SwiftSignalKit
import TelegramCore
import WalletBackupCrypto
import WalletEngineFFI

@available(macOS 10.15, *)
func withWalletBackupRotationRetry<Value>(
    now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    wait: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
    operation: (_ checkDeadline: @escaping () throws -> Void) async throws -> Value
) async throws -> Value {
    var deadline: TimeInterval?
    while true {
        do {
            try Task.checkCancellation()
            return try await operation {
                if let deadline, now() >= deadline {
                    throw WalletContext.WalletError.rotationNotFound
                }
            }
        } catch {
            guard error as? WalletContext.WalletError == .rotationNotFound
                || error as? TelegramCore.WalletOperationError == .rotationNotFound else { throw error }
            let currentTime = now()
            let retryDeadline = deadline ?? (currentTime + 30)
            deadline = retryDeadline
            guard currentTime + 3 < retryDeadline else { throw error }
            try await wait(3_000_000_000)
        }
    }
}

@available(macOS 10.15, *)
func encryptedWalletBackupParts(
    engine: TelegramEngine,
    words: [String]
) async throws -> [Data] {
    guard let secret = WalletPhraseCodec.encode(words: words) else {
        throw WalletContext.WalletError.invalidBackupData
    }
    let holders = try await WalletSignalRequestContext<[TelegramCore.WalletBackupHolder]>().run(
        engine.wallet.getBackupHolders()
    )
    guard let parts = WalletBackupCrypto.encryptSecretForBackup(
        secret,
        holderPublicKeys: holders.map(\.publicKey)
    ) else {
        throw WalletContext.WalletError.invalidBackupData
    }
    return parts
}

@available(macOS 10.15, *)
private func shouldRetryWalletPhraseExport(_ error: TelegramCore.WalletOperationError) -> Bool {
    switch error {
    case .network, .tokenInvalid, .tokenExpired, .clientKeyInvalid, .partUnavailable, .invalidBackupData:
        return true
    default:
        return false
    }
}

@available(macOS 10.15, *)
private func exportWalletSecretPhraseAttempt(
    engine: TelegramEngine,
    password: String?,
    expectedPublicKey: Data,
    retryFetchFailure: Bool
) -> Signal<[String], TelegramCore.WalletOperationError> {
    return engine.wallet.requestSecretPhraseExport(password: password)
    |> mapToSignal { phraseExport -> Signal<[String], TelegramCore.WalletOperationError> in
        guard let keyPair = WalletBackupCryptoKeyPair.generateKeyPair() else {
            return .fail(.invalidBackupData)
        }
        let datacenterIds = phraseExport.datacenterIds
        let fetch = combineLatest(
            engine.wallet.fetchEncryptedSecretPhrasePart(
                datacenterId: datacenterIds[0],
                token: phraseExport.token,
                publicKey: keyPair.publicKey
            ),
            engine.wallet.fetchEncryptedSecretPhrasePart(
                datacenterId: datacenterIds[1],
                token: phraseExport.token,
                publicKey: keyPair.publicKey
            ),
            engine.wallet.fetchEncryptedSecretPhrasePart(
                datacenterId: datacenterIds[2],
                token: phraseExport.token,
                publicKey: keyPair.publicKey
            )
        )
        |> mapToSignal { first, second, third -> Signal<[String], TelegramCore.WalletOperationError> in
            guard let secret = keyPair.decryptAndCombineBackupEnvelopes([first, second, third]),
                  let words = WalletPhraseCodec.decode(secret) else {
                return .fail(.invalidBackupData)
            }
            do {
                let publicKey = try walletMnemonicSigningPublicKey(words: words)
                guard expectedPublicKey.count == 32,
                      publicKey.count == 32,
                      Data(publicKey) == expectedPublicKey else {
                    return .fail(.invalidBackupData)
                }
            } catch {
                return .fail(.invalidBackupData)
            }
            return .single(words)
        }
        return fetch
        |> `catch` { error -> Signal<[String], TelegramCore.WalletOperationError> in
            guard retryFetchFailure, shouldRetryWalletPhraseExport(error) else {
                return .fail(error)
            }
            return exportWalletSecretPhraseAttempt(
                engine: engine,
                password: password,
                expectedPublicKey: expectedPublicKey,
                retryFetchFailure: false
            )
        }
    }
}

@available(macOS 10.15, *)
func exportWalletSecretPhrase(
    engine: TelegramEngine,
    password: String?,
    expectedPublicKey: Data
) async throws -> [String] {
    return try await WalletSignalRequestContext<[String]>().run(
        exportWalletSecretPhraseAttempt(
            engine: engine,
            password: password,
            expectedPublicKey: expectedPublicKey,
            retryFetchFailure: true
        )
    )
}

enum WalletPhraseCodec {
    private static let textLength = 215
    // Only the padded text is split; WalletBackupCrypto prefixes each share.
    static func encode(words: [String]) -> Data? {
        let words = words
        .flatMap { value in
            value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        }
        .map { $0.lowercased() }
        guard !words.isEmpty else {
            return nil
        }
        guard var text = words.joined(separator: " ").data(using: .utf8), text.count <= textLength else {
            return nil
        }
        text.append(Data(repeating: 0x20, count: textLength - text.count))
        return text
    }

    static func decode(_ data: Data) -> [String]? {
        guard data.count == textLength,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let words = value.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: { $0.isWhitespace })
        .map { String($0).lowercased() }
        guard !words.isEmpty, encode(words: words) == data else {
            return nil
        }
        return words
    }
}
