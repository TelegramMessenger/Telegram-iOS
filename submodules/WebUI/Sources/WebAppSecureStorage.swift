import Foundation
import Security
import SwiftSignalKit
import TelegramCore
import AccountContext

final class WebAppSecureStorage {
    enum Error {
        case quotaExceeded
        case canRestore
        case storageNotEmpty
        case unknown
    }
    
    struct StorageValue: Codable {
          let timestamp: Int32
          let accountName: String
          let value: String
    }
    
    static private let maxKeyCount = 10
    
    private init() {
    }
    
    static private func keyPrefix(uuid: String, botId: EnginePeer.Id) -> String {
        return "WebBot\(UInt64(bitPattern: botId.toInt64()))U\(uuid)Key_"
    }
    
    static private func makeQuery(uuid: String, botId: EnginePeer.Id, key: String) -> [String: Any] {
        let identifier = self.keyPrefix(uuid: uuid, botId: botId) + key
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "TMASecureStorage"
        ]
    }
    
    static private func countKeys(uuid: String, botId: EnginePeer.Id) -> Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "TMASecureStorage",
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            let relevantPrefix = self.keyPrefix(uuid: uuid, botId: botId)
            let count = items.filter {
                if let account = $0[kSecAttrAccount as String] as? String {
                    return account.hasPrefix(relevantPrefix)
                }
                return false
            }.count
            return count
        }
        
        return 0
    }
    
    static func setValue(context: AccountContext, botId: EnginePeer.Id, key: String, value: String?) -> Signal<Never, WebAppSecureStorage.Error> {
        return combineLatest(
            context.engine.peers.secureBotStorageUuid(),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        )
        |> castError(WebAppSecureStorage.Error.self)
        |> mapToSignal { uuid, accountPeer in
            var query = makeQuery(uuid: uuid, botId: botId, key: key)
            guard let value else {
                let status = SecItemDelete(query as CFDictionary)
                if status == errSecSuccess || status == errSecItemNotFound {
                    return .complete()
                } else {
                    return .fail(.unknown)
                }
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let storageValue = StorageValue(
                timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970),
                accountName: accountPeer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "",
                value: value
            )
            
            guard let storageValueData = try? JSONEncoder().encode(storageValue) else {
                return .fail(.unknown)
            }
            
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            
            let status = SecItemCopyMatching(query as CFDictionary, nil)
            if status == errSecSuccess {
                let updateQuery: [String: Any] = [
                    kSecValueData as String: storageValueData
                ]
                let updateStatus = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)
                if updateStatus == errSecSuccess {
                    return .complete()
                } else {
                    return .fail(.unknown)
                }
            } else if status == errSecItemNotFound {
                let currentCount = countKeys(uuid: uuid, botId: botId)
                if currentCount >= maxKeyCount {
                    return .fail(.quotaExceeded)
                }
                
                query[kSecValueData as String] = storageValueData
                
                let createStatus = SecItemAdd(query as CFDictionary, nil)
                if createStatus == errSecSuccess {
                    return .complete()
                } else {
                    return .fail(.unknown)
                }
            } else {
                return .fail(.unknown)
            }
        }
    }
    
    static func getValue(context: AccountContext, botId: EnginePeer.Id, key: String) -> Signal<String?, WebAppSecureStorage.Error> {
        return context.engine.peers.secureBotStorageUuid()
        |> castError(WebAppSecureStorage.Error.self)
        |> mapToSignal { uuid in
            var query = makeQuery(uuid: uuid, botId: botId, key: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let storageValueData = result as? Data, let storageValue = try? JSONDecoder().decode(StorageValue.self, from: storageValueData) {
                return .single(storageValue.value)
            } else if status == errSecItemNotFound {
                return findRestorableKeys(context: context, botId: botId, key: key)
                |> castError(WebAppSecureStorage.Error.self)
                |> mapToSignal { restorableKeys in
                    if !restorableKeys.isEmpty {
                        return .fail(.canRestore)
                    } else {
                        return .single(nil)
                    }
                }
            } else {
                return .fail(.unknown)
            }
        }
    }
    
    static func checkRestoreAvailability(context: AccountContext, botId: EnginePeer.Id, key: String) -> Signal<[ExistingKey], WebAppSecureStorage.Error> {
        return context.engine.peers.secureBotStorageUuid()
        |> castError(WebAppSecureStorage.Error.self)
        |> mapToSignal { uuid in
            let currentCount = countKeys(uuid: uuid, botId: botId)
            guard currentCount == 0 else {
                return .fail(.storageNotEmpty)
            }
            return findRestorableKeys(context: context, botId: botId, key: key)
            |> castError(WebAppSecureStorage.Error.self)
        }
    }
    
    private static func findRestorableKeys(context: AccountContext, botId: EnginePeer.Id, key: String) -> Signal<[ExistingKey], NoError> {
        let storedKeys = getAllStoredKeys(botId: botId, key: key)
        guard !storedKeys.isEmpty else {
            return .single([])
        }
        return context.sharedContext.activeAccountContexts
        |> take(1)
        |> mapToSignal { _, accountContexts, _ in
            let signals = accountContexts.map { $0.1.engine.peers.secureBotStorageUuid() }
            return combineLatest(signals)
            |> map { activeUuids in
                let inactiveAccountKeys = storedKeys.filter { !activeUuids.contains($0.uuid) }
                return inactiveAccountKeys
            }
        }
    }
    
    static func transferAllValues(context: AccountContext, fromUuid: String, botId: EnginePeer.Id) -> Signal<Never, WebAppSecureStorage.Error> {
        return context.engine.peers.secureBotStorageUuid()
        |> castError(WebAppSecureStorage.Error.self)
        |> mapToSignal { toUuid in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "TMASecureStorage",
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true,
                kSecReturnData as String: true
            ]
                    
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let items = result as? [[String: Any]] {
                let fromPrefix = keyPrefix(uuid: fromUuid, botId: botId)
                let toPrefix = keyPrefix(uuid: toUuid, botId: botId)
                
                for item in items {
                    if let account = item[kSecAttrAccount as String] as? String, account.hasPrefix(fromPrefix), let data = item[kSecValueData as String] as? Data {
                        let keySuffix = account.dropFirst(fromPrefix.count)
                        let newKeyIdentifier = toPrefix + keySuffix
                        
                        let newKeyQuery: [String: Any] = [
                            kSecClass as String: kSecClassGenericPassword,
                            kSecAttrAccount as String: newKeyIdentifier,
                            kSecAttrService as String: "TMASecureStorage",
                            kSecValueData as String: data,
                            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
                        ]
                        
                        SecItemAdd(newKeyQuery as CFDictionary, nil)
                    }
                }
                return clearStorage(uuid: fromUuid, botId: botId)
            } else {
                return .complete()
            }
        }
    }
    
    struct ExistingKey: Equatable {
        let uuid: String
        let accountName: String
        let timestamp: Int32
    }
    
    private static func getAllStoredKeys(botId: EnginePeer.Id, key: String) -> [ExistingKey] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "TMASecureStorage",
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        var storedKeys: [ExistingKey] = []
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            let botIdString = "\(UInt64(bitPattern: botId.toInt64()))"
            
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String, account.contains("WebBot\(botIdString)U"), account.hasSuffix("Key_\(key)"), let valueData = item[kSecValueData as String] as? Data, let value = try? JSONDecoder().decode(StorageValue.self, from: valueData) {
                    if let range = account.range(of: "WebBot\(botIdString)U"), let endRange = account.range(of: "Key_\(key)") {
                        let startIndex = range.upperBound
                        let endIndex = endRange.lowerBound
                        let uuid = String(account[startIndex..<endIndex])
                        storedKeys.append(ExistingKey(
                            uuid: uuid,
                            accountName: value.accountName,
                            timestamp: value.timestamp
                        ))
                    }
                }
            }
        }
        
        return storedKeys
    }
    
    static func clearStorage(context: AccountContext, botId: EnginePeer.Id) -> Signal<Never, WebAppSecureStorage.Error> {
        return context.engine.peers.secureBotStorageUuid()
        |> castError(WebAppSecureStorage.Error.self)
        |> mapToSignal { uuid in
            return clearStorage(uuid: uuid, botId: botId)
        }
    }
    
    static func clearStorage(uuid: String, botId: EnginePeer.Id) -> Signal<Never, WebAppSecureStorage.Error> {
        let serviceQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "TMASecureStorage",
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(serviceQuery as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            let relevantPrefix = self.keyPrefix(uuid: uuid, botId: botId)
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String, account.hasPrefix(relevantPrefix) {
                    let deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrAccount as String: account,
                        kSecAttrService as String: "TMASecureStorage"
                    ]
                    
                    SecItemDelete(deleteQuery as CFDictionary)
                }
            }
        }
        return .complete()
    }
}
