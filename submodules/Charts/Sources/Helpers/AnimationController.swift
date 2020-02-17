//
//  RangeAnimatedContainer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/12/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

protocol Animatable {
    static func valueBetween(start: Self, end: Self, offset: Double) -> Self
}

enum TimeFunction {
    case linear
    case easeOut
    case easeIn
    
    func profress(time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        switch self {
        case .linear:
            return time / duration
        case .easeIn:
            return (pow(2, 10 * (time / duration - 1)) - 0.0009765625) * 1.0009775171065499
            
        case .easeOut:
            return (-pow(2, -10 * time / duration)) + 1 * 1.0009775171065499
        }
    }
}

class AnimationController<AnimatableObject: Animatable> {
    
    private(set) var isAnimating: Bool = false
    private(set) var animationDuration: TimeInterval = 0.0
    private(set) var currentTime: TimeInterval = 0.0

    private(set) var start: AnimatableObject
    private(set) var end: AnimatableObject
    private(set) var current: AnimatableObject
    
    var timeFunction: TimeFunction = .linear

    var refreshClosure: (() -> Void)?
//    var updateClosure: ((AnimatableObject) -> Void)?
    var completionClosure: (() -> Void)?

    init(current: AnimatableObject, refreshClosure: (() -> Void)?) {
        self.current = current
        self.start = current
        self.end = current
        self.refreshClosure = refreshClosure
    }
    
    func animate(to: AnimatableObject, duration: TimeInterval, timeFunction: TimeFunction = .linear) {
        self.timeFunction = timeFunction
        currentTime = 0
        animationDuration = duration
        if animationDuration > 0 {
            start = current
            end = to
            isAnimating = true
            DisplayLinkService.shared.add(listner: self)
        } else {
            start = to
            end = to
            current = to
            isAnimating = false
            DisplayLinkService.shared.remove(listner: self)
        }
        refreshClosure?()
    }
    
    func set(current: AnimatableObject) {
        self.start = current
        self.end = current
        self.current = current
        
        animationDuration = 0.0
        currentTime = 0.0
//        updateClosure?(current)
        refreshClosure?()
        if isAnimating {
            isAnimating = false
            DisplayLinkService.shared.remove(listner: self)
        }
    }
}

extension AnimationController: DisplayLinkListner {
    func update(delta: TimeInterval) {
        guard isAnimating else {
            DisplayLinkService.shared.remove(listner: self)
            return
        }
        
        currentTime += delta
        if currentTime > animationDuration || animationDuration <= 0 {
            start = end
            current = end
            isAnimating = false
            animationDuration = 0.0
            currentTime = 0.0
//            updateClosure?(end)
            completionClosure?()
            refreshClosure?()
            DisplayLinkService.shared.remove(listner: self)
        } else {
            let offset = timeFunction.profress(time: currentTime, duration: animationDuration)
            current = AnimatableObject.valueBetween(start: start, end: end, offset: offset)
//            updateClosure?(current)
            refreshClosure?()
        }
    }
}

extension ClosedRange: Animatable where Bound: BinaryFloatingPoint {
    static func valueBetween(start: ClosedRange<Bound>, end: ClosedRange<Bound>, offset: Double) -> ClosedRange<Bound> {
        let castedOffset = Bound(offset)
        return ClosedRange(uncheckedBounds: (lower: start.lowerBound + (end.lowerBound - start.lowerBound) * castedOffset,
                                             upper: start.upperBound + (end.upperBound - start.upperBound) * castedOffset))
    }
}

extension CGFloat: Animatable {
    static func valueBetween(start: CGFloat, end: CGFloat, offset: Double) -> CGFloat {
        return start + (end - start) * CGFloat(offset)
    }
}

extension Double: Animatable {
    static func valueBetween(start: Double, end: Double, offset: Double) -> Double {
        return start + (end - start) * Double(offset)
    }
}

extension Int: Animatable {
    static func valueBetween(start: Int, end: Int, offset: Double) -> Int {
        return start + Int(Double(end - start) * offset)
    }
}

extension CGPoint: Animatable {
    static func valueBetween(start: CGPoint, end: CGPoint, offset: Double) -> CGPoint {
        return CGPoint(x: start.x + (end.x - start.x) * CGFloat(offset),
                       y: start.y + (end.y - start.y) * CGFloat(offset))
    }
}

extension CGRect: Animatable {
    static func valueBetween(start: CGRect, end: CGRect, offset: Double) -> CGRect {
        return CGRect(x: start.origin.x + (end.origin.x - start.origin.x) * CGFloat(offset),
                      y: start.origin.y + (end.origin.y - start.origin.y) * CGFloat(offset),
                      width: start.width + (end.width - start.width) * CGFloat(offset),
                      height: start.height + (end.height - start.height) * CGFloat(offset))
    }
}

struct UIColorContainer: Animatable {
    var color: UIColor
    
    static func valueBetween(start: UIColorContainer, end: UIColorContainer, offset: Double) -> UIColorContainer {
        return UIColorContainer(color: UIColor.valueBetween(start: start.color, end: end.color, offset: offset))
    }
}

extension UIColor {
    static func valueBetween(start: UIColor, end: UIColor, offset: Double) -> UIColor {
        let offsetF = CGFloat(offset)
        let startCIColor = CIColor(color: start)
        let endCIColor = CIColor(color: end)
        return UIColor(red: startCIColor.red + (endCIColor.red - startCIColor.red) * offsetF,
                       green: startCIColor.green + (endCIColor.green - startCIColor.green) * offsetF,
                       blue: startCIColor.blue + (endCIColor.blue - startCIColor.blue) * offsetF,
                       alpha: startCIColor.alpha + (endCIColor.alpha - startCIColor.alpha) * offsetF)
    }
}
