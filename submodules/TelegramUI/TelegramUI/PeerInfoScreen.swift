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
import TelegramIntents
import PeerInfoUI
import SearchBarNode
import SearchUI

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
        let imageSize = CGSize(width: min(size.width, size.height), height: min(size.width, size.height))
        let makeLayout = self.imageNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
        let _ = applyLayout()
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize))
    }
}

private final class PeerInfoAvatarListContainerNode: ASDisplayNode {
    private let context: AccountContext
    
    let controlsContainerNode: ASDisplayNode
    let controlsContainerTransformNode: ASDisplayNode
    let shadowNode: ASDisplayNode
    
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
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: peer, synchronousLoad: self.isFirstAvatarLoading, displayDimensions: CGSize(width: 100.0, height: 100.0))
            self.isFirstAvatarLoading = false
        }
    }
}

private final class PeerInfoEditingAvatarNode: ASDisplayNode {
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

private final class PeerInfoHeaderNavigationButton: HighlightableButtonNode {
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

private enum PeerInfoHeaderNavigationButtonKey {
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
}

private struct PeerInfoHeaderNavigationButtonSpec: Equatable {
    let key: PeerInfoHeaderNavigationButtonKey
    let isForExpandedView: Bool
}

private final class PeerInfoHeaderNavigationButtonContainerNode: ASDisplayNode {
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

private final class PeerInfoHeaderRegularContentNode: ASDisplayNode {
    
}

private enum PeerInfoHeaderTextFieldNodeKey {
    case firstName
    case lastName
    case title
    case description
}

private protocol PeerInfoHeaderTextFieldNode: ASDisplayNode {
    var text: String { get }
    
    func update(width: CGFloat, safeInset: CGFloat, hasPrevious: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat
}

private final class PeerInfoHeaderSingleLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode {
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

/*private final class PeerInfoHeaderMultiLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode {
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

private final class PeerInfoHeaderEditingContentNode: ASDisplayNode {
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
        if let _ = peer as? TelegramUser {
            fieldKeys.append(.firstName)
            fieldKeys.append(.lastName)
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

private final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private var presentationData: PresentationData?
    
    private(set) var isAvatarExpanded: Bool
    
    let avatarListNode: PeerInfoAvatarListNode
    
    let regularContentNode: PeerInfoHeaderRegularContentNode
    let editingContentNode: PeerInfoHeaderEditingContentNode
    let titleNodeContainer: ASDisplayNode
    let titleNodeRawContainer: ASDisplayNode
    let titleNode: ImmediateTextNode
    let subtitleNodeContainer: ASDisplayNode
    let subtitleNodeRawContainer: ASDisplayNode
    let subtitleNode: ImmediateTextNode
    private var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    private let backgroundNode: ASDisplayNode
    private let expandedBackgroundNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    let navigationButtonContainer: PeerInfoHeaderNavigationButtonContainerNode
    
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
            if !strongSelf.isAvatarExpanded {
                strongSelf.requestAvatarExpansion?()
            }
        }
    }
    
    func update(width: CGFloat, containerHeight: CGFloat, containerInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, contentOffset: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, notificationSettings: TelegramPeerNotificationSettings?, presence: TelegramUserPresence?, isContact: Bool, state: PeerInfoState, transition: ContainedViewLayoutTransition, additive: Bool) -> CGFloat {
        self.presentationData = presentationData
        
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
            
            //transition.updateBackgroundColor(node: self.backgroundNode, color: presentationData.theme.list.itemBlocksBackgroundColor.interpolateTo(presentationData.theme.rootController.navigationBar.backgroundColor, fraction: transitionFraction)!)
            transition.updateAlpha(node: self.expandedBackgroundNode, alpha: transitionFraction)
        } else {
            let backgroundTransitionFraction: CGFloat = max(0.0, min(1.0, contentOffset / (212.0)))
            transition.updateAlpha(node: self.expandedBackgroundNode, alpha: backgroundTransitionFraction)
            //transition.updateBackgroundColor(node: self.backgroundNode, color: presentationData.theme.list.itemBlocksBackgroundColor.interpolateTo(presentationData.theme.rootController.navigationBar.backgroundColor, fraction: backgroundTransitionFraction)!)
        }
        
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let defaultButtonSize: CGFloat = 40.0
        let defaultMaxButtonSpacing: CGFloat = 40.0
        let expandedAvatarListHeight = min(width, containerHeight - 64.0)
        let expandedAvatarListSize = CGSize(width: width, height: expandedAvatarListHeight)
        
        var buttonKeys: [PeerInfoHeaderButtonKey] = []
        
        if let peer = peer {
            buttonKeys.append(.message)
            buttonKeys.append(.call)
            buttonKeys.append(.mute)
            buttonKeys.append(.more)
            
            self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.medium(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            
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
        let expandedAvatarHeight: CGFloat = expandedAvatarListSize.height + expandedAvatarControlsHeight
        
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
            case .more:
                hiddenWhileExpanded = false
            default:
                hiddenWhileExpanded = true
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
    
    func updateIsAvatarExpanded(_ isAvatarExpanded: Bool) {
        self.isAvatarExpanded = isAvatarExpanded
    }
}

protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    func update(size: CGSize, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func transferVelocity(_ velocity: CGFloat)
    func findLoadedMessage(id: MessageId) -> Message?
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    func updateSelectedMessages(animated: Bool)
}

final class PeerInfoPaneInteraction {
    var selectedMessageIds: Set<MessageId>?
    
    let toggleMessageSelected: (MessageId) -> Void
    let openPeer: (Peer) -> Void
    
    init(
        toggleMessageSelected: @escaping (MessageId) -> Void,
        openPeer: @escaping (Peer) -> Void
    ) {
        self.toggleMessageSelected = toggleMessageSelected
        self.openPeer = openPeer
    }
}

private final class PeerInfoPaneWrapper {
    let key: PeerInfoPaneKey
    let node: PeerInfoPaneNode
    private var appliedParams: (CGSize, CGFloat, Bool, PresentationData)?
    
    init(key: PeerInfoPaneKey, node: PeerInfoPaneNode) {
        self.key = key
        self.node = node
    }
    
    func update(size: CGSize, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        if let (currentSize, visibleHeight, currentIsScrollingLockedAtTop, currentPresentationData) = self.appliedParams {
            if currentSize == size && currentIsScrollingLockedAtTop == isScrollingLockedAtTop && currentPresentationData === presentationData {
                return
            }
        }
        self.appliedParams = (size, visibleHeight, isScrollingLockedAtTop, presentationData)
        self.node.update(size: size, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: synchronous, transition: transition)
    }
}

private enum PeerInfoPaneKey {
    case media
    case files
    case links
    case voice
    case music
    case groupsInCommon
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
        
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
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
        
        let focusOnSelectedPane = self.currentParams?.1 != selectedPane
        
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
            if focusOnSelectedPane {
                if selectedPane == paneList.first?.key {
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size))
                } else if selectedPane == paneList.last?.key {
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width, y: 0.0), size: self.scrollNode.bounds.size))
                } else {
                    let contentOffsetX = max(0.0, min(self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width, floor(selectedFrame.midX - self.scrollNode.bounds.width / 2.0)))
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: contentOffsetX, y: 0.0), size: self.scrollNode.bounds.size))
                }
            }
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
    
    private var currentParams: (size: CGSize, visibleHeight: CGFloat, expansionFraction: CGFloat, presentationData: PresentationData, data: PeerInfoScreenData?)?
    private(set) var currentPaneKey: PeerInfoPaneKey?
    private(set) var currentPane: PeerInfoPaneWrapper?
    
    private var currentCandidatePaneKey: PeerInfoPaneKey?
    private var candidatePane: (PeerInfoPaneWrapper, Disposable, Bool)?
    
    var selectionPanelNode: PeerInfoSelectionPanelNode?
    
    var _paneInteraction: PeerInfoPaneInteraction?
    var paneInteraction: PeerInfoPaneInteraction {
        return self._paneInteraction!
    }
    
    var openMessage: ((MessageId) -> Bool)?
    var toggleMessageSelected: ((MessageId) -> Void)?
    var openPeer: ((Peer) -> Void)?
    var currentPaneUpdated: (() -> Void)?
    
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
        
        self._paneInteraction = PeerInfoPaneInteraction(
            toggleMessageSelected: { [weak self] id in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.toggleMessageSelected?(id)
            },
            openPeer: { [weak self] peer in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.openPeer?(peer)
            }
        )
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coveringBackgroundNode)
        self.addSubnode(self.tabsContainerNode)
        self.addSubnode(self.tapsSeparatorNode)
        
        self.tabsContainerNode.requestSelectPane = { [weak self] key in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentPaneKey == key {
                return
            }
            if strongSelf.currentCandidatePaneKey == key {
                return
            }
            strongSelf.currentCandidatePaneKey = key
            
            if let (size, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                strongSelf.update(size: size, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: .immediate)
            }
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
    
    func updateSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?, animated: Bool) {
        if self.paneInteraction.selectedMessageIds != selectedMessageIds {
            self.paneInteraction.selectedMessageIds = selectedMessageIds
            self.currentPane?.node.updateSelectedMessages(animated: animated)
            self.candidatePane?.0.node.updateSelectedMessages(animated: animated)
        }
    }
    
    func update(size: CGSize, visibleHeight: CGFloat, expansionFraction: CGFloat, presentationData: PresentationData, data: PeerInfoScreenData?, transition: ContainedViewLayoutTransition) {
        let availablePanes = data?.availablePanes ?? []
        
        let previousCurrentPaneKey = self.currentPaneKey
        if availablePanes.isEmpty {
            self.currentPaneKey = nil
            self.currentCandidatePaneKey = nil
            if let (_, disposable, _) = self.candidatePane {
                disposable.dispose()
                self.candidatePane = nil
            }
            if let currentPane = self.currentPane {
                self.currentPane = nil
                currentPane.node.removeFromSupernode()
            }
        } else if (self.currentParams?.data?.availablePanes ?? []).isEmpty {
            self.currentCandidatePaneKey = availablePanes.first
        }
        
        self.currentParams = (size, visibleHeight, expansionFraction, presentationData, data)
        
        transition.updateAlpha(node: self.coveringBackgroundNode, alpha: expansionFraction)
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.coveringBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.tapsSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let tabsHeight: CGFloat = 48.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.coveringBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: tabsHeight + UIScreenPixel)))
        
        transition.updateFrame(node: self.tapsSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: tabsHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        let paneFrame = CGRect(origin: CGPoint(x: 0.0, y: tabsHeight), size: CGSize(width: size.width, height: size.height - tabsHeight))
        
        if let currentCandidatePaneKey = self.currentCandidatePaneKey {
            if self.candidatePane?.0.key != currentCandidatePaneKey {
                self.candidatePane?.1.dispose()
                
                let paneNode: PeerInfoPaneNode
                switch currentCandidatePaneKey {
                case .media:
                    paneNode = PeerInfoVisualMediaPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, interaction: self.paneInteraction)
                case .files:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .file, interaction: self.paneInteraction)
                case .links:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .webPage, interaction: self.paneInteraction)
                case .voice:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .voiceOrInstantVideo, interaction: self.paneInteraction)
                case .music:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .music, interaction: self.paneInteraction)
                case .groupsInCommon:
                    paneNode = PeerInfoGroupsInCommonPaneNode(context: self.context, peerId: peerId, interaction: self.paneInteraction, peers: data?.groupsInCommon ?? [])
                }
                
                let disposable = MetaDisposable()
                self.candidatePane = (PeerInfoPaneWrapper(key: currentCandidatePaneKey, node: paneNode), disposable, false)
                
                var shouldReLayout = false
                disposable.set((paneNode.isReady
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    if let (candidatePane, disposable, _) = strongSelf.candidatePane {
                        strongSelf.candidatePane = (candidatePane, disposable, true)
                        
                        if shouldReLayout {
                            if let (size, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                                strongSelf.update(size: size, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: strongSelf.currentPane != nil ? .animated(duration: 0.35, curve: .spring) : .immediate)
                            }
                        }
                    }
                }))
                shouldReLayout = true
            }
        }
        
        if let (candidatePane, _, isReady) = self.candidatePane, isReady {
            let previousPane = self.currentPane
            self.candidatePane = nil
            self.currentPaneKey = candidatePane.key
            self.currentCandidatePaneKey = nil
            self.currentPane = candidatePane
            
            if let selectionPanelNode = self.selectionPanelNode {
                self.insertSubnode(candidatePane.node, belowSubnode: selectionPanelNode)
            } else {
                self.addSubnode(candidatePane.node)
            }
            candidatePane.node.frame = paneFrame
            candidatePane.update(size: paneFrame.size, visibleHeight: max(0.0, visibleHeight - paneFrame.minY), isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: true, transition: .immediate)
            
            if let previousPane = previousPane {
                let directionToRight: Bool
                if let previousIndex = availablePanes.index(of: previousPane.key), let updatedIndex = availablePanes.index(of: candidatePane.key) {
                    directionToRight = previousIndex < updatedIndex
                } else {
                    directionToRight = false
                }
                
                let offset: CGFloat = directionToRight ? previousPane.node.bounds.width : -previousPane.node.bounds.width
                
                transition.animatePositionAdditive(node: candidatePane.node, offset: CGPoint(x: offset, y: 0.0))
                let previousNode = previousPane.node
                transition.updateFrame(node: previousNode, frame: paneFrame.offsetBy(dx: -offset, dy: 0.0), completion: { [weak previousNode] _ in
                    previousNode?.removeFromSupernode()
                })
            }
        } else if let currentPane = self.currentPane {
            let paneWasAdded = currentPane.node.supernode == nil
            if paneWasAdded {
                self.addSubnode(currentPane.node)
            }
            
            let paneTransition: ContainedViewLayoutTransition = paneWasAdded ? .immediate : transition
            paneTransition.updateFrame(node: currentPane.node, frame: paneFrame)
            currentPane.update(size: paneFrame.size, visibleHeight: visibleHeight, isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: paneWasAdded, transition: paneTransition)
        }
        
        transition.updateFrame(node: self.tabsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: tabsHeight)))
        self.tabsContainerNode.update(size: CGSize(width: size.width, height: tabsHeight), presentationData: presentationData, paneList: availablePanes.map { key in
            let title: String
            switch key {
            case .media:
                title = "Media"
            case .files:
                title = "Files"
            case .links:
                title = "Links"
            case .voice:
                title = "Voice Messages"
            case .music:
                title = "Audio"
            case .groupsInCommon:
                title = "Groups"
            }
            return PeerInfoPaneSpecifier(key: key, title: title)
        }, selectedPane: self.currentPaneKey, transition: transition)
        
        if let (candidatePane, _, _) = self.candidatePane {
            let paneTransition: ContainedViewLayoutTransition = .immediate
            paneTransition.updateFrame(node: candidatePane.node, frame: paneFrame)
            candidatePane.update(size: paneFrame.size, visibleHeight: visibleHeight, isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: true, transition: paneTransition)
        }
        if !self.didSetIsReady && data != nil {
            if let currentPane = self.currentPane {
                self.didSetIsReady = true
                self.isReady.set(currentPane.node.isReady)
            } else if self.candidatePane == nil {
                self.didSetIsReady = true
                self.isReady.set(.single(true))
            }
        }
        if let previousCurrentPaneKey = previousCurrentPaneKey, self.currentPaneKey != previousCurrentPaneKey {
            self.currentPaneUpdated?()
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
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: contentHeight)))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: UIScreenPixel)))
        
        if contentHeight.isZero {
            transition.updateAlpha(node: self.topSeparatorNode, alpha: 0.0)
            transition.updateAlpha(node: self.bottomSeparatorNode, alpha: 0.0)
        } else {
            transition.updateAlpha(node: self.topSeparatorNode, alpha: 1.0)
            transition.updateAlpha(node: self.bottomSeparatorNode, alpha: 1.0)
        }
        
        return contentHeight
    }
}

private final class PeerInfoSelectionPanelNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let deleteMessages: () -> Void
    private let shareMessages: () -> Void
    private let forwardMessages: () -> Void
    private let reportMessages: () -> Void
    
    let selectionPanel: ChatMessageSelectionInputPanelNode
    let separatorNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    
    init(context: AccountContext, peerId: PeerId, deleteMessages: @escaping () -> Void, shareMessages: @escaping () -> Void, forwardMessages: @escaping () -> Void, reportMessages: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.deleteMessages = deleteMessages
        self.shareMessages = shareMessages
        self.forwardMessages = forwardMessages
        self.reportMessages = reportMessages
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.separatorNode = ASDisplayNode()
        self.backgroundNode = ASDisplayNode()
        
        self.selectionPanel = ChatMessageSelectionInputPanelNode(theme: presentationData.theme, strings: presentationData.strings, peerMedia: true)
        self.selectionPanel.context = context
        self.selectionPanel.backgroundColor = presentationData.theme.chat.inputPanel.panelBackgroundColor
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, deleteSelectedMessages: {
            deleteMessages()
        }, reportSelectedMessages: {
            reportMessages()
        }, reportMessages: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
            forwardMessages()
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, shareSelectedMessages: {
            shareMessages()
        }, updateTextInputStateAndMode: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, openSearchResults: {
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _ in
        }, navigateToChat: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _, _, _ in
            return false
        }, sendBotCommand: { _, _ in
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: {
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _ in
        }, unpinMessage: {
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: {
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: {
        }, reportPeerIrrelevantGeoLocation: {
        }, displaySlowmodeTooltip: { _, _ in
        }, displaySendMessageOptions: { _, _ in
        }, openScheduledMessages: {
        }, displaySearchResultsTooltip: { _, _ in
        }, statuses: nil)
        
        selectionPanel.interfaceInteraction = interfaceInteraction
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.selectionPanel)
    }
    
    func update(width: CGFloat, safeInset: CGFloat, metrics: LayoutMetrics, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        
        let interfaceState = ChatPresentationInterfaceState(chatWallpaper: .color(0), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, limitsConfiguration: .defaultValue, fontSize: .regular, bubbleCorners: PresentationChatBubbleCorners(mainRadius: 16.0, auxiliaryRadius: 8.0, mergeBubbleCorners: true), accountPeerId: self.context.account.peerId, mode: .standard(previewing: false), chatLocation: .peer(self.peerId), isScheduledMessages: false)
        let panelHeight = self.selectionPanel.updateLayout(width: width, leftInset: safeInset, rightInset: safeInset, maxHeight: 0.0, isSecondary: false, transition: transition, interfaceState: interfaceState, metrics: metrics)
        
        transition.updateFrame(node: self.selectionPanel, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight)))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
}

private final class PeerInfoState {
    let isEditing: Bool
    let isSearching: Bool
    let selectedMessageIds: Set<MessageId>?
    
    init(
        isEditing: Bool,
        isSearching: Bool,
        selectedMessageIds: Set<MessageId>?
    ) {
        self.isEditing = isEditing
        self.isSearching = isSearching
        self.selectedMessageIds = selectedMessageIds
    }
    
    func withIsEditing(_ isEditing: Bool) -> PeerInfoState {
        return PeerInfoState(
            isEditing: isEditing,
            isSearching: self.isSearching,
            selectedMessageIds: self.selectedMessageIds
        )
    }
    
    func withSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> PeerInfoState {
        return PeerInfoState(
            isEditing: self.isEditing,
            isSearching: self.isSearching,
            selectedMessageIds: selectedMessageIds
        )
    }
}

private final class PeerInfoScreenData {
    let peer: Peer?
    let cachedData: CachedPeerData?
    let presence: TelegramUserPresence?
    let notificationSettings: TelegramPeerNotificationSettings?
    let globalNotificationSettings: GlobalNotificationSettings?
    let isContact: Bool
    let availablePanes: [PeerInfoPaneKey]
    let groupsInCommon: [Peer]?
    
    init(
        peer: Peer?,
        cachedData: CachedPeerData?,
        presence: TelegramUserPresence?,
        notificationSettings: TelegramPeerNotificationSettings?,
        globalNotificationSettings: GlobalNotificationSettings?,
        isContact: Bool,
        availablePanes: [PeerInfoPaneKey],
        groupsInCommon: [Peer]?
    ) {
        self.peer = peer
        self.cachedData = cachedData
        self.presence = presence
        self.notificationSettings = notificationSettings
        self.globalNotificationSettings = globalNotificationSettings
        self.isContact = isContact
        self.availablePanes = availablePanes
        self.groupsInCommon = groupsInCommon
    }
}

private enum PeerInfoScreenInputData: Equatable {
    case none
    case user
}

private func peerInfoAvailableMediaPanes(context: AccountContext, peerId: PeerId) -> Signal<[PeerInfoPaneKey], NoError> {
    let tags: [(MessageTags, PeerInfoPaneKey)] = [
        (.photoOrVideo, .media),
        (.file, .files),
        (.music, .music),
        (.voiceOrInstantVideo, .voice),
        (.webPage, .links)
    ]
    return combineLatest(tags.map { tagAndKey -> Signal<PeerInfoPaneKey?, NoError> in
        let (tag, key) = tagAndKey
        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .upperBound, anchorIndex: .upperBound, count: 2, clipHoles: false, fixedCombinedReadStates: nil, tagMask: tag)
        |> map { (view, _, _) -> PeerInfoPaneKey? in
            if view.entries.isEmpty {
                return nil
            } else {
                return key
            }
        }
    })
    |> map { keys -> [PeerInfoPaneKey] in
        return keys.compactMap { $0 }
    }
    |> distinctUntilChanged
    /*return context.account.postbox.combinedView(keys: tags.map { (tag, _) -> PostboxViewKey in
        return .historyTagInfo(peerId: peerId, tag: tag)
    })
    |> map { view -> [PeerInfoPaneKey] in
        return tags.compactMap { (tag, key) -> PeerInfoPaneKey? in
            if let info = view.views[.historyTagInfo(peerId: peerId, tag: tag)] as? HistoryTagInfoView, !info.isEmpty {
                return key
            } else {
                return nil
            }
        }
    }
    |> distinctUntilChanged*/
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
                notificationSettings: nil,
                globalNotificationSettings: nil,
                isContact: false,
                availablePanes: [],
                groupsInCommon: nil
            ))
        case .user:
            let groupsInCommonSignal: Signal<[Peer]?, NoError> = .single(nil)
            |> then(
                groupsInCommon(account: context.account, peerId: peerId)
                |> map(Optional.init)
            )
            let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
            return combineLatest(
                context.account.viewTracker.peerView(peerId, updateData: true),
                peerInfoAvailableMediaPanes(context: context, peerId: peerId),
                context.account.postbox.combinedView(keys: [.peerChatState(peerId: peerId), globalNotificationsKey]),
                groupsInCommonSignal
            )
            |> map { peerView, availablePanes, combinedView, groupsInCommon -> PeerInfoScreenData in
                var globalNotificationSettings: GlobalNotificationSettings = .defaultSettings
                if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
                    if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                        globalNotificationSettings = settings
                    }
                }
                
                var availablePanes = availablePanes
                if let groupsInCommon = groupsInCommon, !groupsInCommon.isEmpty {
                    availablePanes.append(.groupsInCommon)
                }
                
                return PeerInfoScreenData(
                    peer: peerView.peers[peerId],
                    cachedData: peerView.cachedData,
                    presence: peerView.peerPresences[peerId] as? TelegramUserPresence,
                    notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings,
                    globalNotificationSettings: globalNotificationSettings,
                    isContact: peerView.peerIsContact,
                    availablePanes: availablePanes,
                    groupsInCommon: groupsInCommon
                )
            }
        }
    }
}

private final class PeerInfoInteraction {
    let openUsername: (String) -> Void
    let openPhone: (String) -> Void
    let editingOpenNotificationSettings: () -> Void
    let editingOpenSoundSettings: () -> Void
    let editingToggleShowMessageText: (Bool) -> Void
    let requestDeleteContact: () -> Void
    let openAddContact: () -> Void
    let updateBlocked: (Bool) -> Void
    
    init(
        openUsername: @escaping (String) -> Void,
        openPhone: @escaping (String) -> Void,
        editingOpenNotificationSettings: @escaping () -> Void,
        editingOpenSoundSettings: @escaping () -> Void,
        editingToggleShowMessageText: @escaping (Bool) -> Void,
        requestDeleteContact: @escaping () -> Void,
        openAddContact: @escaping () -> Void,
        updateBlocked: @escaping (Bool) -> Void
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
        self.editingOpenNotificationSettings = editingOpenNotificationSettings
        self.editingOpenSoundSettings = editingOpenSoundSettings
        self.editingToggleShowMessageText = editingToggleShowMessageText
        self.requestDeleteContact = requestDeleteContact
        self.openAddContact = openAddContact
        self.updateBlocked = updateBlocked
    }
}

private func peerInfoSectionItems(data: PeerInfoScreenData?, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [PeerInfoScreenItem] {
    guard let data = data else {
        return []
    }
    var items: [PeerInfoScreenItem] = []
    if let user = data.peer as? TelegramUser {
        if let phone = user.phone {
            items.append(PeerInfoScreenLabeledValueItem(id: 2, label: "mobile", text: "\(formatPhoneNumber(phone))", textColor: .accent, action: {
                interaction.openPhone(phone)
            }))
        }
        if let username = user.username {
            items.append(PeerInfoScreenLabeledValueItem(id: 1, label: "username", text: "@\(username)", textColor: .accent, action: {
                interaction.openUsername(username)
            }))
        }
        if let cachedData = data.cachedData as? CachedUserData {
            if let about = cachedData.about {
                items.append(PeerInfoScreenLabeledValueItem(id: 0, label: "bio", text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 10), action: nil))
            }
        }
        if !data.isContact {
            items.append(PeerInfoScreenActionItem(id: 3, text: "Add Contact", action: {
                interaction.openAddContact()
            }))
            if let cachedData = data.cachedData as? CachedUserData {
                if cachedData.isBlocked {
                    items.append(PeerInfoScreenActionItem(id: 4, text: "Unblock", action: {
                        interaction.updateBlocked(false)
                    }))
                } else {
                    if user.flags.contains(.isSupport) {
                    } else {
                        items.append(PeerInfoScreenActionItem(id: 4, text: "Block User", color: .destructive, action: {
                            interaction.updateBlocked(true)
                        }))
                    }
                }
            }
        }
    }
    return items
}

private func editingInfoSectionItems(data: PeerInfoScreenData?, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [PeerInfoScreenItem] {
    guard let data = data else {
        return []
    }
    var items: [PeerInfoScreenItem] = []
    
    if let _ = data.peer as? TelegramUser {
        if let notificationSettings = data.notificationSettings {
            let notificationsLabel: String
            let soundLabel: String
            let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings ?? TelegramPeerNotificationSettings.defaultSettings
            if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                if until < Int32.max - 1 {
                    notificationsLabel = stringForRemainingMuteInterval(strings: presentationData.strings, muteInterval: until)
                } else {
                    notificationsLabel = presentationData.strings.UserInfo_NotificationsDisabled
                }
            } else {
                notificationsLabel = presentationData.strings.UserInfo_NotificationsEnabled
            }
        
            let globalNotificationSettings: GlobalNotificationSettings = data.globalNotificationSettings ?? GlobalNotificationSettings.defaultSettings
            soundLabel = localizedPeerNotificationSoundString(strings: presentationData.strings, sound: notificationSettings.messageSound, default: globalNotificationSettings.effective.privateChats.sound)
            
            items.append(PeerInfoScreenDisclosureItem(id: 0, label: notificationsLabel, text: "Notifications", action: {
                interaction.editingOpenNotificationSettings()
            }))
            items.append(PeerInfoScreenDisclosureItem(id: 1, label: soundLabel, text: "Sound", action: {
                interaction.editingOpenSoundSettings()
            }))
            items.append(PeerInfoScreenSwitchItem(id: 2, text: "Show Message Text", value: notificationSettings.displayPreviews != .hide, toggled: { value in
                interaction.editingToggleShowMessageText(value)
            }))
        }
    }
    
    return items
}

private func editingActionsSectionItems(data: PeerInfoScreenData?, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [PeerInfoScreenItem] {
    var items: [PeerInfoScreenItem] = []
    if let data = data {
        if data.isContact {
            items.append(PeerInfoScreenActionItem(id: 0, text: "Delete Contact", color: .destructive, action: {
                interaction.requestDeleteContact()
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
    private let editingInfoSection: PeerInfoScreenItemSectionContainerNode
    private let editingActionsSection: PeerInfoScreenItemSectionContainerNode
    private let paneContainerNode: PeerInfoPaneContainerNode
    private var ignoreScrolling: Bool = false
    private var hapticFeedback: HapticFeedback?
    
    private var searchDisplayController: SearchDisplayController?
    
    private var _interaction: PeerInfoInteraction?
    private var interaction: PeerInfoInteraction {
        return self._interaction!
    }
    
    private var _chatInterfaceInteraction: ChatControllerInteraction?
    private var chatInterfaceInteraction: ChatControllerInteraction {
        return self._chatInterfaceInteraction!
    }
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private(set) var data: PeerInfoScreenData?
    private(set) var state = PeerInfoState(
        isEditing: false,
        isSearching: false,
        selectedMessageIds: nil
    )
    private var dataDisposable: Disposable?
    
    private let activeActionDisposable = MetaDisposable()
    
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
        self.editingInfoSection = PeerInfoScreenItemSectionContainerNode(id: 1)
        self.editingActionsSection = PeerInfoScreenItemSectionContainerNode(id: 2)
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, peerId: peerId)
        
        super.init()
        
        self._interaction = PeerInfoInteraction(
            openUsername: { [weak self] value in
                self?.openUsername(value: value)
            },
            openPhone: { [weak self] value in
                self?.openPhone(value: value)
            },
            editingOpenNotificationSettings: { [weak self] in
                self?.editingOpenNotificationSettings()
            },
            editingOpenSoundSettings: { [weak self] in
                self?.editingOpenSoundSettings()
            },
            editingToggleShowMessageText: { [weak self] value in
                self?.editingToggleShowMessageText(value: value)
            },
            requestDeleteContact: { [weak self] in
                self?.requestDeleteContact()
            },
            openAddContact: { [weak self] in
                self?.openAddContact()
            },
            updateBlocked: { [weak self] block in
                self?.updateBlocked(block: block)
            }
        )
        
        self._chatInterfaceInteraction = ChatControllerInteraction(openMessage: { message, mode in
            /*if let strongSelf = self, strongSelf.isNodeLoaded, let galleryMessage = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id) {
                guard let navigationController = strongSelf.navigationController as? NavigationController else {
                    return false
                }
                strongSelf.mediaCollectionDisplayNode.view.endEditing(true)
                return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, message: galleryMessage.message, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: {
                    self?.mediaCollectionDisplayNode.view.endEditing(true)
                }, present: { c, a in
                    self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                }, transitionNode: { messageId, media in
                    if let strongSelf = self {
                        return strongSelf.mediaCollectionDisplayNode.transitionNodeForGallery(messageId: messageId, media: media)
                    }
                    return nil
                }, addToTransitionSurface: { view in
                    if let strongSelf = self {
                        var belowSubview: UIView?
                        if let historyNode = strongSelf.mediaCollectionDisplayNode.historyNode as? ChatHistoryGridNode {
                            if let lowestSectionNode = historyNode.lowestSectionNode() {
                                belowSubview = lowestSectionNode.view
                            }
                        }
                        strongSelf.mediaCollectionDisplayNode.historyNode
                        if let belowSubview = belowSubview {
                        strongSelf.mediaCollectionDisplayNode.historyNode.view.insertSubview(view, belowSubview: belowSubview)
                        } else {
                            strongSelf.mediaCollectionDisplayNode.historyNode.view.addSubview(view)
                        }
                    }
                }, openUrl: { url in
                    self?.openUrl(url)
                }, openPeer: { peer, navigation in
                    self?.controllerInteraction?.openPeer(peer.id, navigation, nil)
                }, callPeer: { peerId in
                    self?.controllerInteraction?.callPeer(peerId)
                }, enqueueMessage: { _ in
                }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }))
            }*/
            return false
        }, openPeer: { id, navigation, _ in
            /*if let strongSelf = self, let id = id, let navigationController = strongSelf.navigationController as? NavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id)))
            }*/
        }, openPeerMention: { _ in
        }, openMessageContextMenu: { message, _, _, _, _ in
            /*guard let strongSelf = self else {
                return
            }
            let items = (chatAvailableMessageActionsImpl(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
            |> deliverOnMainQueue).start(next: { actions in
                var messageIds = Set<MessageId>()
                messageIds.insert(message.id)
                
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if let message = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id)?.message {
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        var items: [ActionSheetButtonItem] = []
                        
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.SharedMedia_ViewInChat, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), subject: .message(message.id)))
                            }
                        }))
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ContextMenuForward, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.forwardMessages(messageIds)
                            }
                        }))
                        if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                            items.append( ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.deleteMessages(messageIds)
                                }
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.mediaCollectionDisplayNode.view.endEditing(true)
                        strongSelf.present(actionSheet, in: .window(.root))
                    }
                }
            })*/
        }, openMessageContextActions: { message, node, rect, gesture in
            /*guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            
            let _ = (chatMediaListPreviewControllerData(context: strongSelf.context, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongSelf.navigationController as? NavigationController)
            |> deliverOnMainQueue).start(next: { previewData in
                guard let strongSelf = self else {
                    gesture?.cancel()
                    return
                }
                if let previewData = previewData {
                    let context = strongSelf.context
                    let strings = strongSelf.presentationData.strings
                    let items = chatAvailableMessageActionsImpl(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
                    |> map { actions -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = []
                        
                        items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c.dismiss(completion: {
                                if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), subject: .message(message.id)))
                                }
                            })
                        })))
                        
                        items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c.dismiss(completion: {
                                if let strongSelf = self {
                                    strongSelf.forwardMessages([message.id])
                                }
                            })
                        })))
                        
                        if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, f in
                                c.setItems(context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                                    var items: [ContextMenuItem] = []
                                    let messageIds = [message.id]
                                    
                                    if let peer = transaction.getPeer(message.id.peerId) {
                                        var personalPeerName: String?
                                        var isChannel = false
                                        if let user = peer as? TelegramUser {
                                            personalPeerName = user.compactDisplayTitle
                                        } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                            isChannel = true
                                        }
                                        
                                        if actions.options.contains(.deleteGlobally) {
                                            let globalTitle: String
                                            if isChannel {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                                            } else if let personalPeerName = personalPeerName {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                                            } else {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                            }
                                            items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                                c.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
                                                        let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
                                                    }
                                                })
                                            })))
                                        }
                                        
                                        if actions.options.contains(.deleteLocally) {
                                            var localOptionText = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                                            if strongSelf.context.account.peerId == strongSelf.peerId {
                                                if messageIds.count == 1 {
                                                    localOptionText = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                                                } else {
                                                    localOptionText = strongSelf.presentationData.strings.Conversation_DeleteManyMessages
                                                }
                                            }
                                            items.append(.action(ContextMenuActionItem(text: localOptionText, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                                c.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
                                                        let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forLocalPeer).start()
                                                    }
                                                })
                                            })))
                                        }
                                    }
                                    
                                    return items
                                })
                            })))
                        }
                        
                        return items
                    }
                    
                    switch previewData {
                    case let .gallery(gallery):
                        gallery.setHintWillBePresentedInPreviewingContext(true)
                        let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node)), items: items, reactionItems: [], gesture: gesture)
                        strongSelf.presentInGlobalOverlay(contextController)
                    case .instantPage:
                        break
                    }
                }
            })*/
        }, navigateToMessage: { fromId, id in
            /*if let strongSelf = self, strongSelf.isNodeLoaded {
                if id.peerId == strongSelf.peerId {
                    var fromIndex: MessageIndex?
                    
                    if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                        fromIndex = message.index
                    }
                } else {
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id.peerId), subject: .message(id)))
                }
            }*/
        }, tapMessage: nil, clickThroughMessage: {
            //self?.view.endEditing(true)
        }, toggleMessagesSelection: { ids, value in
            /*if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.updateInterfaceState(animated: true, { $0.withToggledSelectedMessages(ids, value: value) })
            }*/
        }, sendCurrentMessage: { _ in
        }, sendMessage: { _ in
        }, sendSticker: { _, _, _, _ in
            return false
        }, sendGif: { _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _ in
        }, requestMessageActionUrlAuth: { _, _, _ in
        }, activateSwitchInline: { _, _ in
        }, openUrl: { url, _, external, _ in
            //self?.openUrl(url, external: external ?? false)
        }, shareCurrentLocation: {
        }, shareAccountContact: {
        }, sendBotCommand: { _, _ in
        }, openInstantPage: { message, associatedData in
            /*if let strongSelf = self, strongSelf.isNodeLoaded, let navigationController = strongSelf.navigationController as? NavigationController, let message = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id)?.message {
                openChatInstantPage(context: strongSelf.context, message: message, sourcePeerType: associatedData?.automaticDownloadPeerType, navigationController: navigationController)
            }*/
        }, openWallpaper: { message in
            /*if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id)?.message {
                openChatWallpaper(context: strongSelf.context, message: message, present: { [weak self] c, a in
                    self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                })
            }*/
        }, openTheme: { _ in
        }, openHashtag: { _, _ in
        }, updateInputState: { _ in
        }, updateInputMode: { _ in
        }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, reactionContainerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in
        }, longTap: { content, _ in
            /*if let strongSelf = self {
                strongSelf.view.endEditing(true)
                switch content {
                    case let .url(url):
                        let canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                        let openText = canOpenIn ? strongSelf.presentationData.strings.Conversation_FileOpenIn : strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: url),
                            ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    if canOpenIn {
                                        let actionSheet = OpenInActionSheetController(context: strongSelf.context, item: .url(url: url), openUrl: { [weak self] url in
                                            if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                                                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                                                })
                                            }
                                        })
                                        strongSelf.present(actionSheet, in: .window(.root))
                                    } else {
                                        strongSelf.context.sharedContext.applicationBindings.openUrl(url)
                                    }
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = url
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let link = URL(string: url) {
                                    let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                }
                            })
                        ]), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.present(actionSheet, in: .window(.root))
                    default:
                        break
                }
            }*/
        }, openCheckoutOrReceipt: { _ in
        }, openSearch: {
            //self?.activateSearch()
        }, setupReply: { _ in
        }, canSetupReply: { _ in
            return false
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: {
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _ in
        }, updateMessageReaction: { _, _ in
        }, openMessageReactions: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false))
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.infoSection)
        self.scrollNode.addSubnode(self.editingInfoSection)
        self.scrollNode.addSubnode(self.editingActionsSection)
        self.scrollNode.addSubnode(self.paneContainerNode)
        self.addSubnode(self.headerNode)
        
        self.paneContainerNode.openMessage = { [weak self] id in
            return self?.openMessage(id: id) ?? false
        }
        
        self.paneContainerNode.toggleMessageSelected = { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            if var selectedMessageIds = strongSelf.state.selectedMessageIds {
                if selectedMessageIds.contains(id) {
                    selectedMessageIds.remove(id)
                } else {
                    selectedMessageIds.insert(id)
                }
                strongSelf.state = strongSelf.state.withSelectedMessageIds(selectedMessageIds)
                strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
                }
            }
        }
        
        self.paneContainerNode.openPeer = { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer.id), keepStack: .always))
            }
        }
        
        self.paneContainerNode.currentPaneUpdated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                strongSelf.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: strongSelf.paneContainerNode.frame.minY - navigationHeight), animated: true)
            }
        }
        
        self.headerNode.performButtonAction = { [weak self] key in
            self?.performButtonAction(key: key)
        }
        
        self.headerNode.requestAvatarExpansion = { [weak self] in
            guard let strongSelf = self, let peer = strongSelf.data?.peer, peer.smallProfileImage != nil else {
                return
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
            
            strongSelf.headerNode.updateIsAvatarExpanded(true)
            strongSelf.updateNavigationExpansionPresentation(isExpanded: true, animated: true)
            
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
            }
        }
        
        self.headerNode.navigationButtonContainer.performAction = { [weak self] key in
            guard let strongSelf = self else {
                return
            }
            switch key {
            case .edit:
                strongSelf.state = strongSelf.state.withIsEditing(true)
                if strongSelf.headerNode.isAvatarExpanded {
                    strongSelf.headerNode.updateIsAvatarExpanded(false)
                    strongSelf.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
                }
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.scrollNode.view.setContentOffset(CGPoint(), animated: false)
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                UIView.transition(with: strongSelf.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                }, completion: nil)
                strongSelf.controller?.navigationItem.setLeftBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, style: .plain, target: strongSelf, action: #selector(strongSelf.editingCancelPressed)), animated: true)
            case .done, .cancel:
                if case .done = key {
                    if let data = strongSelf.data, data.isContact {
                        if let peer = data.peer as? TelegramUser {
                            let firstName = strongSelf.headerNode.editingContentNode.editingTextForKey(.firstName) ?? ""
                            let lastName = strongSelf.headerNode.editingContentNode.editingTextForKey(.lastName) ?? ""
                            
                            if peer.firstName != firstName || peer.lastName != lastName {
                                strongSelf.activeActionDisposable.set((updateContactName(account: context.account, peerId: peer.id, firstName: firstName, lastName: lastName)
                                |> deliverOnMainQueue).start(error: { _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                }, completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let context = strongSelf.context
                                    let _ = (getUserPeer(postbox: strongSelf.context.account.postbox, peerId: peer.id)
                                    |> mapToSignal { peer, _ -> Signal<Void, NoError> in
                                        guard let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty else {
                                            return .complete()
                                        }
                                        return (context.sharedContext.contactDataManager?.basicDataForNormalizedPhoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone))) ?? .single([]))
                                        |> take(1)
                                        |> mapToSignal { records -> Signal<Void, NoError> in
                                            var signals: [Signal<DeviceContactExtendedData?, NoError>] = []
                                            if let contactDataManager = context.sharedContext.contactDataManager {
                                                for (id, basicData) in records {
                                                    signals.append(contactDataManager.appendContactData(DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: basicData.phoneNumbers), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: ""), to: id))
                                                }
                                            }
                                            return combineLatest(signals)
                                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                                return .complete()
                                            }
                                        }
                                    }).start()
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                }))
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                            }
                        }
                    } else {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                    }
                } else {
                    strongSelf.state = strongSelf.state.withIsEditing(false)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.scrollNode.view.setContentOffset(CGPoint(), animated: false)
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    UIView.transition(with: strongSelf.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                    strongSelf.controller?.navigationItem.setLeftBarButton(nil, animated: true)
                }
            case .select:
                strongSelf.state = strongSelf.state.withSelectedMessageIds(Set())
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
                }
                strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
            case .selectionDone:
                strongSelf.state = strongSelf.state.withSelectedMessageIds(nil)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
                }
                strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
            case .search:
                strongSelf.activateSearch()
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
        self.activeActionDisposable.dispose()
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
    
    @objc private func editingCancelPressed() {
        self.headerNode.navigationButtonContainer.performAction?(.cancel)
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
            var items: [ActionSheetItem] = []
            if self.headerNode.isAvatarExpanded {
                items.append(ActionSheetButtonItem(title: "Message", color: .accent, action: { [weak self] in
                    dismissAction()
                    self?.performButtonAction(key: .message)
                }))
                items.append(ActionSheetButtonItem(title: "Call", color: .accent, action: { [weak self] in
                    dismissAction()
                    self?.performButtonAction(key: .call)
                }))
                items.append(ActionSheetButtonItem(title: "Mute", color: .accent, action: { [weak self] in
                    dismissAction()
                    self?.performButtonAction(key: .mute)
                }))
            }
            items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_StartSecretChat, color: .accent, action: { [weak self] in
                dismissAction()
                self?.openStartSecretChat()
            }))
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
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
    
    private func editingOpenNotificationSettings() {
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
            let muteSettingsController = notificationMuteSettingsController(presentationData: strongSelf.presentationData, notificationSettings: globalSettings.effective.groupChats, soundSettings: nil, openSoundSettings: {
                guard let strongSelf = self else {
                    return
                }
                let soundController = notificationSoundSelectionController(context: strongSelf.context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = updatePeerNotificationSoundInteractive(account: strongSelf.context.account, peerId: strongSelf.peerId, sound: sound).start()
                })
                strongSelf.controller?.push(soundController)
            }, updateSettings: { value in
                guard let strongSelf = self else {
                    return
                }
                let _ = updatePeerMuteSetting(account: strongSelf.context.account, peerId: strongSelf.peerId, muteInterval: value).start()
            })
            strongSelf.controller?.present(muteSettingsController, in: .window(.root))
        })
    }
    
    private func editingOpenSoundSettings() {
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
            
            let soundController = notificationSoundSelectionController(context: strongSelf.context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                guard let strongSelf = self else {
                    return
                }
                let _ = updatePeerNotificationSoundInteractive(account: strongSelf.context.account, peerId: strongSelf.peerId, sound: sound).start()
            })
            strongSelf.controller?.push(soundController)
        })
    }
    
    private func editingToggleShowMessageText(value: Bool) {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            let _ = updatePeerDisplayPreviewsSetting(account: strongSelf.context.account, peerId: peer.id, displayPreviews: value ? .show : .hide).start()
        })
    }
    
    private func requestDeleteContact() {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak actionSheet] in
            actionSheet?.dismissAnimated()
        }
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.UserInfo_DeleteContact, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (getUserPeer(postbox: strongSelf.context.account.postbox, peerId: strongSelf.peerId)
                    |> deliverOnMainQueue).start(next: { peer, _ in
                        guard let peer = peer, let strongSelf = self else {
                            return
                        }
                        let deleteContactFromDevice: Signal<Never, NoError>
                        if let contactDataManager = strongSelf.context.sharedContext.contactDataManager {
                            deleteContactFromDevice = contactDataManager.deleteContactWithAppSpecificReference(peerId: peer.id)
                        } else {
                            deleteContactFromDevice = .complete()
                        }
                        
                        var deleteSignal = deleteContactPeerInteractively(account: strongSelf.context.account, peerId: peer.id)
                        |> then(deleteContactFromDevice)
                        
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            guard let strongSelf = self else {
                                return EmptyDisposable
                            }
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                            strongSelf.controller?.present(statusController, in: .window(.root))
                            return ActionDisposable { [weak statusController] in
                                Queue.mainQueue().async() {
                                    statusController?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        deleteSignal = deleteSignal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        
                        strongSelf.activeActionDisposable.set((deleteSignal
                        |> deliverOnMainQueue).start(completed: {
                            self?.controller?.dismiss()
                        }))
                        
                        deleteSendMessageIntents(peerId: strongSelf.peerId)
                    })
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.controller?.present(actionSheet, in: .window(.root))
    }
    
    private func openAddContact() {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            openAddPersonContactImpl(context: strongSelf.context, peerId: peer.id, pushController: { c in
                self?.controller?.push(c)
            }, present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            })
        })
    }
    
    private func updateBlocked(block: Bool) {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            let presentationData = strongSelf.presentationData
            if let peer = peer as? TelegramUser, let _ = peer.botInfo {
                strongSelf.activeActionDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: block).start())
                if !block {
                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
                    if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer.id)))
                    }
                }
            } else {
                if block {
                    let presentationData = strongSelf.presentationData
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    let dismissAction: () -> Void = { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    }
                    var reportSpam = false
                    var deleteChat = false
                    actionSheet.setItemGroups([
                        ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(peer.compactDisplayTitle).0),
                            ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(peer.compactDisplayTitle).0, color: .destructive, action: {
                                dismissAction()
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.activeActionDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: true).start())
                                if deleteChat {
                                    let _ = removePeerChat(account: strongSelf.context.account, peerId: strongSelf.peerId, reportChatSpam: reportSpam).start()
                                    (strongSelf.controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
                                } else if reportSpam {
                                    let _ = reportPeer(account: strongSelf.context.account, peerId: strongSelf.peerId, reason: .spam).start()
                                }
                                
                                deleteSendMessageIntents(peerId: strongSelf.peerId)
                            })
                        ]),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    strongSelf.controller?.present(actionSheet, in: .window(.root))
                } else {
                    let text: String
                    if block {
                        text = presentationData.strings.UserInfo_BlockConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).0
                    } else {
                        text = presentationData.strings.UserInfo_UnblockConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).0
                    }
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Yes, action: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.activeActionDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: block).start())
                    })]), in: .window(.root))
                }
            }
        })
    }
    
    func deleteMessages() {
        if let messageIds = self.state.selectedMessageIds, !messageIds.isEmpty {
            self.activeActionDisposable.set((self.context.sharedContext.chatAvailableMessageActions(postbox: self.context.account.postbox, accountPeerId: self.context.account.peerId, messageIds: messageIds)
            |> deliverOnMainQueue).start(next: { [weak self] actions in
                if let strongSelf = self, let peer = strongSelf.data?.peer, !actions.options.isEmpty {
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    var personalPeerName: String?
                    var isChannel = false
                    if let user = peer as? TelegramUser {
                        personalPeerName = user.compactDisplayTitle
                    } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    if actions.options.contains(.deleteGlobally) {
                        let globalTitle: String
                        if isChannel {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        } else if let personalPeerName = personalPeerName {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                        } else {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                        }
                        items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
                            }
                        }))
                    }
                    if actions.options.contains(.deleteLocally) {
                        var localOptionText = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        if strongSelf.context.account.peerId == strongSelf.peerId {
                            if messageIds.count == 1 {
                                localOptionText = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                            } else {
                                localOptionText = strongSelf.presentationData.strings.Conversation_DeleteManyMessages
                            }
                        }
                        items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forLocalPeer).start()
                            }
                        }))
                    }
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.controller?.present(actionSheet, in: .window(.root))
                }
            }))
        }
    }
    
    func forwardMessages() {
        if let messageIds = self.state.selectedMessageIds, !messageIds.isEmpty {
            let peerSelectionController = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: [.onlyWriteable, .excludeDisabled]))
            peerSelectionController.peerSelected = { [weak self, weak peerSelectionController] peerId in
                if let strongSelf = self, let _ = peerSelectionController {
                    if peerId == strongSelf.context.account.peerId {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                        
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                            return .forward(source: id, grouping: .auto, attributes: [])
                        })
                        |> deliverOnMainQueue).start(next: { [weak self] messageIds in
                            if let strongSelf = self {
                                let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                    guard let id = id else {
                                        return nil
                                    }
                                    return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                        |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                            if status != nil {
                                                return .never()
                                            } else {
                                                return .single(true)
                                            }
                                        }
                                        |> take(1)
                                })
                                strongSelf.activeActionDisposable.set((combineLatest(signals)
                                |> deliverOnMainQueue).start(completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.controller?.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .success), in: .window(.root))
                                }))
                            }
                        })
                        if let peerSelectionController = peerSelectionController {
                            peerSelectionController.dismiss()
                        }
                    } else {
                        let _ = (strongSelf.context.account.postbox.transaction({ transaction -> Void in
                            transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                                if let currentState = currentState as? ChatInterfaceState {
                                    return currentState.withUpdatedForwardMessageIds(Array(messageIds))
                                } else {
                                    return ChatInterfaceState().withUpdatedForwardMessageIds(Array(messageIds))
                                }
                            })
                        }) |> deliverOnMainQueue).start(completed: {
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                
                                let ready = ValuePromise<Bool>()
                                strongSelf.activeActionDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                    if let peerSelectionController = peerSelectionController {
                                        peerSelectionController.dismiss()
                                    }
                                }))
                                
                                (strongSelf.controller?.navigationController as? NavigationController)?.replaceTopController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(peerId)), animated: false, ready: ready)
                            }
                        })
                    }
                }
            }
            self.controller?.push(peerSelectionController)
        }
    }
    
    private func activateSearch() {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        
        var maybePlaceholderNode: SearchBarPlaceholderNode?
        /*if let listNode = historyNode as? ListView {
            listNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
        }*/
        
        if let _ = self.searchDisplayController {
            return
        }
        
        var tagMask: MessageTags = .file
        if let currentPaneKey = self.paneContainerNode.currentPaneKey {
            switch currentPaneKey {
            case .links:
                tagMask = .webPage
            case .music:
                tagMask = .music
            default:
                break
            }
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.peerId, tagMask: tagMask, interfaceInteraction: self.chatInterfaceInteraction), cancel: { [weak self] in
            self?.deactivateSearch()
        })
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 0.0)
        }
        
        self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            if let strongSelf = self, let navigationBar = strongSelf.controller?.navigationBar {
                strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
            }
        }, placeholder: nil)
        
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
        }
    }
    
    private func deactivateSearch() {
        guard let searchDisplayController = self.searchDisplayController else {
            return
        }
        self.searchDisplayController = nil
        searchDisplayController.deactivate(placeholder: nil)
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 1.0)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition, additive: Bool = false) {
        self.validLayout = (layout, navigationHeight)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: transition)
            if !searchDisplayController.isDeactivating {
                //vanillaInsets.top += (layout.statusBarHeight ?? 0.0) - navigationBarHeightDelta
            }
        }
        
        self.ignoreScrolling = true
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sectionSpacing: CGFloat = 24.0
        
        var contentHeight: CGFloat = 0.0
        
        let headerHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: layout.safeInsets.left, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, contentOffset: self.scrollNode.view.contentOffset.y, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, presence: self.data?.presence, isContact: self.data?.isContact ?? false, state: self.state, transition: transition, additive: additive)
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
        
        let editingInfoSectionHeight = self.editingInfoSection.update(width: layout.size.width, presentationData: self.presentationData, items: editingInfoSectionItems(data: self.data, presentationData: self.presentationData, interaction: self.interaction), transition: transition)
        let editingInfoSectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: infoSectionHeight))
        if additive {
            transition.updateFrameAdditive(node: self.editingInfoSection, frame: editingInfoSectionFrame)
        } else {
            transition.updateFrame(node: self.editingInfoSection, frame: editingInfoSectionFrame)
        }
        
        if self.state.isEditing {
            transition.updateAlpha(node: self.infoSection, alpha: 0.0)
            transition.updateAlpha(node: self.editingInfoSection, alpha: 1.0)
            transition.updateAlpha(node: self.editingActionsSection, alpha: 1.0)
            if !editingInfoSectionHeight.isZero {
                contentHeight += editingInfoSectionHeight
                contentHeight += sectionSpacing
            }
        } else {
            transition.updateAlpha(node: self.infoSection, alpha: 1.0)
            transition.updateAlpha(node: self.editingInfoSection, alpha: 0.0)
            transition.updateAlpha(node: self.editingActionsSection, alpha: 0.0)
            if !infoSectionHeight.isZero {
                contentHeight += infoSectionHeight
                contentHeight += sectionSpacing
            }
        }
        
        let editingActionsSectionHeight = self.editingActionsSection.update(width: layout.size.width, presentationData: self.presentationData, items: editingActionsSectionItems(data: self.data, presentationData: self.presentationData, interaction: self.interaction), transition: transition)
        let editingActionsSectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: editingActionsSectionHeight))
        if additive {
            transition.updateFrameAdditive(node: self.editingActionsSection, frame: editingActionsSectionFrame)
        } else {
            transition.updateFrame(node: self.editingActionsSection, frame: editingActionsSectionFrame)
        }
        
        if self.state.isEditing {
            if !editingActionsSectionHeight.isZero {
                contentHeight += editingActionsSectionHeight
                contentHeight += sectionSpacing
            }
        }
        
        let paneContainerSize = CGSize(width: layout.size.width, height: layout.size.height - navigationHeight)
        var restoreContentOffset: CGPoint?
        if additive {
            restoreContentOffset = self.scrollNode.view.contentOffset
        }
        
        let paneContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: paneContainerSize)
        if self.state.isEditing || (self.data?.availablePanes ?? []).isEmpty {
            transition.updateAlpha(node: self.paneContainerNode, alpha: 0.0)
        } else {
            contentHeight += layout.size.height - navigationHeight
            transition.updateAlpha(node: self.paneContainerNode, alpha: 1.0)
        }
        
        if let selectedMessageIds = self.state.selectedMessageIds {
            var wasAdded = false
            let selectionPanelNode: PeerInfoSelectionPanelNode
            if let current = self.paneContainerNode.selectionPanelNode {
                selectionPanelNode = current
            } else {
                wasAdded = true
                selectionPanelNode = PeerInfoSelectionPanelNode(context: self.context, peerId: self.peerId, deleteMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.deleteMessages()
                }, shareMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                        var messages: [Message] = []
                        for id in messageIds {
                            if let message = transaction.getMessage(id) {
                                messages.append(message)
                            }
                        }
                        return messages
                    }
                    |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                            
                            let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            })), externalShare: true, immediateExternalShare: true)
                            strongSelf.controller?.present(shareController, in: .window(.root))
                        }
                    })
                }, forwardMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.forwardMessages()
                }, reportMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    strongSelf.controller?.present(peerReportOptionsController(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), present: { c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    }, push: { c in
                        self?.controller?.push(c)
                    }, completion: { _ in }), in: .window(.root))
                })
                self.paneContainerNode.selectionPanelNode = selectionPanelNode
                self.paneContainerNode.addSubnode(selectionPanelNode)
            }
            selectionPanelNode.selectionPanel.selectedMessages = selectedMessageIds
            let panelHeight = selectionPanelNode.update(width: layout.size.width, safeInset: layout.safeInsets.left, metrics: layout.metrics, presentationData: self.presentationData, transition: wasAdded ? .immediate : transition)
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: paneContainerSize.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            if wasAdded {
                selectionPanelNode.frame = panelFrame
                transition.animatePositionAdditive(node: selectionPanelNode, offset: CGPoint(x: 0.0, y: panelHeight))
            } else {
                transition.updateFrame(node: selectionPanelNode, frame: panelFrame)
            }
        } else if let selectionPanelNode = self.paneContainerNode.selectionPanelNode {
            self.paneContainerNode.selectionPanelNode = nil
            transition.updateFrame(node: selectionPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: selectionPanelNode.bounds.size), completion: { [weak selectionPanelNode] _ in
                selectionPanelNode?.removeFromSupernode()
            })
        }
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        if let restoreContentOffset = restoreContentOffset {
            self.scrollNode.view.contentOffset = restoreContentOffset
        }
        
        if additive {
            transition.updateFrameAdditive(node: self.paneContainerNode, frame: paneContainerFrame)
        } else {
            transition.updateFrame(node: self.paneContainerNode, frame: paneContainerFrame)
        }
        
        self.ignoreScrolling = false
        self.updateNavigation(transition: transition, additive: additive)
        
        if !self.didSetReady && self.data != nil {
            self.didSetReady = true
            let avatarReady = self.headerNode.avatarListNode.isReady.get()
            let combinedSignal = combineLatest(queue: .mainQueue(),
                avatarReady,
                self.paneContainerNode.isReady.get()
            )
            |> map { lhs, rhs in
                return lhs && rhs
            }
            self._ready.set(combinedSignal
            |> filter { $0 }
            |> take(1))
        }
    }
    
    private func updateNavigation(transition: ContainedViewLayoutTransition, additive: Bool) {
        let offsetY = self.scrollNode.view.contentOffset.y
        
        if self.state.isEditing || offsetY <= 50.0 {
            self.scrollNode.view.bounces = true
            self.scrollNode.view.alwaysBounceVertical = true
        } else {
            self.scrollNode.view.bounces = false
            self.scrollNode.view.alwaysBounceVertical = false
        }
        
        if let (layout, navigationHeight) = self.validLayout {
            if !additive {
                self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: layout.safeInsets.left, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, contentOffset: offsetY, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, presence: self.data?.presence, isContact: self.data?.isContact ?? false, state: self.state, transition: transition, additive: additive)
            }
            
            let paneAreaExpansionDistance: CGFloat = 32.0
            var paneAreaExpansionDelta = (self.paneContainerNode.frame.minY - navigationHeight) - self.scrollNode.view.contentOffset.y
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            
            let paneAreaExpansionFraction: CGFloat = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            
            let effectiveAreaExpansionFraction: CGFloat
            if self.state.isEditing {
                effectiveAreaExpansionFraction = 0.0
            } else {
                effectiveAreaExpansionFraction = paneAreaExpansionFraction
            }
            
            transition.updateAlpha(node: self.headerNode.separatorNode, alpha: 1.0 - effectiveAreaExpansionFraction)
            
            let visibleHeight = self.scrollNode.view.contentOffset.y + self.scrollNode.view.bounds.height - self.paneContainerNode.frame.minY
            
            self.paneContainerNode.update(size: self.paneContainerNode.bounds.size, visibleHeight: visibleHeight, expansionFraction: paneAreaExpansionFraction, presentationData: self.presentationData, data: self.data, transition: transition)
            self.headerNode.navigationButtonContainer.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: layout.statusBarHeight ?? 0.0), size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: 44.0))
            self.headerNode.navigationButtonContainer.isWhite = self.headerNode.isAvatarExpanded
            
            var navigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            if self.state.isEditing {
                navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .done, isForExpandedView: false))
            } else {
                navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                if self.state.selectedMessageIds == nil {
                    if let currentPaneKey = self.paneContainerNode.currentPaneKey {
                        switch currentPaneKey {
                        case .files, .music, .links:
                            navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                        default:
                            break
                        }
                    }
                    navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .select, isForExpandedView: true))
                } else {
                    navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .selectionDone, isForExpandedView: true))
                }
            }
            self.headerNode.navigationButtonContainer.update(size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: 44.0), presentationData: self.presentationData, buttons: navigationButtons, expandFraction: effectiveAreaExpansionFraction, transition: transition)
        }
    }
    
    private var canUpdateAvatarExpansion = false
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.canUpdateAvatarExpansion = true
    }
    
    private var previousVelocityM1: CGFloat = 0.0
    private var previousVelocity: CGFloat = 0.0
    
    private let velocityKey: String = encodeText("`wfsujdbmWfmpdjuz", -1)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling {
            return
        }
        self.updateNavigation(transition: .immediate, additive: false)
        
        if !self.state.isEditing {
            self.previousVelocityM1 = self.previousVelocity
            if let value = (scrollView.value(forKey: self.velocityKey) as? NSNumber)?.doubleValue {
                //print("previousVelocity \(CGFloat(value))")
                self.previousVelocity = CGFloat(value)
            }
            
            let offsetY = self.scrollNode.view.contentOffset.y
            var shouldBeExpanded: Bool?
            if offsetY <= -32.0 && scrollView.isDragging && scrollView.isTracking {
                if let peer = self.data?.peer, peer.smallProfileImage != nil {
                    shouldBeExpanded = true
                }
            } else if offsetY >= 1.0 {
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
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        
        let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
        if abs(scrollView.contentOffset.y - paneAreaExpansionFinalPoint) < .ulpOfOne {
            self.paneContainerNode.currentPane?.node.transferVelocity(self.previousVelocityM1)
        }
    }
    
    private func updateNavigationExpansionPresentation(isExpanded: Bool, animated: Bool) {
        if let controller = self.controller {
            controller.statusBar.updateStatusBarStyle(isExpanded ? .White : self.presentationData.theme.rootController.statusBarStyle.style, animated: animated)
            
            if animated {
                UIView.transition(with: controller.controllerNode.headerNode.navigationButtonContainer.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                }, completion: nil)
            }
            
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
        if !self.state.isEditing {
            if targetContentOffset.pointee.y < 212.0 {
                if targetContentOffset.pointee.y < 212.0 / 2.0 {
                    targetContentOffset.pointee.y = 0.0
                } else {
                    targetContentOffset.pointee.y = 212.0
                }
            }
            let paneAreaExpansionDistance: CGFloat = 32.0
            let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
            if targetContentOffset.pointee.y > paneAreaExpansionFinalPoint - paneAreaExpansionDistance && targetContentOffset.pointee.y < paneAreaExpansionFinalPoint {
                targetContentOffset.pointee.y = paneAreaExpansionFinalPoint
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
    
    fileprivate var controllerNode: PeerInfoScreenNode {
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
            if strongSelf.navigationItem.leftBarButtonItem != nil {
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
    private var reverseFraction: Bool = false
    
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
        if let _ = bottomNavigationBar.userInfo as? PeerInfoNavigationSourceTag {
            self.topNavigationBar = topNavigationBar
            self.bottomNavigationBar = bottomNavigationBar
        } else {
            self.topNavigationBar = bottomNavigationBar
            self.bottomNavigationBar = topNavigationBar
            self.reverseFraction = true
        }
        
        topNavigationBar.isHidden = true
        bottomNavigationBar.isHidden = true
        
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar {
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
    }
    
    func update(containerSize: CGSize, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }
        
        let fraction = self.reverseFraction ? (1.0 - fraction) : fraction
        
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
                self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: layout.safeInsets.left, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: topNavigationBar.bounds.height, contentOffset: 0.0, presentationData: self.presentationData, peer: self.screenNode.data?.peer, cachedData: self.screenNode.data?.cachedData, notificationSettings: self.screenNode.data?.notificationSettings, presence: self.screenNode.data?.presence, isContact: self.screenNode.data?.isContact ?? false, state: self.screenNode.state, transition: transition, additive: false)
            }
            
            let titleScale = (fraction * previousTitleNode.bounds.height + (1.0 - fraction) * self.headerNode.titleNode.bounds.height) / previousTitleNode.bounds.height
            let subtitleScale = max(0.01, min(10.0, (fraction * previousStatusNode.bounds.height + (1.0 - fraction) * self.headerNode.subtitleNode.bounds.height) / previousStatusNode.bounds.height))
            
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
            
            transition.updateAlpha(node: self.headerNode.navigationButtonContainer, alpha: (1.0 - fraction))
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

private func encodeText(_ string: String, _ key: Int) -> String {
    var result = ""
    for c in string.unicodeScalars {
        result.append(Character(UnicodeScalar(UInt32(Int(c.value) + key))!))
    }
    return result
}
