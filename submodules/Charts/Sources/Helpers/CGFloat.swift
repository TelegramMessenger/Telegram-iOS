//
//  CGFloat.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

private let screenScale: CGFloat = UIScreen.main.scale

extension CGFloat {
    func roundedUpToPixelGrid() -> CGFloat {
        return (self * screenScale).rounded(.up) / screenScale
    }
}
