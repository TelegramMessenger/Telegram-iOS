//
//  ListSectionHeaderView.swift
//  AppleReminders
//
//  Created by Josh R on 7/15/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import UIKit

class ListSectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "ListSectionHeaderView"
    static let height: CGFloat = 40
    
    var title: String? {
        didSet {
            guard let title = title else { return }
            sectionLbl.text = title
        }
    }
    
    lazy var sectionLbl: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        
        return label
    }()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        setupViews()
        
        self.contentView.backgroundColor = .systemGroupedBackground
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func setupViews() {
        contentView.addSubview(sectionLbl)
        sectionLbl.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            sectionLbl.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 8),
            sectionLbl.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 5),
            sectionLbl.heightAnchor.constraint(equalToConstant: ReminderHeaderView.height)
        ])
    }

}
