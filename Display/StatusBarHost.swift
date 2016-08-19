import UIKit

public protocol StatusBarHost {
    var statusBarFrame: CGRect { get }
    var statusBarStyle: UIStatusBarStyle { get set }
    var statusBarWindow: UIView? { get }
    var statusBarView: UIView? { get }
}
