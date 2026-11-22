//
//  ChartLineData.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

struct ChartLineData {
    var title: String
    var color: GColor
    var width: CGFloat?
    var points: [CGPoint]
}

extension ChartLineData {
    static func horizontalRange(lines: [ChartLineData]) -> ClosedRange<CGFloat>? {
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
    
    static func verticalRange(lines: [ChartLineData], calculatingRange: ClosedRange<CGFloat>? = nil, addBounds: Bool = false) -> ClosedRange<CGFloat>? {
        if let calculatingRange = calculatingRange {
            guard let initalStart = lines.first?.points.first(where: { $0.x > calculatingRange.lowerBound &&
                                                                       $0.x < calculatingRange.upperBound }) else { return nil }
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
            return vMin...vMax
        }
    }
}
