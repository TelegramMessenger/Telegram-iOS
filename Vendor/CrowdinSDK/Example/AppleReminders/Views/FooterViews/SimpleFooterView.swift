//
//  SimpleFooterView.swift
//  AppleReminders
//
//  Created by Josh R on 3/2/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class SimpleFooterView: UIView {
    
    lazy var textLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .left
        label.textColor = .label
        label.numberOfLines = 3
        label.backgroundColor = .clear
        
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(textLbl)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupConstraints() {
        textLbl.translatesAutoresizingMaskIntoConstraints = false
        
        textLbl.topAnchor.constraint(equalTo: self.topAnchor, constant: 6).isActive = true
        textLbl.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16).isActive = true
        textLbl.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -16).isActive = true
        self.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }
    
}
