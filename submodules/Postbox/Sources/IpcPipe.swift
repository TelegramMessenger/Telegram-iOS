import Foundation
import SwiftSignalKit

func ipcNotify(basePath: String, data: Int64) {
    DispatchQueue.global(qos: .default).async {
        let path = basePath + ".ipc"
        let fd = open(path, open(path, O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR))
        if fd != -1 {
            var value = data
            write(fd, &value, 8)
            close(fd)
        }
    }
}

func ipcNotifications(basePath: String) -> Signal<Int64, Void> {
    return Signal { subscriber in
        let queue = Queue()
        let disposable = MetaDisposable()
        
        queue.async {
            let path = basePath + ".ipc"
            let fd = open(path, open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR))
            if fd != -1 {
                let readSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write])
                
                readSource.setEventHandler(handler: {
                    subscriber.putNext(Int64.max)
                    /*lseek(fd, 0, SEEK_SET)
                    var value: Int64 = 0
                    if read(fd, &value, 8) == 8 {
                        if previousValue != value {
                            previousValue = value
                            subscriber.putNext(value)
                        }
                    }*/
                })
                
                readSource.resume()
                
                disposable.set(ActionDisposable {
                    queue.async {
                        readSource.cancel()
                        close(fd)
                    }
                })
            } else {
                subscriber.putError(Void())
            }
        }
        
        return disposable
    }
}

