import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

public class StepBarsChartController2: BaseChartController {
    class GraphController {
        let mainBarsRenderer: BarChartRenderer
        let verticalScalesRenderer = VerticalScalesRenderer()
        let lineBulletsRenderer = LineBulletsRenderer()
        let previewBarsRenderer: BarChartRenderer
        
        var chartBars: BarChartRenderer.BarsData = .blank
        var barsWidth: CGFloat = 1
        
        var totalVerticalRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
        
        init(isZoomed: Bool,
             mainBarsRenderer: BarChartRenderer,
             previewBarsRenderer: BarChartRenderer) {
            self.mainBarsRenderer = mainBarsRenderer
            self.previewBarsRenderer = previewBarsRenderer
            
            self.mainBarsRenderer.optimizationLevel = BaseConstants.barsChartOptimizationLevel
            self.previewBarsRenderer.optimizationLevel = BaseConstants.barsChartOptimizationLevel
        }
    }
    
    private var graphControllers: [GraphController] = []
    private let horizontalScalesRenderer = HorizontalScalesRenderer()
    
    private let verticalLineRenderer = VerticalLinesRenderer()
    
    var chartVisibility: [Bool] = []
    var zoomChartVisibility: [Bool] = []
    
    private let initialChartCollection: ChartsCollection
    var initialChartRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    var zoomedChartRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    var totalHorizontalRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    
    var lastChartInteractionPoint: CGPoint = .zero
    var isChartInteractionBegun: Bool = false
    
    override public init(chartsCollection: ChartsCollection)  {
        self.initialChartCollection = chartsCollection
    
        self.graphControllers = chartsCollection.chartValues.map { _ in GraphController(isZoomed: false, mainBarsRenderer: BarChartRenderer(step: true), previewBarsRenderer: BarChartRenderer(step: true))
        }
        
        super.init(chartsCollection: chartsCollection)
        
        self.chartVisibility = Array(repeating: true, count: chartsCollection.chartValues.count)
        self.zoomChartVisibility = self.chartVisibility
        
//        self.graphControllers.map({ $0.barsController }).forEach { controller in
//            controller.chartFrame = { [unowned self] in self.chartFrame() }
//            controller.cartViewBounds = { [unowned self] in self.cartViewBounds() }
//            controller.zoomInOnDateClosure = { [unowned self] date in
//                self.didTapZoomIn(date: date)
//            }
//            controller.setChartTitleClosure = { [unowned self] (title, animated) in
//                self.setChartTitleClosure?(title, animated)
//            }
//            controller.setDetailsViewPositionClosure = { [unowned self] (position) in
//                self.setDetailsViewPositionClosure?(position)
//            }
//            controller.setDetailsChartVisibleClosure = { [unowned self] (visible, animated) in
//                self.setDetailsChartVisibleClosure?(visible, animated)
//            }
//            controller.setDetailsViewModel = { [unowned self] (viewModel, animated) in
//                self.setDetailsViewModel?(viewModel, animated)
//            }
//            controller.updatePreviewRangeClosure = { [unowned self] (fraction, animated) in
//                self.chartRangeUpdatedClosure?(fraction, animated)
//            }
//            controller.chartRangePagingClosure = { [unowned self] (isEnabled, pageSize) in
//                self.setChartRangePagingEnabled(isEnabled: isEnabled, minimumSelectionSize: pageSize)
//            }
//        }
    }
    
    public override var mainChartRenderers: [ChartViewRenderer] {
        var renderers: [ChartViewRenderer] = []
        self.graphControllers.forEach { controller in
            renderers.append(controller.mainBarsRenderer)
        }
        renderers.append(self.horizontalScalesRenderer)
        self.graphControllers.forEach { controller in
            renderers.append(controller.verticalScalesRenderer)
            renderers.append(controller.lineBulletsRenderer)
        }
        renderers.append(self.verticalLineRenderer)
        return renderers
    }
    
    public override var navigationRenderers: [ChartViewRenderer] {
        return graphControllers.map { $0.previewBarsRenderer }
    }
    
    public override func initializeChart() {
        if let first = initialChartCollection.axisValues.first?.timeIntervalSince1970,
            let last = initialChartCollection.axisValues.last?.timeIntervalSince1970 {
            initialChartRange = CGFloat(max(first, last - BaseConstants.defaultRangePresetLength))...CGFloat(last)
        }
        setupChartCollection(chartsCollection: initialChartCollection, animated: false, isZoomed: false)
    }

    public override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        self.chartVisibility = visibility
        self.zoomChartVisibility = visibility
        let firstIndex = visibility.firstIndex(where: { $0 })
        for (index, isVisible) in visibility.enumerated() {
            let graph = graphControllers[index]
            for graphIndex in graph.chartBars.components.indices {
                graph.mainBarsRenderer.setComponentVisible(isVisible, at: graphIndex, animated: animated)
                graph.previewBarsRenderer.setComponentVisible(isVisible, at: graphIndex, animated: animated)
                graph.lineBulletsRenderer.setLineVisible(isVisible, at: graphIndex, animated: animated)
            }
            graph.verticalScalesRenderer.setVisible(isVisible, animated: animated)
            if let firstIndex = firstIndex {
                graph.verticalScalesRenderer.setHorizontalLinesVisible(index == firstIndex, animated: animated)
            }
        }
        
//        updateVerticalLimitsAndRange(horizontalRange: currentHorizontalRange, animated: true)
        
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
    }
    
    private func findClosestDateTo(dateToFind: Date) -> (Date, Int)? {
        guard self.initialChartCollection.axisValues.count > 0 else { return nil }
        var closestDate = self.initialChartCollection.axisValues[0]
        var minIndex = 0
        for (index, date) in self.initialChartCollection.axisValues.enumerated() {
            if abs(dateToFind.timeIntervalSince(date)) < abs(dateToFind.timeIntervalSince(closestDate)) {
                closestDate = date
                minIndex = index
            }
        }
        return (closestDate, minIndex)
    }
    
    public override func chartInteractionDidBegin(point: CGPoint) {
        let horizontalRange = currentHorizontalRange
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }
        
        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }
        
        let chartInteractionWasBegin = isChartInteractionBegun
        super.chartInteractionDidBegin(point: point)
        
//        for graphController in graphControllers {
//            graphController.lineBulletsRenderer.bullets = graphController.chartBars.components.map { component in
//                LineBulletsRenderer.Bullet(coordinate: component.values[minIndex], color: component.color)
//            }
//            graphController.lineBulletsRenderer.isEnabled = true
//        }
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        let detailsViewPosition = (chartValue - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX
        self.setDetailsViewModel?(chartDetailsViewModel(closestDate: closestDate, pointIndex: minIndex), chartInteractionWasBegin)
        self.setDetailsChartVisibleClosure?(true, true)
        self.setDetailsViewPositionClosure?(detailsViewPosition)
        self.verticalLineRenderer.values = [chartValue]
    }
    
//    func chartDetailsViewModel(closestDate: Date, pointIndex: Int) -> ChartDetailsViewModel {
//        var viewModel = super.chartDetailsViewModel(closestDate: closestDate, pointIndex: pointIndex)
//        let visibleChartValues = self.visibleChartValues
//        let totalSumm: CGFloat = visibleChartValues.map { CGFloat($0.values[pointIndex]) }.reduce(0, +)
//
//        viewModel.totalValue = ChartDetailsViewModel.Value(prefix: nil,
//                                                           title: "Total",
//                                                           value:  BaseConstants.detailsNumberFormatter.string(from: totalSumm),
//                                                           color: .white,
//                                                           visible: visibleChartValues.count > 1)
//        return viewModel
//    }
//
    func chartDetailsViewModel(closestDate: Date, pointIndex: Int) -> ChartDetailsViewModel {
        let values: [ChartDetailsViewModel.Value] = initialChartCollection.chartValues.enumerated().map { arg in
            let (index, component) = arg
            return ChartDetailsViewModel.Value(prefix: nil,
                                               title: component.name,
                                               value: BaseConstants.detailsNumberFormatter.string(from: NSNumber(value: component.values[pointIndex])) ?? "",
                                               color: component.color,
                                               visible: chartVisibility[index])
        }
        let dateString: String
        if isZoomed {
            dateString = BaseConstants.timeDateFormatter.string(from: closestDate)
        } else {
            dateString = BaseConstants.headerMediumRangeFormatter.string(from: closestDate)
        }
        let viewModel = ChartDetailsViewModel(title: dateString,
                                              showArrow: !self.isZoomed,
                                              showPrefixes: false,
                                              values: values,
                                              totalValue: nil,
                                              tapAction: { [weak self] in })
        return viewModel
    }
    
    public override func chartInteractionDidEnd() {
        self.isChartInteractionBegun = false
    }
    
    public override var currentHorizontalRange: ClosedRange<CGFloat> {
        return graphControllers.first?.mainBarsRenderer.horizontalRange.end ?? BaseConstants.defaultRange
    }
    
    public override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        let lowerPercent = (currentHorizontalRange.lowerBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        let upperPercent = (currentHorizontalRange.upperBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        return lowerPercent...upperPercent
    }
    
    public override func cancelChartInteraction() {
        super.cancelChartInteraction()
        self.graphControllers.forEach { controller in
            controller.lineBulletsRenderer.isEnabled = false
        }
        
        self.setDetailsChartVisibleClosure?(false, true)
        self.verticalLineRenderer.values = []
    }
    
    func setupChartCollection(chartsCollection: ChartsCollection, animated: Bool, isZoomed: Bool) {
        for (index, controller) in self.graphControllers.enumerated() {
            let chart = chartsCollection.chartValues[index]
            let points = chart.values.enumerated().map({ (arg) -> CGPoint in
                return CGPoint(x: chartsCollection.axisValues[arg.offset].timeIntervalSince1970,
                               y: arg.element)
            })
            
            let (width, chartBars, totalHorizontalRange, totalVerticalRange) = BarChartRenderer.BarsData.initialComponents(chartsCollection: chartsCollection)
            controller.chartBars = chartBars
            controller.barsWidth = width
        
            controller.verticalScalesRenderer.labelsColor = chart.color
            
            controller.totalVerticalRange = totalVerticalRange
            self.totalHorizontalRange = totalHorizontalRange
//            controller.lineBulletsRenderer.bullets = chartBars.components.map { LineBulletsRenderer.Bullet(coordinate: $0.values.first ?? .zero,
//                                                                                               color: $0.color) }
            controller.previewBarsRenderer.setup(horizontalRange: self.totalHorizontalRange, animated: animated)
            controller.previewBarsRenderer.setup(verticalRange: controller.totalVerticalRange, animated: animated)
            
            controller.mainBarsRenderer.bars = chartBars
            controller.previewBarsRenderer.bars = chartBars
            
            controller.verticalScalesRenderer.setHorizontalLinesVisible((index == 0), animated: animated)
            controller.verticalScalesRenderer.isRightAligned = (index != 0)
        }
                
        let chartRange: ClosedRange<CGFloat>
        if isZoomed {
            chartRange = zoomedChartRange
        } else {
            chartRange = initialChartRange
        }
        
//        updateHorizontalLimits(horizontalRange: chartRange, animated: animated)
        updateMainChartHorizontalRange(range: chartRange, animated: animated)
        updateMainChartVerticalRange(range: chartRange, animated: animated)
//        updateVerticalLimitsAndRange(horizontalRange: chartRange, animated: animated)
        
        self.chartRangeUpdatedClosure?(currentChartHorizontalRangeFraction, animated)
    }
    
//    func setupChartCollection(chartsCollection: ChartsCollection, animated: Bool, isZoomed: Bool) {
//        if animated {
//            TimeInterval.setDefaultSuration(.expandAnimationDuration)
//            DispatchQueue.main.asyncAfter(deadline: .now() + .expandAnimationDuration) {
//                TimeInterval.setDefaultSuration(.osXDuration)
//            }
//        }
//
//        self.initialChartsCollection = chartsCollection
//        self.isZoomed = isZoomed
//
//        self.setBackButtonVisibilityClosure?(isZoomed, animated)
//
//        self.graphControllers.forEach { controller in
//            controller.barsController.willAppear(animated: animated)
//        }
//
//        self.refreshChartToolsClosure?(animated)
//    }
    
    public override func didTapZoomIn(date: Date) {
        guard isZoomed == false else { return }
        cancelChartInteraction()
        self.getDetailsData?(date, { updatedCollection in
            if let updatedCollection = updatedCollection {
                self.initialChartRange = self.currentHorizontalRange
                if let startDate = updatedCollection.axisValues.first,
                    let endDate = updatedCollection.axisValues.last {
                    self.zoomedChartRange = CGFloat(max(date.timeIntervalSince1970, startDate.timeIntervalSince1970))...CGFloat(min(date.timeIntervalSince1970 + .day - .hour, endDate.timeIntervalSince1970))
                } else {
                    self.zoomedChartRange = CGFloat(date.timeIntervalSince1970)...CGFloat(date.timeIntervalSince1970 + .day - 1)
                }
                self.setupChartCollection(chartsCollection: updatedCollection, animated: true, isZoomed: true)
            }
        })
    }
    
    public override func didTapZoomOut() {
        cancelChartInteraction()
        self.setupChartCollection(chartsCollection: self.initialChartCollection, animated: true, isZoomed: false)
    }
    
    public override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        cancelChartInteraction()
              
        let horizontalRange = ClosedRange(uncheckedBounds:
            (lower: totalHorizontalRange.lowerBound + rangeFraction.lowerBound * totalHorizontalRange.distance,
             upper: totalHorizontalRange.lowerBound + rangeFraction.upperBound * totalHorizontalRange.distance))
        
        zoomedChartRange = horizontalRange
//        updateChartRangeTitle(animated: true)
        
        updateMainChartHorizontalRange(range: horizontalRange, animated: false)
//        updateHorizontalLimits(horizontalRange: horizontalRange, animated: true)
//        updateVerticalLimitsAndRange(horizontalRange: horizontalRange, animated: true)

//        barsController.chartRangeFractionDidUpdated(rangeFraction)
//
//        let totalHorizontalRange = barsController.totalHorizontalRange
//        let horizontalRange = ClosedRange(uncheckedBounds:
//            (lower: totalHorizontalRange.lowerBound + rangeFraction.lowerBound * totalHorizontalRange.distance,
//             upper: totalHorizontalRange.lowerBound + rangeFraction.upperBound * totalHorizontalRange.distance))
//
//        updateMainChartHorizontalRange(range: horizontalRange, animated: false)
    }
    
    func updateMainChartHorizontalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        self.graphControllers.forEach { controller in
            controller.mainBarsRenderer.setup(horizontalRange: range, animated: animated)
//            controller.horizontalScalesRenderer.setup(horizontalRange: range, animated: animated)
            controller.verticalScalesRenderer.setup(horizontalRange: range, animated: animated)
            controller.lineBulletsRenderer.setup(horizontalRange: range, animated: animated)
        }
        self.horizontalScalesRenderer.setup(horizontalRange: range, animated: animated)
        self.verticalLineRenderer.setup(horizontalRange: range, animated: animated)
    }
    
    func updateMainChartVerticalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        self.verticalLineRenderer.setup(verticalRange: range, animated: animated)
        
        self.graphControllers.forEach { controller in
            controller.lineBulletsRenderer.setup(verticalRange: range, animated: animated)
        }
    }
    
    override public func apply(colorMode: GColorMode, animated: Bool) {
        super.apply(colorMode: colorMode, animated: animated)
        
        self.graphControllers.forEach { controller in
            controller.verticalScalesRenderer.horizontalLinesColor = colorMode.chartHelperLinesColor
            controller.lineBulletsRenderer.setInnerColor(colorMode.chartBackgroundColor, animated: animated)
            controller.verticalScalesRenderer.axisXColor = colorMode.chartStrongLinesColor
        }
        verticalLineRenderer.linesColor = colorMode.chartStrongLinesColor
    }
    
    public override var drawChartVisibity: Bool {
        return true
    }
}

//TODO: Убрать Performance полоски сверзу чартов (Не забыть)
//TODO: Добавить ховеры на кнопки
