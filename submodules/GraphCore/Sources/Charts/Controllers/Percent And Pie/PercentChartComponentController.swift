//
//  PercentChartComponentController.swift
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

class PercentChartComponentController: GeneralChartComponentController {
    let mainPecentChartRenderer: PecentChartRenderer
    let horizontalScalesRenderer: HorizontalScalesRenderer
    let verticalScalesRenderer: VerticalScalesRenderer
    let verticalLineRenderer: VerticalLinesRenderer
    let previewPercentChartRenderer: PecentChartRenderer
    var percentageData: PecentChartRenderer.PercentageData = .blank
    
    init(isZoomed: Bool,
         mainPecentChartRenderer: PecentChartRenderer,
         horizontalScalesRenderer: HorizontalScalesRenderer,
         verticalScalesRenderer: VerticalScalesRenderer,
         verticalLineRenderer: VerticalLinesRenderer,
         previewPercentChartRenderer: PecentChartRenderer) {
        self.mainPecentChartRenderer = mainPecentChartRenderer
        self.horizontalScalesRenderer = horizontalScalesRenderer
        self.verticalScalesRenderer = verticalScalesRenderer
        self.verticalLineRenderer = verticalLineRenderer
        self.previewPercentChartRenderer = previewPercentChartRenderer
        
        super.init(isZoomed: isZoomed)
    }
    
    override func initialize(chartsCollection: ChartsCollection, initialDate: Date, totalHorizontalRange _: ClosedRange<CGFloat>, totalVerticalRange _: ClosedRange<CGFloat>) {
        let components = chartsCollection.chartValues.map { PecentChartRenderer.PercentageData.Component(color: $0.color,
                                                                                                         values: $0.values.map { CGFloat($0) }) }
        self.percentageData = PecentChartRenderer.PercentageData(locations: chartsCollection.axisValues.map { CGFloat($0.timeIntervalSince1970) },
                                                                 components: components)
        let totalHorizontalRange = PecentChartRenderer.PercentageData.horizontalRange(data: self.percentageData) ?? BaseConstants.defaultRange
        let totalVerticalRange = BaseConstants.defaultRange
        
        super.initialize(chartsCollection: chartsCollection,
                         initialDate: initialDate,
                         totalHorizontalRange: totalHorizontalRange,
                         totalVerticalRange: totalVerticalRange)
        
        mainPecentChartRenderer.percentageData = self.percentageData
        previewPercentChartRenderer.percentageData = self.percentageData
        
        let axisValues: [CGFloat] = [0, 25, 50, 75, 100]
        let labels: [LinesChartLabel] = axisValues.map { value in
            return LinesChartLabel(value: value / 100, text: BaseConstants.detailsNumberFormatter.string(from: NSNumber(value: Double(value))) ?? "")
        }
        verticalScalesRenderer.setup(verticalLimitsLabels: labels, animated: false)
        
        setupMainChart(horizontalRange: initialHorizontalRange, animated: false)
        setupMainChart(verticalRange: initialVerticalRange, animated: false)
        previewPercentChartRenderer.setup(verticalRange: totalVerticalRange, animated: false)
        previewPercentChartRenderer.setup(horizontalRange: totalHorizontalRange, animated: false)
        updateHorizontalLimitLabels(animated: false)
    }
    
    override func willAppear(animated: Bool) {
        previewPercentChartRenderer.setup(verticalRange: totalVerticalRange, animated: animated)
        previewPercentChartRenderer.setup(horizontalRange: totalHorizontalRange, animated: animated)
        
        setConponentsVisible(visible: true, animated: true)
        
        setupMainChart(verticalRange: initialVerticalRange, animated: animated)
        setupMainChart(horizontalRange: initialHorizontalRange, animated: animated)
        
        updatePreviewRangeClosure?(currentChartHorizontalRangeFraction, animated)
        
        super.willAppear(animated: animated)
    }
    
    override func chartRangeDidUpdated(_ updatedRange: ClosedRange<CGFloat>) {
        super.chartRangeDidUpdated(updatedRange)
        
        initialHorizontalRange = updatedRange
        setupMainChart(horizontalRange: updatedRange, animated: false)
        updateHorizontalLimitLabels(animated: true)
    }
    
    func updateHorizontalLimitLabels(animated: Bool) {
        updateHorizontalLimitLabels(horizontalScalesRenderer: horizontalScalesRenderer,
                                    horizontalRange: initialHorizontalRange,
                                    scaleType: isZoomed ? .hour : .day,
                                    forceUpdate: false,
                                    animated: animated)
    }
    
    func prepareAppearanceAnimation(horizontalRnage: ClosedRange<CGFloat>) {
        setupMainChart(horizontalRange: horizontalRnage, animated: false)
        setConponentsVisible(visible: false, animated: false)
    }
    
    func setConponentsVisible(visible: Bool, animated: Bool) {
        mainPecentChartRenderer.setVisible(visible, animated: animated)
        horizontalScalesRenderer.setVisible(visible, animated: animated)
        verticalScalesRenderer.setVisible(visible, animated: animated)
        verticalLineRenderer.setVisible(visible, animated: animated)
        previewPercentChartRenderer.setVisible(visible, animated: animated)
    }
    
    func setupMainChart(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainPecentChartRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        verticalLineRenderer.setup(horizontalRange: horizontalRange, animated: animated)
    }
    
    func setupMainChart(verticalRange: ClosedRange<CGFloat>, animated: Bool) {
        mainPecentChartRenderer.setup(verticalRange: verticalRange, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        verticalScalesRenderer.setup(verticalRange: verticalRange, animated: animated)
        verticalLineRenderer.setup(verticalRange: verticalRange, animated: animated)
    }
    
    public override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        super.updateChartsVisibility(visibility: visibility, animated: animated)
        for (index, isVisible) in visibility.enumerated() {
            mainPecentChartRenderer.setComponentVisible(isVisible, at: index, animated: animated)
            previewPercentChartRenderer.setComponentVisible(isVisible, at: index, animated: animated)
        }
        verticalScalesRenderer.setVisible(visibility.contains(true), animated: animated)
    }
    
    override func chartDetailsViewModel(closestDate: Date, pointIndex: Int) -> ChartDetailsViewModel {
        let visibleValues = visibleDetailsChartValues
        
        let total = visibleValues.map { $0.values[pointIndex] }.reduce(0, +)
        
        let values: [ChartDetailsViewModel.Value] = chartsCollection.chartValues.enumerated().map { arg in
            let (index, component) = arg
            return ChartDetailsViewModel.Value(prefix: total > 0 ? PercentConstants.percentValueFormatter.string(from: component.values[pointIndex] / total * 100) : "0%",
                                               title: component.name,
                                               value: BaseConstants.detailsNumberFormatter.string(from: component.values[pointIndex]),
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
                                              showArrow: total > 0 && self.isZoomable && !self.isZoomed,
                                              showPrefixes: true,
                                              isLoading: false,
                                              values: values,
                                              totalValue: nil,
                                              tapAction: { [weak self] in
                                                self?.hideDetailsView(animated: true)
                                                self?.zoomInOnDateClosure?(closestDate) },
                                              hideAction: { [weak self] in
                                                self?.hideDetailsView(animated: true)
                                            })
        return viewModel
    }
    
    var currentlyVisiblePercentageData: PecentChartRenderer.PercentageData {
        var currentPercentageData = percentageData
        currentPercentageData.components = chartVisibility.enumerated().compactMap { $0.element ? currentPercentageData.components[$0.offset] : nil }
        return currentPercentageData
    }
    
    override var currentMainRangeRenderer: BaseChartRenderer {
        return mainPecentChartRenderer
    }
    
    override var currentPreviewRangeRenderer: BaseChartRenderer {
        return previewPercentChartRenderer
    }
    
    override func showDetailsView(at chartPosition: CGFloat, detailsViewPosition: CGFloat, dataIndex: Int, date: Date, animated: Bool, feedback: Bool) {
        super.showDetailsView(at: chartPosition, detailsViewPosition: detailsViewPosition, dataIndex: dataIndex, date: date, animated: animated, feedback: feedback)
        verticalLineRenderer.values = [chartPosition]
        verticalLineRenderer.isEnabled = true
    }
    
    override func hideDetailsView(animated: Bool) {
        super.hideDetailsView(animated: animated)
        
        verticalLineRenderer.values = []
        verticalLineRenderer.isEnabled = false
    }
    
    override func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        super.apply(theme: theme, strings: strings, animated: animated)
        
        horizontalScalesRenderer.labelsColor = theme.chartLabelsColor
        verticalScalesRenderer.labelsColor = theme.chartLabelsColor
        verticalScalesRenderer.axisXColor = theme.barChartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = theme.barChartStrongLinesColor
        verticalLineRenderer.linesColor = theme.chartStrongLinesColor
    }
}
