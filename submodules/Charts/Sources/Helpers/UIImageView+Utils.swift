//
//  UIImageView+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/9/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

extension UIImageView {
    func setImage(_ image: UIImage?, animated: Bool) {
        if self.image != image {
            if animated {
                let animation = CATransition()
                animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
                animation.type = .fade
                animation.duration = .defaultDuration
                self.layer.add(animation, forKey: "kCATransitionImageFade")
            }
            self.image = image
        }
    }
}
