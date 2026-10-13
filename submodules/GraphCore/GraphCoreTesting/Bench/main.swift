import Foundation
import ScenariosLegacy
import ScenariosV2

func now() -> Double {
    return Double(DispatchTime.now().uptimeNanoseconds) / 1e9
}

func mallocInUse() -> Int {
    var stats = malloc_statistics_t()
    malloc_zone_statistics(nil, &stats)
    return Int(stats.size_in_use)
}

func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

func pad(_ string: String, _ width: Int) -> String {
    return string.count >= width ? string : string + String(repeating: " ", count: width - string.count)
}

func lpad(_ string: String, _ width: Int) -> String {
    return string.count >= width ? string : String(repeating: " ", count: width - string.count) + string
}

struct Measurement {
    var staticMs = 0.0
    var scrubMs = 0.0
    var hoverMs = 0.0
    var navigationMs = 0.0
    var kilobytes = 0.0
}

let arguments = CommandLine.arguments
let repetitions = arguments.firstIndex(of: "--reps").flatMap { Int(arguments[$0 + 1]) } ?? 5
let frames = arguments.firstIndex(of: "--frames").flatMap { Int(arguments[$0 + 1]) } ?? 60
let filter = arguments.firstIndex(of: "--filter").map { arguments[$0 + 1] }

func measureLegacy(typeIndex: Int) -> Measurement {
    let type = ScenariosLegacy.chartTypes[typeIndex]
    let dataset = ScenariosLegacy.datasets(for: type).first(where: { $0.points == 365 && $0.series != 1 }) ?? ScenariosLegacy.datasets(for: type)[0]
    var result = Measurement()
    let before = mallocInUse()
    let scenario = ScenariosLegacy.ChartScenario(type: type, dataset: dataset, size: ScenariosLegacy.chartSizes[0])
    scenario.setRange(0.6 ... 1.0)
    scenario.renderMain()
    scenario.renderNavigation()
    result.kilobytes = Double(mallocInUse() - before) / 1024
    var t = now()
    for _ in 0 ..< frames {
        scenario.renderMain()
    }
    result.staticMs = (now() - t) / Double(frames) * 1000
    t = now()
    for i in 0 ..< frames {
        let lower = 0.2 + 0.4 * CGFloat(i) / CGFloat(frames)
        scenario.setRange(lower ... lower + 0.4)
        scenario.renderMain()
    }
    result.scrubMs = (now() - t) / Double(frames) * 1000
    t = now()
    for i in 0 ..< frames {
        scenario.select(x: CGFloat(i) / CGFloat(frames))
        scenario.renderMain()
    }
    scenario.deselect()
    result.hoverMs = (now() - t) / Double(frames) * 1000
    t = now()
    for _ in 0 ..< frames {
        scenario.renderNavigation()
    }
    result.navigationMs = (now() - t) / Double(frames) * 1000
    return result
}

func measureV2(typeIndex: Int) -> Measurement {
    let type = ScenariosV2.chartTypes[typeIndex]
    let dataset = ScenariosV2.datasets(for: type).first(where: { $0.points == 365 && $0.series != 1 }) ?? ScenariosV2.datasets(for: type)[0]
    var result = Measurement()
    let before = mallocInUse()
    let scenario = ScenariosV2.ChartScenario(type: type, dataset: dataset, size: ScenariosV2.chartSizes[0])
    scenario.setRange(0.6 ... 1.0)
    scenario.renderMain()
    scenario.renderNavigation()
    result.kilobytes = Double(mallocInUse() - before) / 1024
    var t = now()
    for _ in 0 ..< frames {
        scenario.renderMain()
    }
    result.staticMs = (now() - t) / Double(frames) * 1000
    t = now()
    for i in 0 ..< frames {
        let lower = 0.2 + 0.4 * CGFloat(i) / CGFloat(frames)
        scenario.setRange(lower ... lower + 0.4)
        scenario.renderMain()
    }
    result.scrubMs = (now() - t) / Double(frames) * 1000
    t = now()
    for i in 0 ..< frames {
        scenario.select(x: CGFloat(i) / CGFloat(frames))
        scenario.renderMain()
    }
    scenario.deselect()
    result.hoverMs = (now() - t) / Double(frames) * 1000
    t = now()
    for _ in 0 ..< frames {
        scenario.renderNavigation()
    }
    result.navigationMs = (now() - t) / Double(frames) * 1000
    return result
}

print(pad("chart (600x250 @2x)", 22) + lpad("static", 16) + lpad("scrub", 16) + lpad("hover", 16) + lpad("range view", 16) + lpad("KB", 14))
print(pad("", 22) + lpad("legacy -> v2", 16) + lpad("legacy -> v2", 16) + lpad("legacy -> v2", 16) + lpad("legacy -> v2", 16) + lpad("legacy -> v2", 14))
var ratios: [Double] = []
for typeIndex in 0 ..< ScenariosLegacy.chartTypes.count {
    let name = ScenariosLegacy.chartTypes[typeIndex].name
    if let filter = filter, !name.contains(filter) {
        continue
    }
    var legacy: [Measurement] = []
    var v2: [Measurement] = []
    for repetition in 0 ..< repetitions {
        if repetition % 2 == 0 {
            legacy.append(measureLegacy(typeIndex: typeIndex))
            v2.append(measureV2(typeIndex: typeIndex))
        } else {
            v2.append(measureV2(typeIndex: typeIndex))
            legacy.append(measureLegacy(typeIndex: typeIndex))
        }
    }
    func cell(_ key: KeyPath<Measurement, Double>, _ format: String) -> String {
        let l = median(legacy.map { $0[keyPath: key] })
        let r = median(v2.map { $0[keyPath: key] })
        return String(format: format, l, r)
    }
    let l = median(legacy.map { $0.staticMs + $0.scrubMs + $0.hoverMs + $0.navigationMs })
    let r = median(v2.map { $0.staticMs + $0.scrubMs + $0.hoverMs + $0.navigationMs })
    ratios.append(l / r)
    print(pad(name, 22) + lpad(cell(\.staticMs, "%.2f -> %.2f"), 16) + lpad(cell(\.scrubMs, "%.2f -> %.2f"), 16) + lpad(cell(\.hoverMs, "%.2f -> %.2f"), 16) + lpad(cell(\.navigationMs, "%.2f -> %.2f"), 16) + lpad(cell(\.kilobytes, "%.0f -> %.0f"), 14))
}
if !ratios.isEmpty {
    print(String(format: "geometric mean speedup (sum of all four): %.2fx", exp(ratios.map { log($0) }.reduce(0, +) / Double(ratios.count))))
}
