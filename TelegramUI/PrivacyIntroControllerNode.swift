import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

private func generateButtonImage(backgroundColor: UIColor, borderColor: UIColor, highlightColor: UIColor?) -> UIImage? {
    return generateImage(CGSize(width: 1.0, height: 44.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        if let highlightColor = highlightColor {
            context.setFillColor(highlightColor.cgColor)
            context.fill(bounds)
        } else {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(bounds)
            
            context.setFillColor(borderColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: 1.0, height: UIScreenPixel)))
        }
    })
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
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonBackgroundNode: ASImageNode
    private let buttonHighlightedBackgroundNode: ASImageNode
    private let buttonTextNode: ASTextNode
    private let noticeNode: ASTextNode
    
    private var validLayout: ContainerViewLayout?
    
    init(context: AccountContext, mode: PrivacyIntroControllerMode, proceedAction: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.proceedAction = proceedAction
        
        self.iconNode = ASImageNode()
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
        
        self.addSubnode(self.iconNode)
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
        
        self.iconNode.image = self.mode.icon(theme: presentationData.theme)
        self.titleNode.attributedText = NSAttributedString(string: self.mode.title(strings: presentationData.strings), font: titleFont, textColor: presentationData.theme.list.sectionHeaderTextColor, paragraphAlignment: .center)
        self.textNode.attributedText = NSAttributedString(string: self.mode.text(strings: presentationData.strings), font: textFont, textColor: presentationData.theme.list.freeTextColor, paragraphAlignment: .center)
        self.noticeNode.attributedText = NSAttributedString(string: self.mode.notice(strings: presentationData.strings), font: textFont, textColor: presentationData.theme.list.freeTextColor, paragraphAlignment: .center)
        self.buttonTextNode.attributedText = NSAttributedString(string: self.mode.buttonTitle(strings: presentationData.strings), font: buttonFont, textColor: presentationData.theme.list.itemAccentColor, paragraphAlignment: .center)
        self.buttonBackgroundNode.image = generateButtonImage(backgroundColor: presentationData.theme.list.itemBlocksBackgroundColor, borderColor: presentationData.theme.list.itemBlocksSeparatorColor, highlightColor: nil)
        self.buttonHighlightedBackgroundNode.image = generateButtonImage(backgroundColor: presentationData.theme.list.itemBlocksBackgroundColor, borderColor: presentationData.theme.list.itemBlocksSeparatorColor, highlightColor: presentationData.theme.list.itemHighlightedBackgroundColor)
        
        if let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout, navigationBarHeight: 0.0, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        if let iconSize = self.iconNode.image?.size {
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: 151.0), size: iconSize))
            
            var iconAlpha: CGFloat = 1.0
            if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
                iconAlpha = 0.0
            }
            transition.updateAlpha(node: self.iconNode, alpha: iconAlpha)
        }
        
        let inset: CGFloat = 30.0
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: 409.0), size: titleSize))
        
        let textSize = self.textNode.measure(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: 441.0), size: textSize))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.noticeNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - noticeSize.width) / 2.0), y: 610.0), size: noticeSize))
        
        let buttonFrame = CGRect(x: 0.0, y: 530.0, width: layout.size.width, height: 44.0)
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonBackgroundNode, frame: buttonFrame)
        transition.updateFrame(node: self.buttonHighlightedBackgroundNode, frame: buttonFrame)
        
        let buttonTextSize = self.buttonTextNode.measure(layout.size)
        let buttonTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonTextSize.width) / 2.0), y: floor(buttonFrame.center.y - buttonTextSize.height / 2.0)), size: buttonTextSize)
        transition.updateFrame(node: self.buttonTextNode, frame: buttonTextFrame)
    }
    
    @objc func buttonPressed() {
        self.proceedAction()
    }
}
