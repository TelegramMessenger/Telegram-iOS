//
//  UIView+Extensions.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/10/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

extension UIView {
    static let oneDevicePixel: CGFloat = (1.0 / max(2, min(1, UIScreen.main.scale)))
}

// MARK: UIView+Animation
public extension UIView {
    func bringToFront() {
        superview?.bringSubviewToFront(self)
    }
    
    func layoutIfNeeded(animated: Bool) {
        UIView.perform(animated: animated) {
            self.layoutIfNeeded()
        }
    }
    
    func setVisible(_ visible: Bool, animated: Bool) {
        let updatedAlpha: CGFloat = visible ? 1 : 0
        if self.alpha != updatedAlpha {
            UIView.perform(animated: animated) {
                self.alpha = updatedAlpha
            }
        }
    }
    
    static func perform(animated: Bool, animations: @escaping () -> Void) {
        perform(animated: animated, animations: animations, completion: { _ in })
    }
    
    static func perform(animated: Bool, animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        if animated {
            
            UIView.animate(withDuration: .defaultDuration, delay: 0, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
    
    var isVisibleInWindow: Bool {
        guard let windowBounds = window?.bounds else {
            return false
        }
        let frame = convert(bounds, to: nil)
        return frame.intersects(windowBounds)
    }
}
