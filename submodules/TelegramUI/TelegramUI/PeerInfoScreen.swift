import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import TelegramStringFormatting
import PhoneNumberFormat
import AppBundle
import PresentationDataUtils
import NotificationMuteSettingsUI
import NotificationSoundSelectionUI
import OverlayStatusController
import ShareController
import PhotoResources
import PeerAvatarGalleryUI

private let avatarFont = avatarPlaceholderFont(size: 28.0)

private enum PeerInfoHeaderButtonKey: Hashable {
    case message
    case call
    case mute
    case more
    case addMember
}

private enum PeerInfoHeaderButtonIcon {
    case message
    case call
    case mute
    case unmute
    case more
    case addMember
}

private final class PeerInfoHeaderButtonNode: HighlightableButtonNode {
    let key: PeerInfoHeaderButtonKey
    private let action: (PeerInfoHeaderButtonNode) -> Void
    let containerNode: ASDisplayNode
    private let backgroundNode: ASImageNode
    private let textNode: ImmediateTextNode
    
    private var theme: PresentationTheme?
    private var icon: PeerInfoHeaderButtonIcon?
    
    init(key: PeerInfoHeaderButtonKey, action: @escaping (PeerInfoHeaderButtonNode) -> Void) {
        self.key = key
        self.action = action
        
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.action(self)
    }
    
    func update(size: CGSize, text: String, icon: PeerInfoHeaderButtonIcon, isExpanded: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.theme != presentationData.theme || self.icon != icon {
            self.theme = presentationData.theme
            self.icon = icon
            self.backgroundNode.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.setBlendMode(.normal)
                context.setFillColor(presentationData.theme.list.itemCheckColors.foregroundColor.cgColor)
                let imageName: String
                switch icon {
                case .message:
                    imageName = "Peer Info/ButtonMessage"
                case .call:
                    imageName = "Peer Info/ButtonCall"
                case .mute:
                    imageName = "Peer Info/ButtonMute"
                case .unmute:
                    imageName = "Peer Info/ButtonUnmute"
                case .more:
                    imageName = "Peer Info/ButtonMore"
                case .addMember:
                    imageName = "Peer Info/ButtonAddMember"
                }
                if let image = UIImage(bundleImageName: imageName) {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.fill(imageRect)
                }
            })
        }
        
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(12.0), textColor: presentationData.theme.list.itemAccentColor)
        let titleSize = self.textNode.updateLayout(CGSize(width: 120.0, height: .greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrameAdditiveToCenter(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: size.height + 6.0), size: titleSize))
        transition.updateAlpha(node: self.textNode, alpha: isExpanded ? 0.0 : 1.0)
    }
}

private final class PeerInfoHeaderNavigationTransition {
    let sourceNavigationBar: NavigationBar
    let sourceTitleView: ChatTitleView
    let sourceTitleFrame: CGRect
    let sourceSubtitleFrame: CGRect
    let fraction: CGFloat
    
    init(sourceNavigationBar: NavigationBar, sourceTitleView: ChatTitleView, sourceTitleFrame: CGRect, sourceSubtitleFrame: CGRect, fraction: CGFloat) {
        self.sourceNavigationBar = sourceNavigationBar
        self.sourceTitleView = sourceTitleView
        self.sourceTitleFrame = sourceTitleFrame
        self.sourceSubtitleFrame = sourceSubtitleFrame
        self.fraction = fraction
    }
}

private enum PeerInfoAvatarListItem: Equatable {
    case topImage([ImageRepresentationWithReference])
    case image(TelegramMediaImageReference?, [ImageRepresentationWithReference])
    
    var id: WrappedMediaResourceId {
        switch self {
        case let .topImage(representations):
            let representation = largestImageRepresentation(representations.map { $0.representation }) ?? representations[representations.count - 1].representation
            return WrappedMediaResourceId(representation.resource.id)
        case let .image(_, representations):
            let representation = largestImageRepresentation(representations.map { $0.representation }) ?? representations[representations.count - 1].representation
            return WrappedMediaResourceId(representation.resource.id)
        }
    }
}

private final class PeerInfoAvatarListItemNode: ASDisplayNode {
    private let imageNode: TransformImageNode
    
    let isReady = Promise<Bool>()
    private var didSetReady: Bool = false
    
    init(context: AccountContext, item: PeerInfoAvatarListItem) {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
        let representations: [ImageRepresentationWithReference]
        switch item {
        case let .topImage(topRepresentations):
            representations = topRepresentations
        case let .image(_, imageRepresentations):
            representations = imageRepresentations
        }
        self.imageNode.setSignal(chatAvatarGalleryPhoto(account: context.account, representations: representations, autoFetchFullSize: true), dispatchOnDisplayLink: false)
        
        self.imageNode.imageUpdated = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf.isReady.set(.single(true))
            }
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let makeLayout = self.imageNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        let _ = applyLayout()
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
    }
}

private final class PeerInfoAvatarListContainerNode: ASDisplayNode {
    private let context: AccountContext
    
    let contentNode: ASDisplayNode
    private var items: [PeerInfoAvatarListItem] = []
    private var itemNodes: [WrappedMediaResourceId: PeerInfoAvatarListItemNode] = [:]
    private var currentIndex: Int = 0
    private var transitionFraction: CGFloat = 0.0
    
    private var validLayout: CGSize?
    
    private let disposable = MetaDisposable()
    private var initializedList = false
    
    let isReady = Promise<Bool>()
    private var didSetReady = false
    
    init(context: AccountContext) {
        self.context = context
        
        self.contentNode = ASDisplayNode()
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.contentNode)
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            let translation = recognizer.translation(in: self.view)
            var transitionFraction = translation.x / self.bounds.width
            if self.currentIndex <= 0 {
                transitionFraction = min(0.0, transitionFraction)
            }
            if self.currentIndex >= self.items.count - 1 {
                transitionFraction = max(0.0, transitionFraction)
            }
            self.transitionFraction = transitionFraction
            if let size = self.validLayout {
                self.updateItems(size: size, transition: .animated(duration: 0.3, curve: .spring))
            }
        case .cancelled, .ended:
            let translation = recognizer.translation(in: self.view)
            let velocity = recognizer.velocity(in: self.view)
            var directionIsToRight = false
            if abs(velocity.x) > 10.0 {
                directionIsToRight = velocity.x < 0.0
            } else {
                directionIsToRight = translation.x > self.bounds.width / 2.0
            }
            var updatedIndex = self.currentIndex
            if directionIsToRight {
                updatedIndex = min(updatedIndex + 1, self.items.count - 1)
            } else {
                updatedIndex = max(updatedIndex - 1, 0)
            }
            self.currentIndex = updatedIndex
            self.transitionFraction = 0.0
            if let size = self.validLayout {
                self.updateItems(size: size, transition: .animated(duration: 0.3, curve: .spring))
            }
        default:
            break
        }
    }
    
    func update(size: CGSize, peer: Peer?, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        if let peer = peer, !self.initializedList {
            self.initializedList = true
            self.disposable.set((fetchedAvatarGalleryEntries(account: self.context.account, peer: peer)
            |> deliverOnMainQueue).start(next: { [weak self] entries in
                guard let strongSelf = self else {
                    return
                }
                var items: [PeerInfoAvatarListItem] = []
                for entry in entries {
                    switch entry {
                    case let .topImage(representations, _):
                        items.append(.topImage(representations))
                    case let .image(reference, representations, _, _, _, _):
                        items.append(.image(reference, representations))
                    }
                }
                strongSelf.items = items
                if let size = strongSelf.validLayout {
                    strongSelf.updateItems(size: size, transition: .immediate)
                }
                if items.isEmpty {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf.isReady.set(.single(true))
                    }
                }
            }))
        }
        self.updateItems(size: size, transition: transition)
    }
    
    private func updateItems(size: CGSize, transition: ContainedViewLayoutTransition) {
        var validIds: [WrappedMediaResourceId] = []
        var addedItemNodesForAdditiveTransition: [PeerInfoAvatarListItemNode] = []
        var additiveTransitionOffset: CGFloat = 0.0
        if self.currentIndex >= 0 && self.currentIndex < self.items.count {
            for i in max(0, self.currentIndex - 1) ... min(self.currentIndex + 1, self.items.count - 1) {
                validIds.append(self.items[i].id)
                let itemNode: PeerInfoAvatarListItemNode
                var wasAdded = false
                if let current = self.itemNodes[self.items[i].id] {
                    itemNode = current
                } else {
                    wasAdded = true
                    itemNode = PeerInfoAvatarListItemNode(context: self.context, item: self.items[i])
                    self.itemNodes[self.items[i].id] = itemNode
                    self.contentNode.addSubnode(itemNode)
                }
                let indexOffset = CGFloat(i - self.currentIndex)
                let itemFrame = CGRect(origin: CGPoint(x: indexOffset * size.width + self.transitionFraction * size.width - size.width / 2.0, y: -size.height / 2.0), size: size)
                
                if wasAdded {
                    addedItemNodesForAdditiveTransition.append(itemNode)
                    itemNode.frame = itemFrame
                    itemNode.update(size: size, transition: .immediate)
                } else {
                    additiveTransitionOffset = itemNode.frame.minX - itemFrame.minX
                    transition.updateFrame(node: itemNode, frame: itemFrame)
                    itemNode.update(size: size, transition: transition)
                }
            }
        }
        for itemNode in addedItemNodesForAdditiveTransition {
            transition.animatePositionAdditive(node: itemNode, offset: CGPoint(x: additiveTransitionOffset, y: 0.0))
        }
        var removeIds: [WrappedMediaResourceId] = []
        for (id, _) in self.itemNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
        
        if let item = self.items.first, let itemNode = self.itemNodes[item.id] {
            if !self.didSetReady {
                self.didSetReady = true
                self.isReady.set(itemNode.isReady.get())
            }
        }
    }
}

private final class PeerInfoAvatarTransformContainerNode: ASDisplayNode {
    let context: AccountContext
    let avatarNode: AvatarNode
    
    var tapped: (() -> Void)?
    
    private var isFirstAvatarLoading = true
    
    init(context: AccountContext) {
        self.context = context
        self.avatarNode = AvatarNode(font: avatarFont)
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.frame = CGRect(origin: CGPoint(x: -50.0, y: -50.0), size: CGSize(width: 100.0, height: 100.0))
        
        self.avatarNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    func update(peer: Peer?, theme: PresentationTheme) {
        if let peer = peer {
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: peer, synchronousLoad: self.isFirstAvatarLoading, displayDimensions: CGSize(width: 100.0, height: 100.0))
            self.isFirstAvatarLoading = false
        }
    }
}

private final class PeerInfoAvatarListNode: ASDisplayNode {
    let avatarContainerNode: PeerInfoAvatarTransformContainerNode
    let listContainerTransformNode: ASDisplayNode
    let listContainerNode: PeerInfoAvatarListContainerNode
    
    let isReady = Promise<Bool>()
    
    init(context: AccountContext, readyWhenGalleryLoads: Bool) {
        self.avatarContainerNode = PeerInfoAvatarTransformContainerNode(context: context)
        self.listContainerTransformNode = ASDisplayNode()
        self.listContainerNode = PeerInfoAvatarListContainerNode(context: context)
        self.listContainerNode.clipsToBounds = true
        self.listContainerNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.avatarContainerNode)
        self.listContainerTransformNode.addSubnode(self.listContainerNode)
        self.addSubnode(self.listContainerTransformNode)
        
        let avatarReady = self.avatarContainerNode.avatarNode.ready
        |> mapToSignal { _ -> Signal<Bool, NoError> in
            return .complete()
        }
        |> then(.single(true))
        
        let galleryReady = self.listContainerNode.isReady.get()
        |> filter { $0 }
        |> take(1)
        
        let combinedSignal: Signal<Bool, NoError>
        if readyWhenGalleryLoads {
            combinedSignal = combineLatest(queue: .mainQueue(),
                avatarReady,
                galleryReady
            )
            |> map { lhs, rhs in
                return lhs && rhs
            }
        } else {
            combinedSignal = avatarReady
        }
        
        self.isReady.set(combinedSignal
        |> filter { $0 }
        |> take(1))
    }
    
    func update(size: CGSize, isExpanded: Bool, peer: Peer?, theme: PresentationTheme, transition: ContainedViewLayoutTransition) {
        self.avatarContainerNode.update(peer: peer, theme: theme)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.listContainerNode.isHidden {
            if let result = self.listContainerNode.view.hitTest(self.view.convert(point, to: self.listContainerNode.view), with: event) {
                return result
            }
        } else {
            if let result = self.avatarContainerNode.avatarNode.view.hitTest(self.view.convert(point, to: self.avatarContainerNode.avatarNode.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
}

private final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private var presentationData: PresentationData?
    
    private(set) var isAvatarExpanded: Bool
    
    private let avatarListNode: PeerInfoAvatarListNode
    let titleNodeContainer: ASDisplayNode
    let titleNodeRawContainer: ASDisplayNode
    let titleNode: ImmediateTextNode
    let subtitleNodeContainer: ASDisplayNode
    let subtitleNodeRawContainer: ASDisplayNode
    let subtitleNode: ImmediateTextNode
    private var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    private let backgroundNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    
    var performButtonAction: ((PeerInfoHeaderButtonKey) -> Void)?
    var requestAvatarExpansion: (() -> Void)?
    
    var navigationTransition: PeerInfoHeaderNavigationTransition?
    
    init(context: AccountContext, avatarInitiallyExpanded: Bool) {
        self.context = context
        self.isAvatarExpanded = avatarInitiallyExpanded
        
        self.avatarListNode = PeerInfoAvatarListNode(context: context, readyWhenGalleryLoads: avatarInitiallyExpanded)
        
        self.titleNodeContainer = ASDisplayNode()
        self.titleNodeRawContainer = ASDisplayNode()
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNodeContainer = ASDisplayNode()
        self.subtitleNodeRawContainer = ASDisplayNode()
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarListNode)
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.addSubnode(self.titleNodeContainer)
        self.subtitleNodeContainer.addSubnode(self.subtitleNode)
        self.addSubnode(self.subtitleNodeContainer)
        
        self.avatarListNode.avatarContainerNode.tapped = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isAvatarExpanded {
                strongSelf.requestAvatarExpansion?()
            }
        }
    }
    
    func update(width: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, contentOffset: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, notificationSettings: TelegramPeerNotificationSettings?, presence: TelegramUserPresence?, transition: ContainedViewLayoutTransition, additive: Bool) -> CGFloat {
        self.presentationData = presentationData
        
        var transitionSourceHeight: CGFloat = 0.0
        var transitionFraction: CGFloat = 0.0
        var transitionSourceAvatarFrame = CGRect()
        var transitionSourceTitleFrame = CGRect()
        var transitionSourceSubtitleFrame = CGRect()
        if let navigationTransition = self.navigationTransition, let sourceAvatarNode = navigationTransition.sourceTitleView.avatarNode?.avatarNode {
            transitionSourceHeight = navigationTransition.sourceNavigationBar.bounds.height
            transitionFraction = navigationTransition.fraction
            transitionSourceAvatarFrame = sourceAvatarNode.view.convert(sourceAvatarNode.view.bounds, to: navigationTransition.sourceNavigationBar.view)
            transitionSourceTitleFrame = navigationTransition.sourceTitleFrame
            transitionSourceSubtitleFrame = navigationTransition.sourceSubtitleFrame
            
            transition.updateBackgroundColor(node: self.backgroundNode, color: presentationData.theme.list.itemBlocksBackgroundColor.interpolateTo(presentationData.theme.rootController.navigationBar.backgroundColor, fraction: transitionFraction)!)
        } else {
            self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            
            let backgroundTransitionFraction: CGFloat = max(0.0, min(1.0, contentOffset / (212.0)))
            transition.updateBackgroundColor(node: self.backgroundNode, color: presentationData.theme.list.itemBlocksBackgroundColor.interpolateTo(presentationData.theme.rootController.navigationBar.backgroundColor, fraction: backgroundTransitionFraction)!)
        }
        
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let defaultButtonSize: CGFloat = 40.0
        let defaultMaxButtonSpacing: CGFloat = 40.0
        
        var buttonKeys: [PeerInfoHeaderButtonKey] = []
        
        if let peer = peer {
            buttonKeys.append(.message)
            buttonKeys.append(.call)
            buttonKeys.append(.mute)
            buttonKeys.append(.more)
            
            self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.semibold(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            
            let presence = presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            let (subtitleString, activity) = stringAndActivityForUserPresence(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp), expanded: true)
            let subtitleColor: UIColor
            if activity {
                subtitleColor = presentationData.theme.list.itemAccentColor
            } else {
                subtitleColor = presentationData.theme.list.itemSecondaryTextColor
            }
            self.subtitleNode.attributedText = NSAttributedString(string: subtitleString, font: Font.regular(15.0), textColor: subtitleColor)
        }
        
        let textSideInset: CGFloat = 16.0
        let expandedAvatarControlsHeight: CGFloat = 64.0
        let expandedAvatarHeight: CGFloat = width + expandedAvatarControlsHeight
        
        let avatarSize: CGFloat = 100.0
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 10.0), size: CGSize(width: avatarSize, height: avatarSize))
        let avatarCenter = CGPoint(x: (1.0 - transitionFraction) * avatarFrame.midX + transitionFraction * transitionSourceAvatarFrame.midX, y: (1.0 - transitionFraction) * avatarFrame.midY + transitionFraction * transitionSourceAvatarFrame.midY)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - textSideInset * 2.0, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: width - textSideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let titleFrame: CGRect
        let subtitleFrame: CGRect
        if self.isAvatarExpanded {
            titleFrame = CGRect(origin: CGPoint(x: 16.0, y: expandedAvatarHeight - expandedAvatarControlsHeight + 12.0), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: 16.0, y: titleFrame.maxY - 5.0), size: subtitleSize)
        } else {
            titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 10.0), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: floor((width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
        }
        
        let titleLockOffset: CGFloat = 7.0
        let titleMaxLockOffset: CGFloat = 7.0
        let titleCollapseOffset = titleFrame.midY - statusBarHeight - titleLockOffset
        let titleOffset = -min(titleCollapseOffset, contentOffset)
        let titleCollapseFraction = max(0.0, min(1.0, contentOffset / titleCollapseOffset))
        
        let titleMinScale: CGFloat = 0.7
        let subtitleMinScale: CGFloat = 0.8
        let avatarMinScale: CGFloat = 0.7
        
        let apparentTitleLockOffset = (1.0 - titleCollapseFraction) * 0.0 + titleCollapseFraction * titleMaxLockOffset
        
        let avatarScale: CGFloat
        let avatarOffset: CGFloat
        if self.navigationTransition != nil {
            avatarScale = ((1.0 - transitionFraction) * avatarFrame.width + transitionFraction * transitionSourceAvatarFrame.width) / avatarFrame.width
            avatarOffset = 0.0
        } else {
            avatarScale = 1.0 * (1.0 - titleCollapseFraction) + avatarMinScale * titleCollapseFraction
            avatarOffset = apparentTitleLockOffset + 0.0 * (1.0 - titleCollapseFraction) + 10.0 * titleCollapseFraction
        }
        let avatarListFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: width))
        
        if self.isAvatarExpanded {
            self.avatarListNode.listContainerNode.isHidden = false
            if !transitionSourceAvatarFrame.width.isZero {
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: transitionFraction * transitionSourceAvatarFrame.width / 2.0)
            } else {
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 0.0)
            }
        } else if self.avatarListNode.listContainerNode.cornerRadius != 50.0 {
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 50.0, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.avatarListNode.listContainerNode.isHidden = true
            })
        }
        
        self.avatarListNode.update(size: CGSize(), isExpanded: self.isAvatarExpanded, peer: peer, theme: presentationData.theme, transition: transition)
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
        }
        let apparentAvatarFrame: CGRect
        if self.isAvatarExpanded {
            let expandedAvatarCenter = CGPoint(x: width / 2.0, y: width / 2.0 - contentOffset / 2.0)
            apparentAvatarFrame = CGRect(origin: CGPoint(x: expandedAvatarCenter.x * (1.0 - transitionFraction) + transitionFraction * avatarCenter.x, y: expandedAvatarCenter.y * (1.0 - transitionFraction) + transitionFraction * avatarCenter.y), size: CGSize())
        } else {
            apparentAvatarFrame = CGRect(origin: CGPoint(x: avatarCenter.x - avatarFrame.width / 2.0, y: -contentOffset + avatarOffset + avatarCenter.y - avatarFrame.height / 2.0), size: avatarFrame.size)
        }
        if case let .animated(duration, curve) = transition, !transitionSourceAvatarFrame.width.isZero {
            let previousFrame = self.avatarListNode.frame
            self.avatarListNode.frame = CGRect(origin: apparentAvatarFrame.center, size: CGSize())
            let horizontalTransition: ContainedViewLayoutTransition
            let verticalTransition: ContainedViewLayoutTransition
            if transitionFraction < .ulpOfOne {
                horizontalTransition = .animated(duration: duration * 0.85, curve: curve)
                verticalTransition = .animated(duration: duration * 1.15, curve: curve)
            } else {
                horizontalTransition = transition
                verticalTransition = .animated(duration: duration * 0.6, curve: curve)
            }
            horizontalTransition.animatePositionAdditive(node: self.avatarListNode, offset: CGPoint(x: previousFrame.midX - apparentAvatarFrame.midX, y: 0.0))
            verticalTransition.animatePositionAdditive(node: self.avatarListNode, offset: CGPoint(x: 0.0, y: previousFrame.midY - apparentAvatarFrame.midY))
        } else {
            transition.updateFrameAdditive(node: self.avatarListNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        }
        
        let avatarListContainerFrame: CGRect
        let avatarListContainerScale: CGFloat
        if self.isAvatarExpanded {
            if !transitionSourceAvatarFrame.width.isZero {
                let neutralAvatarListContainerSize = CGSize(width: width, height: width)
                let avatarListContainerSize = CGSize(width: neutralAvatarListContainerSize.width * (1.0 - transitionFraction) + transitionSourceAvatarFrame.width * transitionFraction, height: neutralAvatarListContainerSize.height * (1.0 - transitionFraction) + transitionSourceAvatarFrame.height * transitionFraction)
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -avatarListContainerSize.width / 2.0, y: -avatarListContainerSize.height / 2.0), size: avatarListContainerSize)
            } else {
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -width / 2.0, y: -width / 2.0), size: CGSize(width: width, height: width))
            }
            avatarListContainerScale = 1.0 + max(0.0, -contentOffset / avatarListContainerFrame.width)
        } else {
            avatarListContainerFrame = CGRect(origin: CGPoint(x: -apparentAvatarFrame.width / 2.0, y: -apparentAvatarFrame.height / 2.0), size: apparentAvatarFrame.size)
            avatarListContainerScale = avatarScale
        }
        transition.updateFrame(node: self.avatarListNode.listContainerNode, frame: avatarListContainerFrame)
        let innerScale = avatarListContainerFrame.width / width
        let innerDelta = (avatarListContainerFrame.width - width) / 2.0
        transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerNode, scale: innerScale)
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.contentNode, frame: CGRect(origin: CGPoint(x: innerDelta + width / 2.0, y: innerDelta + width / 2.0), size: CGSize()))
        
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        }
        
        self.avatarListNode.listContainerNode.update(size: CGSize(width: width, height: width), peer: peer, transition: transition)
        
        let buttonsCollapseStart = titleCollapseOffset
        let buttonsCollapseEnd = 212.0 - (navigationHeight - statusBarHeight) + 10.0
        
        let buttonsCollapseFraction = max(0.0, contentOffset - buttonsCollapseStart) / (buttonsCollapseEnd - buttonsCollapseStart)
        
        let rawHeight: CGFloat
        let height: CGFloat
        if self.isAvatarExpanded {
            rawHeight = expandedAvatarHeight
            height = max(navigationHeight, rawHeight - contentOffset)
        } else {
            rawHeight = navigationHeight + 212.0
            height = navigationHeight + max(0.0, 212.0 - contentOffset)
        }
        
        let apparentHeight = (1.0 - transitionFraction) * height + transitionFraction * transitionSourceHeight
        
        if !titleSize.width.isZero && !titleSize.height.isZero {
            if self.navigationTransition != nil {
                var neutralTitleScale: CGFloat = 1.0
                var neutralSubtitleScale: CGFloat = 1.0
                if self.isAvatarExpanded {
                    neutralTitleScale = 0.7
                    neutralSubtitleScale = 1.0
                }
                
                let titleScale = (transitionFraction * transitionSourceTitleFrame.height + (1.0 - transitionFraction) * titleFrame.height * neutralTitleScale) / (titleFrame.height)
                let subtitleScale = (transitionFraction * transitionSourceSubtitleFrame.height + (1.0 - transitionFraction) * subtitleFrame.height * neutralSubtitleScale) / (subtitleFrame.height)
                
                let titleOrigin = CGPoint(x: transitionFraction * transitionSourceTitleFrame.minX + (1.0 - transitionFraction) * titleFrame.minX, y: transitionFraction * transitionSourceTitleFrame.minY + (1.0 - transitionFraction) * titleFrame.minY)
                let subtitleOrigin = CGPoint(x: transitionFraction * transitionSourceSubtitleFrame.minX + (1.0 - transitionFraction) * subtitleFrame.minX, y: transitionFraction * transitionSourceSubtitleFrame.minY + (1.0 - transitionFraction) * subtitleFrame.minY)
                
                let rawTitleFrame = CGRect(origin: titleOrigin, size: titleFrame.size)
                self.titleNodeRawContainer.frame = rawTitleFrame
                transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: rawTitleFrame.offsetBy(dx: rawTitleFrame.width * 0.5 * (titleScale - 1.0), dy: titleOffset + rawTitleFrame.height * 0.5 * (titleScale - 1.0)))
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: titleFrame.size))
                let rawSubtitleFrame = CGRect(origin: subtitleOrigin, size: subtitleFrame.size)
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: rawSubtitleFrame.offsetBy(dx: rawSubtitleFrame.width * 0.5 * (subtitleScale - 1.0), dy: titleOffset + rawSubtitleFrame.height * 0.5 * (subtitleScale - 1.0)))
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(), size: subtitleFrame.size))
                transition.updateSublayerTransformScale(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScale(node: self.subtitleNodeContainer, scale: subtitleScale)
            } else {
                let titleScale: CGFloat
                let subtitleScale: CGFloat
                if self.isAvatarExpanded {
                    titleScale = 0.7
                    subtitleScale = 1.0
                } else {
                    titleScale = (1.0 - titleCollapseFraction) * 1.0 + titleCollapseFraction * titleMinScale
                    subtitleScale = (1.0 - titleCollapseFraction) * 1.0 + titleCollapseFraction * subtitleMinScale
                }
                
                let rawTitleFrame = titleFrame
                self.titleNodeRawContainer.frame = rawTitleFrame
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: titleFrame.size))
                let rawSubtitleFrame = subtitleFrame
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                if self.isAvatarExpanded {
                    transition.updateFrameAdditive(node: self.titleNodeContainer, frame: rawTitleFrame.offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset).offsetBy(dx: rawTitleFrame.width * 0.5 * (titleScale - 1.0), dy: rawTitleFrame.height * 0.5 * (titleScale - 1.0)))
                    transition.updateFrameAdditive(node: self.subtitleNodeContainer, frame: rawSubtitleFrame.offsetBy(dx: 0.0, dy: titleOffset).offsetBy(dx: rawSubtitleFrame.width * 0.5 * (subtitleScale - 1.0), dy: rawSubtitleFrame.height * 0.5 * (subtitleScale - 1.0)))
                } else {
                    transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: rawTitleFrame.offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                    transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: rawSubtitleFrame.offsetBy(dx: 0.0, dy: titleOffset))
                }
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(), size: subtitleFrame.size))
                transition.updateSublayerTransformScaleAdditive(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScaleAdditive(node: self.subtitleNodeContainer, scale: subtitleScale)
            }
        }
        
        let buttonSpacing: CGFloat
        if self.isAvatarExpanded {
            buttonSpacing = 16.0
        } else {
            buttonSpacing = min(defaultMaxButtonSpacing, width - floor(CGFloat(buttonKeys.count) * defaultButtonSize / CGFloat(buttonKeys.count + 1)))
        }
        
        let expandedButtonSize: CGFloat = 32.0
        let buttonsWidth = buttonSpacing * CGFloat(buttonKeys.count - 1) + CGFloat(buttonKeys.count) * defaultButtonSize
        var buttonRightOrigin: CGPoint
        if self.isAvatarExpanded {
            buttonRightOrigin = CGPoint(x: width - 16.0, y: apparentHeight - 74.0)
        } else {
            buttonRightOrigin = CGPoint(x: floor((width - buttonsWidth) / 2.0) + buttonsWidth, y: apparentHeight - 74.0)
        }
        let buttonsScale: CGFloat
        let buttonsAlpha: CGFloat
        let apparentButtonSize: CGFloat
        let buttonsVerticalOffset: CGFloat
        if self.navigationTransition != nil {
            if self.isAvatarExpanded {
                apparentButtonSize = expandedButtonSize
            } else {
                apparentButtonSize = defaultButtonSize
            }
            let neutralButtonsScale = apparentButtonSize / defaultButtonSize
            buttonsScale = (1.0 - transitionFraction) * neutralButtonsScale + 0.2 * transitionFraction
            buttonsAlpha = 1.0 - transitionFraction
            
            let neutralButtonsOffset: CGFloat
            if self.isAvatarExpanded {
                neutralButtonsOffset = 74.0 - 15.0 - defaultButtonSize + (defaultButtonSize - apparentButtonSize) / 2.0
            } else {
                neutralButtonsOffset = (1.0 - buttonsScale) * apparentButtonSize
            }
                
            buttonsVerticalOffset = (1.0 - transitionFraction) * neutralButtonsOffset + ((1.0 - buttonsScale) * apparentButtonSize) * transitionFraction
        } else {
            apparentButtonSize = self.isAvatarExpanded ? expandedButtonSize : defaultButtonSize
            if self.isAvatarExpanded {
                buttonsScale = apparentButtonSize / defaultButtonSize
                buttonsVerticalOffset = 74.0 - 15.0 - defaultButtonSize + (defaultButtonSize - apparentButtonSize) / 2.0
            } else {
                buttonsScale = (1.0 - buttonsCollapseFraction) * 1.0 + 0.2 * buttonsCollapseFraction
                buttonsVerticalOffset = (1.0 - buttonsScale) * apparentButtonSize
            }
            buttonsAlpha = 1.0 - buttonsCollapseFraction
        }
        let buttonsScaledOffset = (defaultButtonSize - apparentButtonSize) / 2.0
        for buttonKey in buttonKeys.reversed() {
            let buttonNode: PeerInfoHeaderButtonNode
            var wasAdded = false
            if let current = self.buttonNodes[buttonKey] {
                buttonNode = current
            } else {
                wasAdded = true
                buttonNode = PeerInfoHeaderButtonNode(key: buttonKey, action: { [weak self] buttonNode in
                    self?.buttonPressed(buttonNode)
                })
                self.buttonNodes[buttonKey] = buttonNode
                self.addSubnode(buttonNode)
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonRightOrigin.x - defaultButtonSize + buttonsScaledOffset, y: buttonRightOrigin.y), size: CGSize(width: defaultButtonSize, height: defaultButtonSize))
            let buttonTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            let apparentButtonFrame = buttonFrame.offsetBy(dx: 0.0, dy: buttonsVerticalOffset)
            if additive {
                buttonTransition.updateFrameAdditiveToCenter(node: buttonNode, frame: apparentButtonFrame)
            } else {
                buttonTransition.updateFrame(node: buttonNode, frame: apparentButtonFrame)
            }
            let buttonText: String
            let buttonIcon: PeerInfoHeaderButtonIcon
            switch buttonKey {
            case .message:
                buttonText = "Message"
                buttonIcon = .message
            case .call:
                buttonText = "Call"
                buttonIcon = .call
            case .mute:
                if let notificationSettings = notificationSettings, case .muted = notificationSettings.muteState {
                    buttonText = "Unmute"
                    buttonIcon = .unmute
                } else {
                    buttonText = "Mute"
                    buttonIcon = .mute
                }
            case .more:
                buttonText = "More"
                buttonIcon = .more
            case .addMember:
                buttonText = "Add Member"
                buttonIcon = .addMember
            }
            buttonNode.update(size: buttonFrame.size, text: buttonText, icon: buttonIcon, isExpanded: self.isAvatarExpanded, presentationData: presentationData, transition: buttonTransition)
            transition.updateSublayerTransformScaleAdditive(node: buttonNode, scale: buttonsScale)
            
            transition.updateAlpha(node: buttonNode, alpha: buttonsAlpha)
            if self.isAvatarExpanded, case .mute = buttonKey {
                if case let .animated(duration, curve) = transition {
                    ContainedViewLayoutTransition.animated(duration: duration * 0.3, curve: curve).updateAlpha(node: buttonNode.containerNode, alpha: 0.0)
                } else {
                    transition.updateAlpha(node: buttonNode.containerNode, alpha: 0.0)
                }
            } else {
                if case .mute = buttonKey, buttonNode.containerNode.alpha.isZero, additive {
                    if case let .animated(duration, curve) = transition {
                        ContainedViewLayoutTransition.animated(duration: duration * 0.3, curve: curve).updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                    } else {
                        transition.updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                    }
                } else {
                    transition.updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                }
                buttonRightOrigin.x -= apparentButtonSize + buttonSpacing
            }
        }
        
        for key in self.buttonNodes.keys {
            if !buttonKeys.contains(key) {
                if let buttonNode = self.buttonNodes[key] {
                    self.buttonNodes.removeValue(forKey: key)
                    buttonNode.removeFromSupernode()
                }
            }
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + apparentHeight), size: CGSize(width: width, height: 2000.0))
        let separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: apparentHeight), size: CGSize(width: width, height: UIScreenPixel))
        if additive {
            transition.updateFrameAdditive(node: self.backgroundNode, frame: backgroundFrame)
            transition.updateFrameAdditive(node: self.separatorNode, frame: separatorFrame)
        } else {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            transition.updateFrame(node: self.separatorNode, frame: separatorFrame)
        }
        
        if self.isAvatarExpanded {
            return width + expandedAvatarControlsHeight
        } else {
            return 212.0 + navigationHeight
        }
    }
    
    private func buttonPressed(_ buttonNode: PeerInfoHeaderButtonNode) {
        self.performButtonAction?(buttonNode.key)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.backgroundNode.frame.contains(point) {
            return nil
        }
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result == self.view {
            return nil
        }
        return result
    }
    
    func updateIsAvatarExpanded(_ isAvatarExpanded: Bool) {
        self.isAvatarExpanded = isAvatarExpanded
    }
}

protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func findLoadedMessage(id: MessageId) -> Message?
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
}

private final class PeerInfoPaneWrapper {
    let key: PeerInfoPaneKey
    let node: PeerInfoPaneNode
    private var appliedParams: (CGSize, Bool, PresentationData)?
    
    init(key: PeerInfoPaneKey, node: PeerInfoPaneNode) {
        self.key = key
        self.node = node
    }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        if let (currentSize, currentIsScrollingLockedAtTop, currentPresentationData) = self.appliedParams {
            if currentSize == size && currentIsScrollingLockedAtTop == isScrollingLockedAtTop && currentPresentationData === presentationData {
                return
            }
        }
        self.appliedParams = (size, isScrollingLockedAtTop, presentationData)
        self.node.update(size: size, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: synchronous, transition: transition)
    }
}

private enum PeerInfoPaneKey {
    case media
    case files
    case links
    case music
}

private final class PeerInfoPaneTabsContainerPaneNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let titleNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func updateText(_ title: String, isSelected: Bool, presentationData: PresentationData) {
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: isSelected ? presentationData.theme.list.itemAccentColor : presentationData.theme.list.itemSecondaryTextColor)
    }
    
    func updateLayout(height: CGFloat) -> CGFloat {
        let titleSize = self.titleNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        return titleSize.width
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat) {
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))
    }
}

private struct PeerInfoPaneSpecifier: Equatable {
    var key: PeerInfoPaneKey
    var title: String
}

private final class PeerInfoPaneTabsContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private var paneNodes: [PeerInfoPaneKey: PeerInfoPaneTabsContainerPaneNode] = [:]
    private let selectedLineNode: ASImageNode
    
    private var currentParams: ([PeerInfoPaneSpecifier], PeerInfoPaneKey?, PresentationData)?
    
    var requestSelectPane: ((PeerInfoPaneKey) -> Void)?
    
    override init() {
        self.scrollNode = ASScrollNode()
        
        self.selectedLineNode = ASImageNode()
        self.selectedLineNode.displaysAsynchronously = false
        self.selectedLineNode.displayWithoutProcessing = true
        
        super.init()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.selectedLineNode)
    }
    
    func update(size: CGSize, presentationData: PresentationData, paneList: [PeerInfoPaneSpecifier], selectedPane: PeerInfoPaneKey?, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if self.currentParams?.2.theme !== presentationData.theme {
            self.selectedLineNode.image = generateImage(CGSize(width: 7.0, height: 4.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
            })?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 1)
        }
        
        if self.currentParams?.0 != paneList || self.currentParams?.1 != selectedPane || self.currentParams?.2 !== presentationData {
            self.currentParams = (paneList, selectedPane, presentationData)
            for specifier in paneList {
                let paneNode: PeerInfoPaneTabsContainerPaneNode
                var wasAdded = false
                if let current = self.paneNodes[specifier.key] {
                    paneNode = current
                } else {
                    wasAdded = true
                    paneNode = PeerInfoPaneTabsContainerPaneNode(pressed: { [weak self] in
                        self?.paneSelected(specifier.key)
                    })
                    self.paneNodes[specifier.key] = paneNode
                    self.scrollNode.addSubnode(paneNode)
                }
                paneNode.updateText(specifier.title, isSelected: selectedPane == specifier.key, presentationData: presentationData)
            }
            var removeKeys: [PeerInfoPaneKey] = []
            for (key, _) in self.paneNodes {
                if !paneList.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let paneNode = self.paneNodes.removeValue(forKey: key) {
                    paneNode.removeFromSupernode()
                }
            }
        }
        
        var tabSizes: [(CGSize, PeerInfoPaneTabsContainerPaneNode)] = []
        var totalRawTabSize: CGFloat = 0.0
        
        var selectedFrame: CGRect?
        for specifier in paneList {
            guard let paneNode = self.paneNodes[specifier.key] else {
                continue
            }
            let paneNodeWidth = paneNode.updateLayout(height: size.height)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            tabSizes.append((paneNodeSize, paneNode))
            totalRawTabSize += paneNodeSize.width
        }
        
        let spacing: CGFloat = 32.0
        if totalRawTabSize + CGFloat(tabSizes.count + 1) * spacing <= size.width {
            let singleTabSpace = floor((size.width - spacing * 2.0) / CGFloat(tabSizes.count))
            
            for i in 0 ..< tabSizes.count {
                let (paneNodeSize, paneNode) = tabSizes[i]
                let leftOffset = spacing + CGFloat(i) * singleTabSpace + floor((singleTabSpace - paneNodeSize.width) / 2.0)
                
                let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                paneNode.frame = paneFrame
                let areaSideInset = floor((singleTabSpace - paneFrame.size.width) / 2.0)
                paneNode.updateArea(size: paneFrame.size, sideInset: areaSideInset)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -areaSideInset, bottom: 0.0, right: -areaSideInset)
                
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
                }
            }
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: size.height)
        } else {
            let sideInset: CGFloat = 16.0
            var leftOffset: CGFloat = sideInset
            for i in 0 ..< tabSizes.count {
                let (paneNodeSize, paneNode) = tabSizes[i]
                let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                paneNode.frame = paneFrame
                paneNode.updateArea(size: paneFrame.size, sideInset: spacing)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -spacing, bottom: 0.0, right: -spacing)
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
                }
                leftOffset += paneNodeSize.width + spacing
            }
            self.scrollNode.view.contentSize = CGSize(width: leftOffset + sideInset, height: size.height)
        }
        
        if let selectedFrame = selectedFrame {
            self.selectedLineNode.isHidden = false
            transition.updateFrame(node: self.selectedLineNode, frame: CGRect(origin: CGPoint(x: selectedFrame.minX, y: size.height - 4.0), size: CGSize(width: selectedFrame.width, height: 4.0)))
        } else {
            self.selectedLineNode.isHidden = true
        }
    }
    
    private func paneSelected(_ key: PeerInfoPaneKey) {
        self.requestSelectPane?(key)
    }
}

private final class PeerInfoPaneContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let coveringBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let tabsContainerNode: PeerInfoPaneTabsContainerNode
    private let tapsSeparatorNode: ASDisplayNode
    
    let isReady = Promise<Bool>()
    var didSetIsReady = false
    
    private var currentParams: (size: CGSize, expansionFraction: CGFloat, presentationData: PresentationData)?
    
    private var availablePanes: [PeerInfoPaneKey] = []
    private var currentPaneKey: PeerInfoPaneKey?
    private var currentPane: PeerInfoPaneWrapper?
    
    private var candidatePane: (PeerInfoPaneWrapper, Disposable)?
    
    var openMessage: ((MessageId) -> Bool)?
    
    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.coveringBackgroundNode = ASDisplayNode()
        self.coveringBackgroundNode.isLayerBacked = true
        
        self.tabsContainerNode = PeerInfoPaneTabsContainerNode()
        
        self.tapsSeparatorNode = ASDisplayNode()
        self.tapsSeparatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coveringBackgroundNode)
        self.addSubnode(self.tabsContainerNode)
        self.addSubnode(self.tapsSeparatorNode)
        
        self.availablePanes = [.media, .files, .links, .music]
        self.currentPaneKey = .media
        
        self.tabsContainerNode.requestSelectPane = { [weak self] key in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentPaneKey == key {
                return
            }
            
            let paneNode: PeerInfoPaneNode
            switch key {
            case .media:
                paneNode = PeerInfoVisualMediaPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId)
            case .files:
                paneNode = PeerInfoListPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId, tagMask: .file)
            case .links:
                paneNode = PeerInfoListPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId, tagMask: .webPage)
            case .music:
                paneNode = PeerInfoListPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId, tagMask: .music)
            }
            
            if let (_, disposable) = strongSelf.candidatePane {
                disposable.dispose()
            }
            
            let disposable = MetaDisposable()
            strongSelf.candidatePane = (PeerInfoPaneWrapper(key: key, node: paneNode), disposable)
            
            if let (size, expansionFraction, presentationData) = strongSelf.currentParams {
                strongSelf.update(size: size, expansionFraction: expansionFraction, presentationData: presentationData, transition: .immediate)
            }
            
            disposable.set((paneNode.isReady
            |> take(1)
            |> deliverOnMainQueue).start(next: { _ in
                guard let strongSelf = self else {
                    return
                }
                if let (candidatePane, _) = strongSelf.candidatePane {
                    let previousPane = strongSelf.currentPane
                    strongSelf.candidatePane = nil
                    strongSelf.currentPaneKey = candidatePane.key
                    strongSelf.currentPane = candidatePane
                    
                    if let (size, expansionFraction, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, expansionFraction: expansionFraction, presentationData: presentationData, transition: .animated(duration: 0.35, curve: .spring))
                        
                        if let previousPane = previousPane {
                            let directionToRight: Bool
                            if let previousIndex = strongSelf.availablePanes.index(of: previousPane.key), let updatedIndex = strongSelf.availablePanes.index(of: candidatePane.key) {
                                directionToRight = previousIndex < updatedIndex
                            } else {
                                directionToRight = false
                            }
                            
                            let offset: CGFloat = directionToRight ? previousPane.node.bounds.width : -previousPane.node.bounds.width
                            candidatePane.node.layer.animatePosition(from: CGPoint(x: offset, y: 0.0), to: CGPoint(), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            let previousNode = previousPane.node
                            previousNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -offset, y: 0.0), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak previousNode] _ in
                                previousNode?.removeFromSupernode()
                            })
                        }
                    } else {
                        if let previousPane = previousPane {
                            previousPane.node.removeFromSupernode()
                        }
                    }
                }
            }))
        }
    }
    
    func scrollToTop() -> Bool {
        if let currentPane = self.currentPane {
            return currentPane.node.scrollToTop()
        } else {
            return false
        }
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        return self.currentPane?.node.findLoadedMessage(id: id)
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.currentPane?.node.transitionNodeForGallery(messageId: messageId, media: media)
    }
    
    func update(size: CGSize, expansionFraction: CGFloat, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, expansionFraction, presentationData)
        
        transition.updateAlpha(node: self.coveringBackgroundNode, alpha: expansionFraction)
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.coveringBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.tapsSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let tabsHeight: CGFloat = 48.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.coveringBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: tabsHeight + UIScreenPixel)))
        
        transition.updateFrame(node: self.tapsSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: tabsHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.tabsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: tabsHeight)))
        self.tabsContainerNode.update(size: CGSize(width: size.width, height: tabsHeight), presentationData: presentationData, paneList: self.availablePanes.map { key in
            let title: String
            switch key {
            case .media:
                title = "Media"
            case .files:
                title = "Files"
            case .links:
                title = "Links"
            case .music:
                title = "Audio"
            }
            return PeerInfoPaneSpecifier(key: key, title: title)
        }, selectedPane: self.currentPaneKey, transition: transition)
        
        let paneFrame = CGRect(origin: CGPoint(x: 0.0, y: tabsHeight), size: CGSize(width: size.width, height: size.height - tabsHeight))
        
        if self.currentPane?.key != self.currentPaneKey {
            if let currentPane = self.currentPane {
                currentPane.node.removeFromSupernode()
                self.currentPane = nil
            }
            
            if let currentPaneKey = self.currentPaneKey {
                let paneNode: PeerInfoPaneNode
                switch currentPaneKey {
                case .media:
                    paneNode = PeerInfoVisualMediaPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId)
                case .files:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .file)
                case .links:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self]  id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .webPage)
                case .music:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self]  id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .music)
                }
                self.currentPane = PeerInfoPaneWrapper(key: currentPaneKey, node: paneNode)
            }
        }
        
        if let currentPane = self.currentPane {
            let paneWasAdded = currentPane.node.supernode == nil
            if paneWasAdded {
                self.addSubnode(currentPane.node)
            }
            
            let paneTransition: ContainedViewLayoutTransition = paneWasAdded ? .immediate : transition
            paneTransition.updateFrame(node: currentPane.node, frame: paneFrame)
            currentPane.update(size: paneFrame.size, isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: paneWasAdded, transition: paneTransition)
        }
        if let (candidatePane, _) = self.candidatePane {
            let paneTransition: ContainedViewLayoutTransition = .immediate
            paneTransition.updateFrame(node: candidatePane.node, frame: paneFrame)
            candidatePane.update(size: paneFrame.size, isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: true, transition: paneTransition)
        }
        if !self.didSetIsReady {
            self.didSetIsReady = true
            if let currentPane = self.currentPane {
                self.isReady.set(currentPane.node.isReady)
            } else {
                self.isReady.set(.single(true))
            }
        }
    }
}

protocol PeerInfoScreenItem: class {
    var id: AnyHashable { get }
    func node() -> PeerInfoScreenItemNode
}

class PeerInfoScreenItemNode: ASDisplayNode {
    var bringToFrontForHighlight: (() -> Void)?
    
    func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        preconditionFailure()
    }
}

private final class PeerInfoScreenItemSectionContainerNode: ASDisplayNode {
    let id: AnyHashable
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var currentItems: [PeerInfoScreenItem] = []
    private var itemNodes: [AnyHashable: PeerInfoScreenItemNode] = [:]
    
    init(id: AnyHashable) {
        self.id = id
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
    }
    
    func update(width: CGFloat, presentationData: PresentationData, items: [PeerInfoScreenItem], transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.topSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        var contentHeight: CGFloat = 0.0
        
        for i in 0 ..< items.count {
            let item = items[i]
            
            let itemNode: PeerInfoScreenItemNode
            var wasAdded = false
            if let current = self.itemNodes[item.id] {
                itemNode = current
            } else {
                wasAdded = true
                itemNode = item.node()
                self.itemNodes[item.id] = itemNode
                self.addSubnode(itemNode)
                itemNode.bringToFrontForHighlight = { [weak self, weak itemNode] in
                    guard let strongSelf = self, let itemNode = itemNode else {
                        return
                    }
                    strongSelf.view.bringSubviewToFront(itemNode.view)
                }
            }
            
            let itemTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            let itemHeight = itemNode.update(width: width, presentationData: presentationData, item: item, topItem: i == 0 ? nil : items[i - 1], bottomItem: (i == items.count - 1) ? nil : items[i + 1], transition: itemTransition)
            let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight))
            itemTransition.updateFrame(node: itemNode, frame: itemFrame)
            if wasAdded {
                itemNode.alpha = 0.0
                transition.updateAlpha(node: itemNode, alpha: 1.0)
            }
            contentHeight += itemHeight
        }
        
        var removeIds: [AnyHashable] = []
        for (id, _) in self.itemNodes {
            if !items.contains(where: { $0.id == id }) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes[id] {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: contentHeight)))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: UIScreenPixel)))
        
        return contentHeight
    }
}

private final class PeerInfoScreenData {
    let peer: Peer?
    let cachedData: CachedPeerData?
    let presence: TelegramUserPresence?
    let notificationSettings: TelegramPeerNotificationSettings?
    
    init(
        peer: Peer?,
        cachedData: CachedPeerData?,
        presence: TelegramUserPresence?,
        notificationSettings: TelegramPeerNotificationSettings?
    ) {
        self.peer = peer
        self.cachedData = cachedData
        self.presence = presence
        self.notificationSettings = notificationSettings
    }
}

private enum PeerInfoScreenInputData: Equatable {
    case none
    case user
}

private func peerInfoScreenData(context: AccountContext, peerId: PeerId) -> Signal<PeerInfoScreenData, NoError> {
    return context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
    |> map { view -> PeerInfoScreenInputData in
        guard let peer = (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer else {
            return .none
        }
        if let _ = peer as? TelegramUser {
            return .user
        } else {
            preconditionFailure()
        }
    }
    |> distinctUntilChanged
    |> mapToSignal { inputData -> Signal<PeerInfoScreenData, NoError> in
        switch inputData {
        case .none:
            return .single(PeerInfoScreenData(
                peer: nil,
                cachedData: nil,
                presence: nil,
                notificationSettings: nil
            ))
        case .user:
            return context.account.viewTracker.peerView(peerId, updateData: true)
            |> map { view -> PeerInfoScreenData in
                return PeerInfoScreenData(
                    peer: view.peers[peerId],
                    cachedData: view.cachedData,
                    presence: view.peerPresences[peerId] as? TelegramUserPresence,
                    notificationSettings: view.notificationSettings as? TelegramPeerNotificationSettings
                )
            }
        }
    }
}

private final class PeerInfoInteraction {
    let openUsername: (String) -> Void
    let openPhone: (String) -> Void
    
    init(
        openUsername: @escaping (String) -> Void,
        openPhone: @escaping (String) -> Void
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
    }
}

private func peerInfoSectionItems(data: PeerInfoScreenData?, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [PeerInfoScreenItem] {
    var items: [PeerInfoScreenItem] = []
    if let user = data?.peer as? TelegramUser {
        if let cachedData = data?.cachedData as? CachedUserData {
            if let about = cachedData.about {
                items.append(PeerInfoScreenLabeledValueItem(id: 0, label: "bio", text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 10), action: nil))
            }
        }
        if let username = user.username {
            items.append(PeerInfoScreenLabeledValueItem(id: 1, label: "username", text: "@\(username)", textColor: .accent, action: {
                interaction.openUsername(username)
            }))
        }
        if let phone = user.phone {
            items.append(PeerInfoScreenLabeledValueItem(id: 2, label: "mobile", text: "\(formatPhoneNumber(phone))", textColor: .accent, action: {
                interaction.openPhone(phone)
            }))
        }
    }
    return items
}

private final class PeerInfoScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private weak var controller: PeerInfoScreen?
    
    private let context: AccountContext
    private let peerId: PeerId
    private var presentationData: PresentationData
    let scrollNode: ASScrollNode
    
    let headerNode: PeerInfoHeaderNode
    private let infoSection: PeerInfoScreenItemSectionContainerNode
    private let paneContainerNode: PeerInfoPaneContainerNode
    private var ignoreScrolling: Bool = false
    private var hapticFeedback: HapticFeedback?
    
    private var _interaction: PeerInfoInteraction?
    private var interaction: PeerInfoInteraction {
        return self._interaction!
    }
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private(set) var data: PeerInfoScreenData?
    private var dataDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    init(controller: PeerInfoScreen, context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool) {
        self.controller = controller
        self.context = context
        self.peerId = peerId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.scrollNode = ASScrollNode()
        
        self.headerNode = PeerInfoHeaderNode(context: context, avatarInitiallyExpanded: avatarInitiallyExpanded)
        self.infoSection = PeerInfoScreenItemSectionContainerNode(id: 0)
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, peerId: peerId)
        
        super.init()
        
        self._interaction = PeerInfoInteraction(
            openUsername: { [weak self] value in
                self?.openUsername(value: value)
            },
            openPhone: { [weak self] value in
                self?.openPhone(value: value)
            }
        )
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.infoSection)
        self.scrollNode.addSubnode(self.paneContainerNode)
        self.addSubnode(self.headerNode)
        
        self.paneContainerNode.openMessage = { [weak self] id in
            return self?.openMessage(id: id) ?? false
        }
        
        self.headerNode.performButtonAction = { [weak self] key in
            self?.performButtonAction(key: key)
        }
        
        self.headerNode.requestAvatarExpansion = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
            
            strongSelf.headerNode.updateIsAvatarExpanded(true)
            strongSelf.updateNavigationExpansionPresentation(isExpanded: true, animated: true)
            
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
            }
        }
        
        self.dataDisposable = (peerInfoScreenData(context: context, peerId: peerId)
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateData(data)
        })
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    private func updateData(_ data: PeerInfoScreenData) {
        self.data = data
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func scrollToTop() {
        self.scrollNode.view.setContentOffset(CGPoint(), animated: true)
    }
    
    private func openMessage(id: MessageId) -> Bool {
        guard let galleryMessage = self.paneContainerNode.findLoadedMessage(id: id), let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        self.view.endEditing(true)
        
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, message: galleryMessage, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, transitionNode: { [weak self] messageId, media in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.paneContainerNode.transitionNodeForGallery(messageId: messageId, media: media)
        }, addToTransitionSurface: { [weak self] view in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.addSubview(view)
        }, openUrl: { url in
            //self?.openUrl(url)
        }, openPeer: { peer, navigation in
            //self?.controllerInteraction?.openPeer(peer.id, navigation, nil)
        }, callPeer: { peerId in
            //self?.controllerInteraction?.callPeer(peerId)
        }, enqueueMessage: { _ in
        }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }))
    }
    
    private func performButtonAction(key: PeerInfoHeaderButtonKey) {
        guard let controller = self.controller else {
            return
        }
        switch key {
        case .message:
            if let navigationController = controller.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(self.peerId)))
            }
        case .call:
            self.requestCall()
        case .mute:
            let peerId = self.peerId
            let _ = (self.context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
                let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
                let globalSettings: GlobalNotificationSettings = (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
                return (peerSettings, globalSettings)
            }
            |> deliverOnMainQueue).start(next: { [weak self] peerSettings, globalSettings in
                guard let strongSelf = self else {
                    return
                }
                let soundSettings: NotificationSoundSettings?
                if case .default = peerSettings.messageSound {
                    soundSettings = NotificationSoundSettings(value: nil)
                } else {
                    soundSettings = NotificationSoundSettings(value: peerSettings.messageSound)
                }
                let muteSettingsController = notificationMuteSettingsController(presentationData: strongSelf.presentationData, notificationSettings: globalSettings.effective.groupChats, soundSettings: soundSettings, openSoundSettings: {
                    guard let strongSelf = self else {
                        return
                    }
                    let soundController = notificationSoundSelectionController(context: strongSelf.context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = updatePeerNotificationSoundInteractive(account: strongSelf.context.account, peerId: strongSelf.peerId, sound: sound).start()
                    })
                    strongSelf.controller?.present(soundController, in: .window(.root))
                }, updateSettings: { value in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = updatePeerMuteSetting(account: strongSelf.context.account, peerId: strongSelf.peerId, muteInterval: value).start()
                })
                strongSelf.controller?.present(muteSettingsController, in: .window(.root))
            })
        case .more:
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            var reportSpam = false
            var deleteChat = false
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.UserInfo_StartSecretChat, color: .accent, action: { [weak self] in
                        dismissAction()
                        self?.openStartSecretChat()
                    })
                ]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            controller.present(actionSheet, in: .window(.root))
        case .addMember:
            break
        }
    }
    
    private func openStartSecretChat() {
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, PeerId?) in
            let peer = transaction.getPeer(peerId)
            let filteredPeerIds = Array(transaction.getAssociatedPeerIds(peerId)).filter { $0.namespace == Namespaces.Peer.SecretChat }
            var activeIndices: [ChatListIndex] = []
            for associatedId in filteredPeerIds {
                if let state = (transaction.getPeer(associatedId) as? TelegramSecretChat)?.embeddedState {
                    switch state {
                        case .active, .handshake:
                            if let (_, index) = transaction.getPeerChatListIndex(associatedId) {
                                activeIndices.append(index)
                            }
                        default:
                            break
                    }
                }
            }
            activeIndices.sort()
            if let index = activeIndices.last {
                return (peer, index.messageIndex.id.peerId)
            } else {
                return (peer, nil)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer, currentPeerId in
            guard let strongSelf = self else {
                return
            }
            if let currentPeerId = currentPeerId {
                if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(currentPeerId)))
                }
            } else if let controller = strongSelf.controller {
                let displayTitle = peer?.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder) ?? ""
                controller.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.UserInfo_StartSecretChatConfirmation(displayTitle).0, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.UserInfo_StartSecretChatStart, action: {
                    guard let strongSelf = self else {
                        return
                    }
                    var createSignal = createSecretChat(account: strongSelf.context.account, peerId: peerId)
                    var cancelImpl: (() -> Void)?
                    let progressSignal = Signal<Never, NoError> { subscriber in
                        if let strongSelf = self {
                            let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                cancelImpl?()
                            }))
                            strongSelf.controller?.present(statusController, in: .window(.root))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        } else {
                            return EmptyDisposable
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.15, queue: Queue.mainQueue())
                    let progressDisposable = progressSignal.start()
                    
                    createSignal = createSignal
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    let createSecretChatDisposable = MetaDisposable()
                    cancelImpl = {
                        createSecretChatDisposable.set(nil)
                    }
                    
                    createSecretChatDisposable.set((createSignal
                    |> deliverOnMainQueue).start(next: { peerId in
                        guard let strongSelf = self else {
                            return
                        }
                        if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId)))
                        }
                    }, error: { _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }))
                })]), in: .window(.root))
            }
        })
    }
    
    private func openUsername(value: String) {
        let shareController = ShareController(context: context, subject: .url("\(value)"))
        self.controller?.present(shareController, in: .window(.root))
    }
    
    private func requestCall() {
        guard let peer = self.data?.peer as? TelegramUser, let cachedUserData = self.data?.cachedData as? CachedUserData else {
            return
        }
        if cachedUserData.callsPrivate {
            self.controller?.present(textAlertController(context: self.context, title: self.presentationData.strings.Call_ConnectionErrorTitle, text: self.presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            return
        }
            
        let callResult = self.context.sharedContext.callManager?.requestCall(account: self.context.account, peerId: peer.id, endCurrentIfAny: false)
        if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
            if currentPeerId == peer.id {
                self.context.sharedContext.navigateToCurrentCall()
            } else {
                let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                    return (transaction.getPeer(peer.id), transaction.getPeer(currentPeerId))
                }
                |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                    guard let strongSelf = self else {
                        return
                    }
                    if let peer = peer, let current = current {
                        strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.sharedContext.callManager?.requestCall(account: strongSelf.context.account, peerId: peer.id, endCurrentIfAny: true)
                        })]), in: .window(.root))
                    }
                })
            }
        }
    }
    
    private func openPhone(value: String) {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self else {
                return
            }
            if let peer = peer as? TelegramUser, let peerPhoneNumber = peer.phone, formatPhoneNumber(value) == formatPhoneNumber(peerPhoneNumber) {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                let dismissAction: () -> Void = { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                }
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.UserInfo_TelegramCall, action: {
                            dismissAction()
                            self?.requestCall()
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.UserInfo_PhoneCall, action: {
                            dismissAction()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(value).replacingOccurrences(of: " ", with: ""))")
                        }),
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                strongSelf.controller?.present(actionSheet, in: .window(.root))
            } else {
                strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(value).replacingOccurrences(of: " ", with: ""))")
            }
        })
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition, additive: Bool = false) {
        self.validLayout = (layout, navigationHeight)
        
        self.ignoreScrolling = true
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sectionSpacing: CGFloat = 24.0
        
        var contentHeight: CGFloat = 0.0
        
        let headerHeight = self.headerNode.update(width: layout.size.width, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, contentOffset: self.scrollNode.view.contentOffset.y, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, presence: self.data?.presence, transition: transition, additive: additive)
        let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: headerHeight))
        if additive {
            transition.updateFrameAdditive(node: self.headerNode, frame: headerFrame)
        } else {
            transition.updateFrame(node: self.headerNode, frame: headerFrame)
        }
        contentHeight += headerHeight
        contentHeight += sectionSpacing
        
        let infoSectionHeight = self.infoSection.update(width: layout.size.width, presentationData: self.presentationData, items: peerInfoSectionItems(data: self.data, presentationData: self.presentationData, interaction: self.interaction), transition: transition)
        let infoSectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: infoSectionHeight))
        if additive {
            transition.updateFrameAdditive(node: self.infoSection, frame: infoSectionFrame)
        } else {
            transition.updateFrame(node: self.infoSection, frame: infoSectionFrame)
        }
        contentHeight += infoSectionHeight
        contentHeight += sectionSpacing
        
        let paneContainerSize = CGSize(width: layout.size.width, height: layout.size.height - navigationHeight)
        var restoreContentOffset: CGPoint?
        if additive {
            restoreContentOffset = self.scrollNode.view.contentOffset
        }
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight + paneContainerSize.height)
        if let restoreContentOffset = restoreContentOffset {
            self.scrollNode.view.contentOffset = restoreContentOffset
        }
        
        let paneAreaExpansionDistance: CGFloat = 32.0
        var paneAreaExpansionDelta = (contentHeight - navigationHeight) - self.scrollNode.view.contentOffset.y
        paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
        let paneAreaExpansionFraction: CGFloat = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
        
        let paneContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: paneContainerSize)
        if additive {
            transition.updateFrameAdditive(node: self.paneContainerNode, frame: paneContainerFrame)
        } else {
            transition.updateFrame(node: self.paneContainerNode, frame: paneContainerFrame)
        }
        contentHeight += layout.size.height - navigationHeight
        
        self.ignoreScrolling = false
        self.updateNavigation(transition: transition, additive: additive)
        
        if !self.didSetReady && self.data != nil {
            self.didSetReady = true
            self._ready.set(self.paneContainerNode.isReady.get())
        }
    }
    
    private func updateNavigation(transition: ContainedViewLayoutTransition, additive: Bool) {
        let offsetY = self.scrollNode.view.contentOffset.y
        
        if offsetY <= 50.0 {
            self.scrollNode.view.bounces = true
        } else {
            self.scrollNode.view.bounces = false
        }
        
        if let (layout, navigationHeight) = self.validLayout {
            if !additive {
                self.headerNode.update(width: layout.size.width, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, contentOffset: offsetY, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, presence: self.data?.presence, transition: transition, additive: additive)
            }
            
            let paneAreaExpansionDistance: CGFloat = 32.0
            var paneAreaExpansionDelta = (self.paneContainerNode.frame.minY - navigationHeight) - self.scrollNode.view.contentOffset.y
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            let paneAreaExpansionFraction: CGFloat = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            
            transition.updateAlpha(node: self.headerNode.separatorNode, alpha: 1.0 - paneAreaExpansionFraction)
            
            self.paneContainerNode.update(size: self.paneContainerNode.bounds.size, expansionFraction: paneAreaExpansionFraction, presentationData: self.presentationData, transition: transition)
        }
    }
    
    private var canUpdateAvatarExpansion = false
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.canUpdateAvatarExpansion = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling {
            return
        }
        self.updateNavigation(transition: .immediate, additive: false)
        
        if scrollView.isDragging && scrollView.isTracking {
            let offsetY = self.scrollNode.view.contentOffset.y
            var shouldBeExpanded: Bool?
            if offsetY <= -32.0 {
                shouldBeExpanded = true
            } else if offsetY >= 4.0 {
                shouldBeExpanded = false
            }
            if let shouldBeExpanded = shouldBeExpanded, self.canUpdateAvatarExpansion, shouldBeExpanded != self.headerNode.isAvatarExpanded {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                if shouldBeExpanded {
                    self.hapticFeedback?.impact()
                } else {
                    self.hapticFeedback?.tap()
                }
                
                self.headerNode.updateIsAvatarExpanded(shouldBeExpanded)
                self.updateNavigationExpansionPresentation(isExpanded: shouldBeExpanded, animated: true)
                
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
                
                if !shouldBeExpanded {
                    //scrollView.setContentOffset(CGPoint(), animated: true)
                }
            }
        }
    }
    
    private func updateNavigationExpansionPresentation(isExpanded: Bool, animated: Bool) {
        if let controller = self.controller {
            controller.statusBar.updateStatusBarStyle(isExpanded ? .White : self.presentationData.theme.rootController.statusBarStyle.style, animated: animated)
            
            let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
            let navigationBarPresentationData = NavigationBarPresentationData(
                theme: NavigationBarTheme(
                    buttonColor: isExpanded ? .white : baseNavigationBarPresentationData.theme.buttonColor,
                    disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                    primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                    backgroundColor: .clear,
                    separatorColor: .clear,
                    badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                    badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                    badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
            ), strings: baseNavigationBarPresentationData.strings)
            
            if let navigationBar = controller.navigationBar {
                if animated {
                    UIView.transition(with: navigationBar.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                }
                navigationBar.updatePresentationData(navigationBarPresentationData)
            }
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        if targetContentOffset.pointee.y < 212.0 {
            if targetContentOffset.pointee.y < 212.0 / 2.0 {
                targetContentOffset.pointee.y = 0.0
            } else {
                targetContentOffset.pointee.y = 212.0
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        var currentParent: UIView? = result
        var enableScrolling = true
        while true {
            if currentParent == nil || currentParent === self.view {
                break
            }
            if let scrollView = currentParent as? UIScrollView {
                if scrollView === self.scrollNode.view {
                    break
                }
                if scrollView.isDecelerating && scrollView.contentOffset.y < -scrollView.contentInset.top {
                    return self.scrollNode.view
                }
            } else if let listView = currentParent as? ListViewBackingView, let listNode = listView.target {
                if listNode.scroller.isDecelerating && listNode.scroller.contentOffset.y < listNode.scroller.contentInset.top {
                    return self.scrollNode.view
                }
            }
            currentParent = currentParent?.superview
        }
        return result
    }
}

public final class PeerInfoScreen: ViewController {
    private let context: AccountContext
    private let peerId: PeerId
    private let avatarInitiallyExpanded: Bool
    
    private var presentationData: PresentationData
    
    private var controllerNode: PeerInfoScreenNode {
        return self.displayNode as! PeerInfoScreenNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool = false) {
        self.context = context
        self.peerId = peerId
        self.avatarInitiallyExpanded = avatarInitiallyExpanded
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            theme: NavigationBarTheme(
                buttonColor: avatarInitiallyExpanded ? .white : baseNavigationBarPresentationData.theme.buttonColor,
                disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                backgroundColor: .clear,
                separatorColor: .clear,
                badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
        ), strings: baseNavigationBarPresentationData.strings))
        self.navigationBar?.makeCustomTransitionNode = { [weak self] other in
            guard let strongSelf = self else {
                return nil
            }
            if strongSelf.controllerNode.scrollNode.view.contentOffset.y > .ulpOfOne {
                return nil
            }
            if let tag = other.userInfo as? PeerInfoNavigationSourceTag, tag.peerId == peerId {
                return PeerInfoNavigationTransitionNode(screenNode: strongSelf.controllerNode, presentationData: strongSelf.presentationData, headerNode: strongSelf.controllerNode.headerNode)
            }
            return nil
        }
        
        self.statusBar.statusBarStyle = avatarInitiallyExpanded ? .White : self.presentationData.theme.rootController.statusBarStyle.style
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerInfoScreenNode(controller: self, context: self.context, peerId: self.peerId, avatarInitiallyExpanded: self.avatarInitiallyExpanded)
        
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private func getUserPeer(postbox: Postbox, peerId: PeerId) -> Signal<(Peer?, CachedPeerData?), NoError> {
    return postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        var resultPeer: Peer?
        if let peer = peer as? TelegramSecretChat {
            resultPeer = transaction.getPeer(peer.regularPeerId)
        } else {
            resultPeer = peer
        }
        return (resultPeer, resultPeer.flatMap({ transaction.getPeerCachedData(peerId: $0.id) }))
    }
}

final class PeerInfoNavigationSourceTag {
    let peerId: PeerId
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
}

private final class PeerInfoNavigationTransitionNode: ASDisplayNode, CustomNavigationTransitionNode {
    private let screenNode: PeerInfoScreenNode
    private let presentationData: PresentationData
    
    private var topNavigationBar: NavigationBar?
    private var bottomNavigationBar: NavigationBar?
    
    private let headerNode: PeerInfoHeaderNode
    
    private var previousBackButtonArrow: ASDisplayNode?
    private var currentBackButtonArrow: ASDisplayNode?
    private var previousBackButtonBadge: ASDisplayNode?
    private var previousRightButton: ASDisplayNode?
    private var currentBackButton: ASDisplayNode?
    
    private var previousTitleNode: (ASDisplayNode, TextNode)?
    private var previousStatusNode: (ASDisplayNode, ASDisplayNode)?
    
    private var didSetup: Bool = false
    
    init(screenNode: PeerInfoScreenNode, presentationData: PresentationData, headerNode: PeerInfoHeaderNode) {
        self.screenNode = screenNode
        self.presentationData = presentationData
        self.headerNode = headerNode
        
        super.init()
        
        self.addSubnode(headerNode)
    }
    
    func setup(topNavigationBar: NavigationBar, bottomNavigationBar: NavigationBar) {
        self.topNavigationBar = topNavigationBar
        self.bottomNavigationBar = bottomNavigationBar
        
        topNavigationBar.isHidden = true
        bottomNavigationBar.isHidden = true
        
        if let previousBackButtonArrow = bottomNavigationBar.makeTransitionBackArrowNode(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
            self.previousBackButtonArrow = previousBackButtonArrow
            self.addSubnode(previousBackButtonArrow)
        }
        if self.screenNode.headerNode.isAvatarExpanded, let currentBackButtonArrow = topNavigationBar.makeTransitionBackArrowNode(accentColor: self.screenNode.headerNode.isAvatarExpanded ? .white : self.presentationData.theme.rootController.navigationBar.accentTextColor) {
            self.currentBackButtonArrow = currentBackButtonArrow
            self.addSubnode(currentBackButtonArrow)
        }
        if let previousBackButtonBadge = bottomNavigationBar.makeTransitionBadgeNode() {
            self.previousBackButtonBadge = previousBackButtonBadge
            self.addSubnode(previousBackButtonBadge)
        }
        if let previousRightButton = bottomNavigationBar.makeTransitionRightButtonNode(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
            self.previousRightButton = previousRightButton
            self.addSubnode(previousRightButton)
        }
        if let currentBackButton = topNavigationBar.makeTransitionBackButtonNode(accentColor: self.screenNode.headerNode.isAvatarExpanded ? .white : self.presentationData.theme.rootController.navigationBar.accentTextColor) {
            self.currentBackButton = currentBackButton
            self.addSubnode(currentBackButton)
        }
        if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView {
            let previousTitleNode = previousTitleView.titleNode.makeCopy()
            let previousTitleContainerNode = ASDisplayNode()
            previousTitleContainerNode.addSubnode(previousTitleNode)
            self.previousTitleNode = (previousTitleContainerNode, previousTitleNode)
            self.addSubnode(previousTitleContainerNode)
            
            let previousStatusNode = previousTitleView.activityNode.makeCopy()
            let previousStatusContainerNode = ASDisplayNode()
            previousStatusContainerNode.addSubnode(previousStatusNode)
            self.previousStatusNode = (previousStatusContainerNode, previousStatusNode)
            self.addSubnode(previousStatusContainerNode)
        }
    }
    
    func update(containerSize: CGSize, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }
        
        if let previousBackButtonArrow = self.previousBackButtonArrow {
            let previousBackButtonArrowFrame = bottomNavigationBar.backButtonArrow.view.convert(bottomNavigationBar.backButtonArrow.view.bounds, to: bottomNavigationBar.view)
            previousBackButtonArrow.frame = previousBackButtonArrowFrame
        }
        
        if let currentBackButtonArrow = self.currentBackButtonArrow {
            let currentBackButtonArrowFrame = topNavigationBar.backButtonArrow.view.convert(topNavigationBar.backButtonArrow.view.bounds, to: topNavigationBar.view)
            currentBackButtonArrow.frame = currentBackButtonArrowFrame
            
            transition.updateAlpha(node: currentBackButtonArrow, alpha: 1.0 - fraction)
            if let previousBackButtonArrow = self.previousBackButtonArrow {
                transition.updateAlpha(node: previousBackButtonArrow, alpha: fraction)
            }
        }
        
        if let previousBackButtonBadge = self.previousBackButtonBadge {
            let previousBackButtonBadgeFrame = bottomNavigationBar.badgeNode.view.convert(bottomNavigationBar.badgeNode.view.bounds, to: bottomNavigationBar.view)
            previousBackButtonBadge.frame = previousBackButtonBadgeFrame
            
            transition.updateAlpha(node: previousBackButtonBadge, alpha: fraction)
        }
        
        if let previousRightButton = self.previousRightButton {
            let previousRightButtonFrame = bottomNavigationBar.rightButtonNode.view.convert(bottomNavigationBar.rightButtonNode.view.bounds, to: bottomNavigationBar.view)
            previousRightButton.frame = previousRightButtonFrame
            transition.updateAlpha(node: previousRightButton, alpha: fraction)
        }
        
        if let currentBackButton = self.currentBackButton {
            let currentBackButtonFrame = topNavigationBar.backButtonNode.view.convert(topNavigationBar.backButtonNode.view.bounds, to: topNavigationBar.view)
            transition.updateFrame(node: currentBackButton, frame: currentBackButtonFrame.offsetBy(dx: fraction * 12.0, dy: 0.0))
            
            transition.updateAlpha(node: currentBackButton, alpha: (1.0 - fraction))
        }
        
        if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView, let avatarNode = previousTitleView.avatarNode, let (previousTitleContainerNode, previousTitleNode) = self.previousTitleNode, let (previousStatusContainerNode, previousStatusNode) = self.previousStatusNode {
            let previousTitleFrame = previousTitleView.titleNode.view.convert(previousTitleView.titleNode.bounds, to: bottomNavigationBar.view)
            let previousStatusFrame = previousTitleView.activityNode.view.convert(previousTitleView.activityNode.bounds, to: bottomNavigationBar.view)
            
            self.headerNode.navigationTransition = PeerInfoHeaderNavigationTransition(sourceNavigationBar: bottomNavigationBar, sourceTitleView: previousTitleView, sourceTitleFrame: previousTitleFrame, sourceSubtitleFrame: previousStatusFrame, fraction: fraction)
            if let (layout, navigationHeight) = self.screenNode.validLayout {
                self.headerNode.update(width: layout.size.width, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: topNavigationBar.bounds.height, contentOffset: 0.0, presentationData: self.presentationData, peer: self.screenNode.data?.peer, cachedData: self.screenNode.data?.cachedData, notificationSettings: self.screenNode.data?.notificationSettings, presence: self.screenNode.data?.presence, transition: transition, additive: false)
            }
            
            let titleScale = (fraction * previousTitleNode.bounds.height + (1.0 - fraction) * self.headerNode.titleNode.bounds.height) / previousTitleNode.bounds.height
            let subtitleScale = (fraction * previousStatusNode.bounds.height + (1.0 - fraction) * self.headerNode.subtitleNode.bounds.height) / previousStatusNode.bounds.height
            
            transition.updateFrame(node: previousTitleContainerNode, frame: CGRect(origin: self.headerNode.titleNodeRawContainer.frame.origin.offsetBy(dx: previousTitleFrame.size.width * 0.5 * (titleScale - 1.0), dy: previousTitleFrame.size.height * 0.5 * (titleScale - 1.0)), size: previousTitleFrame.size))
            transition.updateFrame(node: previousTitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: previousTitleFrame.size))
            transition.updateFrame(node: previousStatusContainerNode, frame: CGRect(origin: self.headerNode.subtitleNodeRawContainer.frame.origin.offsetBy(dx: previousStatusFrame.size.width * 0.5 * (subtitleScale - 1.0), dy: previousStatusFrame.size.height * 0.5 * (subtitleScale - 1.0)), size: previousStatusFrame.size))
            transition.updateFrame(node: previousStatusNode, frame: CGRect(origin: CGPoint(), size: previousStatusFrame.size))
            
            transition.updateSublayerTransformScale(node: previousTitleContainerNode, scale: titleScale)
            transition.updateSublayerTransformScale(node: previousStatusContainerNode, scale: subtitleScale)
            
            transition.updateAlpha(node: self.headerNode.titleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(node: previousTitleNode, alpha: fraction)
            transition.updateAlpha(node: self.headerNode.subtitleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(node: previousStatusNode, alpha: fraction)
        }
    }
    
    func restore() {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }
        
        topNavigationBar.isHidden = false
        bottomNavigationBar.isHidden = false
        self.headerNode.navigationTransition = nil
        self.screenNode.insertSubnode(self.headerNode, aboveSubnode: self.screenNode.scrollNode)
    }
}
