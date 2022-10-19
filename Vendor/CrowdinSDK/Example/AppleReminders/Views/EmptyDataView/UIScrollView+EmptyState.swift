//
//  UIScrollView+EmptyState.swift
//  AppleReminders
//
//  Created by Nazar Yavornytskyy on 2/25/21.
//  Copyright © 2021 Josh R. All rights reserved.
//

import UIKit

extension UIScrollView {
    
    private enum Settings {
        
        static let placeholderSize = CGSize(width: 255 * Layout.Ratio.width, height: 135 * Layout.Ratio.height)
        static let emptyText = "You do not have any lists. To create a new one, press the \"Add List\" button".localized
    }
    
    func showPlaceholder(message: String = Settings.emptyText) {
        hidePlaceholder()
        
        let view = EmptyDataView()
        view.viewModel = EmptyDataViewModel(message: message)
        
        addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.centerYAnchor.constraint(equalTo: centerYAnchor),
            view.centerXAnchor.constraint(equalTo: centerXAnchor),
            view.widthAnchor.constraint(equalToConstant: Settings.placeholderSize.width),
            view.heightAnchor.constraint(equalToConstant: Settings.placeholderSize.height)
        ])
    }
    
    func hidePlaceholder() {
        subviews.first { $0 is EmptyDataView }?.removeFromSuperview()
    }
}
