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
    public var statusBarStyle: StatusBarStyle = .Black {
        didSet {
            if self.statusBarStyle != statusBarStyle {
                self.layer.invalidateUpTheTree()
            }
        }
    }
    private var proxyNode: StatusBarProxyNode?
    private var removeProxyNodeScheduled = false
    
    public override init() {
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.layer.setTraceableInfo(NSWeakReference(value: self))
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
    }
    
    func removeProxyNode() {
        self.removeProxyNodeScheduled = true
        
        DispatchQueue.main.async(execute: { [weak self] in
            if let strongSelf = self {
                if strongSelf.removeProxyNodeScheduled {
                    strongSelf.removeProxyNodeScheduled = false
                    strongSelf.proxyNode?.isHidden = true
                    strongSelf.proxyNode?.removeFromSupernode()
                    strongSelf.proxyNode = nil
                }
            }
        })
    }
    
    func updateProxyNode(statusBar: UIView) {
        self.removeProxyNodeScheduled = false
        if let proxyNode = proxyNode {
            proxyNode.statusBarStyle = self.statusBarStyle
        } else {
            self.proxyNode = StatusBarProxyNode(statusBarStyle: self.statusBarStyle, statusBar: statusBar)
            self.proxyNode!.isHidden = false
            self.addSubnode(self.proxyNode!)
        }
    }
}
