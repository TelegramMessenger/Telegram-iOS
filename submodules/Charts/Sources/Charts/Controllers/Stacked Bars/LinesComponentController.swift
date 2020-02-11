//
//  LinesComponentController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/14/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class LinesComponentController: GeneralChartComponentController {
    let mainLinesRenderer: LinesChartRenderer
    let horizontalScalesRenderer: HorizontalScalesRenderer
    let verticalScalesRenderer: VerticalScalesRenderer
    let verticalLineRenderer: VerticalLinesRenderer
    let lineBulletsRenerer: LineBulletsRenerer
    
    let previewLinesChartRenderer: LinesChartRenderer
    
    private let zoomedLinesRenderer = LinesChartRenderer()
    private let zoomedPreviewLinesRenderer = LinesChartRenderer()

    private let userLinesTransitionAnimation: Bool

    private(set) var chartLines: [LinesChartRenderer.LineData] = []
    
    init(isZoomed: Bool,
         userLinesTransitionAnimation: Bool,
         mainLinesRenderer: LinesChartRenderer,
         horizontalScalesRenderer: HorizontalScalesRenderer,
         verticalScalesRenderer: VerticalScalesRenderer,
         verticalLineRenderer: VerticalLinesRenderer,
         lineBulletsRenerer: LineBulletsRenerer,
         previewLinesChartRenderer: LinesChartRenderer) {
        self.mainLinesRenderer = mainLinesRenderer
        self.horizontalScalesRenderer = horizontalScalesRenderer
        self.verticalScalesRenderer = verticalScalesRenderer
        self.verticalLineRenderer = verticalLineRenderer
        self.lineBulletsRenerer = lineBulletsRenerer
        self.previewLinesChartRenderer = previewLinesChartRenderer
        self.userLinesTransitionAnimation = userLinesTransitionAnimation
        
        super.init(isZoomed: isZoomed)
        
        self.mainLinesRenderer.lineWidth = BaseConstants.mainChartLineWidth
        self.mainLinesRenderer.optimizationLevel = BaseConstants.linesChartOptimizationLevel
        self.previewLinesChartRenderer.lineWidth = BaseConstants.previewChartLineWidth
        self.previewLinesChartRenderer.optimizationLevel = BaseConstants.previewLinesChartOptimizationLevel
        
        self.lineBulletsRenerer.isEnabled = false
    }
    
    override func initialize(chartsCollection: ChartsCollection,
                             initialDate: Date,
                             totalHorizontalRange _: ClosedRange<CGFloat>,
                             totalVerticalRange _: ClosedRange<CGFloat>) {
        let (chartLines, totalHorizontalRange, totalVerticalRange) = LinesChartRenderer.LineData.initialComponents(chartsCollection: chartsCollection)
        self.chartLines = chartLines
        
        self.lineBulletsRenerer.bullets = self.chartLines.map { LineBulletsRenerer.Bullet(coordinate: $0.points.first ?? .zero,
                                                                                          color: $0.color)}
        
        super.initialize(chartsCollection: chartsCollection,
                         initialDate: initialDate,
                         totalHorizontalRange: totalHorizontalRange,
                         totalVerticalRange: totalVerticalRange)
        
        self.mainLinesRenderer.setup(verticalRange: totalVerticalRange, animated: true)
    }
    
    override func willAppear(animated: Bool) {
        mainLinesRenderer.setLines(lines: self.chartLines, animated: animated && userLinesTransitionAnimation)
        previewLinesChartRenderer.setLines(lines: self.chartLines, animated: animated && userLinesTransitionAnimation)
        
        previewLinesChartRenderer.setup(verticalRange: totalVerticalRange, animated: animated)
        previewLinesChartRenderer.setup(horizontalRange: totalHorizontalRange, animated: animated)
        
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
        mainLinesRenderer.setVisible(visible, animated: animated)
        horizontalScalesRenderer.setVisible(visible, animated: animated)
        verticalScalesRenderer.setVisible(visible, animated: animated)
        verticalLineRenderer.setVisible(visible, animated: animated)
        previewLinesChartRenderer.setVisible(visible, animated: animated)
        lineBulletsRenerer.setVisible(visible, animated: animated)
    }
    
    func setupMainChart(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainLinesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        verticalLineRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        lineBulletsRenerer.setup(horizontalRange: horizontalRange, animated: animated)
    }
    
    var visibleLines: [LinesChartRenderer.LineData] {
        return chartVisibility.enumerated().compactMap { $0.element ? chartLines[$0.offset] : nil }
    }
    
    func updateChartVerticalRanges(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let range = LinesChartRenderer.LineData.verticalRange(lines: visibleLines,
                                                                 calculatingRange: horizontalRange,
                                                                 addBounds: true) {
            let (range, labels) = verticalLimitsLabels(verticalRange: range)
            if verticalScalesRenderer.verticalRange.end != range {
                verticalScalesRenderer.setup(verticalLimitsLabels: labels, animated: animated)
            }
            
            setupMainChart(verticalRange: range, animated: animated)
            verticalScalesRenderer.setVisible(true, animated: animated)
        } else {
            verticalScalesRenderer.setVisible(false, animated: animated)
        }
        
        if let range = LinesChartRenderer.LineData.verticalRange(lines: visibleLines) {
            previewLinesChartRenderer.setup(verticalRange: range, animated: animated)
        }
    }
    
    func setupMainChart(verticalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainLinesRenderer.setup(verticalRange: verticalRange, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        verticalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        verticalLineRenderer.setup(verticalRange: verticalRange, animated: animated)
        lineBulletsRenerer.setup(verticalRange: verticalRange, animated: animated)
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        super.updateChartsVisibility(visibility: visibility, animated: animated)
        for (index, isVisible) in visibility.enumerated() {
            mainLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
            previewLinesChartRenderer.setLineVisible(isVisible, at: index, animated: animated)
            lineBulletsRenerer.setLineVisible(isVisible, at: index, animated: animated)
        }
        updateChartVerticalRanges(horizontalRange: currentHorizontalMainChartRange, animated: true)
    }
    
    override var currentMainRangeRenderer: BaseChartRenderer {
        return mainLinesRenderer
    }
    
    override var currentPreviewRangeRenderer: BaseChartRenderer {
        return previewLinesChartRenderer
    }
    
    override func showDetailsView(at chartPosition: CGFloat, detailsViewPosition: CGFloat, dataIndex: Int, date: Date, animted: Bool) {
        super.showDetailsView(at: chartPosition, detailsViewPosition: detailsViewPosition, dataIndex: dataIndex, date: date, animted: animted)
        verticalLineRenderer.values = [chartPosition]
        verticalLineRenderer.isEnabled = true
        
        lineBulletsRenerer.isEnabled = true
        lineBulletsRenerer.setVisible(true, animated: animted)
        lineBulletsRenerer.bullets = chartLines.compactMap { chart in
            return LineBulletsRenerer.Bullet(coordinate: chart.points[dataIndex], color: chart.color)
        }
    }
    
    override func hideDetailsView(animated: Bool) {
        super.hideDetailsView(animated: animated)
        
        verticalLineRenderer.values = []
        verticalLineRenderer.isEnabled = false
        lineBulletsRenerer.isEnabled = false
    }
    
    override func apply(colorMode: ColorMode, animated: Bool) {
        super.apply(colorMode: colorMode, animated: animated)
        
        horizontalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.axisXColor = colorMode.chartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = colorMode.chartHelperLinesColor
        lineBulletsRenerer.setInnerColor(colorMode.chartBackgroundColor, animated: animated)
        verticalLineRenderer.linesColor = colorMode.chartStrongLinesColor
    }
}
