//
//  DailyBarsChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class DailyBarsChartController: BaseChartController {
    let barsController: BarsComponentController
    let linesController: LinesComponentController
    
    override init(chartsCollection: ChartsCollection) {
        let horizontalScalesRenderer = HorizontalScalesRenderer()
        let verticalScalesRenderer = VerticalScalesRenderer()
        barsController = BarsComponentController(isZoomed: false,
                                                 mainBarsRenderer: BarChartRenderer(),
                                                 horizontalScalesRenderer: horizontalScalesRenderer,
                                                 verticalScalesRenderer: verticalScalesRenderer,
                                                 previewBarsChartRenderer: BarChartRenderer())
        linesController = LinesComponentController(isZoomed: true,
                                                   userLinesTransitionAnimation: false,
                                                   mainLinesRenderer: LinesChartRenderer(),
                                                   horizontalScalesRenderer: horizontalScalesRenderer,
                                                   verticalScalesRenderer: verticalScalesRenderer,
                                                   verticalLineRenderer: VerticalLinesRenderer(),
                                                   lineBulletsRenerer: LineBulletsRenerer(),
                                                   previewLinesChartRenderer: LinesChartRenderer())
        
        super.init(chartsCollection: chartsCollection)
        
        [barsController, linesController].forEach { controller in
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
    }
    
    override var mainChartRenderers: [ChartViewRenderer] {
        return [barsController.mainBarsRenderer,
                linesController.mainLinesRenderer,
                barsController.horizontalScalesRenderer,
                barsController.verticalScalesRenderer,
                linesController.verticalLineRenderer,
                linesController.lineBulletsRenerer,
//                performanceRenderer
        ]
    }
    
    override var navigationRenderers: [ChartViewRenderer] {
        return [barsController.previewBarsChartRenderer,
                linesController.previewLinesChartRenderer]
    }
    
    override func initializeChart() {
        barsController.initialize(chartsCollection: initialChartsCollection,
                                  initialDate: Date(),
                                  totalHorizontalRange: BaseConstants.defaultRange,
                                  totalVerticalRange: BaseConstants.defaultRange)
        switchToChart(chartsCollection: barsController.chartsCollection, isZoomed: false, animated: false)
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
            let toHorizontalRange = linesController.initialHorizontalRange
            let destinationHorizontalRange = (toHorizontalRange.lowerBound - barsController.barsWidth)...(toHorizontalRange.upperBound - barsController.barsWidth)
            let initialChartVerticalRange = lineProportionAnimationRange()
            
            linesController.mainLinesRenderer.setup(horizontalRange: barsController.currentHorizontalMainChartRange, animated: false)
            linesController.previewLinesChartRenderer.setup(horizontalRange: barsController.currentPreviewHorizontalRange, animated: false)
            linesController.mainLinesRenderer.setup(verticalRange: initialChartVerticalRange, animated: false)
            linesController.previewLinesChartRenderer.setup(verticalRange: initialChartVerticalRange, animated: false)
            linesController.mainLinesRenderer.setVisible(false, animated: false)
            linesController.previewLinesChartRenderer.setVisible(false, animated: false)
            
            barsController.setupMainChart(horizontalRange: destinationHorizontalRange, animated: animated)
            barsController.previewBarsChartRenderer.setup(horizontalRange: linesController.totalHorizontalRange, animated: animated)
            barsController.mainBarsRenderer.setVisible(false, animated: animated)
            barsController.previewBarsChartRenderer.setVisible(false, animated: animated)
            
            linesController.willAppear(animated: animated)
            barsController.willDisappear(animated: animated)
            
            linesController.updateChartsVisibility(visibility: linesController.chartLines.map { _ in true }, animated: false)
        } else {
            if !linesController.chartsCollection.isBlank {
                barsController.hideDetailsView(animated: false)
                let visibleVerticalRange = BarChartRenderer.BarsData.verticalRange(bars: barsController.visibleBars,
                                                                                   calculatingRange: barsController.initialHorizontalRange) ?? BaseConstants.defaultRange
                barsController.mainBarsRenderer.setup(verticalRange: visibleVerticalRange, animated: false)
                
                let toHorizontalRange = barsController.initialHorizontalRange
                let destinationChartVerticalRange = lineProportionAnimationRange()
                
                linesController.setupMainChart(horizontalRange: toHorizontalRange, animated: animated)
                linesController.mainLinesRenderer.setup(verticalRange: destinationChartVerticalRange, animated: animated)
                linesController.previewLinesChartRenderer.setup(verticalRange: destinationChartVerticalRange, animated: animated)
                linesController.previewLinesChartRenderer.setup(horizontalRange: barsController.totalHorizontalRange, animated: animated)
                linesController.mainLinesRenderer.setVisible(false, animated: animated)
                linesController.previewLinesChartRenderer.setVisible(false, animated: animated)
            }
            
            barsController.willAppear(animated: animated)
            linesController.willDisappear(animated: animated)
        }
        
        self.setBackButtonVisibilityClosure?(isZoomed, animated)
        self.refreshChartToolsClosure?(animated)
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        if isZoomed {
            linesController.updateChartsVisibility(visibility: visibility, animated: animated)
        } else {
            barsController.updateChartsVisibility(visibility: visibility, animated: animated)
        }
    }
    
    var visibleChartValues: [ChartsCollection.Chart] {
        let visibility = isZoomed ? linesController.chartVisibility : barsController.chartVisibility
        let collection = isZoomed ? linesController.chartsCollection : barsController.chartsCollection
        let visibleCharts: [ChartsCollection.Chart] = visibility.enumerated().compactMap { args in
            args.element ? collection.chartValues[args.offset] : nil
        }
        return visibleCharts
    }
    
    override var actualChartVisibility: [Bool] {
        return isZoomed ? linesController.chartVisibility : barsController.chartVisibility
    }
    
    override var actualChartsCollection: ChartsCollection {
        return isZoomed ? linesController.chartsCollection : barsController.chartsCollection
    }
    
    override func chartInteractionDidBegin(point: CGPoint) {
        if isZoomed {
            linesController.chartInteractionDidBegin(point: point)
        } else {
            barsController.chartInteractionDidBegin(point: point)
        }
    }
    
    override func chartInteractionDidEnd() {
        if isZoomed {
            linesController.chartInteractionDidEnd()
        } else {
            barsController.chartInteractionDidEnd()
        }
    }
    
    override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        if isZoomed {
            return linesController.currentChartHorizontalRangeFraction
        } else {
            return barsController.currentChartHorizontalRangeFraction
        }
    }
    
    override func cancelChartInteraction() {
        if isZoomed {
            return linesController.hideDetailsView(animated: true)
        } else {
            return barsController.hideDetailsView(animated: true)
        }
    }
    
    override func didTapZoomIn(date: Date) {
        guard isZoomed == false else { return }
        if isZoomed {
            return linesController.hideDetailsView(animated: true)
        }
        self.getDetailsData?(date, { updatedCollection in
            if let updatedCollection = updatedCollection {
                self.linesController.initialize(chartsCollection: updatedCollection,
                                                initialDate: date,
                                                totalHorizontalRange: 0...1,
                                                totalVerticalRange: 0...1)
                self.switchToChart(chartsCollection: updatedCollection, isZoomed: true, animated: true)
            }
        })
    }
    
    func lineProportionAnimationRange() -> ClosedRange<CGFloat> {
        let visibleLines = self.barsController.chartVisibility.enumerated().compactMap { $0.element ? self.linesController.chartLines[$0.offset] : nil }
        let linesRange = LinesChartRenderer.LineData.verticalRange(lines: visibleLines) ?? BaseConstants.defaultRange
        let barsRange = BarChartRenderer.BarsData.verticalRange(bars: self.barsController.visibleBars,
                                                                calculatingRange: self.linesController.totalHorizontalRange) ?? BaseConstants.defaultRange
        let range = 0...(linesRange.upperBound / barsRange.distance * self.barsController.currentVerticalMainChartRange.distance)
        return range
    }
    
    override func didTapZoomOut() {
        cancelChartInteraction()
        switchToChart(chartsCollection: barsController.chartsCollection, isZoomed: false, animated: true)
    }
    
    override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        if isZoomed {
            return linesController.chartRangeFractionDidUpdated(rangeFraction)
        } else {
            return barsController.chartRangeFractionDidUpdated(rangeFraction)
        }
    }
    
    override func apply(colorMode: ColorMode, animated: Bool) {
        super.apply(colorMode: colorMode, animated: animated)
        
        linesController.apply(colorMode: colorMode, animated: animated)
        barsController.apply(colorMode: colorMode, animated: animated)
    }

    override var drawChartVisibity: Bool {
        return isZoomed
    }
}

//TODO: Убрать Performance полоски сверзу чартов (Не забыть)
//TODO: Добавить ховеры на кнопки
