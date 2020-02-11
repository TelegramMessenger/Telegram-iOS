//
//  NumberFormatter+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/12/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

extension NumberFormatter {
    func string(from value: CGFloat) -> String {
        return string(from: Double(value))
    }

    func string(from value: Double) -> String {
        return string(from: NSNumber(value: Double(value))) ?? ""
    }
}
