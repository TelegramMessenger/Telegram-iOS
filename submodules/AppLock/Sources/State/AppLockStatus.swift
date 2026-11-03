import SwiftSignalKit
import PasscodeCore

/// Separates an actual passcode lock from the legacy UI gate, which also blocks
/// interaction while UIKit is temporarily inactive (for example, during Face ID).
final class AppLockStatus {
    private struct State {
        let isPasscodeLocked: Bool
        let isApplicationActive: Bool
    }

    private let state = Promise<State>()

    var isPasscodeLocked: Signal<Bool, NoError> {
        return self.state.get()
        |> map { $0.isPasscodeLocked }
        |> distinctUntilChanged
    }

    var isCurrentlyLocked: Signal<Bool, NoError> {
        return self.state.get()
        |> map { !$0.isApplicationActive || $0.isPasscodeLocked }
        |> distinctUntilChanged
    }

    func update(isPasscodeLocked: Bool, isApplicationActive: Bool, isApplicationInForeground: Bool = true) {
        PasscodeSession.setApplicationAvailable(isApplicationInForeground && !isPasscodeLocked)
        self.state.set(.single(State(isPasscodeLocked: isPasscodeLocked, isApplicationActive: isApplicationActive)))
    }
}
