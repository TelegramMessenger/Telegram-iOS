// Logging
import Foundation
import TelegramCore

enum NGManagedFileMode {
    case read
    case readwrite
    case append
}

private func wrappedWrite(_ fd: Int32, _ data: UnsafeRawPointer, _ count: Int) -> Int {
    return write(fd, data, count)
}

private func wrappedRead(_ fd: Int32, _ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
    return read(fd, data, count)
}

final class NGManagedFile {
    private let fd: Int32
    private let mode: NGManagedFileMode
    
    init?(path: String, mode: NGManagedFileMode) {
        self.mode = mode
        let fileMode: Int32
        let accessMode: UInt16
        switch mode {
        case .read:
            fileMode = O_RDONLY
            accessMode = S_IRUSR
        case .readwrite:
            fileMode = O_RDWR | O_CREAT
            accessMode = S_IRUSR | S_IWUSR
        case .append:
            fileMode = O_WRONLY | O_CREAT | O_APPEND
            accessMode = S_IRUSR | S_IWUSR
        }
        let fd = open(path, fileMode, accessMode)
        if fd >= 0 {
            self.fd = fd
        } else {
            return nil
        }
    }
    
    deinit {
        close(self.fd)
    }
    
    func write(_ data: UnsafeRawPointer, count: Int) -> Int {
        return wrappedWrite(self.fd, data, count)
    }
    
    func read(_ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
        return wrappedRead(self.fd, data, count)
    }
    
    func readData(count: Int) -> Data {
        var result = Data(count: count)
        result.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Void in
            let readCount = self.read(bytes, count)
            assert(readCount == count)
        }
        return result
    }
    
    func seek(position: Int64) {
        lseek(self.fd, position, SEEK_SET)
    }
    
    func truncate(count: Int64) {
        ftruncate(self.fd, count)
    }
    
    func getSize() -> Int? {
        var value = stat()
        if fstat(self.fd, &value) == 0 {
            return Int(value.st_size)
        } else {
            return nil
        }
    }
    
    func sync() {
        fsync(self.fd)
    }
}


public var ngLogger: NGLogger?

public final class NGLogger {
    private let maxLength: Int = 2 * 1024 * 1024
    private let maxFiles: Int = 20
    
    private let basePath: String
    private var file: (NGManagedFile, Int)?
    
    var logToFile: Bool = true
    var logToConsole: Bool = true
    
    public static func setSharedLogger(_ logger: NGLogger) {
        ngLogger = logger
    }
    
    public static var shared: NGLogger {
        if let ngLogger = ngLogger {
            return ngLogger
        } else {
            assertionFailure()
            let tempLogger = NGLogger(basePath: "")
            tempLogger.logToFile = false
            tempLogger.logToConsole = false
            return tempLogger
        }
    }
    
    public init(basePath: String) {
        self.basePath = basePath
        //self.logToConsole = false
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
            let content: String
            if let consoleContent = consoleContent {
                content = consoleContent
            } else {
                content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
            }
            
            var currentFile: NGManagedFile?
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
                            if let file = NGManagedFile(path: url.path, mode: .append) {
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
                    
                    if let file = NGManagedFile(path: path, mode: .append) {
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


public func ngLog(_ text: String, _ tag: String = "NG") {
    let baseAppBundleId = Bundle.main.bundleIdentifier!
    let appGroupName = "group.\(baseAppBundleId)"
    let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    
    if let appGroupUrl = maybeAppGroupUrl {
        let rootPath = appGroupUrl.path + "/telegram-data"
        
        if ngLogger == nil {
            let logsPath = rootPath + "/ngLogs"
            NGLogger.setSharedLogger(NGLogger(basePath: logsPath))
        }
    } else {
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            Logger.shared.log(tag + " (Main Logger)", text)
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        if let appGroupUrl = maybeAppGroupUrl {
            let rootPath = appGroupUrl.path + "/telegram-data"
            
            if ngLogger == nil {
                let logsPath = rootPath + "/ngLogs"
                NGLogger.setSharedLogger(NGLogger(basePath: logsPath))
            }
        } else {
            Logger.shared.log(tag + " (Main Logger)", text)
        }
    }
    
    
    NGLogger.shared.log(tag, text)
}
