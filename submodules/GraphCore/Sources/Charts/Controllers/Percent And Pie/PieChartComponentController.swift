//
//  PieChartComponentController.swift
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

class PieChartComponentController: GeneralChartComponentController {
    let pieChartRenderer: PieChartRenderer
    let previewBarChartRenderer: BarChartRenderer
    var barWidth: CGFloat = 1
    
    var chartBars: BarChartRenderer.BarsData = .blank
    
    init(isZoomed: Bool,
         pieChartRenderer: PieChartRenderer,
         previewBarChartRenderer: BarChartRenderer) {
        self.pieChartRenderer = pieChartRenderer
        self.previewBarChartRenderer = previewBarChartRenderer
        super.init(isZoomed: isZoomed)
    }
    
    override func initialize(chartsCollection: ChartsCollection, initialDate: Date, totalHorizontalRange _: ClosedRange<CGFloat>, totalVerticalRange _: ClosedRange<CGFloat>) {
        let (width, chartBars, totalHorizontalRange, _) = BarChartRenderer.BarsData.initialComponents(chartsCollection: chartsCollection)
        self.barWidth = width
        self.chartBars = chartBars
        super.initialize(chartsCollection: chartsCollection,
                         initialDate: initialDate,
                         totalHorizontalRange: totalHorizontalRange,
                         totalVerticalRange: BaseConstants.defaultRange)
        
        self.previewBarChartRenderer.bars = chartBars
        self.previewBarChartRenderer.fillToTop = true
        
        pieChartRenderer.valuesFormatter = PercentConstants.percentValueFormatter
        pieChartRenderer.setup(horizontalRange: initialHorizontalRange, animated: false)
        previewBarChartRenderer.setup(verticalRange: initialVerticalRange, animated: false)
        previewBarChartRenderer.setup(horizontalRange: initialHorizontalRange, animated: false)
        
        pieChartRenderer.updatePercentageData(pieDataWithCurrentPreviewRange, animated: false)
        pieChartRenderer.selectSegmentAt(at: nil, animated: false)
    }
    
    private var pieDataWithCurrentPreviewRange: [PieChartRenderer.PieComponent] {
        let range = currentHorizontalMainChartRange
        var pieComponents = chartsCollection.chartValues.map { PieChartRenderer.PieComponent(color: $0.color,
                                                                                             value: 0) }
        guard var valueIndex = chartsCollection.axisValues.firstIndex(where: { CGFloat($0.timeIntervalSince1970) > (range.lowerBound + 1)}) else {
            return pieComponents
        }
        var count = 0
        while valueIndex < chartsCollection.axisValues.count, CGFloat(chartsCollection.axisValues[valueIndex].timeIntervalSince1970) <= range.upperBound {
            count += 1
            for pieIndex in pieComponents.indices {
                pieComponents[pieIndex].value += CGFloat(chartsCollection.chartValues[pieIndex].values[valueIndex])
            }
            valueIndex += 1
        }
        return pieComponents
    }
    
    var visiblePieDataWithCurrentPreviewRange: [PieChartRenderer.PieComponent] {
        let currentData = pieDataWithCurrentPreviewRange
        return chartVisibility.enumerated().compactMap { $0.element ? currentData[$0.offset] : nil }
    }
    
    override func willAppear(animated: Bool) {
        pieChartRenderer.setup(horizontalRange: initialHorizontalRange, animated: animated)
        pieChartRenderer.setVisible(true, animated: animated)
        
        previewBarChartRenderer.setup(verticalRange: totalVerticalRange, animated: animated)
        previewBarChartRenderer.setup(horizontalRange: totalHorizontalRange, animated: animated)
        previewBarChartRenderer.setVisible(true, animated: animated)
        
        updatePreviewRangeClosure?(currentChartHorizontalRangeFraction, animated)
        pieChartRenderer.updatePercentageData(pieDataWithCurrentPreviewRange, animated: false)
        
        super.willAppear(animated: animated)
    }
    
    override func setupChartRangePaging() {
        let valuesCount = chartsCollection.axisValues.count
        guard valuesCount > 0 else { return }
        chartRangePagingClosure?(true, 1.0 / CGFloat(valuesCount))
    }
    
    override func chartRangeDidUpdated(_ updatedRange: ClosedRange<CGFloat>) {
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
        initialHorizontalRange = updatedRange
        
        setupMainChart(horizontalRange: updatedRange, animated: true)
        updateSelectedDataLabelIfNeeded()
    }
    
    func setupMainChart(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        pieChartRenderer.setup(horizontalRange: horizontalRange, animated: animated)
        pieChartRenderer.updatePercentageData(pieDataWithCurrentPreviewRange, animated: animated)
    }
    
    public override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        super.updateChartsVisibility(visibility: visibility, animated: animated)
        for (index, isVisible) in visibility.enumerated() {
            pieChartRenderer.setComponentVisible(isVisible, at: index, animated: animated)
            previewBarChartRenderer.setComponentVisible(isVisible, at: index, animated: animated)
        }
        if let segment = pieChartRenderer.selectedSegment {
            if !visibility[segment] {
                pieChartRenderer.selectSegmentAt(at: nil, animated: true)
            }
        }
        updateSelectedDataLabelIfNeeded()
    }
    
    func deselectSegment(completion: @escaping () -> Void) {
        if pieChartRenderer.hasSelectedSegments {
            hideDetailsView(animated: true)
            pieChartRenderer.selectSegmentAt(at: nil, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + .defaultDuration / 2) {
                completion()
            }
        } else {
            completion()
        }
    }
    
    func updateSelectedDataLabelIfNeeded() {
        if let segment = pieChartRenderer.selectedSegment {
            self.setDetailsChartVisibleClosure?(true, true)
            self.setDetailsViewModel?(chartDetailsViewModel(segmentInde: segment), false, false)
            self.setDetailsViewPositionClosure?(chartFrame().width / 4)
        } else {
            self.setDetailsChartVisibleClosure?(false, true)
        }
    }
    
    func chartDetailsViewModel(segmentInde: Int) -> ChartDetailsViewModel {
        let pieItem = pieDataWithCurrentPreviewRange[segmentInde]
        let title = chartsCollection.chartValues[segmentInde].name
        let valueString = BaseConstants.detailsNumberFormatter.string(from: pieItem.value)
        let viewModel = ChartDetailsViewModel(title: "",
                                              showArrow: false,
                                              showPrefixes: false,
                                              isLoading: false,
                                              values: [ChartDetailsViewModel.Value(prefix: nil,
                                                                                   title: title,
                                                                                   value: valueString,
                                                                                   color: pieItem.color,
                                                                                   visible: true)],
                                              totalValue: nil,
                                              tapAction: nil,
                                              hideAction: { [weak self] in
                                                self?.deselectSegment(completion: {})
        })
        return viewModel
    }
    
    override var currentMainRangeRenderer: BaseChartRenderer {
        return pieChartRenderer
    }
    
    override var currentPreviewRangeRenderer: BaseChartRenderer {
        return previewBarChartRenderer
    }

    public override func chartInteractionDidBegin(point: CGPoint, manual: Bool = true) {
        if let segment = pieChartRenderer.selectedItemIndex(at: point) {
            pieChartRenderer.selectSegmentAt(at: segment, animated: true)
            updateSelectedDataLabelIfNeeded()
        }
    }
    
    override func hideDetailsView(animated: Bool) {
        pieChartRenderer.selectSegmentAt(at: nil, animated: animated)
        updateSelectedDataLabelIfNeeded()
    }
    
    override func updateChartRangeTitle(animated: Bool) {
        let fromDate = Date(timeIntervalSince1970: TimeInterval(currentHorizontalMainChartRange.lowerBound) + .day + 1)
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
