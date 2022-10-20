//
//  BarsComponentController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/14/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

class BarsComponentController: GeneralChartComponentController {
    let mainBarsRenderer: BarChartRenderer
    let horizontalScalesRenderer: HorizontalScalesRenderer
    let verticalScalesRenderer: VerticalScalesRenderer
    
    let lineBulletsRenderer = LineBulletsRenderer()
    let verticalLineRenderer = VerticalLinesRenderer()
    
    let previewBarsChartRenderer: BarChartRenderer
    private(set) var barsWidth: CGFloat = 1
    
    private (set) var chartBars: BarChartRenderer.BarsData = .blank
    
    private var step: Bool
    
    init(isZoomed: Bool,
         mainBarsRenderer: BarChartRenderer,
         horizontalScalesRenderer: HorizontalScalesRenderer,
         verticalScalesRenderer: VerticalScalesRenderer,
         previewBarsChartRenderer: BarChartRenderer,
         step: Bool = false) {
        self.mainBarsRenderer = mainBarsRenderer
        self.horizontalScalesRenderer = horizontalScalesRenderer
        self.verticalScalesRenderer = verticalScalesRenderer
        self.previewBarsChartRenderer = previewBarsChartRenderer
        self.step = step
        
        self.lineBulletsRenderer.isEnabled = false
        
        self.mainBarsRenderer.optimizationLevel = BaseConstants.barsChartOptimizationLevel
        self.previewBarsChartRenderer.optimizationLevel = BaseConstants.barsChartOptimizationLevel

        super.init(isZoomed: isZoomed)
    }
    
    override func initialize(chartsCollection: ChartsCollection, initialDate: Date, totalHorizontalRange _: ClosedRange<CGFloat>, totalVerticalRange _: ClosedRange<CGFloat>) {
        let (width, chartBars, totalHorizontalRange, totalVerticalRange) = BarChartRenderer.BarsData.initialComponents(chartsCollection: chartsCollection, separate: self.step)
        self.chartBars = chartBars
        self.barsWidth = width
        
        super.initialize(chartsCollection: chartsCollection,
                         initialDate: initialDate,
                         totalHorizontalRange: totalHorizontalRange,
                         totalVerticalRange: totalVerticalRange)
    }
    
    override func setupInitialChartRange(initialDate: Date) {
        guard let first = chartsCollection.axisValues.first?.timeIntervalSince1970,
            let last = chartsCollection.axisValues.last?.timeIntervalSince1970 else { return }
        
        let rangeStart = CGFloat(first)
        let rangeEnd = CGFloat(last)
        
        if isZoomed {
            let initalDate = CGFloat(initialDate.timeIntervalSince1970)
            
            initialHorizontalRange = max(initalDate - barsWidth, rangeStart)...min(initalDate + GeneralChartComponentConstants.defaultZoomedRangeLength - barsWidth, rangeEnd)
            initialVerticalRange = totalVerticalRange
        } else {
            super.setupInitialChartRange(initialDate: initialDate)
        }
    }

    
    override func willAppear(animated: Bool) {
        mainBarsRenderer.bars = self.chartBars
        previewBarsChartRenderer.bars = self.chartBars
        
        previewBarsChartRenderer.setup(verticalRange: totalVerticalRange, animated: animated)
        previewBarsChartRenderer.setup(horizontalRange: totalHorizontalRange, animated: animated)
        
        setupMainChart(verticalRange: initialVerticalRange, animated: animated)
        setupMainChart(horizontalRange: initialHorizontalRange, animated: animated)        
        updateChartVerticalRanges(horizontalRange: initialHorizontalRange, animated: animated)

        super.willAppear(animated: animated)
        
        updatePreviewRangeClosure?(currentChartHorizontalRangeFraction, animated)
        setComponentsVisible(visible: true, animated: animated)
        updateHorizontalLimitLabels(animated: animated, forceUpdate: true)
    }
    
    override func chartRangeDidUpdated(_ updatedRange: ClosedRange<CGFloat>) {
        super.chartRangeDidUpdated(updatedRange)
        if !isZoomed {
            initialHorizontalRange = updatedRange
        }
        setupMainChart(horizontalRange: updatedRange, animated: false)
        updateHorizontalLimitLabels(animated: true, forceUpdate: false)
        updateChartVerticalRanges(horizontalRange: updatedRange, animated: true)
    }
    
    func updateHorizontalLimitLabels(animated: Bool, forceUpdate: Bool) {
        updateHorizontalLimitLabels(horizontalScalesRenderer: horizontalScalesRenderer,
                                    horizontalRange: currentHorizontalMainChartRange,
                                    scaleType: isZoomed ? .hour : .day,
                                    forceUpdate: forceUpdate,
                                    animated: animated)
    }
    
    func prepareAppearanceAnimation(horizontalRnage: ClosedRange<CGFloat>) {
        setupMainChart(horizontalRange: horizontalRnage, animated: false)
        setComponentsVisible(visible: false, animated: false)
    }
    
    func setComponentsVisible(visible: Bool, animated: Bool) {
        mainBarsRenderer.setVisible(visible, animated: animated)
        horizontalScalesRenderer.setVisible(visible, animated: animated)
        verticalScalesRenderer.setVisible(visible, animated: animated)
        previewBarsChartRenderer.setVisible(visible, animated: animated)
    }
    
    func setupMainChart(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainBarsRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        
        verticalLineRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        lineBulletsRenderer.setup(horizontalRange: horizontalRange, animated: animated)

    }
    
    var visibleBars: BarChartRenderer.BarsData {
        let visibleComponents: [BarChartRenderer.BarsData.Component] = chartVisibility.enumerated().compactMap { args in
            args.element ? chartBars.components[args.offset] : nil
        }
        return BarChartRenderer.BarsData(barWidth: chartBars.barWidth,
                                         locations: chartBars.locations,
                                         components: visibleComponents)
    }
    
    func updateChartVerticalRanges(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let range = BarChartRenderer.BarsData.verticalRange(bars: visibleBars,
                                                               separate: self.step,
                                                               calculatingRange: horizontalRange,
                                                               addBounds: true) {
            let (range, labels) = verticalLimitsLabels(verticalRange: range)
            if verticalScalesRenderer.verticalRange.end != range {
                verticalScalesRenderer.setup(verticalLimitsLabels: labels, animated: animated)
            }
            verticalScalesRenderer.setVisible(true, animated: animated)
            
            setupMainChart(verticalRange: range, animated: animated)
        } else {
            verticalScalesRenderer.setVisible(false, animated: animated)
        }
        
        if let range = BarChartRenderer.BarsData.verticalRange(bars: visibleBars, separate: self.step) {
            previewBarsChartRenderer.setup(verticalRange: range, animated: animated)
        }
    }
    
    func setupMainChart(verticalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainBarsRenderer.setup(verticalRange: verticalRange, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        verticalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        lineBulletsRenderer.setup(verticalRange: verticalRange, animated: animated)
    }
    
    public override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        super.updateChartsVisibility(visibility: visibility, animated: animated)
        for (index, isVisible) in visibility.enumerated() {
            mainBarsRenderer.setComponentVisible(isVisible, at: index, animated: animated)
            previewBarsChartRenderer.setComponentVisible(isVisible, at: index, animated: animated)
        }
        updateChartVerticalRanges(horizontalRange: currentHorizontalMainChartRange, animated: true)
    }
    
    var visibleChartValues: [ChartsCollection.Chart] {
        let visibleCharts: [ChartsCollection.Chart] = chartVisibility.enumerated().compactMap { args in
            args.element ? chartsCollection.chartValues[args.offset] : nil
        }
        return visibleCharts
    }
    
    override func chartDetailsViewModel(closestDate: Date, pointIndex: Int) -> ChartDetailsViewModel {
        var viewModel = super.chartDetailsViewModel(closestDate: closestDate, pointIndex: pointIndex)
        let visibleChartValues = self.visibleChartValues
        let totalSumm: CGFloat = visibleChartValues.map { CGFloat($0.values[pointIndex]) }.reduce(0, +)
        viewModel.hideAction = { [weak self] in
            self?.hideDetailsView(animated: true)
        }
        if !self.step {
            viewModel.totalValue = ChartDetailsViewModel.Value(prefix: nil,
                                                               title: self.strings.total,
                                                               value: BaseConstants.detailsNumberFormatter.string(from: totalSumm),
                                                               color: .white,
                                                               visible: visibleChartValues.count > 1)
        } else {
            viewModel.title = "\(Int(closestDate.timeIntervalSince1970)):00"
        }
        return viewModel
    }
    
    override var currentMainRangeRenderer: BaseChartRenderer {
        return mainBarsRenderer
    }
    
    override var currentPreviewRangeRenderer: BaseChartRenderer {
        return previewBarsChartRenderer
    }
    
    override func showDetailsView(at chartPosition: CGFloat, detailsViewPosition: CGFloat, dataIndex: Int, date: Date, animated: Bool, feedback: Bool) {
        super.showDetailsView(at: chartPosition, detailsViewPosition: detailsViewPosition, dataIndex: dataIndex, date: date, animated: animated, feedback: feedback)
        mainBarsRenderer.setSelectedIndex(dataIndex, animated: true)
    }
    
    override func hideDetailsView(animated: Bool) {
        super.hideDetailsView(animated: animated)
        
        mainBarsRenderer.setSelectedIndex(nil, animated: animated)
    }
    override func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        super.apply(theme: theme, strings: strings, animated: animated)
        
        horizontalScalesRenderer.labelsColor = theme.chartLabelsColor
        verticalScalesRenderer.labelsColor = theme.chartLabelsColor
        verticalScalesRenderer.axisXColor = theme.barChartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = theme.barChartStrongLinesColor
        mainBarsRenderer.update(backgroundColor: theme.chartBackgroundColor, animated: false)
        previewBarsChartRenderer.update(backgroundColor: theme.chartBackgroundColor, animated: false)
        verticalLineRenderer.linesColor = theme.chartStrongLinesColor
    }
    
    override func updateChartRangeTitle(animated: Bool) {
        let fromDate = Date(timeIntervalSince1970: TimeInterval(currentHorizontalMainChartRange.lowerBound + barsWidth))
        let toDate = Date(timeIntervalSince1970: TimeInterval(currentHorizontalMainChartRange.upperBound))
        if Calendar.utc.startOfDay(for: fromDate) == Calendar.utc.startOfDay(for: toDate) {
            let stirng = BaseConstants.headerFullZoomedFormatter.string(from: fromDate)
            self.setChartTitleClosure?(stirng, animated)
        } else {
            let stirng = "\(BaseConstants.headerMediumRangeFormatter.string(from: fromDate)) - \(BaseConstants.headerMediumRangeFormatter.string(from: toDate))"
            self.setChartTitleClosure?(stirng, animated)
        }
    }
    
    override func chartInteractionDidBegin(point: CGPoint, manual: Bool = true) {
        if manual && !isChartInteracting && detailsVisible {
                  self.hideDetailsView(animated: true)
                  ignoreInteraction = true
                  return
              }
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }
        let horizontalRange = currentHorizontalMainChartRange
        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }
        
        let chartWasInteracting = isChartInteractionBegun
        lastChartInteractionPoint = point
        isChartInteractionBegun = true
        isChartInteracting = true
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        var chartValueUpdated = true
        if chartValue == currentChartValue {
            chartValueUpdated = false
        }
        currentChartValue = chartValue
        let detailsViewPosition = (chartValue - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX
        
        
        showDetailsView(at: chartValue, detailsViewPosition: detailsViewPosition, dataIndex: minIndex, date: closestDate, animated: chartWasInteracting, feedback: chartWasInteracting && chartValueUpdated)
        
        super.chartInteractionDidBegin(point: point)
        
        self.verticalLineRenderer.values = [chartValue]
//        self.verticalLineRenderer.offset = barOffset
    }
}
