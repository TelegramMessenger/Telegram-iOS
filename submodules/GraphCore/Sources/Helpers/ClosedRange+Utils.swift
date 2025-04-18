//
//  ClosedRange+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

extension ClosedRange where Bound: Numeric {
    var distance: Bound {
        return upperBound - lowerBound
    }
}
