//
//  AddListView.swift
//  AppleReminders
//
//  Created by Josh R on 1/29/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class AddListView: UIView {
    
    lazy var addGroupBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Add Group".localized, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .clear
        
        return button
    }()
    
    lazy var addListBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Add List".localized, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .clear
        
        return button
    }()
    
    lazy var settingsBtn: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "gearshape")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .clear
        
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        
        //addGroupBtn hidden up view creation
        addGroupBtn.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        //Setup main view
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.systemChromeMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(blurEffectView)
        
        //MARK: Constraints
        self.addSubview(addGroupBtn)
        self.addSubview(settingsBtn)
        self.addSubview(addListBtn)
        addGroupBtn.translatesAutoresizingMaskIntoConstraints = false
        settingsBtn.translatesAutoresizingMaskIntoConstraints = false
        addListBtn.translatesAutoresizingMaskIntoConstraints = false
       
        NSLayoutConstraint.activate([
            addGroupBtn.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            addGroupBtn.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 10),
            addGroupBtn.heightAnchor.constraint(equalToConstant: 30),
            
            settingsBtn.centerXAnchor.constraint(equalTo: self.centerXAnchor, constant: 0.0),
            settingsBtn.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 10),
            settingsBtn.heightAnchor.constraint(equalToConstant: 30),
            
            addListBtn.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            addListBtn.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 10),
            addListBtn.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
}
