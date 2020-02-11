//
//  BarsComponentController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/14/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class BarsComponentController: GeneralChartComponentController {
    let mainBarsRenderer: BarChartRenderer
    let horizontalScalesRenderer: HorizontalScalesRenderer
    let verticalScalesRenderer: VerticalScalesRenderer
    
    let previewBarsChartRenderer: BarChartRenderer
    private(set) var barsWidth: CGFloat = 1
    
    private (set) var chartBars: BarChartRenderer.BarsData = .blank
    
    init(isZoomed: Bool,
         mainBarsRenderer: BarChartRenderer,
         horizontalScalesRenderer: HorizontalScalesRenderer,
         verticalScalesRenderer: VerticalScalesRenderer,
         previewBarsChartRenderer: BarChartRenderer) {
        self.mainBarsRenderer = mainBarsRenderer
        self.horizontalScalesRenderer = horizontalScalesRenderer
        self.verticalScalesRenderer = verticalScalesRenderer
        self.previewBarsChartRenderer = previewBarsChartRenderer
        
        self.mainBarsRenderer.optimizationLevel = BaseConstants.barsChartOptimizationLevel
        self.previewBarsChartRenderer.optimizationLevel = BaseConstants.barsChartOptimizationLevel

        super.init(isZoomed: isZoomed)
    }
    
    override func initialize(chartsCollection: ChartsCollection, initialDate: Date, totalHorizontalRange _: ClosedRange<CGFloat>, totalVerticalRange _: ClosedRange<CGFloat>) {
        let (width, chartBars, totalHorizontalRange, totalVerticalRange) = BarChartRenderer.BarsData.initialComponents(chartsCollection: chartsCollection)
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
        setConponentsVisible(visible: true, animated: animated)
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
        setConponentsVisible(visible: false, animated: false)
    }
    
    func setConponentsVisible(visible: Bool, animated: Bool) {
        mainBarsRenderer.setVisible(visible, animated: animated)
        horizontalScalesRenderer.setVisible(visible, animated: animated)
        verticalScalesRenderer.setVisible(visible, animated: animated)
        previewBarsChartRenderer.setVisible(visible, animated: animated)
    }
    
    func setupMainChart(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainBarsRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
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
        
        if let range = BarChartRenderer.BarsData.verticalRange(bars: visibleBars) {
            previewBarsChartRenderer.setup(verticalRange: range, animated: animated)
        }
    }
    
    func setupMainChart(verticalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainBarsRenderer.setup(verticalRange: verticalRange, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        verticalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
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
        
        viewModel.totalValue = ChartDetailsViewModel.Value(prefix: nil,
                                                           title: "Total",
                                                           value:  BaseConstants.detailsNumberFormatter.string(from: totalSumm),
                                                           color: .white,
                                                           visible: visibleChartValues.count > 1)
        return viewModel
    }
    
    override var currentMainRangeRenderer: BaseChartRenderer {
        return mainBarsRenderer
    }
    
    override var currentPreviewRangeRenderer: BaseChartRenderer {
        return previewBarsChartRenderer
    }
    
    override func showDetailsView(at chartPosition: CGFloat, detailsViewPosition: CGFloat, dataIndex: Int, date: Date, animted: Bool) {
        let rangeWithOffset = detailsViewPosition - barsWidth / currentHorizontalMainChartRange.distance * chartFrame().width / 2
        super.showDetailsView(at: chartPosition, detailsViewPosition: rangeWithOffset, dataIndex: dataIndex, date: date, animted: animted)
        mainBarsRenderer.setSelectedIndex(dataIndex, animated: true)
    }
    
    override func hideDetailsView(animated: Bool) {
        super.hideDetailsView(animated: animated)
        
        mainBarsRenderer.setSelectedIndex(nil, animated: animated)
    }
    override func apply(colorMode: ColorMode, animated: Bool) {
        super.apply(colorMode: colorMode, animated: animated)
        
        horizontalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.axisXColor = colorMode.barChartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = colorMode.barChartStrongLinesColor
        mainBarsRenderer.update(backgroundColor: colorMode.chartBackgroundColor, animated: false)
        previewBarsChartRenderer.update(backgroundColor: colorMode.chartBackgroundColor, animated: false)
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
}
