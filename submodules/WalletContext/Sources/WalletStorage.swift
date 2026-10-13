import Foundation
import Security
import PasscodeCore
import WalletEngineFFI

@available(macOS 10.15, *)
struct WalletEngineDescriptorRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let recordId: String
    let address: String
    let publicKey: Data
    let signingPublicKey: Data?
    let network: String
    let secretRef: String?

    init(descriptor: WalletDescriptor, signingPublicKey: Data? = nil) {
        self.schemaVersion = 2
        self.recordId = descriptor.recordId
        self.address = descriptor.address
        self.publicKey = descriptor.publicKey
        self.signingPublicKey = signingPublicKey
        self.network = descriptor.network == .mainnet ? "mainnet" : "testnet"
        self.secretRef = descriptor.secretRef.value
    }

    init(recordId: String, address: String, publicKey: Data, secretRef: String?, signingPublicKey: Data? = nil, network: String = "mainnet") {
        self.schemaVersion = 2
        self.recordId = recordId
        self.address = address
        self.publicKey = publicKey
        self.signingPublicKey = signingPublicKey
        self.network = network
        self.secretRef = secretRef
    }

    func withSigningPublicKey(_ value: Data) -> WalletEngineDescriptorRecord {
        WalletEngineDescriptorRecord(
            recordId: self.recordId, address: self.address, publicKey: self.publicKey,
            secretRef: self.secretRef, signingPublicKey: value, network: self.network
        )
    }

    var descriptor: WalletDescriptor? {
        guard self.schemaVersion == 2,
              !self.recordId.isEmpty,
              self.publicKey.count == 32,
              let secretRef = self.secretRef,
              !secretRef.isEmpty else {
            return nil
        }
        return WalletDescriptor(
            recordId: self.recordId,
            address: self.address,
            publicKey: self.publicKey,
            network: self.network == "testnet" ? .testnet : .mainnet,
            secretRef: ProtectedSecretRef(value: secretRef)
        )
    }
}

@available(macOS 10.15, *)
enum WalletEngineKeyRotationStoragePhase: String, Codable, Equatable, Sendable {
    case candidateStored
    case submissionStarted
    case chainApplied
    case backupDisabled
    case previousRestored
}

@available(macOS 10.15, *)
struct WalletEngineArchivedWalletRecord: Codable, Equatable, Sendable {
    let descriptor: WalletEngineDescriptorRecord
    var balance: Int64?
    let archivedAt: Int32
}

@available(macOS 10.15, *)
struct WalletEngineKeyRotationRecord: Codable, Equatable, Sendable {
    let operationId: String
    let recordId: String
    let walletAddress: String
    let walletPublicKey: Data
    let activeSecretRef: String
    let rollbackSecretRef: String
    let candidateSecretRef: String
    let previousPublicKey: Data
    let newPublicKey: Data
    let validUntil: UInt64
    var phase: WalletEngineKeyRotationStoragePhase
}

@available(macOS 10.15, *)
enum WalletEngineStorageError: Error, Equatable {
    case keychainStatus(Int32)
    case corrupted
}

@available(macOS 10.15, *)
actor WalletEngineStorage {
    private struct JournalDiskRecord: Codable {
        let version: UInt64
        let payload: Data
    }

    let namespace: String
    private let descriptorService: String
    private let secretService: String
    private let journalService: String

    static let descriptorServicePrefix = "org.telegram.ton-wallet.engine.v2.descriptor."
    static let journalServicePrefix = "org.telegram.ton-wallet.engine.v2.journal."

    init(namespace: String) {
        self.namespace = namespace
        self.descriptorService = Self.scoped(Self.descriptorServicePrefix + namespace)
        self.secretService = Self.scoped(WalletVault.service(namespace: namespace))
        self.journalService = Self.scoped(Self.journalServicePrefix + namespace)
    }

    private static func scoped(_ service: String) -> String {
        #if os(macOS)
        return PasscodeKeychainScope.service(service)
        #else
        return service
        #endif
    }

    func loadDescriptor() throws -> WalletEngineDescriptorRecord? {
        try self.readCodable(service: self.descriptorService, account: "wallet")
    }

    func saveDescriptor(_ descriptor: WalletEngineDescriptorRecord) throws {
        try self.writeCodable(descriptor, service: self.descriptorService, account: "wallet")
    }

    func loadTransferSubmissions() throws -> [WalletTransferSubmissionRecord] {
        try self.readCodable(service: self.descriptorService, account: "transfer-submissions") ?? []
    }

    func saveTransferSubmission(_ record: WalletTransferSubmissionRecord) throws {
        var records = try self.loadTransferSubmissions().filter {
            $0.recordId != record.recordId && !walletEngineAddressesEqual($0.walletAddress, record.walletAddress)
        }
        records.append(record)
        try self.writeCodable(records, service: self.descriptorService, account: "transfer-submissions")
    }

    func resolveTransferSubmission(operationId: String, resolution: WalletTransferSubmissionRecord.Resolution) throws {
        var records = try self.loadTransferSubmissions()
        guard let index = records.firstIndex(where: { $0.operationId == operationId }),
              records[index].resolution != resolution,
              records[index].resolution == .pending || resolution == .consumed else { return }
        records[index].resolution = resolution
        try self.writeCodable(records, service: self.descriptorService, account: "transfer-submissions")
    }

    func loadArchivedWallets() throws -> [WalletEngineArchivedWalletRecord] {
        try self.readCodable(service: self.descriptorService, account: "archived-wallets") ?? []
    }

    func archiveWallet(_ descriptor: WalletEngineDescriptorRecord, balance: Int64?, archivedAt: Int32) throws {
        guard let secretRef = descriptor.secretRef, !secretRef.isEmpty,
              try self.containsProtectedSecret(ProtectedSecretRef(value: secretRef)) else {
            throw WalletEngineStorageError.corrupted
        }
        var records = try self.loadArchivedWallets().filter { $0.descriptor.recordId != descriptor.recordId }
        records.append(WalletEngineArchivedWalletRecord(
            descriptor: descriptor,
            balance: balance,
            archivedAt: archivedAt
        ))
        records.sort { $0.archivedAt > $1.archivedAt }
        try self.writeCodable(records, service: self.descriptorService, account: "archived-wallets")
    }

    func availableArchivedWallets() throws -> [WalletEngineArchivedWalletRecord] {
        try self.loadArchivedWallets().filter {
            guard let secretRef = $0.descriptor.secretRef, !secretRef.isEmpty else { return false }
            return (try? self.containsProtectedSecret(ProtectedSecretRef(value: secretRef))) == true
        }
    }

    func updateArchivedWalletBalances(_ balances: [String: Int64]) throws {
        try Task.checkCancellation()
        guard !balances.isEmpty else { return }
        var records = try self.loadArchivedWallets()
        var changed = false
        for index in records.indices {
            if let balance = balances[records[index].descriptor.address], records[index].balance != balance {
                records[index].balance = balance
                changed = true
            }
        }
        if changed {
            try self.writeCodable(records, service: self.descriptorService, account: "archived-wallets")
        }
    }

    func removeArchivedWallet(recordId: String) throws {
        let records = try self.loadArchivedWallets()
        guard let record = records.first(where: { $0.descriptor.recordId == recordId }) else {
            return
        }
        try self.writeCodable(
            records.filter { $0.descriptor.recordId != recordId },
            service: self.descriptorService,
            account: "archived-wallets"
        )
        if let secretRef = record.descriptor.secretRef, !secretRef.isEmpty {
            try self.deleteProtectedSecret(ProtectedSecretRef(value: secretRef))
        }
    }

    func removeArchivedWallets() throws {
        for record in try self.loadArchivedWallets() {
            if let secretRef = record.descriptor.secretRef, !secretRef.isEmpty {
                try self.deleteProtectedSecret(ProtectedSecretRef(value: secretRef))
            }
        }
        try self.remove(service: self.descriptorService, account: "archived-wallets")
    }

    func loadReplacementCandidate() throws -> WalletEngineDescriptorRecord? {
        try self.readCodable(service: self.descriptorService, account: "replacement-candidate")
    }

    func saveReplacementCandidate(_ descriptor: WalletEngineDescriptorRecord) throws {
        try self.writeCodable(descriptor, service: self.descriptorService, account: "replacement-candidate")
    }

    func installReplacementCandidate(
        _ descriptor: WalletEngineDescriptorRecord,
        secret: Data
    ) throws {
        guard let secretRef = descriptor.secretRef,
              !secretRef.isEmpty,
              !secret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        if let existing = try self.loadReplacementCandidate(), existing != descriptor {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(WalletVault.encrypt(secret, namespace: self.namespace), service: self.secretService, account: secretRef)
        do {
            try self.saveReplacementCandidate(descriptor)
        } catch let saveError {
            do {
                try self.remove(service: self.secretService, account: secretRef)
            } catch let cleanupError {
                throw cleanupError
            }
            throw saveError
        }
    }

    func removeReplacementCandidate() throws {
        try self.remove(service: self.descriptorService, account: "replacement-candidate")
    }

    func discardReplacementCandidate(recordId: String) throws {
        try discardWalletReplacementCandidate(
            recordId: recordId,
            loadCandidate: { try self.loadReplacementCandidate() },
            isSecretReferenced: { secretRef in
                try walletReplacementSecretIsReferenced(secretRef, active: self.loadDescriptor(), archived: self.loadArchivedWallets(), rotation: self.loadKeyRotation())
            },
            deleteSecret: { try self.deleteProtectedSecret(ProtectedSecretRef(value: $0)) },
            removeCandidate: { try self.removeReplacementCandidate() }
        )
    }

    func loadKeyRotation() throws -> WalletEngineKeyRotationRecord? {
        try self.readCodable(service: self.descriptorService, account: "key-rotation")
    }

    func installKeyRotationCandidate(
        operationId: String,
        descriptor: WalletEngineDescriptorRecord,
        previousPublicKey: Data,
        newPublicKey: Data,
        validUntil: UInt64,
        candidateSecret: Data
    ) throws -> WalletEngineKeyRotationRecord {
        guard !operationId.isEmpty,
              previousPublicKey.count == 32,
              newPublicKey.count == 32,
              !candidateSecret.isEmpty,
              let activeSecretRef = descriptor.secretRef,
              !activeSecretRef.isEmpty,
              let currentSecret = try self.read(service: self.secretService, account: activeSecretRef),
              !currentSecret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        if let current = try self.loadKeyRotation() {
            guard current.operationId == operationId,
                  current.recordId == descriptor.recordId,
                  current.walletAddress == descriptor.address,
                  current.walletPublicKey == descriptor.publicKey,
                  current.previousPublicKey == previousPublicKey,
                  current.newPublicKey == newPublicKey,
                  current.validUntil == validUntil else {
                throw WalletEngineStorageError.corrupted
            }
            return current
        }

        let rollbackSecretRef = "wallet:\(descriptor.recordId):key-rotation-rollback:\(operationId)"
        let candidateSecretRef = "wallet:\(descriptor.recordId):key-rotation-candidate:\(operationId)"
        try self.write(currentSecret, service: self.secretService, account: rollbackSecretRef)
        try self.write(WalletVault.encrypt(candidateSecret, namespace: self.namespace), service: self.secretService, account: candidateSecretRef)
        let record = WalletEngineKeyRotationRecord(
            operationId: operationId,
            recordId: descriptor.recordId,
            walletAddress: descriptor.address,
            walletPublicKey: descriptor.publicKey,
            activeSecretRef: activeSecretRef,
            rollbackSecretRef: rollbackSecretRef,
            candidateSecretRef: candidateSecretRef,
            previousPublicKey: previousPublicKey,
            newPublicKey: newPublicKey,
            validUntil: validUntil,
            phase: .candidateStored
        )
        try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        return record
    }

    func markKeyRotationSubmissionStarted(operationId: String) throws -> WalletEngineKeyRotationRecord {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId else {
            throw WalletEngineStorageError.corrupted
        }
        if record.phase == .candidateStored {
            record.phase = .submissionStarted
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        } else if record.phase != .submissionStarted {
            throw WalletEngineStorageError.corrupted
        }
        return record
    }

    func keyRotationCandidateSecret(operationId: String) throws -> Data {
        guard let record = try self.loadKeyRotation(), record.operationId == operationId,
              let candidate = try self.read(service: self.secretService, account: record.candidateSecretRef),
              !candidate.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        return try WalletVault.decrypt(candidate, namespace: self.namespace)
    }

    func markKeyRotationChainApplied(
        operationId: String,
        verifiedPublicKey: Data
    ) throws -> WalletEngineKeyRotationRecord {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId else {
            throw WalletEngineStorageError.corrupted
        }
        guard verifiedPublicKey == record.newPublicKey,
              (record.phase == .submissionStarted || record.phase == .chainApplied || record.phase == .backupDisabled) else {
            throw WalletEngineStorageError.corrupted
        }
        if record.phase == .backupDisabled {
            guard let activeSecret = try self.read(service: self.secretService, account: record.activeSecretRef),
                  !activeSecret.isEmpty else {
                throw WalletEngineStorageError.corrupted
            }
            try self.updateKeyRotationSigningPublicKey(record, publicKey: record.newPublicKey)
            return record
        }
        guard let candidate = try self.read(service: self.secretService, account: record.candidateSecretRef),
              !candidate.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(candidate, service: self.secretService, account: record.activeSecretRef)
        try self.updateKeyRotationSigningPublicKey(record, publicKey: record.newPublicKey)
        if record.phase == .submissionStarted {
            record.phase = .chainApplied
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        }
        return record
    }

    func restorePreviousKeyRotationSecret(
        operationId: String,
        verifiedPublicKey: Data,
        removeRecord: Bool
    ) throws {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId,
              record.previousPublicKey == verifiedPublicKey,
              let previousSecret = try self.read(service: self.secretService, account: record.rollbackSecretRef),
              !previousSecret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(previousSecret, service: self.secretService, account: record.activeSecretRef)
        try self.updateKeyRotationSigningPublicKey(record, publicKey: record.previousPublicKey)
        if removeRecord {
            record.phase = .previousRestored
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
            try self.cleanupRestoredKeyRotation(operationId: operationId)
        } else if record.phase == .chainApplied {
            record.phase = .submissionStarted
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        }
    }

    func discardUnsubmittedKeyRotation(operationId: String) throws {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId else {
            return
        }
        guard record.phase == .candidateStored,
              let previousSecret = try self.read(service: self.secretService, account: record.rollbackSecretRef),
              !previousSecret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(previousSecret, service: self.secretService, account: record.activeSecretRef)
        try self.updateKeyRotationSigningPublicKey(record, publicKey: record.previousPublicKey)
        record.phase = .previousRestored
        try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        try self.cleanupRestoredKeyRotation(operationId: operationId)
    }

    func cleanupRestoredKeyRotation(operationId: String) throws {
        guard let record = try self.loadKeyRotation() else {
            return
        }
        guard record.operationId == operationId, record.phase == .previousRestored else {
            throw WalletEngineStorageError.corrupted
        }
        try self.removeKeyRotation(record)
    }

    func completeKeyRotation(operationId: String) throws {
        guard var record = try self.loadKeyRotation() else {
            return
        }
        guard record.operationId == operationId,
              (record.phase == .chainApplied || record.phase == .backupDisabled) else {
            throw WalletEngineStorageError.corrupted
        }
        if record.phase == .chainApplied {
            record.phase = .backupDisabled
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        }
        try self.removeKeyRotation(record)
    }

    func discardOrphanedKeyRotation(operationId: String, activeSecretRef: String?) throws {
        guard let record = try self.loadKeyRotation(), record.operationId == operationId else {
            return
        }
        let descriptor = try self.loadDescriptor()
        guard record.recordId != descriptor?.recordId,
              record.activeSecretRef != activeSecretRef else {
            throw WalletEngineStorageError.corrupted
        }
        try self.removeKeyRotation(record)
    }

    private func removeKeyRotation(_ record: WalletEngineKeyRotationRecord) throws {
        try self.remove(service: self.secretService, account: record.candidateSecretRef)
        try self.remove(service: self.secretService, account: record.rollbackSecretRef)
        try self.remove(service: self.descriptorService, account: "key-rotation")
    }

    private func updateKeyRotationSigningPublicKey(_ record: WalletEngineKeyRotationRecord, publicKey: Data) throws {
        guard let descriptor = try self.loadDescriptor(),
              descriptor.recordId == record.recordId,
              descriptor.publicKey == record.walletPublicKey,
              walletEngineAddressesEqual(descriptor.address, record.walletAddress),
              descriptor.secretRef == record.activeSecretRef else {
            throw WalletEngineStorageError.corrupted
        }
        try self.saveDescriptor(descriptor.withSigningPublicKey(publicKey))
    }

    func readProtectedSecret(_ request: ProtectedSecretRead) throws -> Data {
        guard let data = try self.read(service: self.secretService, account: request.secretRef.value) else {
            throw protectedSecretFailure(.notFound, "Protected secret was not found")
        }
        return try WalletVault.decrypt(data, namespace: self.namespace)
    }

    func containsProtectedSecret(_ secretRef: ProtectedSecretRef) throws -> Bool {
        var query = try self.baseQuery(service: self.secretService, account: secretRef.value)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw WalletEngineStorageError.keychainStatus(status) }
        return true
    }

    func storeProtectedSecret(_ request: ProtectedSecretStore) throws {
        guard !request.secretRef.value.isEmpty, !request.bytes.isEmpty else {
            throw protectedSecretFailure(.policyViolation, "Protected secret is empty")
        }
        let envelope = try WalletVault.encrypt(request.bytes, namespace: self.namespace)
        try self.write(envelope, service: self.secretService, account: request.secretRef.value)
    }

    func deleteProtectedSecret(_ secretRef: ProtectedSecretRef) throws {
        try self.remove(service: self.secretService, account: secretRef.value)
    }

    func debugRemoveMnemonicFromKeychain() throws {
        guard let secretRef = try self.loadDescriptor()?.secretRef, !secretRef.isEmpty else {
            return
        }
        try self.deleteProtectedSecret(ProtectedSecretRef(value: secretRef))
    }

    func loadJournal(_ key: JournalKey) throws -> JournalRecord? {
        let account = self.journalAccount(key)
        guard let value: JournalDiskRecord = try self.readCodable(service: self.journalService, account: account) else {
            return nil
        }
        guard value.version > 0, !value.payload.isEmpty else {
            throw journalFailure(.corruptData, "Wallet send journal is corrupt")
        }
        return JournalRecord(version: value.version, payload: value.payload)
    }

    func compareExchangeJournal(_ mutation: JournalCompareExchange) throws -> JournalCompareExchangeResult {
        let current = try self.loadJournal(mutation.key)
        guard current?.version == mutation.expectedVersion else {
            return JournalCompareExchangeResult(applied: false, current: current)
        }
        guard mutation.replacement.version > 0, !mutation.replacement.payload.isEmpty else {
            throw journalFailure(.corruptData, "Wallet send journal replacement is invalid")
        }
        try self.writeCodable(
            JournalDiskRecord(version: mutation.replacement.version, payload: mutation.replacement.payload),
            service: self.journalService,
            account: self.journalAccount(mutation.key)
        )
        return JournalCompareExchangeResult(applied: true, current: mutation.replacement)
    }

    private func journalAccount(_ key: JournalKey) -> String {
        Data("\(key.recordId)\u{0}\(key.slot)".utf8).base64EncodedString()
    }

    private func readCodable<Value: Decodable>(service: String, account: String) throws -> Value? {
        guard let data = try self.read(service: service, account: account) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw WalletEngineStorageError.corrupted
        }
    }

    private func writeCodable<Value: Encodable>(_ value: Value, service: String, account: String) throws {
        do {
            try self.write(JSONEncoder().encode(value), service: service, account: account)
        } catch let error as WalletEngineStorageError {
            throw error
        } catch {
            throw WalletEngineStorageError.corrupted
        }
    }

    private func baseQuery(service: String, account: String) throws -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        if let group = try WalletVault.keychainAccessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    private func read(service: String, account: String) throws -> Data? {
        var query = try self.baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw WalletEngineStorageError.keychainStatus(status)
        }
        return data
    }

    private func write(_ data: Data, service: String, account: String) throws {
        let query = try self.baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw WalletEngineStorageError.keychainStatus(updateStatus)
        }
        var addQuery = query
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw WalletEngineStorageError.keychainStatus(addStatus)
        }
    }

    private func remove(service: String, account: String) throws {
        let status = SecItemDelete(try self.baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletEngineStorageError.keychainStatus(status)
        }
    }
}

@available(macOS 10.15, *)
func discardWalletReplacementCandidate(
    recordId: String,
    loadCandidate: () throws -> WalletEngineDescriptorRecord?,
    isSecretReferenced: (String) throws -> Bool,
    deleteSecret: (String) throws -> Void,
    removeCandidate: () throws -> Void
) throws {
    guard let candidate = try loadCandidate(), candidate.recordId == recordId else { return }
    if let secretRef = candidate.secretRef, try !isSecretReferenced(secretRef) {
        try deleteSecret(secretRef)
    }
    try removeCandidate()
}

@available(macOS 10.15, *)
func walletReplacementSecretIsReferenced(
    _ secretRef: String,
    active: WalletEngineDescriptorRecord?,
    archived: [WalletEngineArchivedWalletRecord],
    rotation: WalletEngineKeyRotationRecord?
) -> Bool {
    if active?.secretRef == secretRef || archived.contains(where: { $0.descriptor.secretRef == secretRef }) {
        return true
    }
    if let rotation, [rotation.activeSecretRef, rotation.rollbackSecretRef, rotation.candidateSecretRef].contains(secretRef) {
        return true
    }
    return false
}

@available(macOS 10.15, *)
actor WalletEnginePlatformHost: WalletPlatformHost {
    let storage: WalletEngineStorage
    private let logger: WalletLogger
    private var authorization: PasscodeSession?
    private var tonConnectSigningGuard: (@Sendable () throws -> Void)?

    func setTonConnectSigningGuard(_ guardValue: (@Sendable () throws -> Void)?) { self.tonConnectSigningGuard = guardValue }

    func setAuthorization(_ grant: PasscodeSession?) { self.authorization = grant }

    private var captureNextProtectedSecret = false
    private var transientProtectedSecrets: [String: Data] = [:]

    init(storage: WalletEngineStorage, logger: WalletLogger) {
        self.storage = storage
        self.logger = logger
    }

    func now() async -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970.rounded(.down)))
    }

    func beginTransientProtectedSecretCapture() {
        self.captureNextProtectedSecret = true
    }

    func cancelTransientProtectedSecretCapture() {
        self.captureNextProtectedSecret = false
    }

    func transientProtectedSecret(secretRef: ProtectedSecretRef) throws -> Data? {
        try WalletAuthorizationScope.$session.withValue(self.authorization) {
            guard let envelope = self.transientProtectedSecrets[secretRef.value] else { return nil }
            return try WalletVault.decrypt(envelope, namespace: self.storage.namespace)
        }
    }

    func containsTransientProtectedSecret(secretRef: ProtectedSecretRef) -> Bool {
        self.transientProtectedSecrets[secretRef.value] != nil
    }

    func removeTransientProtectedSecret(secretRef: ProtectedSecretRef) {
        self.transientProtectedSecrets[secretRef.value] = nil
    }

    func retainTransientProtectedSecret(secretRef: ProtectedSecretRef, bytes: Data) throws {
        self.transientProtectedSecrets[secretRef.value] = try WalletVault.encrypt(bytes, namespace: self.storage.namespace)
    }

    func removeAllTransientProtectedSecrets() {
        self.captureNextProtectedSecret = false
        self.transientProtectedSecrets.removeAll()
    }

    func readProtectedSecret(request: ProtectedSecretRead) async throws -> Data {
        do {
            if let authorization = self.authorization { try await authorization.waitUntilAvailable() }
            try self.tonConnectSigningGuard?()
            return try await WalletAuthorizationScope.$session.withValue(self.authorization) {
                _ = try WalletVault.access(namespace: self.storage.namespace)
                if let data = self.transientProtectedSecrets[request.secretRef.value] {
                    return try WalletVault.decrypt(data, namespace: self.storage.namespace)
                }
                return try await self.storage.readProtectedSecret(request)
            }
        } catch let error as ProtectedSecretHostError {
            throw error
        } catch let error as PasscodeError {
            switch error {
            case .cancelled, .staleAuthorization:
                throw protectedSecretFailure(.cancelled, "Authorization was cancelled")
            case .authenticationRequired, .invalidCode, .cooldown:
                throw protectedSecretFailure(.authenticationFailed, "Authorization is required")
            default:
                throw protectedSecretFailure(.unavailable, "Protected storage is unavailable")
            }
        } catch {
            throw protectedSecretFailure(.unavailable, "Protected storage is unavailable")
        }
    }

    func storeProtectedSecret(request: ProtectedSecretStore) async throws {
        do {
            if let authorization = self.authorization { try await authorization.waitUntilAvailable() }
            try await WalletAuthorizationScope.$session.withValue(self.authorization) {
                _ = try WalletVault.access(namespace: self.storage.namespace)
                if self.captureNextProtectedSecret {
                    self.captureNextProtectedSecret = false
                    guard !request.secretRef.value.isEmpty, !request.bytes.isEmpty else {
                        throw protectedSecretFailure(.policyViolation, "Protected secret is empty")
                    }
                    self.transientProtectedSecrets[request.secretRef.value] = try WalletVault.encrypt(request.bytes, namespace: self.storage.namespace)
                    return
                }
                try await self.storage.storeProtectedSecret(request)
            }
        } catch let error as ProtectedSecretHostError {
            throw error
        } catch {
            throw protectedSecretFailure(.unavailable, "Protected storage is unavailable")
        }
    }

    func deleteProtectedSecret(secretRef: ProtectedSecretRef) async throws {
        if self.transientProtectedSecrets.removeValue(forKey: secretRef.value) != nil {
            return
        }
        do {
            try await self.storage.deleteProtectedSecret(secretRef)
        } catch {
            self.logger.error("wallet_protected_secret_delete_failed", error)
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func loadJournal(key: JournalKey) async throws -> JournalRecord? {
        do {
            return try await self.storage.loadJournal(key)
        } catch let error as JournalHostError {
            self.logger.error("wallet_journal_load_failed", error)
            throw error
        } catch {
            self.logger.error("wallet_journal_load_failed", error)
            throw journalFailure(.unavailable, String(describing: error))
        }
    }

    func compareExchangeJournal(mutation: JournalCompareExchange) async throws -> JournalCompareExchangeResult {
        do {
            return try await self.storage.compareExchangeJournal(mutation)
        } catch let error as JournalHostError {
            self.logger.error("wallet_journal_compare_exchange_failed", error)
            throw error
        } catch {
            self.logger.error("wallet_journal_compare_exchange_failed", error)
            throw journalFailure(.unavailable, String(describing: error))
        }
    }
}

@available(macOS 10.15, *)
private func protectedSecretFailure(
    _ kind: ProtectedSecretHostErrorKind,
    _ diagnostic: String
) -> ProtectedSecretHostError {
    .Failed(kind: kind, diagnostic: sanitizedWalletEngineDiagnostic(diagnostic))
}

@available(macOS 10.15, *)
private func journalFailure(
    _ kind: JournalHostErrorKind,
    _ diagnostic: String
) -> JournalHostError {
    .Failed(kind: kind, diagnostic: sanitizedWalletEngineDiagnostic(diagnostic))
}

@available(macOS 10.15, *)
func sanitizedWalletEngineDiagnostic(_ value: String) -> String {
    String(
        value.unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }
            .joined()
            .prefix(256)
    )
}
