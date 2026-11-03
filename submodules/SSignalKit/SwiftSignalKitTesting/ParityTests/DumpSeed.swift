import XCTest
import ScenariosLegacy
import ScenariosV2

final class DumpSeedTests: XCTestCase {
    func testDumpSeed() throws {
        guard let seedString = ProcessInfo.processInfo.environment["SSK_DUMP_SEED"], let seed = UInt64(seedString) else {
            throw XCTSkip("set SSK_DUMP_SEED")
        }
        let steps = Int(ProcessInfo.processInfo.environment["SSK_DUMP_STEPS"] ?? "25") ?? 25
        let legacy = ScenariosLegacy.runFuzz(seed: seed, steps: steps).events
        let v2 = ScenariosV2.runFuzz(seed: seed, steps: steps).events
        let count = max(legacy.count, v2.count)
        for i in 0 ..< count {
            let l = i < legacy.count ? legacy[i] : "-"
            let r = i < v2.count ? v2[i] : "-"
            print(String(format: "%4d %@ %-60@ | %@", i, l == r ? " " : "*", l as NSString, r as NSString))
        }
    }
}
