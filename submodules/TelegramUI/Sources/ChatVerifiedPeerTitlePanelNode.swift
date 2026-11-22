import Foundation
import UIKit
import Display
import AsyncDisplayKit
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
import LegacyChatHeaderPanelComponent

private func peerVerificationDescriptionEntities(_ verification: PeerVerification) -> [MessageTextEntity] {
    var result = verification.descriptionEntities
    for entity in generateTextEntities(verification.description, enabledTypes: [.allUrl]) {
        let hasOverlappingLink = result.contains(where: { current in
            switch current.type {
            case .Url, .TextUrl, .Email:
                return current.range.overlaps(entity.range)
            default:
                return false
            }
        })
        if !hasOverlappingLink {
            result.append(entity)
        }
    }
    return result
}

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
            let entities = peerVerificationDescriptionEntities(verification).sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
            let nsDescription = verification.description as NSString
            for entity in entities {
                let url: String?
                switch entity.type {
                case .Url:
                    let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                    if range.location >= 0 && NSMaxRange(range) <= nsDescription.length {
                        url = nsDescription.substring(with: range)
                    } else {
                        url = nil
                    }
                case let .TextUrl(value):
                    url = value
                case .Email:
                    let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                    if range.location >= 0 && NSMaxRange(range) <= nsDescription.length {
                        url = "mailto:\(nsDescription.substring(with: range))"
                    } else {
                        url = nil
                    }
                default:
                    url = nil
                }
                guard let url else {
                    continue
                }
                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: false, presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: {})
                break
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
        
        var panelHeight: CGFloat = 12.0
        
        if let peer = interfaceState.renderedPeer?.peer, let verification = interfaceState.peerVerification {
            if isFirstTime {
                let _ = ApplicationSpecificNotice.setDisplayedPeerVerification(accountManager: self.context.sharedContext.accountManager, peerId: peer.id).start()
            }

            let emojiStatus = PeerEmojiStatus(content: .emoji(fileId: verification.iconFileId), expirationDate: nil)
            let emojiStatusTextNode = self.emojiStatusTextNode

            let textFont = Font.regular(12.0)
            let iconPrefix = "  "
            let iconPrefixLength = (iconPrefix as NSString).length
            let descriptionEntities = peerVerificationDescriptionEntities(verification).map { entity in
                return MessageTextEntity(
                    range: (entity.range.lowerBound + iconPrefixLength) ..< (entity.range.upperBound + iconPrefixLength),
                    type: entity.type
                )
            }
            let attributedText = NSMutableAttributedString(attributedString: stringWithAppliedEntities(
                iconPrefix + verification.description,
                entities: descriptionEntities,
                baseColor: interfaceState.theme.rootController.navigationBar.secondaryTextColor,
                linkColor: interfaceState.theme.rootController.navigationBar.accentTextColor,
                baseFont: textFont,
                linkFont: textFont,
                boldFont: Font.semibold(12.0),
                italicFont: Font.italic(12.0),
                boldItalicFont: Font.semiboldItalic(12.0),
                fixedFont: Font.monospace(12.0),
                blockQuoteFont: textFont,
                underlineLinks: false,
                message: nil,
                paragraphAlignment: .center
            ))
            attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiStatus.fileId, file: nil), range: NSMakeRange(0, 1))
            attributedText.addAttribute(.baselineOffset, value: 1.0, range: NSMakeRange(0, 1))
            
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
            transition.updateFrame(node: emojiStatusTextNode.textNode, frame: CGRect(origin: CGPoint(x: floor((width - emojiStatusLayout.size.width) / 2.0), y: panelHeight + 1.0), size: emojiStatusLayout.size))
            panelHeight += emojiStatusLayout.size.height + 12.0
            
            emojiStatusTextNode.visibilityRect = .infinite
        }

        let initialPanelHeight = panelHeight
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return LayoutResult(backgroundHeight: initialPanelHeight, insetHeight: panelHeight, hitTestSlop: .zero)
    }
}
