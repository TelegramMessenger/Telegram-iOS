import Foundation
import TelegramCorePrivateModule
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

private let queue = DispatchQueue(label: "org.telegram.Telegram.trace", qos: .utility)

public func trace2(_ what: @autoclosure() -> String) {
    let string = what()
    var rawTime = time_t()
    time(&rawTime)
    var timeinfo = tm()
    localtime_r(&rawTime, &timeinfo)
    
    var curTime = timeval()
    gettimeofday(&curTime, nil)
    let milliseconds = curTime.tv_usec / 1000
    
    //queue.async {
        let result = String(format: "%d-%d-%d %02d:%02d:%03d %@", arguments: [Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(milliseconds), string])
        print(result)
    //}
}

public func trace1(_ domain: String, what: @autoclosure() -> String) {
    let string = what()
    var rawTime = time_t()
    time(&rawTime)
    var timeinfo = tm()
    localtime_r(&rawTime, &timeinfo)
    
    var curTime = timeval()
    gettimeofday(&curTime, nil)
    let seconds = curTime.tv_sec
    let milliseconds = curTime.tv_usec / 1000
    
    queue.async {
        let result = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [domain, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(seconds), Int(milliseconds), string])
        
        print(result)
    }
}

public func registerLoggingFunctions() {
    setBridgingTraceFunction({ domain, what in
        if let what = what {
            if let domain = domain {
                Logger.shared.log(domain, what as String)
            } else {
                Logger.shared.log("", what as String)
            }
        }
    })
}

private var sharedLogger: Logger?

public final class Logger {
    private let queue = DispatchQueue(label: "org.telegram.Telegram.log", qos: .utility)
    private let maxLength: Int = 2 * 1024 * 1024
    //private let maxLength: Int = 4 * 1024
    private let maxFiles: Int = 20
    
    private let basePath: String
    private var file: (Int32, Int)?
    
    public static func setSharedLogger(_ logger: Logger) {
        sharedLogger = logger
    }
    
    public static var shared: Logger {
        return sharedLogger!
    }
    
    public init(basePath: String) {
        self.basePath = basePath
    }
    
    public func collectLogs() -> Signal<[(String, String)], NoError> {
        return Signal { subscriber in
            self.queue.async {
                var result: [(String, String)] = []
                if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: self.basePath), includingPropertiesForKeys: [URLResourceKey.creationDateKey], options: []) {
                    for url in files {
                        if url.lastPathComponent.hasPrefix("log-") {
                            result.append((url.lastPathComponent, url.path))
                        }
                    }
                }
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
    }
    
    public func log(_ tag: String, _ what: @autoclosure () -> String) {
        let string = what()
        
        var rawTime = time_t()
        time(&rawTime)
        var timeinfo = tm()
        localtime_r(&rawTime, &timeinfo)
        
        var curTime = timeval()
        gettimeofday(&curTime, nil)
        let milliseconds = curTime.tv_usec / 1000
        
        #if TARGET_IPHONE_SIMULATOR || DEBUG
        let content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
        
        print(content)
        #endif
        
        self.queue.async {
            #if !(TARGET_IPHONE_SIMULATOR || DEBUG)
                let content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
            #endif
            
            var fd: Int32?
            var openNew = false
            if let (file, length) = self.file {
                if length >= self.maxLength {
                    close(file)
                    openNew = true
                } else {
                    fd = file
                }
            } else {
                openNew = true
            }
            if openNew {
                let _ = try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
                
                var createNew = false
                if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: self.basePath), includingPropertiesForKeys: [URLResourceKey.creationDateKey], options: []) {
                    var minCreationDate: (Date, URL)?
                    var maxCreationDate: (Date, URL)?
                    var count = 0
                    for url in files {
                        if url.lastPathComponent.hasPrefix("log-") {
                            if let values = try? url.resourceValues(forKeys: Set([URLResourceKey.creationDateKey])), let creationDate = values.creationDate {
                                count += 1
                                if minCreationDate == nil || minCreationDate!.0 > creationDate {
                                    minCreationDate = (creationDate, url)
                                }
                                if maxCreationDate == nil || maxCreationDate!.0 < creationDate {
                                    maxCreationDate = (creationDate, url)
                                }
                            }
                        }
                    }
                    if let (_, url) = minCreationDate, count >= self.maxFiles {
                        let _ = try? FileManager.default.removeItem(at: url)
                    }
                    if let (_, url) = maxCreationDate {
                        var value = stat()
                        if stat(url.path, &value) == 0 && Int(value.st_size) < self.maxLength {
                            let handle = open(url.path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
                            if handle >= 0 {
                                fd = handle
                                self.file = (handle, Int(value.st_size))
                            }
                        } else {
                            createNew = true
                        }
                    } else {
                        createNew = true
                    }
                }
                
                if createNew {
                    let fileName = String(format: "log-%d-%d-%d_%02d-%02d-%02d.%03d.txt", arguments: [Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds)])
                    
                    let path = self.basePath + "/" + fileName
                    
                    let handle = open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
                    if handle >= 0 {
                        fd = handle
                        self.file = (handle, 0)
                    }
                }
            }
            
            if let fd = fd {
                if let data = content.data(using: .utf8) {
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        write(fd, bytes, data.count)
                    }
                    var newline: UInt8 = 0x0a
                    write(fd, &newline, 1)
                    if let file = self.file {
                        self.file = (file.0, file.1 + data.count)
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
    }
}
