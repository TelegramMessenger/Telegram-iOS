import Foundation

public protocol HLSCancellable: AnyObject {
    func cancel()
}

public enum HLSLoadPriority: Equatable {
    // The segment the player needs next.
    case playback
    case preload
}

public enum HLSLoadOutcome: Equatable {
    // `networkBytes`: the bytes of the range that arrived over the network during this load; 0 when it was on disk.
    // `isSampleable` is false when the timing does not measure the link, e.g. when the load joined a fetch of the same
    // bytes already under way (the chat preload's): those bytes started arriving before this load did.
    case completed(networkBytes: Int64, isSampleable: Bool)
    case failed
}

// One part for the player: the bytes of `dataRange`, preceded by `initRange` when that is set.
public struct HLSAppendRequest: Equatable {
    public var key: HLSSegmentKey
    // nil when `dataRange` starts at 0 and so already holds the init (D5).
    public var initRange: Range<Int64>?
    public var dataRange: Range<Int64>
    public var nominalStart: Double
    public var nominalEnd: Double
    
    public init(key: HLSSegmentKey, initRange: Range<Int64>?, dataRange: Range<Int64>, nominalStart: Double, nominalEnd: Double) {
        self.key = key
        self.initRange = initRange
        self.dataRange = dataRange
        self.nominalStart = nominalStart
        self.nominalEnd = nominalEnd
    }
}

public enum HLSAppendOutcome: Equatable {
    // Probed media times of the part.
    case appended(start: Double, end: Double)
    case failed
}

// Everything the controller needs from the outside. All calls and callbacks happen on one thread, the controller's.
public protocol HLSPlaybackEnvironment: AnyObject {
    // Seconds, monotonic.
    var now: Double { get }
    func schedule(after delay: Double, _ action: @escaping () -> Void) -> HLSCancellable
    // The bytes of `range` of the level's quality file that are not on disk; the whole range while that is unknown.
    func missingBytes(level: Int, range: Range<Int64>) -> Int64
    // Makes `range` of the level's quality file present on disk. `progress` reports the network bytes so far, as
    // they land; `completion` fires once, unless the load is cancelled first.
    func load(level: Int, range: Range<Int64>, priority: HLSLoadPriority, progress: @escaping (_ networkBytesSoFar: Int64) -> Void, completion: @escaping (HLSLoadOutcome) -> Void) -> HLSCancellable
    // Turns on-disk bytes into a part for the player.
    func append(level: Int, request: HLSAppendRequest, completion: @escaping (HLSAppendOutcome) -> Void)
    // The player no longer needs these parts.
    func remove(keys: [HLSSegmentKey])
}
