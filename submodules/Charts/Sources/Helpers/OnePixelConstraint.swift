//
//  OnePixelConstraint.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

public class OnePixelConstrain: NSLayoutConstraint {
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        constant = UIView.oneDevicePixel
    }
}
