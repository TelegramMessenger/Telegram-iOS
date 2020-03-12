//
//  LinesChartLabel.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/18/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

struct LinesChartLabel: Hashable {
    let value: CGFloat
    let text: String
}

class AnimatedLinesChartLabels {
    var labels: [LinesChartLabel]
    var isAppearing: Bool = false
    let alphaAnimator: AnimationController<CGFloat>
    
    init(labels: [LinesChartLabel], alphaAnimator: AnimationController<CGFloat>) {
        self.labels = labels
        self.alphaAnimator = alphaAnimator
    }
}
