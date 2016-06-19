import Foundation
import AsyncDisplayKit

public class StatusBarSurface {
    var statusBars: [StatusBar] = []
    
    func addStatusBar(_ statusBar: StatusBar) {
        self.removeStatusBar(statusBar)
        self.statusBars.append(statusBar)
    }
    
    func insertStatusBar(_ statusBar: StatusBar, atIndex index: Int) {
        self.removeStatusBar(statusBar)
        self.statusBars.insert(statusBar, at: index)
    }
    
    func removeStatusBar(_ statusBar: StatusBar) {
        for i in 0 ..< self.statusBars.count {
            if self.statusBars[i] === statusBar {
                self.statusBars.remove(at: i)
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
        self.isUserInteractionEnabled = false
    }
    
    func removeProxyNode() {
        self.proxyNode?.isHidden = true
        self.proxyNode?.removeFromSupernode()
        self.proxyNode = nil
    }
    
    func updateProxyNode() {
        let origin = self.view.convert(CGPoint(), to: nil)
        if let proxyNode = proxyNode {
            proxyNode.style = self.style
        } else {
            self.proxyNode = StatusBarProxyNode(style: self.style)
            self.proxyNode!.isHidden = false
            self.addSubnode(self.proxyNode!)
        }
        
        let frame = CGRect(origin: CGPoint(x: -origin.x, y: -origin.y), size: self.proxyNode!.frame.size)
        self.proxyNode?.frame = frame
    }
}
