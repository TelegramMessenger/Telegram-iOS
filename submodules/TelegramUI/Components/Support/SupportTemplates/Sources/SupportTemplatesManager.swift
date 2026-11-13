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
    public var url: String = ""
}

public enum SupportTemplatesFileChangeError: Error, Equatable {
    case wrongName
    case nameTaken
    case fileMissing
    case invalidUrl
    case fetch(SupportTemplatesFetchError)
    case notText
    case noTemplates
    case saveFailed
}

public func supportTemplatesFileNameNormalized(_ name: String) -> String {
    var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !result.lowercased().hasPrefix("tl_") {
        result = "tl_" + result
    }
    if !result.lowercased().hasSuffix(".txt") {
        result += ".txt"
    }
    return result
}

private func supportTemplatesFileNameIsValid(_ name: String) -> Bool {
    return isSupportTemplatesFileName(name) && !name.contains("/") && name.lowercased() != "tl_.txt"
}

public struct SupportTemplatesState: Equatable {
    public var files: [SupportTemplatesFileInfo] = []
    public var ownTemplateCount: Int = 0
    public var revision: Int = 0
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
    private var currentFiles: [String: SupportTemplatesFile] = [:]
    private var currentEdits: [String: [String: SupportTemplateEdit]] = [:]
    private var currentOwn: [SupportOwnTemplate] = []
    private var observers: [(token: ObserverToken, callback: (SupportTemplatesState) -> Void)] = []

    private var files: [String: SupportTemplatesFile] = [:]
    private var edits: [String: [String: SupportTemplateEdit]] = [:]
    private var own: [SupportOwnTemplate] = []
    private var errors: [SupportTemplatesError] = []
    private var updatedFiles: [String] = []
    private var isRunning = false
    private var revision = 0
    private var reloadAfterRun = false
    private var operationsAfterRun: [() -> Void] = []
    private var completions: [(SupportTemplatesReloadResult) -> Void] = []

    public init(folderPath: String, fetch: @escaping SupportTemplatesFetch, notify: @escaping (String, SupportTemplatesDelta) -> Void, log: @escaping (String) -> Void) {
        self.folderPath = folderPath
        self.fetch = fetch
        self.notify = notify
        self.log = log
        self.queue.async {
            self.loadLocal()
        }
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

    public func changeFile(name: String, newName: String, url: String, completion: @escaping (Result<Void, SupportTemplatesFileChangeError>) -> Void) {
        let finish: (Result<Void, SupportTemplatesFileChangeError>) -> Void = { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.whenIdle {
            guard let existing = self.files[name] else {
                finish(.failure(.fileMissing))
                return
            }
            if let problem = self.renameProblem(name: name, newName: newName) {
                finish(.failure(problem))
                return
            }
            if utf16Equal(url, existing.url) || url.isEmpty {
                self.applyFileChange(name: name, newName: newName, url: url, downloaded: nil, finish: finish)
                return
            }
            guard let fetchUrl = supportTemplatesFetchUrl(url) else {
                finish(.failure(.invalidUrl))
                return
            }
            self.log("verifying a new URL for '\(name)'")
            self.fetch(fetchUrl, { result in
                switch result {
                case let .failure(error):
                    finish(.failure(.fetch(error)))
                case let .success(data):
                    switch parsedSupportTemplatesFile(data) {
                    case let .success(file) where !file.questions.isEmpty:
                        self.whenIdle {
                            self.applyFileChange(name: name, newName: newName, url: url, downloaded: data, finish: finish)
                        }
                    case .failure(.notText):
                        finish(.failure(.notText))
                    default:
                        finish(.failure(.noTemplates))
                    }
                }
            })
        }
    }

    private func renameProblem(name: String, newName: String) -> SupportTemplatesFileChangeError? {
        if newName == name {
            return nil
        }
        if !supportTemplatesFileNameIsValid(newName) {
            return .wrongName
        }
        let taken = self.files.keys.contains(where: { $0.lowercased() == newName.lowercased() && $0 != name })
        if taken || self.fileManager.fileExists(atPath: self.path(of: newName)) && name.lowercased() != newName.lowercased() {
            return .nameTaken
        }
        return nil
    }

    private func applyFileChange(name: String, newName: String, url: String, downloaded: Data?, finish: (Result<Void, SupportTemplatesFileChangeError>) -> Void) {
        guard let existing = self.files[name] else {
            finish(.failure(.fileMissing))
            return
        }
        if let problem = self.renameProblem(name: name, newName: newName) {
            finish(.failure(problem))
            return
        }
        let replacement: Data?
        if let downloaded {
            replacement = supportTemplatesRewrittenFile(downloaded: downloaded, url: url, ownKeys: [:])
        } else if !utf16Equal(url, existing.url) {
            guard let current = self.fileManager.contents(atPath: self.path(of: name)) else {
                finish(.failure(.fileMissing))
                return
            }
            replacement = supportTemplatesRewrittenFile(downloaded: current, url: url, ownKeys: [:])
        } else {
            replacement = nil
        }
        do {
            if newName != name {
                let temporary = self.path(of: name) + ".renaming"
                try self.fileManager.moveItem(atPath: self.path(of: name), toPath: temporary)
                try self.fileManager.moveItem(atPath: temporary, toPath: self.path(of: newName))
                if self.fileManager.fileExists(atPath: self.path(of: name) + ".old") {
                    if self.fileManager.fileExists(atPath: self.path(of: newName) + ".old") {
                        try self.fileManager.removeItem(atPath: self.path(of: newName) + ".old")
                    }
                    try self.fileManager.moveItem(atPath: self.path(of: name) + ".old", toPath: self.path(of: newName) + ".old")
                }
            }
            if let replacement {
                try self.write(replacement, name: newName)
            }
        } catch {
            self.log("could not change '\(name)'")
            finish(.failure(.saveFailed))
            return
        }
        let updated = self.fileManager.contents(atPath: self.path(of: newName)).map(parseSupportTemplatesFile) ?? existing
        self.files[name] = nil
        self.files[newName] = updated
        if newName != name, let fileEdits = self.edits[name] {
            self.edits[name] = nil
            self.edits[newName] = fileEdits
            self.saveEdits()
        }
        self.log("changed '\(name)'\(newName != name ? " to '\(newName)'" : "")\(replacement != nil ? " with new content" : "")")
        self.publish()
        finish(.success(()))
    }

    public func removeFile(name: String) {
        self.whenIdle {
            let path = self.path(of: name)
            try? self.fileManager.removeItem(atPath: path)
            try? self.fileManager.removeItem(atPath: path + ".old")
            self.files[name] = nil
            if self.edits[name] != nil {
                self.edits[name] = nil
                self.saveEdits()
            }
            self.publish()
        }
    }

    public func listEntries(_ source: SupportTemplatesSource) -> [SupportTemplatesListEntry] {
        self.lock.lock()
        let files = self.currentFiles
        let edits = self.currentEdits
        let own = self.currentOwn
        self.lock.unlock()
        switch source {
        case let .file(name):
            guard let file = files[name] else {
                return []
            }
            return supportTemplatesListEntries(file: file, edits: edits[name] ?? [:])
        case .own:
            return own.map { template in
                let question = template.asQuestion
                return SupportTemplatesListEntry(id: template.id, template: question, original: nil, status: .original)
            }
        }
    }

    public func exportText(_ source: SupportTemplatesSource) -> String {
        let templates = self.listEntries(source).filter { $0.status != .removed }.map(\.template)
        return supportTemplatesFileText(templates)
    }

    public func ownTemplate(id: String) -> SupportOwnTemplate? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.currentOwn.first(where: { $0.id == id })
    }

    public func setEdit(file name: String, id: String, edit: SupportTemplateEdit?) {
        self.whenIdle {
            var fileEdits = self.edits[name] ?? [:]
            if let edit, self.files[name]?.questions[id] != nil, !edit.isEmpty {
                fileEdits[id] = edit
            } else {
                fileEdits[id] = nil
            }
            self.edits[name] = fileEdits.isEmpty ? nil : fileEdits
            self.saveEdits()
            self.publish()
        }
    }

    public func restoreDefaults(file name: String) {
        self.whenIdle {
            self.edits[name] = nil
            self.saveEdits()
            self.publish()
        }
    }

    public func saveOwnTemplate(_ template: SupportOwnTemplate) {
        self.whenIdle {
            if let index = self.own.firstIndex(where: { $0.id == template.id }) {
                self.own[index] = template
            } else {
                self.own.append(template)
            }
            self.saveOwn()
            self.publish()
        }
    }

    public func removeOwnTemplate(id: String) {
        self.whenIdle {
            self.own.removeAll(where: { $0.id == id })
            self.saveOwn()
            self.publish()
        }
    }

    private var editsPath: String {
        return self.folderPath + "/edits.json"
    }

    private var ownPath: String {
        return self.folderPath + "/own.json"
    }

    private func loadLocal() {
        if let data = self.fileManager.contents(atPath: self.editsPath) {
            if let edits = try? JSONDecoder().decode([String: [String: SupportTemplateEdit]].self, from: data) {
                self.edits = edits
            } else {
                self.log("could not read edits.json")
            }
        }
        if let data = self.fileManager.contents(atPath: self.ownPath) {
            if let own = try? JSONDecoder().decode([SupportOwnTemplate].self, from: data) {
                self.own = own
            } else {
                self.log("could not read own.json")
            }
        }
    }

    private func saveLocal<T: Encodable>(_ value: T, path: String, isEmpty: Bool) {
        do {
            if isEmpty {
                if self.fileManager.fileExists(atPath: path) {
                    try self.fileManager.removeItem(atPath: path)
                }
                return
            }
            try self.fileManager.createDirectory(atPath: self.folderPath, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(value).write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            self.log("could not save '\((path as NSString).lastPathComponent)'")
        }
    }

    private func saveEdits() {
        self.saveLocal(self.edits, path: self.editsPath, isEmpty: self.edits.isEmpty)
    }

    private func saveOwn() {
        self.saveLocal(self.own, path: self.ownPath, isEmpty: self.own.isEmpty)
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
        var effective: [String: SupportTemplatesFile] = [:]
        for (name, file) in self.files {
            effective[name] = self.edits[name].map { supportTemplatesFileApplyingEdits(file, edits: $0) } ?? file
        }
        if !self.own.isEmpty {
            effective[supportOwnTemplatesFileName] = supportTemplatesOwnFile(self.own)
        }
        let templates = SupportTemplates(files: effective)
        var state = SupportTemplatesState()
        state.files = self.files.sorted(by: { $0.key < $1.key }).map { SupportTemplatesFileInfo(name: $0.key, templateCount: $0.value.questions.count, hasUrl: !$0.value.url.isEmpty, editCount: supportTemplatesEditCount(file: $0.value, edits: self.edits[$0.key]), url: $0.value.url) }
        state.ownTemplateCount = self.own.count
        self.revision += 1
        state.revision = self.revision
        state.isReloading = self.isRunning
        state.errors = self.errors

        self.lock.lock()
        self.currentTemplates = templates
        self.currentFiles = self.files
        self.currentEdits = self.edits
        self.currentOwn = self.own
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
