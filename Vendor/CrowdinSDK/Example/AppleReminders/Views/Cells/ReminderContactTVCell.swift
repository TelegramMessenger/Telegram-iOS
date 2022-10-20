//
//  ReminderContactTVCell.swift
//  AppleReminders
//
//  Created by Josh R on 3/7/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import Contacts

class ReminderContactTVCell: UITableViewCell {
    
    var passsedContact: CNContact? {
        didSet {
            guard let passsedContact = passsedContact else { return }
            contactNameLbl.text = "\(passsedContact.givenName) \(passsedContact.familyName)"
            contactPicImgView.passedContact = passsedContact
        }
    }

    static let identifier = "ReminderContactTVCell"
    
    var editBtnTappedCallback: ((ReminderContactTVCell) -> Void)?
    
    lazy var contactPicImgView: ContactThumbImgView = {
        let imgView = ContactThumbImgView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        imgView.layer.cornerRadius = imgView.frame.height / 2
        imgView.clipsToBounds = true
        return imgView
    }()
    
    lazy var contactNameLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .label
        
        return label
    }()
    
    lazy var editBtn: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .systemBlue
        button.setTitle("Edit".localized, for: .normal)
        button.addTarget(self, action: #selector(editBtnTapped), for: .touchUpInside)
        
        return button
    }()
    
    @objc func editBtnTapped() {
        editBtnTappedCallback?(self)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.backgroundColor = .secondarySystemGroupedBackground
        
        self.addSubview(contactPicImgView)
        self.addSubview(contactNameLbl)
        self.addSubview(editBtn)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupConstraints() {
        contactPicImgView.translatesAutoresizingMaskIntoConstraints = false
        contactNameLbl.translatesAutoresizingMaskIntoConstraints = false
        editBtn.translatesAutoresizingMaskIntoConstraints = false
        
        contactPicImgView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16).isActive = true
        contactPicImgView.widthAnchor.constraint(equalToConstant: contactPicImgView.frame.width).isActive = true
        contactPicImgView.heightAnchor.constraint(equalToConstant: contactPicImgView.frame.height).isActive = true
        contactPicImgView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
        contactNameLbl.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
        contactNameLbl.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
        contactNameLbl.leadingAnchor.constraint(equalTo: contactPicImgView.trailingAnchor, constant: 8).isActive = true
        contactNameLbl.trailingAnchor.constraint(equalTo: editBtn.leadingAnchor,constant: -5).isActive = true
        
        editBtn.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -8).isActive = true
        editBtn.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
}
