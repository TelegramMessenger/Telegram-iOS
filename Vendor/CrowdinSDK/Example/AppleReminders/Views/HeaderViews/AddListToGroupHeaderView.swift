//
//  AddListToGroupHeaderView.swift
//  AppleReminders
//
//  Created by Josh R on 7/19/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class AddListToGroupHeaderView: UITableViewHeaderFooterView {

    static let reuseIdentifier = "AddListToGroupHeaderView"
    static let height: CGFloat = 30
    
    var title: String? {
        didSet {
            guard let title = title else { return }
            sectionLbl.text = title
        }
    }
    
    lazy var sectionLbl: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.textAlignment = .left
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        return label
    }()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        setupViews()
        
        self.contentView.backgroundColor = .systemBackground
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func setupViews() {
        contentView.addSubview(sectionLbl)
        sectionLbl.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            sectionLbl.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 12),
            sectionLbl.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -2),
            sectionLbl.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -5)
        ])
    }

}
