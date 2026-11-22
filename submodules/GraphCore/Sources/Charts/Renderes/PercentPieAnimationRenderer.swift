//
//  PercentPieAnimationRenderer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

class PercentPieAnimationRenderer: BaseChartRenderer {
    override func setup(verticalRange: ClosedRange<CGFloat>, animated: Bool, timeFunction: TimeFunction? = nil) {
        super.setup(verticalRange: 0...1, animated: animated, timeFunction: timeFunction)
    }
    
    private lazy var transitionAnimator = AnimationController<CGFloat>(current: 0, refreshClosure: refreshClosure)
    private var animationComponentsPoints: [[CGPoint]] = []
    var visiblePercentageData: PecentChartRenderer.PercentageData = .blank {
        didSet {
            animationComponentsPoints = []
        }
    }
    var visiblePieComponents: [PieChartRenderer.PieComponent] = []

    func animate(fromDataToPie: Bool, animated: Bool, completion: @escaping () -> Void) {
        assert(visiblePercentageData.components.count == visiblePieComponents.count)
        
        isEnabled = true
        transitionAnimator.completionClosure = { [weak self] in
            self?.isEnabled = false
            completion()
        }
        transitionAnimator.animate(to: fromDataToPie ? 1 : 0, duration: animated ? .defaultDuration : 0)
    }
    
    private func generateAnimationComponentPoints(bounds: CGRect, chartFrame: CGRect) {
        let range = renderRange(bounds: bounds, chartFrame: chartFrame)
        
        let componentsCount = visiblePercentageData.components.count
        guard componentsCount > 0 else { return }
        animationComponentsPoints = visiblePercentageData.components.map { _ in [] }
        var vertices: [CGFloat] = Array<CGFloat>(repeating: 0, count: visiblePercentageData.components.count)
        
        if var locationIndex = visiblePercentageData.locations.firstIndex(where: { $0 > range.lowerBound }) {
            locationIndex = max(0, locationIndex - 1)
            var currentLocation = transform(toChartCoordinateHorizontal: visiblePercentageData.locations[locationIndex], chartFrame: chartFrame)
            let startPoint = CGPoint(x: currentLocation, y: transform(toChartCoordinateVertical: verticalRange.current.lowerBound, chartFrame: chartFrame))
            for index in 0..<componentsCount {
                animationComponentsPoints[index].append(startPoint)
            }
            animationComponentsPoints[componentsCount - 1].append(CGPoint(x: currentLocation, y: transform(toChartCoordinateVertical: verticalRange.current.upperBound, chartFrame: chartFrame)))
            while locationIndex < visiblePercentageData.locations.count {
                currentLocation = transform(toChartCoordinateHorizontal: visiblePercentageData.locations[locationIndex], chartFrame: chartFrame)
                var summ: CGFloat = 0
                
                for (index, component) in visiblePercentageData.components.enumerated() {
                    let value = component.values[locationIndex]
                    if index == 0 {
                        vertices[index] = value
                    } else {
                        vertices[index] = value + vertices[index - 1]
                    }
                    summ += value
                }
                
                for (index, value) in vertices.dropLast().enumerated() {
                    animationComponentsPoints[index].append(CGPoint(x: currentLocation, y: transform(toChartCoordinateVertical: value / summ, chartFrame: chartFrame)))
                }
                if visiblePercentageData.locations[locationIndex] > range.upperBound {
                    break
                }
                locationIndex += 1
            }
            
            animationComponentsPoints[componentsCount - 1].append(CGPoint(x: currentLocation, y: transform(toChartCoordinateVertical: verticalRange.current.upperBound, chartFrame: chartFrame)))
            let endPoint = CGPoint(x: currentLocation, y: transform(toChartCoordinateVertical: verticalRange.current.lowerBound, chartFrame: chartFrame))
            for index in 0..<componentsCount {
                animationComponentsPoints[index].append(endPoint)
            }
        }
    }
    
    private var initialPieAngle: CGFloat = .pi / 3
    var backgroundColor: GColor = .white

    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        self.optimizationLevel = 1
        
        if animationComponentsPoints.isEmpty {
            generateAnimationComponentPoints(bounds: bounds, chartFrame: chartFrame)
        }
        
        let numberOfComponents = animationComponentsPoints.count
        guard numberOfComponents > 0 else { return }
        let destinationRadius = max(chartFrame.width, chartFrame.height)
        
        let animationFraction = transitionAnimator.current
        let animationFractionD = Double(transitionAnimator.current)
        let easeInAnimationFractionD = animationFractionD * animationFractionD * animationFractionD * animationFractionD
        let center = CGPoint(x: chartFrame.midX, y: chartFrame.midY)
        let totalPieSumm: CGFloat = visiblePieComponents.map { $0.value } .reduce(0, +)
        
        let pathsToDraw: [CGMutablePath] = (0..<numberOfComponents).map { _ in CGMutablePath() }
        
        var startAngle: CGFloat = initialPieAngle
        for componentIndex in 0..<(numberOfComponents - 1) {
            let componentPoints = animationComponentsPoints[componentIndex]
            guard componentPoints.count > 4 else {
                return
            }
            
            let percent = visiblePieComponents[componentIndex].value / totalPieSumm
            let segmentSize = 2 * .pi * percent
            let endAngle = startAngle + segmentSize
            let centerAngle = (startAngle + endAngle) / 2
            
            let lineCenterPoint = CGPoint.valueBetween(start: componentPoints[componentPoints.count / 2],
                                                       end: center,
                                                       offset: animationFractionD)
            
            let startDestinationPoint = lineCenterPoint + CGPoint(x: destinationRadius, y: 0)
            let endDestinationPoint = lineCenterPoint + CGPoint(x: -destinationRadius, y: 0)
            let initialStartDestinationAngle: CGFloat = 0
            let initialCenterDestinationAngle: CGFloat = .pi / 2
            let initialEndDestinationAngle: CGFloat = .pi
            
            var previousAddedPoint = (componentPoints[0] * 2 - center)
                .rotate(origin: lineCenterPoint, angle: CGFloat.valueBetween(start: 0, end: centerAngle - initialCenterDestinationAngle, offset: animationFractionD))
            
            pathsToDraw[componentIndex].move(to: previousAddedPoint)
            
            func addPointToPath(_ point: CGPoint) {
                if (point - previousAddedPoint).lengthSquared() > optimizationLevel {
                    pathsToDraw[componentIndex].addLine(to: point)
                    previousAddedPoint = point
                }
            }
            
            for endPointIndex in 1..<(componentPoints.count / 2) {
                addPointToPath(CGPoint.valueBetween(start: componentPoints[endPointIndex], end: endDestinationPoint, offset: easeInAnimationFractionD)
                    .rotate(origin: lineCenterPoint, angle: CGFloat.valueBetween(start: 0, end: endAngle - initialEndDestinationAngle, offset: animationFractionD)))
            }
            
            addPointToPath(lineCenterPoint)

            for startPointIndex in (componentPoints.count / 2 + 1)..<(componentPoints.count - 1) {
                addPointToPath(CGPoint.valueBetween(start: componentPoints[startPointIndex], end: startDestinationPoint, offset: easeInAnimationFractionD)
                    .rotate(origin: lineCenterPoint, angle: CGFloat.valueBetween(start: 0, end: startAngle - initialStartDestinationAngle, offset: animationFractionD)))
            }
            
            if let lastPoint = componentPoints.last {
                addPointToPath((lastPoint * 2 - center)
                    .rotate(origin: lineCenterPoint, angle: CGFloat.valueBetween(start: 0, end: centerAngle - initialCenterDestinationAngle, offset: animationFractionD)))
            }
            
            startAngle = endAngle
        }
        
        if let lastPath = animationComponentsPoints.last {
            pathsToDraw.last?.addLines(between: lastPath)
        }
        
        for (index, path) in pathsToDraw.enumerated().reversed() {
            path.closeSubpath()
            
            context.saveGState()
            context.beginPath()
            context.addPath(path)
            
            context.setFillColor(visiblePieComponents[index].color.cgColor)
            context.fillPath()
            context.restoreGState()
        }
        
        let diagramRadius = (min(chartFrame.width, chartFrame.height) / 2) * 0.925
        let targetFrame = CGRect(origin: CGPoint(x: center.x - diagramRadius,
                                                 y: center.y - diagramRadius),
                                 size: CGSize(width: diagramRadius * 2,
                                              height: diagramRadius * 2))
        
        let minX = animationComponentsPoints.last?.first?.x ?? 0
        let maxX = animationComponentsPoints.last?.last?.x ?? 0
        let startFrame = CGRect(x: minX,
                                y: chartFrame.minY,
                                width: maxX - minX,
                                height: chartFrame.height)
        let cornerRadius = diagramRadius * animationFraction
        let fadeOutFrame = CGRect.valueBetween(start: startFrame, end: targetFrame, offset: animationFractionD)
        let fadeOutPath = CGMutablePath()
        fadeOutPath.addRect(bounds)
        fadeOutPath.addPath(CGPath(roundedRect: fadeOutFrame, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        
        context.saveGState()
        context.beginPath()
        context.addPath(fadeOutPath)
        context.setFillColor(backgroundColor.cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }
}
