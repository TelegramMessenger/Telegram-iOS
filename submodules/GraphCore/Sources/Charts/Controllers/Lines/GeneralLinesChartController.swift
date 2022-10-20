//
//  LinesChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

private enum Constants {
    static let defaultRange: ClosedRange<CGFloat> = 0...1
}

public class GeneralLinesChartController: BaseLinesChartController {
    private let initialChartCollection: ChartsCollection

    private let mainLinesRenderer = LinesChartRenderer()
    private let horizontalScalesRenderer = HorizontalScalesRenderer()
    private let verticalScalesRenderer = VerticalScalesRenderer()
    private let verticalLineRenderer = VerticalLinesRenderer()
    private let lineBulletsRenderer = LineBulletsRenderer()

    private let previewLinesRenderer = LinesChartRenderer()

    private var totalVerticalRange: ClosedRange<CGFloat> = Constants.defaultRange
    private var totalHorizontalRange: ClosedRange<CGFloat> = Constants.defaultRange
    
    private var prevoiusHorizontalStrideInterval: Int = 1
    
    private (set) var chartLines: [LinesChartRenderer.LineData] = []

    override public init(chartsCollection: ChartsCollection)  {
        self.initialChartCollection = chartsCollection
        self.mainLinesRenderer.lineWidth = 2
        self.mainLinesRenderer.optimizationLevel = BaseConstants.linesChartOptimizationLevel
        self.previewLinesRenderer.optimizationLevel = BaseConstants.previewLinesChartOptimizationLevel

        self.lineBulletsRenderer.isEnabled = false

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
        self.lineBulletsRenderer.bullets = self.chartLines.map { LineBulletsRenderer.Bullet(coordinate: $0.points.first ?? .zero, offset: .zero,
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
        
        updateHorizontalLimits(horizontalRange: chartRange, animated: animated)
        updateMainChartHorizontalRange(range: chartRange, animated: animated)
        updateVerticalLimitsAndRange(horizontalRange: chartRange, animated: animated)
        self.chartRangeUpdatedClosure?(currentChartHorizontalRangeFraction, animated)
    }
    
   public  override func initializeChart() {
        if let first = initialChartCollection.axisValues.first?.timeIntervalSince1970,
            let last = initialChartCollection.axisValues.last?.timeIntervalSince1970 {
            initialChartRange = CGFloat(max(first, last - BaseConstants.defaultRangePresetLength))...CGFloat(last)
        }
        setupChartCollection(chartsCollection: initialChartCollection, animated: false, isZoomed: false)
    }
    
    public override var mainChartRenderers: [ChartViewRenderer] {
        return [//performanceRenderer,
                mainLinesRenderer,
                horizontalScalesRenderer,
                verticalScalesRenderer,
                verticalLineRenderer,
                lineBulletsRenderer
        ]
    }
    
    public override var navigationRenderers: [ChartViewRenderer] {
        return [previewLinesRenderer]
    }
    
    public override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        chartVisibility = visibility
        zoomChartVisibility = visibility
        for (index, isVisible) in visibility.enumerated() {
            mainLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
            previewLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
            lineBulletsRenderer.setLineVisible(isVisible, at: index, animated: animated)
        }
        
        updateVerticalLimitsAndRange(horizontalRange: currentHorizontalRange, animated: true)
     
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint, manual: false)
        }
    }

    public override func chartInteractionDidBegin(point: CGPoint, manual: Bool = true) {
        if manual && !isChartInteracting && !self.verticalLineRenderer.values.isEmpty {
            self.cancelChartInteraction()
            ignoreInteraction = true
            return
        }
        let horizontalRange = mainLinesRenderer.horizontalRange.current
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }

        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }
        
        let chartInteractionWasBegin = isChartInteractionBegun
        super.chartInteractionDidBegin(point: point)

        self.lineBulletsRenderer.bullets = chartLines.compactMap { chart in
            return LineBulletsRenderer.Bullet(coordinate: chart.points[minIndex], offset: .zero, color: chart.color)
        }
        self.lineBulletsRenderer.isEnabled = true
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        var chartValueUpdated = true
        if self.verticalLineRenderer.values == [chartValue] {
            chartValueUpdated = false
        }
        let detailsViewPosition = (chartValue - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX
        self.setDetailsViewModel?(chartDetailsViewModel(closestDate: closestDate, pointIndex: minIndex, loading: false), chartInteractionWasBegin, chartInteractionWasBegin && chartValueUpdated)
        self.setDetailsChartVisibleClosure?(true, true)
        self.setDetailsViewPositionClosure?(detailsViewPosition)
        self.verticalLineRenderer.values = [chartValue]
    }
    
    
    public override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        let lowerPercent = (currentHorizontalRange.lowerBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        let upperPercent = (currentHorizontalRange.upperBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        return lowerPercent...upperPercent
    }
    
    public override var currentHorizontalRange: ClosedRange<CGFloat> {
        return mainLinesRenderer.horizontalRange.end
    }

    public override func cancelChartInteraction() {
        super.cancelChartInteraction()
        self.lineBulletsRenderer.isEnabled = false
        
        self.setDetailsChartVisibleClosure?(false, true)
        self.verticalLineRenderer.values = []
    }
    
    public override func didTapZoomOut() {
        cancelChartInteraction()
        self.setupChartCollection(chartsCollection: initialChartCollection, animated: true, isZoomed: false)
    }
    
    var visibleCharts: [LinesChartRenderer.LineData] {
        let visibleCharts: [LinesChartRenderer.LineData] = chartVisibility.enumerated().compactMap { args in
            args.element ? chartLines[args.offset] : nil
        }
        return visibleCharts
    }
    
    public override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>, animated: Bool = true) {
        cancelChartInteraction()
        
        let horizontalRange = ClosedRange(uncheckedBounds:
            (lower: totalHorizontalRange.lowerBound + rangeFraction.lowerBound * totalHorizontalRange.distance,
             upper: totalHorizontalRange.lowerBound + rangeFraction.upperBound * totalHorizontalRange.distance))
        
        zoomedChartRange = horizontalRange
        updateChartRangeTitle(animated: animated)

        updateMainChartHorizontalRange(range: horizontalRange, animated: false)
        updateHorizontalLimits(horizontalRange: horizontalRange, animated: animated)
        updateVerticalLimitsAndRange(horizontalRange: horizontalRange, animated: animated)
    }
    
    func updateMainChartHorizontalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        mainLinesRenderer.setup(horizontalRange: range, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalLineRenderer.setup(horizontalRange: range, animated: animated)
        lineBulletsRenderer.setup(horizontalRange: range, animated: animated)
    }

    func updateMainChartVerticalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        mainLinesRenderer.setup(verticalRange: range, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalLineRenderer.setup(verticalRange: range, animated: animated)
        lineBulletsRenderer.setup(verticalRange: range, animated: animated)
    }
    
    func updateHorizontalLimits(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
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
    
    override public func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        horizontalScalesRenderer.labelsColor = theme.chartLabelsColor
        verticalScalesRenderer.labelsColor = theme.chartLabelsColor
        verticalScalesRenderer.axisXColor = theme.chartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = theme.chartHelperLinesColor
        lineBulletsRenderer.setInnerColor(theme.chartBackgroundColor, animated: animated)
        verticalLineRenderer.linesColor = theme.chartStrongLinesColor
    }
}
