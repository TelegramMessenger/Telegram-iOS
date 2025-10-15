import UIKit
import SwiftSignalKit

public protocol StatusBarHost {
    var statusBarFrame: CGRect { get }
    
    var keyboardWindow: UIWindow? { get }
    var keyboardView: UIView? { get }
    
    var isApplicationInForeground: Bool { get }
}
