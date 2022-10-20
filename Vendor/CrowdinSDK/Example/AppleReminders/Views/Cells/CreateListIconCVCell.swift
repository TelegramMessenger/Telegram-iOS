//
//  CreateListIconCVCell.swift
//  AppleReminders
//
//  Created by Josh R on 2/7/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

struct CreateListModel: Hashable {
    let colorHEX: String
    let iconName: String?
    let iconType: Icons.IconType?
    let cellType: CreateListIconCVCell.CellType
    let identifier = UUID()
}

class CreateListIconCVCell: UICollectionViewCell {
    
    static let identifier = "CreateListIconCVCell"
    
    enum CellType {
        case color
        case icon
    }
    
    var cellType: CellType?
    var iconImgViewBackgroundColor: UIColor? {
        didSet {
            self.containerView.backgroundColor = iconImgViewBackgroundColor ?? .systemRed
        }
    }
    
    lazy var containerView: UIView = {
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        view.layer.cornerRadius = view.frame.height / 2
        view.backgroundColor = .systemPink
        
        return view
    }()
    
    lazy var iconImgView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.tintColor = traitCollection.userInterfaceStyle == .light ? .darkGray : .white
        imgView.backgroundColor = .clear
        
        return imgView
    }()
    
    override var isSelected: Bool {
        willSet{
            super.isSelected = newValue
            if newValue {
                self.layer.borderWidth = 3.0
                self.layer.borderColor = UIColor.lightGray.cgColor
            } else {
                self.layer.borderWidth = 0.0
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        containerView.addSubview(iconImgView)
        
        addViews(views: containerView)
        setupConstraints()
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addViews(views: UIView...) {
        views.forEach({ self.contentView.addSubview($0) })
    }
    
    private func configure() {
//        self.backgroundColor = .systemRed
        self.layer.cornerRadius = self.frame.height / 2
        
        switch cellType {
        case .color:
            return
        case .icon:
            return
        case .none:
            return
        }
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconImgView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        containerView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor).isActive = true
        containerView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true

        iconImgView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8).isActive = true
        iconImgView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8).isActive = true
        iconImgView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8).isActive = true
        iconImgView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,constant: -8).isActive = true

        iconImgView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
        iconImgView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        
    }
    
}
