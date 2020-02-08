import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import SyncCore
import TelegramCore
import AvatarNode
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PhotoResources
import PeerAvatarGalleryUI
import TelegramStringFormatting

enum PeerInfoHeaderButtonKey: Hashable {
    case message
    case call
    case mute
    case more
    case addMember
}

enum PeerInfoHeaderButtonIcon {
    case message
    case call
    case mute
    case unmute
    case more
    case addMember
}

final class PeerInfoHeaderButtonNode: HighlightableButtonNode {
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

final class PeerInfoHeaderNavigationTransition {
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

enum PeerInfoAvatarListItem: Equatable {
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

final class PeerInfoAvatarListItemNode: ASDisplayNode {
    let imageNode: TransformImageNode
    
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
        let imageSize = CGSize(width: min(size.width, size.height), height: min(size.width, size.height))
        let makeLayout = self.imageNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
        let _ = applyLayout()
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize))
    }
}

final class PeerInfoAvatarListContainerNode: ASDisplayNode {
    private let context: AccountContext
    
    let controlsContainerNode: ASDisplayNode
    let controlsContainerTransformNode: ASDisplayNode
    let shadowNode: ASDisplayNode
    
    let contentNode: ASDisplayNode
    private(set) var galleryEntries: [AvatarGalleryEntry] = []
    private var items: [PeerInfoAvatarListItem] = []
    private var itemNodes: [WrappedMediaResourceId: PeerInfoAvatarListItemNode] = [:]
    private var currentIndex: Int = 0
    private var transitionFraction: CGFloat = 0.0
    
    private var validLayout: CGSize?
    
    private let disposable = MetaDisposable()
    private var initializedList = false
    
    let isReady = Promise<Bool>()
    private var didSetReady = false
    
    var currentItemNode: PeerInfoAvatarListItemNode? {
        if self.currentIndex >= 0 && self.currentIndex < self.items.count {
            return self.itemNodes[self.items[self.currentIndex].id]
        } else {
            return nil
        }
    }
    
    init(context: AccountContext) {
        self.context = context
        
        self.contentNode = ASDisplayNode()
        
        self.controlsContainerNode = ASDisplayNode()
        self.controlsContainerNode.isUserInteractionEnabled = false
        
        self.controlsContainerTransformNode = ASDisplayNode()
        self.controlsContainerTransformNode.isUserInteractionEnabled = false
        
        self.shadowNode = ASDisplayNode()
        //self.shadowNode.backgroundColor = .green
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.contentNode)
        
        self.controlsContainerNode.addSubnode(self.shadowNode)
        self.controlsContainerTransformNode.addSubnode(self.controlsContainerNode)
        self.addSubnode(self.controlsContainerTransformNode)
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    func selectFirstItem() {
        self.currentIndex = 0
        if let size = self.validLayout {
            self.updateItems(size: size, transition: .immediate)
        }
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
                strongSelf.galleryEntries = entries
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

final class PeerInfoAvatarTransformContainerNode: ASDisplayNode {
    let context: AccountContext
    let avatarNode: AvatarNode
    
    var tapped: (() -> Void)?
    
    private var isFirstAvatarLoading = true
    
    init(context: AccountContext) {
        self.context = context
        let avatarFont = avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0))
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
            var overrideImage: AvatarNodeImageOverride?
            if peer.isDeleted {
                overrideImage = .deletedIcon
            }
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: peer, overrideImage: overrideImage, synchronousLoad: self.isFirstAvatarLoading, displayDimensions: CGSize(width: 100.0, height: 100.0))
            self.isFirstAvatarLoading = false
        }
    }
}

final class PeerInfoEditingAvatarNode: ASDisplayNode {
    let context: AccountContext
    let avatarNode: AvatarNode
    
    var tapped: (() -> Void)?
    
    init(context: AccountContext) {
        self.context = context
        let avatarFont = avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0))
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
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: peer, synchronousLoad: false, displayDimensions: CGSize(width: 100.0, height: 100.0))
        }
    }
}

final class PeerInfoAvatarListNode: ASDisplayNode {
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
    
    func animateAvatarCollapse(transition: ContainedViewLayoutTransition) {
        if let currentItemNode = self.listContainerNode.currentItemNode, let avatarCopyView = self.avatarContainerNode.avatarNode.view.snapshotContentTree(), case let .animated(duration, curve) = transition {
            avatarCopyView.center = currentItemNode.imageNode.position
            currentItemNode.view.addSubview(avatarCopyView)
            let scale = currentItemNode.imageNode.bounds.height / avatarCopyView.bounds.height
            avatarCopyView.layer.transform = CATransform3DMakeScale(scale, scale, scale)
            avatarCopyView.alpha = 0.0
            transition.updateAlpha(layer: avatarCopyView.layer, alpha: 1.0, completion: { [weak avatarCopyView] _ in
                Queue.mainQueue().after(0.1, {
                    avatarCopyView?.removeFromSuperview()
                })
            })
        }
    }
}

final class PeerInfoHeaderNavigationButton: HighlightableButtonNode {
    private let regularTextNode: ImmediateTextNode
    private let whiteTextNode: ImmediateTextNode
    private let iconNode: ASImageNode
    
    private var key: PeerInfoHeaderNavigationButtonKey?
    private var theme: PresentationTheme?
    
    var isWhite: Bool = false {
        didSet {
            if self.isWhite != oldValue {
                self.regularTextNode.isHidden = self.isWhite
                self.whiteTextNode.isHidden = !self.isWhite
            }
        }
    }
    
    var action: (() -> Void)?
    
    override init() {
        self.regularTextNode = ImmediateTextNode()
        self.whiteTextNode = ImmediateTextNode()
        self.whiteTextNode.isHidden = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.regularTextNode)
        self.addSubnode(self.whiteTextNode)
        self.addSubnode(self.iconNode)
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressed() {
        self.action?()
    }
    
    func update(key: PeerInfoHeaderNavigationButtonKey, presentationData: PresentationData) -> CGSize {
        let textSize: CGSize
        if self.key != key || self.theme !== presentationData.theme {
            self.key = key
            self.theme = presentationData.theme
            
            let text: String
            var icon: UIImage?
            var isBold = false
            switch key {
            case .edit:
                text = presentationData.strings.Common_Edit
            case .done, .cancel, .selectionDone:
                text = presentationData.strings.Common_Done
                isBold = true
            case .select:
                text = presentationData.strings.Common_Select
            case .search:
                text = ""
                icon = PresentationResourcesRootController.navigationCompactSearchIcon(presentationData.theme)
            }
            
            let font: UIFont = isBold ? Font.semibold(17.0) : Font.regular(17.0)
            
            self.regularTextNode.attributedText = NSAttributedString(string: text, font: font, textColor: presentationData.theme.rootController.navigationBar.accentTextColor)
            self.whiteTextNode.attributedText = NSAttributedString(string: text, font: font, textColor: .white)
            self.iconNode.image = icon
            
            textSize = self.regularTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            let _ = self.whiteTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        } else {
            textSize = self.regularTextNode.bounds.size
        }
        
        let inset: CGFloat = 0.0
        let height: CGFloat = 44.0
        
        let textFrame = CGRect(origin: CGPoint(x: inset, y: floor((height - textSize.height) / 2.0)), size: textSize)
        self.regularTextNode.frame = textFrame
        self.whiteTextNode.frame = textFrame
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((height - image.size.height) / 2.0)), size: image.size)
            
            return CGSize(width: image.size.width + inset * 2.0, height: height)
        } else {
            return CGSize(width: textSize.width + inset * 2.0, height: height)
        }
    }
}

enum PeerInfoHeaderNavigationButtonKey {
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
}

struct PeerInfoHeaderNavigationButtonSpec: Equatable {
    let key: PeerInfoHeaderNavigationButtonKey
    let isForExpandedView: Bool
}

final class PeerInfoHeaderNavigationButtonContainerNode: ASDisplayNode {
    private var buttonNodes: [PeerInfoHeaderNavigationButtonKey: PeerInfoHeaderNavigationButton] = [:]
    
    private var currentButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    
    var isWhite: Bool = false {
        didSet {
            if self.isWhite != oldValue {
                for (_, buttonNode) in self.buttonNodes {
                    buttonNode.isWhite = self.isWhite
                }
            }
        }
    }
    
    var performAction: ((PeerInfoHeaderNavigationButtonKey) -> Void)?
    
    override init() {
        super.init()
    }
    
    func update(size: CGSize, presentationData: PresentationData, buttons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        let maximumExpandOffset: CGFloat = 14.0
        let expandOffset: CGFloat = -expandFraction * maximumExpandOffset
        if self.currentButtons != buttons {
            self.currentButtons = buttons
            
            var nextRegularButtonOrigin = size.width - 16.0
            var nextExpandedButtonOrigin = size.width - 16.0
            for spec in buttons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                if let current = self.buttonNodes[spec.key] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.buttonNodes[spec.key] = buttonNode
                    self.addSubnode(buttonNode)
                    buttonNode.isWhite = self.isWhite
                    buttonNode.action = { [weak self] in
                        self?.performAction?(spec.key)
                    }
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData)
                var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                nextButtonOrigin -= buttonSize.width + 4.0
                if spec.isForExpandedView {
                    nextExpandedButtonOrigin = nextButtonOrigin
                } else {
                    nextRegularButtonOrigin = nextButtonOrigin
                }
                if wasAdded {
                    buttonNode.frame = buttonFrame
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                }
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonKey] = []
            for (key, _) in self.buttonNodes {
                if !buttons.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let buttonNode = self.buttonNodes.removeValue(forKey: key) {
                    buttonNode.removeFromSupernode()
                }
            }
        } else {
            var nextRegularButtonOrigin = size.width - 16.0
            var nextExpandedButtonOrigin = size.width - 16.0
            for spec in buttons.reversed() {
                if let buttonNode = self.buttonNodes[spec.key] {
                    let buttonSize = buttonNode.bounds.size
                    var nextButtonOrigin = spec.isForExpandedView ? nextExpandedButtonOrigin : nextRegularButtonOrigin
                    let buttonFrame = CGRect(origin: CGPoint(x: nextButtonOrigin - buttonSize.width, y: expandOffset + (spec.isForExpandedView ? maximumExpandOffset : 0.0)), size: buttonSize)
                    nextButtonOrigin -= buttonSize.width + 4.0
                    if spec.isForExpandedView {
                        nextExpandedButtonOrigin = nextButtonOrigin
                    } else {
                        nextRegularButtonOrigin = nextButtonOrigin
                    }
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
            }
        }
    }
}

final class PeerInfoHeaderRegularContentNode: ASDisplayNode {
    
}

enum PeerInfoHeaderTextFieldNodeKey {
    case firstName
    case lastName
    case title
    case description
}

protocol PeerInfoHeaderTextFieldNode: ASDisplayNode {
    var text: String { get }
    
    func update(width: CGFloat, safeInset: CGFloat, hasPrevious: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat
}

final class PeerInfoHeaderSingleLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode {
    private let textNode: TextFieldNode
    private let topSeparator: ASDisplayNode
    
    private var theme: PresentationTheme?
    
    var text: String {
        return self.textNode.textField.text ?? ""
    }
    
    override init() {
        self.textNode = TextFieldNode()
        self.topSeparator = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.topSeparator)
    }
    
    func update(width: CGFloat, safeInset: CGFloat, hasPrevious: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            self.textNode.textField.textColor = presentationData.theme.list.itemPrimaryTextColor
            //self.textNode.textField.keyboardAppearance = presentationData.theme.keyboardAppearance
            self.textNode.textField.tintColor = presentationData.theme.list.itemAccentColor
        }
        
        let attributedPlaceholderText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPlaceholderTextColor)
        if self.textNode.textField.attributedPlaceholder == nil || !self.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
            self.textNode.textField.attributedPlaceholder = attributedPlaceholderText
            self.textNode.textField.accessibilityHint = attributedPlaceholderText.string
        }
        
        if let updateText = updateText {
            self.textNode.textField.text = updateText
        }
        
        self.topSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.topSeparator.frame = CGRect(origin: CGPoint(x: safeInset + (hasPrevious ? 16.0 : 0.0), y: 0.0), size: CGSize(width: width, height: UIScreenPixel))
        
        let height: CGFloat = 44.0
        
        self.textNode.frame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: floor((height - 40.0) / 2.0)), size: CGSize(width: max(1.0, width - 16.0 * 2.0), height: 40.0))
        
        self.textNode.isUserInteractionEnabled = isEnabled
        self.textNode.alpha = isEnabled ? 1.0 : 0.6
        
        return height
    }
}

/*final class PeerInfoHeaderMultiLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode {
    private let textNode: TextFieldNode
    private let topSeparator: ASDisplayNode
    
    override init() {
        self.textNode = TextFieldNode()
        self.topSeparator = ASDisplayNode()
        
        super.init()
    }
    
    func update(width: CGFloat, safeInset: CGFloat) -> CGFloat {
        return 44.0
    }
}*/

final class PeerInfoHeaderEditingContentNode: ASDisplayNode {
    private let context: AccountContext
    let avatarNode: PeerInfoEditingAvatarNode
    
    var itemNodes: [PeerInfoHeaderTextFieldNodeKey: PeerInfoHeaderTextFieldNode] = [:]
    
    init(context: AccountContext) {
        self.context = context
        self.avatarNode = PeerInfoEditingAvatarNode(context: context)
        
        super.init()
        
        self.addSubnode(self.avatarNode)
    }
    
    func editingTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) -> String? {
        return self.itemNodes[key]?.text
    }
    
    func update(width: CGFloat, safeInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, peer: Peer?, isContact: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        let avatarSize: CGFloat = 100.0
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 10.0), size: CGSize(width: avatarSize, height: avatarSize))
        transition.updateFrameAdditiveToCenter(node: self.avatarNode, frame: CGRect(origin: avatarFrame.center, size: CGSize()))
        
        var contentHeight: CGFloat = statusBarHeight + 10.0 + 100.0 + 20.0
        
        var fieldKeys: [PeerInfoHeaderTextFieldNodeKey] = []
        if let user = peer as? TelegramUser {
            if !user.isDeleted {
                fieldKeys.append(.firstName)
                if user.botInfo == nil {
                    fieldKeys.append(.lastName)
                }
            }
        }
        var hasPrevious = false
        for key in fieldKeys {
            let itemNode: PeerInfoHeaderTextFieldNode
            var updateText: String?
            if let current = self.itemNodes[key] {
                itemNode = current
            } else {
                switch key {
                case .firstName:
                    updateText = (peer as? TelegramUser)?.firstName ?? ""
                case .lastName:
                    updateText = (peer as? TelegramUser)?.lastName ?? ""
                case .title:
                    updateText = (peer as? TelegramUser)?.debugDisplayTitle ?? ""
                case .description:
                    break
                }
                itemNode = PeerInfoHeaderSingleLineTextFieldNode()
                self.itemNodes[key] = itemNode
                self.addSubnode(itemNode)
            }
            let placeholder: String
            var isEnabled = true
            switch key {
            case .firstName:
                placeholder = "First Name"
                isEnabled = isContact
            case .lastName:
                placeholder = "Last Name"
                isEnabled = isContact
            case .title:
                placeholder = "Title"
            case .description:
                placeholder = "Description"
            }
            let itemHeight = itemNode.update(width: width, safeInset: safeInset, hasPrevious: hasPrevious, placeholder: placeholder, isEnabled: isEnabled, presentationData: presentationData, updateText: updateText)
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight)))
            contentHeight += itemHeight
            hasPrevious = true
        }
        var removeKeys: [PeerInfoHeaderTextFieldNodeKey] = []
        for (key, _) in self.itemNodes {
            if !fieldKeys.contains(key) {
                removeKeys.append(key)
            }
        }
        for key in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: key) {
                itemNode.removeFromSupernode()
            }
        }
        
        return contentHeight
    }
}

final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private var presentationData: PresentationData?
    
    private(set) var isAvatarExpanded: Bool
    
    let avatarListNode: PeerInfoAvatarListNode
    
    let regularContentNode: PeerInfoHeaderRegularContentNode
    let editingContentNode: PeerInfoHeaderEditingContentNode
    let titleNodeContainer: ASDisplayNode
    let titleNodeRawContainer: ASDisplayNode
    let titleNode: ImmediateTextNode
    let titleCredibilityIconNode: ASImageNode
    let subtitleNodeContainer: ASDisplayNode
    let subtitleNodeRawContainer: ASDisplayNode
    let subtitleNode: ImmediateTextNode
    private var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    private let backgroundNode: ASDisplayNode
    private let expandedBackgroundNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    let navigationButtonContainer: PeerInfoHeaderNavigationButtonContainerNode
    
    var performButtonAction: ((PeerInfoHeaderButtonKey) -> Void)?
    var requestAvatarExpansion: (([AvatarGalleryEntry], (ASDisplayNode, CGRect, () -> (UIView?, UIView?))) -> Void)?
    
    var navigationTransition: PeerInfoHeaderNavigationTransition?
    
    init(context: AccountContext, avatarInitiallyExpanded: Bool) {
        self.context = context
        self.isAvatarExpanded = avatarInitiallyExpanded
        
        self.avatarListNode = PeerInfoAvatarListNode(context: context, readyWhenGalleryLoads: avatarInitiallyExpanded)
        
        self.titleNodeContainer = ASDisplayNode()
        self.titleNodeRawContainer = ASDisplayNode()
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.titleCredibilityIconNode = ASImageNode()
        self.titleCredibilityIconNode.displaysAsynchronously = false
        self.titleCredibilityIconNode.displayWithoutProcessing = true
        self.titleNode.addSubnode(self.titleCredibilityIconNode)
        
        self.subtitleNodeContainer = ASDisplayNode()
        self.subtitleNodeRawContainer = ASDisplayNode()
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        
        self.regularContentNode = PeerInfoHeaderRegularContentNode()
        self.editingContentNode = PeerInfoHeaderEditingContentNode(context: context)
        self.editingContentNode.alpha = 0.0
        
        self.navigationButtonContainer = PeerInfoHeaderNavigationButtonContainerNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.expandedBackgroundNode = ASDisplayNode()
        self.expandedBackgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.expandedBackgroundNode)
        self.addSubnode(self.separatorNode)
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.regularContentNode.addSubnode(self.titleNodeContainer)
        self.subtitleNodeContainer.addSubnode(self.subtitleNode)
        self.regularContentNode.addSubnode(self.subtitleNodeContainer)
        self.regularContentNode.addSubnode(self.avatarListNode)
        self.addSubnode(self.regularContentNode)
        self.addSubnode(self.editingContentNode)
        self.addSubnode(self.navigationButtonContainer)
        
        self.avatarListNode.avatarContainerNode.tapped = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let avatarNode = strongSelf.avatarListNode.avatarContainerNode.avatarNode
            strongSelf.requestAvatarExpansion?(strongSelf.avatarListNode.listContainerNode.galleryEntries, (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
            }))
        }
    }
    
    func updateAvatarIsHidden(_ isHidden: Bool) {
        self.avatarListNode.avatarContainerNode.avatarNode.isHidden = isHidden
    }
    
    func update(width: CGFloat, containerHeight: CGFloat, containerInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, contentOffset: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, notificationSettings: TelegramPeerNotificationSettings?, statusData: PeerInfoStatusData?, isContact: Bool, state: PeerInfoState, transition: ContainedViewLayoutTransition, additive: Bool) -> CGFloat {
        let themeUpdated = self.presentationData?.theme !== presentationData.theme
        self.presentationData = presentationData
        
        if themeUpdated {
            self.titleCredibilityIconNode.image = PresentationResourcesItemList.verifiedPeerIcon(presentationData.theme)
        }
        
        self.regularContentNode.alpha = state.isEditing ? 0.0 : 1.0
        self.editingContentNode.alpha = state.isEditing ? 1.0 : 0.0
        
        let editingContentHeight = self.editingContentNode.update(width: width, safeInset: containerInset, statusBarHeight: statusBarHeight, navigationHeight: navigationHeight, peer: state.isEditing ? peer : nil, isContact: isContact, presentationData: presentationData, transition: transition)
        transition.updateFrame(node: self.editingContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -contentOffset), size: CGSize(width: width, height: editingContentHeight)))
        
        var transitionSourceHeight: CGFloat = 0.0
        var transitionFraction: CGFloat = 0.0
        var transitionSourceAvatarFrame = CGRect()
        var transitionSourceTitleFrame = CGRect()
        var transitionSourceSubtitleFrame = CGRect()
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.expandedBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        
        if let navigationTransition = self.navigationTransition, let sourceAvatarNode = navigationTransition.sourceTitleView.avatarNode?.avatarNode {
            transitionSourceHeight = navigationTransition.sourceNavigationBar.bounds.height
            transitionFraction = navigationTransition.fraction
            transitionSourceAvatarFrame = sourceAvatarNode.view.convert(sourceAvatarNode.view.bounds, to: navigationTransition.sourceNavigationBar.view)
            transitionSourceTitleFrame = navigationTransition.sourceTitleFrame
            transitionSourceSubtitleFrame = navigationTransition.sourceSubtitleFrame
            
            transition.updateAlpha(node: self.expandedBackgroundNode, alpha: transitionFraction)
        } else {
            let backgroundTransitionFraction: CGFloat = max(0.0, min(1.0, contentOffset / (212.0)))
            transition.updateAlpha(node: self.expandedBackgroundNode, alpha: backgroundTransitionFraction)
        }
        
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let defaultButtonSize: CGFloat = 40.0
        let defaultMaxButtonSpacing: CGFloat = 40.0
        let expandedAvatarListHeight = min(width, containerHeight - 64.0)
        let expandedAvatarListSize = CGSize(width: width, height: expandedAvatarListHeight)
        
        let buttonKeys: [PeerInfoHeaderButtonKey] = peerInfoHeaderButtons(peer: peer, cachedData: cachedData)
        
        if let peer = peer {
            self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.medium(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            
            let subtitleString: NSAttributedString?
            if let statusData = statusData {
                let subtitleColor: UIColor
                if statusData.isActivity {
                    subtitleColor = presentationData.theme.list.itemAccentColor
                } else {
                    subtitleColor = presentationData.theme.list.itemSecondaryTextColor
                }
                subtitleString = NSAttributedString(string: statusData.text, font: Font.regular(15.0), textColor: subtitleColor)
            } else {
                subtitleString = nil
            }
            self.subtitleNode.attributedText = subtitleString
        }
        
        let textSideInset: CGFloat = 16.0
        let expandedAvatarControlsHeight: CGFloat = 64.0
        let expandedAvatarHeight: CGFloat = expandedAvatarListSize.height + expandedAvatarControlsHeight
        
        let avatarSize: CGFloat = 100.0
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 10.0), size: CGSize(width: avatarSize, height: avatarSize))
        let avatarCenter = CGPoint(x: (1.0 - transitionFraction) * avatarFrame.midX + transitionFraction * transitionSourceAvatarFrame.midX, y: (1.0 - transitionFraction) * avatarFrame.midY + transitionFraction * transitionSourceAvatarFrame.midY)
        
        var isVerified = false
        if let peer = peer, peer.isVerified {
            isVerified = true
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - textSideInset * 2.0 - (isVerified ? 16.0 : 0.0), height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: width - textSideInset * 2.0, height: .greatestFiniteMagnitude))
        
        if let image = self.titleCredibilityIconNode.image {
            transition.updateFrame(node: self.titleCredibilityIconNode, frame: CGRect(origin: CGPoint(x: titleSize.width + 4.0, y: floor((titleSize.height - image.size.height) / 2.0) + 1.0), size: image.size))
            self.titleCredibilityIconNode.isHidden = !isVerified
        }
        
        let titleFrame: CGRect
        let subtitleFrame: CGRect
        if self.isAvatarExpanded {
            titleFrame = CGRect(origin: CGPoint(x: 16.0, y: expandedAvatarHeight - expandedAvatarControlsHeight + 12.0 + (subtitleSize.height.isZero ? 10.0 : 0.0)), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: 16.0, y: titleFrame.maxY - 5.0), size: subtitleSize)
        } else {
            titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 10.0 + (subtitleSize.height.isZero ? 11.0 : 0.0)), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: floor((width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
        }
        
        let titleLockOffset: CGFloat = 7.0 + (subtitleSize.height.isZero ? 8.0 : 0.0)
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
        let avatarListFrame = CGRect(origin: CGPoint(), size: expandedAvatarListSize)
        
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
        self.editingContentNode.avatarNode.update(peer: peer, theme: presentationData.theme)
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
        }
        let apparentAvatarFrame: CGRect
        if self.isAvatarExpanded {
            let expandedAvatarCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.height / 2.0 - contentOffset / 2.0)
            apparentAvatarFrame = CGRect(origin: CGPoint(x: expandedAvatarCenter.x * (1.0 - transitionFraction) + transitionFraction * avatarCenter.x, y: expandedAvatarCenter.y * (1.0 - transitionFraction) + transitionFraction * avatarCenter.y), size: CGSize())
        } else {
            apparentAvatarFrame = CGRect(origin: CGPoint(x: avatarCenter.x - avatarFrame.width / 2.0, y: -contentOffset + avatarOffset + avatarCenter.y - avatarFrame.height / 2.0), size: avatarFrame.size)
        }
        if case let .animated(duration, curve) = transition, !transitionSourceAvatarFrame.width.isZero, false {
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
                let neutralAvatarListContainerSize = expandedAvatarListSize
                let avatarListContainerSize = CGSize(width: neutralAvatarListContainerSize.width * (1.0 - transitionFraction) + transitionSourceAvatarFrame.width * transitionFraction, height: neutralAvatarListContainerSize.height * (1.0 - transitionFraction) + transitionSourceAvatarFrame.height * transitionFraction)
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -avatarListContainerSize.width / 2.0, y: -avatarListContainerSize.height / 2.0), size: avatarListContainerSize)
            } else {
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -expandedAvatarListSize.width / 2.0, y: -expandedAvatarListSize.height / 2.0), size: expandedAvatarListSize)
            }
            avatarListContainerScale = 1.0 + max(0.0, -contentOffset / avatarListContainerFrame.height)
        } else {
            avatarListContainerFrame = CGRect(origin: CGPoint(x: -apparentAvatarFrame.width / 2.0, y: -apparentAvatarFrame.height / 2.0), size: apparentAvatarFrame.size)
            avatarListContainerScale = avatarScale
        }
        transition.updateFrame(node: self.avatarListNode.listContainerNode, frame: avatarListContainerFrame)
        let innerScale = avatarListContainerFrame.height / expandedAvatarListSize.height
        let innerDeltaX = (avatarListContainerFrame.width - expandedAvatarListSize.width) / 2.0
        let innerDeltaY = (avatarListContainerFrame.height - expandedAvatarListSize.height) / 2.0
        transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerNode, scale: innerScale)
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.contentNode, frame: CGRect(origin: CGPoint(x: innerDeltaX + expandedAvatarListSize.width / 2.0, y: innerDeltaY + expandedAvatarListSize.height / 2.0), size: CGSize()))
        
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsContainerTransformNode, frame: CGRect(origin: CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.height / 2.0 - innerDeltaY), size: CGSize()))
        transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerNode.controlsContainerNode, scale: 1.0 / innerScale)
        transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.listContainerNode.controlsContainerTransformNode, scale: 1.0 / avatarListContainerScale)
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.shadowNode, frame: CGRect(origin: CGPoint(x: -apparentAvatarFrame.minX, y: -apparentAvatarFrame.minY), size: CGSize(width: expandedAvatarListSize.width, height: navigationHeight)))
        
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        }
        
        self.avatarListNode.listContainerNode.update(size: expandedAvatarListSize, peer: peer, transition: transition)
        
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
                let subtitleScale = max(0.01, min(10.0, (transitionFraction * transitionSourceSubtitleFrame.height + (1.0 - transitionFraction) * subtitleFrame.height * neutralSubtitleScale) / (subtitleFrame.height)))
                
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
                self.regularContentNode.addSubnode(buttonNode)
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
            
            let hiddenWhileExpanded: Bool
            switch buttonKey {
            case .mute:
                hiddenWhileExpanded = true
            default:
                hiddenWhileExpanded = false
            }
            
            if self.isAvatarExpanded, hiddenWhileExpanded {
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
        
        let resolvedRegularHeight: CGFloat
        if self.isAvatarExpanded {
            resolvedRegularHeight = expandedAvatarListSize.height + expandedAvatarControlsHeight
        } else {
            resolvedRegularHeight = 212.0 + navigationHeight
        }
        
        let backgroundFrame: CGRect
        let separatorFrame: CGRect
        
        let resolvedHeight: CGFloat
        if state.isEditing {
            resolvedHeight = editingContentHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + resolvedHeight - contentOffset), size: CGSize(width: width, height: 2000.0))
            separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: resolvedHeight - contentOffset), size: CGSize(width: width, height: UIScreenPixel))
        } else {
            resolvedHeight = resolvedRegularHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + apparentHeight), size: CGSize(width: width, height: 2000.0))
            separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: apparentHeight), size: CGSize(width: width, height: UIScreenPixel))
        }
        
        transition.updateFrame(node: self.regularContentNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: resolvedHeight)))
        
        if additive {
            transition.updateFrameAdditive(node: self.backgroundNode, frame: backgroundFrame)
            transition.updateFrameAdditive(node: self.expandedBackgroundNode, frame: backgroundFrame)
            transition.updateFrameAdditive(node: self.separatorNode, frame: separatorFrame)
        } else {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            transition.updateFrame(node: self.expandedBackgroundNode, frame: backgroundFrame)
            transition.updateFrame(node: self.separatorNode, frame: separatorFrame)
        }
        
        return resolvedHeight
    }
    
    private func buttonPressed(_ buttonNode: PeerInfoHeaderButtonNode) {
        self.performButtonAction?(buttonNode.key)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result.isDescendant(of: self.navigationButtonContainer.view) {
            return result
        }
        if !self.backgroundNode.frame.contains(point) {
            return nil
        }
        if result == self.view || result == self.regularContentNode.view || result == self.editingContentNode.view {
            return nil
        }
        return result
    }
    
    func updateIsAvatarExpanded(_ isAvatarExpanded: Bool, transition: ContainedViewLayoutTransition) {
        if self.isAvatarExpanded != isAvatarExpanded {
            self.isAvatarExpanded = isAvatarExpanded
            if isAvatarExpanded {
                self.avatarListNode.listContainerNode.selectFirstItem()
            }
            if case .animated = transition, !isAvatarExpanded {
                self.avatarListNode.animateAvatarCollapse(transition: transition)
            }
        }
    }
}
