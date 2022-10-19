//
//  DatePickerTVCell.swift
//  AppleReminders
//
//  Created by Josh R on 3/5/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class DatePickerTVCell: UITableViewCell {
    
    var passDate:((Date) -> Void)?
   
    lazy var datePicker: UIDatePicker = {
       let datePicker = UIDatePicker()
        datePicker.backgroundColor = .clear
        datePicker.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
        
        return datePicker
    }()
    
    @objc func datePickerChanged() {
        passDate?(datePicker.date)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.backgroundColor = .secondarySystemGroupedBackground
        
        self.addViews(views: datePicker)
        self.addConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addViews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
    }
    
    private func addConstraints() {
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        
        datePicker.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
        datePicker.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
        datePicker.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
        datePicker.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: 0).isActive = true
        
    }

}
