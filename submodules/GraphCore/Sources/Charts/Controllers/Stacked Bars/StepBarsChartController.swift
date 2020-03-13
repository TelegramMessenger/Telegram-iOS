//
//  DailyBarsChartController.swift
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

public class StepBarsChartController: BaseChartController {
    let barsController: BarsComponentController
    let zoomedBarsController: BarsComponentController
    
    override public init(chartsCollection: ChartsCollection)  {
        let horizontalScalesRenderer = HorizontalScalesRenderer()
        let verticalScalesRenderer = VerticalScalesRenderer()
        barsController = BarsComponentController(isZoomed: false,
                                                 mainBarsRenderer: BarChartRenderer(step: true),
                                                 horizontalScalesRenderer: horizontalScalesRenderer,
                                                 verticalScalesRenderer: verticalScalesRenderer,
                                                 previewBarsChartRenderer: BarChartRenderer())
        zoomedBarsController = BarsComponentController(isZoomed: true,
                                                       mainBarsRenderer: BarChartRenderer(step: true),
                                                       horizontalScalesRenderer: horizontalScalesRenderer,
                                                       verticalScalesRenderer: verticalScalesRenderer,
                                                       previewBarsChartRenderer: BarChartRenderer())
        
        super.init(chartsCollection: chartsCollection)
        
        [barsController, zoomedBarsController].forEach { controller in
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
    
    public override var mainChartRenderers: [ChartViewRenderer] {
        return [barsController.mainBarsRenderer,
                zoomedBarsController.mainBarsRenderer,
                barsController.horizontalScalesRenderer,
                barsController.verticalScalesRenderer,
                barsController.secondVerticalScalesRenderer!
//                performanceRenderer
        ]
    }
    
    public override var navigationRenderers: [ChartViewRenderer] {
        return [barsController.previewBarsChartRenderer,
                zoomedBarsController.previewBarsChartRenderer]
    }
    
    public override func initializeChart() {
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
            let toHorizontalRange = zoomedBarsController.initialHorizontalRange
            let destinationHorizontalRange = (toHorizontalRange.lowerBound - barsController.barsWidth)...(toHorizontalRange.upperBound - barsController.barsWidth)
//            let initialChartVerticalRange = lineProportionAnimationRange()
            
//            let visibleVerticalRange = BarChartRenderer.BarsData.verticalRange(bars: zoomedBarsController.visibleBars,
//                                                                               calculatingRange: zoomedBarsController.initialHorizontalRange) ?? BaseConstants.defaultRange
            zoomedBarsController.mainBarsRenderer.setup(verticalRange: 0...117278, animated: false)
            
            zoomedBarsController.setupMainChart(horizontalRange: barsController.currentHorizontalMainChartRange, animated: false)
            zoomedBarsController.previewBarsChartRenderer.setup(horizontalRange: barsController.currentPreviewHorizontalRange, animated: false)
//            zoomedBarsController.mainLinesRenderer.setup(verticalRange: initialChartVerticalRange, animated: false)
//            zoomedBarsController.previewLinesChartRenderer.setup(verticalRange: initialChartVerticalRange, animated: false)
            zoomedBarsController.mainBarsRenderer.setVisible(false, animated: false)
            zoomedBarsController.previewBarsChartRenderer.setVisible(false, animated: false)
            
            barsController.setupMainChart(horizontalRange: destinationHorizontalRange, animated: animated)
            barsController.previewBarsChartRenderer.setup(horizontalRange: zoomedBarsController.totalHorizontalRange, animated: animated)
            barsController.mainBarsRenderer.setVisible(false, animated: animated)
            barsController.previewBarsChartRenderer.setVisible(false, animated: animated)
            
            zoomedBarsController.willAppear(animated: animated)
            barsController.willDisappear(animated: animated)
            
            zoomedBarsController.updateChartsVisibility(visibility: zoomedBarsController.chartBars.components.map { _ in true }, animated: false)
        } else {
            if !zoomedBarsController.chartsCollection.isBlank {
                barsController.hideDetailsView(animated: false)
                let visibleVerticalRange = BarChartRenderer.BarsData.verticalRange(bars: barsController.visibleBars,
                                                                                   calculatingRange: barsController.initialHorizontalRange) ?? BaseConstants.defaultRange
                barsController.mainBarsRenderer.setup(verticalRange: visibleVerticalRange, animated: false)
                
                let toHorizontalRange = barsController.initialHorizontalRange
//                let destinationChartVerticalRange = lineProportionAnimationRange()
                
                zoomedBarsController.setupMainChart(horizontalRange: toHorizontalRange, animated: animated)
//                zoomedBarsController.mainLinesRenderer.setup(verticalRange: destinationChartVerticalRange, animated: animated)
//                zoomedBarsController.previewLinesChartRenderer.setup(verticalRange: destinationChartVerticalRange, animated: animated)
                zoomedBarsController.previewBarsChartRenderer.setup(horizontalRange: barsController.totalHorizontalRange, animated: animated)
                zoomedBarsController.mainBarsRenderer.setVisible(false, animated: animated)
                zoomedBarsController.previewBarsChartRenderer.setVisible(false, animated: animated)
            }
            
            barsController.willAppear(animated: animated)
            zoomedBarsController.willDisappear(animated: animated)
        }
        
        self.setBackButtonVisibilityClosure?(isZoomed, animated)
        self.refreshChartToolsClosure?(animated)
    }
    
    public override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        if isZoomed {
            zoomedBarsController.updateChartsVisibility(visibility: visibility, animated: animated)
        } else {
            barsController.updateChartsVisibility(visibility: visibility, animated: animated)
        }
    }
    
    var visibleChartValues: [ChartsCollection.Chart] {
        let visibility = isZoomed ? zoomedBarsController.chartVisibility : barsController.chartVisibility
        let collection = isZoomed ? zoomedBarsController.chartsCollection : barsController.chartsCollection
        let visibleCharts: [ChartsCollection.Chart] = visibility.enumerated().compactMap { args in
            args.element ? collection.chartValues[args.offset] : nil
        }
        return visibleCharts
    }
    
    public override var actualChartVisibility: [Bool] {
        return isZoomed ? zoomedBarsController.chartVisibility : barsController.chartVisibility
    }
    
    public override var actualChartsCollection: ChartsCollection {
        let collection = isZoomed ? zoomedBarsController.chartsCollection : barsController.chartsCollection
        
        if collection.isBlank {
            return self.initialChartsCollection
        }
        return collection
    }
    
    public override func chartInteractionDidBegin(point: CGPoint) {
        if isZoomed {
            zoomedBarsController.chartInteractionDidBegin(point: point)
        } else {
            barsController.chartInteractionDidBegin(point: point)
        }
    }
    
    public override func chartInteractionDidEnd() {
        if isZoomed {
            zoomedBarsController.chartInteractionDidEnd()
        } else {
            barsController.chartInteractionDidEnd()
        }
    }
    
    public override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        if isZoomed {
            return zoomedBarsController.currentChartHorizontalRangeFraction
        } else {
            return barsController.currentChartHorizontalRangeFraction
        }
    }
    
    public override func cancelChartInteraction() {
        if isZoomed {
            return zoomedBarsController.hideDetailsView(animated: true)
        } else {
            return barsController.hideDetailsView(animated: true)
        }
    }
    
    public override func didTapZoomIn(date: Date) {
        guard isZoomed == false else { return }
        if isZoomed {
            return zoomedBarsController.hideDetailsView(animated: true)
        }
        self.getDetailsData?(date, { updatedCollection in
            if let updatedCollection = updatedCollection {
                self.zoomedBarsController.initialize(chartsCollection: updatedCollection,
                                                initialDate: date,
                                                totalHorizontalRange: 0...1,
                                                totalVerticalRange: 0...1)
                self.switchToChart(chartsCollection: updatedCollection, isZoomed: true, animated: true)
            }
        })
    }
    
//    func lineProportionAnimationRange() -> ClosedRange<CGFloat> {
//        let visibleLines = self.barsController.chartVisibility.enumerated().compactMap { $0.element ? self.zoomedBarsController.chartLines[$0.offset] : nil }
//        let linesRange = LinesChartRenderer.LineData.verticalRange(lines: visibleLines) ?? BaseConstants.defaultRange
//        let barsRange = BarChartRenderer.BarsData.verticalRange(bars: self.barsController.visibleBars,
//                                                                calculatingRange: self.zoomedBarsController.totalHorizontalRange) ?? BaseConstants.defaultRange
//        let range = 0...(linesRange.upperBound / barsRange.distance * self.barsController.currentVerticalMainChartRange.distance)
//        return range
//    }
    
   public override func didTapZoomOut() {
        cancelChartInteraction()
        switchToChart(chartsCollection: barsController.chartsCollection, isZoomed: false, animated: true)
    }
    
    public override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>, animated: Bool = true) {
        if isZoomed {
            return zoomedBarsController.chartRangeFractionDidUpdated(rangeFraction)
        } else {
            return barsController.chartRangeFractionDidUpdated(rangeFraction)
        }
    }
    
    override public func apply(theme: ChartTheme, animated: Bool) {
        super.apply(theme: theme, animated: animated)
        
        zoomedBarsController.apply(theme: theme, animated: animated)
        barsController.apply(theme: theme, animated: animated)
    }

    public override var drawChartVisibity: Bool {
        return true
    }
}

//TODO: Убрать Performance полоски сверзу чартов (Не забыть)
//TODO: Добавить ховеры на кнопки
