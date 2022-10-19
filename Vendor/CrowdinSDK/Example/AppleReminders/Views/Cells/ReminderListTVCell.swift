//
//  ListCVC.swift
//  AppleReminders
//
//  Created by Josh R on 1/24/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import RealmSwift

protocol ReminderListCellDelegate: class {
    func pass(list: ReminderList)
}

class ReminderListTVCell: UITableViewCell {
    
    static let reuseIdentifier = "ListCVCell"
    
    weak var delegate: ReminderListCellDelegate?
    
    var list: ReminderList? {
        didSet {
            guard let list = list else { return }
            setupListViews()
            listNameLbl.text = list.groupName ?? list.name
            
            //Set up group or reminder count
            numberOfActiveRemindersLbl.isHidden = false
            let listcount = list.isGroup ? list.reminderLists.count : list.reminders.filter({ $0.isCompleted == false }).count
            numberOfActiveRemindersLbl.text = "\(listcount)"
            iconBackgroundView.backgroundColor = list.listUIColor
        
            //Set up icon -- list or group
            let iconImg = list.getListIcon
            listIconImgView.image = iconImg
            listIconImgView.tintColor = list.isGroup ? .systemGray : .white
        }
    }
    
    //MARK: title ui components
    let accountTitleContainerView = UIView()
    
    lazy var accountTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        
        return label
    }()
    
    lazy var iconBackgroundView: UIView = {
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        view.layer.cornerRadius = view.frame.height / 2
        
        return view
    }()
    
    lazy var listIconImgView: UIImageView = {
        let imgView = UIImageView()
        let iconImg = UIImage(systemName: "list.bullet")?.withRenderingMode(.alwaysTemplate)
        imgView.contentMode = .scaleAspectFit
        imgView.tintColor = .white
        imgView.image = iconImg
        
        return imgView
    }()
    
    lazy var listNameLbl: UILabel = {
        let label = UILabel()
        label.textColor = .label
        
        return label
    }()
    
    lazy var sharedToLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = .label
        
        return label
    }()
    
    lazy var numberOfActiveRemindersLbl: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        
        return label
    }()
    
    
    //MARK: List title SVs
    let listTitleSV: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 2
        sv.distribution = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        
        return sv
    }()
    
    lazy var accessoryImageView: UIImageView = {
        let imgView = UIImageView()
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let chevronImageName = rtl ? "chevron.left" : "chevron.right"
        let chevronImage = UIImage(systemName: chevronImageName)
        imgView.image = chevronImage
        imgView.tintColor = UIColor.lightGray.withAlphaComponent(0.7)
        
        return imgView
    }()
    
    //MARK: DetailDisclosure btn in editing mode
    lazy var editingDetailBtn: UIButton = {
        let button = UIButton(type: .detailDisclosure)
        button.addTarget(self, action: #selector(editingDetailBtnTapped), for: .touchUpInside)
        return button
    }()
    
    @objc func editingDetailBtnTapped() {
        guard let list = list else { return }
        delegate?.pass(list: list)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

//        self.editingAccessoryView = UIButton(type: .detailDisclosure)
        self.editingAccessoryView = editingDetailBtn
        self.indentationLevel = 10
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        numberOfActiveRemindersLbl.isHidden = self.isEditing ? true : false
        accessoryImageView.isHidden = self.isEditing ? true : false
        
        if let list = list, list.isExpanded {
            numberOfActiveRemindersLbl.isHidden = true
        }
        
        setupConstraints()
        rotateChevron()
    }
    
    required init?(coder: NSCoder) {
        fatalError("not implemented")
    }
    
    private func rotateChevron() {
        if let list = list {
            listIconImgView.image = list.getListIcon
            
            if list.isExpanded {
                accessoryImageView.transform = CGAffineTransform(rotationAngle: Conversions.convertRadiansToDegrees(90))
            } else {
                accessoryImageView.transform = .identity
            }
        }
    }

    //MARK:  Cell constraints
    var cellViewConstraints: [NSLayoutConstraint] = [] {
        willSet { NSLayoutConstraint.deactivate(cellViewConstraints) }
        didSet { NSLayoutConstraint.activate(cellViewConstraints) }
    }
    
    private func setupListViews() {
        //add ui elements to containerView
        self.contentView.backgroundColor = .secondarySystemGroupedBackground

        //add views to containerView
        iconBackgroundView.addSubview(listIconImgView)
        self.contentView.addSubview(iconBackgroundView)
        listTitleSV.addArrangedSubview(listNameLbl)
        listTitleSV.addArrangedSubview(sharedToLbl)
        self.contentView.addSubview(numberOfActiveRemindersLbl)
        self.contentView.addSubview(accessoryImageView)
        self.contentView.addSubview(listTitleSV)
        
        //set constraints
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        listIconImgView.translatesAutoresizingMaskIntoConstraints = false
        listNameLbl.translatesAutoresizingMaskIntoConstraints = false
        listTitleSV.translatesAutoresizingMaskIntoConstraints = false
        numberOfActiveRemindersLbl.translatesAutoresizingMaskIntoConstraints = false
        accessoryImageView.translatesAutoresizingMaskIntoConstraints = false
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        let indentLevel: CGFloat = list!.isInGroup ? 10 : 0
        let iconWidth: CGFloat = list!.isGroup ? 30 : 20
        
        cellViewConstraints = [
            iconBackgroundView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 10 + indentLevel),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 30),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 30),
            iconBackgroundView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            
            listIconImgView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            listIconImgView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            
            listIconImgView.widthAnchor.constraint(equalToConstant: iconWidth),
            listIconImgView.heightAnchor.constraint(equalToConstant: iconWidth),
            
            listTitleSV.leadingAnchor.constraint(equalTo: iconBackgroundView.trailingAnchor, constant: 8),
            listTitleSV.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor,constant: 0),
            listTitleSV.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            
            accessoryImageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            accessoryImageView.widthAnchor.constraint(equalToConstant: 10),
            accessoryImageView.heightAnchor.constraint(equalToConstant: 17),
            accessoryImageView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -8),
            
            numberOfActiveRemindersLbl.trailingAnchor.constraint(equalTo: accessoryImageView.leadingAnchor,constant: -8),
            numberOfActiveRemindersLbl.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor)
        ]
    }
  
}
