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
import ActivityIndicator

enum PeerInfoHeaderButtonKey: Hashable {
    case message
    case discussion
    case call
    case mute
    case more
    case addMember
    case search
    case leave
}

enum PeerInfoHeaderButtonIcon {
    case message
    case call
    case mute
    case unmute
    case more
    case addMember
    case search
    case leave
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
                case .search:
                    imageName = "Peer Info/ButtonSearch"
                case .leave:
                    imageName = "Peer Info/ButtonLeave"
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
    private let context: AccountContext
    let imageNode: TransformImageNode
    
    let isReady = Promise<Bool>()
    private var didSetReady: Bool = false
    
    init(context: AccountContext) {
        self.context = context
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
        self.addSubnode(self.imageNode)
        
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
    
    func setup(item: PeerInfoAvatarListItem, synchronous: Bool) {
        let representations: [ImageRepresentationWithReference]
        switch item {
        case let .topImage(topRepresentations):
            representations = topRepresentations
        case let .image(_, imageRepresentations):
            representations = imageRepresentations
        }
        self.imageNode.setSignal(chatAvatarGalleryPhoto(account: self.context.account, representations: representations, autoFetchFullSize: true, attemptSynchronously: synchronous), attemptSynchronously: synchronous, dispatchOnDisplayLink: false)
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
    let controlsClippingNode: ASDisplayNode
    let controlsClippingOffsetNode: ASDisplayNode
    let shadowNode: ASImageNode
    
    let contentNode: ASDisplayNode
    let leftHighlightNode: ASImageNode
    let rightHighlightNode: ASImageNode
    var highlightedSide: Bool?
    let stripContainerNode: ASDisplayNode
    let highlightContainerNode: ASDisplayNode
    private(set) var galleryEntries: [AvatarGalleryEntry] = []
    private var items: [PeerInfoAvatarListItem] = []
    private var itemNodes: [WrappedMediaResourceId: PeerInfoAvatarListItemNode] = [:]
    private var stripNodes: [ASImageNode] = []
    private let activeStripImage: UIImage
    private var appliedStripNodeCurrentIndex: Int?
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
    
    var currentEntry: AvatarGalleryEntry? {
        if self.currentIndex >= 0 && self.currentIndex < self.galleryEntries.count {
            return self.galleryEntries[self.currentIndex]
        } else {
            return nil
        }
    }
    
    init(context: AccountContext) {
        self.context = context
        
        self.contentNode = ASDisplayNode()
        
        self.leftHighlightNode = ASImageNode()
        self.leftHighlightNode.displaysAsynchronously = false
        self.leftHighlightNode.displayWithoutProcessing = true
        self.leftHighlightNode.contentMode = .scaleToFill
        self.leftHighlightNode.image = generateImage(CGSize(width: 88.0, height: 1.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let topColor = UIColor(rgb: 0x000000, alpha: 0.1)
            let bottomColor = UIColor(rgb: 0x000000, alpha: 0.0)
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colors: [CGColor] = [topColor.cgColor, bottomColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        })
        self.leftHighlightNode.alpha = 0.0
        
        self.rightHighlightNode = ASImageNode()
        self.rightHighlightNode.displaysAsynchronously = false
        self.rightHighlightNode.displayWithoutProcessing = true
        self.rightHighlightNode.contentMode = .scaleToFill
        self.rightHighlightNode.image = generateImage(CGSize(width: 88.0, height: 1.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let topColor = UIColor(rgb: 0x000000, alpha: 0.1)
            let bottomColor = UIColor(rgb: 0x000000, alpha: 0.0)
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colors: [CGColor] = [topColor.cgColor, bottomColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0.0), end: CGPoint(x: 0.0, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        })
        self.rightHighlightNode.alpha = 0.0
        
        self.stripContainerNode = ASDisplayNode()
        self.contentNode.addSubnode(self.stripContainerNode)
        self.activeStripImage = generateSmallHorizontalStretchableFilledCircleImage(diameter: 2.0, color: .white)!
        
        self.highlightContainerNode = ASDisplayNode()
        self.highlightContainerNode.addSubnode(self.leftHighlightNode)
        self.highlightContainerNode.addSubnode(self.rightHighlightNode)
        
        self.controlsContainerNode = ASDisplayNode()
        self.controlsContainerNode.isUserInteractionEnabled = false
        
        self.controlsClippingOffsetNode = ASDisplayNode()
        
        self.controlsClippingNode = ASDisplayNode()
        self.controlsClippingNode.isUserInteractionEnabled = false
        self.controlsClippingNode.clipsToBounds = true
        
        self.shadowNode = ASImageNode()
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.displayWithoutProcessing = true
        self.shadowNode.contentMode = .scaleToFill
        
        do {
            let size = CGSize(width: 88.0, height: 88.0)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            if let context = UIGraphicsGetCurrentContext() {
                context.clip(to: CGRect(origin: CGPoint(), size: size))
                
                let topColor = UIColor(rgb: 0x000000, alpha: 0.4)
                let bottomColor = UIColor(rgb: 0x000000, alpha: 0.0)
                
                var locations: [CGFloat] = [0.0, 1.0]
                let colors: [CGColor] = [topColor.cgColor, bottomColor.cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let image = image {
                    self.shadowNode.image = generateImage(image.size, contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.rotate(by: -CGFloat.pi / 2.0)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    })
                }
            }
        }
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.contentNode)
        
        self.controlsContainerNode.addSubnode(self.highlightContainerNode)
        self.controlsContainerNode.addSubnode(self.shadowNode)
        self.controlsContainerNode.addSubnode(self.stripContainerNode)
        self.controlsClippingNode.addSubnode(self.controlsContainerNode)
        self.controlsClippingOffsetNode.addSubnode(self.controlsClippingNode)
        
        self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.currentIndex != 0
        }
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .keepWithSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            var highlightedSide: Bool?
            if let point = point {
                if point.x < size.width * 1.0 / 5.0 {
                    if strongSelf.items.count > 1 {
                        highlightedSide = false
                    }
                } else {
                    if strongSelf.items.count > 1 {
                        highlightedSide = true
                    }
                }
            }
            if strongSelf.highlightedSide != highlightedSide {
                strongSelf.highlightedSide = highlightedSide
                let leftAlpha: CGFloat
                let rightAlpha: CGFloat
                if let highlightedSide = highlightedSide {
                    leftAlpha = highlightedSide ? 0.0 : 1.0
                    rightAlpha = highlightedSide ? 1.0 : 0.0
                } else {
                    leftAlpha = 0.0
                    rightAlpha = 0.0
                }
                if strongSelf.leftHighlightNode.alpha != leftAlpha {
                    strongSelf.leftHighlightNode.alpha = leftAlpha
                    if leftAlpha.isZero {
                        strongSelf.leftHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        strongSelf.leftHighlightNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)
                    }
                }
                if strongSelf.rightHighlightNode.alpha != rightAlpha {
                    strongSelf.rightHighlightNode.alpha = rightAlpha
                    if rightAlpha.isZero {
                        strongSelf.rightHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        strongSelf.rightHighlightNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)
                    }
                }
            }
        }
        self.view.addGestureRecognizer(recognizer)
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
            self.updateItems(size: size, transition: .immediate, stripTransition: .immediate)
        }
    }
    
    func updateEntryIsHidden(entry: AvatarGalleryEntry?) {
        if let entry = entry, let index = self.galleryEntries.index(of: entry) {
            self.currentItemNode?.isHidden = index == self.currentIndex
        } else {
            self.currentItemNode?.isHidden = false
        }
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if let size = self.validLayout, case .tap = gesture {
                    if location.x < size.width * 1.0 / 5.0 {
                        if self.currentIndex != 0 {
                            self.currentIndex -= 1
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring))
                        } else if self.items.count > 1 {
                            self.currentIndex = self.items.count - 1
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
                        }
                    } else {
                        if self.currentIndex < self.items.count - 1 {
                            self.currentIndex += 1
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring))
                        } else if self.items.count > 1 {
                            self.currentIndex = 0
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
                        }
                    }
                }
            }
        default:
            break
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
                self.updateItems(size: size, transition: .animated(duration: 0.3, curve: .spring), stripTransition: .animated(duration: 0.3, curve: .spring))
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
                self.updateItems(size: size, transition: .animated(duration: 0.3, curve: .spring), stripTransition: .animated(duration: 0.3, curve: .spring))
            }
        default:
            break
        }
    }
    
    func update(size: CGSize, peer: Peer?, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        self.leftHighlightNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: floor(size.width * 1.0 / 5.0), height: size.height))
        self.rightHighlightNode.frame = CGRect(origin: CGPoint(x: size.width - floor(size.width * 1.0 / 5.0), y: 0.0), size: CGSize(width: floor(size.width * 1.0 / 5.0), height: size.height))
        
        if let peer = peer, !self.initializedList {
            self.initializedList = true
            self.disposable.set((peerInfoProfilePhotosWithCache(context: self.context, peerId: peer.id)
            |> deliverOnMainQueue).start(next: { [weak self] entries in
                guard let strongSelf = self else {
                    return
                }
                var items: [PeerInfoAvatarListItem] = []
                for entry in entries {
                    switch entry {
                    case let .topImage(representations, _):
                        items.append(.topImage(representations))
                    case let .image(_, reference, representations, _, _, _, _):
                        items.append(.image(reference, representations))
                    }
                }
                strongSelf.galleryEntries = entries
                strongSelf.items = items
                if let size = strongSelf.validLayout {
                    strongSelf.updateItems(size: size, transition: .immediate, stripTransition: .immediate)
                }
                if items.isEmpty {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf.isReady.set(.single(true))
                    }
                }
            }))
        }
        self.updateItems(size: size, transition: transition, stripTransition: transition)
    }
    
    private func updateItems(size: CGSize, transition: ContainedViewLayoutTransition, stripTransition: ContainedViewLayoutTransition, synchronous: Bool = false) {
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
                    itemNode = PeerInfoAvatarListItemNode(context: self.context)
                    itemNode.setup(item: self.items[i], synchronous: synchronous && i == self.currentIndex)
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
        
        let hadOneStripNode = self.stripNodes.count == 1
        if self.stripNodes.count != self.items.count {
            if self.stripNodes.count < self.items.count {
                for _ in 0 ..< self.items.count - self.stripNodes.count {
                    let stripNode = ASImageNode()
                    stripNode.displaysAsynchronously = false
                    stripNode.displayWithoutProcessing = true
                    stripNode.image = self.activeStripImage
                    if stripNodes.count != self.currentIndex {
                        stripNode.alpha = 0.2
                    }
                    self.stripNodes.append(stripNode)
                    self.stripContainerNode.addSubnode(stripNode)
                }
            } else {
                for i in (self.items.count ..< self.stripNodes.count).reversed() {
                    self.stripNodes[i].removeFromSupernode()
                    self.stripNodes.remove(at: i)
                }
            }
        }
        if self.appliedStripNodeCurrentIndex != self.currentIndex {
            if let appliedStripNodeCurrentIndex = self.appliedStripNodeCurrentIndex {
                if appliedStripNodeCurrentIndex >= 0 && appliedStripNodeCurrentIndex < self.stripNodes.count {
                    let previousAlpha = self.stripNodes[appliedStripNodeCurrentIndex].alpha
                    self.stripNodes[appliedStripNodeCurrentIndex].alpha = 0.2
                    if previousAlpha == 1.0 {
                        self.stripNodes[appliedStripNodeCurrentIndex].layer.animateAlpha(from: 1.0, to: 0.2, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
            }
            self.appliedStripNodeCurrentIndex = self.currentIndex
            if self.currentIndex >= 0 && self.currentIndex < self.stripNodes.count {
                self.stripNodes[self.currentIndex].alpha = 1.0
            }
        }
        if hadOneStripNode && self.stripNodes.count > 1 {
            self.stripContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        }
        let stripInset: CGFloat = 8.0
        let stripSpacing: CGFloat = 4.0
        let stripWidth: CGFloat = max(5.0, floor((size.width - stripInset * 2.0 - stripSpacing * CGFloat(self.stripNodes.count - 1)) / CGFloat(self.stripNodes.count)))
        let currentStripMinX = stripInset + CGFloat(self.currentIndex) * (stripWidth + stripSpacing)
        let currentStripMidX = floor(currentStripMinX + stripWidth / 2.0)
        let lastStripMaxX = stripInset + CGFloat(self.stripNodes.count - 1) * (stripWidth + stripSpacing) + stripWidth
        let maxStripOffset: CGFloat = 0.0
        let stripOffset: CGFloat = min(0.0, max(size.width - stripInset - lastStripMaxX, size.width / 2.0 - currentStripMidX))
        for i in 0 ..< self.stripNodes.count {
            let stripX: CGFloat = stripInset + CGFloat(i) * (stripWidth + stripSpacing)
            if i == 0 && self.stripNodes.count == 1 {
                self.stripNodes[i].isHidden = true
            } else {
                self.stripNodes[i].isHidden = false
            }
            let stripFrame = CGRect(origin: CGPoint(x: stripOffset + stripX, y: 0.0), size: CGSize(width: stripWidth + 1.0, height: 2.0))
            stripTransition.updateFrame(node: self.stripNodes[i], frame: stripFrame)
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
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: peer, overrideImage: overrideImage, synchronousLoad: self.isFirstAvatarLoading, displayDimensions: CGSize(width: 100.0, height: 100.0), storeUnrounded: true)
            self.isFirstAvatarLoading = false
        }
    }
}

final class PeerInfoEditingAvatarNode: ASDisplayNode {
    let context: AccountContext
    let avatarNode: AvatarNode
    
    private let updatingAvatarOverlay: ASImageNode
    private let activityIndicator: ActivityIndicator
    
    var tapped: (() -> Void)?
    
    init(context: AccountContext) {
        self.context = context
        let avatarFont = avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0))
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.updatingAvatarOverlay = ASImageNode()
        self.updatingAvatarOverlay.displayWithoutProcessing = true
        self.updatingAvatarOverlay.displaysAsynchronously = false
        self.updatingAvatarOverlay.isHidden = true
        
        self.activityIndicator = ActivityIndicator(type: .custom(.white, 22.0, 1.0, false))
        self.activityIndicator.isHidden = true
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.frame = CGRect(origin: CGPoint(x: -50.0, y: -50.0), size: CGSize(width: 100.0, height: 100.0))
        self.updatingAvatarOverlay.frame = self.avatarNode.frame
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(self.avatarNode.frame.midX - indicatorSize.width / 2.0), y: floorToScreenPixels(self.avatarNode.frame.midY - indicatorSize.height / 2.0)), size: indicatorSize)
        
        self.addSubnode(self.updatingAvatarOverlay)
        self.addSubnode(self.activityIndicator)
        
        self.avatarNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    func update(peer: Peer?, updatingAvatar: PeerInfoUpdatingAvatar?, theme: PresentationTheme) {
        if let peer = peer {
            let overrideImage: AvatarNodeImageOverride?
            if canEditPeerInfo(peer: peer) {
                if let updatingAvatar = updatingAvatar {
                    switch updatingAvatar {
                    case let .image(representation):
                        overrideImage = .image(representation)
                    case .none:
                        overrideImage = .none
                    }
                    self.activityIndicator.isHidden = false
                    self.updatingAvatarOverlay.isHidden = false
                    if self.updatingAvatarOverlay.image == nil {
                        self.updatingAvatarOverlay.image = generateFilledCircleImage(diameter: 100.0, color: UIColor(white: 0.0, alpha: 0.4), backgroundColor: nil)
                    }
                } else {
                    overrideImage = .editAvatarIcon
                    self.activityIndicator.isHidden = true
                    self.updatingAvatarOverlay.isHidden = true
                }
            } else {
                overrideImage = nil
                self.activityIndicator.isHidden = true
                self.updatingAvatarOverlay.isHidden = true
            }
            self.avatarNode.setPeer(context: self.context, theme: theme, peer: peer, overrideImage: overrideImage, synchronousLoad: false, displayDimensions: CGSize(width: 100.0, height: 100.0))
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.avatarNode.frame.contains(point) {
            return self.avatarNode.view
        }
        return super.hitTest(point, with: event)
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
        if let currentItemNode = self.listContainerNode.currentItemNode, let unroundedImage = self.avatarContainerNode.avatarNode.unroundedImage, case let .animated(duration, curve) = transition {
            let avatarCopyView = UIImageView()
            avatarCopyView.image = unroundedImage
            avatarCopyView.frame = self.avatarContainerNode.avatarNode.frame
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
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                } else {
                    transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                }
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

final class PeerInfoHeaderSingleLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode, UITextFieldDelegate {
    private let textNode: TextFieldNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    private let topSeparator: ASDisplayNode
    
    private var theme: PresentationTheme?
    
    var text: String {
        return self.textNode.textField.text ?? ""
    }
    
    override init() {
        self.textNode = TextFieldNode()
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        self.clearIconNode.isHidden = true
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.isHidden = true
        
        self.topSeparator = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        self.addSubnode(self.topSeparator)
        
        self.textNode.textField.delegate = self
        
        self.clearButtonNode.addTarget(self, action: #selector(self.clearButtonPressed), forControlEvents: .touchUpInside)
        self.clearButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconNode.alpha = 0.4
                } else {
                    strongSelf.clearIconNode.alpha = 1.0
                    strongSelf.clearIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func clearButtonPressed() {
        self.textNode.textField.text = ""
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        self.updateClearButtonVisibility()
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        self.updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let isHidden = !self.textNode.textField.isFirstResponder || self.text.isEmpty
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    func update(width: CGFloat, safeInset: CGFloat, hasPrevious: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            self.textNode.textField.textColor = presentationData.theme.list.itemPrimaryTextColor
            self.textNode.textField.keyboardAppearance = presentationData.theme.rootController.keyboardColor.keyboardAppearance
            self.textNode.textField.tintColor = presentationData.theme.list.itemAccentColor
            
            self.clearIconNode.image = PresentationResourcesItemList.itemListClearInputIcon(presentationData.theme)
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
        
        let buttonSize = CGSize(width: 38.0, height: height)
        self.clearButtonNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width, y: 0.0), size: buttonSize)
        if let image = self.clearIconNode.image {
            self.clearIconNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.textNode.frame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: floor((height - 40.0) / 2.0)), size: CGSize(width: max(1.0, width - 16.0 * 2.0 - 32.0), height: 40.0))
        
        self.textNode.isUserInteractionEnabled = isEnabled
        self.textNode.alpha = isEnabled ? 1.0 : 0.6
        
        return height
    }
}

final class PeerInfoHeaderMultiLineTextFieldNode: ASDisplayNode, PeerInfoHeaderTextFieldNode, ASEditableTextNodeDelegate {
    private let textNode: EditableTextNode
    private let textNodeContainer: ASDisplayNode
    private let measureTextNode: ImmediateTextNode
    private let clearIconNode: ASImageNode
    private let clearButtonNode: HighlightableButtonNode
    private let topSeparator: ASDisplayNode
    
    private let requestUpdateHeight: () -> Void
    
    private var theme: PresentationTheme?
    private var currentParams: (width: CGFloat, safeInset: CGFloat)?
    private var currentMeasuredHeight: CGFloat?
    
    var text: String {
        return self.textNode.attributedText?.string ?? ""
    }
    
    init(requestUpdateHeight: @escaping () -> Void) {
        self.requestUpdateHeight = requestUpdateHeight
        
        self.textNode = EditableTextNode()
        self.textNode.clipsToBounds = false
        self.textNode.textView.clipsToBounds = false
        self.textNode.textContainerInset = UIEdgeInsets()
        
        self.textNodeContainer = ASDisplayNode()
        self.measureTextNode = ImmediateTextNode()
        self.measureTextNode.maximumNumberOfLines = 0
        self.topSeparator = ASDisplayNode()
        
        self.clearIconNode = ASImageNode()
        self.clearIconNode.isLayerBacked = true
        self.clearIconNode.displayWithoutProcessing = true
        self.clearIconNode.displaysAsynchronously = false
        self.clearIconNode.isHidden = true
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.isHidden = true
        
        super.init()
        
        self.textNodeContainer.addSubnode(self.textNode)
        self.addSubnode(self.textNodeContainer)
        self.addSubnode(self.clearIconNode)
        self.addSubnode(self.clearButtonNode)
        self.addSubnode(self.topSeparator)
    
        self.clearButtonNode.addTarget(self, action: #selector(self.clearButtonPressed), forControlEvents: .touchUpInside)
        self.clearButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.clearIconNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.clearIconNode.alpha = 0.4
                } else {
                    strongSelf.clearIconNode.alpha = 1.0
                    strongSelf.clearIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
        
    @objc private func clearButtonPressed() {
        guard let theme = self.theme else {
            return
        }
        let attributedText = NSAttributedString(string: "", font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = attributedText
        self.requestUpdateHeight()
        self.updateClearButtonVisibility()
    }
    
    func update(width: CGFloat, safeInset: CGFloat, hasPrevious: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat {
        self.currentParams = (width, safeInset)
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            let textColor = presentationData.theme.list.itemPrimaryTextColor
            
            self.textNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(17.0), NSAttributedString.Key.foregroundColor.rawValue: textColor]
            
            self.textNode.clipsToBounds = true
            self.textNode.delegate = self
            self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
            
            self.clearIconNode.image = PresentationResourcesItemList.itemListClearInputIcon(presentationData.theme)
        }
        
        self.topSeparator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.topSeparator.frame = CGRect(origin: CGPoint(x: safeInset + (hasPrevious ? 16.0 : 0.0), y: 0.0), size: CGSize(width: width, height: UIScreenPixel))
        
        let attributedPlaceholderText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPlaceholderTextColor)
        if self.textNode.attributedPlaceholderText == nil || !self.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
            self.textNode.attributedPlaceholderText = attributedPlaceholderText
        }
        
        if let updateText = updateText {
            let attributedText = NSAttributedString(string: updateText, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            self.textNode.attributedText = attributedText
        }
        
        var measureText = self.textNode.attributedText?.string ?? ""
        if measureText.hasSuffix("\n") || measureText.isEmpty {
           measureText += "|"
        }
        let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
        self.measureTextNode.attributedText = attributedMeasureText
        let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
        self.currentMeasuredHeight = measureTextSize.height
        
        let height = measureTextSize.height + 22.0
        
        let buttonSize = CGSize(width: 38.0, height: height)
        self.clearButtonNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width, y: 0.0), size: buttonSize)
        if let image = self.clearIconNode.image {
            self.clearIconNode.frame = CGRect(origin: CGPoint(x: width - safeInset - buttonSize.width + floor((buttonSize.width - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        let textNodeFrame = CGRect(origin: CGPoint(x: safeInset + 16.0, y: 10.0), size: CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: max(height, 1000.0)))
        self.textNodeContainer.frame = textNodeFrame
        self.textNode.frame = CGRect(origin: CGPoint(), size: textNodeFrame.size)
        
        return height
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.updateClearButtonVisibility()
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.updateClearButtonVisibility()
    }
    
    private func updateClearButtonVisibility() {
        let isHidden = !self.textNode.isFirstResponder() || self.text.isEmpty
        self.clearIconNode.isHidden = isHidden
        self.clearButtonNode.isHidden = isHidden
        self.clearButtonNode.isAccessibilityElement = isHidden
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let theme = self.theme else {
            return true
        }
        let updatedText = (editableTextNode.textView.text as NSString).replacingCharacters(in: range, with: text)
        if updatedText.count > 255 {
            let attributedText = NSAttributedString(string: String(updatedText[updatedText.startIndex..<updatedText.index(updatedText.startIndex, offsetBy: 255)]), font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
            self.textNode.attributedText = attributedText
            self.requestUpdateHeight()
            
            return false
        } else {
            return true
        }
    }
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let (width, safeInset) = self.currentParams {
            var measureText = self.textNode.attributedText?.string ?? ""
            if measureText.hasSuffix("\n") || measureText.isEmpty {
               measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            self.measureTextNode.attributedText = attributedMeasureText
            let measureTextSize = self.measureTextNode.updateLayout(CGSize(width: width - safeInset * 2.0 - 16.0 * 2.0 - 38.0, height: .greatestFiniteMagnitude))
            if let currentMeasuredHeight = self.currentMeasuredHeight, abs(measureTextSize.height - currentMeasuredHeight) > 0.1 {
                self.requestUpdateHeight()
            }
        }
    }
    
    func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool {
        let text: String? = UIPasteboard.general.string
        if let _ = text {
            return true
        } else {
            return false
        }
    }
}

final class PeerInfoHeaderEditingContentNode: ASDisplayNode {
    private let context: AccountContext
    private let requestUpdateLayout: () -> Void
    
    let avatarNode: PeerInfoEditingAvatarNode
    
    var itemNodes: [PeerInfoHeaderTextFieldNodeKey: PeerInfoHeaderTextFieldNode] = [:]
    
    init(context: AccountContext, requestUpdateLayout: @escaping () -> Void) {
        self.context = context
        self.requestUpdateLayout = requestUpdateLayout
        
        self.avatarNode = PeerInfoEditingAvatarNode(context: context)
        
        super.init()
        
        self.addSubnode(self.avatarNode)
    }
    
    func editingTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) -> String? {
        return self.itemNodes[key]?.text
    }
    
    func shakeTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) {
        self.itemNodes[key]?.layer.addShakeAnimation()
    }
    
    func update(width: CGFloat, safeInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, peer: Peer?, cachedData: CachedPeerData?, isContact: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
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
        } else if let _ = peer as? TelegramGroup {
            fieldKeys.append(.title)
            if canEditPeerInfo(peer: peer) {
                fieldKeys.append(.description)
            }
        } else if let _ = peer as? TelegramChannel {
            fieldKeys.append(.title)
            if canEditPeerInfo(peer: peer) {
                fieldKeys.append(.description)
            }
        }
        var hasPrevious = false
        for key in fieldKeys {
            let itemNode: PeerInfoHeaderTextFieldNode
            var updateText: String?
            if let current = self.itemNodes[key] {
                itemNode = current
            } else {
                var isMultiline = false
                switch key {
                case .firstName:
                    updateText = (peer as? TelegramUser)?.firstName ?? ""
                case .lastName:
                    updateText = (peer as? TelegramUser)?.lastName ?? ""
                case .title:
                    updateText = peer?.debugDisplayTitle ?? ""
                case .description:
                    isMultiline = true
                    if let cachedData = cachedData as? CachedChannelData {
                        updateText = cachedData.about ?? ""
                    } else if let cachedData = cachedData as? CachedGroupData {
                        updateText = cachedData.about ?? ""
                    } else {
                        updateText = ""
                    }
                }
                if isMultiline {
                    itemNode = PeerInfoHeaderMultiLineTextFieldNode(requestUpdateHeight: { [weak self] in
                        self?.requestUpdateLayout()
                    })
                } else {
                    itemNode = PeerInfoHeaderSingleLineTextFieldNode()
                }
                self.itemNodes[key] = itemNode
                self.addSubnode(itemNode)
            }
            let placeholder: String
            var isEnabled = true
            switch key {
            case .firstName:
                placeholder = presentationData.strings.UserInfo_FirstNamePlaceholder
                isEnabled = isContact
            case .lastName:
                placeholder = presentationData.strings.UserInfo_LastNamePlaceholder
                isEnabled = isContact
            case .title:
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    placeholder = presentationData.strings.GroupInfo_ChannelListNamePlaceholder
                } else {
                    placeholder = presentationData.strings.GroupInfo_GroupNamePlaceholder
                }
                isEnabled = canEditPeerInfo(peer: peer)
            case .description:
                placeholder = presentationData.strings.Channel_Edit_AboutItem
                isEnabled = canEditPeerInfo(peer: peer)
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

private let TitleNodeStateRegular = 0
private let TitleNodeStateExpanded = 1

final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private var presentationData: PresentationData?
    
    private let isOpenedFromChat: Bool
    
    private(set) var isAvatarExpanded: Bool
    
    let avatarListNode: PeerInfoAvatarListNode
    
    let regularContentNode: PeerInfoHeaderRegularContentNode
    let editingContentNode: PeerInfoHeaderEditingContentNode
    let titleNodeContainer: ASDisplayNode
    let titleNodeRawContainer: ASDisplayNode
    let titleNode: MultiScaleTextNode
    let titleCredibilityIconNode: ASImageNode
    let titleExpandedCredibilityIconNode: ASImageNode
    let subtitleNodeContainer: ASDisplayNode
    let subtitleNodeRawContainer: ASDisplayNode
    let subtitleNode: MultiScaleTextNode
    private var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    private let backgroundNode: ASDisplayNode
    private let expandedBackgroundNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    let navigationButtonContainer: PeerInfoHeaderNavigationButtonContainerNode
    
    var performButtonAction: ((PeerInfoHeaderButtonKey) -> Void)?
    var requestAvatarExpansion: (([AvatarGalleryEntry], AvatarGalleryEntry?, (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?) -> Void)?
    var requestOpenAvatarForEditing: (() -> Void)?
    var requestUpdateLayout: (() -> Void)?
    
    var navigationTransition: PeerInfoHeaderNavigationTransition?
    
    init(context: AccountContext, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool) {
        self.context = context
        self.isAvatarExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        
        self.avatarListNode = PeerInfoAvatarListNode(context: context, readyWhenGalleryLoads: avatarInitiallyExpanded)
        
        self.titleNodeContainer = ASDisplayNode()
        self.titleNodeRawContainer = ASDisplayNode()
        self.titleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.titleNode.displaysAsynchronously = false
        
        self.titleCredibilityIconNode = ASImageNode()
        self.titleCredibilityIconNode.displaysAsynchronously = false
        self.titleCredibilityIconNode.displayWithoutProcessing = true
        self.titleNode.stateNode(forKey: TitleNodeStateRegular)?.addSubnode(self.titleCredibilityIconNode)
        
        self.titleExpandedCredibilityIconNode = ASImageNode()
        self.titleExpandedCredibilityIconNode.displaysAsynchronously = false
        self.titleExpandedCredibilityIconNode.displayWithoutProcessing = true
        self.titleNode.stateNode(forKey: TitleNodeStateExpanded)?.addSubnode(self.titleExpandedCredibilityIconNode)
        
        self.subtitleNodeContainer = ASDisplayNode()
        self.subtitleNodeRawContainer = ASDisplayNode()
        self.subtitleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.subtitleNode.displaysAsynchronously = false
        
        self.regularContentNode = PeerInfoHeaderRegularContentNode()
        var requestUpdateLayoutImpl: (() -> Void)?
        self.editingContentNode = PeerInfoHeaderEditingContentNode(context: context, requestUpdateLayout: {
            requestUpdateLayoutImpl?()
        })
        self.editingContentNode.alpha = 0.0
        
        self.navigationButtonContainer = PeerInfoHeaderNavigationButtonContainerNode()
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.expandedBackgroundNode = ASDisplayNode()
        self.expandedBackgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        requestUpdateLayoutImpl = { [weak self] in
            self?.requestUpdateLayout?()
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.expandedBackgroundNode)
        self.addSubnode(self.separatorNode)
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.regularContentNode.addSubnode(self.titleNodeContainer)
        self.subtitleNodeContainer.addSubnode(self.subtitleNode)
        self.regularContentNode.addSubnode(self.subtitleNodeContainer)
        self.regularContentNode.addSubnode(self.avatarListNode)
        self.regularContentNode.addSubnode(self.avatarListNode.listContainerNode.controlsClippingOffsetNode)
        self.addSubnode(self.regularContentNode)
        self.addSubnode(self.editingContentNode)
        self.addSubnode(self.navigationButtonContainer)
        
        self.avatarListNode.avatarContainerNode.tapped = { [weak self] in
            self?.initiateAvatarExpansion()
        }
        self.editingContentNode.avatarNode.tapped = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.requestOpenAvatarForEditing?()
        }
    }
    
    func initiateAvatarExpansion() {
        if self.isAvatarExpanded {
            if let currentEntry = self.avatarListNode.listContainerNode.currentEntry {
                self.requestAvatarExpansion?(self.avatarListNode.listContainerNode.galleryEntries, self.avatarListNode.listContainerNode.currentEntry, self.avatarTransitionArguments(entry: currentEntry))
            }
        } else if let entry = self.avatarListNode.listContainerNode.galleryEntries.first{
            let avatarNode = self.avatarListNode.avatarContainerNode.avatarNode
            self.requestAvatarExpansion?(self.avatarListNode.listContainerNode.galleryEntries, nil, self.avatarTransitionArguments(entry: entry))
        }
    }
    
    func avatarTransitionArguments(entry: AvatarGalleryEntry) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.isAvatarExpanded {
            if let avatarNode = self.avatarListNode.listContainerNode.currentItemNode?.imageNode {
                return (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                    return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
                })
            } else {
                return nil
            }
        } else if entry == self.avatarListNode.listContainerNode.galleryEntries.first {
            let avatarNode = self.avatarListNode.avatarContainerNode.avatarNode
            return (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    func addToAvatarTransitionSurface(view: UIView) {
        if self.isAvatarExpanded {
            self.avatarListNode.listContainerNode.view.addSubview(view)
        } else {
            self.view.addSubview(view)
        }
    }
    
    func updateAvatarIsHidden(entry: AvatarGalleryEntry?) {
        if let entry = entry {
            self.avatarListNode.avatarContainerNode.avatarNode.isHidden = entry == self.avatarListNode.listContainerNode.galleryEntries.first
        } else {
            self.avatarListNode.avatarContainerNode.avatarNode.isHidden = false
        }
        self.avatarListNode.listContainerNode.updateEntryIsHidden(entry: entry)
    }
    
    func update(width: CGFloat, containerHeight: CGFloat, containerInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, contentOffset: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, notificationSettings: TelegramPeerNotificationSettings?, statusData: PeerInfoStatusData?, isContact: Bool, state: PeerInfoState, transition: ContainedViewLayoutTransition, additive: Bool) -> CGFloat {
        let themeUpdated = self.presentationData?.theme !== presentationData.theme
        self.presentationData = presentationData
        
        if themeUpdated {
            if let sourceImage = UIImage(bundleImageName: "Peer Info/VerifiedIcon") {
                let image = generateImage(sourceImage.size, contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(presentationData.theme.list.itemCheckColors.foregroundColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: 7.0, dy: 7.0))
                    context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: sourceImage.cgImage!)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                })
                self.titleCredibilityIconNode.image = image
                self.titleExpandedCredibilityIconNode.image = image
            }
        }
        
        self.regularContentNode.alpha = state.isEditing ? 0.0 : 1.0
        self.editingContentNode.alpha = state.isEditing ? 1.0 : 0.0
        
        let editingContentHeight = self.editingContentNode.update(width: width, safeInset: containerInset, statusBarHeight: statusBarHeight, navigationHeight: navigationHeight, peer: state.isEditing ? peer : nil, cachedData: cachedData, isContact: isContact, presentationData: presentationData, transition: transition)
        transition.updateFrame(node: self.editingContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -contentOffset), size: CGSize(width: width, height: editingContentHeight)))
        
        var transitionSourceHeight: CGFloat = 0.0
        var transitionFraction: CGFloat = 0.0
        var transitionSourceAvatarFrame = CGRect()
        var transitionSourceTitleFrame = CGRect()
        var transitionSourceSubtitleFrame = CGRect()
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.expandedBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        
        if let navigationTransition = self.navigationTransition, let sourceAvatarNode = (navigationTransition.sourceNavigationBar.rightButtonNode.singleCustomNode as? ChatAvatarNavigationNode)?.avatarNode {
            transitionSourceHeight = navigationTransition.sourceNavigationBar.bounds.height
            transitionFraction = navigationTransition.fraction
            transitionSourceAvatarFrame = sourceAvatarNode.view.convert(sourceAvatarNode.view.bounds, to: navigationTransition.sourceNavigationBar.view)
            transitionSourceTitleFrame = navigationTransition.sourceTitleFrame
            transitionSourceSubtitleFrame = navigationTransition.sourceSubtitleFrame
            
            transition.updateAlpha(node: self.expandedBackgroundNode, alpha: transitionFraction)
            
            if self.isAvatarExpanded, case .animated = transition, transitionFraction == 1.0 {
                self.avatarListNode.animateAvatarCollapse(transition: transition)
            }
        } else {
            let backgroundTransitionFraction: CGFloat = max(0.0, min(1.0, contentOffset / (212.0)))
            transition.updateAlpha(node: self.expandedBackgroundNode, alpha: backgroundTransitionFraction)
        }
        
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let defaultButtonSize: CGFloat = 40.0
        let defaultMaxButtonSpacing: CGFloat = 40.0
        let expandedAvatarControlsHeight: CGFloat = 61.0
        let expandedAvatarListHeight = min(width, containerHeight - expandedAvatarControlsHeight)
        let expandedAvatarListSize = CGSize(width: width, height: expandedAvatarListHeight)
        
        let buttonKeys: [PeerInfoHeaderButtonKey] = peerInfoHeaderButtons(peer: peer, cachedData: cachedData, isOpenedFromChat: self.isOpenedFromChat)
        
        var isVerified = false
        let titleString: NSAttributedString
        let subtitleString: NSAttributedString
        if let peer = peer, peer.isVerified {
            isVerified = true
        }
        
        if let peer = peer {
            if peer.id == self.context.account.peerId {
                titleString = NSAttributedString(string: presentationData.strings.Conversation_SavedMessages, font: Font.medium(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            } else {
                titleString = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.medium(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            }
            
            if let statusData = statusData {
                let subtitleColor: UIColor
                if statusData.isActivity {
                    subtitleColor = presentationData.theme.list.itemAccentColor
                } else {
                    subtitleColor = presentationData.theme.list.itemSecondaryTextColor
                }
                subtitleString = NSAttributedString(string: statusData.text, font: Font.regular(15.0), textColor: subtitleColor)
            } else {
                subtitleString = NSAttributedString(string: " ", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
            }
        } else {
            titleString = NSAttributedString(string: " ", font: Font.medium(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            subtitleString = NSAttributedString(string: " ", font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
        }
        
        let textSideInset: CGFloat = 44.0
        let expandedAvatarHeight: CGFloat = expandedAvatarListSize.height + expandedAvatarControlsHeight
        
        let titleConstrainedSize = CGSize(width: width - textSideInset * 2.0 - (isVerified ? 16.0 : 0.0), height: .greatestFiniteMagnitude)
        
        let titleNodeLayout = self.titleNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: titleString, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: titleString, constrainedSize: CGSize(width: titleConstrainedSize.width, height: titleConstrainedSize.height))
        ], mainState: TitleNodeStateRegular)
        
        let subtitleNodeLayout = self.subtitleNode.updateLayout(states: [
            TitleNodeStateRegular: MultiScaleTextState(attributedText: subtitleString, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributedText: subtitleString, constrainedSize: CGSize(width: titleConstrainedSize.width - 82.0, height: titleConstrainedSize.height))
        ], mainState: TitleNodeStateRegular)
        
        self.titleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], transition: transition)
        
        self.subtitleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], transition: transition)
        
        let avatarSize: CGFloat = 100.0
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 10.0), size: CGSize(width: avatarSize, height: avatarSize))
        let avatarCenter = CGPoint(x: (1.0 - transitionFraction) * avatarFrame.midX + transitionFraction * transitionSourceAvatarFrame.midX, y: (1.0 - transitionFraction) * avatarFrame.midY + transitionFraction * transitionSourceAvatarFrame.midY)
        
        let titleSize = titleNodeLayout[TitleNodeStateRegular]!.size
        let titleExpandedSize = titleNodeLayout[TitleNodeStateExpanded]!.size
        let subtitleSize = subtitleNodeLayout[TitleNodeStateRegular]!.size
        
        if let image = self.titleCredibilityIconNode.image {
            transition.updateFrame(node: self.titleCredibilityIconNode, frame: CGRect(origin: CGPoint(x: titleSize.width + 4.0, y: floor((titleSize.height - image.size.height) / 2.0) + 1.0), size: image.size))
            self.titleCredibilityIconNode.isHidden = !isVerified
            
            transition.updateFrame(node: self.titleExpandedCredibilityIconNode, frame: CGRect(origin: CGPoint(x: titleExpandedSize.width + 4.0, y: floor((titleExpandedSize.height - image.size.height) / 2.0) + 1.0), size: image.size))
            self.titleExpandedCredibilityIconNode.isHidden = !isVerified
        }
        
        let titleFrame: CGRect
        let subtitleFrame: CGRect
        if self.isAvatarExpanded {
            let minTitleSize = CGSize(width: titleSize.width * 0.7, height: titleSize.height * 0.7)
            let minTitleFrame = CGRect(origin: CGPoint(x: 16.0, y: expandedAvatarHeight - expandedAvatarControlsHeight + 9.0 + (subtitleSize.height.isZero ? 10.0 : 0.0)), size: minTitleSize)
            titleFrame = CGRect(origin: CGPoint(x: minTitleFrame.midX - titleSize.width / 2.0, y: minTitleFrame.midY - titleSize.height / 2.0), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: 16.0, y: minTitleFrame.maxY + 4.0), size: subtitleSize)
        } else {
            titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 10.0 + (subtitleSize.height.isZero ? 11.0 : 0.0)), size: titleSize)
            subtitleFrame = CGRect(origin: CGPoint(x: floor((width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
        }
        
        let singleTitleLockOffset: CGFloat = (peer?.id == self.context.account.peerId || subtitleSize.height.isZero) ? 8.0 : 0.0
        
        let titleLockOffset: CGFloat = 7.0 + singleTitleLockOffset
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
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: transitionFraction * transitionSourceAvatarFrame.width / 2.0)
            } else {
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 0.0)
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: 0.0)
            }
        } else if self.avatarListNode.listContainerNode.cornerRadius != 50.0 {
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: 50.0)
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 50.0, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.avatarListNode.listContainerNode.isHidden = true
            })
        }
        
        self.avatarListNode.update(size: CGSize(), isExpanded: self.isAvatarExpanded, peer: peer, theme: presentationData.theme, transition: transition)
        self.editingContentNode.avatarNode.update(peer: peer, updatingAvatar: state.updatingAvatar, theme: presentationData.theme)
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
        }
        let apparentAvatarFrame: CGRect
        let controlsClippingFrame: CGRect
        if self.isAvatarExpanded {
            let expandedAvatarCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.height / 2.0 - contentOffset / 2.0)
            apparentAvatarFrame = CGRect(origin: CGPoint(x: expandedAvatarCenter.x * (1.0 - transitionFraction) + transitionFraction * avatarCenter.x, y: expandedAvatarCenter.y * (1.0 - transitionFraction) + transitionFraction * avatarCenter.y), size: CGSize())
            if !transitionSourceAvatarFrame.width.isZero {
                let expandedFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
                controlsClippingFrame = CGRect(origin: CGPoint(x: transitionFraction * transitionSourceAvatarFrame.minX + (1.0 - transitionFraction) * expandedFrame.minX, y: transitionFraction * transitionSourceAvatarFrame.minY + (1.0 - transitionFraction) * expandedFrame.minY), size: CGSize(width: transitionFraction * transitionSourceAvatarFrame.width + (1.0 - transitionFraction) * expandedFrame.width, height: transitionFraction * transitionSourceAvatarFrame.height + (1.0 - transitionFraction) * expandedFrame.height))
            } else {
                controlsClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
            }
        } else {
            apparentAvatarFrame = CGRect(origin: CGPoint(x: avatarCenter.x - avatarFrame.width / 2.0, y: -contentOffset + avatarOffset + avatarCenter.y - avatarFrame.height / 2.0), size: avatarFrame.size)
            controlsClippingFrame = apparentAvatarFrame
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
        
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsClippingOffsetNode, frame: CGRect(origin: controlsClippingFrame.center, size: CGSize()))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.controlsClippingNode, frame: CGRect(origin: CGPoint(x: -controlsClippingFrame.width / 2.0, y: -controlsClippingFrame.height / 2.0), size: controlsClippingFrame.size))
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsContainerNode, frame: CGRect(origin: CGPoint(x: -controlsClippingFrame.minX, y: -controlsClippingFrame.minY), size: CGSize(width: expandedAvatarListSize.width, height: expandedAvatarListSize.height)))
        
        transition.updateFrame(node: self.avatarListNode.listContainerNode.shadowNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: expandedAvatarListSize.width, height: navigationHeight + 20.0)))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.stripContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusBarHeight < 25.0 ? (statusBarHeight + 2.0) : (statusBarHeight - 3.0)), size: CGSize(width: expandedAvatarListSize.width, height: 2.0)))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.highlightContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: expandedAvatarListSize.width, height: expandedAvatarListSize.height)))
        transition.updateAlpha(node: self.avatarListNode.listContainerNode.controlsContainerNode, alpha: self.isAvatarExpanded ? (1.0 - transitionFraction) : 0.0)
        
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
                
                let titleCenter = CGPoint(x: transitionFraction * transitionSourceTitleFrame.midX + (1.0 - transitionFraction) * titleFrame.midX, y: transitionFraction * transitionSourceTitleFrame.midY + (1.0 - transitionFraction) * titleFrame.midY)
                let subtitleCenter = CGPoint(x: transitionFraction * transitionSourceSubtitleFrame.midX + (1.0 - transitionFraction) * subtitleFrame.midX, y: transitionFraction * transitionSourceSubtitleFrame.midY + (1.0 - transitionFraction) * subtitleFrame.midY)
                
                let rawTitleFrame = CGRect(origin: CGPoint(x: titleCenter.x - titleFrame.size.width * neutralTitleScale / 2.0, y: titleCenter.y - titleFrame.size.height * neutralTitleScale / 2.0), size: CGSize(width: titleFrame.size.width * neutralTitleScale, height: titleFrame.size.height * neutralTitleScale))
                self.titleNodeRawContainer.frame = rawTitleFrame
                transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()))
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                let rawSubtitleFrame = CGRect(origin: CGPoint(x: subtitleCenter.x - subtitleFrame.size.width / 2.0, y: subtitleCenter.y - subtitleFrame.size.height / 2.0), size: subtitleFrame.size)
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()))
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
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
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                let rawSubtitleFrame = subtitleFrame
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                if self.isAvatarExpanded {
                    transition.updateFrameAdditive(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                    transition.updateFrameAdditive(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                } else {
                    transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                    transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                }
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                transition.updateSublayerTransformScaleAdditive(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScaleAdditive(node: self.subtitleNodeContainer, scale: subtitleScale)
            }
        }
        
        let buttonSpacing: CGFloat
        if self.isAvatarExpanded {
            buttonSpacing = 16.0
        } else {
            let normWidth = min(width, containerHeight)
            let buttonSpacingValue = floor((normWidth - floor(CGFloat(buttonKeys.count) * defaultButtonSize)) / CGFloat(buttonKeys.count + 1))
            buttonSpacing = min(buttonSpacingValue, 160.0)
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
        
        var buttonsAlphaTransition = transition
        
        if self.navigationTransition != nil {
            if case let .animated(duration, curve) = transition, transitionFraction >= 1.0 - CGFloat.ulpOfOne {
                buttonsAlphaTransition = .animated(duration: duration * 0.6, curve: curve)
            }
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
                buttonText = presentationData.strings.PeerInfo_ButtonMessage
                buttonIcon = .message
            case .discussion:
                buttonText = presentationData.strings.PeerInfo_ButtonDiscuss
                buttonIcon = .message
            case .call:
                buttonText = presentationData.strings.PeerInfo_ButtonCall
                buttonIcon = .call
            case .mute:
                if let notificationSettings = notificationSettings, case .muted = notificationSettings.muteState {
                    buttonText = presentationData.strings.PeerInfo_ButtonUnmute
                    buttonIcon = .unmute
                } else {
                    buttonText = presentationData.strings.PeerInfo_ButtonMute
                    buttonIcon = .mute
                }
            case .more:
                buttonText = presentationData.strings.PeerInfo_ButtonMore
                buttonIcon = .more
            case .addMember:
                buttonText = presentationData.strings.PeerInfo_ButtonAddMember
                buttonIcon = .addMember
            case .search:
                buttonText = presentationData.strings.PeerInfo_ButtonSearch
                buttonIcon = .search
            case .leave:
                buttonText = presentationData.strings.PeerInfo_ButtonLeave
                buttonIcon = .leave
            }
            buttonNode.update(size: buttonFrame.size, text: buttonText, icon: buttonIcon, isExpanded: self.isAvatarExpanded, presentationData: presentationData, transition: buttonTransition)
            transition.updateSublayerTransformScaleAdditive(node: buttonNode, scale: buttonsScale)
            
            if wasAdded {
                buttonNode.alpha = 0.0
            }
            buttonsAlphaTransition.updateAlpha(node: buttonNode, alpha: buttonsAlpha)
            
            let hiddenWhileExpanded: Bool
            if buttonKeys.count > 3 {
                if self.isOpenedFromChat {
                    switch buttonKey {
                    case .message, .search:
                        hiddenWhileExpanded = true
                    default:
                        hiddenWhileExpanded = false
                    }
                } else {
                    switch buttonKey {
                    case .mute, .search:
                        hiddenWhileExpanded = true
                    default:
                        hiddenWhileExpanded = false
                    }
                }
            } else {
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
