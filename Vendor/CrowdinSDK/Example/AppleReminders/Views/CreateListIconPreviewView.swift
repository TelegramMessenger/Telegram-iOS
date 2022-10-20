//
//  CreateListIconPreviewView.swift
//  AppleReminders
//
//  Created by Josh R on 2/5/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class CreateListIconPreviewView: UIView {
    
    var iconBackGround: UIColor? {
        didSet {
            self.backgroundColor = iconBackGround ?? .systemBlue
            
            //View Shadow
            if traitCollection.userInterfaceStyle == .light {
                self.layer.shadowColor = iconBackGround?.cgColor ?? UIColor.systemBlue.cgColor
            }
        }
    }
    
    lazy var iconImgView: UIImageView = {
        let imgView = UIImageView()
        imgView.image = UIImage(named: "paperplane.fill")
        imgView.contentMode = .scaleAspectFit
        
        return imgView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        applyIconBackgroundShadow()
        
        self.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        self.backgroundColor = iconBackGround ?? .systemBlue
        self.tintColor = .white
        self.layer.cornerRadius = self.frame.height / 2
        
        addViews(views: iconImgView)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addViews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
    }
    
    private func setupConstraints() {
        iconImgView.translatesAutoresizingMaskIntoConstraints = false
        
        iconImgView.widthAnchor.constraint(equalToConstant: 55).isActive = true
        iconImgView.heightAnchor.constraint(equalToConstant: 55).isActive = true
        iconImgView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        iconImgView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    private func applyIconBackgroundShadow() {
        if traitCollection.userInterfaceStyle == .light {
            print("Light mode")
            self.layer.shadowColor = iconBackGround?.cgColor ?? UIColor.systemBlue.cgColor
            self.layer.shadowOffset = CGSize(width: 0, height: 5)
            self.layer.shadowRadius = 7
            self.layer.shadowOpacity = 0.4
        } else {
            print("Dark mode")
            //Shadow config not needed
        }
    }
}
