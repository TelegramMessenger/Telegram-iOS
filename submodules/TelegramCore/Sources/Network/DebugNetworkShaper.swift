#if DEBUG

import Foundation

// A slow network for measuring media playback on a fast one: debug builds only, set by the `-debugNetworkProfile <name>`
// launch argument. Every media download goes through `MultiplexedRequestManager`, which holds each response until a
// link with the profile's round trip and bandwidth would have delivered it. The link is one per process, shared by
// every account's downloads; a held response keeps its worker slot, so no more requests are in flight than the slow
// link would allow. The HLS playback lab (`submodules/HLSPlayback/Tests`) models the same link with the same profiles.
final class DebugNetworkShaper {
    struct Step: Equatable {
        // Seconds since the shaper began.
        var start: Double
        var bitsPerSecond: Double
    }

    struct Profile: Equatable {
        var name: String
        // Sorted by start; the first applies from the beginning.
        var steps: [Step]
        // A full round trip, in seconds.
        var roundTrip: Double

        // `wifi`, `lte`, `poor-lte`, `3g`, `step-down`, or "<bitsPerSecond>,<roundTripMs>".
        static func named(_ name: String) -> Profile? {
            switch name {
            case "wifi":
                return Profile(name: name, steps: [Step(start: 0.0, bitsPerSecond: 50_000_000.0)], roundTrip: 0.02)
            case "lte":
                return Profile(name: name, steps: [Step(start: 0.0, bitsPerSecond: 10_000_000.0)], roundTrip: 0.06)
            case "poor-lte":
                return Profile(name: name, steps: [Step(start: 0.0, bitsPerSecond: 3_000_000.0)], roundTrip: 0.15)
            case "3g":
                return Profile(name: name, steps: [Step(start: 0.0, bitsPerSecond: 1_500_000.0)], roundTrip: 0.3)
            case "step-down":
                return Profile(name: name, steps: [
                    Step(start: 0.0, bitsPerSecond: 10_000_000.0),
                    Step(start: 30.0, bitsPerSecond: 1_000_000.0),
                    Step(start: 60.0, bitsPerSecond: 10_000_000.0)
                ], roundTrip: 0.08)
            default:
                let parts = name.split(separator: ",")
                guard parts.count == 2, let bitsPerSecond = Double(parts[0]), bitsPerSecond > 0.0, let roundTripMs = Double(parts[1]), roundTripMs >= 0.0 else {
                    return nil
                }
                return Profile(name: name, steps: [Step(start: 0.0, bitsPerSecond: bitsPerSecond)], roundTrip: roundTripMs / 1000.0)
            }
        }
    }

    static let shared: DebugNetworkShaper? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-debugNetworkProfile"), index + 1 < arguments.count else {
            return nil
        }
        guard let profile = Profile.named(arguments[index + 1]) else {
            Logger.shared.log("DebugNetworkShaper", "unknown profile \(arguments[index + 1])")
            return nil
        }
        Logger.shared.log("DebugNetworkShaper", "profile=\(profile.name) on")
        return DebugNetworkShaper(profile: profile, startTime: CFAbsoluteTimeGetCurrent())
    }()

    private static let logInterval: Double = 2.0

    private let profile: Profile
    private let startTime: Double
    private let lock = NSLock()
    private var linkFreeAt: Double = 0.0

    private var lastLogTime: Double?
    private var loggedResponses: Int = 0
    private var loggedBytes: Int = 0
    private var loggedHold: Double = 0.0

    init(profile: Profile, startTime: Double) {
        self.profile = profile
        self.startTime = startTime
    }

    private func bitsPerSecond(at time: Double) -> Double {
        var result = self.profile.steps.first?.bitsPerSecond ?? 1.0
        for step in self.profile.steps where step.start <= time {
            result = step.bitsPerSecond
        }
        return max(1.0, result)
    }

    // Seconds to hold a response of `bytes`, sent at `sentAt`, that arrived at `now` (one clock for all three): its
    // bytes start arriving one round trip after it was sent, or when the link is done with the responses before it,
    // and take the profile's bandwidth. Moves the link on.
    func holdDuration(bytes: Int, sentAt: Double, now: Double) -> Double {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let begin = max(sentAt + self.profile.roundTrip, self.linkFreeAt)
        let finish = begin + 8.0 * Double(bytes) / self.bitsPerSecond(at: begin - self.startTime)
        self.linkFreeAt = finish
        let hold = max(0.0, finish - now)

        self.loggedResponses += 1
        self.loggedBytes += bytes
        self.loggedHold += hold
        if let lastLogTime = self.lastLogTime {
            if now - lastLogTime >= DebugNetworkShaper.logInterval {
                Logger.shared.log("DebugNetworkShaper", "profile=\(self.profile.name) responses=\(self.loggedResponses) bytes=\(self.loggedBytes) meanHoldMs=\(Int(self.loggedHold * 1000.0 / Double(self.loggedResponses)))")
                self.lastLogTime = now
                self.loggedResponses = 0
                self.loggedBytes = 0
                self.loggedHold = 0.0
            }
        } else {
            self.lastLogTime = now
        }
        return hold
    }
}

#endif
