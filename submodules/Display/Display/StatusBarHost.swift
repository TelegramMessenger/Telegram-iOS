import UIKit
import SwiftSignalKit

public protocol StatusBarHost {
    var statusBarFrame: CGRect { get }
    var statusBarStyle: UIStatusBarStyle { get set }
    var statusBarWindow: UIView? { get }
    var statusBarView: UIView? { get }
    
    var keyboardWindow: UIWindow? { get }
    var keyboardView: UIView? { get }
    
    var handleVolumeControl: Signal<Bool, NoError> { get }
    
    var isApplicationInForeground: Bool { get }
    
    func setStatusBarStyle(_ style: UIStatusBarStyle, animated: Bool)
    func setStatusBarHidden(_ value: Bool, animated: Bool)
}
