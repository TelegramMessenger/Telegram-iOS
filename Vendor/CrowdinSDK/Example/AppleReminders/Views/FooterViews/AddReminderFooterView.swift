//
//  AddReminderFooterView.swift
//  AppleReminders
//
//  Created by Josh R on 7/12/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class AddReminderFooterView: UITableViewHeaderFooterView {
    
    static let reuseIdentifier = "AddReminderFooterView"
    static let height: CGFloat = 40
    
    var passReminderText:((String?) -> Void)?
    
    var reminderListID: String?
    var sectionDateString: String?
    
    lazy var addBtn: UIButton = {
        let button = UIButton()
        let btnImage = UIImage(systemName: "plus.circle.fill")
        button.setBackgroundImage(btnImage, for: .normal)
        button.tintColor = .darkGray
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(addBtnTapped), for: .touchUpInside)
        
        return button
    }()
    
    @objc func addBtnTapped() {
        passReminderText?(reminderTxtBox.text)
        reminderTxtBox.text?.removeAll()
    }
    
    lazy var reminderTxtBox: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = .label
        textField.textAlignment = .left
        textField.backgroundColor = .clear
        textField.setPadding(left: 4, right: 4)
        
        return textField
    }()
    
    lazy var separator: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        
        return view
    }()
    
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        setupViews()
        
        self.contentView.backgroundColor = .systemBackground
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func setupViews() {
        contentView.addSubview(addBtn)
        contentView.addSubview(reminderTxtBox)
        contentView.addSubview(separator)
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        reminderTxtBox.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            addBtn.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 8),
            addBtn.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            addBtn.heightAnchor.constraint(equalToConstant: 25),
            addBtn.widthAnchor.constraint(equalToConstant: 25),
            
            reminderTxtBox.leadingAnchor.constraint(equalTo: addBtn.trailingAnchor, constant: 5),
            reminderTxtBox.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -12),
            reminderTxtBox.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 1),
            reminderTxtBox.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: 1),
            
            separator.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 0),
            separator.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 0),
            separator.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: 0),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    
}
