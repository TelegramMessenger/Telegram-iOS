import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import TelegramStringFormatting
import TextFormat
import Markdown
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import AccountContext
import TelegramNotices

final class ChatVerifiedPeerTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private let separatorNode: ASDisplayNode
    private let emojiStatusTextNode: TextNodeWithEntities
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var theme: PresentationTheme?
        
    private var tapGestureRecognizer: UITapGestureRecognizer?
    
    init(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
                
        self.emojiStatusTextNode = TextNodeWithEntities()
        
        super.init()

        self.addSubnode(self.separatorNode)
        self.addSubnode(self.emojiStatusTextNode.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    @objc private func tapped() {
        guard let navigationController = self.interfaceInteraction?.getNavigationController(), let interfaceState = self.presentationInterfaceState else {
            return
        }
        if let verification = interfaceState.peerVerification {
            let entities = generateTextEntities(verification.description, enabledTypes: [.allUrl])
            if let entity = entities.first {
                let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                let url = (verification.description as NSString).substring(with: range)
                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: false, presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: {})
            }
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        let isFirstTime = self.presentationInterfaceState == nil
        self.presentationInterfaceState = interfaceState
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }
        
        var panelHeight: CGFloat = 8.0
        
        if let peer = interfaceState.renderedPeer?.peer, let verification = interfaceState.peerVerification {
            if isFirstTime {
                let _ = ApplicationSpecificNotice.setDisplayedPeerVerification(accountManager: self.context.sharedContext.accountManager, peerId: peer.id).start()
            }

            let emojiStatus = PeerEmojiStatus(content: .emoji(fileId: verification.iconFileId), expirationDate: nil)
            let emojiStatusTextNode = self.emojiStatusTextNode

            let description = verification.description
            let plainText = "  \(description)"
            let entities = generateTextEntities(plainText, enabledTypes: [.allUrl])
            
            let attributedText = NSMutableAttributedString(attributedString: NSAttributedString(string: plainText, font: Font.regular(12.0), textColor: interfaceState.theme.rootController.navigationBar.secondaryTextColor, paragraphAlignment: .center))
            attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiStatus.fileId, file: nil), range: NSMakeRange(0, 1))
            if let entity = entities.first {
                let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                attributedText.addAttribute(NSAttributedString.Key.foregroundColor, value: interfaceState.theme.rootController.navigationBar.accentTextColor, range: range)
            }
            
            let makeEmojiStatusLayout = TextNodeWithEntities.asyncLayout(emojiStatusTextNode)
            let (emojiStatusLayout, emojiStatusApply) = makeEmojiStatusLayout(TextNodeLayoutArguments(
                attributedString: attributedText,
                backgroundColor: nil,
                minimumNumberOfLines: 0,
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: CGSize(width: width - leftInset * 2.0 - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude),
                alignment: .center,
                verticalAlignment: .top,
                lineSpacing: 0.2,
                cutout: nil,
                insets: UIEdgeInsets(),
                lineColor: nil,
                textShadowColor: nil,
                textStroke: nil,
                displaySpoilers: false,
                displayEmbeddedItemsUnderSpoilers: false
            ))
            let _ = emojiStatusApply(TextNodeWithEntities.Arguments(
                context: self.context,
                cache: self.animationCache,
                renderer: self.animationRenderer,
                placeholderColor: interfaceState.theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            ))
            transition.updateFrame(node: emojiStatusTextNode.textNode, frame: CGRect(origin: CGPoint(x: floor((width - emojiStatusLayout.size.width) / 2.0), y: panelHeight), size: emojiStatusLayout.size))
            panelHeight += emojiStatusLayout.size.height + 8.0
            
            emojiStatusTextNode.visibilityRect = .infinite
        }

        let initialPanelHeight = panelHeight
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return LayoutResult(backgroundHeight: initialPanelHeight, insetHeight: panelHeight, hitTestSlop: .zero)
    }
}
