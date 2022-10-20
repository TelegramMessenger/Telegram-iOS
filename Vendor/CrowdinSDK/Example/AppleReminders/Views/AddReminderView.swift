//
//  AddReminderView.swift
//  AppleReminders
//
//  Created by Josh R on 2/6/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class AddReminderView: UIView {
    
    enum State {
        case normal
        case editing
    }
    
    var state: State? {
        didSet {
            guard let state = state else { return }
            addReminderBtn.isHidden = state == .normal ? false : true
            moveToBtn.isHidden = state == .normal ? true : false
            deleteBtn.isHidden = state == .normal ? true : false
        }
    }
    
    lazy var addReminderBtn: NewReminderBtn = {
        let button = NewReminderBtn()
        button.sizeToFit()
        
        return button
    }()
    
    lazy var moveToBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Move To...".localized, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .clear
        
        return button
    }()
    
    lazy var deleteBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Delete".localized, for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        state = .normal
        
        setupBlurView()
        addViews(views: addReminderBtn, deleteBtn, moveToBtn)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
    }
    
    var viewConstraints: [NSLayoutConstraint] = [] {
        willSet { NSLayoutConstraint.deactivate(viewConstraints) }
        didSet { NSLayoutConstraint.activate(viewConstraints) }
    }
    
    private func setupBlurView() {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.systemChromeMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(blurEffectView)
    }
    
    private func addViews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
        views.forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })
    }
    
    private func setupConstraints() {
        viewConstraints = [
            addReminderBtn.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            addReminderBtn.leadingAnchor.constraint(equalTo: self.leadingAnchor,constant: 16),
            addReminderBtn.heightAnchor.constraint(equalToConstant: 40),
            
            moveToBtn.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            moveToBtn.leadingAnchor.constraint(equalTo: self.leadingAnchor,constant: 16),
            moveToBtn.heightAnchor.constraint(equalToConstant: 40),
            
            deleteBtn.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            deleteBtn.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -16),
            deleteBtn.heightAnchor.constraint(equalToConstant: 40)
        ]
        
        
    }
    
    
}
