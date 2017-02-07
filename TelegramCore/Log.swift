import Foundation
import TelegramCorePrivateModule

private let queue = DispatchQueue(label: "org.telegram.Telegram.trace", qos: .utility)

public func trace(_ what: @autoclosure() -> String) {
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

public func trace(_ domain: String, what: @autoclosure() -> String) {
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
                trace(domain, what: what as String)
            } else {
                trace("", what: what as String)
            }
        }
    })
}

public final class Logger {
    private let queue = DispatchQueue(label: "org.telegram.Telegram.log", qos: .utility)
    private let maxLength: Int = 512 * 1024
    private let maxFiles: Int = 20
    
    private let basePath: String
    private var file: (Int32, Int)?
    
    init(basePath: String) {
        self.basePath = basePath
    }
    
    func log(_ tag: String, _ what: @autoclosure () -> String) {
        let string = what()
        
        var rawTime = time_t()
        time(&rawTime)
        var timeinfo = tm()
        localtime_r(&rawTime, &timeinfo)
        
        var curTime = timeval()
        gettimeofday(&curTime, nil)
        let seconds = curTime.tv_sec
        let milliseconds = curTime.tv_usec / 1000
        
        let content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(seconds), Int(milliseconds), string])
        
        self.queue.async {
            var fd: Int32?
            var createNew = false
            if let (file, length) = self.file {
                if length < self.maxLength {
                    close(file)
                    createNew = true
                } else {
                    fd = file
                }
            } else {
                let _ = try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
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
            }
            if createNew {
                let path = self.basePath + "/log-\(Date()).txt"
                
                let handle = open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
                if handle >= 0 {
                    fd = handle
                    self.file = (handle, 0)
                }
            }
            
            if let fd = fd {
                if let data = content.data(using: .utf8) {
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        write(fd, bytes, data.count)
                    }
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
