//
//  BarChartRenderer.swift
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

class BarChartRenderer: BaseChartRenderer {
    struct BarsData {
        static let blank = BarsData(barWidth: 1, locations: [], components: [])
        var barWidth: CGFloat
        var locations: [CGFloat]
        var components: [Component]
        
        struct Component {
            var color: GColor
            var values: [CGFloat]
        }
    }
    
    private var step = false
    private var lineWidth: CGFloat = 2.0
    
    init(step: Bool = false, lineWidth: CGFloat = 2.0) {
        self.step = step
        self.lineWidth = lineWidth
        
        super.init()
    }
    
    var fillToTop: Bool = false
    private(set) lazy var selectedIndexAnimator: AnimationController<CGFloat> = {
        return AnimationController(current: 0, refreshClosure: self.refreshClosure)
    }()
    func setSelectedIndex(_ index: Int?, animated: Bool) {
        let destinationValue: CGFloat = (index == nil) ? 0 : 1
        if animated {
            if index != nil {
                selectedBarIndex = index
            }
            self.selectedIndexAnimator.completionClosure = {
                self.selectedBarIndex = index
            }
            guard self.selectedIndexAnimator.end != destinationValue else { return }
            self.selectedIndexAnimator.animate(to: destinationValue, duration: .defaultDuration)
        } else {
            self.selectedIndexAnimator.set(current: destinationValue)
            self.selectedBarIndex = index
        }
    }

    private var selectedBarIndex: Int? {
        didSet {
            setNeedsDisplay()
        }
    }
    var generalUnselectedAlpha: CGFloat = 0.5
    
    private var componentsAnimators: [AnimationController<CGFloat>] = []
    var bars: BarsData = BarsData(barWidth: 1, locations: [], components: []) {
        willSet {
            if bars.components.count != newValue.components.count {
                componentsAnimators = newValue.components.map { _ in AnimationController<CGFloat>(current: 1, refreshClosure: self.refreshClosure) }
            }
        }
        didSet {
            setNeedsDisplay()
        }
    }
    
    func setComponentVisible(_ isVisible: Bool, at index: Int, animated: Bool) {
        componentsAnimators[index].animate(to: isVisible ? 1 : 0, duration: animated ? .defaultDuration : 0)
    }
    
    private lazy var backgroundColorAnimator = AnimationController(current: NSColorContainer(color: .white), refreshClosure: refreshClosure)
    func update(backgroundColor: GColor, animated: Bool) {
        if animated {
            backgroundColorAnimator.animate(to: NSColorContainer(color: backgroundColor), duration: .defaultDuration)
        } else {
            backgroundColorAnimator.set(current: NSColorContainer(color: backgroundColor))
        }
    }
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let chartsAlpha = chartAlphaAnimator.current
        if chartsAlpha == 0 { return }

        let range = renderRange(bounds: bounds, chartFrame: chartFrame)

        var selectedPaths: [[CGRect]] = bars.components.map { _ in [] }
        var unselectedPaths: [[CGRect]] = bars.components.map { _ in [] }

        if var barIndex = bars.locations.firstIndex(where: { $0 >= range.lowerBound }) {
            if fillToTop {
                barIndex = max(0, barIndex - 1)
                
                while barIndex < bars.locations.count {
                    let currentLocation = bars.locations[barIndex]
                    let right = transform(toChartCoordinateHorizontal: currentLocation, chartFrame: chartFrame).roundedUpToPixelGrid()
                    let left = transform(toChartCoordinateHorizontal: currentLocation - bars.barWidth, chartFrame: chartFrame).roundedUpToPixelGrid()
                    
                    var summ: CGFloat = 0
                    for (index, component) in bars.components.enumerated() {
                        summ += componentsAnimators[index].current * component.values[barIndex]
                    }
                    guard summ > 0 else {
                        barIndex += 1
                        continue
                    }
                    
                    var stackedValue: CGFloat = 0
                    for (index, component) in bars.components.enumerated() {
                        let visibilityPercent = componentsAnimators[index].current
                        if visibilityPercent == 0 { continue }
                        
                        let bottomFraction = stackedValue
                        let topFraction = stackedValue + ((component.values[barIndex] * visibilityPercent) / summ)
                        
                        let rect = CGRect(x: left,
                                          y: chartFrame.maxY - chartFrame.height * topFraction,
                                          width: right - left,
                                          height: chartFrame.height * (topFraction - bottomFraction))
                        if selectedBarIndex == barIndex {
                            selectedPaths[index].append(rect)
                        } else {
                            unselectedPaths[index].append(rect)
                        }
                        stackedValue = topFraction
                    }
                    if currentLocation > range.upperBound {
                        break
                    }
                    barIndex += 1
                }
                
                for (index, component) in bars.components.enumerated() {
                    context.saveGState()
                    context.setFillColor(component.color.withAlphaComponent(chartsAlpha * component.color.alphaValue).cgColor)
                    context.fill(selectedPaths[index])
                    let resultAlpha: CGFloat = 1.0 - (1.0 - generalUnselectedAlpha) * selectedIndexAnimator.current
                    context.setFillColor(component.color.withAlphaComponent(chartsAlpha * component.color.alphaValue * resultAlpha).cgColor)
                    context.fill(unselectedPaths[index])
                    context.restoreGState()
                }
            } else {
                if self.step {
                    var selectedPaths: [[CGRect]] = bars.components.map { _ in [] }
                    barIndex = max(0, barIndex - 1)
                    
                    var currentLocation = bars.locations[barIndex]
                    var leftX = transform(toChartCoordinateHorizontal: currentLocation - bars.barWidth, chartFrame: chartFrame)
                    var rightX: CGFloat = 0
                    
                    var backgroundPaths: [[CGPoint]] = bars.components.map { _ in Array() }
                    let itemsCount = ((bars.locations.count - barIndex) * 2) + 4
                    for path in backgroundPaths.indices {
                        backgroundPaths[path].reserveCapacity(itemsCount)
                    }
                    
                    var maxValues: [CGFloat] = bars.components.map { _ in 0 }
                    while barIndex < bars.locations.count {
                        currentLocation = bars.locations[barIndex]
                        rightX = transform(toChartCoordinateHorizontal: currentLocation, chartFrame: chartFrame)
                        
                        let bottomY: CGFloat = transform(toChartCoordinateVertical: 0.0, chartFrame: chartFrame)
                        for (index, component) in bars.components.enumerated() {
                            let visibilityPercent = componentsAnimators[index].current
                            if visibilityPercent == 0 { continue }
                            
                            let value = component.values[barIndex]
                            let height = value * visibilityPercent
                            let topY = transform(toChartCoordinateVertical: height, chartFrame: chartFrame)
                            let componentHeight = (bottomY - topY)
                            maxValues[index] = max(maxValues[index], componentHeight)
                            if selectedBarIndex == barIndex {
                                let rect = CGRect(x: leftX,
                                                  y: topY,
                                                  width: rightX - leftX,
                                                  height: componentHeight)
                                selectedPaths[index].append(rect)
                            }
                            backgroundPaths[index].append(CGPoint(x: leftX, y: topY))
                            backgroundPaths[index].append(CGPoint(x: rightX, y: topY))
                        }
                        if currentLocation > range.upperBound {
                            break
                        }
                        leftX = rightX
                        barIndex += 1
                    }
                                        
                    for (index, component) in bars.components.enumerated().reversed() {
                        if maxValues[index] < optimizationLevel {
                            continue
                        }
                        context.saveGState()
                        
                        context.setLineWidth(self.lineWidth)
                        context.setStrokeColor(GColor.valueBetween(start: backgroundColorAnimator.current.color,
                                                                 end: component.color,
                                                                 offset: 1.0).cgColor)
                        context.beginPath()
                        context.addLines(between: backgroundPaths[index])
                        context.strokePath()
                        context.restoreGState()
                    }
                } else {
                    var selectedPaths: [[CGRect]] = bars.components.map { _ in [] }
                    barIndex = max(0, barIndex - 1)
                    
                    var currentLocation = bars.locations[barIndex]
                    var leftX = transform(toChartCoordinateHorizontal: currentLocation - bars.barWidth, chartFrame: chartFrame)
                    var rightX: CGFloat = 0
                    
                    let startPoint = CGPoint(x: leftX,
                                             y: transform(toChartCoordinateVertical: verticalRange.current.lowerBound, chartFrame: chartFrame))
                    
                    var backgroundPaths: [[CGPoint]] = bars.components.map { _ in Array() }
                    let itemsCount = ((bars.locations.count - barIndex) * 2) + 4
                    for path in backgroundPaths.indices {
                        backgroundPaths[path].reserveCapacity(itemsCount)
                        backgroundPaths[path].append(startPoint)
                    }
                    var maxValues: [CGFloat] = bars.components.map { _ in 0 }
                    while barIndex < bars.locations.count {
                        currentLocation = bars.locations[barIndex]
                        rightX = transform(toChartCoordinateHorizontal: currentLocation, chartFrame: chartFrame)
                        
                        var stackedValue: CGFloat = 0
                        var bottomY: CGFloat = transform(toChartCoordinateVertical: stackedValue, chartFrame: chartFrame)
                        for (index, component) in bars.components.enumerated() {
                            let visibilityPercent = componentsAnimators[index].current
                            if visibilityPercent == 0 { continue }
                            
                            let height = component.values[barIndex] * visibilityPercent
                            stackedValue += height
                            let topY = transform(toChartCoordinateVertical: stackedValue, chartFrame: chartFrame)
                            let componentHeight = (bottomY - topY)
                            maxValues[index] = max(maxValues[index], componentHeight)
                            if selectedBarIndex == barIndex {
                                let rect = CGRect(x: leftX,
                                                  y: topY,
                                                  width: rightX - leftX,
                                                  height: componentHeight)
                                selectedPaths[index].append(rect)
                            }
                            backgroundPaths[index].append(CGPoint(x: leftX, y: topY))
                            backgroundPaths[index].append(CGPoint(x: rightX, y: topY))
                            bottomY = topY
                        }
                        if currentLocation > range.upperBound {
                            break
                        }
                        leftX = rightX
                        barIndex += 1
                    }

                    let endPoint = CGPoint(x: transform(toChartCoordinateHorizontal: currentLocation, chartFrame: chartFrame).roundedUpToPixelGrid(),
                                           y: transform(toChartCoordinateVertical: verticalRange.current.lowerBound, chartFrame: chartFrame))
                    let colorOffset = Double((1.0 - (1.0 - generalUnselectedAlpha) * selectedIndexAnimator.current) * chartsAlpha)

                    for (index, component) in bars.components.enumerated().reversed() {
                        if maxValues[index] < optimizationLevel {
                            continue
                        }
                        context.saveGState()
                        backgroundPaths[index].append(endPoint)
                        
                        context.setFillColor(GColor.valueBetween(start: backgroundColorAnimator.current.color,
                                                                  end: component.color,
                                                                  offset: colorOffset).cgColor)
                        context.beginPath()
                        context.addLines(between: backgroundPaths[index])
                        context.closePath()
                        context.fillPath()
                        context.restoreGState()
                    }
                    
                    for (index, component) in bars.components.enumerated().reversed() {
                        context.setFillColor(component.color.withAlphaComponent(chartsAlpha * component.color.alphaValue).cgColor)
                        context.fill(selectedPaths[index])
                    }
                }
            }
        }
    }
}

extension BarChartRenderer.BarsData {
    static func initialComponents(chartsCollection: ChartsCollection, separate: Bool = false, initialComponents: [BarChartRenderer.BarsData.Component]? = nil) ->
        (width: CGFloat,
        chartBars: BarChartRenderer.BarsData,
        totalHorizontalRange: ClosedRange<CGFloat>,
        totalVerticalRange: ClosedRange<CGFloat>) {
            let width: CGFloat
            if chartsCollection.axisValues.count > 1 {
                width = CGFloat(abs(chartsCollection.axisValues[1].timeIntervalSince1970 - chartsCollection.axisValues[0].timeIntervalSince1970))
            } else {
                width = 1
            }
            let components = initialComponents ?? chartsCollection.chartValues.map { BarChartRenderer.BarsData.Component(color: $0.color,
                                                                                                    values: $0.values.map { CGFloat($0) }) }
            let chartBars = BarChartRenderer.BarsData(barWidth: width,
                                                      locations: chartsCollection.axisValues.map { CGFloat($0.timeIntervalSince1970) },
                                                      components: components)
            
            let totalVerticalRange = BarChartRenderer.BarsData.verticalRange(bars: chartBars, separate: separate) ?? 0...1
            let totalHorizontalRange = BarChartRenderer.BarsData.visibleHorizontalRange(bars: chartBars, width: width) ?? 0...1
            return (width: width, chartBars: chartBars, totalHorizontalRange: totalHorizontalRange, totalVerticalRange: totalVerticalRange)
    }
    
    static func visibleHorizontalRange(bars: BarChartRenderer.BarsData, width: CGFloat) -> ClosedRange<CGFloat>? {
        guard let firstPoint = bars.locations.first,
            let lastPoint = bars.locations.last,
            firstPoint <= lastPoint else {
                return nil
        }
        
        return (firstPoint - width)...lastPoint
    }
    
    static func verticalRange(bars: BarChartRenderer.BarsData, separate: Bool = false, calculatingRange: ClosedRange<CGFloat>? = nil, addBounds: Bool = false) -> ClosedRange<CGFloat>? {
        guard bars.components.count > 0 else {
            return nil
        }
        if let calculatingRange = calculatingRange {
            guard var index = bars.locations.firstIndex(where: { $0 >= calculatingRange.lowerBound && $0 <= calculatingRange.upperBound }) else {
                return nil
            }
            
            var vMax: CGFloat = bars.components[0].values[index]
            while index < bars.locations.count {
                if separate {
                    for component in bars.components {
                        vMax = max(vMax, component.values[index])
                    }
                } else {
                    var summ: CGFloat = 0
                    for component in bars.components {
                        summ += component.values[index]
                    }
                    vMax = max(vMax, summ)
                }
                
                if bars.locations[index] > calculatingRange.upperBound {
                    break
                }
                index += 1
            }
            return 0...vMax
        } else {
            var index = 0
            
            var vMax: CGFloat = bars.components[0].values[index]
            while index < bars.locations.count {
                if separate {
                    for component in bars.components {
                        vMax = max(vMax, component.values[index])
                    }
                } else {
                    var summ: CGFloat = 0
                    for component in bars.components {
                        summ += component.values[index]
                    }
                    vMax = max(vMax, summ)
                }
                
                index += 1
            }
            return 0...vMax
        }
    }
}
