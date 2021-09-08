import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

final class InstantPageFeedbackNode: ASDisplayNode, InstantPageNode {
    private let context: AccountContext
    let webPage: TelegramMediaWebpage
    private let openUrl: (InstantPageUrlItem) -> Void
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    private let labelNode: ASTextNode
    private let viewsNode: ASTextNode
    
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
      
        self.viewsNode = ASTextNode()
        self.viewsNode.isLayerBacked = true
        self.viewsNode.maximumNumberOfLines = 2
        
        super.init()
        
        if case let .Loaded(content) = webPage.content, let views = content.instantPage?.views {
            self.viewsNode.attributedText = NSAttributedString(string: strings.InstantPage_Views(views), font: Font.regular(13.0), textColor: theme.panelSecondaryColor)
        }
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.viewsNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.labelNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.labelNode.alpha = 0.4
                } else {
                    strongSelf.labelNode.alpha = 1.0
                    strongSelf.labelNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    deinit {
        self.resolveDisposable.dispose()
    }
    
    @objc func buttonPressed() {
        self.resolveDisposable.set((self.context.engine.peers.resolvePeerByName(name: "previews") |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self, let _ = peer, let webPageId = strongSelf.webPage.id?.id {
                strongSelf.openUrl(InstantPageUrlItem(url: "https://t.me/previews?start=webpage\(webPageId)", webpageId: nil))
            }
        }))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 16.0
        
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: size.height + UIScreenPixel))
        
        
        let viewsSize = self.viewsNode.measure(CGSize(width: size.width - inset * 2.0, height: size.height))
        self.viewsNode.frame = CGRect(origin: CGPoint(x: inset, y: floorToScreenPixels((size.height - viewsSize.height) / 2.0)), size: viewsSize)
        
        let labelSize = self.labelNode.measure(CGSize(width: size.width - inset * 2.0, height: size.height))
        self.labelNode.frame = CGRect(origin: CGPoint(x: size.width - labelSize.width - inset, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: size.width - labelSize.width - inset * 2.0, y: 0.0), size: size)
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
        self.labelNode.attributedText = NSAttributedString(string: strings.InstantPage_FeedbackButtonShort, font: Font.regular(13.0), textColor: theme.panelSecondaryColor)
        self.viewsNode.attributedText = NSAttributedString(string: self.viewsNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: theme.panelSecondaryColor)
    }
}
