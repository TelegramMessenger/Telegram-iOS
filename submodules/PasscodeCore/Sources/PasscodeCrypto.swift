import Foundation
import CryptoKit
import CommonCrypto
import Security

public enum PasscodeError: Error, Equatable {
    case unavailable
    case corrupted
    case invalidCode
    case cooldown(Int)
    case cancelled
    case authenticationRequired
    case staleAuthorization
    case biometricsUnavailable
    case keychain(Int32)
}

@available(macOS 10.15, *)
enum PasscodeCrypto {
    static let minimumIterations = 600_000
    static let maximumIterations = 3_000_000

    static func random(_ count: Int) throws -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw PasscodeError.keychain(status) }
        return bytes
    }

    static func iterations() -> Int {
        let value = Int(CCCalibratePBKDF(CCPBKDFAlgorithm(kCCPBKDF2), 32, 16, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 32, 350))
        return min(maximumIterations, max(minimumIterations, value))
    }

    static func derive(code: String, deviceSecret: Data, salt: Data, iterations: Int) throws -> Data {
        guard deviceSecret.count == 32, salt.count == 16,
              (minimumIterations ... maximumIterations).contains(iterations) else { throw PasscodeError.corrupted }
        var password = Data(HMAC<SHA256>.authenticationCode(for: Data(("telegram.passcode.v1\0" + code).utf8), using: SymmetricKey(data: deviceSecret)))
        defer { password.resetBytes(in: 0 ..< password.count) }
        var key = Data(count: 32)
        let status = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                key.withUnsafeMutableBytes { keyBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self), password.count,
                                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                                        keyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        guard status == kCCSuccess else { throw PasscodeError.unavailable }
        return key
    }

    static func seal(_ data: Data, key: Data, context: String) throws -> Data {
        guard key.count == 32 else { throw PasscodeError.corrupted }
        let nonce = try AES.GCM.Nonce(data: random(12))
        guard let result = try AES.GCM.seal(data, using: SymmetricKey(data: key), nonce: nonce, authenticating: Data(context.utf8)).combined else {
            throw PasscodeError.corrupted
        }
        return result
    }

    static func open(_ data: Data, key: Data, context: String) throws -> Data {
        guard key.count == 32, data.count >= 28 else { throw PasscodeError.corrupted }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: SymmetricKey(data: key), authenticating: Data(context.utf8))
        } catch {
            throw PasscodeError.corrupted
        }
    }
}

@available(macOS 10.15, *)
public final class PasscodeSession: @unchecked Sendable {
    public enum Lifetime: Equatable, Sendable {
        case standard
        case ownerManaged
    }

    public enum Scope: Equatable, Sendable {
        case appUnlock
        case managePasscode
        case settings
        case resource(namespace: String)
    }

    enum Authentication {
        case unprotected
        case passcode
        case biometrics
    }

    private static let registryLock = NSRecursiveLock()
    private static let registry = NSHashTable<PasscodeSession>.weakObjects()
    private static var revocationGeneration: UInt64 = 0
    private static var applicationAvailable = false

    public let id = UUID()
    public let scope: Scope
    public let lifetime: Lifetime
    public let expiresAt: TimeInterval?

    let credentialId: String
    let authentication: Authentication
    private var currentRevision: UInt64
    private var key: Data
    private var generation: UInt64
    private let uptime: () -> TimeInterval
    private var availabilityWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    var revision: UInt64 {
        Self.registryLock.lock()
        defer {
            Self.registryLock.unlock()
        }
        return self.currentRevision
    }

    public var isValid: Bool {
        Self.registryLock.lock()
        defer {
            Self.registryLock.unlock()
        }
        return self.isValidLocked
    }

    private var isValidLocked: Bool {
        return self.generation == Self.revocationGeneration && self.key.count == 32 && (self.expiresAt.map { self.uptime() < $0 } ?? true)
    }

    private var isAvailableLocked: Bool {
        if case .resource = self.scope {
            return Self.applicationAvailable
        }
        return true
    }

    init(credentialId: String, revision: UInt64, key: Data, scope: Scope, authentication: Authentication = .unprotected,
         lifetime: Lifetime = .standard, expiresAt: TimeInterval? = nil,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        if lifetime == .ownerManaged {
            guard case .resource = scope else {
                preconditionFailure()
            }
        }
        self.credentialId = credentialId
        self.currentRevision = revision
        self.key = key
        self.scope = scope
        self.authentication = authentication
        self.lifetime = lifetime
        self.expiresAt = lifetime == .standard ? (expiresAt ?? uptime() + 300) : nil
        self.uptime = uptime
        Self.registryLock.lock()
        self.generation = Self.revocationGeneration
        Self.registry.add(self)
        Self.registryLock.unlock()
        if let expiresAt = self.expiresAt {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + max(0, expiresAt - uptime())) { [weak self] in self?.invalidate() }
        }
    }
    
    deinit {
        self.invalidate()
    }

    func require(scope: Scope, passcode: Bool = false) throws {
        guard self.scope == scope, !passcode || self.authentication == .passcode else {
            throw PasscodeError.authenticationRequired
        }
    }

    func withKey<T>(_ body: (Data) throws -> T) throws -> T {
        Self.registryLock.lock()
        defer {
            Self.registryLock.unlock()
        }
        guard self.isValidLocked else {
            throw PasscodeError.staleAuthorization
        }
        guard self.isAvailableLocked else {
            throw PasscodeError.unavailable
        }
        return try body(self.key)
    }

    /// Derive a resource key without exposing the credential's access key.
    /// Namespace binding, availability, and revocation share the key-use lock.
    @available(macOS 11.0, *)
    public func withDerivedKey<T>(namespace: String, domain: String, _ body: (Data) throws -> T) throws -> T {
        guard !namespace.isEmpty, !domain.isEmpty else {
            throw PasscodeError.authenticationRequired
        }
        try self.require(scope: .resource(namespace: namespace))
        return try self.withKey { accessKey in
            let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: accessKey),
                salt: Data(namespace.utf8), info: Data(domain.utf8), outputByteCount: 32)
            var derivedKey = key.withUnsafeBytes { Data($0) }
            defer { derivedKey.resetBytes(in: 0 ..< derivedKey.count) }
            return try body(derivedKey)
        }
    }

    public func waitUntilAvailable() async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Self.registryLock.lock()
                defer { Self.registryLock.unlock() }
                if Task.isCancelled {
                    continuation.resume(throwing: PasscodeError.cancelled)
                } else if !self.isValidLocked {
                    continuation.resume(throwing: PasscodeError.staleAuthorization)
                } else if self.isAvailableLocked {
                    continuation.resume()
                } else if self.lifetime == .ownerManaged {
                    self.availabilityWaiters[id] = continuation
                } else {
                    continuation.resume(throwing: PasscodeError.unavailable)
                }
            }
        }, onCancel: {
            Self.registryLock.lock()
            let continuation = self.availabilityWaiters.removeValue(forKey: id)
            Self.registryLock.unlock()
            continuation?.resume(throwing: PasscodeError.cancelled)
        })
        if Task.isCancelled { throw PasscodeError.cancelled }
    }

    public static func setApplicationAvailable(_ available: Bool) {
        self.registryLock.lock()
        defer {
            self.registryLock.unlock()
        }
        guard self.applicationAvailable != available else { return }
        self.applicationAvailable = available
        for session in self.registry.allObjects {
            if !available, session.lifetime == .standard {
                session.invalidate()
            } else if available {
                let waiters = session.availabilityWaiters.values
                session.availabilityWaiters = [:]
                for continuation in waiters {
                    if session.isValidLocked { continuation.resume() }
                    else { continuation.resume(throwing: PasscodeError.staleAuthorization) }
                }
            }
        }
    }

    func advance(to revision: UInt64) throws {
        Self.registryLock.lock()
        defer {
            Self.registryLock.unlock()
        }
        guard self.isValidLocked else { throw PasscodeError.staleAuthorization }
        self.currentRevision = revision
    }

    public func invalidate() {
        Self.registryLock.lock()
        defer {
            Self.registryLock.unlock()
        }
        self.key.resetBytes(in: 0 ..< self.key.count)
        self.key.removeAll()
        let waiters = self.availabilityWaiters.values
        self.availabilityWaiters = [:]
        for continuation in waiters { continuation.resume(throwing: PasscodeError.staleAuthorization) }
    }

    public static func invalidateAll() {
        self.invalidateAll(except: nil)
    }

    static func invalidateAll(except retained: PasscodeSession?) {
        self.registryLock.lock()
        defer {
            self.registryLock.unlock()
        }
        let retainIsValid = retained?.isValidLocked == true
        Self.revocationGeneration &+= 1
        if retainIsValid { retained?.generation = Self.revocationGeneration }
        for value in self.registry.allObjects where value !== retained || !retainIsValid {
            value.invalidate()
        }
    }
}

