import Foundation
import SwiftSignalKit

/// One open of a value per key at a time. iOS makes a new handler for every intent, and two
/// intents can arrive together (two announced notifications); each used to find the account
/// cache empty and open the account itself, so the extension ran two accounts on one database,
/// both connected and both syncing. A second request for the key while the first is still
/// opening now waits for that open. A nil result (a logged-out or upgrading record) is not kept,
/// so the next request opens again. Called on one queue only (the main queue).
final class SharedOpening<Key: Equatable, Value> {
    private var current: (key: Key, promise: Promise<Value?>)?

    init() {
    }

    func value(for key: Key, open: () -> Signal<Value?, NoError>) -> Signal<Value?, NoError> {
        if let current, current.key == key {
            return current.promise.get() |> take(1)
        }
        let promise = Promise<Value?>()
        self.current = (key, promise)
        promise.set(open()
        |> afterNext { [weak self, weak promise] value in
            if value == nil {
                Queue.mainQueue().async {
                    if let self, let current = self.current, current.promise === promise {
                        self.current = nil
                    }
                }
            }
        })
        return promise.get() |> take(1)
    }

    /// Forgets the open (the app switched accounts).
    func clear() {
        self.current = nil
    }
}

/// Brings the account up to date before Siri reads it, as the notification extension does
/// (`standalonePollDifference`): that poll never resets the account (a differenceTooLong ends it
/// and leaves the reset to the app) and answers false only after a slice, when it is asked again.
/// The search intent used to reset the account's whole state management instead, which ran the
/// app's own sync in the extension, account reset included.
func pollUntilDone(_ poll: @escaping () -> Signal<Bool, NoError>) -> Signal<Void, NoError> {
    return poll()
    |> mapToSignal { done -> Signal<Void, NoError> in
        if done {
            return .single(Void())
        } else {
            return pollUntilDone(poll)
        }
    }
}
