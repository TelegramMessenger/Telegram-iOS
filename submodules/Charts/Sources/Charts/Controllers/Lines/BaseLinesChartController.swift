//
//  BaseLinesChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/14/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class BaseLinesChartController: BaseChartController {
    var chartVisibility: [Bool]
    var zoomChartVisibility: [Bool]
    var lastChartInteractionPoint: CGPoint = .zero
    var isChartInteractionBegun: Bool = false
    
    var initialChartRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    var zoomedChartRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    
    override init(chartsCollection: ChartsCollection) {
        self.chartVisibility = Array(repeating: true, count: chartsCollection.chartValues.count)
        self.zoomChartVisibility = []
        super.init(chartsCollection: chartsCollection)
    }
    
    func setupChartCollection(chartsCollection: ChartsCollection, animated: Bool, isZoomed: Bool) {
        if animated {
            TimeInterval.setDefaultSuration(.expandAnimationDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + .expandAnimationDuration) {
                TimeInterval.setDefaultSuration(.osXDuration)
            }
        }
        
        self.initialChartsCollection = chartsCollection
        self.isZoomed = isZoomed
        
        self.setBackButtonVisibilityClosure?(isZoomed, animated)
        
        updateChartRangeTitle(animated: animated)
    }
    
    func updateChartRangeTitle(animated: Bool) {
        let fromDate = Date(timeIntervalSince1970: TimeInterval(zoomedChartRange.lowerBound) + .hour)
        let toDate = Date(timeIntervalSince1970: TimeInterval(zoomedChartRange.upperBound))
        if Calendar.utc.startOfDay(for: fromDate) == Calendar.utc.startOfDay(for: toDate) {
            let stirng = BaseConstants.headerFullZoomedFormatter.string(from: fromDate)
            self.setChartTitleClosure?(stirng, animated)
        } else {
            let stirng = "\(BaseConstants.headerMediumRangeFormatter.string(from: fromDate)) - \(BaseConstants.headerMediumRangeFormatter.string(from: toDate))"
            self.setChartTitleClosure?(stirng, animated)
        }
    }
    
    override func chartInteractionDidBegin(point: CGPoint) {
        lastChartInteractionPoint = point
        isChartInteractionBegun = true
    }
    
    override func chartInteractionDidEnd() {
        
    }
    
    override func cancelChartInteraction() {
        isChartInteractionBegun = false
    }
    
    override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        
    }
    
    override var actualChartVisibility: [Bool] {
        return isZoomed ? zoomChartVisibility : chartVisibility
    }
    
    override var actualChartsCollection: ChartsCollection {
        return initialChartsCollection
    }

    var visibleChartValues: [ChartsCollection.Chart] {
        let visibleCharts: [ChartsCollection.Chart] = actualChartVisibility.enumerated().compactMap { args in
            args.element ? initialChartsCollection.chartValues[args.offset] : nil
        }
        return visibleCharts
    }
    
    
    func chartDetailsViewModel(closestDate: Date, pointIndex: Int) -> ChartDetailsViewModel {
        let values: [ChartDetailsViewModel.Value] = actualChartsCollection.chartValues.enumerated().map { arg in
            let (index, component) = arg
            return ChartDetailsViewModel.Value(prefix: nil,
                                               title: component.name,
                                               value: BaseConstants.detailsNumberFormatter.string(from: component.values[pointIndex]),
                                               color: component.color,
                                               visible: actualChartVisibility[index])
        }
        let dateString: String
        if isZoomed {
            dateString = BaseConstants.timeDateFormatter.string(from: closestDate)
        } else {
            dateString = BaseConstants.headerMediumRangeFormatter.string(from: closestDate)
        }
        let viewModel = ChartDetailsViewModel(title: dateString,
                                              showArrow: !self.isZoomed,
                                              showPrefixes: false,
                                              values: values,
                                              totalValue: nil,
                                              tapAction: { [weak self] in self?.didTapZoomIn(date: closestDate) })
        return viewModel
    }
    
    override func didTapZoomIn(date: Date) {
        guard isZoomed == false else { return }
        cancelChartInteraction()
        self.getDetailsData?(date, { updatedCollection in
            if let updatedCollection = updatedCollection {
                self.initialChartRange = self.currentHorizontalRange
                if let startDate = updatedCollection.axisValues.first,
                    let endDate = updatedCollection.axisValues.last {
                    self.zoomedChartRange = CGFloat(max(date.timeIntervalSince1970, startDate.timeIntervalSince1970))...CGFloat(min(date.timeIntervalSince1970 + .day - .hour, endDate.timeIntervalSince1970))
                } else {
                    self.zoomedChartRange = CGFloat(date.timeIntervalSince1970)...CGFloat(date.timeIntervalSince1970 + .day - 1)
                }
                self.setupChartCollection(chartsCollection: updatedCollection, animated: true, isZoomed: true)
            }
        })
    }
    
    func horizontalLimitsLabels(horizontalRange: ClosedRange<CGFloat>,
                                scaleType: ChartScaleType,
                                prevoiusHorizontalStrideInterval: Int) -> (Int, [LinesChartLabel])? {
        let numberOfItems = horizontalRange.distance / CGFloat(scaleType.timeInterval)
        let maximumNumberOfItems = chartFrame().width / scaleType.minimumAxisXDistance
        let tempStride = max(1, Int((numberOfItems / maximumNumberOfItems).rounded(.up)))
        var strideInterval = 1
        while strideInterval < tempStride {
            strideInterval *= 2
        }
        
        if strideInterval != prevoiusHorizontalStrideInterval && strideInterval > 0 {
            var labels: [LinesChartLabel] = []
            for index in stride(from: initialChartsCollection.axisValues.count - 1, to: -1, by: -strideInterval).reversed() {
                let date = initialChartsCollection.axisValues[index]
                labels.append(LinesChartLabel(value: CGFloat(date.timeIntervalSince1970),
                                              text: scaleType.dateFormatter.string(from: date)))
            }
            return (strideInterval, labels)
        }
        return nil
    }
    
    func findClosestDateTo(dateToFind: Date) -> (Date, Int)? {
        guard initialChartsCollection.axisValues.count > 0 else { return nil }
        var closestDate = initialChartsCollection.axisValues[0]
        var minIndex = 0
        for (index, date) in initialChartsCollection.axisValues.enumerated() {
            if abs(dateToFind.timeIntervalSince(date)) < abs(dateToFind.timeIntervalSince(closestDate)) {
                closestDate = date
                minIndex = index
            }
        }
        return (closestDate, minIndex)
    }
    
    func verticalLimitsLabels(verticalRange: ClosedRange<CGFloat>) -> (ClosedRange<CGFloat>, [LinesChartLabel]) {
        let ditance = verticalRange.distance
        let chartHeight = chartFrame().height
        
        guard ditance > 0, chartHeight > 0 else { return (BaseConstants.defaultRange, []) }
        
        let approximateNumberOfChartValues = (chartHeight / BaseConstants.minimumAxisYLabelsDistance)
        
        var numberOfOffsetsPerItem = ditance / approximateNumberOfChartValues
        var multiplier: CGFloat = 1.0
        while numberOfOffsetsPerItem > 10 {
            numberOfOffsetsPerItem /= 10
            multiplier *= 10
        }
        var dividor: CGFloat = 1.0
        var maximumNumberOfDecimals = 2
        while numberOfOffsetsPerItem < 1 {
            numberOfOffsetsPerItem *= 10
            dividor *= 10
            maximumNumberOfDecimals += 1
        }
        
        var base: CGFloat = BaseConstants.verticalBaseAnchors.first { numberOfOffsetsPerItem > $0 } ?? BaseConstants.defaultVerticalBaseAnchor
        base = base * multiplier / dividor
        
        var verticalLabels: [LinesChartLabel] = []
        var verticalValue = (verticalRange.lowerBound / base).rounded(.down) * base
        let lowerBound = verticalValue
        
        let numberFormatter = BaseConstants.chartNumberFormatter
        numberFormatter.maximumFractionDigits = maximumNumberOfDecimals
        while verticalValue < verticalRange.upperBound {
            let text: String = numberFormatter.string(from: NSNumber(value: Double(verticalValue))) ?? ""
            
            verticalLabels.append(LinesChartLabel(value: verticalValue, text: text))
            verticalValue += base
        }
        let updatedRange = lowerBound...verticalValue
        
        return (updatedRange, verticalLabels)
    }
}

enum ChartScaleType {
    case day
    case hour
    case minutes5
}

extension ChartScaleType {
    var timeInterval: TimeInterval {
        switch self {
        case .day: return .day
        case .hour: return .hour
        case .minutes5: return .minute * 5
        }
    }
    
    var minimumAxisXDistance: CGFloat {
        switch self {
        case .day: return 50
        case .hour: return 40
        case .minutes5: return 40
        }
    }
    var dateFormatter: DateFormatter {
        switch self {
        case .day: return BaseConstants.monthDayDateFormatter
        case .hour: return BaseConstants.timeDateFormatter
        case .minutes5: return BaseConstants.timeDateFormatter
        }
    }
}
