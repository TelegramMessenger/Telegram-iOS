import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

final class InstantPageFeedbackNode: ASDisplayNode, InstantPageNode {
    private let context: AccountContext
    private let webPage: TelegramMediaWebpage
    private let openUrl: (InstantPageUrlItem) -> Void
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let labelNode: ASTextNode
    
    private let resolveDisposable = MetaDisposable()
    
    init(context: AccountContext, strings: PresentationStrings, theme: InstantPageTheme, webPage: TelegramMediaWebpage, openUrl: @escaping (InstantPageUrlItem) -> Void) {
        self.context = context
        self.webPage = webPage
        self.openUrl = openUrl
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.labelNode = ASTextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.labelNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    deinit {
        self.resolveDisposable.dispose()
    }
    
    @objc func buttonPressed() {
        self.resolveDisposable.set((resolvePeerByName(account: self.context.account, name: "previews") |> deliverOnMainQueue).start(next: { [weak self] peerId in
            if let strongSelf = self, let _ = peerId, let webPageId = strongSelf.webPage.id?.id {
                strongSelf.openUrl(InstantPageUrlItem(url: "https://t.me/previews?start=webpage\(webPageId)", webpageId: nil))
            }
        }))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 15.0
        
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: size.height + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.labelNode.measure(CGSize(width: size.width - inset * 2.0, height: size.height))
        
        self.labelNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.backgroundColor = theme.panelBackgroundColor
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
        self.labelNode.attributedText = NSAttributedString(string: strings.InstantPage_FeedbackButton, font: Font.regular(13.0), textColor: theme.panelSecondaryColor)
    }
}
