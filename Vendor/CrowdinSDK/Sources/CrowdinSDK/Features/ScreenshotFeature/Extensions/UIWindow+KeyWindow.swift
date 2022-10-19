//
//  UIWindow+KeyWindow.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 18.12.2020.
//

import UIKit

extension UIApplication {
    var cw_KeyWindow: UIWindow? {
        return windows.first(where: { $0.isKind(of: UIWindow.self) })
    }
}

extension UIWindow {
    var rootVC: UIViewController? {
        guard let keyWindow = UIApplication.shared.cw_KeyWindow, let rootViewController = keyWindow.rootViewController else {
            return nil
        }
        return rootViewController
    }
    
    func topViewController(controller: UIViewController? = UIApplication.shared.cw_KeyWindow?.rootVC) -> UIViewController? {
        if let presentedViewController = controller?.presentedViewController {
            return presentedViewController
        }
        
        if let navigationController = controller as? UINavigationController {
            return navigationController
        }
        
        if let tabController = controller as? UITabBarController {
            return tabController
        }
        
        return controller
    }
}
