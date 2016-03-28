import Foundation
import AsyncDisplayKit

public class StatusBarSurface {
    var statusBars: [StatusBar] = []
    
    func addStatusBar(statusBar: StatusBar) {
        self.removeStatusBar(statusBar)
        self.statusBars.append(statusBar)
    }
    
    func insertStatusBar(statusBar: StatusBar, atIndex index: Int) {
        self.removeStatusBar(statusBar)
        self.statusBars.insert(statusBar, atIndex: index)
    }
    
    func removeStatusBar(statusBar: StatusBar) {
        for i in 0 ..< self.statusBars.count {
            if self.statusBars[i] === statusBar {
                self.statusBars.removeAtIndex(i)
                break
            }
        }
    }
}

public class StatusBar: ASDisplayNode {
    public var style: StatusBarStyle = .Black
    var proxyNode: StatusBarProxyNode?
    
    override init() {
        super.init()
        
        self.clipsToBounds = true
        self.userInteractionEnabled = false
    }
    
    func removeProxyNode() {
        self.proxyNode?.hidden = true
        self.proxyNode?.removeFromSupernode()
        self.proxyNode = nil
    }
    
    func updateProxyNode() {
        let origin = self.view.convertPoint(CGPoint(), toView: nil)
        if let proxyNode = proxyNode {
            proxyNode.style = self.style
        } else {
            self.proxyNode = StatusBarProxyNode(style: self.style)
            self.proxyNode!.hidden = false
            self.addSubnode(self.proxyNode!)
        }
        
        let frame = CGRect(origin: CGPoint(x: -origin.x, y: -origin.y), size: self.proxyNode!.frame.size)
        self.proxyNode?.frame = frame
    }
    
    
}
