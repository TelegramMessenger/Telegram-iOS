import Foundation
import TelegramCorePrivateModule
#if os(macOS)
    import SwiftSignalKitMac
    import PostboxMac
#else
    import SwiftSignalKit
    import Postbox
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
        let result = String(format: "%d-%d-%d %02d:%02d:%03d %@", arguments: [Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(milliseconds), string])
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
        let result = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [domain, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(seconds), Int(milliseconds), string])
        
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
    private let queue = Queue(name: "org.telegram.Telegram.log", qos: .utility)
    private let maxLength: Int = 2 * 1024 * 1024
    private let maxFiles: Int = 20
    
    private let basePath: String
    private var file: (ManagedFile, Int)?
    
    public var logToFile: Bool = true {
        didSet {
            let oldEnabled = self.logToConsole || oldValue
            let newEnabled = self.logToConsole || self.logToFile
            if oldEnabled != newEnabled {
                NetworkSetLoggingEnabled(newEnabled)
            }
        }
    }
    public var logToConsole: Bool = true {
        didSet {
            let oldEnabled = self.logToFile || oldValue
            let newEnabled = self.logToFile || self.logToConsole
            if oldEnabled != newEnabled {
                NetworkSetLoggingEnabled(newEnabled)
            }
        }
    }
    public var redactSensitiveData: Bool = true
    
    public static func setSharedLogger(_ logger: Logger) {
        sharedLogger = logger
        setPostboxLogger({ s in
            Logger.shared.log("Postbox", s)
        })
    }
    
    public static var shared: Logger {
        if let sharedLogger = sharedLogger {
            return sharedLogger
        } else {
            assertionFailure()
            let tempLogger = Logger(basePath: "")
            tempLogger.logToFile = false
            tempLogger.logToConsole = false
            return tempLogger
        }
    }
    
    public init(basePath: String) {
        self.basePath = basePath
        //self.logToConsole = false
    }
    
    public func collectLogs() -> Signal<[(String, String)], NoError> {
        return Signal { subscriber in
            self.queue.async {
                var result: [(Date, String, String)] = []
                if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: self.basePath), includingPropertiesForKeys: [URLResourceKey.creationDateKey], options: []) {
                    for url in files {
                        if url.lastPathComponent.hasPrefix("log-") {
                            if let creationDate = (try? url.resourceValues(forKeys: Set([.creationDateKey])))?.creationDate {
                                result.append((creationDate, url.lastPathComponent, url.path))
                            }
                        }
                    }
                }
                result.sort(by: { $0.0 < $1.0 })
                subscriber.putNext(result.map { ($0.1, $0.2) })
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
    }
    
    public func log(_ tag: String, _ what: @autoclosure () -> String) {
        if !self.logToFile && !self.logToConsole {
            return
        }
        
        let string = what()
        
        var rawTime = time_t()
        time(&rawTime)
        var timeinfo = tm()
        localtime_r(&rawTime, &timeinfo)
        
        var curTime = timeval()
        gettimeofday(&curTime, nil)
        let milliseconds = curTime.tv_usec / 1000
        
        var consoleContent: String?
        if self.logToConsole {
            let content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
            consoleContent = content
            print(content)
        }
        
        if self.logToFile {
            self.queue.async {
                let content: String
                if let consoleContent = consoleContent {
                    content = consoleContent
                } else {
                    content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
                }
                
                var currentFile: ManagedFile?
                var openNew = false
                if let (file, length) = self.file {
                    if length >= self.maxLength {
                        self.file = nil
                        openNew = true
                    } else {
                        currentFile = file
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
                                if let file = ManagedFile(queue: self.queue, path: url.path, mode: .append) {
                                    self.file = (file, Int(value.st_size))
                                    currentFile = file
                                }
                            } else {
                                createNew = true
                            }
                        } else {
                            createNew = true
                        }
                    }
                    
                    if createNew {
                        let fileName = String(format: "log-%d-%d-%d_%02d-%02d-%02d.%03d.txt", arguments: [Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds)])
                        
                        let path = self.basePath + "/" + fileName
                        
                        if let file = ManagedFile(queue: self.queue, path: path, mode: .append) {
                            self.file = (file, 0)
                            currentFile = file
                        }
                    }
                }
                
                if let currentFile = currentFile {
                    if let data = content.data(using: .utf8) {
                        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                            let _ = currentFile.write(bytes, count: data.count)
                        }
                        var newline: UInt8 = 0x0a
                        let _ = currentFile.write(&newline, count: 1)
                        if let file = self.file {
                            self.file = (file.0, file.1 + data.count + 1)
                        } else {
                            assertionFailure()
                        }
                    }
                }
            }
        }
    }
}
