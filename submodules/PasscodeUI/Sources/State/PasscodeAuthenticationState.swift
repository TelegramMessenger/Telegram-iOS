import Foundation
import PasscodeCore

func validatedPasscodeBiometricSession(_ session: PasscodeSession, scope: PasscodeSession.Scope,
                                      lifetime: PasscodeSession.Lifetime,
                                      credentials: PasscodeCredentialStore = .shared) throws -> PasscodeSession {
    do {
        guard session.lifetime == lifetime else { throw PasscodeError.authenticationRequired }
        try credentials.validate(session, scope: scope)
        return session
    } catch {
        session.invalidate()
        throw error
    }
}

struct PasscodeEntryLifecycle {
    private let isMainApp: Bool
    private var isInBackground = false
    private var isDismissed = false
    private(set) var generation: UInt64 = 0

    init(isMainApp: Bool) {
        self.isMainApp = isMainApp
    }

    var canAuthenticate: Bool {
        return !self.isInBackground && !self.isDismissed
    }

    mutating func updateApplicationInForeground(_ value: Bool) -> Bool {
        let isInBackground = self.isMainApp && !value
        guard self.isInBackground != isInBackground else { return false }
        self.isInBackground = isInBackground
        if isInBackground {
            self.generation &+= 1
            return true
        }
        return false
    }

    func acceptsResult(generation: UInt64) -> Bool {
        return self.canAuthenticate && self.generation == generation
    }

    mutating func dismiss() {
        guard !self.isDismissed else { return }
        self.isDismissed = true
        self.generation &+= 1
    }
}

final class PasscodeAuthenticationDismissal {
    typealias Outcome = Result<PasscodeSession?, PasscodeError>

    enum Phase {
        case active
        case closing
        case finished
    }

    private(set) var phase: Phase = .active
    private var pendingResult: Outcome?
    private var completed: ((Outcome) -> Void)?
    private var removalCompletions: [() -> Void] = []

    func finish(_ result: Outcome, stopAuthentication: () -> Void,
                removeController: (@escaping () -> Void) -> Void,
                completed: @escaping (Outcome) -> Void) {
        guard self.phase == .active else {
            if self.phase == .closing, case .failure(.cancelled) = result {
                if case let .success(session) = self.pendingResult { session?.invalidate() }
                self.pendingResult = result
            } else if case let .success(session) = result {
                if case let .success(pending?) = self.pendingResult, pending === session { return }
                session?.invalidate()
            }
            return
        }
        self.phase = .closing
        self.pendingResult = result
        self.completed = completed
        stopAuthentication()
        removeController { [self] in self.didRemoveController() }
    }

    func afterRemoval(_ completion: @escaping () -> Void) {
        if self.phase == .finished {
            completion()
        } else {
            self.removalCompletions.append(completion)
        }
    }

    func didRemoveController() {
        guard self.phase == .closing, let result = self.pendingResult else { return }
        self.phase = .finished
        self.pendingResult = nil
        let completed = self.completed
        self.completed = nil
        let removalCompletions = self.removalCompletions
        self.removalCompletions.removeAll()
        completed?(result)
        for completion in removalCompletions { completion() }
    }
}

final class PendingPasscodeAuthentication<Controller: AnyObject>: @unchecked Sendable {
    typealias Outcome = Result<PasscodeSession, PasscodeError>
    typealias UIWork = @MainActor @Sendable () -> Void

    private let lock = NSLock()
    private var completion: ((Outcome) -> Void)?
    private var cancelled = false
    @MainActor private var controller: Controller?
    @MainActor private var didPresent = false
    private let schedule: @Sendable (@escaping UIWork) -> Void
    private let create: @MainActor (@escaping (Outcome) -> Void) -> Controller?
    private let prepare: @MainActor (Controller, @escaping @MainActor () -> Void) -> Void
    private let present: @MainActor (Controller) -> Void
    private let dismiss: @MainActor (Controller) -> Void

    init(schedule: @escaping @Sendable (@escaping UIWork) -> Void = { work in DispatchQueue.main.async(execute: work) },
         create: @escaping @MainActor (@escaping (Outcome) -> Void) -> Controller?,
         prepare: @escaping @MainActor (Controller, @escaping @MainActor () -> Void) -> Void = { _, present in present() },
         present: @escaping @MainActor (Controller) -> Void, dismiss: @escaping @MainActor (Controller) -> Void) {
        self.schedule = schedule
        self.create = create
        self.prepare = prepare
        self.present = present
        self.dismiss = dismiss
    }

    func start(_ completion: @escaping (Outcome) -> Void) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            completion(.failure(.cancelled))
            return
        }
        self.completion = completion
        self.lock.unlock()
        self.schedule { [self] in
            guard self.canPresent() else {
                self.finish(.failure(.cancelled))
                return
            }
            let controller = self.create { [self] result in self.finish(result) }
            guard let controller else {
                return
            }
            guard self.canPresent() else {
                self.dismiss(controller)
                return
            }
            self.controller = controller
            self.prepare(controller) { [weak self, weak controller] in
                guard let self, let controller, self.controller === controller, !self.didPresent else { return }
                guard self.canPresent() else {
                    self.dismiss(controller)
                    return
                }
                self.didPresent = true
                self.present(controller)
            }
        }
    }

    private func canPresent() -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return !self.cancelled && self.completion != nil
    }

    private func finish(_ result: Outcome) {
        self.lock.lock()
        let completion = self.completion
        self.completion = nil
        let cancelled = self.cancelled
        self.lock.unlock()
        guard let completion else {
            if case let .success(session) = result { session.invalidate() }
            return
        }
        self.schedule { [self] in self.controller = nil }
        if cancelled {
            if case let .success(session) = result { session.invalidate() }
            completion(.failure(.cancelled))
        } else {
            completion(result)
        }
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        self.lock.unlock()
        self.schedule { [self] in
            if let controller = self.controller {
                self.dismiss(controller)
            } else {
                self.finish(.failure(.cancelled))
            }
        }
    }
}
