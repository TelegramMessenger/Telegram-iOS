import Foundation
import SwiftSignalKit

// Throughput of the account's media downloads per network type, from the engine's own timing of each part request:
// bytes over the time the link was busy with them (the union of the requests' send-to-receive intervals), so parts in
// flight together are not charged the same seconds twice. It feeds no telemetry; the HLS player takes it as the
// starting estimate of a session's first video.
public final class DownloadThroughputMeter {
    public struct Configuration {
        // Samples older than this no longer count.
        public var window: Double = 120.0
        // Below either, the estimate is nil. Small files measure the round trip rather than the link, so they only ever
        // make it lower; the busy time only keeps a single instant from dividing by nearly nothing (a fast link moves
        // 512 KB in 50 ms).
        public var minimumBytes: Int64 = 512 * 1024
        public var minimumBusyTime: Double = 0.02
        public var maximumSamples: Int = 256

        public init() {
        }
    }

    private struct Sample {
        let bytes: Int64
        let start: Double
        let end: Double
    }

    private struct Samples {
        var wifi: [Sample] = []
        var cellular: [Sample] = []
    }

    private let configuration: Configuration
    private let samples = Atomic<Samples>(value: Samples())

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // `networkDuration`: the engine's send-to-receive time of the request; nothing is recorded when it is unknown (0).
    // `completedAt`: when the response arrived, on the clock `estimate` is asked with.
    public func add(bytes: Int64, networkDuration: Double, isWifi: Bool, completedAt: Double) {
        if bytes <= 0 || !(networkDuration > 0.0) || !networkDuration.isFinite {
            return
        }
        let sample = Sample(bytes: bytes, start: completedAt - networkDuration, end: completedAt)
        let maximumSamples = self.configuration.maximumSamples
        let _ = self.samples.modify { samples in
            var samples = samples
            if isWifi {
                samples.wifi.append(sample)
                if samples.wifi.count > maximumSamples {
                    samples.wifi.removeFirst(samples.wifi.count - maximumSamples)
                }
            } else {
                samples.cellular.append(sample)
                if samples.cellular.count > maximumSamples {
                    samples.cellular.removeFirst(samples.cellular.count - maximumSamples)
                }
            }
            return samples
        }
    }

    // Bits per second over the window ending at `now`, or nil without enough data.
    public func estimate(isWifi: Bool, now: Double) -> Double? {
        let samples = self.samples.with { isWifi ? $0.wifi : $0.cellular }
        let recent = samples.filter({ $0.end >= now - self.configuration.window }).sorted(by: { $0.start < $1.start })

        var bytes: Int64 = 0
        var busyTime = 0.0
        var busyStart: Double?
        var busyEnd = 0.0
        for sample in recent {
            bytes += sample.bytes
            if busyStart != nil && sample.start <= busyEnd {
                busyEnd = max(busyEnd, sample.end)
            } else {
                if let busyStart {
                    busyTime += busyEnd - busyStart
                }
                busyStart = sample.start
                busyEnd = sample.end
            }
        }
        if let busyStart {
            busyTime += busyEnd - busyStart
        }
        if bytes < self.configuration.minimumBytes || busyTime < self.configuration.minimumBusyTime {
            return nil
        }
        return Double(bytes) * 8.0 / busyTime
    }
}
