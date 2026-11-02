import Foundation
import SwiftSignalKit
import TelegramCore
import HLSPlayback

// One quality of an adaptive video, at its index in `HLSLevels.sorted` order.
final class HLSNativeQualityFile {
    let level: Int
    let file: FileMediaReference
    let playlistFile: FileMediaReference
    let size: Int64
    
    init(level: Int, file: FileMediaReference, playlistFile: FileMediaReference, size: Int64) {
        self.level = level
        self.file = file
        self.playlistFile = playlistFile
        self.size = size
    }
}

// Every level's media playlist, read from MediaBox and fetched there when missing (D5: all at creation, the start
// level's first). Each arrives on the main queue once.
final class HLSNativePlaylistLoader {
    private let engine: TelegramEngine
    private let userLocation: MediaResourceUserLocation
    private let files: [HLSNativeQualityFile]
    private let startLevel: Int
    
    private let dataDisposables = DisposableSet()
    private var fetchDisposables: [Int: Disposable] = [:]
    private var retryTimers: [Int: SwiftSignalKit.Timer] = [:]
    private var fetchAttempts: [Int: Int] = [:]
    private var delivered = Set<Int>()
    private var reportedUnavailable = Set<Int>()
    private var rejected = Set<Int>()
    private var isCancelled = false
    private var startTime: Double = 0.0
    
    var onPlaylist: ((_ level: Int, _ playlist: HLSMediaPlaylist) -> Void)?
    // The playlist is not on disk; it is being fetched.
    var onPlaylistUnavailable: ((_ level: Int) -> Void)?
    // The playlist cannot be used, and will not become usable.
    var onPlaylistRejected: ((_ level: Int) -> Void)?
    var onLog: ((String) -> Void)?
    
    init(engine: TelegramEngine, userLocation: MediaResourceUserLocation, files: [HLSNativeQualityFile], startLevel: Int) {
        self.engine = engine
        self.userLocation = userLocation
        self.files = files
        self.startLevel = startLevel
    }
    
    deinit {
        self.cancel()
    }
    
    func start() {
        self.startTime = CFAbsoluteTimeGetCurrent()
        let ordered = self.files.filter({ $0.level == self.startLevel }) + self.files.filter({ $0.level != self.startLevel })
        for file in ordered {
            let level = file.level
            self.dataDisposables.add((self.engine.resources.data(resource: EngineMediaResource(file.playlistFile.media.resource))
            |> deliverOnMainQueue).startStrict(next: { [weak self] data in
                guard let self, !self.isCancelled else {
                    return
                }
                if data.isComplete {
                    self.fetchDisposables.removeValue(forKey: level)?.dispose()
                    self.parse(level: level, file: file, path: data.path)
                } else {
                    self.reportUnavailable(level: level)
                    self.fetch(file: file)
                }
            }))
        }
    }
    
    func cancel() {
        self.isCancelled = true
        self.dataDisposables.dispose()
        for (_, disposable) in self.fetchDisposables {
            disposable.dispose()
        }
        self.fetchDisposables.removeAll()
        for (_, timer) in self.retryTimers {
            timer.invalidate()
        }
        self.retryTimers.removeAll()
    }
    
    private func fetch(file: HLSNativeQualityFile) {
        let level = file.level
        if self.fetchDisposables[level] != nil || self.retryTimers[level] != nil || self.delivered.contains(level) || self.rejected.contains(level) {
            return
        }
        let playlistFile = file.playlistFile
        // The fetch waits for the server for as long as it takes. The whole-file fetch reports errors (a range fetch
        // turns them into completion); a failure is never terminal, so the fetch is started again.
        self.fetchDisposables[level] = (self.engine.resources.fetch(
            reference: playlistFile.resourceReference(playlistFile.media.resource),
            userLocation: self.userLocation,
            userContentType: MediaResourceUserContentType(file: playlistFile.media),
            range: nil,
            preferBackgroundReferenceRevalidation: true,
            continueInBackground: true
        )
        |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
            self?.fetchFailed(file: file)
        })
    }
    
    // Fetched again after 2 s, 4 s, 6 s, … at most 30 s.
    private func fetchFailed(file: HLSNativeQualityFile) {
        if self.isCancelled {
            return
        }
        let level = file.level
        self.fetchDisposables.removeValue(forKey: level)?.dispose()
        let attempts = (self.fetchAttempts[level] ?? 0) + 1
        self.fetchAttempts[level] = attempts
        let delay = min(30.0, 2.0 * Double(attempts))
        self.onLog?("playlist fetch failed level=\(level), fetching again in \(Int(delay)) s")
        let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: { [weak self] in
            guard let self, !self.isCancelled else {
                return
            }
            self.retryTimers.removeValue(forKey: level)
            self.fetch(file: file)
        }, queue: Queue.mainQueue())
        self.retryTimers[level] = timer
        timer.start()
    }
    
    private func reportUnavailable(level: Int) {
        if self.delivered.contains(level) || self.reportedUnavailable.contains(level) {
            return
        }
        self.reportedUnavailable.insert(level)
        self.onPlaylistUnavailable?(level)
    }
    
    private func reject(level: Int) {
        if self.delivered.contains(level) || self.rejected.contains(level) {
            return
        }
        self.rejected.insert(level)
        self.onPlaylistRejected?(level)
    }
    
    private func parse(level: Int, file: HLSNativeQualityFile, path: String) {
        if self.delivered.contains(level) || self.rejected.contains(level) {
            return
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let text = String(data: data, encoding: .utf8) else {
            self.onLog?("playlist unreadable level=\(level)")
            self.reject(level: level)
            return
        }
        let playlist: HLSMediaPlaylist
        do {
            playlist = try HLSMediaPlaylist.parse(text)
        } catch let error {
            self.onLog?("playlist rejected level=\(level) error=\(error)")
            self.reject(level: level)
            return
        }
        // The playlist must describe this level's quality file.
        if playlist.resourceURI != "mtproto:\(file.file.media.fileId.id)" {
            self.onLog?("playlist names another file level=\(level) uri=\(playlist.resourceURI)")
            self.reject(level: level)
            return
        }
        if let lastSegment = playlist.segments.last, lastSegment.byteRange.upperBound > file.size {
            self.onLog?("playlist ranges exceed the file level=\(level)")
            self.reject(level: level)
            return
        }
        self.delivered.insert(level)
        self.onLog?("playlist level=\(level) ms=\(Int((CFAbsoluteTimeGetCurrent() - self.startTime) * 1000.0))")
        self.onPlaylist?(level, playlist)
    }
}
