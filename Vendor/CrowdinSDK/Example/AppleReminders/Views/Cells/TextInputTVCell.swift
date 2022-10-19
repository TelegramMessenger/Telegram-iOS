//
//  TextInputTVCell.swift
//  AppleReminders
//
//  Created by Josh R on 2/29/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

class TextInputTVCell: UITableViewCell {
    
    static let identifier = "TextInputTVCell"
    
    var passTextFieldText: ((String) -> Void)?
    
    lazy var inputTextField: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .clear
        textField.textColor = .label
        textField.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textField.attributedPlaceholder = NSAttributedString(string: "Text".localized,
                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.systemGray])
        
        return textField
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.backgroundColor = .secondarySystemGroupedBackground
        
        self.addSubview(inputTextField)
        setupConstraints()
        
        inputTextField.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupConstraints() {
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        
        inputTextField.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
        inputTextField.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0).isActive = true
        inputTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16).isActive = true
        inputTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor,constant: -12).isActive = true
        inputTextField.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    func setupTextInputTVCell(with text: String, placeholderText: String) {
        inputTextField.text = text
        inputTextField.placeholder = placeholderText
    }

}

extension TextInputTVCell: UITextFieldDelegate {
    func textFieldDidChangeSelection(_ textField: UITextField) {
        passTextFieldText?(textField.text!.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
