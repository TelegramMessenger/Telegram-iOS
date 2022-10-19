//
//  SubtaskCell.swift
//  AppleReminders
//
//  Created by Josh R on 4/22/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift

class SubtaskCell: UITableViewCell {

    let realm = MyRealm.getConfig()
    
    static let identifier = "SubtaskCell"
    
    var passParentReminder: ((Reminder?) -> Void)?

    var parentReminder: Reminder?
    var reminder: Reminder? {
        didSet {
            configureViews()
            
            print("Reminder name: \(String(describing: reminder?.name))")
            
            if reminder?.name == "" {
                nameTxtBox.delegate = self
            } else {
                nameTxtBox.text = reminder?.name
            }
        }
    }
    
    var checkBoxColorString: String?  //set from ReminderListRealm object from ReminderListVC

    lazy var completedBtn: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage(systemName: "circle"), for: .normal)
        button.backgroundColor = .clear
        button.tintColor = .systemGray
        button.addTarget(self, action: #selector(completedBtnTapped), for: .touchUpInside)
        return button
    }()
    
    @objc func completedBtnTapped() {
        try! realm?.write {
            reminder?.isCompleted.toggle()
        }
    }
    
    let separatorView = UIView()
    
    lazy var nameTxtBox: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = .label
        textField.textAlignment = .left
        textField.backgroundColor = .clear
        textField.setPadding(left: 4, right: 4)
        
        return textField
    }()
    
    lazy var addReminderLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.text = "Add Reminder".localized
        label.textColor = .systemBlue
        
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        addViewsToCell(views: completedBtn, nameTxtBox, addReminderLbl, separatorView)
        separatorView.backgroundColor = .lightGray
        
        //hide addReminder lbl
        addReminderLbl.isHidden = true
        
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addViewsToCell(views: UIView...) {
        views.forEach({ self.contentView.addSubview($0) })
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        completedBtn.translatesAutoresizingMaskIntoConstraints = false
        nameTxtBox.translatesAutoresizingMaskIntoConstraints = false
        addReminderLbl.translatesAutoresizingMaskIntoConstraints = false
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        
        completedBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5).isActive = true
        completedBtn.heightAnchor.constraint(equalToConstant: 25).isActive = true
        completedBtn.widthAnchor.constraint(equalToConstant: 25).isActive = true
        completedBtn.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        nameTxtBox.leadingAnchor.constraint(equalTo: completedBtn.trailingAnchor, constant: 5).isActive = true
        nameTxtBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor,constant: -8).isActive = true
        nameTxtBox.heightAnchor.constraint(equalToConstant: self.frame.height - 5).isActive = true
        nameTxtBox.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        addReminderLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + 25 + 5).isActive = true
        addReminderLbl.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
        separatorView.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
    }
    
    func configureAddReminderCell() {
        completedBtn.isHidden = true
        nameTxtBox.isHidden = true
        addReminderLbl.isHidden = false
    }
    
    func configureViews() {
        completedBtn.isHidden = false
        nameTxtBox.isHidden = false
        addReminderLbl.isHidden = true
    }
    
    private func configureCompletedBtn(with reminder: Reminder?) {
        let completedBtnImgString = reminder?.isCompleted ?? false ? UIImage(systemName: "largecircle.fill.circle") : UIImage(systemName: "circle")
        completedBtn.setBackgroundImage(completedBtnImgString, for: .normal)
        completedBtn.tintColor = reminder?.listColor
    }
    
    func configure() {
        guard let reminder = reminder else { return }
        
        configureCompletedBtn(with: reminder)
    }
}

extension SubtaskCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let reminder = reminder else { return false }
        
        if textField.text == "" {
            if let reminderIndex = parentReminder?.subtasks.firstIndex(where: { $0.reminderID == reminder.reminderID }) {
                parentReminder?.subtasks.remove(at: reminderIndex)
            }
        } else {
            //Add todo
            reminder.name = textField.text!
            parentReminder?.subtasks.append(reminder)
        }
        
        self.reminder = nil
        passParentReminder?(parentReminder)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let enteredReminderName = textField.text else { return }
        reminder?.name = enteredReminderName
    }
}
