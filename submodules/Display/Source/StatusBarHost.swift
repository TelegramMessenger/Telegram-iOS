import UIKit
import SwiftSignalKit

public protocol StatusBarHost {
    var statusBarFrame: CGRect { get }
    var statusBarStyle: UIStatusBarStyle { get set }
    
    var keyboardWindow: UIWindow? { get }
    var keyboardView: UIView? { get }
    
    var isApplicationInForeground: Bool { get }
    
    func setStatusBarStyle(_ style: UIStatusBarStyle, animated: Bool)
    func setStatusBarHidden(_ value: Bool, animated: Bool)
    
    var shouldChangeStatusBarStyle: ((UIStatusBarStyle) -> Bool)? { get set }
}
