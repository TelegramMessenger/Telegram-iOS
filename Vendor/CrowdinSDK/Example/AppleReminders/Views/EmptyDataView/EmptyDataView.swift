//
//  EmptyDataView.swift
//  AppleReminders
//
//  Created by Nazar Yavornytskyy on 2/25/21.
//  Copyright © 2021 Josh R. All rights reserved.
//

import Foundation
import UIKit

final class EmptyDataView: UIView {
    
    private enum Settings {
        
        static let cloudImage = UIImage(named: "empty_list_placeholder")
    }
    
    lazy var logoImageView: UIImageView = {
        let imgView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        imgView.contentMode = .scaleAspectFit
        
        return imgView
    }()
    
    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .systemGray
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = .zero
        
        return label
    }()
    
    private var viewConstraints: [NSLayoutConstraint] = [] {
        willSet { NSLayoutConstraint.deactivate(viewConstraints) }
        didSet { NSLayoutConstraint.activate(viewConstraints) }
    }
    
    var viewModel: EmptyDataPresentationModel? {
        didSet {
            setupAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addViews(views: logoImageView, messageLabel)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private
    
    private func setupAppearance() {
        logoImageView.image = Settings.cloudImage
        messageLabel.text = viewModel?.message
        
        backgroundColor = .clear
    }
    
    private func addViews(views: UIView...) {
        views.forEach({ self.addSubview($0) })
        views.forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })
    }
    
    private func setupConstraints() {
        viewConstraints = [
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 25),
            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 10),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.widthAnchor.constraint(equalTo: widthAnchor)
        ]
    }
}
