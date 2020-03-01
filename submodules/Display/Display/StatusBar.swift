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

private let inCallBackgroundColor = UIColor(rgb: 0x43d551)

private func addInCallAnimation(_ layer: CALayer) {
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.keyTimes = [0.0 as NSNumber, 0.1 as NSNumber, 0.5 as NSNumber, 0.9 as NSNumber, 1.0 as NSNumber]
    animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.0 as NSNumber, 1.0 as NSNumber, 1.0 as NSNumber]
    animation.duration = 1.8
    animation.autoreverses = true
    animation.repeatCount = Float.infinity
    animation.beginTime = 1.0
    layer.add(animation, forKey: "blink")
}

private final class StatusBarLabelNode: ASTextNode {
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        addInCallAnimation(self.layer)
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.layer.removeAnimation(forKey: "blink")
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
    private let inCallBackgroundNode = ASDisplayNode()
    private let inCallLabel: StatusBarLabelNode
    
    private var inCallText: String? = nil
    
    public var verticalOffset: CGFloat = 0.0 {
        didSet {
            if !self.verticalOffset.isEqual(to: oldValue) {
                self.offsetNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -self.verticalOffset), size: CGSize())
                self.layer.invalidateUpTheTree()
            }
        }
    }
    
    var alphaUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    public func updateAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        self.alpha = alpha
        self.alphaUpdated?(transition)
    }
    
    public override init() {
        self.inCallLabel = StatusBarLabelNode()
        self.inCallLabel.isUserInteractionEnabled = false
        
        self.offsetNode.isUserInteractionEnabled = false
        
        let labelSize = self.inCallLabel.measure(CGSize(width: 300.0, height: 300.0))
        self.inCallLabel.frame = CGRect(origin: CGPoint(x: 10.0, y: 20.0 + 4.0), size: labelSize)
        
        super.init()
        
        self.setViewBlock({
            return StatusBarView()
        })
        
        (self.view as! StatusBarView).node = self
        
        self.addSubnode(self.offsetNode)
        self.addSubnode(self.inCallBackgroundNode)
        
        self.layer.setTraceableInfo(CATracingLayerInfo(shouldBeAdjustedToInverseTransform: true, userData: self, tracingTag: WindowTracingTags.statusBar, disableChildrenTracingTags: 0))
        
        self.clipsToBounds = true
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateState(statusBar: UIView?, withSafeInsets: Bool, inCallText: String?, animated: Bool) {
        if let statusBar = statusBar {
            self.removeProxyNodeScheduled = false
            let resolvedStyle: StatusBarStyle
            if inCallText != nil && !self.ignoreInCall {
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
        
        var resolvedInCallText: String? = inCallText
        if ignoreInCall {
            resolvedInCallText = nil
        }
        
        if (resolvedInCallText != nil) != (self.inCallText != nil) {
            if let _ = resolvedInCallText {
                if !withSafeInsets {
                    self.addSubnode(self.inCallLabel)
                }
                addInCallAnimation(self.inCallLabel.layer)
                
                self.inCallBackgroundNode.layer.backgroundColor = inCallBackgroundColor.cgColor
                if animated {
                    self.inCallBackgroundNode.layer.animate(from: UIColor.clear.cgColor, to: inCallBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3)
                }
            } else {
                self.inCallLabel.removeFromSupernode()
                
                self.inCallBackgroundNode.layer.backgroundColor = UIColor.clear.cgColor
                if animated {
                    self.inCallBackgroundNode.layer.animate(from: inCallBackgroundColor.cgColor, to: UIColor.clear.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3)
                }
            }
        }
        
        
        if let resolvedInCallText = resolvedInCallText {
            if self.inCallText != resolvedInCallText {
                self.inCallLabel.attributedText = NSAttributedString(string: resolvedInCallText, font: Font.regular(14.0), textColor: .white)
            }
            
            self.layoutInCallLabel()
        }
        
        self.inCallText = resolvedInCallText
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) && self.inCallText != nil {
            return self.view
        } else {
            return nil
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, self.inCallText != nil {
            self.inCallNavigate?()
        }
    }
    
    override public func layout() {
        super.layout()
        
        self.layoutInCallLabel()
    }
    
    override public var frame: CGRect {
        didSet {
            if oldValue.size != self.frame.size {
                let bounds = self.bounds
                self.inCallBackgroundNode.frame = CGRect(origin: CGPoint(), size: bounds.size)
            }
        }
    }
    
    override public var bounds: CGRect {
        didSet {
            if oldValue.size != self.bounds.size {
                let bounds = self.bounds
                self.inCallBackgroundNode.frame = CGRect(origin: CGPoint(), size: bounds.size)
            }
        }
    }
    
    private func layoutInCallLabel() {
        if self.inCallLabel.supernode != nil {
            let size = self.bounds.size
            if !size.width.isZero && !size.height.isZero {
                let labelSize = self.inCallLabel.measure(size)
                self.inCallLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) / 2.0), y: 20.0 + floor((20.0 - labelSize.height) / 2.0)), size: labelSize)
            }
        }
    }
}
