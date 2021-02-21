import Foundation
import SwiftSignalKit

private final class TempBoxFileContext {
    let directory: String
    let fileName: String
    var subscribers = Set<Int>()
    
    var path: String {
        if self.fileName.isEmpty {
            return self.directory
        } else {
            return self.directory + "/" + self.fileName
        }
    }
    
    init(directory: String, fileName: String) {
        self.directory = directory
        self.fileName = fileName
    }
}

private struct TempBoxKey: Equatable, Hashable {
    let path: String?
    let fileName: String
    let uniqueId: Int?
}

public final class TempBoxFile {
    fileprivate let key: TempBoxKey
    fileprivate let id: Int
    public let path: String
    
    fileprivate init(key: TempBoxKey, id: Int, path: String) {
        self.key = key
        self.id = id
        self.path = path
    }
}

public final class TempBoxDirectory {
    fileprivate let key: TempBoxKey
    fileprivate let id: Int
    public let path: String
    
    fileprivate init(key: TempBoxKey, id: Int, path: String) {
        self.key = key
        self.id = id
        self.path = path
    }
}

private final class TempBoxContexts {
    private var nextId: Int = 0
    private var contexts: [TempBoxKey: TempBoxFileContext] = [:]
    
    func file(basePath: String, path: String, fileName: String) -> TempBoxFile {
        let key = TempBoxKey(path: path, fileName: fileName, uniqueId: nil)
        let context: TempBoxFileContext
        if let current = self.contexts[key] {
            context = current
        } else {
            let id = self.nextId
            self.nextId += 1
            let dirName = "\(id)"
            let dirPath = basePath + "/" + dirName
            var cleanName = fileName
            if cleanName.hasPrefix("..") {
                cleanName = "__" + String(cleanName[cleanName.index(cleanName.startIndex, offsetBy: 2)])
            }
            cleanName = cleanName.replacingOccurrences(of: "/", with: "_")
            context = TempBoxFileContext(directory: dirPath, fileName: cleanName)
            self.contexts[key] = context
            let _ = try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
            let _ = try? FileManager.default.linkItem(atPath: path, toPath: context.path)
        }
        let id = self.nextId
        self.nextId += 1
        context.subscribers.insert(id)
        return TempBoxFile(key: key, id: id, path: context.path)
    }
    
    func tempFile(basePath: String, fileName: String) -> TempBoxFile {
        let id = self.nextId
        self.nextId += 1
        
        let key = TempBoxKey(path: nil, fileName: fileName, uniqueId: id)
        let context: TempBoxFileContext
        
        let dirName = "\(id)"
        let dirPath = basePath + "/" + dirName
        var cleanName = fileName
        if cleanName.hasPrefix("..") {
            cleanName = "__" + String(cleanName[cleanName.index(cleanName.startIndex, offsetBy: 2)])
        }
        cleanName = cleanName.replacingOccurrences(of: "/", with: "_")
        context = TempBoxFileContext(directory: dirPath, fileName: cleanName)
        self.contexts[key] = context
        let _ = try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
    
        context.subscribers.insert(id)
        return TempBoxFile(key: key, id: id, path: context.path)
    }
    
    func tempDirectory(basePath: String) -> TempBoxDirectory {
        let id = self.nextId
        self.nextId += 1
        
        let key = TempBoxKey(path: nil, fileName: "", uniqueId: id)
        let context: TempBoxFileContext
        
        let dirName = "\(id)"
        let dirPath = basePath + "/" + dirName
        context = TempBoxFileContext(directory: dirPath, fileName: "")
        self.contexts[key] = context
        let _ = try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
    
        context.subscribers.insert(id)
        return TempBoxDirectory(key: key, id: id, path: context.path)
    }
    
    func dispose(_ file: TempBoxFile) -> [String] {
        if let context = self.contexts[file.key] {
            context.subscribers.remove(file.id)
            if context.subscribers.isEmpty {
                self.contexts.removeValue(forKey: file.key)
                return [context.directory]
            }
        }
        return []
    }
    
    func dispose(_ directory: TempBoxDirectory) -> [String] {
        if let context = self.contexts[directory.key] {
            context.subscribers.remove(directory.id)
            if context.subscribers.isEmpty {
                self.contexts.removeValue(forKey: directory.key)
                return [context.directory]
            }
        }
        return []
    }
}

private var sharedValue: TempBox?

public final class TempBox {
    private let basePath: String
    private let processType: String
    private let launchSpecificId: Int64
    private let currentBasePath: String
    
    private let contexts = Atomic<TempBoxContexts>(value: TempBoxContexts())
    
    public static func initializeShared(basePath: String, processType: String, launchSpecificId: Int64) {
        sharedValue = TempBox(basePath: basePath, processType: processType, launchSpecificId: launchSpecificId)
    }
    
    public static var shared: TempBox {
        return sharedValue!
    }
    
    private init(basePath: String, processType: String, launchSpecificId: Int64) {
        self.basePath = basePath
        self.processType = processType
        self.launchSpecificId = launchSpecificId
        
        self.currentBasePath = basePath + "/temp/" + processType + "/temp-" + String(UInt64(bitPattern: launchSpecificId), radix: 16)
        self.cleanupPreviousLaunches(path: basePath + "/temp/" + processType, currentLaunchSpecificId: launchSpecificId)
    }
    
    private func cleanupPreviousLaunches(path: String, currentLaunchSpecificId: Int64) {
        DispatchQueue.global(qos: .background).async {
            let currentName = "temp-" + String(UInt64(bitPattern: currentLaunchSpecificId), radix: 16)
            if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [], options: []) {
                for url in files {
                    if url.lastPathComponent.hasPrefix("temp-") && url.lastPathComponent != currentName {
                        let _ = try? FileManager.default.removeItem(atPath: url.path)
                    }
                }
            }
        }
    }
    
    public func file(path: String, fileName: String) -> TempBoxFile {
        return self.contexts.with { contexts in
            return contexts.file(basePath: self.currentBasePath, path: path, fileName: fileName)
        }
    }
    
    public func tempFile(fileName: String) -> TempBoxFile {
        return self.contexts.with { contexts in
            return contexts.tempFile(basePath: self.currentBasePath, fileName: fileName)
        }
    }
    
    public func tempDirectory() -> TempBoxDirectory {
        return self.contexts.with { contexts in
            return contexts.tempDirectory(basePath: self.currentBasePath)
        }
    }
    
    public func dispose(_ file: TempBoxFile) {
        let removePaths = self.contexts.with { contexts in
            return contexts.dispose(file)
        }
        if !removePaths.isEmpty {
            DispatchQueue.global(qos: .background).async {
                for path in removePaths {
                    let _ = try? FileManager.default.removeItem(atPath: path)
                }
            }
        }
    }
    
    public func dispose(_ directory: TempBoxDirectory) {
        let removePaths = self.contexts.with { contexts in
            return contexts.dispose(directory)
        }
        if !removePaths.isEmpty {
            DispatchQueue.global(qos: .background).async {
                for path in removePaths {
                    let _ = try? FileManager.default.removeItem(atPath: path)
                }
            }
        }
    }
}
