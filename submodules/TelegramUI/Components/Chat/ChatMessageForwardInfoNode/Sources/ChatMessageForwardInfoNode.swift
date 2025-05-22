import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import AccountContext
import AvatarNode
import TextLoadingEffect
import SwiftSignalKit

public enum ChatMessageForwardInfoType: Equatable {
    case bubble(incoming: Bool)
    case standalone
}

private final class InfoButtonNode: HighlightableButtonNode {
    private let pressed: () -> Void
    let iconNode: ASImageNode
    
    private var theme: ChatPresentationThemeData?
    private var type: ChatMessageForwardInfoType?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.iconNode)
        
        self.addTarget(self, action: #selector(self.pressedEvent), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressedEvent() {
        self.pressed()
    }
    
    func update(size: CGSize, theme: ChatPresentationThemeData, type: ChatMessageForwardInfoType) {
        if self.theme !== theme || self.type != type {
            self.theme = theme
            self.type = type
            let color: UIColor
            switch type {
            case let .bubble(incoming):
                color = incoming ? theme.theme.chat.message.incoming.accentControlColor : theme.theme.chat.message.outgoing.accentControlColor
            case .standalone:
                let serviceColor = serviceMessageColorComponents(theme: theme.theme, wallpaper: theme.wallpaper)
                color = serviceColor.primaryText
            }
            self.iconNode.image = PresentationResourcesChat.chatPsaInfo(theme.theme, color: color.argb)
        }
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
    }
}

public class ChatMessageForwardInfoNode: ASDisplayNode {
    public enum StoryType {
        case regular
        case expired
        case unavailable
    }
    
    public struct StoryData: Equatable {
        public var storyType: StoryType
        
        public init(storyType: StoryType) {
            self.storyType = storyType
        }
    }
    
    public private(set) var titleNode: TextNode?
    public private(set) var nameNode: TextNode?
    private var credibilityIconNode: ASImageNode?
    private var infoNode: InfoButtonNode?
    private var expiredStoryIconView: UIImageView?
    private var avatarNode: AvatarNode?
    
    private var theme: PresentationTheme?
    private var highlightColor: UIColor?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var hasLinkProgress: Bool = false
    private var linkProgressView: TextLoadingEffectView?
    private var linkProgressDisposable: Disposable?
    
    private var previousPeer: Peer?
    
    public var openPsa: ((String, ASDisplayNode) -> Void)?
    
    override public init() {
        super.init()
    }
    
    deinit {
        self.linkProgressDisposable?.dispose()
    }
    
    public func hasAction(at point: CGPoint) -> Bool {
        if let infoNode = self.infoNode, infoNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
    
    public func updatePsaButtonDisplay(isVisible: Bool, animated: Bool) {
        if let infoNode = self.infoNode {
            if isVisible != !infoNode.iconNode.alpha.isZero {
                let transition: ContainedViewLayoutTransition
                if animated {
                    transition = .animated(duration: 0.25, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                transition.updateAlpha(node: infoNode.iconNode, alpha: isVisible ? 1.0 : 0.0)
                transition.updateSublayerTransformScale(node: infoNode, scale: isVisible ? 1.0 : 0.1)
            }
        }
    }
    
    public func getBoundingRects() -> [CGRect] {
        var initialRects: [CGRect] = []
        let addRects: (TextNode, CGPoint, CGFloat) -> Void = { textNode, offset, additionalWidth in
            guard let cachedLayout = textNode.cachedLayout else {
                return
            }
            for rect in cachedLayout.linesRects() {
                var rect = rect
                rect.size.width += rect.origin.x + additionalWidth
                rect.origin.x = 0.0
                initialRects.append(rect.offsetBy(dx: offset.x, dy: offset.y))
            }
        }
        
        let offsetY: CGFloat = -12.0
        if let titleNode = self.titleNode {
            addRects(titleNode, CGPoint(x: titleNode.frame.minX, y: offsetY + titleNode.frame.minY), 0.0)
            
            if let nameNode = self.nameNode {
                addRects(nameNode, CGPoint(x: titleNode.frame.minX, y: offsetY + nameNode.frame.minY), nameNode.frame.minX - titleNode.frame.minX)
            }
        }
        
        return initialRects
    }
    
    public func updateTouchesAtPoint(_ point: CGPoint?) {
        var isHighlighted = false
        if point != nil {
            isHighlighted = true
        }
        
        var initialRects: [CGRect] = []
        let addRects: (TextNode, CGPoint, CGFloat) -> Void = { textNode, offset, additionalWidth in
            guard let cachedLayout = textNode.cachedLayout else {
                return
            }
            for rect in cachedLayout.linesRects() {
                var rect = rect
                rect.size.width += rect.origin.x + additionalWidth
                rect.origin.x = 0.0
                initialRects.append(rect.offsetBy(dx: offset.x, dy: offset.y))
            }
        }
        
        let offsetY: CGFloat = -12.0
        if let titleNode = self.titleNode {
            addRects(titleNode, CGPoint(x: titleNode.frame.minX, y: offsetY + titleNode.frame.minY), 0.0)
            
            if let nameNode = self.nameNode {
                addRects(nameNode, CGPoint(x: titleNode.frame.minX, y: offsetY + nameNode.frame.minY), nameNode.frame.minX - titleNode.frame.minX)
            }
        }
        
        if isHighlighted, !initialRects.isEmpty, let highlightColor = self.highlightColor {
            let rects = initialRects
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: highlightColor)
                self.linkHighlightingNode = linkHighlightingNode
                self.addSubnode(linkHighlightingNode)
            }
            linkHighlightingNode.frame = self.bounds
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
    }
    
    public func makeActivate() -> (() -> Promise<Bool>?)? {
        return { [weak self] in
            guard let self else {
                return nil
            }
            
            let promise = Promise<Bool>()
            self.linkProgressDisposable?.dispose()
            
            if self.hasLinkProgress {
                self.hasLinkProgress = false
                self.updateLinkProgressState()
            }
            
            self.linkProgressDisposable = (promise.get() |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                guard let self else {
                    return
                }
                if self.hasLinkProgress != value {
                    self.hasLinkProgress = value
                    self.updateLinkProgressState()
                }
            })
            
            return promise
        }
    }
    
    private func updateLinkProgressState() {
        guard let highlightColor = self.highlightColor else {
            return
        }
        
        if self.hasLinkProgress, let titleNode = self.titleNode, let nameNode = self.nameNode {
            var initialRects: [CGRect] = []
            let addRects: (TextNode, CGPoint, CGFloat) -> Void = { textNode, offset, additionalWidth in
                guard let cachedLayout = textNode.cachedLayout else {
                    return
                }
                for rect in cachedLayout.linesRects() {
                    var rect = rect
                    rect.size.width += rect.origin.x + additionalWidth
                    rect.origin.x = 0.0
                    initialRects.append(rect.offsetBy(dx: offset.x, dy: offset.y))
                }
            }
            
            let offsetY: CGFloat = -12.0
            if let titleNode = self.titleNode {
                addRects(titleNode, CGPoint(x: titleNode.frame.minX, y: offsetY + titleNode.frame.minY), 0.0)
                
                if let nameNode = self.nameNode {
                    addRects(nameNode, CGPoint(x: titleNode.frame.minX, y: offsetY + nameNode.frame.minY), nameNode.frame.minX - titleNode.frame.minX)
                }
            }
            
            let linkProgressView: TextLoadingEffectView
            if let current = self.linkProgressView {
                linkProgressView = current
            } else {
                linkProgressView = TextLoadingEffectView(frame: CGRect())
                self.linkProgressView = linkProgressView
                self.view.addSubview(linkProgressView)
            }
            linkProgressView.frame = titleNode.frame
            
            let progressColor: UIColor = highlightColor
            
            linkProgressView.update(color: progressColor, size: CGRectUnion(titleNode.frame, nameNode.frame).size, rects: initialRects)
        } else {
            if let linkProgressView = self.linkProgressView {
                self.linkProgressView = nil
                linkProgressView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak linkProgressView] _ in
                    linkProgressView?.removeFromSuperview()
                })
            }
        }
    }
    
    public static func asyncLayout(_ maybeNode: ChatMessageForwardInfoNode?) -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ strings: PresentationStrings, _ type: ChatMessageForwardInfoType, _ peer: Peer?, _ authorName: String?, _ psaType: String?, _ storyData: StoryData?, _ constrainedSize: CGSize) -> (CGSize, (CGFloat) -> ChatMessageForwardInfoNode) {
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let nameNodeLayout = TextNode.asyncLayout(maybeNode?.nameNode)
        
        let previousPeer = maybeNode?.previousPeer
        
        return { context, presentationData, strings, type, peer, authorName, psaType, storyData, constrainedSize in
            let originalPeer = peer
            let peer = peer ?? previousPeer
            
            let fontSize = floor(presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let prefixFont = Font.regular(fontSize)
            let peerFont = Font.medium(fontSize)
            
            let peerString: String
            if let peer = peer {
                if let authorName = authorName, originalPeer === peer {
                    peerString = "\(EnginePeer(peer).displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)) (\(authorName))"
                } else {
                    peerString = EnginePeer(peer).displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)
                }
            } else if let authorName = authorName {
                peerString = authorName
            } else {
                peerString = ""
            }
            
            var hasPsaInfo = false
            if let _ = psaType {
                hasPsaInfo = true
            }
            
            let titleColor: UIColor
            let titleString: PresentationStrings.FormattedString
            var authorString: String?
            
            switch type {
            case let .bubble(incoming):
                if let psaType = psaType {
                    titleColor = incoming ? presentationData.theme.theme.chat.message.incoming.polls.barPositive : presentationData.theme.theme.chat.message.outgoing.polls.barPositive
                    
                    var customFormat: String?
                    let key = "Message.ForwardedPsa.\(psaType)"
                    if let string = presentationData.strings.primaryComponent.dict[key] {
                        customFormat = string
                    } else if let string = presentationData.strings.secondaryComponent?.dict[key] {
                        customFormat = string
                    }
                    
                    if let customFormat = customFormat {
                        if let range = customFormat.range(of: "%@") {
                            let leftPart = String(customFormat[customFormat.startIndex ..< range.lowerBound])
                            let rightPart = String(customFormat[range.upperBound...])
                            
                            let formattedText = leftPart + peerString + rightPart
                            titleString = PresentationStrings.FormattedString(string: formattedText, ranges: [PresentationStrings.FormattedString.Range(index: 0, range: NSRange(location: leftPart.count, length: peerString.count))])
                        } else {
                            titleString = PresentationStrings.FormattedString(string: customFormat, ranges: [])
                        }
                    } else {
                        titleString = strings.Message_GenericForwardedPsa(peerString)
                    }
                } else {
                    if incoming {
                        if let nameColor = peer?.nameColor {
                            titleColor = context.peerNameColors.get(nameColor, dark: presentationData.theme.theme.overallDarkAppearance).main
                        } else {
                            titleColor = presentationData.theme.theme.chat.message.incoming.accentTextColor
                        }
                    } else {
                        titleColor = presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    }
                    
                    if let storyData = storyData {
                        switch storyData.storyType {
                        case .regular:
                            titleString = PresentationStrings.FormattedString(string: presentationData.strings.Chat_MessageForwardInfo_StoryHeader, ranges: [])
                            authorString = peerString
                        case .expired:
                            titleString = PresentationStrings.FormattedString(string: presentationData.strings.Chat_MessageForwardInfo_ExpiredStoryHeader, ranges: [])
                            authorString = peerString
                        case .unavailable:
                            titleString = PresentationStrings.FormattedString(string: presentationData.strings.Chat_MessageForwardInfo_UnavailableStoryHeader, ranges: [])
                            authorString = peerString
                        }
                    } else {
                        titleString = PresentationStrings.FormattedString(string: presentationData.strings.Chat_MessageForwardInfo_MessageHeader, ranges: [])
                        authorString = peerString
                    }
                }
            case .standalone:
                let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                titleColor = serviceColor.primaryText
                
                if let psaType = psaType {
                    var customFormat: String?
                    let key = "Message.ForwardedPsa.\(psaType)"
                    if let string = presentationData.strings.primaryComponent.dict[key] {
                        customFormat = string
                    } else if let string = presentationData.strings.secondaryComponent?.dict[key] {
                        customFormat = string
                    }
                    
                    if let customFormat = customFormat {
                        if let range = customFormat.range(of: "%@") {
                            let leftPart = String(customFormat[customFormat.startIndex ..< range.lowerBound])
                            let rightPart = String(customFormat[range.upperBound...])
                            
                            let formattedText = leftPart + peerString + rightPart
                            titleString = PresentationStrings.FormattedString(string: formattedText, ranges: [PresentationStrings.FormattedString.Range(index: 0, range: NSRange(location: leftPart.count, length: peerString.count))])
                        } else {
                            titleString = PresentationStrings.FormattedString(string: customFormat, ranges: [])
                        }
                    } else {
                        titleString = strings.Message_GenericForwardedPsa(peerString)
                    }
                } else {
                    titleString = PresentationStrings.FormattedString(string: presentationData.strings.Chat_MessageForwardInfo_MessageHeader, ranges: [])
                    authorString = peerString
                }
            }
            
            var currentCredibilityIconImage: UIImage?
            var highlight = true
            if let peer = peer {
                if let channel = peer as? TelegramChannel, channel.addressName == nil {
                    if case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
                    } else if case .member = channel.participationStatus {
                    } else {
                        highlight = false
                    }
                }
                
                if peer.isFake {
                    switch type {
                    case let .bubble(incoming):
                        currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(presentationData.theme.theme, strings: presentationData.strings, type: incoming ? .regular : .outgoing)
                    case .standalone:
                        currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(presentationData.theme.theme, strings: presentationData.strings, type: .service)
                    }
                } else if peer.isScam {
                    switch type {
                    case let .bubble(incoming):
                        currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(presentationData.theme.theme, strings: presentationData.strings, type: incoming ? .regular : .outgoing)
                    case .standalone:
                        currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(presentationData.theme.theme, strings: presentationData.strings, type: .service)
                    }
                } else {
                    currentCredibilityIconImage = nil
                }
            } else {
                highlight = false
            }
            
            let rawTitleString: NSString = titleString.string as NSString
            let string = NSMutableAttributedString(string: rawTitleString as String, attributes: [NSAttributedString.Key.foregroundColor: titleColor, NSAttributedString.Key.font: prefixFont])
            if highlight, let range = titleString.ranges.first?.range {
                string.addAttributes([NSAttributedString.Key.font: peerFont], range: range)
            }
            
            var credibilityIconWidth: CGFloat = 0.0
            if let icon = currentCredibilityIconImage {
                credibilityIconWidth += icon.size.width + 4.0
            }
            
            var infoWidth: CGFloat = 0.0
            if hasPsaInfo {
                infoWidth += 32.0
            }
            let leftOffset: CGFloat = 0.0
            infoWidth += leftOffset
            
            var cutout: TextNodeCutout?
            if let storyData {
                switch storyData.storyType {
                case .regular, .unavailable:
                    break
                case .expired:
                    cutout = TextNodeCutout(topLeft: CGSize(width: 16.0, height: 10.0))
                }
            }
            
            let (titleLayout, titleApply) = titleNodeLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - credibilityIconWidth - infoWidth, height: constrainedSize.height), alignment: .natural, cutout: cutout, insets: UIEdgeInsets()))
            
            var authorAvatarInset: CGFloat = 0.0
            authorAvatarInset = 20.0
            
            var nameLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let authorString {
                nameLayoutAndApply = nameNodeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: authorString, font: peer != nil ? peerFont : prefixFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - credibilityIconWidth - infoWidth - authorAvatarInset, height: constrainedSize.height), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            }
            
            let titleAuthorSpacing: CGFloat = 0.0
            
            let resultSize: CGSize
            if let nameLayoutAndApply {
                resultSize = CGSize(
                    width: max(
                        titleLayout.size.width + credibilityIconWidth + infoWidth,
                        authorAvatarInset + nameLayoutAndApply.0.size.width
                    ),
                    height: titleLayout.size.height + titleAuthorSpacing + nameLayoutAndApply.0.size.height
                )
            } else {
                resultSize = CGSize(width: titleLayout.size.width + credibilityIconWidth + infoWidth, height: titleLayout.size.height)
            }
            
            return (resultSize, { width in
                let node: ChatMessageForwardInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageForwardInfoNode()
                }
                
                node.theme = presentationData.theme.theme
                node.highlightColor = titleColor.withMultipliedAlpha(0.1)
                
                node.previousPeer = peer
                
                let titleNode = titleApply()
                titleNode.displaysAsynchronously = !presentationData.isPreview
                
                if node.titleNode == nil {
                    titleNode.isUserInteractionEnabled = false
                    node.titleNode = titleNode
                    node.addSubnode(titleNode)
                }
                titleNode.frame = CGRect(origin: CGPoint(x: leftOffset, y: 0.0), size: titleLayout.size)
                
                if let (nameLayout, nameApply) = nameLayoutAndApply {
                    let nameNode = nameApply()
                    if node.nameNode == nil {
                        nameNode.isUserInteractionEnabled = false
                        node.nameNode = nameNode
                        node.addSubnode(nameNode)
                    }
                    nameNode.frame = CGRect(origin: CGPoint(x: leftOffset + authorAvatarInset, y: titleLayout.size.height + titleAuthorSpacing), size: nameLayout.size)
                    
                    if authorAvatarInset != 0.0 {
                        let avatarNode: AvatarNode
                        if let current = node.avatarNode {
                            avatarNode = current
                        } else {
                            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                            node.avatarNode = avatarNode
                            node.addSubnode(avatarNode)
                        }
                        let avatarSize = CGSize(width: 16.0, height: 16.0)
                        avatarNode.frame = CGRect(origin: CGPoint(x: leftOffset, y: titleLayout.size.height + titleAuthorSpacing), size: avatarSize)
                        avatarNode.updateSize(size: avatarSize)
                        if let peer {
                            if peer.smallProfileImage != nil {
                                avatarNode.setPeerV2(context: context, theme: presentationData.theme.theme, peer: EnginePeer(peer), displayDimensions: avatarSize)
                            } else {
                                avatarNode.setPeer(context: context, theme: presentationData.theme.theme, peer: EnginePeer(peer), displayDimensions: avatarSize)
                            }
                        } else if let authorName, !authorName.isEmpty {
                            avatarNode.setCustomLetters([String(authorName[authorName.startIndex])])
                        } else {
                            avatarNode.setCustomLetters([" "])
                        }
                    } else {
                        if let avatarNode = node.avatarNode {
                            node.avatarNode = nil
                            avatarNode.removeFromSupernode()
                        }
                    }
                } else {
                    if let nameNode = node.nameNode {
                        node.nameNode = nil
                        nameNode.removeFromSupernode()
                    }
                    if let avatarNode = node.avatarNode {
                        node.avatarNode = nil
                        avatarNode.removeFromSupernode()
                    }
                }
                
                if let storyData, case .expired = storyData.storyType {
                    let expiredStoryIconView: UIImageView
                    if let current = node.expiredStoryIconView {
                        expiredStoryIconView = current
                    } else {
                        expiredStoryIconView = UIImageView()
                        node.expiredStoryIconView = expiredStoryIconView
                        node.view.addSubview(expiredStoryIconView)
                    }
                    
                    let imageType: ChatExpiredStoryIndicatorType
                    switch type {
                    case .standalone:
                        imageType = .free
                    case let .bubble(incoming):
                        imageType = incoming ? .incoming : .outgoing
                    }
                    
                    expiredStoryIconView.image = PresentationResourcesChat.chatExpiredStoryIndicatorIcon(presentationData.theme.theme, type: imageType)
                    if let _ = expiredStoryIconView.image {
                        let imageSize = CGSize(width: 18.0, height: 18.0)
                        expiredStoryIconView.frame = CGRect(origin: CGPoint(x: -1.0, y: -2.0), size: imageSize)
                    }
                } else if let expiredStoryIconView = node.expiredStoryIconView {
                    expiredStoryIconView.removeFromSuperview()
                }
                
                if let credibilityIconImage = currentCredibilityIconImage {
                    let credibilityIconNode: ASImageNode
                    if let node = node.credibilityIconNode {
                        credibilityIconNode = node
                    } else {
                        credibilityIconNode = ASImageNode()
                        node.credibilityIconNode = credibilityIconNode
                        node.addSubnode(credibilityIconNode)
                    }
                    credibilityIconNode.frame = CGRect(origin: CGPoint(x: titleLayout.size.width + 4.0, y: 16.0), size: credibilityIconImage.size)
                    credibilityIconNode.image = credibilityIconImage
                } else {
                    node.credibilityIconNode?.removeFromSupernode()
                    node.credibilityIconNode = nil
                }
                
                if hasPsaInfo {
                    let infoNode: InfoButtonNode
                    if let current = node.infoNode {
                        infoNode = current
                    } else {
                        infoNode = InfoButtonNode(pressed: { [weak node] in
                            guard let node = node else {
                                return
                            }
                            if let psaType = psaType, let infoNode = node.infoNode {
                                node.openPsa?(psaType, infoNode)
                            }
                        })
                        node.infoNode = infoNode
                        node.addSubnode(infoNode)
                    }
                    let infoButtonSize = CGSize(width: 32.0, height: 32.0)
                    let infoButtonFrame = CGRect(origin: CGPoint(x: width - infoButtonSize.width - 2.0, y: 1.0), size: infoButtonSize)
                    infoNode.frame = infoButtonFrame
                    infoNode.update(size: infoButtonFrame.size, theme: presentationData.theme, type: type)
                } else if let infoNode = node.infoNode {
                    node.infoNode = nil
                    infoNode.removeFromSupernode()
                }
                
                return node
            })
        }
    }
}
