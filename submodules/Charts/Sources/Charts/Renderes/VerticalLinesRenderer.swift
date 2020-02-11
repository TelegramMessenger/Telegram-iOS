//
//  VerticalLinesRenderer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class VerticalLinesRenderer: BaseChartRenderer {
    var values: [CGFloat] = [] {
        didSet {
            alphaAnimators = values.map { _ in AnimationController<CGFloat>(current: 1.0, refreshClosure: refreshClosure) }
            setNeedsDisplay()
        }
    }
    private var alphaAnimators: [AnimationController<CGFloat>] = []
    
    var linesColor: UIColor = .black
    var linesWidth: CGFloat = UIView.oneDevicePixel
    
    func setLineVisible(_ isVisible: Bool, at index: Int, animated: Bool) {
        alphaAnimators[index].animate(to: isVisible ? 1 : 0, duration: animated ? .defaultDuration : 0)
    }
    
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        
        context.setLineWidth(linesWidth)

        for (index, value) in values.enumerated() {
            let alpha = alphaAnimators[index].current
            if alpha == 0 { continue }

            context.setStrokeColor(linesColor.withAlphaComponent(linesColor.alphaValue * alpha).cgColor)
            let pointX = transform(toChartCoordinateHorizontal: value, chartFrame: chartFrame)
            context.strokeLineSegments(between: [CGPoint(x: pointX, y: chartFrame.minY),
                                                 CGPoint(x: pointX, y: chartFrame.maxY)])
        }
    }
}
