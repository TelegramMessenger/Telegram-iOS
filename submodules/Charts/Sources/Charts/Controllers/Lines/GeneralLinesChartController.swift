//
//  LinesChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

private enum Constants {
    static let defaultRange: ClosedRange<CGFloat> = 0...1
}

class GeneralLinesChartController: BaseLinesChartController {
    private let initialChartCollection: ChartsCollection

    private let mainLinesRenderer = LinesChartRenderer()
    private let horizontalScalesRenderer = HorizontalScalesRenderer()
    private let verticalScalesRenderer = VerticalScalesRenderer()
    private let verticalLineRenderer = VerticalLinesRenderer()
    private let lineBulletsRenerer = LineBulletsRenerer()

    private let previewLinesRenderer = LinesChartRenderer()

    private var totalVerticalRange: ClosedRange<CGFloat> = Constants.defaultRange
    private var totalHorizontalRange: ClosedRange<CGFloat> = Constants.defaultRange
    
    private var prevoiusHorizontalStrideInterval: Int = 1
    
    private (set) var chartLines: [LinesChartRenderer.LineData] = []

    override init(chartsCollection: ChartsCollection) {
        self.initialChartCollection = chartsCollection
        self.mainLinesRenderer.lineWidth = 2
        self.mainLinesRenderer.optimizationLevel = BaseConstants.linesChartOptimizationLevel
        self.previewLinesRenderer.optimizationLevel = BaseConstants.previewLinesChartOptimizationLevel

        self.lineBulletsRenerer.isEnabled = false

        super.init(chartsCollection: chartsCollection)
        self.zoomChartVisibility = chartVisibility
    }
    
    override func setupChartCollection(chartsCollection: ChartsCollection, animated: Bool, isZoomed: Bool) {
        super.setupChartCollection(chartsCollection: chartsCollection, animated: animated, isZoomed: isZoomed)
        
        self.chartLines = chartsCollection.chartValues.map { chart in
            let points = chart.values.enumerated().map({ (arg) -> CGPoint in
                return CGPoint(x: chartsCollection.axisValues[arg.offset].timeIntervalSince1970,
                               y: arg.element)
            })
            return LinesChartRenderer.LineData(color: chart.color, points: points)
        }
        
        self.prevoiusHorizontalStrideInterval = -1
        self.totalVerticalRange = LinesChartRenderer.LineData.verticalRange(lines: chartLines) ?? Constants.defaultRange
        self.totalHorizontalRange = LinesChartRenderer.LineData.horizontalRange(lines: chartLines) ?? Constants.defaultRange
        self.lineBulletsRenerer.bullets = self.chartLines.map { LineBulletsRenerer.Bullet(coordinate: $0.points.first ?? .zero,
                                                                                          color: $0.color)}

        let chartRange: ClosedRange<CGFloat>
        if isZoomed {
            chartRange = zoomedChartRange
        } else {
            chartRange = initialChartRange
        }

        self.previewLinesRenderer.setup(horizontalRange: totalHorizontalRange, animated: animated)
        self.previewLinesRenderer.setup(verticalRange: totalVerticalRange, animated: animated)
        
        self.mainLinesRenderer.setLines(lines: chartLines, animated: animated)
        self.previewLinesRenderer.setLines(lines: chartLines, animated: animated)
        
        updateHorizontalLimists(horizontalRange: chartRange, animated: animated)
        updateMainChartHorizontalRange(range: chartRange, animated: animated)
        updateVerticalLimitsAndRange(horizontalRange: chartRange, animated: animated)
        
        self.chartRangeUpdatedClosure?(currentChartHorizontalRangeFraction, animated)
    }
    
    override func initializeChart() {
        if let first = initialChartCollection.axisValues.first?.timeIntervalSince1970,
            let last = initialChartCollection.axisValues.last?.timeIntervalSince1970 {
            initialChartRange = CGFloat(max(first, last - BaseConstants.defaultRangePresetLength))...CGFloat(last)
        }
        setupChartCollection(chartsCollection: initialChartCollection, animated: false, isZoomed: false)
    }
    
    override var mainChartRenderers: [ChartViewRenderer] {
        return [//performanceRenderer,
                mainLinesRenderer,
                horizontalScalesRenderer,
                verticalScalesRenderer,
                verticalLineRenderer,
                lineBulletsRenerer
        ]
    }
    
    override var navigationRenderers: [ChartViewRenderer] {
        return [previewLinesRenderer]
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        chartVisibility = visibility
        zoomChartVisibility = visibility
        for (index, isVisible) in visibility.enumerated() {
            mainLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
            previewLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
            lineBulletsRenerer.setLineVisible(isVisible, at: index, animated: animated)
        }
        
        updateVerticalLimitsAndRange(horizontalRange: currentHorizontalRange, animated: true)
     
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
    }

    override func chartInteractionDidBegin(point: CGPoint) {
        let horizontalRange = mainLinesRenderer.horizontalRange.current
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }
        let chartInteractionWasBegin = isChartInteractionBegun

        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }
        
        super.chartInteractionDidBegin(point: point)

        self.lineBulletsRenerer.bullets = chartLines.compactMap { chart in
            return LineBulletsRenerer.Bullet(coordinate: chart.points[minIndex], color: chart.color)
        }
        self.lineBulletsRenerer.isEnabled = true
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        let detailsViewPosition = (chartValue - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX
        self.setDetailsViewModel?(chartDetailsViewModel(closestDate: closestDate, pointIndex: minIndex), chartInteractionWasBegin)
        self.setDetailsChartVisibleClosure?(true, true)
        self.setDetailsViewPositionClosure?(detailsViewPosition)
        self.verticalLineRenderer.values = [chartValue]
    }
    
    
    override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        let lowerPercent = (currentHorizontalRange.lowerBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        let upperPercent = (currentHorizontalRange.upperBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        return lowerPercent...upperPercent
    }
    
    override var currentHorizontalRange: ClosedRange<CGFloat> {
        return mainLinesRenderer.horizontalRange.end
    }

    override func cancelChartInteraction() {
        super.cancelChartInteraction()
        self.lineBulletsRenerer.isEnabled = false
        
        self.setDetailsChartVisibleClosure?(false, true)
        self.verticalLineRenderer.values = []
    }
    
    override func didTapZoomOut() {
        cancelChartInteraction()
        self.setupChartCollection(chartsCollection: initialChartCollection, animated: true, isZoomed: false)
    }
    
    var visibleCharts: [LinesChartRenderer.LineData] {
        let visibleCharts: [LinesChartRenderer.LineData] = chartVisibility.enumerated().compactMap { args in
            args.element ? chartLines[args.offset] : nil
        }
        return visibleCharts
    }
    
    override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        cancelChartInteraction()
        
        let horizontalRange = ClosedRange(uncheckedBounds:
            (lower: totalHorizontalRange.lowerBound + rangeFraction.lowerBound * totalHorizontalRange.distance,
             upper: totalHorizontalRange.lowerBound + rangeFraction.upperBound * totalHorizontalRange.distance))
        
        zoomedChartRange = horizontalRange
        updateChartRangeTitle(animated: true)

        updateMainChartHorizontalRange(range: horizontalRange, animated: false)
        updateHorizontalLimists(horizontalRange: horizontalRange, animated: true)
        updateVerticalLimitsAndRange(horizontalRange: horizontalRange, animated: true)
    }
    
    func updateMainChartHorizontalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        mainLinesRenderer.setup(horizontalRange: range, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalLineRenderer.setup(horizontalRange: range, animated: animated)
        lineBulletsRenerer.setup(horizontalRange: range, animated: animated)
    }

    func updateMainChartVerticalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        mainLinesRenderer.setup(verticalRange: range, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalLineRenderer.setup(verticalRange: range, animated: animated)
        lineBulletsRenerer.setup(verticalRange: range, animated: animated)
    }
    
    func updateHorizontalLimists(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let (stride, labels) = horizontalLimitsLabels(horizontalRange: horizontalRange,
                                                         scaleType: isZoomed ? .hour : .day,
                                                         prevoiusHorizontalStrideInterval: prevoiusHorizontalStrideInterval) {
            self.horizontalScalesRenderer.setup(labels: labels, animated: animated)
            self.prevoiusHorizontalStrideInterval = stride
        }
    }
    
    func updateVerticalLimitsAndRange(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let verticalRange = LinesChartRenderer.LineData.verticalRange(lines: visibleCharts,
                                                                         calculatingRange: horizontalRange,
                                                                         addBounds: true) {
            
            
            let (range, labels) = verticalLimitsLabels(verticalRange: verticalRange)
            
            if verticalScalesRenderer.verticalRange.end != range {
                verticalScalesRenderer.setup(verticalLimitsLabels: labels, animated: animated)
                updateMainChartVerticalRange(range: range, animated: animated)
            }
            verticalScalesRenderer.setVisible(true, animated: animated)
        } else {
            verticalScalesRenderer.setVisible(false, animated: animated)
        }
        
        guard let previewVerticalRange = LinesChartRenderer.LineData.verticalRange(lines: visibleCharts) else { return }

        if previewLinesRenderer.verticalRange.end != previewVerticalRange {
            previewLinesRenderer.setup(verticalRange: previewVerticalRange, animated: animated)
        }
    }
    
    override func apply(colorMode: ColorMode, animated: Bool) {
        horizontalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.axisXColor = colorMode.chartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = colorMode.chartHelperLinesColor
        lineBulletsRenerer.setInnerColor(colorMode.chartBackgroundColor, animated: animated)
        verticalLineRenderer.linesColor = colorMode.chartStrongLinesColor
    }
}
