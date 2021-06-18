import Foundation
import UIKit
import AsyncDisplayKit

public enum AlertControllerThemeBackgroundType {
    case light
    case dark
}

public final class AlertControllerTheme: Equatable {
    public let backgroundType: ActionSheetControllerThemeBackgroundType
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let highlightedItemColor: UIColor
    public let primaryColor: UIColor
    public let secondaryColor: UIColor
    public let accentColor: UIColor
    public let contrastColor: UIColor
    public let destructiveColor: UIColor
    public let disabledColor: UIColor
    public let controlBorderColor: UIColor
    public let baseFontSize: CGFloat
    
    public init(backgroundType: ActionSheetControllerThemeBackgroundType, backgroundColor: UIColor, separatorColor: UIColor, highlightedItemColor: UIColor, primaryColor: UIColor, secondaryColor: UIColor, accentColor: UIColor, contrastColor: UIColor, destructiveColor: UIColor, disabledColor: UIColor, controlBorderColor: UIColor, baseFontSize: CGFloat) {
        self.backgroundType = backgroundType
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.highlightedItemColor = highlightedItemColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.contrastColor = contrastColor
        self.destructiveColor = destructiveColor
        self.disabledColor = disabledColor
        self.controlBorderColor = controlBorderColor
        self.baseFontSize = baseFontSize
    }
    
    public static func ==(lhs: AlertControllerTheme, rhs: AlertControllerTheme) -> Bool {
        if lhs.backgroundType != rhs.backgroundType {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        if lhs.highlightedItemColor != rhs.highlightedItemColor {
            return false
        }
        if lhs.primaryColor != rhs.primaryColor {
            return false
        }
        if lhs.secondaryColor != rhs.secondaryColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.destructiveColor != rhs.destructiveColor {
            return false
        }
        if lhs.disabledColor != rhs.disabledColor {
            return false
        }
        if lhs.baseFontSize != rhs.baseFontSize {
            return false
        }
        return true
    }
}

open class AlertController: ViewController, StandalonePresentableController {
    private var controllerNode: AlertControllerNode {
        return self.displayNode as! AlertControllerNode
    }
    
    public var theme: AlertControllerTheme {
        didSet {
            if oldValue != self.theme {
                self.controllerNode.updateTheme(self.theme)
            }
        }
    }
    private let contentNode: AlertContentNode
    private let allowInputInset: Bool
    
    private weak var existingAlertController: AlertController?
    
    public var willDismiss: (() -> Void)?
    public var dismissed: (() -> Void)?
    
    public init(theme: AlertControllerTheme, contentNode: AlertContentNode, existingAlertController: AlertController? = nil, allowInputInset: Bool = true) {
        self.theme = theme
        self.contentNode = contentNode
        self.existingAlertController = existingAlertController
        self.allowInputInset = allowInputInset
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = AlertControllerNode(contentNode: self.contentNode, theme: self.theme, allowInputInset: self.allowInputInset)
        self.displayNodeDidLoad()
        
        self.controllerNode.existingAlertControllerNode = self.existingAlertController?.controllerNode
        
        self.controllerNode.dismiss = { [weak self] in
            if let strongSelf = self, strongSelf.contentNode.dismissOnOutsideTap {
                strongSelf.willDismiss?()
                strongSelf.controllerNode.animateOut {
                    self?.dismiss()
                }
            }
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.existingAlertController?.dismiss(completion: nil)
        self.existingAlertController = nil
        
        self.controllerNode.animateIn()
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.dismissed?()
        self.presentingViewController?.dismiss(animated: false, completion: completion)
    }
    
    public func dismissAnimated() {
        self.controllerNode.animateOut { [weak self] in
            self?.dismiss()
        }
    }
}
