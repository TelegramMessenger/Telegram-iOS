//
//  BaseChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

enum BaseConstants {
    static let defaultRange: ClosedRange<CGFloat> = 0...1
    static let minimumAxisYLabelsDistance: CGFloat = 90
    static let monthDayDateFormatter = DateFormatter.utc(format: "MMM d")
    static let timeDateFormatter = DateFormatter.utc(format: "HH:mm")
    static let headerFullRangeFormatter: DateFormatter = {
        let formatter = DateFormatter.utc()
        formatter.calendar = Calendar.utc
        formatter.dateStyle = .long
        return formatter
    }()
    static let headerMediumRangeFormatter: DateFormatter = {
        let formatter = DateFormatter.utc()
        formatter.dateStyle = .medium
        return formatter
    }()
    static let headerFullZoomedFormatter: DateFormatter = {
        let formatter = DateFormatter.utc()
        formatter.dateStyle = .full
        return formatter
    }()

    static let verticalBaseAnchors: [CGFloat] = [8, 5, 2.5, 2, 1]
    static let defaultVerticalBaseAnchor: CGFloat = 1

    static let mainChartLineWidth: CGFloat = 2
    static let previewChartLineWidth: CGFloat = 1

    static let previewLinesChartOptimizationLevel: CGFloat = 1.5
    static let linesChartOptimizationLevel: CGFloat = 1.0
    static let barsChartOptimizationLevel: CGFloat = 0.75

    static let defaultRangePresetLength = TimeInterval.day * 60
    
    static let chartNumberFormatter: ScalesNumberFormatter = {
        let numberFormatter = ScalesNumberFormatter()
        numberFormatter.allowsFloats = true
        numberFormatter.numberStyle = .decimal
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.groupingSeparator = " "
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        return numberFormatter
    }()
    
    static let detailsNumberFormatter: NumberFormatter = {
        let detailsNumberFormatter = NumberFormatter()
        detailsNumberFormatter.allowsFloats = false
        detailsNumberFormatter.numberStyle = .decimal
        detailsNumberFormatter.usesGroupingSeparator = true
        detailsNumberFormatter.groupingSeparator = " "
        return detailsNumberFormatter
    }()
}

class BaseChartController: ColorModeContainer {
    //let performanceRenderer = PerformanceRenderer()
    var initialChartsCollection: ChartsCollection
    var isZoomed: Bool = false

    var chartTitle: String = ""
    
    init(chartsCollection: ChartsCollection) {
        self.initialChartsCollection = chartsCollection
    }
        
    var mainChartRenderers: [ChartViewRenderer] {
        fatalError("Abstract")
    }
    
    var navigationRenderers: [ChartViewRenderer] {
        fatalError("Abstract")
    }
    
    var cartViewBounds: (() -> CGRect) = { fatalError() }
    var chartFrame: (() -> CGRect) = { fatalError() }
    
    func initializeChart() {
        fatalError("Abstract")
    }
    
    func chartInteractionDidBegin(point: CGPoint) {
        fatalError("Abstract")
    }
    
    func chartInteractionDidEnd() {
        fatalError("Abstract")
    }
    
    func cancelChartInteraction() {
        fatalError("Abstract")
    }
    
    func didTapZoomOut() {
        fatalError("Abstract")
    }
    
    func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        fatalError("Abstract")
    }
    
    var currentHorizontalRange: ClosedRange<CGFloat> {
        fatalError("Abstract")
    }
    
    var isChartRangePagingEnabled: Bool = false
    var minimumSelectedChartRange: CGFloat = 0.05
    var chartRangePagingClosure: ((Bool, CGFloat) -> Void)? // isEnabled, PageSize
    func setChartRangePagingEnabled(isEnabled: Bool, minimumSelectionSize: CGFloat) {
        isChartRangePagingEnabled = isEnabled
        minimumSelectedChartRange = minimumSelectionSize
        chartRangePagingClosure?(isChartRangePagingEnabled, minimumSelectedChartRange)
    }
    
    var chartRangeUpdatedClosure: ((ClosedRange<CGFloat>, Bool) -> Void)?
    var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        fatalError("Abstract")
    }
    
    func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        fatalError("Abstract")
    }
    
    var actualChartVisibility: [Bool] {
        fatalError("Abstract")
    }
    
    var actualChartsCollection: ChartsCollection {
        fatalError("Abstract")
    }
    
    var drawChartVisibity: Bool {
        return true
    }

    var drawChartNavigation: Bool {
        return true
    }
    
    var setDetailsViewPositionClosure: ((CGFloat) -> Void)?
    var setDetailsChartVisibleClosure: ((Bool, Bool) -> Void)?
    var setDetailsViewModel: ((ChartDetailsViewModel, Bool) -> Void)?
    var getDetailsData: ((Date, @escaping (ChartsCollection?) -> Void) -> Void)?
    var setChartTitleClosure: ((String, Bool) -> Void)?
    var setBackButtonVisibilityClosure: ((Bool, Bool) -> Void)?
    var refreshChartToolsClosure: ((Bool) -> Void)?

    func didTapZoomIn(date: Date) {
        fatalError("Abstract")
    }
    
    func apply(colorMode: ColorMode, animated: Bool) {
        
    }
}
