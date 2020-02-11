//
//  LineBulletsRenerer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class LineBulletsRenerer: BaseChartRenderer {
    struct Bullet {
        var coordinate: CGPoint
        var color: UIColor
    }
    
    var bullets: [Bullet] = [] {
        willSet {
            if alphaAnimators.count != newValue.count {
                alphaAnimators = newValue.map { _ in AnimationController<CGFloat>(current: 1.0, refreshClosure: refreshClosure) }
            }
        }
        didSet {
            setNeedsDisplay()
        }
    }
    private var alphaAnimators: [AnimationController<CGFloat>] = []
    
    private lazy var innerColorAnimator = AnimationController(current: UIColorContainer(color: .white), refreshClosure: refreshClosure)
    public func setInnerColor(_ color: UIColor, animated: Bool) {
        if animated {
            innerColorAnimator.animate(to: UIColorContainer(color: color), duration: .defaultDuration)
        } else {
            innerColorAnimator.set(current: UIColorContainer(color: color))
        }
    }

    var linesWidth: CGFloat = 2
    var bulletRadius: CGFloat = 6

    func setLineVisible(_ isVisible: Bool, at index: Int, animated: Bool) {
        alphaAnimators[index].animate(to: isVisible ? 1 : 0, duration: animated ? .defaultDuration : 0)
    }
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let generalAlpha = chartAlphaAnimator.current
        if generalAlpha == 0 { return }

        for (index, bullet) in bullets.enumerated() {
            let alpha = alphaAnimators[index].current
            if alpha == 0 { continue }

            let centerX = transform(toChartCoordinateHorizontal: bullet.coordinate.x, chartFrame: chartFrame)
            let centerY = transform(toChartCoordinateVertical: bullet.coordinate.y, chartFrame: chartFrame)
            context.setFillColor(innerColorAnimator.current.color.withAlphaComponent(alpha).cgColor)
            context.setStrokeColor(bullet.color.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(linesWidth)
            let rect = CGRect(x: centerX - bulletRadius / 2,
                              y: centerY - bulletRadius / 2,
                              width: bulletRadius,
                              height: bulletRadius)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        }
    }
}
