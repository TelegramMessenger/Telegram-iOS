import TelegramCore
#if os(macOS)
import PasscodeCore
#endif

public func passcodeKind(from kind: PostboxAccessChallengeData.Kind) -> PasscodeKind {
    switch kind {
    case .digits4:
        return .digits4
    case .digits6:
        return .digits6
    case .alphanumeric:
        return .alphanumeric
    }
}

public func passcodeCredentialReference(from challenge: PostboxAccessChallengeData) -> PasscodeCredentialReference? {
    guard case let .secured(id, kind) = challenge else {
        return nil
    }
    return PasscodeCredentialReference(id: id, kind: passcodeKind(from: kind))
}

public func accessChallengeData(reference: PasscodeCredentialReference) -> PostboxAccessChallengeData {
    let kind: PostboxAccessChallengeData.Kind
    switch reference.kind {
    case .digits4:
        kind = .digits4
    case .digits6:
        kind = .digits6
    case .alphanumeric:
        kind = .alphanumeric
    }
    return .secured(id: reference.id, kind: kind)
}

/// nil input requests authority without migrating legacy metadata. A nil result
/// means no managed credential exists; .some(.none) is an authoritative removal.
@available(macOS 10.15, *)
private func resolveAccessChallenge(_ current: PostboxAccessChallengeData?, allowMigration: Bool) throws -> PostboxAccessChallengeData? {
    let credentials = PasscodeCredentialStore.shared
    if let current, case .secured = current {
        credentials.requireExistingCredential()
    }
    if let reference = try credentials.managedReference() {
        return .some(reference.map { accessChallengeData(reference: $0) } ?? .none)
    }
    guard allowMigration, let current else {
        return nil
    }
    switch current {
    case let .numericalPassword(code):
        let kind: PasscodeKind = code.count == 6 ? .digits6 : .digits4
        let reference = try credentials.migrateLegacy(code: code, kind: kind)
        return .some(reference.map { accessChallengeData(reference: $0) } ?? .none)
    case let .plaintextPassword(code):
        let reference = try credentials.migrateLegacy(code: code, kind: .alphanumeric)
        return .some(reference.map { accessChallengeData(reference: $0) } ?? .none)
    case .none, .secured:
        return nil
    }
}

@available(macOS 10.15, *)
public func setupAccountManager<Types: AccountManagerTypes>(basePath: String, isTemporary: Bool, isReadOnly: Bool, useCaches: Bool, removeDatabaseOnError: Bool, resetLocalSecrets: (() throws -> Void)? = nil) -> AccountManager<Types> {
    let isMainProcess = PasscodeEnvironment.shared.isMainApp
    let canReset = isMainProcess && !isTemporary && !isReadOnly
    precondition(!canReset || resetLocalSecrets != nil)

    return AccountManager(
        basePath: basePath,
        isTemporary: isTemporary,
        isReadOnly: isReadOnly,
        useCaches: useCaches,
        removeDatabaseOnError: removeDatabaseOnError,
        accessChallenge: AccountManagerAccessChallenge(
            prepare: { isFreshInstallation in
                let _ = try PasscodeEnvironment.shared.sharedAccessGroup()
                PasscodeCredentialStore.shared.configureLock(directory: basePath)
                if canReset && isFreshInstallation {
                    try resetLocalSecrets?()
                }
            },
            resolve: { current, allowMigration in
                return try resolveAccessChallenge(current, allowMigration: allowMigration)
            },
            finishInitialization: {
                if isMainProcess {
                    try PasscodeCredentialStore.shared.resumeCleanup()
                }
            }
        )
    )
}
