import Foundation

// A kind of network the device can be on (Wi-Fi, a cellular generation). Estimates are kept per class: what was
// measured on Wi-Fi says nothing about cellular.
public struct HLSNetworkClass: Hashable {
    public var rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let unknown = HLSNetworkClass("unknown")
}

// A network load's share of the link, from `HLSBandwidthStore.beginLoad`.
public struct HLSLinkLoadToken: Hashable {
    fileprivate let id: Int
    fileprivate let networkClass: HLSNetworkClass
}

// The bandwidth estimate of the device's link, one per network class, shared by every player in the process
// (deviation D3). Every player samples into it and reads from it, so a second video starts from what the first measured.
//
// After `idleBeforePrior` seconds without a sample, the class's estimate becomes a prior before the next sample: the
// same value, with each average's weight capped at `maximumPriorWeight` seconds of downloading and halved for every
// `priorWeightHalfLife` seconds of idleness. A new viewing session then moves it quickly, without starting from
// nothing.
//
// It also keeps the link's busy time, so that loads in flight together (two of one player's, or several players') are
// not charged the same seconds twice: a load is charged from the later of the start of the link's busy period and the
// end of the previous load in it that completed. A cancelled load's time goes to the loads still running, so the
// estimate errs low rather than high.
//
// Thread-safe.
public final class HLSBandwidthStore {
    public struct Configuration: Equatable {
        // Seconds of downloading.
        public var maximumPriorWeight: Double = 4.0
        // Seconds of idleness that halve the prior's weight.
        public var priorWeightHalfLife: Double = 300.0
        // Seconds without a sample after which the estimate is treated as a prior: longer than the pauses inside one
        // playback (at 10 s the lab's step-down lost 1% of its bitrate to conversions while its buffer was full).
        public var idleBeforePrior: Double = 60.0

        public init() {
        }
    }

    public static let shared = HLSBandwidthStore()

    private final class ClassState {
        var estimator: HLSBandwidthEstimator?
        var lastSampleTime: Double?
        var activeLoads = Set<Int>()
        var busyStart: Double?
        var lastEnd: Double?
    }

    private let configuration: Configuration
    private let lock = NSLock()
    private var classes: [HLSNetworkClass: ClassState] = [:]
    private var nextLoadId = 0

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    private func state(_ networkClass: HLSNetworkClass) -> ClassState {
        if let state = self.classes[networkClass] {
            return state
        }
        let state = ClassState()
        self.classes[networkClass] = state
        return state
    }

    // nil when nothing was sampled on this class.
    public func estimator(for networkClass: HLSNetworkClass) -> HLSBandwidthEstimator? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.classes[networkClass]?.estimator
    }

    public func sample(durationMs: Double, bytes: Int64, networkClass: HLSNetworkClass, defaultEstimate: Double, now: Double) -> HLSBandwidthEstimator {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let state = self.state(networkClass)
        var estimator = state.estimator ?? HLSBandwidthEstimator(defaultEstimate: defaultEstimate)
        if state.estimator != nil, let lastSampleTime = state.lastSampleTime, now - lastSampleTime >= self.configuration.idleBeforePrior {
            let decay = pow(0.5, (now - lastSampleTime) / self.configuration.priorWeightHalfLife)
            estimator = estimator.withMaximumWeight(self.configuration.maximumPriorWeight, decay: decay)
        }
        estimator.sample(durationMs: durationMs, bytes: bytes)
        state.estimator = estimator
        state.lastSampleTime = now
        return estimator
    }

    // A starting estimate from outside the player (the account's other downloads) for a class with no sample of its own:
    // one with that estimate and no weight, which the class's first sample replaces, as does a later seed. False when
    // the class has sampled.
    @discardableResult
    public func seedPrior(bitsPerSecond: Double, networkClass: HLSNetworkClass) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let state = self.state(networkClass)
        if state.estimator != nil && state.lastSampleTime != nil {
            return false
        }
        state.estimator = HLSBandwidthEstimator(defaultEstimate: bitsPerSecond)
        return true
    }

    // An abandon's sample and reset.
    public func replace(_ estimator: HLSBandwidthEstimator, networkClass: HLSNetworkClass, now: Double) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let state = self.state(networkClass)
        state.estimator = estimator
        state.lastSampleTime = now
    }

    public func beginLoad(networkClass: HLSNetworkClass, now: Double) -> HLSLinkLoadToken {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let id = self.nextLoadId
        self.nextLoadId += 1
        let state = self.state(networkClass)
        if state.activeLoads.isEmpty {
            state.busyStart = now
            state.lastEnd = nil
        }
        state.activeLoads.insert(id)
        return HLSLinkLoadToken(id: id, networkClass: networkClass)
    }

    // The busy time the load is charged; 0 for a token already ended.
    public func endLoad(_ token: HLSLinkLoadToken, now: Double) -> Double {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.finishLoad(token, now: now)
    }

    // Ends the load's share uncharged: its time goes to the loads still running, whose bytes moved during it too.
    public func cancelLoad(_ token: HLSLinkLoadToken, now: Double) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let _ = self.finishLoad(token, now: now, isCancelled: true)
    }

    private func finishLoad(_ token: HLSLinkLoadToken, now: Double, isCancelled: Bool = false) -> Double {
        guard let state = self.classes[token.networkClass], state.activeLoads.contains(token.id) else {
            return 0.0
        }
        let busyStart = state.busyStart ?? now
        let charged = max(0.0, now - max(busyStart, state.lastEnd ?? busyStart))
        state.activeLoads.remove(token.id)
        if state.activeLoads.isEmpty {
            state.busyStart = nil
            state.lastEnd = nil
        } else if !isCancelled {
            state.lastEnd = now
        }
        return charged
    }
}
