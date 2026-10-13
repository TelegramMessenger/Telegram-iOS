import Foundation

/// Deterministic RNG for property tests. xorshift64 — small state, decent distribution.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Reject 0 — xorshift64 produces a stuck-at-zero sequence from zero state.
        self.state = seed == 0 ? 0xDEAD_BEEF_DEAD_BEEF : seed
    }

    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }

    mutating func int(in range: Range<Int>) -> Int {
        precondition(range.lowerBound < range.upperBound)
        let span = UInt64(range.upperBound - range.lowerBound)
        return Int(next() % span) + range.lowerBound
    }

    mutating func bool(probability: Double = 0.5) -> Bool {
        Double(next()) / Double(UInt64.max) < probability
    }
}
