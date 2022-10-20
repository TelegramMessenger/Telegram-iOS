//
//  UILabel+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/9/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

extension UILabel {
    func setTextColor(_ color: UIColor, animated: Bool) {
        if self.textColor != color {
            if animated {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = .defaultDuration
                self.layer.add(animation, forKey: "kCATransitionColorFade")
            }
            self.textColor = color
        }
    }
    
    func setText(_ title: String?, animated: Bool) {
        if self.text != title {
            if animated {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = .defaultDuration
                self.layer.add(animation, forKey: "kCATransitionTextFade")
            }
            self.text = title
        }
    }
}
