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
    public var style: StatusBarStyle = .Black {
        didSet {
            if self.style != oldValue {
                self.layer.invalidateUpTheTree()
            }
        }
    }
    private var proxyNode: StatusBarProxyNode?
    private var removeProxyNodeScheduled = false
    
    override init() {
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
    
    func updateProxyNode() {
        self.removeProxyNodeScheduled = false
        if let proxyNode = proxyNode {
            proxyNode.style = self.style
        } else {
            self.proxyNode = StatusBarProxyNode(style: self.style)
            self.proxyNode!.isHidden = false
            self.addSubnode(self.proxyNode!)
        }
    }
}
