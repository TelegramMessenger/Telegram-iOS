//
//  ReminderActionView.swift
//  AppleReminders
//
//  Created by Josh R on 2/1/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import Contacts

class ReminderActionView: UIView {
    
    lazy var iconAPI = IconAPI()
    
    enum IconType {
        case car
        case contact
        case location
        case webURL
    }
    
    var iconType: IconType? {
        didSet {
            setupActionView()
            setupIconImgViewConstraints()
        }
    }
    
    var passedContact: CNContact?
    var passedReminder: Reminder?
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.backgroundColor = .clear
        label.sizeToFit()
        
        return label
    }()
    
    lazy var iconBackground: UIView = {
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = view.frame.height / 2
        
        return view
    }()
    
    lazy var iconImgView: ContactThumbImgView = {
        let imgView = ContactThumbImgView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        
        return imgView
    }()
    
    lazy var iconTextLbl: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .systemGray6
        self.layer.cornerRadius = 8
        
        setupActivityIcon()
        addviews(views: titleLabel, iconBackground)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupActivityIcon() {
        iconBackground.addSubview(iconImgView)
        iconBackground.addSubview(iconTextLbl)
    }
    
    private func addviews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
    }
    
    private func setupActionView() {
        switch iconType {
        case .car:
            self.iconBackground.backgroundColor = .systemBlue
            self.iconImgView.image = UIImage(systemName: "car.fill")
        case .location:
            self.iconBackground.backgroundColor = .systemRed
            self.iconImgView.tintColor = .white
            self.iconImgView.image = UIImage(systemName: "mappin")
        case .contact:
            iconImgView.passedContact = passedContact
            self.iconBackground.backgroundColor = .systemGray
        case .webURL:
            guard let passedReminder = passedReminder else { return }
            self.iconImgView.tintColor = .white
            self.iconBackground.backgroundColor = .clear
            self.iconImgView.image = UIImage(systemName: "safari")
            iconAPI.fetchIcon(urlString: passedReminder.url!) { (response: Result<Data?, Error>) in
                switch response {
                case .success(let data):
                    DispatchQueue.main.async {
                        if let data = data {
                            //Even though nil is set to data in IconAPi method, 1 byte is still returned
                            if data.count > 1 {
                                self.iconImgView.image = UIImage(data: data)
                            }
                        }
                    }
                case .failure:
                    break
                }
            }
        default:
            break
        }
    }
    
    private func setupConstraints() {
        self.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        
        
        self.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        iconBackground.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5).isActive = true
        iconBackground.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconBackground.heightAnchor.constraint(equalToConstant: 20).isActive = true
        iconBackground.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 5).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -12).isActive = true
        titleLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        
    }
    
    private func setupIconImgViewConstraints() {
        iconImgView.translatesAutoresizingMaskIntoConstraints = false
        iconTextLbl.translatesAutoresizingMaskIntoConstraints = false
        
        let imgViewConstraints: CGFloat = iconType == .contact || iconType == .webURL ? 0 : 3
        
        iconImgView.topAnchor.constraint(equalTo: iconBackground.topAnchor, constant: imgViewConstraints).isActive = true
        iconImgView.bottomAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: -imgViewConstraints).isActive = true
        iconImgView.leadingAnchor.constraint(equalTo: iconBackground.leadingAnchor, constant: imgViewConstraints).isActive = true
        iconImgView.trailingAnchor.constraint(equalTo: iconBackground.trailingAnchor,constant: -imgViewConstraints).isActive = true
        
        iconTextLbl.topAnchor.constraint(equalTo: iconBackground.topAnchor, constant: imgViewConstraints).isActive = true
        iconTextLbl.bottomAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: -imgViewConstraints).isActive = true
        iconTextLbl.leadingAnchor.constraint(equalTo: iconBackground.leadingAnchor, constant: imgViewConstraints).isActive = true
        iconTextLbl.trailingAnchor.constraint(equalTo: iconBackground.trailingAnchor,constant: -imgViewConstraints).isActive = true
    }
    
    
}
