import Foundation
import UIKit
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

open class CallStatusBarNode: ASDisplayNode {
    open func update(size: CGSize) {
        
    }
}

private final class StatusBarView: UITracingLayerView {
    weak var node: StatusBar?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let node = self.node {
            return node.hitTest(point, with: event)
        }
        return nil
    }
}

public final class StatusBar: ASDisplayNode {
    private var _statusBarStyle: StatusBarStyle = .Black
    
    public var statusBarStyle: StatusBarStyle {
        get {
            return self._statusBarStyle
        } set(value) {
            if self._statusBarStyle != value {
                self._statusBarStyle = value
                self.alphaUpdated?(.immediate)
            }
        }
    }
    
    public func updateStatusBarStyle(_ statusBarStyle: StatusBarStyle, animated: Bool) {
        if self._statusBarStyle != statusBarStyle {
            self._statusBarStyle = statusBarStyle
            self.alphaUpdated?(animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
        }
    }
    
    public var ignoreInCall: Bool = false
    
    var inCallNavigate: (() -> Void)?
    
    private var proxyNode: StatusBarProxyNode?
    private var removeProxyNodeScheduled = false
    
    let offsetNode = ASDisplayNode()
    var callStatusBarNode: CallStatusBarNode? = nil
    
    public var verticalOffset: CGFloat = 0.0 {
        didSet {
            if !self.verticalOffset.isEqual(to: oldValue) {
                self.offsetNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -self.verticalOffset), size: CGSize())
            }
        }
    }
    
    var alphaUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    public func updateAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        self.alpha = alpha
        self.alphaUpdated?(transition)
    }
    
    public override init() {
        self.offsetNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.setViewBlock({
            return StatusBarView()
        })
        
        (self.view as! StatusBarView).node = self
        
        self.addSubnode(self.offsetNode)
        
        self.clipsToBounds = true
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateState(statusBar: UIView?, withSafeInsets: Bool, inCallNode: CallStatusBarNode?, animated: Bool) {
        if let statusBar = statusBar {
            self.removeProxyNodeScheduled = false
            let resolvedStyle: StatusBarStyle
            if inCallNode != nil && !self.ignoreInCall {
                resolvedStyle = .White
            } else {
                resolvedStyle = self.statusBarStyle
            }
            if let proxyNode = self.proxyNode {
                proxyNode.statusBarStyle = resolvedStyle
            } else {
                self.proxyNode = StatusBarProxyNode(statusBarStyle: resolvedStyle, statusBar: statusBar)
                self.proxyNode!.isHidden = false
                self.addSubnode(self.proxyNode!)
            }
        } else {
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
        
        var ignoreInCall = self.ignoreInCall
        switch self.statusBarStyle {
            case .Black, .White:
                break
            default:
                ignoreInCall = true
        }
        
        var resolvedCallStatusBarNode: CallStatusBarNode? = inCallNode
        if ignoreInCall {
            resolvedCallStatusBarNode = nil
        }
        
        if (resolvedCallStatusBarNode != nil) != (self.callStatusBarNode != nil) {
            if let resolvedCallStatusBarNode = resolvedCallStatusBarNode {
                self.addSubnode(resolvedCallStatusBarNode)
            } else if let callStatusBarNode = self.callStatusBarNode {
                self.callStatusBarNode = nil
                callStatusBarNode.removeFromSupernode()
            }
        }
        
        self.callStatusBarNode = resolvedCallStatusBarNode
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) && self.callStatusBarNode != nil {
            return self.view
        } else {
            return nil
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, self.callStatusBarNode != nil {
            self.inCallNavigate?()
        }
    }
}
