import Foundation
@testable import HLSPlayback

// A network profile for the lab; the same names and numbers as `DebugNetworkShaper.Profile` in TelegramCore.
struct LabProfile {
    var name: String
    // A fresh link per run.
    var makeLink: () -> SimulatedLink
}

enum LabProfiles {
    static let wifi = LabProfile(name: "wifi", makeLink: { SimulatedLink(bitsPerSecond: 50_000_000.0, roundTrip: 0.02) })
    static let lte = LabProfile(name: "lte", makeLink: { SimulatedLink(bitsPerSecond: 10_000_000.0, roundTrip: 0.06) })
    static let poorLte = LabProfile(name: "poor-lte", makeLink: { SimulatedLink(bitsPerSecond: 3_000_000.0, roundTrip: 0.15) })
    static let threeG = LabProfile(name: "3g", makeLink: { SimulatedLink(bitsPerSecond: 1_500_000.0, roundTrip: 0.3) })
    static let stepDown = LabProfile(name: "step-down", makeLink: {
        return SimulatedLink(steps: [
            SimulatedLink.Step(start: 0.0, bitsPerSecond: 10_000_000.0),
            SimulatedLink.Step(start: 30.0, bitsPerSecond: 1_000_000.0),
            SimulatedLink.Step(start: 60.0, bitsPerSecond: 10_000_000.0)
        ], roundTrip: 0.08)
    })
    static let all: [LabProfile] = [wifi, lte, poorLte, threeG, stepDown]
}

// A ladder shaped like the server's: 120 s of 5 s segments.
enum LabStreams {
    static let ladder: [HLSLevel] = [
        HLSLevel(key: 360, width: 640, height: 360, bandwidth: 350_000),
        HLSLevel(key: 480, width: 854, height: 480, bandwidth: 600_000),
        HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 1_100_000),
        HLSLevel(key: 1080, width: 1920, height: 1080, bandwidth: 2_200_000)
    ]
    static let seconds: Double = 120.0
    static let preloadLevel = 2

    // The simulator's test video (the 3:39:25 interview): three levels, the preload quality 720p.
    static let testVideoLadder: [HLSLevel] = [
        HLSLevel(key: 480, width: 854, height: 480, bandwidth: 530_000),
        HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 870_000),
        HLSLevel(key: 1080, width: 1920, height: 1080, bandwidth: 1_120_000)
    ]
    static let testVideoPreloadLevel = 1
}

enum LabCache: Equatable {
    case none
    // The chat preload's opening of the preload level.
    case preloadOpening(seconds: Double)
}

struct LabResult: Equatable {
    var profile: String
    var cache: LabCache
    // Seconds from the start to the first moment of playing; nil if it never played.
    var startTime: Double?
    var stallCount: Int
    var stallTime: Double
    var playedSeconds: Double
    // Bits per second of the level under the playhead, averaged over played time.
    var meanBitrate: Double
    var networkBytes: Int64
    var bytesPerPlayedSecond: Double
}

// The controller over the shared link, with a player that follows ChunkMediaPlayerV2's measured rules: the clock moves
// while the contiguous run of parts from the position (gaps up to 0.5 s) holds at least 1.0 s, or reaches the end; the
// first such moment is the start, and dropping out of it before the end is a stall. Before the start the clock also
// waits for the controller's `startNotBefore`, taken at each buffer change as the node hands it to the player. The player reports its position to
// the controller when it moved 0.25 s or more, as `HLSNativePlayerSource` does, and keeps reporting `isPlaying` while
// it buffers (it is the requested state).
final class PlaybackLab {
    let harness: ControllerHarness
    private let profile: LabProfile
    private let cache: LabCache
    private let levels: [HLSLevel]
    private let preloadLevel: Int
    private let startPosition: Double
    // The first time a part was buffered.
    private(set) var firstPartTime: Double?

    // `store`: nil runs on a store of its own, so runs never see each other's samples. `startPosition`: where the open
    // starts, as a gallery open at a timestamp does (the controller seeks there before it starts).
    init(profile: LabProfile, cache: LabCache, configuration: HLSPlaybackController.Configuration = HLSPlaybackController.Configuration(), store: HLSBandwidthStore? = nil, appendDelay: Double = 0.05, levels: [HLSLevel] = LabStreams.ladder, preloadLevel: Int = LabStreams.preloadLevel, seconds: Double = LabStreams.seconds, startPosition: Double = 0.0) {
        self.profile = profile
        self.cache = cache
        self.levels = levels
        self.preloadLevel = preloadLevel
        self.startPosition = startPosition
        self.harness = ControllerHarness(levels: levels, seconds: seconds, preloadLevel: preloadLevel, configuration: configuration, store: store ?? HLSBandwidthStore())
        self.harness.environment.link = profile.makeLink()
        self.harness.environment.appendDelay = appendDelay
    }

    // The seconds the player can play from `position`, and whether that run reaches the end.
    private static func playable(_ parts: [HLSBufferedPart], position: Double, duration: Double) -> (seconds: Double, reachesEnd: Bool) {
        let sorted = parts.sorted(by: { $0.start < $1.start })
        guard let currentIndex = sorted.firstIndex(where: { position >= $0.start - 0.5 && position < $0.end }) else {
            return (0.0, false)
        }
        var seconds = sorted[currentIndex].end - position
        var runEnd = sorted[currentIndex].end
        for part in sorted[(currentIndex + 1)...] {
            if part.start > runEnd + 0.5 {
                break
            }
            if part.end > runEnd {
                seconds += part.end - max(part.start, runEnd)
                runEnd = part.end
            }
        }
        return (seconds, runEnd >= duration - 0.5)
    }

    func run(wallSeconds: Double = 120.0, step: Double = 0.05) -> LabResult {
        let controller = self.harness.controller
        let environment = self.harness.environment
        if case let .preloadOpening(seconds) = self.cache {
            self.harness.cache(level: self.preloadLevel, seconds: seconds)
        }
        if self.startPosition > 0.0 {
            controller.seek(to: self.startPosition)
        }
        self.harness.setPlaylists()
        controller.updatePlayback(position: self.startPosition, isPlaying: true, rate: 1.0)
        controller.start()
        let duration = self.harness.playlists.map(\.totalDuration).max() ?? 0.0

        var time = 0.0
        var position = self.startPosition
        var reportedPosition = self.startPosition
        // Taken with each buffer change, as the node hands it to the player with the parts.
        var startNotBefore: Double?
        let recordBufferChange = controller.onBufferChanged
        controller.onBufferChanged = { [weak controller] parts, duration in
            recordBufferChange?(parts, duration)
            startNotBefore = controller?.startNotBefore
        }
        var isPlaying = false
        var startTime: Double?
        var stallCount = 0
        var stallTime = 0.0
        var playedSeconds = 0.0
        var bitTime = 0.0

        while time < wallSeconds - 1e-9 {
            environment.advance(by: step)
            time += step
            let parts = self.harness.buffered
            if self.firstPartTime == nil && !parts.isEmpty {
                self.firstPartTime = time
            }
            let playable = PlaybackLab.playable(parts, position: position, duration: duration)
            let isHeld = startTime == nil && startNotBefore.map { environment.now < $0 } == true
            if (playable.seconds >= 1.0 && !isHeld) || (playable.reachesEnd && playable.seconds > 0.0) {
                if startTime == nil {
                    startTime = time
                }
                isPlaying = true
                let level = controller.level(at: position)
                let advance = min(step, playable.seconds)
                position += advance
                playedSeconds += advance
                if let level, level >= 0, level < self.levels.count {
                    bitTime += Double(self.levels[level].bandwidth) * advance
                }
                if position >= duration - 0.5 {
                    break
                }
            } else {
                if isPlaying {
                    stallCount += 1
                }
                isPlaying = false
                if startTime != nil {
                    stallTime += step
                }
            }
            if abs(position - reportedPosition) >= 0.25 {
                reportedPosition = position
                controller.updatePlayback(position: position, isPlaying: true, rate: 1.0)
            }
        }

        let networkBytes = environment.loads.reduce(Int64(0), { $0 + $1.networkBytes })
        return LabResult(
            profile: self.profile.name,
            cache: self.cache,
            startTime: startTime,
            stallCount: stallCount,
            stallTime: stallTime,
            playedSeconds: playedSeconds,
            meanBitrate: playedSeconds > 0.0 ? bitTime / playedSeconds : 0.0,
            networkBytes: networkBytes,
            bytesPerPlayedSecond: playedSeconds > 0.0 ? Double(networkBytes) / playedSeconds : 0.0
        )
    }
}

func labTable(_ results: [LabResult]) -> String {
    func pad(_ value: String, _ width: Int) -> String {
        return value.count >= width ? value : value + String(repeating: " ", count: width - value.count)
    }
    func format(_ value: Double, _ digits: Int) -> String {
        return String(format: "%.\(digits)f", value)
    }
    var lines: [String] = []
    lines.append([pad("profile", 10), pad("cache", 8), pad("start", 7), pad("stalls", 7), pad("stall s", 8), pad("played", 7), pad("kbit/s", 7), pad("MB", 6), "B/s played"].joined(separator: " "))
    for result in results {
        let cache: String
        switch result.cache {
        case .none:
            cache = "none"
        case let .preloadOpening(seconds):
            cache = "pre\(Int(seconds))s"
        }
        lines.append([
            pad(result.profile, 10),
            pad(cache, 8),
            pad(result.startTime.map { format($0, 2) } ?? "-", 7),
            pad("\(result.stallCount)", 7),
            pad(format(result.stallTime, 2), 8),
            pad(format(result.playedSeconds, 1), 7),
            pad("\(Int(result.meanBitrate / 1000.0))", 7),
            pad(format(Double(result.networkBytes) / 1_000_000.0, 2), 6),
            "\(Int(result.bytesPerPlayedSecond))"
        ].joined(separator: " "))
    }
    return lines.joined(separator: "\n")
}
