import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AnimatedStickerNode

final class ToastNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let effectView: UIView
    private let animationNode: AnimatedStickerNode
    private let textNode: ImmediateTextNode
    
    init(theme: WalletTheme, animationPath: String, text: String) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.cornerRadius = 9.0
        self.backgroundNode.clipsToBounds = true
        if case .dark = theme.keyboardAppearance {
            self.backgroundNode.backgroundColor = theme.navigationBar.backgroundColor
        } else {
            self.backgroundNode.backgroundColor = .clear
        }
        
        self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.backgroundNode.view.addSubview(self.effectView)
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.visibility = true
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: animationPath), width: 100, height: 100, playbackMode: .once, mode: .direct)
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
        self.textNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.textNode)
    }
    
    func update(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let contentSideInset: CGFloat = 10.0
        let contentVerticalInset: CGFloat = 8.0
        let iconSpacing: CGFloat = 4.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - contentSideInset * 2.0, height: .greatestFiniteMagnitude))
        let iconSize = CGSize(width: 32.0, height: 32.0)
        
        let contentSize = CGSize(width: iconSize.width + iconSpacing + textSize.width, height: max(iconSize.height, textSize.height))
        
        let insets = layout.insets(options: .input)
        let contentOriginX = floor((layout.size.width - contentSize.width) / 2.0)
        let contentOriginY = insets.top + floor((layout.size.height - insets.top - insets.bottom - contentSize.height) / 2.0)
        
        let iconFrame = CGRect(origin: CGPoint(x: contentOriginX, y: contentOriginY + floor((contentSize.height - iconSize.height) / 2.0)), size: iconSize)
        transition.updateFrame(node: self.animationNode, frame: iconFrame)
        self.animationNode.updateLayout(size: iconFrame.size)
        
        let textFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + iconSpacing, y: contentOriginY + floor((contentSize.height - textSize.height) / 2.0)), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: contentOriginX - contentSideInset, y: contentOriginY - contentVerticalInset), size: CGSize(width: contentSize.width + contentSideInset * 2.0, height: contentSize.height + contentVerticalInset * 2.0))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
    
    func show(removed: @escaping () -> Void) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 3.0, removeOnCompletion: false, completion: { _ in
            removed()
        })
    }
}
