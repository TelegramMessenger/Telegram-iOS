//
//  TypeCVCell.swift
//  AppleReminders
//
//  Created by Josh R on 1/24/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class TypeCVCell: UICollectionViewCell {
    static let reuseIdentifier = "TypeCVC"
    
    var desiredType: ReminderType? {
        didSet {
            configure()
            typeLbl.text = desiredType?.rawValue.capitalizeFirstLetter().localized
        }
    }
    
    //Cell views
    lazy var countLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.text = "0"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var iconBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .red
        view.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        view.layer.cornerRadius = view.frame.height / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    lazy var typeImgView: UIImageView = {
        let imgView = UIImageView()
        //image icon set in configure method below
        imgView.tintColor = .white
        imgView.translatesAutoresizingMaskIntoConstraints = false
        
        return imgView
    }()
    
    lazy var typeLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .systemGray
        label.text = "Type".localized
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 12
        
        iconBackgroundView.addSubview(typeImgView)
        addViews(views: countLbl, iconBackgroundView, typeLbl)
        configure()
        setViewConstraints()
    }
    required init?(coder: NSCoder) {
        fatalError("not implemnted")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
    }
    
    private func addViews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
    }
    
    private func setViewConstraints() {
        countLbl.topAnchor.constraint(equalTo: self.topAnchor, constant: 10).isActive = true
        countLbl.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -10).isActive = true
        
        NSLayoutConstraint.activate([
            iconBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            iconBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            iconBackgroundView.widthAnchor.constraint(equalToConstant: 30),
            iconBackgroundView.heightAnchor.constraint(equalToConstant: 30),
            
            typeImgView.widthAnchor.constraint(equalToConstant: 20),
            typeImgView.heightAnchor.constraint(equalToConstant: 20),
            typeImgView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            typeImgView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            
            typeLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            typeLbl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            typeLbl.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    func configure() {
        
        //MARK: Icon set
        guard let desiredType = desiredType else { return }
        var iconStringName = ""
        var reminderCount = ""
        
        switch desiredType {
        case .today:
            iconBackgroundView.backgroundColor = .systemBlue
            iconStringName = "calendar"
            reminderCount = "\(Reminder.numberOfTodayReminders)"
        case .scheduled:
            iconBackgroundView.backgroundColor = .systemOrange
            iconStringName = "clock.fill"
            reminderCount = "\(Reminder.numberOfScheduledReminders)"
        case .all:
            iconBackgroundView.backgroundColor = .systemGray
            iconStringName = "tray.fill"
            reminderCount = "\(Reminder.numberOfAllReminders)"
        case .flagged:
            iconBackgroundView.backgroundColor = .systemRed
            iconStringName = "flag.fill"
            reminderCount = "\(Reminder.numberOfFlaggedReminders)"
        }
        
        countLbl.text = reminderCount
        
        let iconImg = UIImage(systemName: iconStringName)?.withRenderingMode(.alwaysTemplate)
        typeImgView.image = iconImg
    }
    
}
