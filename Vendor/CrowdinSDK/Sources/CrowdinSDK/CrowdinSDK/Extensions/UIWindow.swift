//
//  UIWindow.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/14/19.
//

import UIKit

// MARK: - Extension for window screenshot creation.
extension UIView {
    /// Current window screenshot.
    var screenshot: UIImage? {
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(self.frame.size, true, scale)
        defer { UIGraphicsEndImageContext() }
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
