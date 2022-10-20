//
//  UIViewController.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/16/19.

import UIKit

#if os(iOS)
// MARK: - Custom view controller presentation and dismiss.
public extension UIViewController {
    private static let alertWindowAssociation = ObjectAssociation<UIWindow>()
    private var alertWindow: UIWindow? {
        get { return UIViewController.alertWindowAssociation[self] }
        set { UIViewController.alertWindowAssociation[self] = newValue }
    }
    
    private static let topWindowAssociation = ObjectAssociation<UIWindow>()
    var topWindow: UIWindow? {
        get { return UIViewController.topWindowAssociation[self] }
        set { UIViewController.topWindowAssociation[self] = newValue }
    }
    
    /// Custom view controller presentation. View controller presenter on new window over all existing windows. To dismiss it cw_dismiss() method should be used.
    /// https://stackoverflow.com/a/51723032/3697225
    @objc func cw_present() {
        self.topWindow = UIApplication.shared.keyWindow
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.filter({ $0.activationState == .foregroundActive }).first as? UIWindowScene {
                self.alertWindow = UIWindow(windowScene: windowScene)
            } else {
                self.alertWindow = UIWindow.init(frame: UIScreen.main.bounds)
            }
        } else {
            self.alertWindow = UIWindow.init(frame: UIScreen.main.bounds)
        }
        
        let viewController = UIViewController()
        self.alertWindow?.rootViewController = viewController

        if let topWindow = topWindow {
            self.alertWindow?.windowLevel = topWindow.windowLevel + 1
        }

        self.alertWindow?.makeKeyAndVisible()
        self.alertWindow?.rootViewController?.present(self, animated: true, completion: nil)
    }
    
    /// Dissmiss view controller presenter with cw_present() method.
    @objc func cw_dismiss() {
        self.dismiss(animated: false, completion: nil)
        self.alertWindow?.resignKey()
        self.alertWindow?.isHidden = true
        self.alertWindow = nil
        self.topWindow?.makeKeyAndVisible()
        self.topWindow = nil
    }
    
    @objc func cw_askToClearLogsAlert() {
        let alert = UIAlertController(title: "CrowdinSDK", message: "Are you sure you want to remove all logs?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            alert.cw_dismiss()
            CrowdinLogsCollector.shared.clear()
            NotificationCenter.default.post(name: NSNotification.Name.refreshLogsName, object: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
            alert.cw_dismiss()
        }))
        alert.cw_present()
    }
}
#endif
