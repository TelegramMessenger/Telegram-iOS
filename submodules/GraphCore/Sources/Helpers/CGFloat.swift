//
//  CGFloat.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif


extension CGFloat {
    func roundedUpToPixelGrid() -> CGFloat {
        return (self * deviceScale).rounded(.up) / deviceScale
    }
}
