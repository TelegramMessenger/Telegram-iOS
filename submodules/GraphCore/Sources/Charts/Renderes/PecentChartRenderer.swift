//
//  PecentChartRenderer.swift
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

class PecentChartRenderer: BaseChartRenderer {
    struct PercentageData {
        static let blank = PecentChartRenderer.PercentageData(locations: [], components: [])
        var locations: [CGFloat]
        var components: [Component]
        
        struct Component {
            var color: GColor
            var values: [CGFloat]
        }
    }
    
    override func setup(verticalRange: ClosedRange<CGFloat>, animated: Bool, timeFunction: TimeFunction? = nil) {
        super.setup(verticalRange: 0...1, animated: animated, timeFunction: timeFunction)
    }
    
    private var componentsAnimators: [AnimationController<CGFloat>] = []
    var percentageData: PercentageData = PercentageData(locations: [], components: []) {
        willSet {
            if percentageData.components.count != newValue.components.count {
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
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let alpha = chartAlphaAnimator.current
        guard alpha > 0 else { return }
        
        let range = renderRange(bounds: bounds, chartFrame: chartFrame)
        
        let paths: [CGMutablePath] = percentageData.components.map { _ in CGMutablePath() }
        var vertices: [CGFloat] = Array<CGFloat>(repeating: 0, count: percentageData.components.count)

        if var locationIndex = percentageData.locations.firstIndex(where: { $0 > range.lowerBound }) {
            locationIndex = max(0, locationIndex - 1)
            
            var currentLocation = transform(toChartCoordinateHorizontal: percentageData.locations[locationIndex], chartFrame: chartFrame)

            let startPoint = CGPoint(x: currentLocation,
                                     y: transform(toChartCoordinateVertical: verticalRange.current.lowerBound, chartFrame: chartFrame))
            
            for path in paths {
                path.move(to: startPoint)
            }
            paths.last?.addLine(to: CGPoint(x: currentLocation,
                                            y: transform(toChartCoordinateVertical: verticalRange.current.upperBound, chartFrame: chartFrame)))

            while locationIndex < percentageData.locations.count {
                currentLocation = transform(toChartCoordinateHorizontal: percentageData.locations[locationIndex], chartFrame: chartFrame)
                var summ: CGFloat = 0
                
                for (index, component) in percentageData.components.enumerated() {
                    let visibilityPercent = componentsAnimators[index].current
                    
                    let value = component.values[locationIndex] * visibilityPercent
                    if index == 0 {
                        vertices[index] = value
                    } else {
                        vertices[index] = value + vertices[index - 1]
                    }
                    summ += value
                }
                
                if summ > 0 {
                    for (index, value) in vertices.dropLast().enumerated() {
                        paths[index].addLine(to: CGPoint(x: currentLocation,
                                                         y: transform(toChartCoordinateVertical: value / summ, chartFrame: chartFrame)))
                    }
                }
                
                if currentLocation > range.upperBound {
                    break
                }
                
                locationIndex += 1
            }
            
            paths.last?.addLine(to: CGPoint(x: currentLocation,
                                            y: transform(toChartCoordinateVertical: verticalRange.current.upperBound, chartFrame: chartFrame)))

            let endPoint = CGPoint(x: currentLocation,
                                   y: transform(toChartCoordinateVertical: verticalRange.current.lowerBound, chartFrame: chartFrame))
            
            for (index, path) in paths.enumerated().reversed() {
                let visibilityPercent = componentsAnimators[index].current
                if visibilityPercent == 0 { continue }

                path.addLine(to: endPoint)
                path.closeSubpath()
                
                context.saveGState()
                context.beginPath()
                context.addPath(path)
                
                context.setFillColor(percentageData.components[index].color.cgColor)
                context.fillPath()
                context.restoreGState()
            }
        }
    }
}

extension PecentChartRenderer.PercentageData {
    static func horizontalRange(data: PecentChartRenderer.PercentageData) -> ClosedRange<CGFloat>? {
        guard let firstPoint = data.locations.first,
            let lastPoint = data.locations.last,
            firstPoint <= lastPoint else {
                return nil
        }
        
        return firstPoint...lastPoint
    }
}
