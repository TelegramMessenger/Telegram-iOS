import Foundation
import CryptoKit
import LocalAuthentication
import PasscodeCore

@available(macOS 10.15, *)
public struct WalletSecretEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let vaultId: String
    public let secretId: String
    public let wrappedDek: Data
    public let ciphertext: Data

    public static func encrypt(_ secret: Data, vaultId: String, access: PasscodeSession) throws -> WalletSecretEnvelope {
        guard !secret.isEmpty, !vaultId.isEmpty else { throw PasscodeError.corrupted }
        guard #available(macOS 11.0, *) else { throw PasscodeError.unavailable }
        let secretId = UUID().uuidString
        var dek = try random(32)
        defer { dek.resetBytes(in: 0 ..< dek.count) }
        return try access.withDerivedKey(namespace: vaultId, domain: "telegram.wallet.dek.v1") { key in
            WalletSecretEnvelope(version: 1, vaultId: vaultId, secretId: secretId,
                wrappedDek: try seal(dek, key: key, context: "dek.v1:\(vaultId):\(secretId)"),
                ciphertext: try seal(secret, key: dek, context: "secret.v1:\(vaultId):\(secretId)"))
        }
    }

    public func decrypt(vaultId: String, access: PasscodeSession) throws -> Data {
        guard self.version == 1, self.vaultId == vaultId, !self.secretId.isEmpty else { throw PasscodeError.corrupted }
        guard #available(macOS 11.0, *) else { throw PasscodeError.unavailable }
        return try access.withDerivedKey(namespace: vaultId, domain: "telegram.wallet.dek.v1") { key in
            var dek = try Self.open(self.wrappedDek, key: key, context: "dek.v1:\(vaultId):\(self.secretId)")
            defer { dek.resetBytes(in: 0 ..< dek.count) }
            return try Self.open(self.ciphertext, key: dek, context: "secret.v1:\(vaultId):\(self.secretId)")
        }
    }

    private static func random(_ count: Int) throws -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw PasscodeError.keychain(status) }
        return bytes
    }

    private static func seal(_ data: Data, key: Data, context: String) throws -> Data {
        guard key.count == 32 else { throw PasscodeError.corrupted }
        let nonce = try AES.GCM.Nonce(data: random(12))
        guard let result = try AES.GCM.seal(data, using: SymmetricKey(data: key), nonce: nonce, authenticating: Data(context.utf8)).combined else {
            throw PasscodeError.corrupted
        }
        return result
    }

    private static func open(_ data: Data, key: Data, context: String) throws -> Data {
        guard key.count == 32, data.count >= 28 else { throw PasscodeError.corrupted }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: SymmetricKey(data: key), authenticating: Data(context.utf8))
        } catch {
            throw PasscodeError.corrupted
        }
    }
}

@available(macOS 10.15, *)
enum WalletVault {
    static let envelopeServicePrefix = "org.telegram.ton-wallet.vault.v1.envelope."

    static func service(namespace: String) -> String { self.envelopeServicePrefix + namespace }

    static func keychainAccessGroup() throws -> String? {
        #if os(macOS)
        return nil
        #else
        return try PasscodeEnvironment.shared.privateAccessGroup()
        #endif
    }

    static func access(namespace: String) throws -> PasscodeSession {
        if let session = WalletAuthorizationScope.session {
            try PasscodeCredentialStore.shared.validate(session, scope: .resource(namespace: namespace))
            return session
        }
        return try PasscodeCredentialStore.shared.unprotectedSession(namespace: namespace)
    }

    static func encrypt(_ data: Data, namespace: String) throws -> Data {
        let access = try self.access(namespace: namespace)
        return try JSONEncoder().encode(WalletSecretEnvelope.encrypt(data, vaultId: namespace, access: access))
    }

    static func decrypt(_ data: Data, namespace: String) throws -> Data {
        let access = try self.access(namespace: namespace)
        guard let envelope = try? JSONDecoder().decode(WalletSecretEnvelope.self, from: data) else { throw PasscodeError.corrupted }
        return try envelope.decrypt(vaultId: namespace, access: access)
    }

    static let unscopedServicePrefix = "org.telegram.ton-wallet."

    static func servicePrefix(environment: PasscodeEnvironment) -> String {
        #if os(macOS)
        return PasscodeKeychainScope.service(self.unscopedServicePrefix, environment: environment)
        #else
        return self.unscopedServicePrefix
        #endif
    }

    static func removeAll(environment: PasscodeEnvironment = .shared) throws {
        try self.removeAll(environment: environment, readAttributes: { query in
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result)
        }, delete: { query in SecItemDelete(query as CFDictionary) })
    }

    static func removeAll(environment: PasscodeEnvironment, readAttributes: ([String: Any]) -> (OSStatus, CFTypeRef?), delete: ([String: Any]) -> OSStatus) throws {
        let group = try self.keychainAccessGroup()
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrSynchronizable as String: false]
        if let group {
            query[kSecAttrAccessGroup as String] = group
        }
        let (status, result) = readAttributes(query)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { throw PasscodeError.keychain(status) }
        let servicePrefix = self.servicePrefix(environment: environment)
        for item in items {
            guard let service = item[kSecAttrService as String] as? String,
                  service.hasPrefix(servicePrefix),
                  let account = item[kSecAttrAccount as String] as? String else { continue }
            var deletion: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: false]
            if let group {
                deletion[kSecAttrAccessGroup as String] = group
            }
            let status = delete(deletion)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw PasscodeError.keychain(status) }
        }
    }
}

@available(macOS 10.15, *)
public struct WalletAuthorizationRequest: Sendable {
    public let id: UUID
    public let namespace: String
    public let reason: String
    public let lifetime: PasscodeSession.Lifetime
}

@available(macOS 10.15, *)
enum WalletAuthorizationScope {
    @TaskLocal static var session: PasscodeSession?
}

@available(macOS 10.15, *)
final class WalletAuthorizationContext: @unchecked Sendable {
    typealias Presenter = @Sendable (WalletAuthorizationRequest) async throws -> PasscodeSession
    let namespace: String
    private let credentials: PasscodeCredentialStore
    private let lock = NSLock()
    private var presenter: Presenter?
    private var generation: UInt64 = 0
    private var operationRevision: UInt64 = 0
    private let sessions = NSMapTable<NSUUID, PasscodeSession>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var available = false
    private var availabilityWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var resultGenerations: [UUID: UInt64] = [:]

    var isAvailable: Bool {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.available
    }

    init(namespace: String, credentials: PasscodeCredentialStore = .shared) {
        self.namespace = namespace
        self.credentials = credentials
    }

    func operationGeneration(requireAvailable: Bool = true) throws -> UInt64 {
        self.lock.lock(); defer { self.lock.unlock() }
        guard !requireAvailable || self.available else { throw PasscodeError.cancelled }
        return requireAvailable ? self.operationRevision : self.generation
    }

    func validateGeneration(_ generation: UInt64, requireAvailable: Bool = true) throws {
        self.lock.lock(); defer { self.lock.unlock() }
        guard (!requireAvailable || self.available),
              (requireAvailable ? self.operationRevision : self.generation) == generation else { throw PasscodeError.cancelled }
    }

    func setPresenter(_ presenter: @escaping Presenter) {
        self.lock.lock(); self.presenter = presenter; self.lock.unlock()
    }

    func setAvailable(_ available: Bool) {
        self.lock.lock()
        self.available = available
        if !available { self.operationRevision &+= 1 }
        let revoked = available ? [] : (self.sessions.objectEnumerator()?.allObjects as? [PasscodeSession] ?? []).filter { $0.lifetime == .standard }
        for session in revoked { self.sessions.removeObject(forKey: session.id as NSUUID) }
        let waiters = available ? Array(self.availabilityWaiters.values) : []
        if available { self.availabilityWaiters.removeAll() }
        self.lock.unlock()
        for session in revoked { session.invalidate() }
        for waiter in waiters { waiter.resume() }
    }

    func invalidate(preservingResultFor operationId: UUID? = nil) {
        self.lock.lock()
        let preservedId = operationId.flatMap { self.resultGenerations[$0] == self.generation ? $0 : nil }
        self.generation &+= 1
        self.operationRevision &+= 1
        self.resultGenerations.removeAll()
        if let preservedId { self.resultGenerations[preservedId] = self.generation }
        let sessions = self.sessions.objectEnumerator()?.allObjects as? [PasscodeSession] ?? []
        self.sessions.removeAllObjects()
        let waiters = Array(self.availabilityWaiters.values)
        self.availabilityWaiters.removeAll()
        self.lock.unlock()
        for session in sessions { session.invalidate() }
        for waiter in waiters { waiter.resume(throwing: PasscodeError.cancelled) }
    }

    func beginResultDelivery(id: UUID) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.resultGenerations[id] = self.generation
    }

    func resultDeliveryGeneration(id: UUID) throws -> UInt64 {
        self.lock.lock(); defer { self.lock.unlock() }
        guard let generation = self.resultGenerations[id], generation == self.generation else { throw PasscodeError.cancelled }
        return generation
    }

    func finishResultDelivery(id: UUID) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.resultGenerations.removeValue(forKey: id)
    }

    func waitUntilAvailable(generation: UInt64) async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.lock.lock(); defer { self.lock.unlock() }
                if Task.isCancelled || self.generation != generation {
                    continuation.resume(throwing: PasscodeError.cancelled)
                } else if self.available {
                    continuation.resume()
                } else {
                    self.availabilityWaiters[id] = continuation
                }
            }
        }, onCancel: {
            self.lock.lock()
            let continuation = self.availabilityWaiters.removeValue(forKey: id)
            self.lock.unlock()
            continuation?.resume(throwing: PasscodeError.cancelled)
        })
        try Task.checkCancellation()
        try self.validateGeneration(generation, requireAvailable: false)
    }

    private func snapshot() throws -> (UInt64, UInt64, Presenter) {
        self.lock.lock(); defer { self.lock.unlock() }
        guard self.available, let presenter = self.presenter else { throw PasscodeError.authenticationRequired }
        return (self.generation, self.operationRevision, presenter)
    }

    private func install(_ session: PasscodeSession, generation: UInt64) throws -> PasscodeSession {
        do {
            try self.credentials.validate(session, scope: .resource(namespace: self.namespace))
        } catch {
            session.invalidate()
            throw error
        }
        self.lock.lock(); defer { self.lock.unlock() }
        guard self.available, self.generation == generation else { session.invalidate(); throw PasscodeError.cancelled }
        self.sessions.setObject(session, forKey: session.id as NSUUID)
        return session
    }

    func authorize(id: UUID, reason: String, lifetime: PasscodeSession.Lifetime = .standard) async throws -> PasscodeSession? {
        let generation = try self.operationGeneration()
        guard try walletProtectionSettings(credentials: self.credentials).enabled else {
            try self.validateGeneration(generation)
            return nil
        }
        let (credentialGeneration, presentationRevision, presenter) = try self.snapshot()
        let session = try await presenter(WalletAuthorizationRequest(id: id, namespace: self.namespace, reason: reason, lifetime: lifetime))
        do {
            try Task.checkCancellation()
            try self.validateGeneration(presentationRevision)
            guard session.lifetime == lifetime else { throw PasscodeError.authenticationRequired }
            return try self.install(session, generation: credentialGeneration)
        } catch {
            session.invalidate()
            throw error
        }
    }

    func beginSession(id: UUID, reason: String, lifetime: PasscodeSession.Lifetime = .standard) async throws -> PasscodeSession {
        if let session = try await self.authorize(id: id, reason: reason, lifetime: lifetime) { return session }
        let generation = try self.operationGeneration(requireAvailable: false)
        return try self.install(self.credentials.unprotectedSession(namespace: self.namespace, lifetime: lifetime), generation: generation)
    }

    func adoptSession(_ session: PasscodeSession?) throws -> PasscodeSession? {
        if let session {
            do {
                try self.validate(session)
                return session
            } catch {
                self.finish(session)
                return nil
            }
        }
        let generation = try self.operationGeneration(requireAvailable: false)
        guard try !walletProtectionSettings(credentials: self.credentials).enabled else { return nil }
        return try self.install(self.credentials.unprotectedSession(namespace: self.namespace), generation: generation)
    }

    func validate(_ session: PasscodeSession, boundTo sessionId: UUID? = nil, requireAvailable: Bool = true) throws {
        self.lock.lock()
        let valid = (!requireAvailable || session.lifetime == .ownerManaged || self.available)
            && self.sessions.object(forKey: session.id as NSUUID) === session
            && (sessionId == nil || sessionId == session.id)
        self.lock.unlock()
        guard valid else { throw PasscodeError.staleAuthorization }
        try self.credentials.validate(session, scope: .resource(namespace: self.namespace), requireAvailable: requireAvailable)
    }

    func withSession<Value>(_ session: PasscodeSession?, operation: nonisolated(nonsending) () async throws -> Value) async throws -> Value {
        if let session {
            try await session.waitUntilAvailable()
            try self.validate(session)
        }
        return try await WalletAuthorizationScope.$session.withValue(session, operation: operation)
    }

    func finish(_ session: PasscodeSession?) {
        guard let session else { return }
        self.lock.lock(); self.sessions.removeObject(forKey: session.id as NSUUID); self.lock.unlock()
        session.invalidate()
    }
}

public let walletBiometricKeychainService = "org.telegram.ton-wallet.vault.v1.biometric"

@available(macOS 10.15, *)
public struct WalletProtectionSettings: Equatable, Sendable {
    public let passcode: PasscodeCredentialReference?
    public let enabled: Bool
    public let biometricsEnabled: Bool
}

@available(macOS 10.15, *)
public func walletProtectionSettings(credentials: PasscodeCredentialStore = .shared) throws -> WalletProtectionSettings {
    let settings = try credentials.protectionSettings()
    return WalletProtectionSettings(passcode: settings.passcode, enabled: settings.enabled, biometricsEnabled: settings.biometricsEnabled)
}

@available(macOS 10.15, *)
public func setWalletProtectionEnabled(_ enabled: Bool, session: PasscodeSession, credentials: PasscodeCredentialStore = .shared) throws {
    try credentials.validate(session, scope: .settings)
    guard try credentials.protectionSettings().enabled != enabled else {
        return
    }
    if enabled {
        try credentials.resumeCleanup()
    }
    try credentials.setProtectionEnabled(enabled, session: session)
}

@available(macOS 10.15, *)
public func setWalletBiometricsEnabled(_ enabled: Bool, session: PasscodeSession, context: LAContext, credentials: PasscodeCredentialStore = .shared) throws {
    try credentials.validate(session, scope: .settings)
    let settings = try credentials.protectionSettings()
    guard settings.enabled else {
        throw PasscodeError.authenticationRequired
    }
    guard settings.biometricsEnabled != enabled else {
        return
    }
    if enabled {
        try credentials.enableBiometrics(session: session, context: context)
    } else {
        try credentials.disableBiometrics(session: session)
    }
}

@available(macOS 10.15, *)
public func authenticateWalletBiometrics(namespace: String, lifetime: PasscodeSession.Lifetime = .standard, context: LAContext, credentials: PasscodeCredentialStore = .shared) throws -> PasscodeSession {
    return try credentials.authenticateBiometrics(context: context, scope: .resource(namespace: namespace), lifetime: lifetime)
}

#if os(macOS)
/// Copies this build's wallets and wallet passcode items into its keychain scope, each wallet's descriptor last;
/// see `PasscodeKeychainScope`.
@available(macOS 10.15, *)
public func migrateWalletKeychainScope(environment: PasscodeEnvironment = .shared) -> PasscodeKeychainScope.Migration {
    return PasscodeKeychainScope.migrateLegacyItems(walletServicePrefixes: [WalletVault.envelopeServicePrefix, WalletEngineStorage.journalServicePrefix, WalletEngineStorage.descriptorServicePrefix], environment: environment)
}
#endif

@available(macOS 10.15, *)
public func resetWalletLocalSecrets(environment: PasscodeEnvironment = .shared, credentials: PasscodeCredentialStore = .shared) throws {
    try resetWalletLocalSecrets(environment: environment, credentials: credentials) {
        try WalletVault.removeAll(environment: environment)
    }
}

@available(macOS 10.15, *)
func resetWalletLocalSecrets(environment: PasscodeEnvironment, credentials: PasscodeCredentialStore, removingWalletData: () throws -> Void) throws {
    guard environment.isMainApp else { throw PasscodeError.unavailable }
    try credentials.resetCredential(removingProtectedData: removingWalletData)
}

@available(macOS 10.15, *)
public func _internalResetLocalSecretsForPasscodeMigrationTest(then: () throws -> Never) throws -> Never {
    let environment = PasscodeEnvironment.shared
    guard environment.isMainApp else { throw PasscodeError.unavailable }
    try PasscodeCredentialStore.shared._internalResetForPasscodeMigrationTest(removingProtectedData: {
        try WalletVault.removeAll(environment: environment)
    }, then: then)
}
