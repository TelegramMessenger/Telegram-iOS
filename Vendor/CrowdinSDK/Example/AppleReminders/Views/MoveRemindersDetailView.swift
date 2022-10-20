//
//  MoveRemindersDetailView.swift
//  AppleReminders
//
//  Created by Josh R on 7/25/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class MoveRemindersDetailView: UIView {
    
    lazy var reminderDescLbl: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .label
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.minimumScaleFactor = 0.5
        label.backgroundColor = .clear
        
        return label
    }()
    
    lazy var descLbl: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "Move these reminders to a new list".localized
        label.textColor = .label
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.numberOfLines = 1
        label.backgroundColor = .clear
        
        return label
    }()
    
    let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 1
        sv.distribution = .fill
        
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .systemBackground
        
        stackView.addArrangedSubview(reminderDescLbl)
        stackView.addArrangedSubview(descLbl)
        
        self.addSubview(stackView)
        setConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setConstraints() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 50),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -50),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
        ])
    }
}
