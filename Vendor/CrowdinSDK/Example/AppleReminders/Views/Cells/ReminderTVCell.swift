//
//  ReminderTVCell.swift
//  AppleReminders
//
//  Created by Josh R on 1/30/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift


protocol ReminderTVCellDelegate: class {
    func cellTapped(reminder: Reminder?)
}

class ReminderTVCell: UITableViewCell {
    
    let realm = MyRealm.getConfig()
    
    static let identifier = "ReminderTVCell"
    
    weak var delegate: ReminderTVCellDelegate?
    var cellExpand: (() ->Void)?
    
    var reminderDatasourceFilter: ReminderListTVC.VCType?
    
    var reminder: Reminder? {
        didSet {
            guard let reminder = reminder, let reminderDatasourceFilter = reminderDatasourceFilter else { return }
            nameTxtBox.text = reminder.name
            dueDateLbl.text = reminder.isTimeDueDate ? reminder.dueDate?.formatDateMMMMddyyyyWithTime() :reminder.dueDate?.formatDateMdyyyy()
            dueDateLbl.textColor = reminder.dueDate ?? Date() < Date() ? .systemRed : .label
            
            let completedBtnImgString = reminder.isCompleted ? UIImage(systemName: "largecircle.fill.circle") : UIImage(systemName: "circle")
            completedBtn.setBackgroundImage(completedBtnImgString, for: .normal)
            completedBtn.tintColor = reminder.isCompleted ? reminder.listColor : .systemGray3
            
            flagIconImgView.isHidden = reminder.isFlagged ? false : true
            
            //Subtask count lbl
            if reminder.subtasks.count > 0 && reminder.isExpanded == false {
                subtaskCountLbl.isHidden = false
                subtaskCountLbl.text = String(reminder.subtasks.count)
            } else {
                subtaskCountLbl.isHidden = true
            }
            
            //Chevron to indicate todo has subtasks
            switch reminderDatasourceFilter {
            case .today, .flagged:
                chevronBtn.isHidden = true
            default:
                if reminder.subtasks.count > 0 {
                    chevronBtn.isHidden = false
                    if reminder.isExpanded {
                        chevronBtn.transform = CGAffineTransform(rotationAngle: Conversions.convertRadiansToDegrees(90))
                    } else {
                        chevronBtn.transform = .identity
                    }
                } else {
                    chevronBtn.isHidden = true
                    detailDisclosureBtn.isHidden = true
                }
            }
            
            //Priority set
            let priority = Reminder.Priority.init(rawValue: reminder.priority) ?? .none
            priorityLbl.isHidden = priority == .none ? true : false
            priorityLbl.text = priority == .none ? "" : priority.description
            priorityLbl.textColor = reminder.listColor
            
            
            //Set up Action views -- Location, Messaging -- hide views first
            self.locationActionView.isHidden = true
            self.urlActionView.isHidden = true
            self.messagingActionView.isHidden = true
            
            if reminder.isVehicleAction {
                self.locationActionView.isHidden = false
                self.locationActionView.iconType = .car
                self.locationActionView.titleLabel.text = Reminder.LocationVehicleAction(rawValue: reminder.locationVehicleAction ?? "")?.description
            }
            
            if let reminderUrl = reminder.url {
                if !reminderUrl.isEmpty {
                    urlActionView.passedReminder = reminder
                    self.urlActionView.isHidden = false
                    self.urlActionView.iconType = .webURL
                    self.urlActionView.titleLabel.text = reminderUrl
                }
            }
            
            if reminder.isLocationReminder {
                self.locationActionView.isHidden = false
                self.locationActionView.iconType = .location
                self.locationActionView.titleLabel.text = "Location".localized
            }
            
            //I check with count because I assign "TEMP" when user is editing or creating a todo
            if reminder.contactID.count > 0 {
                let retrievedContact = reminder.retrieveContact!
                self.messagingActionView.isHidden = false
                self.messagingActionView.iconType = .contact
                self.messagingActionView.passedContact = retrievedContact
                self.messagingActionView.titleLabel.text = "Messaging: \(retrievedContact.givenName) \(retrievedContact.familyName)"
                
                //Setup Contact Img
                if retrievedContact.imageDataAvailable {
                    self.messagingActionView.iconTextLbl.isHidden = true
                    self.messagingActionView.iconImgView.isHidden = false
                    self.messagingActionView.iconImgView.image = UIImage(data: retrievedContact.thumbnailImageData ?? Data())
                } else {
                    self.messagingActionView.iconTextLbl.isHidden = false
                    self.messagingActionView.iconImgView.isHidden = true
                    self.messagingActionView.iconTextLbl.text = "\(retrievedContact.givenName.first!)\(retrievedContact.familyName.first!)"
                }
            }
            
            setupViewConstraint()
        }
    }
    
    //MARK:  Cell constraints
    var cellViewConstraints: [NSLayoutConstraint] = [] {
        willSet { NSLayoutConstraint.deactivate(cellViewConstraints) }
        didSet { NSLayoutConstraint.activate(cellViewConstraints) }
    }
    
    lazy var completedBtn: UIButton = {
        let button = UIButton()
        button.setBackgroundImage(UIImage(systemName: "circle"), for: .normal)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(self.completedBtnTapped), for: .touchUpInside)
        return button
    }()
    
    @objc func completedBtnTapped() {
        try! realm?.write {
            reminder?.toggleReminderCompletion
        }
    }
    
    let separatorView = UIView()
    
    lazy var nameTxtBox: UITextField = {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = .label
        textField.textAlignment = .left
        textField.backgroundColor = .clear
        textField.setPadding(left: 2, right: 4)
        
        return textField
    }()
    
    lazy var priorityLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemRed
        label.backgroundColor = .clear
        label.textAlignment = .left
        label.sizeToFit()
        
        return label
    }()
    
    let priorityAndNameSV: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 1
        sv.distribution = .fill
        sv.alignment = .leading
        
        return sv
    }()
    
    lazy var dueDateLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemGray
        label.backgroundColor = .clear
        label.textAlignment = .left
        label.sizeToFit()
        
        return label
    }()
    
    lazy var locationActionView: ReminderActionView = {
        let view = ReminderActionView()
        view.iconType = .location
        
        return view
    }()
    
    lazy var urlActionView: ReminderActionView = {
        let view = ReminderActionView()
        view.iconType = .webURL
        
        return view
    }()
    
    lazy var messagingActionView: ReminderActionView = {
        let view = ReminderActionView()
        view.iconType = .contact
        
        return view
    }()
    
    
    let reminderDetailsSV: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 4
        sv.distribution = .fill
        sv.alignment = .leading  //FINALLY, this allows the labels to autofit to their intrinsic content size
        
        return sv
    }()
    
    lazy var flagIconImgView: UIImageView = {
        let imgView = UIImageView()
        imgView.image = UIImage(systemName: "flag.fill")
        imgView.tintColor = .systemGray
        imgView.contentMode = .scaleAspectFit
        
        return imgView
    }()
    
    lazy var subtaskCountLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = .label
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.baselineAdjustment = .alignCenters
        label.sizeToFit()
        
        return label
    }()
    
    lazy var chevronBtn: UIButton = {
        let button = UIButton()
        button.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        button.setBackgroundImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.tintColor = .systemGray3
        button.addTarget(self, action: #selector(self.chevronBtnTapped), for: .touchUpInside)
        return button
    }()
    
    @objc func chevronBtnTapped() {
        reminder?.toggleExpand()
        cellExpand?()
    }
    
    //Only shown when user is editing the name of the todo
    lazy var detailDisclosureBtn: UIButton = {
        let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
        button.addTarget(self, action: #selector(self.detailBtnTapped), for: .touchUpInside)
        
        return button
    }()
    
    @objc func detailBtnTapped() {
        self.nameTxtBox.resignFirstResponder()
        delegate?.cellTapped(reminder: reminder)
    }
    
    //Flag, subtask count lbl, chevron, and disclosure indicator
    let buttonSV: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 4
        sv.distribution = .fill
        sv.alignment = .center
        
        return sv
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setupSV()
        addViewsToCell(views: completedBtn, reminderDetailsSV, buttonSV, separatorView)
        setupViewConstraint()
        configure()
        
        self.backgroundColor = .systemBackground
        nameTxtBox.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.indentationLevel = 0
        
        self.selectionStyle = self.isEditing ? .default : .none
        completedBtn.isHidden = self.isEditing ? true : false
        nameTxtBox.isEnabled = self.isEditing ? false : true
        //        accessoryImageView.isHidden = self.isEditing ? true : false
        
        setupViewConstraint()
    }
    
    private func setupSV() {
        priorityAndNameSV.addArrangedSubview(priorityLbl)
        priorityAndNameSV.addArrangedSubview(nameTxtBox)
        
        reminderDetailsSV.addArrangedSubview(priorityAndNameSV)
        reminderDetailsSV.addArrangedSubview(dueDateLbl)
        reminderDetailsSV.addArrangedSubview(locationActionView)
        reminderDetailsSV.addArrangedSubview(urlActionView)
        reminderDetailsSV.addArrangedSubview(messagingActionView)
        
        buttonSV.addArrangedSubview(flagIconImgView)
        buttonSV.addArrangedSubview(subtaskCountLbl)
        buttonSV.addArrangedSubview(chevronBtn)
        buttonSV.addArrangedSubview(detailDisclosureBtn)
        
        detailDisclosureBtn.isHidden = true
    }
    
    private func addViewsToCell(views: UIView...) {
        views.forEach({ self.contentView.addSubview($0) })
        
        completedBtn.translatesAutoresizingMaskIntoConstraints = false
        reminderDetailsSV.translatesAutoresizingMaskIntoConstraints = false
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        buttonSV.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupViewConstraint() {
        var indentLevel: CGFloat = 0
        
        if let reminder = reminder, let reminderDatasourceFilter = reminderDatasourceFilter {
            switch reminderDatasourceFilter {
            case .today, .flagged, .search(_):  //NOT indented
                indentLevel = 0
            default:
                indentLevel = reminder.isSubtask ? 20 : 0
            }
        }
        
        cellViewConstraints = [
            completedBtn.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 8),
            completedBtn.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 8 + indentLevel),
            completedBtn.heightAnchor.constraint(equalToConstant: 25),
            completedBtn.widthAnchor.constraint(equalToConstant: 25),
            
            reminderDetailsSV.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 7),
            reminderDetailsSV.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -7),
            reminderDetailsSV.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 40 + indentLevel),
            reminderDetailsSV.trailingAnchor.constraint(equalTo: buttonSV.leadingAnchor,constant: 0),
            
            buttonSV.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 6),
            buttonSV.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor,constant: -8),
            buttonSV.heightAnchor.constraint(equalToConstant: 25),
            
            chevronBtn.heightAnchor.constraint(equalToConstant: 25),
            chevronBtn.widthAnchor.constraint(equalToConstant: 25),
            
            detailDisclosureBtn.heightAnchor.constraint(equalToConstant: detailDisclosureBtn.frame.height),
            detailDisclosureBtn.widthAnchor.constraint(equalToConstant: detailDisclosureBtn.frame.width),
            
            separatorView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 40),
            separatorView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
            separatorView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 0),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ]
        
    }
    
    private func configure() {
        separatorView.backgroundColor = .lightGray
    }
    
}


extension ReminderTVCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        detailDisclosureBtn.isHidden = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        detailDisclosureBtn.isHidden = true
        
        //Save changes to realm
        do {
            try realm?.write {
                guard let reminderChange = reminder else { return }
                reminderChange.name = textField.text ?? ""
            }
        } catch {
            fatalError()
        }
    }
}
