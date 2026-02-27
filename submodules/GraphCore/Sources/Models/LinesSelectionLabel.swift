//
//  LinesSelectionLabel.swift
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

struct LinesSelectionLabel {
    let coordinate: CGPoint
    let valueText: String
    let color: GColor
}
