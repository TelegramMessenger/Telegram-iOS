import Foundation

/// Keeps harness-owned objects alive for the life of the process.
///
/// **Why this exists, once, so it is not re-derived at each call site.** Telegram's storage stack
/// holds `ManagedFile`s that assert they are freed on their own queue
/// (`ManagedFile/Sources/ManagedFile.swift:53`). Releasing a live `Account`, or anything owning a
/// media/animation cache built from one, therefore kills the process whenever the last reference
/// happens to expire on some other thread — which is exactly what an ordinary `let` going out of
/// scope at the end of a test method does. The failure surfaces as a bare "Assertion failed"
/// naming nothing, and costs an hour every time.
///
/// The harness app builds one account and one context and keeps them until it exits, so making
/// that explicit costs nothing and matches how the real app behaves. Registering here is a
/// statement that the object is process-scoped, not an accident of who holds a reference.
public enum HarnessProcessRetainer {
    private static let lock = NSLock()
    private static var objects: [AnyObject] = []

    public static func retain(_ object: AnyObject) {
        self.lock.lock()
        self.objects.append(object)
        self.lock.unlock()
    }
}
