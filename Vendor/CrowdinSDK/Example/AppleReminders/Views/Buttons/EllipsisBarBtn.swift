//
//  EllipsisBarBtn.swift
//  AppleReminders
//
//  Created by Josh R on 2/11/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class EllipsisBtn: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configure() {
        let ellipsisImg = UIImage(systemName: "ellipsis")
        self.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        self.backgroundColor = .systemGray5
        self.setImage(ellipsisImg, for: .normal)
        self.layer.cornerRadius = self.frame.height / 2
    }
    
}
