import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

private let titleFont = Font.semibold(14.0)

final class ChatOverlayNavigationBar: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let nameDisplayOrder: PresentationPersonNameOrder
    private let tapped: () -> Void
    private let close: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let titleNode: TextNode
    private let closeButton: HighlightableButtonNode
    
    private var validLayout: CGSize?
    
    private var peerTitle = ""
    var peerView: PeerView? {
        didSet {
            var title = ""
            if let peerView = self.peerView {
                if let peer = peerViewMainPeer(peerView) {
                    title = EnginePeer(peer).displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder)
                }
            }
            if self.peerTitle != title {
                self.peerTitle = title
                if let size = self.validLayout {
                    self.updateLayout(size: size, transition: .immediate)
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, tapped: @escaping () -> Void, close: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.tapped = tapped
        self.close = close
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.inAppNotification.expandedNotification.navigationBar.separatorColor
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
       
        let closeImage = generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.inAppNotification.expandedNotification.navigationBar.controlColor.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: 1.0, y: 1.0))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
            context.strokePath()
            context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
            context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
            context.strokePath()
        })
        self.closeButton.setImage(closeImage, for: [])
        
        super.init()
        
        self.backgroundColor = theme.inAppNotification.expandedNotification.navigationBar.backgroundColor
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.closeButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.view.addGestureRecognizer(gestureRecognizer)
    }
        
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        let sideInset: CGFloat = 10.0
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.peerTitle, font: titleFont, textColor: self.theme.inAppNotification.expandedNotification.navigationBar.primaryTextColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: size.width - sideInset * 2.0 - 40.0, height: size.height)))
        let _ = titleApply()
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - titleLayout.size.height) / 2.0)), size: titleLayout.size))
        
        let closeButtonSize = CGSize(width: size.height, height: size.height)
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: size.width - sideInset - closeButtonSize.width + 10.0, y: 0.0), size: closeButtonSize))
    }
    
    @objc private func handleTap() {
        self.tapped()
    }
    
    @objc private func closePressed() {
        self.close()
    }
}
