//
//  LinesChartRenderer.swift
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

class LinesChartRenderer: BaseChartRenderer {
    struct LineData {
        var color: GColor
        var points: [CGPoint]
    }
    
    private var linesAlphaAnimators: [AnimationController<CGFloat>] = []
    
    var lineWidth: CGFloat = 1 {
        didSet {
            setNeedsDisplay()
        }
    }
    private lazy var linesShapeAnimator = AnimationController<Double>(current: 1, refreshClosure: self.refreshClosure)
    private var fromLines: [LineData] = []
    private var toLines: [LineData] = []
    
    func setLines(lines: [LineData], animated: Bool) {
        if toLines.count != lines.count {
            linesAlphaAnimators = lines.map { _ in AnimationController<CGFloat>(current: 1, refreshClosure: self.refreshClosure) }
        }
        if animated {
            self.fromLines = self.toLines
            self.toLines = lines
            linesShapeAnimator.set(current: 1.0 - linesShapeAnimator.current)
            linesShapeAnimator.completionClosure = {
                self.fromLines = []
            }
            linesShapeAnimator.animate(to: 1, duration: .defaultDuration)
        } else {
            self.fromLines = []
            self.toLines = lines
            linesShapeAnimator.set(current: 1)
        }
    }
    
    func setLineVisible(_ isVisible: Bool, at index: Int, animated: Bool) {
        if linesAlphaAnimators.count > index {
            linesAlphaAnimators[index].animate(to: isVisible ? 1 : 0, duration: animated ? .defaultDuration : 0)
        }
    }
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let chartsAlpha = chartAlphaAnimator.current
        if chartsAlpha == 0 { return }
        let range = renderRange(bounds: bounds, chartFrame: chartFrame)
        
        let spacing: CGFloat = 1.0
        context.clip(to: CGRect(origin: CGPoint(x: 0.0, y: chartFrame.minY - spacing), size: CGSize(width: chartFrame.width + chartFrame.origin.x * 2.0, height: chartFrame.height + spacing * 2.0)))
        
        for (index, toLine) in toLines.enumerated() {
            let alpha = linesAlphaAnimators[index].current * chartsAlpha
            if alpha == 0 { continue }
            context.setAlpha(alpha)
            context.setStrokeColor(toLine.color.cgColor)
            context.setLineWidth(lineWidth)
            
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            
            if linesShapeAnimator.isAnimating {
                let animationOffset = linesShapeAnimator.current
                
                let fromPoints = fromLines.safeElement(at: index)?.points ?? []
                let toPoints = toLines.safeElement(at: index)?.points ?? []
                
                var fromIndex: Int? = fromPoints.firstIndex(where: { $0.x >= range.lowerBound })
                var toIndex: Int? = toPoints.firstIndex(where: { $0.x >= range.lowerBound })
                
                let fromRange = verticalRange.start
                let currentRange = verticalRange.current
                let toRange = verticalRange.end
                
                func convertFromPoint(_ fromPoint: CGPoint) -> CGPoint {
                    return CGPoint(x: fromPoint.x,
                                   y: (fromPoint.y - fromRange.lowerBound) / fromRange.distance * currentRange.distance + currentRange.lowerBound)
                }
                
                func convertToPoint(_ toPoint: CGPoint) -> CGPoint {
                    return CGPoint(x: toPoint.x,
                                   y: (toPoint.y - toRange.lowerBound) / toRange.distance * currentRange.distance + currentRange.lowerBound)
                }
                
                var previousFromPoint: CGPoint
                var previousToPoint: CGPoint
                let startFromPoint: CGPoint?
                let startToPoint: CGPoint?
                
                if let validFrom = fromIndex {
                    previousFromPoint = convertFromPoint(fromPoints[max(0, validFrom - 1)])
                    startFromPoint = previousFromPoint
                } else {
                    previousFromPoint = .zero
                    startFromPoint = nil
                }
                if let validTo = toIndex {
                    previousToPoint = convertToPoint(toPoints[max(0, validTo - 1)])
                    startToPoint = previousToPoint
                } else {
                    previousToPoint = .zero
                    startToPoint = nil
                }
                
                var combinedPoints: [CGPoint] = []
                
                func add(pointToDraw: CGPoint) {
                    if let startFromPoint = startFromPoint,
                        pointToDraw.x < startFromPoint.x {
                        let animatedPoint = CGPoint(x: pointToDraw.x,
                                                    y: CGFloat.valueBetween(start: startFromPoint.y, end: pointToDraw.y, offset: animationOffset))
                        combinedPoints.append(transform(toChartCoordinate: animatedPoint, chartFrame: chartFrame))
                    } else if let startToPoint = startToPoint,
                        pointToDraw.x < startToPoint.x {
                        let animatedPoint = CGPoint(x: pointToDraw.x,
                                                    y: CGFloat.valueBetween(start: startToPoint.y, end: pointToDraw.y, offset: 1 - animationOffset))
                        combinedPoints.append(transform(toChartCoordinate: animatedPoint, chartFrame: chartFrame))
                    } else {
                        combinedPoints.append(transform(toChartCoordinate: pointToDraw, chartFrame: chartFrame))
                    }
                }
                
                if previousToPoint != .zero && previousFromPoint != .zero {
                    add(pointToDraw: (previousToPoint.x < previousFromPoint.x ? previousToPoint : previousFromPoint))
                } else if previousToPoint != .zero {
                    add(pointToDraw: previousToPoint)
                } else if previousFromPoint != .zero {
                    add(pointToDraw: previousFromPoint)
                }
                
                while let validFromIndex = fromIndex,
                    let validToIndex = toIndex,
                    validFromIndex < fromPoints.count,
                    validToIndex < toPoints.count {
                        let currentFromPoint = convertFromPoint(fromPoints[validFromIndex])
                        let currentToPoint = convertToPoint(toPoints[validToIndex])
                        let pointToAdd: CGPoint
                        if currentFromPoint.x == currentToPoint.x {
                            pointToAdd = CGPoint.valueBetween(start: currentFromPoint, end: currentToPoint, offset: animationOffset)
                            previousFromPoint = currentFromPoint
                            previousToPoint = currentToPoint
                            fromIndex = validFromIndex + 1
                            toIndex = validToIndex + 1
                        } else if currentFromPoint.x < currentToPoint.x {
                            if previousToPoint.x < currentFromPoint.x {
                                let offset = Double((currentFromPoint.x - previousToPoint.x) / (currentToPoint.x - previousToPoint.x))
                                let intermidiateToPoint = CGPoint.valueBetween(start: previousToPoint, end: currentToPoint, offset: offset)
                                pointToAdd = CGPoint.valueBetween(start: currentFromPoint, end: intermidiateToPoint, offset: animationOffset)
                            } else {
                                pointToAdd = currentFromPoint
                            }
                            previousFromPoint = currentFromPoint
                            fromIndex = validFromIndex + 1
                        } else {
                            if previousFromPoint.x < currentToPoint.x {
                                let offset = Double((currentToPoint.x - previousFromPoint.x) / (currentFromPoint.x - previousFromPoint.x))
                                let intermidiateFromPoint = CGPoint.valueBetween(start: previousFromPoint, end: currentFromPoint, offset: offset)
                                pointToAdd = CGPoint.valueBetween(start: intermidiateFromPoint, end: currentToPoint, offset: animationOffset)
                            } else {
                                pointToAdd = currentToPoint
                            }
                            previousToPoint = currentToPoint
                            toIndex = validToIndex + 1
                        }
                        add(pointToDraw: pointToAdd)
                        if (pointToAdd.x > range.upperBound) {
                            break
                        }
                }
                
                while let validToIndex = toIndex, validToIndex < toPoints.count {
                    var pointToAdd = convertToPoint(toPoints[validToIndex])
                    pointToAdd.y = CGFloat.valueBetween(start: previousFromPoint.y,
                                                        end: pointToAdd.y,
                                                        offset: animationOffset)
                    
                    add(pointToDraw: pointToAdd)
                    if (pointToAdd.x > range.upperBound) {
                        break
                    }
                    
                    toIndex = validToIndex + 1
                }
                
                while let validFromIndex = fromIndex, validFromIndex < fromPoints.count {
                    var pointToAdd = convertFromPoint(fromPoints[validFromIndex])
                    pointToAdd.y = CGFloat.valueBetween(start: previousToPoint.y,
                                                        end: pointToAdd.y,
                                                        offset: 1 - animationOffset)
                    
                    add(pointToDraw: pointToAdd)
                    if (pointToAdd.x > range.upperBound) {
                        break
                    }
                    
                    fromIndex = validFromIndex + 1
                }
                
                var index = 0
                var lines: [CGPoint] = []
                var currentChartPoint = combinedPoints[index]
                lines.append(currentChartPoint)
                
                var chartPoints = [currentChartPoint]
                var minIndex = 0
                var maxIndex = 0
                index += 1
                
                while index < combinedPoints.count {
                    currentChartPoint = combinedPoints[index]
                    
                    if currentChartPoint.x - chartPoints[0].x < lineWidth * optimizationLevel {
                        chartPoints.append(currentChartPoint)
                        
                        if currentChartPoint.y > chartPoints[maxIndex].y {
                            maxIndex = chartPoints.count - 1
                        }
                        if currentChartPoint.y < chartPoints[minIndex].y {
                            minIndex = chartPoints.count - 1
                        }
                        
                        index += 1
                    } else {
                        if chartPoints.count == 1 {
                            lines.append(currentChartPoint)
                            lines.append(currentChartPoint)
                            chartPoints[0] = currentChartPoint
                            index += 1
                            minIndex = 0
                            maxIndex = 0
                        } else {
                            if minIndex < maxIndex {
                                if minIndex != 0 {
                                    lines.append(chartPoints[minIndex])
                                    lines.append(chartPoints[minIndex])
                                }
                                lines.append(chartPoints[maxIndex])
                                lines.append(chartPoints[maxIndex])
                                if maxIndex != chartPoints.count - 1 {
                                    chartPoints = [chartPoints[maxIndex], chartPoints.last!]
                                } else {
                                    chartPoints = [chartPoints[maxIndex]]
                                }
                            } else {
                                if maxIndex != 0 {
                                    lines.append(chartPoints[maxIndex])
                                    lines.append(chartPoints[maxIndex])
                                }
                                lines.append(chartPoints[minIndex])
                                lines.append(chartPoints[minIndex])
                                if minIndex != chartPoints.count - 1 {
                                    chartPoints = [chartPoints[minIndex], chartPoints.last!]
                                } else {
                                    chartPoints = [chartPoints[minIndex]]
                                }
                            }
                            if chartPoints.count == 2 {
                                if chartPoints[0].y < chartPoints[1].y {
                                    minIndex = 0
                                    maxIndex = 1
                                } else {
                                    minIndex = 1
                                    maxIndex = 0
                                }
                            } else {
                                minIndex = 0
                                maxIndex = 0
                            }
                        }
                    }
                }
                
                if chartPoints.count == 1 {
                    lines.append(currentChartPoint)
                    lines.append(currentChartPoint)
                } else {
                    if minIndex < maxIndex {
                        if minIndex != 0 {
                            lines.append(chartPoints[minIndex])
                            lines.append(chartPoints[minIndex])
                        }
                        lines.append(chartPoints[maxIndex])
                        lines.append(chartPoints[maxIndex])
                        if maxIndex != chartPoints.count - 1 {
                            lines.append(chartPoints.last!)
                            lines.append(chartPoints.last!)
                        }
                    } else {
                        if maxIndex != 0 {
                            lines.append(chartPoints[maxIndex])
                            lines.append(chartPoints[maxIndex])
                        }
                        lines.append(chartPoints[minIndex])
                        lines.append(chartPoints[minIndex])
                        if minIndex != chartPoints.count - 1 {
                            lines.append(chartPoints.last!)
                            lines.append(chartPoints.last!)
                        }
                    }
                }
                
                if (lines.count % 2) == 1 {
                    lines.removeLast()
                }
                
                context.setLineCap(.round)
                context.strokeLineSegments(between: lines)
            } else {                
                if var index = toLine.points.firstIndex(where: { $0.x >= range.lowerBound }) {
                    var lines: [CGPoint] = []
                    index = max(0, index - 1)
                    var currentPoint = toLine.points[index]
                    var currentChartPoint = transform(toChartCoordinate: currentPoint, chartFrame: chartFrame)
                    lines.append(currentChartPoint)
                    //context.move(to: currentChartPoint)
                    
                    var chartPoints = [currentChartPoint]
                    var minIndex = 0
                    var maxIndex = 0
                    index += 1
                    
                    while index < toLine.points.count {
                        currentPoint = toLine.points[index]
                        currentChartPoint = transform(toChartCoordinate: currentPoint, chartFrame: chartFrame)
                        
                        if currentChartPoint.x - chartPoints[0].x < lineWidth * optimizationLevel {
                            chartPoints.append(currentChartPoint)
                            
                            if currentChartPoint.y > chartPoints[maxIndex].y {
                                maxIndex = chartPoints.count - 1
                            }
                            if currentChartPoint.y < chartPoints[minIndex].y {
                                minIndex = chartPoints.count - 1
                            }
                            
                            index += 1
                        } else {
                            if chartPoints.count == 1 {
                                lines.append(currentChartPoint)
                                lines.append(currentChartPoint)
                                chartPoints[0] = currentChartPoint
                                index += 1
                                minIndex = 0
                                maxIndex = 0
                            } else {
                                if minIndex < maxIndex {
                                    if minIndex != 0 {
                                        lines.append(chartPoints[minIndex])
                                        lines.append(chartPoints[minIndex])
                                    }
                                    lines.append(chartPoints[maxIndex])
                                    lines.append(chartPoints[maxIndex])
                                    if maxIndex != chartPoints.count - 1 {
                                        chartPoints = [chartPoints[maxIndex], chartPoints.last!]
                                    } else {
                                        chartPoints = [chartPoints[maxIndex]]
                                    }
                                } else {
                                    if maxIndex != 0 {
                                        lines.append(chartPoints[maxIndex])
                                        lines.append(chartPoints[maxIndex])
                                    }
                                    lines.append(chartPoints[minIndex])
                                    lines.append(chartPoints[minIndex])
                                    if minIndex != chartPoints.count - 1 {
                                        chartPoints = [chartPoints[minIndex], chartPoints.last!]
                                    } else {
                                        chartPoints = [chartPoints[minIndex]]
                                    }
                                }
                                if chartPoints.count == 2 {
                                    if chartPoints[0].y < chartPoints[1].y {
                                        minIndex = 0
                                        maxIndex = 1
                                    } else {
                                        minIndex = 1
                                        maxIndex = 0
                                    }
                                } else {
                                    minIndex = 0
                                    maxIndex = 0
                                }
                            }
                        }
                        if currentPoint.x > range.upperBound {
                            break
                        }
                    }
                    
                    if chartPoints.count == 1 {
                        lines.append(currentChartPoint)
                        lines.append(currentChartPoint)
                    } else {
                        if minIndex < maxIndex {
                            if minIndex != 0 {
                                lines.append(chartPoints[minIndex])
                                lines.append(chartPoints[minIndex])
                            }
                            lines.append(chartPoints[maxIndex])
                            lines.append(chartPoints[maxIndex])
                            if maxIndex != chartPoints.count - 1 {
                                lines.append(chartPoints.last!)
                                lines.append(chartPoints.last!)
                            }
                        } else {
                            if maxIndex != 0 {
                                lines.append(chartPoints[maxIndex])
                                lines.append(chartPoints[maxIndex])
                            }
                            lines.append(chartPoints[minIndex])
                            lines.append(chartPoints[minIndex])
                            if minIndex != chartPoints.count - 1 {
                                lines.append(chartPoints.last!)
                                lines.append(chartPoints.last!)
                            }
                        }
                    }
                    
                    if (lines.count % 2) == 1 {
                        lines.removeLast()
                    }
                    
                    context.setLineCap(.round)
                    context.strokeLineSegments(between: lines)
                }
            }
            context.endTransparencyLayer()
            context.setAlpha(1.0)
        }
        
        context.resetClip()
    }
}

extension LinesChartRenderer.LineData {
    static func initialComponents(chartsCollection: ChartsCollection) -> (linesData: [LinesChartRenderer.LineData],
        totalHorizontalRange: ClosedRange<CGFloat>,
        totalVerticalRange: ClosedRange<CGFloat>) {
            let lines: [LinesChartRenderer.LineData] = chartsCollection.chartValues.map { chart in
                let points = chart.values.enumerated().map({ (arg) -> CGPoint in
                    return CGPoint(x: chartsCollection.axisValues[arg.offset].timeIntervalSince1970,
                                   y: arg.element)
                })
                return LinesChartRenderer.LineData(color: chart.color, points: points)
            }
            let horizontalRange = LinesChartRenderer.LineData.horizontalRange(lines: lines) ?? BaseConstants.defaultRange
            let verticalRange = LinesChartRenderer.LineData.verticalRange(lines: lines) ?? BaseConstants.defaultRange
            return (linesData: lines, totalHorizontalRange: horizontalRange, totalVerticalRange: verticalRange)
    }
    
    static func horizontalRange(lines: [LinesChartRenderer.LineData]) -> ClosedRange<CGFloat>? {
        guard let firstPoint = lines.first?.points.first else { return nil }
        var hMin: CGFloat = firstPoint.x
        var hMax: CGFloat = firstPoint.x
        
        for line in lines {
            if let first = line.points.first,
                let last = line.points.last {
                hMin = min(hMin, first.x)
                hMax = max(hMax, last.x)
            }
        }
        
        return hMin...hMax
    }
    
    static func verticalRange(lines: [LinesChartRenderer.LineData], calculatingRange: ClosedRange<CGFloat>? = nil, addBounds: Bool = false) -> ClosedRange<CGFloat>? {
        if let calculatingRange = calculatingRange {
            guard let initalStart = lines.first?.points.first(where: { $0.x >= calculatingRange.lowerBound &&
                $0.x <= calculatingRange.upperBound }) else { return nil }
            var vMin: CGFloat = initalStart.y
            var vMax: CGFloat = initalStart.y
            for line in lines {
                if var index = line.points.firstIndex(where: { $0.x > calculatingRange.lowerBound }) {
                    if addBounds {
                        index = max(0, index - 1)
                    }
                    while index < line.points.count {
                        let point = line.points[index]
                        if point.x < calculatingRange.upperBound {
                            vMin = min(vMin, point.y)
                            vMax = max(vMax, point.y)
                        } else if addBounds {
                            vMin = min(vMin, point.y)
                            vMax = max(vMax, point.y)
                            break
                        } else {
                            break
                        }
                        index += 1
                    }
                }
            }
            
            if vMin == vMax {
                return 0...vMax * 2.0
            }
            
            return vMin...vMax
        } else {
            guard let firstPoint = lines.first?.points.first else { return nil }
            var vMin: CGFloat = firstPoint.y
            var vMax: CGFloat = firstPoint.y
            for line in lines {
                for point in line.points {
                    vMin = min(vMin, point.y)
                    vMax = max(vMax, point.y)
                }
            }
            
            if vMin == vMax {
                return 0...vMax * 2.0
            }
            
            return vMin...vMax
        }
    }
}
