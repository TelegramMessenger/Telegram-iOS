//
//  BaseChartRenderer.swift
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

public protocol ChartViewRenderer: AnyObject {
    var containerViews: [GView] { get set }
    func render(context: CGContext, bounds: CGRect, chartFrame: CGRect)
}


private let exponentialAnimationTrashold: CGFloat = 100

class BaseChartRenderer: ChartViewRenderer {
    var containerViews: [GView] = []
    
    var optimizationLevel: CGFloat = 1 {
        didSet {
            setNeedsDisplay()
        }
    }
    var isEnabled: Bool = true {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private(set) lazy var chartAlphaAnimator: AnimationController<CGFloat> = {
        return AnimationController(current: 1, refreshClosure: self.refreshClosure)
    }()
    func setVisible(_ visible: Bool, animated: Bool) {
        let destinationValue: CGFloat = visible ? 1 : 0
        guard self.chartAlphaAnimator.end != destinationValue else { return }
        if animated {
            self.chartAlphaAnimator.animate(to: destinationValue, duration: .defaultDuration)
        } else {
            self.chartAlphaAnimator.set(current: destinationValue)
        }
    }
    
    lazy var horizontalRange = AnimationController<ClosedRange<CGFloat>>(current: 0...1, refreshClosure: refreshClosure)
    lazy var verticalRange = AnimationController<ClosedRange<CGFloat>>(current: 0...1, refreshClosure: refreshClosure)

    func setup(verticalRange: ClosedRange<CGFloat>, animated: Bool, timeFunction: TimeFunction? = nil) {        
        guard self.verticalRange.end != verticalRange else {
            self.verticalRange.timeFunction = timeFunction ?? .linear
            return
        }
        if animated {
            let function: TimeFunction = .easeInOut
//            if let timeFunction = timeFunction {
//                function = timeFunction
//            } else if self.verticalRange.current.distance > 0 && verticalRange.distance > 0 {
//                if self.verticalRange.current.distance / verticalRange.distance > exponentialAnimationTrashold {
//                    function = .easeIn
//                } else if verticalRange.distance / self.verticalRange.current.distance > exponentialAnimationTrashold {
//                    function = .easeOut
//                } else {
//                    function = .linear
//                }
//            } else {
//                function = .linear
//            }
            
            self.verticalRange.animate(to: verticalRange, duration: .defaultDuration, timeFunction: function)
        } else {
            self.verticalRange.set(current: verticalRange)
        }
    }
    
    func setup(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        guard self.horizontalRange.end != horizontalRange else { return }
        if animated {
            let animationCurve: TimeFunction = self.horizontalRange.current.distance > horizontalRange.distance ? .easeOut : .easeIn
            self.horizontalRange.animate(to: horizontalRange, duration: .defaultDuration, timeFunction: animationCurve)
        } else {
            self.horizontalRange.set(current: horizontalRange)
        }
    }
    
    func transform(toChartCoordinateHorizontal x: CGFloat, chartFrame: CGRect) -> CGFloat {
        return chartFrame.origin.x + (x - horizontalRange.current.lowerBound) / horizontalRange.current.distance * chartFrame.width
    }
    
    func transform(toChartCoordinateVertical y: CGFloat, chartFrame: CGRect) -> CGFloat {
        return chartFrame.height + chartFrame.origin.y - (y - verticalRange.current.lowerBound) / verticalRange.current.distance * chartFrame.height
    }
    
    func transform(toChartCoordinate point: CGPoint, chartFrame: CGRect) -> CGPoint {
        return CGPoint(x: transform(toChartCoordinateHorizontal: point.x, chartFrame: chartFrame),
                       y: transform(toChartCoordinateVertical: point.y, chartFrame: chartFrame))
    }
    
    func renderRange(bounds: CGRect, chartFrame: CGRect) -> ClosedRange<CGFloat> {
        let lowerBound = horizontalRange.current.lowerBound - chartFrame.origin.x / chartFrame.width * horizontalRange.current.distance
        let upperBound = horizontalRange.current.upperBound + (bounds.width - chartFrame.width - chartFrame.origin.x) / chartFrame.width * horizontalRange.current.distance
        guard lowerBound <= upperBound else {
            print("Error: Unexpecated bounds range!")
            return 0...1
        }
        return lowerBound...upperBound
    }
    
    func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        fatalError("abstract")
    }
    
    func setNeedsDisplay() {
        containerViews.forEach { $0.setNeedsDisplay($0.bounds) }
    }
    
    var refreshClosure: () -> Void {
        return { [weak self] in
            self?.setNeedsDisplay()
        }
    }
}
