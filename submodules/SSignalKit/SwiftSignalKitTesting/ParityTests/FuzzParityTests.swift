import XCTest
import ScenariosLegacy
import ScenariosV2

func firstDivergence(_ lhs: [String], _ rhs: [String]) -> Int? {
    let count = min(lhs.count, rhs.count)
    for i in 0 ..< count {
        if lhs[i] != rhs[i] {
            return i
        }
    }
    if lhs.count != rhs.count {
        return count
    }
    return nil
}

func describeDivergence(seed: UInt64, legacy: [String], v2: [String], at index: Int) -> String {
    var lines: [String] = ["seed \(seed) diverges at event \(index) (legacy \(legacy.count) events, v2 \(v2.count) events)"]
    let header = legacy.prefix(while: { $0.hasPrefix("pipeline") })
    lines.append(contentsOf: header)
    let from = max(0, index - 12)
    lines.append("--- legacy")
    for i in from ..< min(legacy.count, index + 8) {
        lines.append("\(i == index ? ">>" : "  ") \(i): \(legacy[i])")
    }
    lines.append("--- v2")
    for i in from ..< min(v2.count, index + 8) {
        lines.append("\(i == index ? ">>" : "  ") \(i): \(v2[i])")
    }
    return lines.joined(separator: "\n")
}

final class FuzzParityTests: XCTestCase {
    func runSeeds(_ seeds: Range<UInt64>, steps: Int, file: StaticString = #filePath, line: UInt = #line) {
        var failures = 0
        var totalEvents = 0
        for seed in seeds {
            let legacy = ScenariosLegacy.runFuzz(seed: seed, steps: steps)
            let v2 = ScenariosV2.runFuzz(seed: seed, steps: steps)
            totalEvents += legacy.events.count
            XCTAssertFalse(legacy.overflowed || v2.overflowed, "seed \(seed) overflowed the trace limit", file: file, line: line)
            if let index = firstDivergence(legacy.events, v2.events) {
                failures += 1
                if failures <= 3 {
                    XCTFail(describeDivergence(seed: seed, legacy: legacy.events, v2: v2.events, at: index), file: file, line: line)
                }
            }
        }
        if failures > 0 {
            XCTFail("\(failures) of \(seeds.count) seeds diverged", file: file, line: line)
        }
        print("fuzz parity: \(seeds.count) seeds, \(totalEvents) legacy events compared, \(failures) divergent")
    }
    
    func testShortRuns() {
        self.runSeeds(0 ..< 3000, steps: 25)
    }
    
    func testLongRuns() {
        self.runSeeds(100_000 ..< 100_400, steps: 300)
    }
    
    func testExtendedRuns() throws {
        guard let countString = ProcessInfo.processInfo.environment["SSK_FUZZ_SEEDS"], let count = UInt64(countString) else {
            throw XCTSkip("set SSK_FUZZ_SEEDS to run the extended sweep")
        }
        let base = UInt64(ProcessInfo.processInfo.environment["SSK_FUZZ_BASE"] ?? "1000000") ?? 1_000_000
        let steps = Int(ProcessInfo.processInfo.environment["SSK_FUZZ_STEPS"] ?? "80") ?? 80
        self.runSeeds(base ..< base + count, steps: steps)
    }
    
    func testOperatorCoverage() {
        var counts: [String: Int] = [:]
        for seed in UInt64(0) ..< 3000 {
            let events = ScenariosV2.runFuzz(seed: seed, steps: 25).events
            for event in events where event.hasPrefix("pipeline") {
                var token = ""
                for character in event {
                    if character.isLetter || character.isNumber {
                        token.append(character)
                    } else {
                        if !token.isEmpty && character == "(" {
                            counts[token, default: 0] += 1
                        }
                        token = ""
                    }
                }
            }
        }
        let summary = counts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("operator coverage: \(summary)")
        XCTAssertGreaterThan(counts.count, 40)
    }
}
