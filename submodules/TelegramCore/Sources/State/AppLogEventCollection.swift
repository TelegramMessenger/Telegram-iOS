import Foundation
import SwiftSignalKit

public final class AppLogEventContext {
    let identifier = UUID().uuidString
    fileprivate weak var owner: AnyObject?
    fileprivate var active = true
    fileprivate let purge: () -> Void
    fileprivate var requests: [UUID: Disposable] = [:]

    fileprivate init(owner: AnyObject, purge: @escaping () -> Void) {
        self.owner = owner
        self.purge = purge
    }

    public func invalidate() {
        AppLogEventCollection.invalidate(self)
    }

    deinit {
        invalidate()
    }
}

enum AppLogEventCollection {
    private final class Entry {
        weak var context: AppLogEventContext?
        let identifier: String

        init(_ context: AppLogEventContext) {
            self.context = context
            self.identifier = context.identifier
        }
    }

    private static let lock = NSRecursiveLock()
    private static var contexts: [ObjectIdentifier: Entry] = [:]

    static var allowsLegacyEvents: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }

    @discardableResult
    static func sync<T>(_ action: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return action()
    }

    static func makeContext(owner: AnyObject, purge: @escaping () -> Void) -> AppLogEventContext {
        let (context, previous) = sync { () -> (AppLogEventContext, AppLogEventContext?) in
            contexts = contexts.filter { $0.value.context != nil }
            let key = ObjectIdentifier(owner)
            let previous = contexts[key]?.context
            let context = AppLogEventContext(owner: owner, purge: purge)
            contexts[key] = Entry(context)
            return (context, previous)
        }
        previous?.invalidate()
        purge()
        return context
    }

    static func invalidate(_ context: AppLogEventContext) {
        let result = sync { () -> ((() -> Void), [Disposable])? in
            guard context.active else { return nil }
            context.active = false
            if let owner = context.owner {
                let key = ObjectIdentifier(owner)
                if contexts[key]?.identifier == context.identifier {
                    contexts.removeValue(forKey: key)
                }
            }
            let requests = Array(context.requests.values)
            context.requests.removeAll()
            return (context.purge, requests)
        }
        if let (purge, requests) = result {
            for request in requests {
                request.dispose()
            }
            purge()
        }
    }

    static func allows(owner: AnyObject, identifier: String?) -> Bool {
        return sync {
            guard let identifier = identifier else { return allowsLegacyEvents }
            guard let context = contexts[ObjectIdentifier(owner)]?.context else { return false }
            return context.active && context.owner === owner && context.identifier == identifier
        }
    }

    static func currentIdentifier(owner: AnyObject) -> String? {
        return sync {
            guard let context = contexts[ObjectIdentifier(owner)]?.context, context.active, context.owner === owner else { return nil }
            return context.identifier
        }
    }

    @discardableResult
    static func perform<T>(owner: AnyObject, identifiers: [String?], _ action: () -> T) -> T? {
        return sync {
            guard !identifiers.isEmpty, identifiers.allSatisfy({ allows(owner: owner, identifier: $0) }) else { return nil }
            return action()
        }
    }

    static func request(owner: AnyObject, identifiers: [String?], timeoutSeconds: Double? = nil, produce: @escaping () -> Signal<Void, NoError>) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let subscription = MetaDisposable()
            let requestId = UUID()
            let finish: () -> Void = {
                sync {
                    let _ = contexts[ObjectIdentifier(owner)]?.context?.requests.removeValue(forKey: requestId)
                }
            }
            let disposable = perform(owner: owner, identifiers: identifiers) { () -> Disposable in
                if identifiers.contains(where: { $0 != nil }) {
                    contexts[ObjectIdentifier(owner)]?.context?.requests[requestId] = ActionDisposable {
                        subscription.dispose()
                        subscriber.putCompletion()
                    }
                }
                var signal = produce()
                if let timeoutSeconds = timeoutSeconds {
                    signal = signal |> timeout(max(0, timeoutSeconds), queue: Queue.concurrentDefaultQueue(), alternate: .complete())
                }
                guard identifiers.allSatisfy({ allows(owner: owner, identifier: $0) }) else {
                    finish()
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                return signal.start(next: { subscriber.putNext($0) }, completed: {
                    finish()
                    subscriber.putCompletion()
                })
            }
            if let disposable = disposable {
                subscription.set(disposable)
            } else {
                subscriber.putCompletion()
            }
            return ActionDisposable {
                subscription.dispose()
                finish()
            }
        }
    }
}

enum AppLogEventLimits {
    static let eventBytes = 16 * 1024
    static let queueCount = 512
    static let queueBytes = 1024 * 1024
    static let lifetime: Double = 24 * 60 * 60
    static let futureTolerance: Double = 5 * 60
    static let requestTimeout: Double = 30

    static func accepts(time: Double, now: Double, bytes: Int) -> Bool {
        return time.isFinite && now.isFinite && bytes > 0 && bytes <= eventBytes && time >= now - lifetime && time <= now + futureTolerance
    }
}
