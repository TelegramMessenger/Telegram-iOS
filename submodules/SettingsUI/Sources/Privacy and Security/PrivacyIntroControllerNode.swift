import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AuthorizationUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode

private func generateButtonImage(backgroundColor: UIColor, highlightColor: UIColor?) -> UIImage? {
    return generateImage(CGSize(width: 24.0, height: 44.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 11.0, height: 11.0))
        context.addPath(path.cgPath)
        context.clip()
        
        if let highlightColor = highlightColor {
            context.setFillColor(highlightColor.cgColor)
            context.fill(bounds)
        } else {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(bounds)
        }
    }, opaque: false)?.stretchableImage(withLeftCapWidth: 11, topCapHeight: 11)
}

private let titleFont = Font.bold(17.0)
private let textFont = Font.regular(14.0)
private let buttonFont = Font.regular(17.0)

final class PrivacyIntroControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private let mode: PrivacyIntroControllerMode
    private var presentationData: PresentationData?
    private let proceedAction: () -> Void
    
    private let iconNode: ASImageNode
    private let animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonBackgroundNode: ASImageNode
    private let buttonHighlightedBackgroundNode: ASImageNode
    private let buttonTextNode: ASTextNode
    private let noticeNode: ASTextNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(context: AccountContext, mode: PrivacyIntroControllerMode, proceedAction: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.proceedAction = proceedAction
        
        self.iconNode = ASImageNode()
        self.animationNode = AnimatedStickerNode()
        
        self.titleNode = ASTextNode()
        self.textNode = ASTextNode()
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonBackgroundNode = ASImageNode()
        self.buttonBackgroundNode.contentMode = .scaleToFill
        self.buttonHighlightedBackgroundNode = ASImageNode()
        self.buttonHighlightedBackgroundNode.alpha = 0.0
        self.buttonHighlightedBackgroundNode.contentMode = .scaleToFill
        self.buttonTextNode = ASTextNode()
        self.noticeNode = ASTextNode()
        
        super.init()
        
        if let animationName = mode.animationName {
            self.iconNode.isHidden = true
            self.animationNode.isHidden = false
            
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 380, height: 380, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.animationNode.visibility = true
        } else {
            self.iconNode.isHidden = false
            self.animationNode.isHidden = true
        }
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonBackgroundNode)
        self.addSubnode(self.buttonHighlightedBackgroundNode)
        self.addSubnode(self.buttonTextNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.noticeNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonHighlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonHighlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.buttonHighlightedBackgroundNode.alpha = 0.0
                    strongSelf.buttonHighlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.updatePresentationData(context.sharedContext.currentPresentationData.with { $0 })
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        if self.animationNode.isHidden {
            self.iconNode.image = self.mode.icon(theme: presentationData.theme)
        }
        self.titleNode.attributedText = NSAttributedString(string: self.mode.title(strings: presentationData.strings), font: titleFont, textColor: presentationData.theme.list.sectionHeaderTextColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.mode.text(strings: presentationData.strings), font: textFont, textColor: presentationData.theme.list.freeTextColor, paragraphAlignment: .center)
        self.noticeNode.attributedText = NSAttributedString(string: self.mode.notice(strings: presentationData.strings), font: textFont, textColor: presentationData.theme.list.freeTextColor, paragraphAlignment: .center)
        self.buttonTextNode.attributedText = NSAttributedString(string: self.mode.buttonTitle(strings: presentationData.strings), font: buttonFont, textColor: presentationData.theme.list.itemAccentColor, paragraphAlignment: .center)
        self.buttonTextNode.isAccessibilityElement = false
        self.buttonNode.accessibilityLabel = self.buttonTextNode.attributedText?.string
        self.buttonBackgroundNode.image = generateButtonImage(backgroundColor: presentationData.theme.list.itemBlocksBackgroundColor, highlightColor: nil)
        self.buttonHighlightedBackgroundNode.image = generateButtonImage(backgroundColor: presentationData.theme.list.itemBlocksBackgroundColor, highlightColor: presentationData.theme.list.itemHighlightedBackgroundColor)
        
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight
        
        var iconSize = CGSize()
        var animationSize = CGSize()
        if !self.animationNode.isHidden {
            animationSize = CGSize(width: 180.0, height: 180.0)
            self.animationNode.updateLayout(size: animationSize)
            
            var iconAlpha: CGFloat = 1.0
            if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
                iconAlpha = 0.0
                iconSize = CGSize()
            }
            transition.updateAlpha(node: self.animationNode, alpha: iconAlpha)
        } else if let size = self.iconNode.image?.size {
            iconSize = size
            
            var iconAlpha: CGFloat = 1.0
            if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
                iconAlpha = 0.0
                iconSize = CGSize()
            }
            transition.updateAlpha(node: self.iconNode, alpha: iconAlpha)
        }
        
        let inset: CGFloat = 30.0
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let buttonInset: CGFloat
        if layout.size.width >= 375.0 {
            buttonInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        } else {
            buttonInset = 0.0
        }
            
        let items: [AuthorizationLayoutItem] = [
            AuthorizationLayoutItem(node: self.iconNode, size: iconSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.textNode, size: textSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.buttonNode, size: CGSize(width: layout.size.width - buttonInset * 2.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 40.0, maxValue: 40.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)),
            AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 44.0, maxValue: 44.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 40.0))
        ]
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 10.0)), items: items, transition: transition, failIfDoesNotFit: false)
        
        transition.updateFrame(node: self.buttonBackgroundNode, frame: self.buttonNode.frame)
        transition.updateFrame(node: self.buttonHighlightedBackgroundNode, frame: self.buttonNode.frame)
        
        let buttonTextSize = self.buttonTextNode.measure(layout.size)
        let buttonTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonTextSize.width) / 2.0), y: floor(self.buttonNode.frame.center.y - buttonTextSize.height / 2.0)), size: buttonTextSize)
        transition.updateFrame(node: self.buttonTextNode, frame: buttonTextFrame)
    }
    
    func animateIn(slide: Bool) {
        if slide {
            self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            })
        } else {
            self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.buttonBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.buttonTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.noticeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    @objc func buttonPressed() {
        self.proceedAction()
    }
}
