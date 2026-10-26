import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import RangeSet
import HLSPlayback

// The playback controller's world, over MediaBox's own file context for each quality file: fetching a
// range joins any fetch of the same bytes already running (the chat preload's included), the bytes land in the quality
// file, and disposing a fetch cancels it. Main queue only.
final class HLSNativeEnvironment: HLSPlaybackEnvironment {
    private final class Cancellable: HLSCancellable {
        private var action: (() -> Void)?
        
        init(_ action: @escaping () -> Void) {
            self.action = action
        }
        
        func cancel() {
            let action = self.action
            self.action = nil
            action?()
        }
    }
    
    // Fires whether or not the caller keeps the token.
    private final class ScheduledAction: HLSCancellable {
        var isCancelled = false
        
        func cancel() {
            self.isCancelled = true
        }
    }
    
    private final class Waiter {
        let range: Range<Int64>
        // The bytes of `range` that were not on disk when the load started.
        let missingAtStart: RangeSet<Int64>
        let missingBytes: Int64
        let progress: (Int64) -> Void
        let completion: (HLSLoadOutcome) -> Void
        // False when the load joined a fetch of the quality file already under way: those bytes started arriving
        // before this load did, so its time measures nothing about the link (D1).
        let isSampleable: Bool
        var reportedBytes: Int64 = 0
        var fetch: Disposable?
        
        init(range: Range<Int64>, missingAtStart: RangeSet<Int64>, missingBytes: Int64, isSampleable: Bool, progress: @escaping (Int64) -> Void, completion: @escaping (HLSLoadOutcome) -> Void) {
            self.range = range
            self.missingAtStart = missingAtStart
            self.missingBytes = missingBytes
            self.isSampleable = isSampleable
            self.progress = progress
            self.completion = completion
        }
    }
    
    private final class LevelState {
        var ranges: RangeSet<Int64>?
        var isFetching = false
        var waiters: [Int: Waiter] = [:]
        let rangesDisposable = MetaDisposable()
        let statusDisposable = MetaDisposable()
    }
    
    private let engine: TelegramEngine
    private let userLocation: MediaResourceUserLocation
    private let files: [HLSNativeQualityFile]
    private let partStore: HLSNativePartStore
    private let levelStates: [LevelState]
    private var nextWaiterId = 0
    
    var onDiskStateKnown: (() -> Void)?
    
    // True once every level's ranges status has delivered its first value.
    var isDiskStateKnown: Bool {
        return self.levelStates.allSatisfy({ $0.ranges != nil })
    }
    
    init(engine: TelegramEngine, userLocation: MediaResourceUserLocation, files: [HLSNativeQualityFile], partStore: HLSNativePartStore) {
        self.engine = engine
        self.userLocation = userLocation
        self.files = files
        self.partStore = partStore
        self.levelStates = files.map { _ in LevelState() }
        assert(files.enumerated().allSatisfy({ $0.offset == $0.element.level }))
        
        for file in files {
            let level = file.level
            self.subscribeToRanges(level: level)
            self.levelStates[level].statusDisposable.set((engine.resources.status(resource: EngineMediaResource(file.file.media.resource))
            |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                guard let self else {
                    return
                }
                if case .Fetching(true, _) = status {
                    self.levelStates[level].isFetching = true
                } else {
                    self.levelStates[level].isFetching = false
                }
            }))
        }
    }
    
    deinit {
        for state in self.levelStates {
            state.rangesDisposable.dispose()
            state.statusDisposable.dispose()
            for (_, waiter) in state.waiters {
                waiter.fetch?.dispose()
            }
        }
    }
    
    // A complete file's ranges status completes; subscribing again picks up a change MediaBox made since (a cleared
    // cache).
    private func subscribeToRanges(level: Int) {
        let file = self.files[level]
        self.levelStates[level].rangesDisposable.set((self.engine.resources.resourceRangesStatus(resource: EngineMediaResource(file.file.media.resource))
        |> deliverOnMainQueue).startStrict(next: { [weak self] ranges in
            self?.rangesUpdated(level: level, ranges: ranges)
        }, completed: { [weak self] in
            // MediaBox completes without a value when it cannot open the file: count nothing as on disk, so the
            // start is not held and loads fetch (and fail and retry) as usual.
            guard let self, self.levelStates[level].ranges == nil else {
                return
            }
            Logger.shared.log("HLSNative", "\(file.file.media.fileId.id): ranges status ended without a value level=\(level)")
            self.rangesUpdated(level: level, ranges: RangeSet())
        }))
    }
    
    var now: Double {
        return CACurrentMediaTime()
    }
    
    func schedule(after delay: Double, _ action: @escaping () -> Void) -> HLSCancellable {
        let scheduled = ScheduledAction()
        Queue.mainQueue().after(max(0.0, delay), {
            if !scheduled.isCancelled {
                action()
            }
        })
        return scheduled
    }
    
    func missingBytes(level: Int, range: Range<Int64>) -> Int64 {
        if range.isEmpty {
            return 0
        }
        guard level >= 0 && level < self.levelStates.count, let ranges = self.levelStates[level].ranges else {
            return Int64(range.count)
        }
        return RangeSet(range).subtracting(ranges).ranges.reduce(Int64(0), { $0 + Int64($1.count) })
    }
    
    func load(level: Int, range: Range<Int64>, priority: HLSLoadPriority, progress: @escaping (Int64) -> Void, completion: @escaping (HLSLoadOutcome) -> Void) -> HLSCancellable {
        guard level >= 0 && level < self.levelStates.count else {
            DispatchQueue.main.async {
                completion(.failed)
            }
            return Cancellable {}
        }
        let state = self.levelStates[level]
        let missing = RangeSet(range).subtracting(state.ranges ?? RangeSet())
        let missingBytes = missing.ranges.reduce(Int64(0), { $0 + Int64($1.count) })
        let id = self.nextWaiterId
        self.nextWaiterId += 1
        // Best effort: the status signal can lag a turn, and the file's own fetches (ours) count as well.
        let ownFetchActive = state.waiters.values.contains(where: { $0.fetch != nil })
        let isSampleable = !(state.isFetching && !ownFetchActive)
        let waiter = Waiter(range: range, missingAtStart: missing, missingBytes: missingBytes, isSampleable: isSampleable, progress: progress, completion: completion)
        state.waiters[id] = waiter
        
        if missingBytes == 0 {
            // Already on disk: complete on a later turn, as a fetch would.
            DispatchQueue.main.async { [weak self] in
                self?.finish(level: level, id: id, outcome: .completed(networkBytes: 0, isSampleable: false))
            }
        } else {
            let file = self.files[level].file
            waiter.fetch = (self.engine.resources.fetch(
                reference: file.resourceReference(file.media.resource),
                userLocation: self.userLocation,
                userContentType: .video,
                range: (range, priority == .playback ? .elevated : .default),
                statsCategory: .video,
                preferBackgroundReferenceRevalidation: true,
                continueInBackground: true
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                self?.finish(level: level, id: id, outcome: .failed)
            }, completed: { [weak self] in
                // MediaBox turns a range fetch's error into completion, and stops fetching the file, so a load whose
                // bytes have not landed after its fetch ended has failed. A completed fetch's last part reaches the
                // ranges status in the same MediaBox data-queue task that completes the fetch, ahead of the completion,
                // and both arrive here through the main queue in that order; the 1 s only covers a busy main queue.
                Queue.mainQueue().after(1.0, {
                    guard let self, let waiter = self.levelStates[level].waiters[id] else {
                        return
                    }
                    if self.missingBytes(level: level, range: waiter.range) > 0 {
                        self.finish(level: level, id: id, outcome: .failed)
                    }
                })
            })
        }
        
        return Cancellable { [weak self] in
            guard let self, let waiter = self.levelStates[level].waiters.removeValue(forKey: id) else {
                return
            }
            waiter.fetch?.dispose()
        }
    }
    
    func append(level: Int, request: HLSAppendRequest, completion: @escaping (HLSAppendOutcome) -> Void) {
        self.partStore.makePart(level: level, request: request, completion: { [weak self] outcome in
            if case .failed = outcome, let self, level >= 0, level < self.levelStates.count {
                // The bytes may be gone (a cleared cache): read the file's ranges again before the retry judges them.
                self.subscribeToRanges(level: level)
            }
            completion(outcome)
        })
    }
    
    func remove(keys: [HLSSegmentKey]) {
        self.partStore.remove(keys: keys)
    }
    
    private func finish(level: Int, id: Int, outcome: HLSLoadOutcome) {
        guard let waiter = self.levelStates[level].waiters.removeValue(forKey: id) else {
            return
        }
        waiter.fetch?.dispose()
        waiter.completion(outcome)
    }
    
    private func rangesUpdated(level: Int, ranges: RangeSet<Int64>) {
        let state = self.levelStates[level]
        let wasKnown = self.isDiskStateKnown
        state.ranges = ranges
        
        // Callbacks may start or cancel loads: walk a snapshot.
        for (id, waiter) in state.waiters.sorted(by: { $0.key < $1.key }) {
            if state.waiters[id] == nil || waiter.missingBytes == 0 {
                continue
            }
            let stillMissing = waiter.missingAtStart.subtracting(ranges)
            let stillMissingBytes = stillMissing.ranges.reduce(Int64(0), { $0 + Int64($1.count) })
            let arrived = waiter.missingBytes - stillMissingBytes
            if stillMissingBytes == 0 {
                self.finish(level: level, id: id, outcome: .completed(networkBytes: waiter.missingBytes, isSampleable: waiter.isSampleable))
            } else if arrived > waiter.reportedBytes {
                waiter.reportedBytes = arrived
                waiter.progress(arrived)
            }
        }
        
        if !wasKnown && self.isDiskStateKnown {
            self.onDiskStateKnown?()
        }
    }
}
