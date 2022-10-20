//
//  SettingsWindow.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 04.12.2020.
//

import UIKit
import CoreGraphics

class SettingsWindow: UIWindow {
    weak var settingsView: SettingsView? {
        didSet {
            if let view = oldValue {
                view.removeFromSuperview()
            }
            if let view = settingsView {
                self.addSubview(view)
            }
        }
    }

    init() {
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.filter({ $0.activationState == .foregroundActive }).first as? UIWindowScene {
                super.init(windowScene: windowScene)
            } else {
                super.init(frame: UIScreen.main.bounds)
            }
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let settingsView = settingsView else { return false }
        let buttonPoint = convert(point, to: settingsView)
        return settingsView.point(inside: buttonPoint, with: event)
    }
    
    deinit {
        print(#function)
    }
}
