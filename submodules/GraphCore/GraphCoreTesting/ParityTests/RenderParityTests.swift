import XCTest
import Foundation
import ScenariosLegacy
import ScenariosV2

struct ImageDifference {
    var exactPixels = 0
    var maxDelta = 0
    var tolerantPixels = 0
    var totalPixels = 0
}

func compareImages(_ a: [UInt8], _ b: [UInt8], width: Int, height: Int, radius: Int = 1, threshold: Int = 24) -> ImageDifference {
    var result = ImageDifference()
    result.totalPixels = width * height
    if a.count != b.count {
        result.exactPixels = result.totalPixels
        result.tolerantPixels = result.totalPixels
        result.maxDelta = 255
        return result
    }
    if a == b {
        return result
    }
    a.withUnsafeBufferPointer { pa in
        b.withUnsafeBufferPointer { pb in
            func delta(_ p: UnsafeBufferPointer<UInt8>, _ i: Int, _ q: UnsafeBufferPointer<UInt8>, _ j: Int) -> Int {
                var d = 0
                for c in 0 ..< 4 {
                    let v = Int(p[i + c]) - Int(q[j + c])
                    d = max(d, v < 0 ? -v : v)
                }
                return d
            }
            func nearby(_ p: UnsafeBufferPointer<UInt8>, _ q: UnsafeBufferPointer<UInt8>, _ x: Int, _ y: Int) -> Bool {
                let i = (y * width + x) * 4
                for yy in max(0, y - radius) ... min(height - 1, y + radius) {
                    for xx in max(0, x - radius) ... min(width - 1, x + radius) {
                        if delta(p, i, q, (yy * width + xx) * 4) <= threshold {
                            return true
                        }
                    }
                }
                return false
            }
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let i = (y * width + x) * 4
                    if pa[i] == pb[i] && pa[i + 1] == pb[i + 1] && pa[i + 2] == pb[i + 2] && pa[i + 3] == pb[i + 3] {
                        continue
                    }
                    let d = delta(pa, i, pb, i)
                    result.exactPixels += 1
                    result.maxDelta = max(result.maxDelta, d)
                    let solid = max(pa[i + 3], pb[i + 3]) >= 128
                    if d > threshold && solid && (!nearby(pa, pb, x, y) || !nearby(pb, pa, x, y)) {
                        result.tolerantPixels += 1
                    }
                }
            }
        }
    }
    return result
}

let lineAntialiasingTypes: Set<String> = ["lines", "twoAxis", "dailyBars"]

struct ParityReport {
    var cases = 0
    var images = 0
    var exactMismatchImages = 0
    var tolerantMismatchImages = 0
    var exactPixels = 0
    var worstDelta = 0
    var logMismatches = 0
    var failures: [String] = []
}

let artifactsDirectory: URL = {
    let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GC_ARTIFACTS"] ?? NSTemporaryDirectory()).appendingPathComponent("graphcore-parity")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}()

final class RenderParityTests: XCTestCase {
    private func run(sizes: [Int], night: Bool, file: StaticString = #filePath, line: UInt = #line) -> ParityReport {
        var report = ParityReport()
        let strictTypes = Set((ProcessInfo.processInfo.environment["GC_STRICT_TYPES"] ?? "pie,area,stackedBars,step,hourlyStep,twoAxisStep,twoAxisHourlyStep,twoAxis5MinStep").split(separator: ",").map(String.init))
        for (typeIndex, legacyType) in ScenariosLegacy.chartTypes.enumerated() {
            let v2Type = ScenariosV2.chartTypes[typeIndex]
            let legacyDatasets = ScenariosLegacy.datasets(for: legacyType)
            let v2Datasets = ScenariosV2.datasets(for: v2Type)
            for (datasetIndex, legacyDataset) in legacyDatasets.enumerated() {
                let v2Dataset = v2Datasets[datasetIndex]
                for sizeIndex in sizes {
                    report.cases += 1
                    let legacy = ScenariosLegacy.ChartScenario(type: legacyType, dataset: legacyDataset, size: ScenariosLegacy.chartSizes[sizeIndex], night: night)
                    let v2 = ScenariosV2.ChartScenario(type: v2Type, dataset: v2Dataset, size: ScenariosV2.chartSizes[sizeIndex], night: night)
                    let legacySteps = ScenariosLegacy.scenarioSteps(seriesCount: legacy.seriesCount)
                    let v2Steps = ScenariosV2.scenarioSteps(seriesCount: v2.seriesCount)
                    XCTAssertEqual(legacySteps.count, v2Steps.count, file: file, line: line)
                    let strict = strictTypes.contains("*") || strictTypes.contains(legacyType.name)
                    for stepIndex in 0 ..< min(legacySteps.count, v2Steps.count) {
                        legacy.clearLog()
                        v2.clearLog()
                        legacySteps[stepIndex].apply(legacy)
                        v2Steps[stepIndex].apply(v2)
                        let caseName = "\(legacyDataset.name)-\(Int(legacy.size.width))x\(Int(legacy.size.height))\(night ? "-night" : "")-\(legacySteps[stepIndex].name)"
                        let legacyLog = legacy.log + [legacy.stateDescription]
                        let v2Log = v2.log + [v2.stateDescription]
                        if legacyLog != v2Log {
                            report.logMismatches += 1
                            report.failures.append("\(caseName): log differs\n  legacy: \(legacyLog)\n  v2:     \(v2Log)")
                        }
                        let pairs = [("main", legacy.mainImage(), v2.mainImage()), ("nav", legacy.navigationImage(), v2.navigationImage())]
                        for (kind, a, b) in pairs {
                            report.images += 1
                            let threshold = lineAntialiasingTypes.contains(legacyType.name) ? 112 : 24
                            let difference = compareImages(a.pixels, b.pixels, width: a.width, height: a.height, threshold: threshold)
                            report.exactPixels += difference.exactPixels
                            report.worstDelta = max(report.worstDelta, difference.maxDelta)
                            if difference.exactPixels > 0 {
                                report.exactMismatchImages += 1
                            }
                            let failed = difference.tolerantPixels > 0 || (strict && difference.exactPixels > 0)
                            if difference.tolerantPixels > 0 {
                                report.tolerantMismatchImages += 1
                            }
                            if failed {
                                report.failures.append("\(caseName) \(kind): exact \(difference.exactPixels) tolerant \(difference.tolerantPixels) maxDelta \(difference.maxDelta)")
                                if report.failures.count <= 40 {
                                    try? a.pngData()?.write(to: artifactsDirectory.appendingPathComponent("\(caseName)-\(kind)-legacy.png"))
                                    try? b.pngData()?.write(to: artifactsDirectory.appendingPathComponent("\(caseName)-\(kind)-v2.png"))
                                }
                            }
                        }
                    }
                }
            }
        }
        print("render parity \(night ? "night" : "day") sizes \(sizes): \(report.cases) cases, \(report.images) images, \(report.exactMismatchImages) differ exactly (\(report.exactPixels) px, worst delta \(report.worstDelta)), \(report.tolerantMismatchImages) differ beyond 1px/AA tolerance, \(report.logMismatches) log mismatches")
        for failure in report.failures.prefix(15) {
            XCTFail(failure, file: file, line: line)
        }
        if report.failures.count > 15 {
            XCTFail("\(report.failures.count) failures in total, images in \(artifactsDirectory.path)", file: file, line: line)
        }
        return report
    }

    func testDayAllTypesAppSize() {
        let _ = self.run(sizes: [0], night: false)
    }

    func testNightAllTypesAppSize() throws {
        if ProcessInfo.processInfo.environment["GC_EXTENDED"] == nil {
            throw XCTSkip("set GC_EXTENDED=1")
        }
        let _ = self.run(sizes: [0], night: true)
    }

    func testOtherSizes() throws {
        if ProcessInfo.processInfo.environment["GC_EXTENDED"] == nil {
            throw XCTSkip("set GC_EXTENDED=1")
        }
        let _ = self.run(sizes: [1, 2], night: false)
    }

    func testLegacyIsDeterministic() {
        for type in ScenariosLegacy.chartTypes {
            let dataset = ScenariosLegacy.datasets(for: type)[0]
            let a = ScenariosLegacy.ChartScenario(type: type, dataset: dataset, size: ScenariosLegacy.chartSizes[0])
            let b = ScenariosLegacy.ChartScenario(type: type, dataset: dataset, size: ScenariosLegacy.chartSizes[0])
            for step in ScenariosLegacy.scenarioSteps(seriesCount: a.seriesCount) {
                step.apply(a)
                step.apply(b)
                XCTAssertEqual(a.mainImage().pixels, b.mainImage().pixels, "\(type.name) \(step.name) main is not deterministic")
                XCTAssertEqual(a.navigationImage().pixels, b.navigationImage().pixels, "\(type.name) \(step.name) nav is not deterministic")
            }
        }
    }
}
