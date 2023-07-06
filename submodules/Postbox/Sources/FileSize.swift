import SwiftSignalKit

import Foundation

public func fileSize(_ path: String, useTotalFileAllocatedSize: Bool = false) -> Int64? {
    if useTotalFileAllocatedSize {
        let url = URL(fileURLWithPath: path, isDirectory: false)
        if let values = (try? url.resourceValues(forKeys: Set([.isRegularFileKey, .totalFileAllocatedSizeKey]))) {
            if values.isRegularFile ?? false {
                if let fileSize = values.totalFileAllocatedSize {
                    return Int64(fileSize)
                }
            }
        }
    }
    
    var value = stat()
    if stat(path, &value) == 0 {
        return value.st_size
    } else {
        return nil
    }
}

func fileSizeChangeNotifier(path: String, queue: Queue) -> Signal<Void, NoError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        
        queue.async {
            let fd = open(path, O_EVTONLY)
            if fd != -1 {
                let readSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.extend], queue: queue.queue)
                
                readSource.setEventHandler(handler: {
                    assert(queue.isCurrent())
                    subscriber.putNext(Void())
                })
                
                readSource.resume()
                
                disposable.set(ActionDisposable {
                    queue.async {
                        readSource.cancel()
                        close(fd)
                    }
                })
            } else {
                assertionFailure()
            }
        }
        
        return disposable
    }
}
