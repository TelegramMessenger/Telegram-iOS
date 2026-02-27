import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import Markdown
import LocalizedPeerData
import LiveLocationTimerNode

private let titleFont = Font.regular(12.0)
private let subtitleFont = Font.regular(10.0)

enum LocationBroadcastNavigationAccessoryPanelMode {
    case summary
    case peer
}

final class LocationBroadcastNavigationAccessoryPanel: ASDisplayNode {
    private let accountPeerId: EnginePeer.Id
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var nameDisplayOrder: PresentationPersonNameOrder
    
    private let tapAction: () -> Void
    private let close: () -> Void
    
    private let contentNode: ASDisplayNode
    
    private let iconNode: ASImageNode
    private let wavesNode: LiveLocationWavesNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let closeButton: HighlightableButtonNode
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    private var peersAndMode: ([EnginePeer], LocationBroadcastNavigationAccessoryPanelMode, Bool)?
    
    init(accountPeerId: EnginePeer.Id, theme: PresentationTheme, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, tapAction: @escaping () -> Void, close: @escaping () -> Void) {
        self.accountPeerId = accountPeerId
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        
        self.tapAction = tapAction
        self.close = close

        self.contentNode = ASDisplayNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/LiveLocationPanelIcon"), color: theme.chat.inputPanel.panelControlColor)
        
        self.wavesNode = LiveLocationWavesNode(color: self.theme.chat.inputPanel.panelControlColor)
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.setImage(generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.chat.inputPanel.panelControlColor.cgColor)
            context.setLineWidth(1.33)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: 1.0, y: 1.0))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
            context.strokePath()
            context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
            context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
            context.strokePath()
        }), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.contentNode)
        
        self.contentNode.addSubnode(self.iconNode)
        self.contentNode.addSubnode(self.wavesNode)
        self.contentNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.subtitleNode)
        self.contentNode.addSubnode(self.closeButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/LiveLocationPanelIcon"), color: theme.chat.inputPanel.panelControlColor)
        
        self.wavesNode.color = self.theme.chat.inputPanel.panelControlColor
        self.closeButton.setImage(generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.chat.inputPanel.panelControlColor.cgColor)
            context.setLineWidth(1.33)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: 1.0, y: 1.0))
            context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
            context.strokePath()
            context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
            context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
            context.strokePath()
        }), for: [])
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset)
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateAlpha(node: self.contentNode, alpha: isHidden ? 0.0 : 1.0)
        
        let titleString = NSAttributedString(string: self.strings.Conversation_LiveLocation, font: titleFont, textColor: self.theme.rootController.navigationBar.primaryTextColor)
        var subtitleString: NSAttributedString?
        if let (peers, mode, canClose) = self.peersAndMode {
            switch mode {
                case .summary:
                    let text: String
                    if peers.count == 1 {
                        text = self.strings.DialogList_LiveLocationSharingTo(peers[0].displayTitle(strings: self.strings, displayOrder: self.nameDisplayOrder)).string
                    } else {
                        text = self.strings.DialogList_LiveLocationChatsCount(Int32(peers.count))
                    }
                    subtitleString = NSAttributedString(string: text, font: subtitleFont, textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                case .peer:
                    self.closeButton.isHidden = !canClose
                    let filteredPeers = peers.filter {
                        $0.id != self.accountPeerId
                    }
                    if filteredPeers.count == 0 {
                        subtitleString = NSAttributedString(string: self.strings.Conversation_LiveLocationYou, font: subtitleFont, textColor: self.theme.chat.inputPanel.panelControlColor)
                    } else {
                        let otherString: String
                        if filteredPeers.count == 1 {
                            otherString = peers[0].compactDisplayTitle.replacingOccurrences(of: "*", with: "")
                        } else {
                            otherString = self.strings.Conversation_LiveLocationMembersCount(Int32(peers.count))
                        }
                        let rawText: String
                        if filteredPeers.count != peers.count {
                            rawText = self.strings.Conversation_LiveLocationYouAndOther(otherString).string
                        } else {
                            rawText = otherString
                        }
                        let body = MarkdownAttributeSet(font: subtitleFont, textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                        let accent = MarkdownAttributeSet(font: subtitleFont, textColor: self.theme.chat.inputPanel.panelControlColor)
                        subtitleString = parseMarkdownIntoAttributedString(rawText, attributes: MarkdownAttributes(body: body, bold: accent, link: body, linkAttribute: { _ in nil }))
                    }
                        
            }
        }
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: size.width - 80.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: size.width - 80.0, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let _ = titleApply()
        let _ = subtitleApply()
        
        let minimizedTitleOffset: CGFloat = subtitleString == nil ? 6.0 : 0.0
        
        let minimizedTitleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleLayout.size.width) / 2.0), y: 4.0 + minimizedTitleOffset), size: titleLayout.size)
        let minimizedSubtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleLayout.size.width) / 2.0), y: 20.0), size: subtitleLayout.size)
        
        if let image = self.iconNode.image {
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: 7.0 + leftInset, y: 9.0), size: image.size))
            transition.updateFrame(node: self.wavesNode, frame: CGRect(origin: CGPoint(x: -2.0 + leftInset, y: -3.0), size: CGSize(width: 48.0, height: 48.0)))
        }
        
        transition.updateFrame(node: self.titleNode, frame: minimizedTitleFrame)
        transition.updateFrame(node: self.subtitleNode, frame: minimizedSubtitleFrame)
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: bounds.size.width - 18.0 - closeButtonSize.width - rightInset, y: minimizedTitleFrame.minY + 10.0), size: closeButtonSize))
    }
    
    func update(peers: [EnginePeer], mode: LocationBroadcastNavigationAccessoryPanelMode, canClose: Bool) {
        self.peersAndMode = (peers, mode, canClose)
        if let (size, leftInset, rightInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    @objc func closePressed() {
        self.close()
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapAction()
        }
    }
}
