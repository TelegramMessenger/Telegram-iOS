import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import SelectablePeerNode
import ShareController
import SolidRoundedButtonNode
import ActivityIndicator

private let avatarFont = avatarPlaceholderFont(size: 42.0)

private final class MoreNode: ASDisplayNode {
    private let avatarNode = AvatarNode(font: Font.regular(24.0))
    
    init(count: Int) {
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setCustomLetters(["+\(count)"])
    }
    
    func updateLayout(size: CGSize) {
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
    }
}

final class JoinLinkPreviewPeerContentNode: ASDisplayNode, ShareContentContainerNode {
    enum Content {
        case invite(isGroup: Bool, image: TelegramMediaImageRepresentation?, title: String, memberCount: Int32, members: [EnginePeer])
        case request(isGroup: Bool, image: TelegramMediaImageRepresentation?, title: String, about: String?, memberCount: Int32)
        
        var isGroup: Bool {
            switch self {
                case let .invite(isGroup, _, _, _, _), let .request(isGroup, _, _, _, _):
                    return isGroup
            }
        }
        
        var image: TelegramMediaImageRepresentation? {
            switch self {
                case let .invite(_, image, _, _, _), let .request(_, image, _, _, _):
                    return image
            }
        }
        
        var title: String {
            switch self {
                case let .invite(_, _, title, _, _), let .request(_, _, title, _, _):
                    return title
            }
        }
        
        var memberCount: Int32 {
            switch self {
                case let .invite(_, _, _, memberCount, _), let .request(_, _, _, _, memberCount):
                    return memberCount
            }
        }
    }
    
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let avatarNode: AvatarNode
    private let titleNode: ASTextNode
    private let countNode: ASTextNode
    private let aboutNode: ASTextNode
    private let descriptionNode: ASTextNode
    private let peersScrollNode: ASScrollNode
    
    private let peerNodes: [SelectablePeerNode]
    private let moreNode: MoreNode?
    
    private let actionButtonNode: SolidRoundedButtonNode
    
    var join: (() -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, content: JoinLinkPreviewPeerContentNode.Content) {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ASTextNode()
        self.titleNode.textAlignment = .center
        self.countNode = ASTextNode()
        self.aboutNode = ASTextNode()
        self.aboutNode.maximumNumberOfLines = 8
        self.aboutNode.textAlignment = .center
        self.descriptionNode = ASTextNode()
        self.descriptionNode.maximumNumberOfLines = 3
        self.descriptionNode.textAlignment = .center
        self.peersScrollNode = ASScrollNode()
        self.peersScrollNode.view.showsHorizontalScrollIndicator = false
        
        self.actionButtonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        
        let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: .green, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.opaqueItemBackgroundColor, avatarPlaceholderColor: theme.list.mediaPlaceholderColor)
        
        if case let .invite(isGroup, _, _, memberCount, members) = content {
            self.peerNodes = members.compactMap { peer in
                guard peer.id != context.account.peerId else {
                    return nil
                }
                let node = SelectablePeerNode()
                node.setup(context: context, theme: theme, strings: strings, peer: EngineRenderedPeer(peer: peer), synchronousLoad: false)
                node.theme = itemTheme
                return node
            }
            
            if members.count < Int(memberCount) {
                self.moreNode = MoreNode(count: Int(memberCount) - members.count)
            } else {
                self.moreNode = nil
            }
            
            self.actionButtonNode.title = isGroup ? strings.Invitation_JoinGroup : strings.Channel_JoinChannel
        } else {
            self.peerNodes = []
            self.moreNode = nil
            
            self.actionButtonNode.title = content.isGroup ? strings.MemberRequests_RequestToJoinGroup : strings.MemberRequests_RequestToJoinChannel
        }
        
        super.init()
        
        let peer = TelegramGroup(id: EnginePeer.Id(0), title: content.title, photo: content.image.flatMap { [$0] } ?? [], participantCount: Int(content.memberCount), role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer), emptyColor: theme.list.mediaPlaceholderColor)
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: content.title, font: Font.semibold(24.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        
        self.addSubnode(self.countNode)
        let membersString: String
        if content.isGroup {
            if case let .invite(_, _, _, memberCount, members) = content, !members.isEmpty {
                membersString = strings.Invitation_Members(memberCount)
            } else {
                membersString = strings.Conversation_StatusMembers(content.memberCount)
            }
        } else {
            membersString = strings.Conversation_StatusSubscribers(content.memberCount)
        }

        self.countNode.attributedText = NSAttributedString(string: membersString, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor, paragraphAlignment: .center)
        
        if !self.peerNodes.isEmpty {
            for peerNode in peerNodes {
                self.peersScrollNode.addSubnode(peerNode)
            }
            self.addSubnode(self.peersScrollNode)
        }
        self.moreNode.flatMap(self.peersScrollNode.addSubnode)
        
        if case let .request(isGroup, _, _, about, _) = content {
            if let about = about, !about.isEmpty {
                self.aboutNode.attributedText = NSAttributedString(string: about, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                self.addSubnode(self.aboutNode)
            }
            
            self.descriptionNode.attributedText = NSAttributedString(string: isGroup ? strings.MemberRequests_RequestToJoinDescriptionGroup : strings.MemberRequests_RequestToJoinDescriptionChannel, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor, paragraphAlignment: .center)
            self.addSubnode(self.descriptionNode)
        }
        
        self.actionButtonNode.pressed = { [weak self] in
            self?.join?()
            self?.actionButtonNode.transitionToProgress()
        }
        self.addSubnode(self.actionButtonNode)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: EnginePeer.Id?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let showPeers = !self.peerNodes.isEmpty && !isLandscape
        var nodeHeight: CGFloat = (!showPeers ? 236.0 : 320.0)
        let paddedSize = CGSize(width: size.width - 60.0, height: size.height)
        
        self.peersScrollNode.isHidden = !showPeers
        
        var aboutSize: CGSize?
        var descriptionSize: CGSize?
        if self.aboutNode.supernode != nil {
            if isLandscape {
                self.aboutNode.maximumNumberOfLines = 3
            } else {
                self.aboutNode.maximumNumberOfLines = 8
            }
            let measuredSize = self.aboutNode.measure(paddedSize)
            nodeHeight += measuredSize.height + 20.0
            aboutSize = measuredSize
        }
        
        if isLandscape {
            self.descriptionNode.removeFromSupernode()
        } else if self.descriptionNode.supernode == nil {
            self.addSubnode(self.descriptionNode)
        }
        if self.descriptionNode.supernode != nil {
            let measuredSize = self.descriptionNode.measure(paddedSize)
            nodeHeight += measuredSize.height + 20.0 + 10.0
            descriptionSize = measuredSize
        }
        
        let constrainSize = CGSize(width: size.width - 32.0, height: size.height)
        let titleSize = self.titleNode.measure(constrainSize)
        nodeHeight += titleSize.height
        
        let verticalOrigin = size.height - nodeHeight
        
        let avatarSize: CGFloat = 100.0
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: floor((size.width - avatarSize) / 2.0), y: verticalOrigin + 32.0), size: CGSize(width: avatarSize, height: avatarSize)))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: verticalOrigin + 27.0 + avatarSize + 15.0), size: titleSize))
        
        let countSize = self.countNode.measure(constrainSize)
        transition.updateFrame(node: self.countNode, frame: CGRect(origin: CGPoint(x: floor((size.width - countSize.width) / 2.0), y: verticalOrigin + 27.0 + avatarSize + 15.0 + titleSize.height + 3.0), size: countSize))
        
        var verticalOffset = verticalOrigin + 27.0 + avatarSize + 15.0 + titleSize.height + 3.0 + countSize.height + 18.0
        
        if let aboutSize = aboutSize {
            transition.updateFrame(node: self.aboutNode, frame: CGRect(origin: CGPoint(x: floor((size.width - aboutSize.width) / 2.0), y: verticalOffset), size: aboutSize))
            verticalOffset += aboutSize.height + 20.0
        }
        
        let peerSize = CGSize(width: 85.0, height: 95.0)
        let peerInset: CGFloat = 10.0
        
        var peerOffset = peerInset
        for node in self.peerNodes {
            node.frame = CGRect(origin: CGPoint(x: peerOffset, y: 0.0), size: peerSize)
            peerOffset += peerSize.width
        }
        
        if let moreNode = self.moreNode {
            moreNode.updateLayout(size: peerSize)
            moreNode.frame = CGRect(origin: CGPoint(x: peerOffset, y: 0.0), size: peerSize)
            peerOffset += peerSize.width
        }
        
        self.peersScrollNode.view.contentSize = CGSize(width: CGFloat(self.peerNodes.count) * peerSize.width + (self.moreNode != nil ? peerSize.width : 0.0) + peerInset * 2.0, height: peerSize.height)
        transition.updateFrame(node: self.peersScrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin + 27.0 + avatarSize + 15.0 + titleSize.height + 3.0 + countSize.height + 12.0), size: CGSize(width: size.width, height: peerSize.height)))
        
        if showPeers {
            verticalOffset += 100.0
        }
        
        let buttonInset: CGFloat = 16.0
        let actionButtonHeight = self.actionButtonNode.updateLayout(width: size.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.actionButtonNode, frame: CGRect(x: buttonInset, y: verticalOffset, width: size.width, height: actionButtonHeight))
        verticalOffset += actionButtonHeight + 20.0
        
        if let descriptionSize = descriptionSize {
            transition.updateFrame(node: self.descriptionNode, frame: CGRect(origin: CGPoint(x: floor((size.width - descriptionSize.width) / 2.0), y: verticalOffset), size: descriptionSize))
        }
            
        self.contentOffsetUpdated?(-size.height + nodeHeight, transition)
    }
    
    func updateSelectedPeers(animated: Bool) {
    }
}

public enum ShareLoadingState {
    case preparing
    case progress(Float)
    case done
}

public final class JoinLinkPreviewLoadingContainerNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let theme: PresentationTheme
    private let activityIndicator: ActivityIndicator
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        self.activityIndicator = ActivityIndicator(type: .custom(theme.actionSheet.controlAccentColor, 22.0, 2.0, false))
        
        super.init()
        
        self.addSubnode(self.activityIndicator)
    }
    
    public func activate() {
    }
    
    public func deactivate() {
    }
    
    public func setEnsurePeerVisibleOnLayout(_ peerId: EnginePeer.Id?) {
    }
    
    public func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    public func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let nodeHeight: CGFloat = 125.0
        
        let indicatorSize = self.activityIndicator.calculateSizeThatFits(size)
        let indicatorFrame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: size.height - nodeHeight + floor((nodeHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        transition.updateFrame(node: self.activityIndicator, frame: indicatorFrame)
        
        self.contentOffsetUpdated?(-size.height + nodeHeight, transition)
    }
    
    public func updateSelectedPeers(animated: Bool) {
    }
}
