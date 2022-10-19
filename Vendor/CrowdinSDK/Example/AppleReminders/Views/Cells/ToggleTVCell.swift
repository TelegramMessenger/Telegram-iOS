//
//  ToggleTVCell.swift
//  AppleReminders
//
//  Created by Josh R on 2/29/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class ToggleTVCell: UITableViewCell {

    static let identifier = "ToggleTVCell"
    
    var switchToggleAction: ((ToggleTVCell) -> Void)?
    
    lazy var descriptionLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .label
        
        return label
    }()
    
    lazy var switchToggle: UISwitch = {
        let toggleSwitch = UISwitch()
        toggleSwitch.tintColor = .systemGreen
        toggleSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
        
        return toggleSwitch
    }()
    
    @objc func switchToggled() {
        switchToggleAction?(self)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .secondarySystemGroupedBackground
        
        self.addSubview(descriptionLbl)
        self.addSubview(switchToggle)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupConstraints() {
        descriptionLbl.translatesAutoresizingMaskIntoConstraints = false
        switchToggle.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionLbl.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
        descriptionLbl.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
        descriptionLbl.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16).isActive = true
        descriptionLbl.trailingAnchor.constraint(equalTo: switchToggle.leadingAnchor,constant: -5).isActive = true
        
        switchToggle.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -8).isActive = true
        switchToggle.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    func setupToggleTVCell(with descText: String, isSwitchOn: Bool) {
        descriptionLbl.text = descText
        switchToggle.isOn = isSwitchOn
    }

}
