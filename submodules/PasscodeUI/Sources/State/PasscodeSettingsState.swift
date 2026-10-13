import Foundation
import PasscodeCore

/// Main-thread state for the settings PIN screen; storage work runs separately.
final class SettingsPasscodeAuthentication {
    enum State: Equatable {
        case ready
        case checking
        case cooldown(Int)
        case finished
    }

    private var lifecycle: PasscodeEntryLifecycle
    private let verify: (String) throws -> PasscodeSession
    private let cooldownRemaining: () throws -> Int
    private let perform: (@escaping () -> Void) -> Void
    private let deliver: (@escaping () -> Void) -> Void
    private var requestId: UInt64 = 0

    private(set) var state: State = .ready
    var updated: ((State) -> Void)?
    var incorrectCode: (() -> Void)?
    var completed: ((Result<PasscodeSession, PasscodeError>) -> Void)?

    init(isMainApp: Bool, verify: @escaping (String) throws -> PasscodeSession,
         cooldownRemaining: @escaping () throws -> Int,
         perform: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.global(qos: .userInitiated).async(execute: work) },
         deliver: @escaping (@escaping () -> Void) -> Void = { work in DispatchQueue.main.async(execute: work) }) {
        self.lifecycle = PasscodeEntryLifecycle(isMainApp: isMainApp)
        self.verify = verify
        self.cooldownRemaining = cooldownRemaining
        self.perform = perform
        self.deliver = deliver
    }

    private func update(_ state: State) {
        self.state = state
        self.updated?(state)
    }

    private func acceptsResult(requestId: UInt64, generation: UInt64) -> Bool {
        return self.requestId == requestId && self.lifecycle.acceptsResult(generation: generation)
    }

    func refreshCooldown() {
        guard self.lifecycle.canAuthenticate, self.state != .checking else { return }
        self.requestId &+= 1
        let requestId = self.requestId
        let generation = self.lifecycle.generation
        let cooldownRemaining = self.cooldownRemaining
        let deliver = self.deliver
        self.update(.checking)
        self.perform { [weak self] in
            let result = Result { try cooldownRemaining() }
            deliver { [weak self] in
                guard let self, self.acceptsResult(requestId: requestId, generation: generation) else { return }
                switch result {
                case let .success(remaining): self.update(remaining > 0 ? .cooldown(remaining) : .ready)
                case let .failure(error): self.finish(.failure(error as? PasscodeError ?? .unavailable))
                }
            }
        }
    }

    func submit(_ code: String) {
        guard self.lifecycle.canAuthenticate, self.state == .ready else { return }
        self.requestId &+= 1
        let requestId = self.requestId
        let generation = self.lifecycle.generation
        let verify = self.verify
        let deliver = self.deliver
        self.update(.checking)
        self.perform { [weak self] in
            let result = Result { try verify(code) }
            deliver { [weak self] in
                guard let self, self.acceptsResult(requestId: requestId, generation: generation) else {
                    if case let .success(session) = result { session.invalidate() }
                    return
                }
                switch result {
                case let .success(session): self.finish(.success(session))
                case let .failure(error):
                    let error = error as? PasscodeError ?? .unavailable
                    switch error {
                    case .invalidCode:
                        self.incorrectCode?()
                        self.update(.ready)
                        self.refreshCooldown()
                    case let .cooldown(remaining): self.update(.cooldown(remaining))
                    default: self.finish(.failure(error))
                    }
                }
            }
        }
    }

    func updateApplicationInForeground(_ value: Bool) {
        if self.lifecycle.updateApplicationInForeground(value) { self.cancel() }
    }

    func updatePasscodeLocked(_ value: Bool) {
        if value { self.cancel() }
    }

    func cancel() {
        self.finish(.failure(.cancelled))
    }

    private func finish(_ result: Result<PasscodeSession, PasscodeError>) {
        guard self.state != .finished else {
            if case let .success(session) = result { session.invalidate() }
            return
        }
        self.lifecycle.dismiss()
        self.update(.finished)
        self.completed?(result)
    }
}

/// Main-thread ownership of settings authorization and asynchronous UI work.
/// Inactive is deliberately not an input: only background, lock and account
/// changes revoke the session. A child settings screen does not end the visit.
public final class PasscodeSettingsSessionState {
    public private(set) var session: PasscodeSession?
    public private(set) var generation: UInt64 = 0
    public var isUpdating: Bool { self.operation != nil }
    private var operation: UInt64?
    private var nextOperation: UInt64 = 0
    private var foreground = true
    private var locked = false
    private var currentAccount = true
    private var closed = false

    public init(session: PasscodeSession?) {
        if let session, session.scope == .settings, session.isValid {
            self.session = session
        } else {
            session?.invalidate()
            self.session = nil
        }
    }

    private var available: Bool { self.foreground && !self.locked && self.currentAccount && !self.closed }

    public func beginOperation() -> UInt64? {
        guard self.available, self.operation == nil else { return nil }
        self.nextOperation &+= 1
        self.operation = self.nextOperation
        return self.nextOperation
    }

    public func accepts(operation: UInt64) -> Bool { self.available && self.operation == operation }

    public func accepts(generation: UInt64) -> Bool { self.available && self.generation == generation }

    public func finish(operation: UInt64) {
        if self.operation == operation { self.operation = nil }
    }

    @discardableResult
    public func replaceSession(_ session: PasscodeSession, generation: UInt64) -> Bool {
        guard self.available, self.generation == generation, session.scope == .settings, session.isValid else {
            session.invalidate()
            return false
        }
        if self.session !== session { self.session?.invalidate() }
        self.session = session
        return true
    }

    public func invalidate() {
        self.generation &+= 1
        self.session?.invalidate()
        self.session = nil
        self.operation = nil
    }

    public func updateEnvironment(foreground: Bool, locked: Bool, currentAccount: Bool) {
        self.foreground = foreground
        self.locked = locked
        self.currentAccount = currentAccount
        if !self.available { self.invalidate() }
    }

    public func close() { self.closed = true; self.invalidate() }

    deinit { self.session?.invalidate() }
}

/// A setup child may borrow its parent settings session until it commits a new
/// credential. Leaving that child revokes only authorization owned by the child.
final class PasscodeSetupSessionState {
    private let authorizationSession: PasscodeSession?
    private let ownsAuthorizationSession: Bool
    private let lifecycle = PasscodeSettingsSessionState(session: nil)
    private var finished = false

    var generation: UInt64 { self.lifecycle.generation }

    init(authorizationSession: PasscodeSession?, ownsAuthorizationSession: Bool) {
        self.authorizationSession = authorizationSession
        self.ownsAuthorizationSession = ownsAuthorizationSession
    }

    func accepts(generation: UInt64) -> Bool {
        return !self.finished && self.lifecycle.accepts(generation: generation)
    }

    func updateEnvironment(foreground: Bool, locked: Bool, currentAccount: Bool) {
        self.lifecycle.updateEnvironment(foreground: foreground, locked: locked, currentAccount: currentAccount)
        if !foreground || locked || !currentAccount {
            self.authorizationSession?.invalidate()
        }
    }

    @discardableResult
    func cancel() -> Bool {
        self.lifecycle.close()
        if self.ownsAuthorizationSession {
            self.authorizationSession?.invalidate()
        }
        guard !self.finished else { return false }
        self.finished = true
        return true
    }

    func complete(generation: UInt64, session: PasscodeSession?) -> Bool {
        guard self.accepts(generation: generation) else {
            session?.invalidate()
            return false
        }
        self.finished = true
        return true
    }
}
