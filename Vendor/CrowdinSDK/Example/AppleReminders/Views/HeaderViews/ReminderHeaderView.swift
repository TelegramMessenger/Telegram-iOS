//
//  ReminderHeaderView.swift
//  AppleReminders
//
//  Created by Josh R on 7/12/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class ReminderHeaderView: UITableViewHeaderFooterView {
    
    static let reuseIdentifier = "ReminderHeaderView"
    static let height: CGFloat = 40
    
    var reminderList: ReminderList?
    var sectionDate: String?
    
    var vcType: ReminderListTVC.VCType? {
        didSet {
            guard let vcType = vcType else { return }
            switch vcType {
            case .all, .search(_):
                guard let reminderList = reminderList else { return }
                sectionLbl.textColor = reminderList.listUIColor
                sectionLbl.text = reminderList.name
            case .scheduled:
                guard let sectionDateString = sectionDate else { return }
                sectionLbl.textColor = .systemGray3
                sectionLbl.text?.removeAll()
                
                //first three letters are label, remaining light gray
                if sectionDateString.count > 3 {
                    let formattedSectionString = NSMutableAttributedString(string: sectionDateString)
                    formattedSectionString.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: 3))
                    sectionLbl.attributedText = formattedSectionString
                }
            default:
                sectionLbl.textColor = .label
            }
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
        
        self.contentView.backgroundColor = .systemBackground
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
