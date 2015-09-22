import Foundation
import SwiftSignalKit
import Display

public struct MediaKeyStatus {
    let size: Int
}

private final class MediaBoxMutexEntry {
    var mutex = pthread_mutex_t()
    
    init() {
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(&mutex, &attr)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func with(@noescape f: Void -> Void) {
        pthread_mutex_lock(&self.mutex)
        f()
        pthread_mutex_unlock(&self.mutex)
    }
}

public final class MediaBox {
    let basePath: String
    let buffer = WriteBuffer()
    
    private var mutexEntriesLock = OSSpinLock()
    private var mutexEntries: [String : MediaBoxMutexEntry] = [:]
    
    lazy var ensureDirectoryCreated: Void = {
        try! NSFileManager.defaultManager().createDirectoryAtPath(self.basePath, withIntermediateDirectories: true, attributes: nil)
    }()
    
    public init(basePath: String) {
        self.basePath = basePath
    }
    
    private func keyForId(id: MediaId, key: MemoryBuffer) -> String {
        let string = NSMutableString()
        string.appendFormat("%d", Int(id.namespace))
        string.appendFormat("_%lld", Int64(id.id))
        string.appendString("_\(key)")
        return string as String
    }
    
    private func pathForId(id: MediaId, key: MemoryBuffer) -> String {
        return "\(self.basePath)/\(self.keyForId(id, key: key))"
    }
    
    private func mutexForKey(key: String) -> MediaBoxMutexEntry {
        let entry: MediaBoxMutexEntry
        
        OSSpinLockLock(&mutexEntriesLock)
        if let existingEntry = self.mutexEntries[key] {
            entry = existingEntry
        } else {
            entry = MediaBoxMutexEntry()
            self.mutexEntries[key] = entry
        }
        OSSpinLockUnlock(&mutexEntriesLock)
        
        return entry
    }
    
    func writeId(id: MediaId, key: ReadBuffer, value: NSData) {
        assertNotOnMainThread()
        self.mutexForKey(self.keyForId(id, key: key)).with {
            let _ = self.ensureDirectoryCreated
            value.writeToFile(self.pathForId(id, key: key), atomically: false)
        }
    }
    
    private func status(id: MediaId, key: ReadBuffer) -> MediaKeyStatus? {
        assertNotOnMainThread()
        var value = stat()
        stat(self.pathForId(id, key: key), &value)
        return MediaKeyStatus(size: Int(value.st_size))
    }
    
    private func read(id: MediaId, key: ReadBuffer) -> NSData? {
        assertNotOnMainThread()
        var data: NSData?
        do {
            data = try NSData(contentsOfFile: self.pathForId(id, key: key), options: NSDataReadingOptions.DataReadingMappedIfSafe)
        } catch _ {
        }
        return data
    }
    
    public func data(id: MediaId, key: ReadBuffer, size: Int, fetch: ((NSData, Int) -> Signal<NSData, NoError>)?) -> Signal<NSData, NoError> {
        return Signal { subscriber in
            var cancelled = false
            let disposable = MetaDisposable()
            disposable.set(ActionDisposable {
                cancelled = true
            })
            
            self.mutexForKey(self.keyForId(id, key: key)).with {
                if cancelled {
                    return
                }
                
                let status = self.status(id, key: key) ?? MediaKeyStatus(size: 0)
                
                var currentData: NSData?
                if status.size > 0 {
                    if let data = self.read(id, key: key) {
                        currentData = data
                        subscriber.putNext(data)
                    }
                }
                
                if status.size < size {
                    if let fetch = fetch {
                        disposable.set(fetch(currentData ?? NSData(), status.size).start(next: { [weak self] next in
                            if let strongSelf = self {
                                strongSelf.mutexForKey(strongSelf.keyForId(id, key: key)).with {
                                    strongSelf.writeId(id, key: key, value: next)
                                }
                            }
                            subscriber.putNext(next)
                        }, error: { error in
                            subscriber.putError(error)
                        }, completed: {
                            subscriber.putCompletion()
                        }))
                    } else {
                        subscriber.putError(NoError())
                    }
                } else {
                    subscriber.putCompletion()
                }
            }
            
            return disposable
        }
    }
}
