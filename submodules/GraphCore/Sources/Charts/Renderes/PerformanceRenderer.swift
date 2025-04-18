//
//  PerformanceRenderer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/10/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

class PerformanceRenderer: ChartViewRenderer {
    var containerViews: [GView] = []
    
    private var previousTickTime: TimeInterval = CACurrentMediaTime()

    func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        let currentTime = CACurrentMediaTime()
        let delta = currentTime - previousTickTime
        previousTickTime = currentTime
        
        let normalDelta = 0.017
        let redDelta = 0.05
        
        if delta > normalDelta || delta < 0.75 {
            let green = CGFloat( 1.0 - crop(0, (delta - normalDelta) / (redDelta - normalDelta), 1))
            let color = GColor(red: 1.0, green: green, blue: 0, alpha: 1)
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 3))
        }
    }
}
