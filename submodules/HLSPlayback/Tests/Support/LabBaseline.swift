import Foundation

// The lab's numbers before the shared estimate and pipelining (2026-10-22), as `testBaselineTable` printed them. No
// later change may make any of them worse (`testNoProfileIsWorseThanTheBaseline`).
enum LabBaseline {
    static let results: [LabResult] = [
        LabResult(profile: "wifi", cache: .none, startTime: 0.20, stallCount: 0, stallTime: 0.0, playedSeconds: 119.5, meanBitrate: 2_153_000, networkBytes: 32_310_000, bytesPerPlayedSecond: 270_301),
        LabResult(profile: "wifi", cache: .preloadOpening(seconds: 10.0), startTime: 0.05, stallCount: 0, stallTime: 0.0, playedSeconds: 119.5, meanBitrate: 2_061_000, networkBytes: 29_560_000, bytesPerPlayedSecond: 247_289),
        LabResult(profile: "lte", cache: .none, startTime: 0.70, stallCount: 0, stallTime: 0.0, playedSeconds: 119.3, meanBitrate: 2_153_000, networkBytes: 32_310_000, bytesPerPlayedSecond: 270_754),
        LabResult(profile: "lte", cache: .preloadOpening(seconds: 10.0), startTime: 0.05, stallCount: 0, stallTime: 0.0, playedSeconds: 119.5, meanBitrate: 2_061_000, networkBytes: 29_560_000, bytesPerPlayedSecond: 247_289),
        LabResult(profile: "poor-lte", cache: .none, startTime: 2.05, stallCount: 0, stallTime: 0.0, playedSeconds: 118.0, meanBitrate: 1_100_000, networkBytes: 16_500_000, bytesPerPlayedSecond: 139_839),
        LabResult(profile: "poor-lte", cache: .preloadOpening(seconds: 10.0), startTime: 0.05, stallCount: 0, stallTime: 0.0, playedSeconds: 119.5, meanBitrate: 1_100_000, networkBytes: 15_120_000, bytesPerPlayedSecond: 126_516),
        LabResult(profile: "3g", cache: .none, startTime: 4.05, stallCount: 0, stallTime: 0.0, playedSeconds: 116.0, meanBitrate: 1_100_000, networkBytes: 16_500_000, bytesPerPlayedSecond: 142_250),
        LabResult(profile: "3g", cache: .preloadOpening(seconds: 10.0), startTime: 0.05, stallCount: 0, stallTime: 0.0, playedSeconds: 119.5, meanBitrate: 1_100_000, networkBytes: 15_120_000, bytesPerPlayedSecond: 126_516),
        LabResult(profile: "step-down", cache: .none, startTime: 0.70, stallCount: 0, stallTime: 0.0, playedSeconds: 119.3, meanBitrate: 1_869_000, networkBytes: 27_940_000, bytesPerPlayedSecond: 234_106),
        LabResult(profile: "step-down", cache: .preloadOpening(seconds: 10.0), startTime: 0.05, stallCount: 0, stallTime: 0.0, playedSeconds: 119.5, meanBitrate: 1_775_000, networkBytes: 25_190_000, bytesPerPlayedSecond: 210_702)
    ]
}
