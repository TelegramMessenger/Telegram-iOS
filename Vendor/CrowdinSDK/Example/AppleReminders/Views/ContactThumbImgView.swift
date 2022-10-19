
//
//  ContactTextImgView.swift
//  AppleReminders
//
//  Created by Josh R on 3/16/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import Contacts

class ContactThumbImgView: UIImageView {
    
    var passedContact: CNContact? {
        didSet {
            guard let contact = passedContact else { return }
            if let thumbnail = contact.thumbnailImageData {
                textLbl.isHidden = true
                self.image = UIImage(data: thumbnail)
            } else {
                //Use initials
                let initials = "\(contact.givenName.first!)\(contact.familyName.first!)"
                textLbl.isHidden = false
                textLbl.text = initials
                self.backgroundColor = .systemGray
            }
        }
    }

    
    lazy var textLbl: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.clipsToBounds = true
        self.layer.cornerRadius = self.frame.height / 2
        
        addViews(views: textLbl)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addViews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
    }
   
    private func setupConstraints() {
        textLbl.translatesAutoresizingMaskIntoConstraints = false
        
        textLbl.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
        textLbl.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
        textLbl.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
        textLbl.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: 0).isActive = true
    }
    
}
