import Foundation
import UIKit
import AsyncDisplayKit
import Display

enum PasscodeEntryTitleAnimation {
    case none
    case slideIn
    case crossFade
}

final class PasscodeEntryLabelNode: ASDisplayNode {
    private let wrapperNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    
    private var validLayout: CGSize?
    
    override init() {
        self.wrapperNode = ASDisplayNode()
        self.wrapperNode.clipsToBounds = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.isLayerBacked = false
        self.textNode.textAlignment = .center
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.addSubnode(self.wrapperNode)
        self.wrapperNode.addSubnode(self.textNode)
    }
    
    func setAttributedText(_ text: NSAttributedString, animation: PasscodeEntryTitleAnimation = .none, completion: @escaping () -> Void = {}) {
        switch animation {
            case .none:
                self.textNode.attributedText = text
                completion()
            
                if let size = self.validLayout {
                    let _ = self.updateLayout(size: size, transition: .immediate)
                }
            case .slideIn:
                self.textNode.attributedText = text
                if let size = self.validLayout {
                    let _ = self.updateLayout(size: size, transition: .immediate)
                }
            
                let offset = self.wrapperNode.bounds.width / 2.0
                self.wrapperNode.layer.animatePosition(from: CGPoint(x: -offset, y: 0.0), to: CGPoint(), duration: 0.45, additive: true)
                self.textNode.layer.animatePosition(from: CGPoint(x: offset * 2.0, y: 0.0), to: CGPoint(), duration: 0.45, additive: true, completion: { _ in
                    completion()
                })
                self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            case .crossFade:
                if let snapshotView = self.textNode.view.snapshotContentTree() {
                    snapshotView.frame = self.textNode.frame
                    self.textNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.textNode.view)
                    self.textNode.alpha = 0.0
                    self.textNode.attributedText = text
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                        self.textNode.alpha = 1.0
                        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, completion: { _ in
                            completion()
                        })
                        if let size = self.validLayout {
                            let _ = self.updateLayout(size: size, transition: .immediate)
                        }
                    })
                } else {
                    self.textNode.attributedText = text
                    self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    completion()
                    if let size = self.validLayout {
                        let _ = self.updateLayout(size: size, transition: .immediate)
                    }
                }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = size
        
        let textSize = self.textNode.updateLayout(size)
        let textFrame = CGRect(x: floor((size.width - textSize.width) / 2.0), y: 0.0, width: textSize.width, height: textSize.height)
        transition.updateFrame(node: self.wrapperNode, frame: textFrame)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(), size: textSize))
        
        return CGSize(width: size.width, height: max(25.0, textSize.height))
    }
}
