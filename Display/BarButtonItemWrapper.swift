import UIKit
import AsyncDisplayKit

internal class BarButtonItemWrapper {
    let parentNode: ASDisplayNode
    let barButtonItem: UIBarButtonItem
    let layoutNeeded: () -> ()
    
    let buttonNode: NavigationButtonNode
    
    private var setEnabledListenerKey: Int!
    private var setTitleListenerKey: Int!
    
    init(parentNode: ASDisplayNode, barButtonItem: UIBarButtonItem, layoutNeeded: () -> ()) {
        self.parentNode = parentNode
        self.barButtonItem = barButtonItem
        self.layoutNeeded = layoutNeeded
        
        self.buttonNode = NavigationButtonNode()
        self.buttonNode.pressed = { [weak self] in
            self?.barButtonItem.performActionOnTarget()
            return
        }
        self.parentNode.addSubnode(self.buttonNode)
        
        self.setEnabledListenerKey = barButtonItem.addSetEnabledListener({ [weak self] enabled in
            self?.buttonNode.isEnabled = enabled.boolValue
            return
        })
        
        self.setTitleListenerKey = barButtonItem.addSetTitleListener({ [weak self] title in
            self?.buttonNode.text = title ?? ""
            if let layoutNeeded = self?.layoutNeeded {
                layoutNeeded()
            }
            return
        })
        
        self.buttonNode.text = barButtonItem.title ?? ""
        self.buttonNode.isEnabled = barButtonItem.isEnabled ?? true
        self.buttonNode.bold = (barButtonItem.style ?? UIBarButtonItemStyle.plain) == UIBarButtonItemStyle.done
    }
    
    deinit {
        self.barButtonItem.removeSetTitleListener(self.setTitleListenerKey)
        self.barButtonItem.removeSetEnabledListener(self.setEnabledListenerKey)
        self.buttonNode.removeFromSupernode()
    }
}
