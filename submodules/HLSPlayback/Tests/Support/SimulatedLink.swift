import Foundation
@testable import HLSPlayback

// One network link for the playback lab, shaped like the app's download path (FetchV2 over MtProtoKit): a load's bytes
// go out as parts of `partSize`, at most `partsInFlightPerLevel` per quality file and `partsInFlightTotal` in all (the
// datacenter's request queue), issued first in, first out. A part issued at `s` lands at
// `max(s + roundTrip, linkFreeAt) + 8 · bytes / bandwidth`: one round trip after it was sent, or once the link is done
// with the parts before it. `DebugNetworkShaper` in TelegramCore models the app's link the same way, with the same
// profiles, so lab and simulator numbers compare.
final class SimulatedLink {
    struct Step {
        // Seconds on the environment's clock.
        var start: Double
        var bitsPerSecond: Double
    }

    private struct Part {
        let loadId: Int
        let level: Int
        let bytes: Int64
        let landed: () -> Void
    }

    let steps: [Step]
    let roundTrip: Double
    let partSize: Int64
    let partsInFlightPerLevel: Int
    let partsInFlightTotal: Int

    private var linkFreeAt: Double = 0.0
    private var queued: [Part] = []
    private var inFlightPerLevel: [Int: Int] = [:]
    private var inFlightTotal = 0
    private var cancelledLoads = Set<Int>()

    init(steps: [Step], roundTrip: Double, partSize: Int64 = 131_072, partsInFlightPerLevel: Int = 6, partsInFlightTotal: Int = 12) {
        self.steps = steps
        self.roundTrip = roundTrip
        self.partSize = partSize
        self.partsInFlightPerLevel = partsInFlightPerLevel
        self.partsInFlightTotal = partsInFlightTotal
    }

    convenience init(bitsPerSecond: Double, roundTrip: Double) {
        self.init(steps: [Step(start: 0.0, bitsPerSecond: bitsPerSecond)], roundTrip: roundTrip)
    }

    func bitsPerSecond(at time: Double) -> Double {
        var result = self.steps.first?.bitsPerSecond ?? 1.0
        for step in self.steps where step.start <= time {
            result = step.bitsPerSecond
        }
        return max(1.0, result)
    }

    func partsInFlight(level: Int) -> Int {
        return self.inFlightPerLevel[level] ?? 0
    }

    // Queues `bytes` of a load as parts; `landed` is called with each part's size as it lands, in order.
    func enqueue(loadId: Int, level: Int, bytes: Int64, environment: SimulatedEnvironment, landed: @escaping (Int64) -> Void) {
        var offset: Int64 = 0
        while offset < bytes {
            let size = min(self.partSize, bytes - offset)
            self.queued.append(Part(loadId: loadId, level: level, bytes: size, landed: {
                landed(size)
            }))
            offset += size
        }
        self.pump(environment: environment)
    }

    // Queued parts are dropped; parts in flight still hold the link until they land, and deliver nothing.
    func cancel(loadId: Int, environment: SimulatedEnvironment) {
        self.cancelledLoads.insert(loadId)
        self.queued.removeAll(where: { $0.loadId == loadId })
        self.pump(environment: environment)
    }

    private func pump(environment: SimulatedEnvironment) {
        var index = 0
        while index < self.queued.count && self.inFlightTotal < self.partsInFlightTotal {
            let part = self.queued[index]
            if self.partsInFlight(level: part.level) >= self.partsInFlightPerLevel {
                index += 1
                continue
            }
            self.queued.remove(at: index)
            self.inFlightPerLevel[part.level, default: 0] += 1
            self.inFlightTotal += 1
            let now = environment.now
            let begin = max(now + self.roundTrip, self.linkFreeAt)
            let finish = begin + 8.0 * Double(part.bytes) / self.bitsPerSecond(at: begin)
            self.linkFreeAt = finish
            let _ = environment.schedule(after: finish - now, { [weak self, weak environment] in
                guard let self, let environment else {
                    return
                }
                self.inFlightPerLevel[part.level, default: 1] -= 1
                self.inFlightTotal -= 1
                if !self.cancelledLoads.contains(part.loadId) {
                    part.landed()
                }
                self.pump(environment: environment)
            })
        }
    }
}
