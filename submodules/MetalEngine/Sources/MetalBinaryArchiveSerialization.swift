import Foundation
import Metal
import ObjectiveC

/// Serializes binary archives so that a failure is thrown rather than crashing the process.
///
/// `serialize(to:)` ends by moving the file Metal compiled (`<target directory>/<UUID>.metallib`) over the target with
/// `-[NSFileManager replaceItemAtURL:withItemAtURL:backupItemName:options:resultingItemURL:error:]`. Metal makes that
/// call in the compiler's completion handler, on another thread, and keeps the error it reports without a reference of
/// its own: the error is freed when that thread's autorelease pool drains, and the thread that called `serialize(to:)`
/// then retains it and crashes (`objc_retain` in `-[_MTLBinaryArchive airntSerializeToURL:options:error:]`; seen on
/// iOS 26.3, reproduced on macOS 27). So whatever makes that move fail, such as the directory or Metal's file
/// disappearing or a target that cannot be replaced, is a crash instead of an error.
///
/// While a target is being serialized, the move into it is watched, and the error it fails with is kept alive until
/// `serialize(to:)` has returned. Every other use of that method passes straight through.
@available(macOS 11.0, iOS 14.0, *)
enum MetalBinaryArchiveSerialization {
    struct UnprotectedError: Error {
    }

    static func serialize(_ archive: MTLBinaryArchive, to url: URL) throws {
        // Without the hook, a failed move is a crash: rather not save at all.
        guard let failedMoveErrors = FailedMoveErrors.shared else {
            throw UnprotectedError()
        }
        failedMoveErrors.beginKeeping(forTarget: url)
        defer {
            failedMoveErrors.endKeeping(forTarget: url)
        }
        try archive.serialize(to: url)
    }
}

/// The errors of failed moves into the targets of the serializations in progress.
final class FailedMoveErrors {
    private typealias ReplaceItemImplementation = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?, UInt, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> ObjCBool
    private typealias ReplaceItemBlock = @convention(block) (AnyObject, AnyObject?, AnyObject?, AnyObject?, UInt, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> ObjCBool

    /// Nil when the move cannot be watched.
    static let shared: FailedMoveErrors? = FailedMoveErrors()

    private let lock = NSLock()
    /// By target path. A target is only serialized once at a time: the cache names each one with a new UUID.
    private var keptErrors: [String: [AnyObject]] = [:]

    private init?() {
        let selector = NSSelectorFromString("replaceItemAtURL:withItemAtURL:backupItemName:options:resultingItemURL:error:")
        guard let method = class_getInstanceMethod(FileManager.self, selector) else {
            return nil
        }
        let original = unsafeBitCast(method_getImplementation(method), to: ReplaceItemImplementation.self)
        let replacement: ReplaceItemBlock = { [unowned self] fileManager, originalItemUrl, newItemUrl, backupItemName, options, resultingItemUrl, error in
            let result = original(fileManager, selector, originalItemUrl, newItemUrl, backupItemName, options, resultingItemUrl, error)
            if !result.boolValue, let error, let path = (originalItemUrl as? NSURL)?.path {
                self.keepError(at: error, forTargetPath: path)
            }
            return result
        }
        method_setImplementation(method, imp_implementationWithBlock(unsafeBitCast(replacement, to: AnyObject.self)))
    }

    func beginKeeping(forTarget url: URL) {
        self.lock.lock()
        self.keptErrors[url.path] = []
        self.lock.unlock()
    }

    /// Releases what was kept for the target; whoever received the error holds its own reference by now.
    func endKeeping(forTarget url: URL) {
        self.lock.lock()
        let errors = self.keptErrors.removeValue(forKey: url.path)
        self.lock.unlock()
        // Released outside the lock.
        withExtendedLifetime(errors) {
        }
    }

    /// Called after a failed move, whose error slot is then written. Other callers' slots are never read.
    private func keepError(at slot: UnsafeMutableRawPointer, forTargetPath path: String) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard self.keptErrors[path] != nil, let error = slot.load(as: Unmanaged<AnyObject>?.self) else {
            return
        }
        // Still alive here: it is autoreleased into this thread's pool, which has not drained yet.
        self.keptErrors[path]?.append(error.takeUnretainedValue())
    }
}
