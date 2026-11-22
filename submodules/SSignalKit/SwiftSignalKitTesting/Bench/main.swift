import Foundation
import ScenariosLegacy
import ScenariosV2

func now() -> UInt64 {
    return DispatchTime.now().uptimeNanoseconds
}

func mallocInUse() -> Int {
    var stats = malloc_statistics_t()
    malloc_zone_statistics(nil, &stats)
    return Int(stats.size_in_use)
}

let arguments = CommandLine.arguments
let scale = arguments.firstIndex(of: "--scale").flatMap { Int(arguments[$0 + 1]) } ?? 1
let repetitions = arguments.firstIndex(of: "--reps").flatMap { Int(arguments[$0 + 1]) } ?? 7
let filter = arguments.firstIndex(of: "--filter").map { arguments[$0 + 1] }

struct BenchWorkload {
    let name: String
    let operations: Int
    let run: () -> Void
}

let legacyWorkloads = ScenariosLegacy.workloads(scale: scale).map { BenchWorkload(name: $0.name, operations: $0.operations, run: $0.run) }
let v2Workloads = ScenariosV2.workloads(scale: scale).map { BenchWorkload(name: $0.name, operations: $0.operations, run: $0.run) }

func pad(_ string: String, _ width: Int) -> String {
    if string.count >= width {
        return string
    }
    return string + String(repeating: " ", count: width - string.count)
}

func lpad(_ string: String, _ width: Int) -> String {
    if string.count >= width {
        return string
    }
    return String(repeating: " ", count: width - string.count) + string
}

func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

func runOnMain(_ f: @escaping () -> Void) {
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        f()
        done.signal()
    }
    done.wait()
}

DispatchQueue.global(qos: .userInitiated).async {
    print(pad("workload", 52) + lpad("legacy ns/op", 14) + lpad("v2 ns/op", 12) + lpad("speedup", 10))
    var ratios: [Double] = []
    for index in 0 ..< legacyWorkloads.count {
        let legacy = legacyWorkloads[index]
        let v2 = v2Workloads[index]
        precondition(legacy.name == v2.name)
        if let filter = filter, !legacy.name.contains(filter) {
            continue
        }
        let onMain = legacy.name.contains("(main)")
        var legacyTimes: [Double] = []
        var v2Times: [Double] = []
        for repetition in 0 ..< repetitions + 1 {
            for (workload, isLegacy) in (repetition % 2 == 0 ? [(legacy, true), (v2, false)] : [(v2, false), (legacy, true)]) {
                let start = now()
                if onMain {
                    runOnMain(workload.run)
                } else {
                    autoreleasepool {
                        workload.run()
                    }
                }
                let elapsed = Double(now() - start) / Double(workload.operations)
                if repetition == 0 {
                    continue
                }
                if isLegacy {
                    legacyTimes.append(elapsed)
                } else {
                    v2Times.append(elapsed)
                }
            }
        }
        let l = median(legacyTimes)
        let r = median(v2Times)
        ratios.append(l / r)
        print(pad(legacy.name, 52) + lpad(String(format: "%.1f", l), 14) + lpad(String(format: "%.1f", r), 12) + lpad(String(format: "%.2fx", l / r), 10))
    }
    if !ratios.isEmpty {
        let geomean = exp(ratios.map { log($0) }.reduce(0, +) / Double(ratios.count))
        print(String(format: "geometric mean speedup: %.2fx", geomean))
    }

    if filter == nil || filter == "memory" {
        print("")
        print(pad("memory (bytes per live object, malloc in use)", 52) + lpad("legacy", 14) + lpad("v2", 12) + lpad("saved", 10))
        let legacyMemory = ScenariosLegacy.memoryWorkloads()
        let v2Memory = ScenariosV2.memoryWorkloads()
        for index in 0 ..< legacyMemory.count {
            let (name, count, makeLegacy) = legacyMemory[index]
            let (_, _, makeV2) = v2Memory[index]
            var results: [Double] = []
            for make in [makeLegacy, makeV2] {
                var samples: [Double] = []
                for _ in 0 ..< 3 {
                    let before = mallocInUse()
                    let objects = make(count)
                    let after = mallocInUse()
                    samples.append(Double(after - before) / Double(count))
                    withExtendedLifetime(objects, {})
                }
                results.append(median(samples))
            }
            print(pad(name, 52) + lpad(String(format: "%.0f", results[0]), 14) + lpad(String(format: "%.0f", results[1]), 12) + lpad(String(format: "%.0f%%", (1.0 - results[1] / results[0]) * 100.0), 10))
        }
    }
    exit(0)
}

dispatchMain()
