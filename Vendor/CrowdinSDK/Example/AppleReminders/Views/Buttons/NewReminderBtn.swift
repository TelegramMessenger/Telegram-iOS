//
//  NewReminderBtn.swift
//  AppleReminders
//
//  Created by Josh R on 1/31/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class NewReminderBtn: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configure() {
        self.setTitle("New Reminder".localized, for: .normal)
        self.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        self.backgroundColor = .clear
        let plusImgConfig = UIImage.SymbolConfiguration(weight: .bold)
        let plusImg = UIImage(systemName: "plus.circle.fill", withConfiguration: plusImgConfig)
        
        self.tintColor = .white
        self.setImage(plusImg, for: .normal)
    }
}
