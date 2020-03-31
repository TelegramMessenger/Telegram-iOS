//
//  StackedBarsChartController.swift
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

public class StackedBarsChartController: BaseChartController {
    let barsController: BarsComponentController
    let zoomedBarsController: BarsComponentController
    
    override public var isZoomable: Bool {
        didSet {
            barsController.isZoomable = self.isZoomable
        }
    }
    
    override public init(chartsCollection: ChartsCollection)  {
        let horizontalScalesRenderer = HorizontalScalesRenderer()
        let verticalScalesRenderer = VerticalScalesRenderer()
        barsController = BarsComponentController(isZoomed: false,
                                                 mainBarsRenderer: BarChartRenderer(),
                                                 horizontalScalesRenderer: horizontalScalesRenderer,
                                                 verticalScalesRenderer: verticalScalesRenderer,
                                                 previewBarsChartRenderer: BarChartRenderer())
        zoomedBarsController = BarsComponentController(isZoomed: true,
                                                       mainBarsRenderer: BarChartRenderer(),
                                                       horizontalScalesRenderer: horizontalScalesRenderer,
                                                       verticalScalesRenderer: verticalScalesRenderer,
                                                       previewBarsChartRenderer: BarChartRenderer())

        super.init(chartsCollection: chartsCollection)
        
        [barsController, zoomedBarsController].forEach { controller in
            controller.chartFrame = { [unowned self] in self.chartFrame() }
            controller.cartViewBounds = { [unowned self] in self.cartViewBounds() }
            controller.zoomInOnDateClosure = { [unowned self] date in
                self.didTapZoomIn(date: date, pointIndex: 0)
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
            controller.setDetailsViewModel = { [unowned self] (viewModel, animated, feedback) in
                self.setDetailsViewModel?(viewModel, animated, feedback)
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
            TimeInterval.setDefaultDuration(.expandAnimationDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + .expandAnimationDuration) {
                TimeInterval.setDefaultDuration(.osXDuration)
            }
        }

        super.isZoomed = isZoomed
        if isZoomed {
            let toHorizontalRange = zoomedBarsController.initialHorizontalRange
            let destinationHorizontalRange = (toHorizontalRange.lowerBound - barsController.barsWidth)...(toHorizontalRange.upperBound - barsController.barsWidth)
            let verticalVisibleRange = barsController.currentVerticalMainChartRange
            let initialVerticalRange = verticalVisibleRange.lowerBound...(verticalVisibleRange.upperBound + verticalVisibleRange.distance * 10)
 
            zoomedBarsController.mainBarsRenderer.setup(horizontalRange: barsController.currentHorizontalMainChartRange, animated: false)
            zoomedBarsController.previewBarsChartRenderer.setup(horizontalRange: barsController.currentPreviewHorizontalRange, animated: false)
            zoomedBarsController.mainBarsRenderer.setup(verticalRange: initialVerticalRange, animated: false)
            zoomedBarsController.previewBarsChartRenderer.setup(verticalRange: initialVerticalRange, animated: false)
            zoomedBarsController.mainBarsRenderer.setVisible(true, animated: false)
            zoomedBarsController.previewBarsChartRenderer.setVisible(true, animated: false)

            barsController.setupMainChart(horizontalRange: destinationHorizontalRange, animated: animated)
            barsController.previewBarsChartRenderer.setup(horizontalRange: zoomedBarsController.totalHorizontalRange, animated: animated)
            barsController.mainBarsRenderer.setVisible(false, animated: animated)
            barsController.previewBarsChartRenderer.setVisible(false, animated: animated)

            zoomedBarsController.willAppear(animated: animated)
            barsController.willDisappear(animated: animated)
            
            zoomedBarsController.updateChartsVisibility(visibility: barsController.chartVisibility, animated: false)
            zoomedBarsController.mainBarsRenderer.setup(verticalRange: zoomedBarsController.currentVerticalMainChartRange, animated: animated, timeFunction: .easeInOut)
            zoomedBarsController.previewBarsChartRenderer.setup(verticalRange: zoomedBarsController.currentPreviewVerticalRange, animated: animated, timeFunction: .easeInOut)
        } else {
            if !zoomedBarsController.chartsCollection.isBlank {
                barsController.hideDetailsView(animated: false)
                barsController.chartVisibility = zoomedBarsController.chartVisibility
                let visibleVerticalRange = BarChartRenderer.BarsData.verticalRange(bars: barsController.visibleBars,
                                                                                   calculatingRange: barsController.initialHorizontalRange) ?? BaseConstants.defaultRange
                barsController.mainBarsRenderer.setup(verticalRange: visibleVerticalRange, animated: false)
                
                let toHorizontalRange = barsController.initialHorizontalRange

                let verticalVisibleRange = barsController.initialVerticalRange
                let targetVerticalRange = verticalVisibleRange.lowerBound...(verticalVisibleRange.upperBound + verticalVisibleRange.distance * 10)

                zoomedBarsController.setupMainChart(horizontalRange: toHorizontalRange, animated: animated)
                zoomedBarsController.mainBarsRenderer.setup(verticalRange: targetVerticalRange, animated: animated, timeFunction: .easeInOut)
                zoomedBarsController.previewBarsChartRenderer.setup(verticalRange: targetVerticalRange, animated: animated, timeFunction: .easeInOut)
                zoomedBarsController.previewBarsChartRenderer.setup(horizontalRange: barsController.totalHorizontalRange, animated: animated)
                DispatchQueue.main.asyncAfter(deadline: .now() + .defaultDuration) { [weak self] in
                    self?.zoomedBarsController.mainBarsRenderer.setVisible(false, animated: false)
                    self?.zoomedBarsController.previewBarsChartRenderer.setVisible(false, animated: false)
                }
            }
            
            barsController.willAppear(animated: animated)
            zoomedBarsController.willDisappear(animated: animated)
            
            if !zoomedBarsController.chartsCollection.isBlank {
                barsController.updateChartsVisibility(visibility: zoomedBarsController.chartVisibility, animated: false)
            }
        }
        
        self.setBackButtonVisibilityClosure?(isZoomed, animated)
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

    public override func chartInteractionDidBegin(point: CGPoint, manual: Bool = true) {
        if isZoomed {
            zoomedBarsController.chartInteractionDidBegin(point: point, manual: manual)
        } else {
            barsController.chartInteractionDidBegin(point: point, manual: manual)
        }
    }
    
    public override func chartInteractionDidEnd() {
        if isZoomed {
            zoomedBarsController.chartInteractionDidEnd()
        } else {
            barsController.chartInteractionDidEnd()
        }
    }
    
    public override var drawChartVisibity: Bool {
        return true
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
    
    public override func didTapZoomIn(date: Date, pointIndex: Int) {
        guard !isZoomed, isZoomable else { return }
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
    
    public override func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        super.apply(theme: theme, strings: strings, animated: animated)
        
        zoomedBarsController.apply(theme: theme, strings: strings, animated: animated)
        barsController.apply(theme: theme, strings: strings, animated: animated)
    }
}
