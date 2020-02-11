//
//  PercentPieChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

enum PercentConstants {
    static let percentValueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.positiveSuffix = "%"
        return formatter
    }()
}

private enum Constants {
    static let zoomedRange = 7
}

class PercentPieChartController: BaseChartController {
    let percentController: PercentChartComponentController
    let pieController: PieChartComponentController
    let transitionRenderer: PercentPieAnimationRenderer
    
    override init(chartsCollection: ChartsCollection) {
        transitionRenderer = PercentPieAnimationRenderer()
        percentController = PercentChartComponentController(isZoomed: false,
                                                            mainPecentChartRenderer: PecentChartRenderer(),
                                                            horizontalScalesRenderer: HorizontalScalesRenderer(),
                                                            verticalScalesRenderer: VerticalScalesRenderer(),
                                                            verticalLineRenderer: VerticalLinesRenderer(),
                                                            previewPercentChartRenderer: PecentChartRenderer())
        pieController = PieChartComponentController(isZoomed: true,
                                                    pieChartRenderer: PieChartRenderer(),
                                                    previewBarChartRenderer: BarChartRenderer())
        
        super.init(chartsCollection: chartsCollection)
        
        [percentController, pieController].forEach { controller in
            controller.chartFrame = { [unowned self] in self.chartFrame() }
            controller.cartViewBounds = { [unowned self] in self.cartViewBounds() }
            controller.zoomInOnDateClosure = { [unowned self] date in
                self.didTapZoomIn(date: date)
            }
            controller.setChartTitleClosure = { [unowned self] (title, animated) in
                self.setChartTitleClosure?(title, animated)
            }
            controller.setDetailsViewPositionClosure = { [unowned self] (position) in
                self.setDetailsViewPositionClosure?(position)
            }
            controller.setDetailsChartVisibleClosure = { [unowned self] (visible, animated) in
                self.setDetailsChartVisibleClosure?(visible, animated)
            }
            controller.setDetailsViewModel = { [unowned self] (viewModel, animated) in
                self.setDetailsViewModel?(viewModel, animated)
            }
            controller.updatePreviewRangeClosure = { [unowned self] (fraction, animated) in
                self.chartRangeUpdatedClosure?(fraction, animated)
            }
            controller.chartRangePagingClosure = { [unowned self] (isEnabled, pageSize) in
                self.setChartRangePagingEnabled(isEnabled: isEnabled, minimumSelectionSize: pageSize)
            }
        }
        transitionRenderer.isEnabled = false
    }
    
    override var mainChartRenderers: [ChartViewRenderer] {
        return [percentController.mainPecentChartRenderer,
                transitionRenderer,
                percentController.horizontalScalesRenderer,
                percentController.verticalScalesRenderer,
                percentController.verticalLineRenderer,
                pieController.pieChartRenderer,
//                performanceRenderer
        ]
    }
    
    override var navigationRenderers: [ChartViewRenderer] {
        return [percentController.previewPercentChartRenderer,
                pieController.previewBarChartRenderer]
    }

    override func initializeChart() {
        percentController.initialize(chartsCollection: initialChartsCollection,
                                     initialDate: Date(),
                                     totalHorizontalRange: BaseConstants.defaultRange,
                                     totalVerticalRange: BaseConstants.defaultRange)
        switchToChart(chartsCollection: percentController.chartsCollection, isZoomed: false, animated: false)
    }
    
    func switchToChart(chartsCollection: ChartsCollection, isZoomed: Bool, animated: Bool) {
        if animated {
            TimeInterval.setDefaultSuration(.expandAnimationDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + .expandAnimationDuration) {
                TimeInterval.setDefaultSuration(.osXDuration)
            }
        }

        super.isZoomed = isZoomed
        if isZoomed {
            let toHorizontalRange = pieController.initialHorizontalRange

            pieController.updateChartsVisibility(visibility: percentController.chartVisibility, animated: false)
            pieController.pieChartRenderer.setup(horizontalRange: percentController.currentHorizontalMainChartRange, animated: false)
            pieController.previewBarChartRenderer.setup(horizontalRange: percentController.currentPreviewHorizontalRange, animated: false)
            pieController.pieChartRenderer.setVisible(false, animated: false)
            pieController.previewBarChartRenderer.setVisible(true, animated: false)

            pieController.willAppear(animated: animated)
            percentController.willDisappear(animated: animated)

            pieController.pieChartRenderer.drawPie = false
            percentController.mainPecentChartRenderer.isEnabled = false
            
            setupTransitionRenderer()
            
            percentController.setupMainChart(horizontalRange: toHorizontalRange, animated: animated)
            percentController.previewPercentChartRenderer.setup(horizontalRange: toHorizontalRange, animated: animated)
            percentController.setConponentsVisible(visible: false, animated: animated)
            
            transitionRenderer.animate(fromDataToPie: true, animated: animated) { [weak self] in
                self?.pieController.pieChartRenderer.drawPie = true
                self?.percentController.mainPecentChartRenderer.isEnabled = true
            }
        } else {
            if !pieController.chartsCollection.isBlank {
                let fromHorizontalRange = pieController.currentHorizontalMainChartRange
                let toHorizontalRange = percentController.initialHorizontalRange

                pieController.pieChartRenderer.setup(horizontalRange: toHorizontalRange, animated: animated)
                pieController.previewBarChartRenderer.setup(horizontalRange: toHorizontalRange, animated: animated)
                pieController.pieChartRenderer.setVisible(false, animated: animated)
                pieController.previewBarChartRenderer.setVisible(false, animated: animated)
                
                percentController.updateChartsVisibility(visibility: pieController.chartVisibility, animated: false)
                percentController.setupMainChart(horizontalRange: fromHorizontalRange, animated: false)
                percentController.previewPercentChartRenderer.setup(horizontalRange: fromHorizontalRange, animated: false)
                percentController.setConponentsVisible(visible: false, animated: false)
            }
            
            percentController.willAppear(animated: animated)
            pieController.willDisappear(animated: animated)
            
            if animated {
                pieController.pieChartRenderer.drawPie = false
                percentController.mainPecentChartRenderer.isEnabled = false
                
                setupTransitionRenderer()

                transitionRenderer.animate(fromDataToPie: false, animated: true) {
                    self.pieController.pieChartRenderer.drawPie = true
                    self.percentController.mainPecentChartRenderer.isEnabled = true
                }
            }
        }
        
        self.setBackButtonVisibilityClosure?(isZoomed, animated)
    }
    
    func setupTransitionRenderer() {
        transitionRenderer.setup(verticalRange: percentController.currentVerticalMainChartRange, animated: false)
        transitionRenderer.setup(horizontalRange: percentController.currentHorizontalMainChartRange, animated: false)
        transitionRenderer.visiblePieComponents = pieController.visiblePieDataWithCurrentPreviewRange
        transitionRenderer.visiblePercentageData = percentController.currentlyVisiblePercentageData
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        if isZoomed {
            pieController.updateChartsVisibility(visibility: visibility, animated: animated)
        } else {
            percentController.updateChartsVisibility(visibility: visibility, animated: animated)
        }
    }
    
    var visibleChartValues: [ChartsCollection.Chart] {
        let visibility = isZoomed ? pieController.chartVisibility : percentController.chartVisibility
        let collection = isZoomed ? pieController.chartsCollection : percentController.chartsCollection
        let visibleCharts: [ChartsCollection.Chart] = visibility.enumerated().compactMap { args in
            args.element ? collection.chartValues[args.offset] : nil
        }
        return visibleCharts
    }

    override var actualChartVisibility: [Bool] {
        return isZoomed ? pieController.chartVisibility : percentController.chartVisibility
    }
    
    override var actualChartsCollection: ChartsCollection {
        return isZoomed ? pieController.chartsCollection : percentController.chartsCollection
    }
    
    override func chartInteractionDidBegin(point: CGPoint) {
        if isZoomed {
            pieController.chartInteractionDidBegin(point: point)
        } else {
            percentController.chartInteractionDidBegin(point: point)
        }
    }
    
    override func chartInteractionDidEnd() {
        if isZoomed {
            pieController.chartInteractionDidEnd()
        } else {
            percentController.chartInteractionDidEnd()
        }
    }
    
    override var drawChartVisibity: Bool {
        return true
    }
    
    override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        if isZoomed {
            return pieController.currentChartHorizontalRangeFraction
        } else {
            return percentController.currentChartHorizontalRangeFraction
        }
    }
    
    override func cancelChartInteraction() {
        if isZoomed {
            return pieController.hideDetailsView(animated: true)
        } else {
            return percentController.hideDetailsView(animated: true)
        }
    }
    
    override func didTapZoomIn(date: Date) {
        guard isZoomed == false else { return }
        cancelChartInteraction()
        let currentCollection = percentController.chartsCollection
        let range: Int = Constants.zoomedRange
        guard let (foundDate, index) = percentController.findClosestDateTo(dateToFind: date) else { return }
        var lowIndex = max(0, index - range / 2)
        var highIndex = min(currentCollection.axisValues.count - 1, index + range / 2)
        if lowIndex == 0 {
            highIndex = lowIndex + (range - 1)
        } else if highIndex == currentCollection.axisValues.count - 1 {
            lowIndex = highIndex - (range - 1)
        }
        
        let newValues = currentCollection.chartValues.map { chart in
            return ChartsCollection.Chart(color: chart.color,
                                          name: chart.name,
                                          values: Array(chart.values[(lowIndex...highIndex)]))
        }
        let newCollection = ChartsCollection(axisValues: Array(currentCollection.axisValues[(lowIndex...highIndex)]),
                                             chartValues: newValues)
        let selectedRange = CGFloat(foundDate.timeIntervalSince1970 - .day)...CGFloat(foundDate.timeIntervalSince1970)
        pieController.initialize(chartsCollection: newCollection, initialDate: date, totalHorizontalRange: 0...1, totalVerticalRange: 0...1)
        pieController.initialHorizontalRange = selectedRange

        switchToChart(chartsCollection: newCollection, isZoomed: true, animated: true)
    }
    
    override func didTapZoomOut() {
        self.pieController.deselectSegment(completion: { [weak self] in
            guard let self = self else { return }
            self.switchToChart(chartsCollection: self.percentController.chartsCollection, isZoomed: false, animated: true)
        })
    }
    
    override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        if isZoomed {
            return pieController.chartRangeFractionDidUpdated(rangeFraction)
        } else {
            return percentController.chartRangeFractionDidUpdated(rangeFraction)
        }
    }
    
    override func apply(colorMode: ColorMode, animated: Bool) {
        super.apply(colorMode: colorMode, animated: animated)
        
        pieController.apply(colorMode: colorMode, animated: animated)
        percentController.apply(colorMode: colorMode, animated: animated)
        transitionRenderer.backgroundColor = colorMode.chartBackgroundColor
    }
}
