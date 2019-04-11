import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class UndoOverlayControllerNode: ViewControllerTracingNode {
    private let statusNode: RadialStatusNode
    private let timerTextNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let buttonTextNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    private let panelNode: ASDisplayNode
    private let panelWrapperNode: ASDisplayNode
    private let action: (Bool) -> Void
    private let dismiss: () -> Void
    
    private let effectView: UIVisualEffectView
    
    private var remainingSeconds = 5
    private var timer: SwiftSignalKit.Timer?
    
    private var validLayout: ContainerViewLayout?
    
    init(presentationData: PresentationData, text: String, action: @escaping (Bool) -> Void, dismiss: @escaping () -> Void) {
        self.action = action
        self.dismiss = dismiss
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        self.timerTextNode = ImmediateTextNode()
        self.timerTextNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: .white)
        
        self.buttonTextNode = ImmediateTextNode()
        self.buttonTextNode.displaysAsynchronously = false
        self.buttonTextNode.attributedText = NSAttributedString(string: presentationData.strings.Undo_Undo, font: Font.regular(17.0), textColor: UIColor(rgb: 0x5ac8fa))
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.panelNode = ASDisplayNode()
        self.panelNode.backgroundColor = .clear
        self.panelNode.clipsToBounds = true
        self.panelNode.cornerRadius = 9.0
        
        self.panelWrapperNode = ASDisplayNode()
        
        self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        
        super.init()
        
        self.panelWrapperNode.addSubnode(self.timerTextNode)
        self.panelWrapperNode.addSubnode(self.statusNode)
        self.panelWrapperNode.addSubnode(self.textNode)
        self.panelWrapperNode.addSubnode(self.buttonTextNode)
        self.panelWrapperNode.addSubnode(self.buttonNode)
        self.addSubnode(self.panelNode)
        self.addSubnode(self.panelWrapperNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonTextNode.alpha = 0.4
                } else {
                    strongSelf.buttonTextNode.alpha = 1.0
                    strongSelf.buttonTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.checkTimer()
    }
    
    override func didLoad() {
        super.didLoad()
        self.panelNode.view.addSubview(self.effectView)
    }
    
    @objc private func buttonPressed() {
        self.action(false)
        self.dismiss()
    }
    
    private func checkTimer() {
        if self.timer != nil {
            self.remainingSeconds -= 1
        }
        if self.remainingSeconds == 0 {
            self.action(true)
            self.dismiss()
        } else {
            if !self.timerTextNode.bounds.size.width.isZero, let snapshot = self.timerTextNode.view.snapshotContentTree() {
                self.panelNode.view.insertSubview(snapshot, aboveSubview: self.timerTextNode.view)
                snapshot.frame = self.timerTextNode.frame
                self.timerTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                self.timerTextNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -10.0), to: CGPoint(), duration: 0.12, removeOnCompletion: false, additive: true)
                snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false)
                snapshot.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 10.0), duration: 0.12, removeOnCompletion: false, additive: true, completion: { [weak snapshot] _ in
                    snapshot?.removeFromSuperview()
                })
            }
            self.timerTextNode.attributedText = NSAttributedString(string: "\(self.remainingSeconds)", font: Font.regular(16.0), textColor: .white)
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(layout: validLayout, transition: .immediate)
            }
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                self?.checkTimer()
            }, queue: .mainQueue())
            self.timer = timer
            timer.start()
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil
        self.validLayout = layout
        
        let leftInset: CGFloat = 50.0
        let rightInset: CGFloat = 16.0
        let contentHeight: CGFloat = 49.0
        let margin: CGFloat = 16.0
        
        let insets = layout.insets(options: [.input])
        
        let panelFrame = CGRect(origin: CGPoint(x: margin + layout.safeInsets.left, y: layout.size.height - contentHeight - insets.bottom - margin - 49.0), size: CGSize(width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight))
        let panelWrapperFrame = CGRect(origin: CGPoint(x: margin + layout.safeInsets.left, y: layout.size.height - contentHeight - insets.bottom - margin - 49.0), size: CGSize(width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight))
        transition.updateFrame(node: self.panelNode, frame: panelFrame)
        transition.updateFrame(node: self.panelWrapperNode, frame: panelWrapperFrame)
        self.effectView.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width - margin * 2.0 - layout.safeInsets.left - layout.safeInsets.right, height: contentHeight)
        
        let buttonTextSize = self.buttonTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        let buttonTextFrame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - rightInset - buttonTextSize.width - margin * 2.0, y: floor((contentHeight - buttonTextSize.height) / 2.0)), size: buttonTextSize)
        transition.updateFrame(node: self.buttonTextNode, frame: buttonTextFrame)
        self.buttonNode.frame = CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - rightInset - buttonTextSize.width - 8.0 - margin * 2.0, y: 0.0), size: CGSize(width: layout.safeInsets.right + rightInset + buttonTextSize.width + 8.0 + margin, height: contentHeight))
        
        let textSize = self.textNode.updateLayout(CGSize(width: buttonTextFrame.minX - 8.0 - leftInset - layout.safeInsets.left - layout.safeInsets.right - margin * 2.0, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset, y: floor((contentHeight - textSize.height) / 2.0)), size: textSize))
        
        let timerTextSize = self.timerTextNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.timerTextNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - timerTextSize.width) / 2.0), y: floor((contentHeight - timerTextSize.height) / 2.0)), size: timerTextSize))
        let statusSize: CGFloat = 30.0
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: floor((leftInset - statusSize) / 2.0), y: floor((contentHeight - statusSize) / 2.0)), size: CGSize(width: statusSize, height: statusSize)))
        if firstLayout {
            self.statusNode.transitionToState(.secretTimeout(color: .white, icon: nil, beginTime: CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970, timeout: Double(self.remainingSeconds), sparks: false), completion: {})
        }
    }
    
    func animateIn() {
        self.panelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.panelWrapperNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.panelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, delay: 0.0, timingFunction: kCAMediaTimingFunctionEaseOut, removeOnCompletion: false, completion: { _ in })
        self.panelWrapperNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, delay: 0.0, timingFunction: kCAMediaTimingFunctionEaseOut, removeOnCompletion: false) { _ in
            completion()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.panelNode.frame.insetBy(dx: -60.0, dy: 0.0).contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
