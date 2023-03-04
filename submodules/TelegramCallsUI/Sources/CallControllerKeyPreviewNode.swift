import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import LegacyComponents
import Emoji

private let emojiFont = Font.regular(28.0)
private let textFont = Font.regular(15.0)

final class CallControllerKeyPreviewNode: ASDisplayNode {
    private let modalContainer: ASDisplayNode
    private let backgroundLayer: SimpleLayer
    private let buttonBackgroundLayer: SimpleLayer
    private let separatorLayer: SimpleLayer
    
    private let contentNode: ASDisplayNode
    private let keyTextNode: ASTextNode
    private let titleTextNode: ASTextNode
    private let infoTextNode: ASTextNode
    private let okButtonNode: ASButtonNode
    
    private let dismiss: () -> Void
    
    init(keyText: String, infoText: String, dismiss: @escaping () -> Void) {
        self.backgroundLayer = SimpleLayer()
        self.buttonBackgroundLayer = SimpleLayer()
        self.separatorLayer = SimpleLayer()
        
        self.modalContainer = ASDisplayNode()
        self.modalContainer.displaysAsynchronously = false
        self.keyTextNode = ASTextNode()
        self.keyTextNode.displaysAsynchronously = false
        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        self.infoTextNode = ASTextNode()
        self.infoTextNode.displaysAsynchronously = false
        self.okButtonNode = ASButtonNode()
        self.okButtonNode.displaysAsynchronously = false
        
        self.dismiss = dismiss
        self.contentNode = ASDisplayNode()
        
        super.init()
        
        
        backgroundLayer.backgroundColor = UIColor.white.withAlphaComponent(0.25).cgColor
        buttonBackgroundLayer.backgroundColor = UIColor.white.withAlphaComponent(0.25).cgColor
        separatorLayer.backgroundColor = UIColor.clear.cgColor
        
        self.keyTextNode.attributedText = NSAttributedString(string: keyText, attributes: [NSAttributedString.Key.font: Font.regular(38.0), NSAttributedString.Key.kern: 11.0 as NSNumber])
        
        self.titleTextNode.attributedText = NSAttributedString(string: "This call is end-to end encrypted", font: Font.bold(16), textColor: UIColor.white, paragraphAlignment: .center)
        
        self.infoTextNode.attributedText = NSAttributedString(string: infoText, font: Font.regular(14.0), textColor: UIColor.white, paragraphAlignment: .center)
        
        self.okButtonNode.setTitle("OK", with: Font.regular(20), with: .white, for: .normal)
        self.layer.addSublayer(separatorLayer)
        self.contentNode.layer.addSublayer(backgroundLayer)
        self.contentNode.addSubnode(self.keyTextNode)
        self.contentNode.addSubnode(self.titleTextNode)
        self.contentNode.addSubnode(self.infoTextNode)
        
        modalContainer.addSubnode(contentNode)
        modalContainer.addSubnode(okButtonNode)
        
        self.okButtonNode.layer.addSublayer(buttonBackgroundLayer)
        
        self.addSubnode(modalContainer)
        okButtonNode.addTarget(self, action: #selector(okTap), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let contentNodeSize = self.contentNode.measure(CGSize(width: size.width - 90, height: 170))
        transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: 0, y: 0), size: contentNodeSize))
        
        let roundPath = UIBezierPath(
            roundedRect: contentNode.bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        let maskLayer = CAShapeLayer()
        maskLayer.path = roundPath.cgPath
        self.backgroundLayer.mask = maskLayer
        self.backgroundLayer.frame = contentNode.bounds
        
        let keyTextSize = self.keyTextNode.measure(CGSize(width: contentNodeSize.width - 32, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.keyTextNode, frame: CGRect(origin: CGPoint(x: floor((contentNodeSize.width - keyTextSize.width) / 2.0), y: 20), size: keyTextSize))
        
        let titleTextSize = self.titleTextNode.measure(CGSize(width: contentNodeSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleTextNode, frame: CGRect(origin: CGPoint(x: floor((contentNodeSize.width - titleTextSize.width) / 2.0), y: keyTextNode.frame.origin.y + keyTextNode.frame.height + 10), size: titleTextSize))
        
        let infoTextSize = self.infoTextNode.measure(CGSize(width: contentNodeSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.infoTextNode, frame: CGRect(origin: CGPoint(x: floor((contentNodeSize.width - infoTextSize.width) / 2.0), y: titleTextNode.frame.origin.y + titleTextNode.frame.height + 10), size: infoTextSize))
        
        transition.updateFrame(layer: separatorLayer, frame: CGRect(origin: CGPoint(x: 0, y: contentNode.frame.origin.y + contentNodeSize.height), size: CGSize(width: contentNodeSize.width, height: 1)))
        
        transition.updateFrame(node: okButtonNode, frame: CGRect(origin: CGPoint(x: 0, y: separatorLayer.frame.origin.y + separatorLayer.frame.height), size: CGSize(width: contentNodeSize.width, height: 55)))
        
        let roundButtonPath = UIBezierPath(
            roundedRect: okButtonNode.bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        let buttomMaskLayer = CAShapeLayer()
        buttomMaskLayer.path = roundButtonPath.cgPath
        self.buttonBackgroundLayer.mask = buttomMaskLayer
        buttonBackgroundLayer.frame = okButtonNode.bounds
        
        transition.updateFrame(node: modalContainer, frame: CGRect(origin: CGPoint(x: size.width / 2 - contentNodeSize.width / 2, y: 100), size: CGSize(width: contentNodeSize.width, height: okButtonNode.frame.origin.y + okButtonNode.frame.height)))
    }
    
    func animateIn(from rect: CGRect, fromNode: ASDisplayNode) {
        self.modalContainer.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.modalContainer.layer.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        if let transitionView = fromNode.view.snapshotView(afterScreenUpdates: false) {
            self.view.addSubview(transitionView)
            transitionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            transitionView.layer.animatePosition(from: CGPoint(x: rect.midX, y: rect.midY), to: self.modalContainer.layer.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak transitionView] _ in
                transitionView?.removeFromSuperview()
            })
            transitionView.layer.animateScale(from: 1.0, to: self.modalContainer.frame.size.width / rect.size.width, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        
        self.modalContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    func animateOut(to rect: CGRect, toNode: ASDisplayNode, completion: @escaping () -> Void) {
        self.modalContainer.layer.animatePosition(from: self.modalContainer.layer.position, to: CGPoint(x: rect.midX + 2.0, y: rect.midY), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.modalContainer.layer.animateScale(from: 1.0, to: rect.size.width / (self.modalContainer.frame.size.width - 2.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.modalContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
    }
    
    @objc func okTap() {
        dismiss()
    }
}

