import Foundation
import SwiftSignalKit
import TelegramCore
import UniversalMediaPlayer
import HLSPlayback

// Turns on-disk segments into the player's parts: the bytes (the level's init, then the segment) go to a temp file
// that is probed for its media times, as SourceBuffer.appendBuffer did in the JavaScript player.
//
// The store owns the temp files. A removed part's file is disposed on the main-queue turn after the next parts list
// is built, by which time the player has that list: SwiftSignalKit delivers a main-queue signal synchronously on
// the main queue, so the player switches lists during the emission. (ChunkMediaPlayerPart.TempFile does not dispose
// its file; livestreams depend on that.)
final class HLSNativePartStore {
    // A range MediaBox lost (a cleared cache) never completes a read; give up on it.
    private static let readTimeout: Double = 10.0
    
    private let engine: TelegramEngine
    private let files: [HLSNativeQualityFile]
    private let queue = Queue(name: "HLSNativePartStore")
    
    private var parts: [HLSSegmentKey: ChunkMediaPlayerPart] = [:]
    private var pendingDisposal: [EngineTempBoxFile] = []
    private var makeDisposables: [HLSSegmentKey: Disposable] = [:]
    
    init(engine: TelegramEngine, files: [HLSNativeQualityFile]) {
        self.engine = engine
        self.files = files
    }
    
    deinit {
        self.removeAll()
    }
    
    // Main queue in, main queue out.
    func makePart(level: Int, request: HLSAppendRequest, completion: @escaping (HLSAppendOutcome) -> Void) {
        guard level >= 0 && level < self.files.count else {
            completion(.failed)
            return
        }
        let qualityFile = self.files[level]
        let resource = EngineMediaResource(qualityFile.file.media.resource)
        let size = qualityFile.size
        let queue = self.queue
        
        let initData: Signal<Data?, NoError>
        if let initRange = request.initRange {
            initData = self.engine.resources.rangeData(resource: resource, size: size, range: initRange)
            |> take(1)
            |> map { data, isComplete -> Data? in
                return isComplete ? data : nil
            }
        } else {
            initData = .single(Data())
        }
        let segmentData = self.engine.resources.rangeData(resource: resource, size: size, range: request.dataRange)
        |> take(1)
        |> map { data, isComplete -> Data? in
            return isComplete ? data : nil
        }
        let bytes = combineLatest(initData, segmentData)
        |> take(1)
        |> map { initData, segmentData -> (Data, Data)? in
            guard let initData, let segmentData else {
                return nil
            }
            return (initData, segmentData)
        }
        |> timeout(HLSNativePartStore.readTimeout, queue: queue, alternate: .single(nil))
        
        // Written and probed on the store's queue. A make cancelled meanwhile disposes the file it wrote.
        let part: Signal<ChunkMediaPlayerPart?, NoError> = Signal { subscriber in
            let isCancelled = Atomic<Bool>(value: false)
            let disposable = (bytes |> deliverOn(queue)).start(next: { value in
                guard let (initData, segmentData) = value else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                let tempFile = EngineTempBox.shared.tempFile(fileName: "data.mp4")
                var combined = Data()
                combined.reserveCapacity(initData.count + segmentData.count)
                combined.append(initData)
                combined.append(segmentData)
                guard let _ = try? combined.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic), let trackTiming = HLSNativePartStore.trackTiming(data: combined, path: tempFile.path), let timing = HLSPartTiming.range(audio: trackTiming.audio, video: trackTiming.video) else {
                    EngineTempBox.shared.dispose(tempFile)
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                if isCancelled.with({ $0 }) {
                    EngineTempBox.shared.dispose(tempFile)
                    return
                }
                subscriber.putNext(ChunkMediaPlayerPart(
                    startTime: timing.start,
                    endTime: timing.end,
                    content: ChunkMediaPlayerPart.TempFile(file: tempFile, ignoreAudioEditList: true),
                    codecName: trackTiming.videoCodecName,
                    offsetTime: 0.0
                ))
                subscriber.putCompletion()
            })
            return ActionDisposable {
                let _ = isCancelled.swap(true)
                disposable.dispose()
            }
        }
        
        let key = request.key
        self.makeDisposables.removeValue(forKey: key)?.dispose()
        self.makeDisposables[key] = (part |> deliverOnMainQueue).startStrict(next: { [weak self] part in
            guard let self else {
                if let part {
                    EngineTempBox.shared.dispose(part.content.file)
                }
                return
            }
            self.makeDisposables.removeValue(forKey: key)?.dispose()
            if let part {
                if let previous = self.parts[key] {
                    self.pendingDisposal.append(previous.content.file)
                }
                self.parts[key] = part
                completion(.appended(start: part.startTime, end: part.endTime))
            } else {
                completion(.failed)
            }
        })
    }
    
    // Each track's start and duration and the video codec, from the part's boxes (`HLSFragmentTiming`), else from
    // FFmpeg's probe of the written file, which costs 15–80 ms a part on a phone.
    private static func trackTiming(data: Data, path: String) -> (audio: (start: Double, duration: Double)?, video: (start: Double, duration: Double)?, videoCodecName: String?)? {
        if let info = HLSFragmentTiming.parse(data) {
            return (info.audio.map { ($0.start, $0.duration) }, info.video.map { ($0.start, $0.duration) }, info.videoCodecName)
        }
        guard let mediaInfo = extractFFMpegMediaInfo(path: path) else {
            return nil
        }
        return (mediaInfo.audio.map { ($0.startTime.seconds, $0.duration.seconds) }, mediaInfo.video.map { ($0.startTime.seconds, $0.duration.seconds) }, mediaInfo.video?.codecName)
    }

    // The player's parts for the buffered segments, sorted by start time (the player reads them in array order).
    // Parts the controller no longer holds (a result it ignored after a seek or a quality change) are released.
    func parts(for buffered: [HLSBufferedPart]) -> [ChunkMediaPlayerPart] {
        let bufferedKeys = Set(buffered.map(\.key))
        for key in Array(self.parts.keys) where !bufferedKeys.contains(key) && self.makeDisposables[key] == nil {
            if let part = self.parts.removeValue(forKey: key) {
                self.pendingDisposal.append(part.content.file)
            }
        }
        let result = buffered.compactMap({ self.parts[$0.key] }).sorted(by: { $0.startTime < $1.startTime })
        self.scheduleDisposal()
        return result
    }
    
    func remove(keys: [HLSSegmentKey]) {
        for key in keys {
            self.makeDisposables.removeValue(forKey: key)?.dispose()
            if let part = self.parts.removeValue(forKey: key) {
                self.pendingDisposal.append(part.content.file)
            }
        }
    }
    
    func removeAll() {
        for (_, disposable) in self.makeDisposables {
            disposable.dispose()
        }
        self.makeDisposables.removeAll()
        for (_, part) in self.parts {
            EngineTempBox.shared.dispose(part.content.file)
        }
        self.parts.removeAll()
        for file in self.pendingDisposal {
            EngineTempBox.shared.dispose(file)
        }
        self.pendingDisposal.removeAll()
    }
    
    private func scheduleDisposal() {
        if self.pendingDisposal.isEmpty {
            return
        }
        let files = self.pendingDisposal
        self.pendingDisposal.removeAll()
        // A real dispatch: Queue.mainQueue().async would run at once on the main queue, before the emission.
        DispatchQueue.main.async {
            for file in files {
                EngineTempBox.shared.dispose(file)
            }
        }
    }
}
