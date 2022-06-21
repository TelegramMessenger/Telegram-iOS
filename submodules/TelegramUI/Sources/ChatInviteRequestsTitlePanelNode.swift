import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import TelegramStringFormatting
import TelegramNotices
import AnimatedAvatarSetNode
import AccountContext
import ChatPresentationInterfaceState

private final class ChatInfoTitlePanelPeerNearbyInfoNode: ASDisplayNode {
    private var theme: PresentationTheme?
    
    private let labelNode: ImmediateTextNode
    private let filledBackgroundNode: LinkHighlightingNode
    
    private let openPeersNearby: () -> Void
    
    init(openPeersNearby: @escaping () -> Void) {
        self.openPeersNearby = openPeersNearby
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.textAlignment = .center
        
        self.filledBackgroundNode = LinkHighlightingNode(color: .clear)
        
        super.init()
        
        self.addSubnode(self.filledBackgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        self.openPeersNearby()
    }
    
    func update(width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, chatPeer: Peer, distance: Int32, transition: ContainedViewLayoutTransition) -> CGFloat {
        let primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
        
        if self.theme !== theme {
            self.theme = theme
            
            self.labelNode.linkHighlightColor = primaryTextColor.withAlphaComponent(0.3)
        }
        
        let topInset: CGFloat = 6.0
        let bottomInset: CGFloat = 6.0
        let sideInset: CGFloat = 16.0
        
        let stringAndRanges = strings.Conversation_PeerNearbyDistance(EnginePeer(chatPeer).compactDisplayTitle, shortStringForDistance(strings: strings, distance: distance))
        
        let attributedString = NSMutableAttributedString(string: stringAndRanges.string, font: Font.regular(13.0), textColor: primaryTextColor)
        
        let boldAttributes = [NSAttributedString.Key.font: Font.semibold(13.0), NSAttributedString.Key(rawValue: "_Link"): true as NSNumber]
        for range in stringAndRanges.ranges.prefix(1) {
            attributedString.addAttributes(boldAttributes, range: range.range)
        }
        
        self.labelNode.attributedText = attributedString
        let labelLayout = self.labelNode.updateLayoutFullInfo(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        var labelRects = labelLayout.linesRects()
        if labelRects.count > 1 {
            let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                            labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            labelRects[index].size.width = labelRects[index + j].size.width
                        }
                    }
                }
            }
        }
        for i in 0 ..< labelRects.count {
            labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
            labelRects[i].size.height = 20.0
            labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
        }
        
        let backgroundLayout = self.filledBackgroundNode.asyncLayout()
        let serviceColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper)
        let backgroundApply = backgroundLayout(serviceColor.fill, labelRects, 10.0, 10.0, 0.0)
        backgroundApply()
        
        let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
        
        let labelFrame = CGRect(origin: CGPoint(x: floor((width - labelLayout.size.width) / 2.0), y: topInset + floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
        self.labelNode.frame = labelFrame
        self.filledBackgroundNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
        
        return topInset + backgroundSize.height + bottomInset
    }
}

final class ChatInviteRequestsTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    
    private let separatorNode: ASDisplayNode
    
    private let closeButton: HighlightableButtonNode
    private var button: UIButton?
    
    private let avatarsContext: AnimatedAvatarSetContext
    private var avatarsContent: AnimatedAvatarSetContext.Content?
    private let avatarsNode: AnimatedAvatarSetNode
    
    private var theme: PresentationTheme?
    
    private var peerId: PeerId?
    private var peers: [EnginePeer] = []
    private var count: Int32 = 0
    
    init(context: AccountContext) {
        self.context = context
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.avatarsContext = AnimatedAvatarSetContext()
        self.avatarsNode = AnimatedAvatarSetNode()
        
        super.init()

        self.addSubnode(self.separatorNode)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.avatarsNode)
    }
    

    func update(peerId: PeerId, peers: [EnginePeer], count: Int32) {
        self.peerId = peerId
        self.peers = peers
        self.count = count
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.avatarsContent = self.avatarsContext.update(peers: peers, animated: false)
        self.button?.setTitle(presentationData.strings.Conversation_RequestsToJoin(count), for: [])
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelEncircledCloseIconImage(interfaceState.theme), for: [])
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }

        let panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 14.0 + rightInset
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize))
        
        if self.button == nil {
            let view = UIButton()
            view.titleLabel?.font = Font.regular(16.0)
            view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor, for: [])
            view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(0.7), for: [.highlighted])
            view.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
            self.view.addSubview(view)
            self.button = view
        }
        
        self.button?.setTitle(interfaceState.strings.Conversation_RequestsToJoin(self.count), for: [])
        
        let maxInset = max(contentRightInset, leftInset)
        let buttonWidth = floor(width - maxInset * 2.0)
        self.button?.frame = CGRect(origin: CGPoint(x: maxInset, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
        
        let initialPanelHeight = panelHeight
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        if let avatarsContent = self.avatarsContent {
            let avatarsSize = self.avatarsNode.update(context: self.context, content: avatarsContent, itemSize: CGSize(width: 32.0, height: 32.0), animated: true, synchronousLoad: true)
            transition.updateFrame(node: self.avatarsNode, frame: CGRect(origin: CGPoint(x: leftInset + 8.0, y: floor((panelHeight - avatarsSize.height) / 2.0)), size: avatarsSize))
        }
        
        return LayoutResult(backgroundHeight: initialPanelHeight, insetHeight: panelHeight)
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.openInviteRequests()
    }
    
    @objc func closePressed() {
        guard let peerId = self.peerId else {
            return
        }

        let ids = peers.map { $0.id.toInt64() }
        let _ = ApplicationSpecificNotice.setDismissedInvitationRequests(accountManager: context.sharedContext.accountManager, peerId: peerId, values: ids).start()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.closeButton.hitTest(CGPoint(x: point.x - self.closeButton.frame.minX, y: point.y - self.closeButton.frame.minY), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
