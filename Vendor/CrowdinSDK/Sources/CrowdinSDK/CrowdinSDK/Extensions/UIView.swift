//
//  UIView.swift
//  CrowdinSDK
//
//  Created by Nazar Yavornytskyy on 3/27/21.
//

import UIKit

// MARK: - Custom view presentation and dismissing.
public extension UIView {
    
    @objc func cw_present() {
        guard let window = UIApplication.shared.windows.last else {
            return
        }

        window.addSubview(self)
    }
}
