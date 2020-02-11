//
//  CustomNavigationController.swift
//  GraphTest
//
//  Created by Andrew Solovey on 15/03/2019.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class CustomNavigationController: UINavigationController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return topViewController?.preferredStatusBarStyle ?? .default
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return topViewController?.preferredStatusBarUpdateAnimation ?? .fade
    }
}
