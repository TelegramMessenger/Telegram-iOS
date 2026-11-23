import Foundation

public enum SupportTemplatesFetchError: Error, Equatable {
    case network(String)
    case noData
    case http(Int)
    case tooLarge
}

public typealias SupportTemplatesFetch = (URL, @escaping (Result<Data, SupportTemplatesFetchError>) -> Void) -> Void

public let supportTemplatesMaxFileSize = 16 * 1024 * 1024

public func supportTemplatesUrlSessionFetch() -> SupportTemplatesFetch {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 30.0
    configuration.timeoutIntervalForResource = 30.0
    let session = URLSession(configuration: configuration)
    return { url, completion in
        session.downloadTask(with: url, completionHandler: { location, response, error in
            if let error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            if let response = response as? HTTPURLResponse, !(200 ..< 300).contains(response.statusCode) {
                completion(.failure(.http(response.statusCode)))
                return
            }
            guard let location else {
                completion(.failure(.noData))
                return
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int) ?? 0
            if size > supportTemplatesMaxFileSize {
                completion(.failure(.tooLarge))
                return
            }
            if let data = try? Data(contentsOf: location) {
                completion(.success(data))
            } else {
                completion(.failure(.noData))
            }
        }).resume()
    }
}

func supportTemplatesFetchUrl(_ string: String) -> URL? {
    guard let url = URL(string: string), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https", url.host != nil else {
        return nil
    }
    return url
}

public enum SupportTemplatesFileProblem: Error, Equatable {
    case wrongName
    case notText
    case noTemplates
    case tooLarge
}

public enum SupportTemplatesDownloadProblem: Equatable {
    case fetch(SupportTemplatesFetchError)
    case notText
    case noTemplates
}

public enum SupportTemplatesError: Equatable {
    case file(name: String, problem: SupportTemplatesFileProblem)
    case importFailed(name: String)
    case unreadable(name: String)
    case invalidUrl(name: String, url: String)
    case updateFailed(name: String, url: String, problem: SupportTemplatesDownloadProblem)
    case saveFailed(name: String)
}

private func parsedSupportTemplatesFile(_ data: Data) -> Result<SupportTemplatesFile, SupportTemplatesFileProblem> {
    if data.count > supportTemplatesMaxFileSize {
        return .failure(.tooLarge)
    }
    if String(data: data, encoding: .utf8) == nil {
        return .failure(.notText)
    }
    let file = parseSupportTemplatesFile(data)
    return file.isEmpty ? .failure(.noTemplates) : .success(file)
}

public struct SupportTemplatesFileInfo: Equatable {
    public let name: String
    public let templateCount: Int
    public let hasUrl: Bool
    public var editCount: Int = 0
}

public struct SupportTemplatesState: Equatable {
    public var files: [SupportTemplatesFileInfo] = []
    public var isReloading: Bool = false
    public var errors: [SupportTemplatesError] = []
}

public struct SupportTemplatesReloadResult: Equatable {
    public var errors: [SupportTemplatesError]
    public var updatedFiles: [String]
}

public final class SupportTemplatesManager {
    public final class ObserverToken {
        fileprivate init() {
        }
    }

    private let folderPath: String
    private let fetch: SupportTemplatesFetch
    private let notify: (String, SupportTemplatesDelta) -> Void
    private let log: (String) -> Void
    private let queue = DispatchQueue(label: "SupportTemplatesManager", qos: .utility)
    private let fileManager = FileManager()

    private let lock = NSLock()
    private var currentTemplates = SupportTemplates(files: [:])
    private var currentState = SupportTemplatesState()
    private var observers: [(token: ObserverToken, callback: (SupportTemplatesState) -> Void)] = []

    private var files: [String: SupportTemplatesFile] = [:]
    private var errors: [SupportTemplatesError] = []
    private var updatedFiles: [String] = []
    private var isRunning = false
    private var reloadAfterRun = false
    private var operationsAfterRun: [() -> Void] = []
    private var completions: [(SupportTemplatesReloadResult) -> Void] = []

    public init(folderPath: String, fetch: @escaping SupportTemplatesFetch, notify: @escaping (String, SupportTemplatesDelta) -> Void, log: @escaping (String) -> Void) {
        self.folderPath = folderPath
        self.fetch = fetch
        self.notify = notify
        self.log = log
    }

    public var templates: SupportTemplates {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.currentTemplates
    }

    public var state: SupportTemplatesState {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.currentState
    }

    public func addStateObserver(_ callback: @escaping (SupportTemplatesState) -> Void) -> ObserverToken {
        let token = ObserverToken()
        self.lock.lock()
        self.observers.append((token: token, callback: callback))
        let state = self.currentState
        self.lock.unlock()
        DispatchQueue.main.async {
            callback(state)
        }
        return token
    }

    public func removeStateObserver(_ token: ObserverToken) {
        self.lock.lock()
        self.observers.removeAll(where: { $0.token === token })
        self.lock.unlock()
    }

    public func reload(completion: ((SupportTemplatesReloadResult) -> Void)? = nil) {
        self.queue.async {
            if let completion {
                self.completions.append(completion)
            }
            if self.isRunning {
                self.reloadAfterRun = true
            } else {
                self.startRun()
            }
        }
    }

    public func importFiles(_ urls: [URL], completion: @escaping (SupportTemplatesReloadResult) -> Void) {
        self.whenIdle {
            var errors: [SupportTemplatesError] = []
            var imported = 0
            for url in urls {
                do {
                    try self.importFile(url)
                    imported += 1
                } catch let problem as SupportTemplatesFileProblem {
                    errors.append(.file(name: url.lastPathComponent, problem: problem))
                } catch {
                    errors.append(.importFailed(name: url.lastPathComponent))
                }
            }
            self.log("imported \(imported) of \(urls.count) files")
            if imported == 0 {
                let result = SupportTemplatesReloadResult(errors: errors, updatedFiles: [])
                DispatchQueue.main.async {
                    completion(result)
                }
                return
            }
            self.completions.append { result in
                completion(SupportTemplatesReloadResult(errors: errors + result.errors, updatedFiles: result.updatedFiles))
            }
            self.reloadAfterRun = true
        }
    }

    public func removeFile(name: String) {
        self.whenIdle {
            let path = self.path(of: name)
            try? self.fileManager.removeItem(atPath: path)
            try? self.fileManager.removeItem(atPath: path + ".old")
            self.files[name] = nil
            self.publish()
        }
    }

    private func whenIdle(_ operation: @escaping () -> Void) {
        self.queue.async {
            if self.isRunning {
                self.operationsAfterRun.append(operation)
            } else {
                operation()
                if self.reloadAfterRun {
                    self.startRun()
                }
            }
        }
    }

    private func path(of name: String) -> String {
        return self.folderPath + "/" + name
    }

    private func importFile(_ url: URL) throws {
        let name = url.lastPathComponent
        if !isSupportTemplatesFileName(name) {
            throw SupportTemplatesFileProblem.wrongName
        }
        let data = try Data(contentsOf: url)
        if case let .failure(problem) = parsedSupportTemplatesFile(data) {
            throw problem
        }
        try self.fileManager.createDirectory(atPath: self.folderPath, withIntermediateDirectories: true)
        try self.write(data, name: name)
    }

    private func write(_ data: Data, name: String) throws {
        let path = self.path(of: name)
        if self.fileManager.fileExists(atPath: path) {
            let old = path + ".old"
            if self.fileManager.fileExists(atPath: old) {
                try self.fileManager.removeItem(atPath: old)
            }
            try self.fileManager.copyItem(atPath: path, toPath: old)
        }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func startRun() {
        self.isRunning = true
        self.reloadAfterRun = false
        self.errors = []
        self.updatedFiles = []
        self.files = self.readFiles()
        self.publish()

        var requests: [(name: String, string: String, url: URL)] = []
        for (name, file) in self.files.sorted(by: { $0.key < $1.key }) where !file.url.isEmpty {
            if let url = supportTemplatesFetchUrl(file.url) {
                requests.append((name: name, string: file.url, url: url))
            } else {
                self.errors.append(.invalidUrl(name: name, url: file.url))
            }
        }
        self.log("read \(self.files.count) files, fetching \(requests.count)")
        if requests.isEmpty {
            self.finishRun()
            return
        }
        var remaining = requests.count
        for request in requests {
            self.fetch(request.url, { result in
                self.queue.async {
                    self.applyFetch(name: request.name, url: request.string, result: result)
                    remaining -= 1
                    if remaining == 0 {
                        self.finishRun()
                    }
                }
            })
        }
    }

    private func readFiles() -> [String: SupportTemplatesFile] {
        var result: [String: SupportTemplatesFile] = [:]
        let names = (try? self.fileManager.contentsOfDirectory(atPath: self.folderPath)) ?? []
        for name in names.sorted() where isSupportTemplatesFileName(name) {
            guard let data = self.fileManager.contents(atPath: self.path(of: name)) else {
                self.errors.append(.unreadable(name: name))
                continue
            }
            switch parsedSupportTemplatesFile(data) {
            case let .success(file):
                result[name] = file
            case let .failure(problem):
                self.errors.append(.file(name: name, problem: problem))
            }
        }
        return result
    }

    private func applyFetch(name: String, url: String, result: Result<Data, SupportTemplatesFetchError>) {
        guard let existing = self.files[name] else {
            return
        }
        let failure: (SupportTemplatesDownloadProblem) -> Void = { problem in
            self.errors.append(.updateFailed(name: name, url: url, problem: problem))
            self.log("'\(name)' update failed")
        }
        let data: Data
        switch result {
        case let .failure(error):
            failure(.fetch(error))
            return
        case let .success(value):
            data = value
        }
        let downloaded: SupportTemplatesFile
        switch parsedSupportTemplatesFile(data) {
        case let .success(file) where !file.questions.isEmpty:
            downloaded = file
        case .failure(.notText):
            failure(.notText)
            return
        default:
            failure(.noTemplates)
            return
        }
        let merged = supportTemplatesFileKeepingOwnData(downloaded: downloaded, existing: existing)
        let delta = supportTemplatesDelta(was: existing, now: merged)
        self.log("'\(name)' fetched: \(delta.added.count) added, \(delta.changed.count) changed, \(delta.removed.count) removed")
        if !delta.isEmpty {
            do {
                try self.write(supportTemplatesRewrittenFile(downloaded: data, url: existing.url, ownKeys: delta.keys), name: name)
            } catch {
                self.errors.append(.saveFailed(name: name))
                return
            }
            self.notify(name, delta)
            self.updatedFiles.append(name)
        }
        self.files[name] = merged
    }

    private func finishRun() {
        self.isRunning = false
        let operations = self.operationsAfterRun
        self.operationsAfterRun = []
        for operation in operations {
            operation()
        }
        if self.reloadAfterRun {
            self.startRun()
            return
        }
        self.publish()
        let result = SupportTemplatesReloadResult(errors: self.errors, updatedFiles: self.updatedFiles)
        let completions = self.completions
        self.completions = []
        if !completions.isEmpty {
            DispatchQueue.main.async {
                for completion in completions {
                    completion(result)
                }
            }
        }
    }

    private func publish() {
        let templates = SupportTemplates(files: self.files)
        var state = SupportTemplatesState()
        state.files = self.files.sorted(by: { $0.key < $1.key }).map { SupportTemplatesFileInfo(name: $0.key, templateCount: $0.value.questions.count, hasUrl: !$0.value.url.isEmpty) }
        state.isReloading = self.isRunning
        state.errors = self.errors

        self.lock.lock()
        self.currentTemplates = templates
        let changed = self.currentState != state
        self.currentState = state
        let callbacks = self.observers.map(\.callback)
        self.lock.unlock()

        if changed {
            DispatchQueue.main.async {
                for callback in callbacks {
                    callback(state)
                }
            }
        }
    }
}
