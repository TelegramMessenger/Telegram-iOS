#if GC_LEGACY
import GraphCoreLegacy
#else
import GraphCore2
#endif
import Foundation
import AppKit

public let implementationName: String = {
    #if GC_LEGACY
    return "legacy"
    #else
    return "v2"
    #endif
}()

public struct Dataset {
    public let name: String
    public let kind: String
    public let series: Int
    public let points: Int
    public let shape: String
    public let seed: UInt64

    public init(name: String, kind: String, series: Int, points: Int, shape: String, seed: UInt64) {
        self.name = name
        self.kind = kind
        self.series = series
        self.points = points
        self.shape = shape
        self.seed = seed
    }
}

public struct ChartType {
    public let name: String
    public let datasetKind: String
    public let make: String

    public init(name: String, datasetKind: String, make: String) {
        self.name = name
        self.datasetKind = datasetKind
        self.make = make
    }
}

struct SeededRandom {
    var state: UInt64

    mutating func next() -> Double {
        self.state = self.state &* 6364136223846793005 &+ 1442695040888963407
        return Double(self.state >> 11) / Double(UInt64(1) << 53)
    }
}

public func chartJSON(_ dataset: Dataset) -> [String: Any] {
    var random = SeededRandom(state: dataset.seed &+ 1)
    let start = 1_600_000_000_000
    let step: Int
    switch dataset.kind {
    case "hourly":
        step = 3_600_000
    case "min5":
        step = 300_000
    default:
        step = 86_400_000
    }
    var columns: [[Any]] = [["x"] + (0 ..< dataset.points).map { start + $0 * step }]
    var types: [String: String] = ["x": "x"]
    var names: [String: String] = [:]
    var colors: [String: String] = [:]
    let palette = ["#3497ED", "#F34C44", "#4BD964", "#FE9500", "#9C27B0", "#00BCD4", "#795548", "#607D8B"]
    for i in 0 ..< dataset.series {
        var value = 1000.0 * Double(i + 1)
        var values: [Any] = ["y\(i)"]
        for p in 0 ..< dataset.points {
            switch dataset.shape {
            case "flat":
                value = 500
            case "zeros":
                value = 0
            case "huge":
                value = 1_000_000_000 + random.next() * 900_000_000
            case "spiky":
                value = (p % 17 == 0) ? 50_000 * random.next() : 100 * random.next()
            case "rising":
                value = Double(p * (i + 1)) + random.next() * 10
            default:
                value = max(0, value + (random.next() - 0.48) * 120 * Double(i + 1))
            }
            values.append(Int(value))
        }
        columns.append(values)
        let type: String
        switch dataset.kind {
        case "bars":
            type = "bar"
        case "step", "hourly", "min5":
            type = "step"
        case "area":
            type = "area"
        default:
            type = "line"
        }
        types["y\(i)"] = type
        names["y\(i)"] = "Series \(i)"
        colors["y\(i)"] = palette[i % palette.count]
    }
    return ["columns": columns, "types": types, "names": names, "colors": colors]
}

public func makeCollection(_ dataset: Dataset) -> ChartsCollection {
    return try! ChartsCollection(from: chartJSON(dataset))
}

func makeController(_ make: String, _ collection: ChartsCollection) -> BaseChartController {
    switch make {
    case "lines":
        return GeneralLinesChartController(chartsCollection: collection)
    case "twoAxis":
        return TwoAxisLinesChartController(chartsCollection: collection)
    case "pie":
        return PercentPieChartController(chartsCollection: collection, initiallyZoomed: true)
    case "area":
        return PercentPieChartController(chartsCollection: collection, initiallyZoomed: false)
    case "stackedBars":
        return StackedBarsChartController(chartsCollection: collection)
    case "dailyBars":
        return DailyBarsChartController(chartsCollection: collection)
    case "step":
        return StepBarsChartController(chartsCollection: collection)
    case "hourlyStep":
        return StepBarsChartController(chartsCollection: collection, hourly: true)
    case "twoAxisStep":
        return TwoAxisStepBarsChartController(chartsCollection: collection)
    case "twoAxisHourlyStep":
        let controller = TwoAxisStepBarsChartController(chartsCollection: collection)
        controller.hourly = true
        return controller
    case "twoAxis5MinStep":
        let controller = TwoAxisStepBarsChartController(chartsCollection: collection)
        controller.min5 = true
        return controller
    default:
        fatalError("unknown chart \(make)")
    }
}

public let chartTypes: [ChartType] = [
    ChartType(name: "lines", datasetKind: "lines", make: "lines"),
    ChartType(name: "twoAxis", datasetKind: "lines", make: "twoAxis"),
    ChartType(name: "pie", datasetKind: "area", make: "pie"),
    ChartType(name: "area", datasetKind: "area", make: "area"),
    ChartType(name: "stackedBars", datasetKind: "bars", make: "stackedBars"),
    ChartType(name: "dailyBars", datasetKind: "bars", make: "dailyBars"),
    ChartType(name: "step", datasetKind: "step", make: "step"),
    ChartType(name: "hourlyStep", datasetKind: "hourly", make: "hourlyStep"),
    ChartType(name: "twoAxisStep", datasetKind: "step", make: "twoAxisStep"),
    ChartType(name: "twoAxisHourlyStep", datasetKind: "hourly", make: "twoAxisHourlyStep"),
    ChartType(name: "twoAxis5MinStep", datasetKind: "min5", make: "twoAxis5MinStep"),
]

public func datasets(for type: ChartType) -> [Dataset] {
    let seriesCounts: [Int]
    switch type.make {
    case "twoAxis", "twoAxisStep", "twoAxisHourlyStep", "twoAxis5MinStep":
        seriesCounts = [2]
    case "dailyBars":
        seriesCounts = [1]
    default:
        seriesCounts = [1, 3, 6]
    }
    var result: [Dataset] = []
    var seed: UInt64 = 1
    for series in seriesCounts {
        for (shape, points) in [("walk", 365), ("walk", 2), ("walk", 9), ("flat", 60), ("zeros", 30), ("huge", 120), ("spiky", 400), ("rising", 1460)] {
            if series == 6 && points < 60 {
                continue
            }
            result.append(Dataset(name: "\(type.name)-s\(series)-\(shape)\(points)", kind: type.datasetKind, series: series, points: points, shape: shape, seed: seed))
            seed += 1
        }
    }
    return result
}

public final class RenderedImage {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public func pngData() -> Data? {
        var pixels = self.pixels
        let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count) as CFData)!
        guard let image = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: self.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

public struct ChartSize {
    public let width: CGFloat
    public let height: CGFloat
    public let scale: CGFloat
}

public let chartSizes: [ChartSize] = [
    ChartSize(width: 600, height: 250, scale: 2),
    ChartSize(width: 320, height: 250, scale: 2),
    ChartSize(width: 900, height: 300, scale: 1),
]

private let rangeViewHeight: CGFloat = 48

public final class ChartScenario {
    public let type: ChartType
    public let dataset: Dataset
    public let size: ChartSize
    let controller: BaseChartController
    let bounds: CGRect
    let chartFrame: CGRect
    let navigationBounds: CGRect
    let navigationFrame: CGRect
    public private(set) var log: [String] = []
    private let context: CGContext
    private let navigationContext: CGContext

    public init(type: ChartType, dataset: Dataset, size: ChartSize, night: Bool = false) {
        self.type = type
        self.dataset = dataset
        self.size = size
        self.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        self.chartFrame = CGRect(x: 16, y: 40, width: max(1, size.width - 32), height: max(1, size.height - 75))
        self.navigationBounds = CGRect(x: 0, y: 0, width: size.width, height: rangeViewHeight)
        self.navigationFrame = CGRect(x: 16, y: 0, width: max(1, size.width - 32), height: rangeViewHeight)
        self.controller = makeController(type.make, makeCollection(dataset))
        self.context = ChartScenario.makeContext(width: size.width, height: size.height, scale: size.scale)
        self.navigationContext = ChartScenario.makeContext(width: size.width, height: rangeViewHeight, scale: size.scale)

        let bounds = self.bounds
        let chartFrame = self.chartFrame
        self.controller.cartViewBounds = {
            return bounds
        }
        self.controller.chartFrame = {
            return chartFrame
        }
        self.controller.setDetailsViewModel = { [weak self] viewModel, animated, feedback in
            self?.record(viewModel: viewModel, animated: animated, feedback: feedback)
        }
        self.controller.setDetailsChartVisibleClosure = { [weak self] visible, animated in
            self?.log.append("detailsVisible \(visible) animated \(animated)")
        }
        self.controller.setDetailsViewPositionClosure = { [weak self] position in
            self?.log.append(String(format: "detailsPosition %.3f", position))
        }
        self.controller.setChartTitleClosure = { [weak self] title, animated in
            self?.log.append("title \(title) animated \(animated)")
        }
        self.controller.setBackButtonVisibilityClosure = { [weak self] visible, animated in
            self?.log.append("backButton \(visible) animated \(animated)")
        }
        self.controller.chartRangeUpdatedClosure = { [weak self] range, animated in
            self?.log.append(String(format: "rangeUpdated %.5f...%.5f animated %@", range.lowerBound, range.upperBound, animated ? "true" : "false"))
        }
        self.controller.chartRangePagingClosure = { [weak self] enabled, size in
            self?.log.append(String(format: "paging %@ %.5f", enabled ? "true" : "false", size))
        }
        self.controller.initializeChart()
        self.controller.apply(theme: night ? ChartTheme.defaultNightTheme : ChartTheme.defaultDayTheme, strings: ChartStrings.defaultStrings, animated: false)
    }

    static func makeContext(width: CGFloat, height: CGFloat, scale: CGFloat) -> CGContext {
        let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8, bytesPerRow: Int(width * scale) * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        context.translateBy(x: 0, y: height * scale)
        context.scaleBy(x: scale, y: -scale)
        return context
    }

    private func record(viewModel: ChartDetailsViewModel, animated: Bool, feedback: Bool) {
        func describe(_ value: ChartDetailsViewModel.Value) -> String {
            let color = value.color.usingColorSpace(.sRGB) ?? value.color
            return "\(value.prefix ?? "-")|\(value.title)|\(value.value)|\(value.visible)|" + String(format: "%.3f,%.3f,%.3f,%.3f", color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent)
        }
        var parts = ["details title=\(viewModel.title) arrow=\(viewModel.showArrow) prefixes=\(viewModel.showPrefixes) loading=\(viewModel.isLoading) animated=\(animated)"]
        parts.append(contentsOf: viewModel.values.map(describe))
        if let total = viewModel.totalValue {
            parts.append("total " + describe(total))
        }
        self.log.append(parts.joined(separator: " ; "))
    }

    public var stateDescription: String {
        let fraction = self.controller.currentChartHorizontalRangeFraction
        return String(format: "fraction %.5f...%.5f visibility %@ height600 %.1f", fraction.lowerBound, fraction.upperBound, self.controller.actualChartVisibility.map { $0 ? "1" : "0" }.joined(), self.controller.height(for: 600))
    }

    public func setRange(_ range: ClosedRange<CGFloat>) {
        self.controller.updateChartRange(range, animated: false)
    }

    public func setVisibility(_ visibility: [Bool]) {
        self.controller.updateChartsVisibility(visibility: visibility, animated: false)
    }

    public var seriesCount: Int {
        return self.controller.actualChartVisibility.count
    }

    public func select(x: CGFloat) {
        self.controller.chartInteractionDidBegin(point: CGPoint(x: x, y: 0.5))
    }

    public func deselect() {
        self.controller.cancelChartInteraction()
    }

    public func clearLog() {
        self.log.removeAll()
    }

    public func renderMain() {
        self.context.clear(self.bounds)
        for renderer in self.controller.mainChartRenderers {
            renderer.render(context: self.context, bounds: self.bounds, chartFrame: self.chartFrame)
        }
    }

    public func renderNavigation() {
        self.navigationContext.clear(self.navigationBounds)
        for renderer in self.controller.navigationRenderers {
            renderer.render(context: self.navigationContext, bounds: self.navigationBounds, chartFrame: self.navigationFrame)
        }
    }

    public func mainImage() -> RenderedImage {
        self.renderMain()
        return ChartScenario.capture(self.context)
    }

    public func navigationImage() -> RenderedImage {
        self.renderNavigation()
        return ChartScenario.capture(self.navigationContext)
    }

    static func capture(_ context: CGContext) -> RenderedImage {
        let count = context.bytesPerRow * context.height
        let buffer = context.data!.bindMemory(to: UInt8.self, capacity: count)
        return RenderedImage(width: context.width, height: context.height, pixels: Array(UnsafeBufferPointer(start: buffer, count: count)))
    }
}

public struct ScenarioStep {
    public let name: String
    public let apply: (ChartScenario) -> Void
}

public func scenarioSteps(seriesCount: Int) -> [ScenarioStep] {
    var steps: [ScenarioStep] = [
        ScenarioStep(name: "initial", apply: { _ in }),
        ScenarioStep(name: "range-full", apply: { $0.setRange(0 ... 1) }),
        ScenarioStep(name: "range-tail", apply: { $0.setRange(0.6 ... 1) }),
        ScenarioStep(name: "range-head", apply: { $0.setRange(0 ... 0.1) }),
        ScenarioStep(name: "range-mid", apply: { $0.setRange(0.45 ... 0.55) }),
        ScenarioStep(name: "range-narrow", apply: { $0.setRange(0.3 ... 0.31) }),
    ]
    if seriesCount > 1 {
        steps.append(ScenarioStep(name: "hide-first", apply: { scenario in
            var visibility = Array(repeating: true, count: seriesCount)
            visibility[0] = false
            scenario.setVisibility(visibility)
        }))
        steps.append(ScenarioStep(name: "only-last", apply: { scenario in
            var visibility = Array(repeating: false, count: seriesCount)
            visibility[seriesCount - 1] = true
            scenario.setVisibility(visibility)
        }))
        steps.append(ScenarioStep(name: "show-all", apply: { $0.setVisibility(Array(repeating: true, count: seriesCount)) }))
    }
    for x in [0.0, 0.33, 0.5, 0.999] as [CGFloat] {
        steps.append(ScenarioStep(name: String(format: "select-%.2f", x), apply: { $0.select(x: x) }))
    }
    steps.append(ScenarioStep(name: "deselect", apply: { $0.deselect() }))
    return steps
}
