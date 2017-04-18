import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private let defaultBackgroundColor: UIColor = UIColor(white: 1.0, alpha: 1.0)
private let highlightedBackgroundColor: UIColor = UIColor(white: 0.9, alpha: 1.0)
private let separatorColor: UIColor = UIColor(0xbcbbc1)

private let subtitleFont = Font.regular(12.0)
private let subtitleColor = UIColor(0x7b7b81)

private let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: .white)
private let highlightedRoundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: highlightedBackgroundColor)

private let halfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
})?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)

private let highlightedHalfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(highlightedBackgroundColor.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
})?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)

final class ShareControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let account: Account
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let dimNode: ASDisplayNode
    
    private let wrappingScrollNode: ASScrollNode
    private let cancelButtonNode: ASButtonNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASImageNode
    private let contentGridNode: GridNode
    private let installActionButtonNode: ShareActionButtonNode
    private let installActionSeparatorNode: ASDisplayNode
    private let contentTitleNode: ASTextNode
    private let contentSubtitleNode: ASTextNode
    private let contentSeparatorNode: ASDisplayNode
    
    private var activityIndicatorView: UIActivityIndicatorView?
    
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    var share: (([PeerId]) -> Void)?
    
    let ready = Promise<Bool>()
    private var didSetReady = false
    
    private var peers: [Peer]?
    private var inProgress = false
    private var peersUpdated = false
    
    private var didSetItems = false
    
    private var selectedPeers: [Peer] = []
    private var controllerInteraction: ShareControllerInteraction?
    
    private var defaultAction: ShareControllerAction?
    
    init(account: Account) {
        self.account = account
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.cancelButtonNode = ASButtonNode()
        self.cancelButtonNode.displaysAsynchronously = false
        self.cancelButtonNode.setBackgroundImage(roundedBackground, for: .normal)
        self.cancelButtonNode.setBackgroundImage(highlightedRoundedBackground, for: .highlighted)
        //self.cancelButtonNode.cornerRadius = 16.0
        //self.cancelButtonNode.clipsToBounds = true
        
        self.contentContainerNode = ASDisplayNode()
        //self.contentContainerNode.cornerRadius = 16.0
        //self.contentContainerNode.clipsToBounds = true
        self.contentContainerNode.isOpaque = false
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.image = roundedBackground
        //self.contentBackgroundNode.cornerRadius = 16.0
        //self.contentBackgroundNode.clipsToBounds = true
        
        self.contentGridNode = GridNode()
        
        self.installActionButtonNode = ShareActionButtonNode()
        self.installActionButtonNode.displaysAsynchronously = false
        self.installActionButtonNode.titleNode.displaysAsynchronously = false
        self.installActionButtonNode.setBackgroundImage(halfRoundedBackground, for: .normal)
        self.installActionButtonNode.setBackgroundImage(highlightedHalfRoundedBackground, for: .highlighted)
        
        self.contentTitleNode = ASTextNode()
        
        self.contentSubtitleNode = ASTextNode()
        self.contentSubtitleNode.maximumNumberOfLines = 1
        self.contentSubtitleNode.isLayerBacked = true
        self.contentSubtitleNode.displaysAsynchronously = false
        self.contentSubtitleNode.truncationMode = .byTruncatingTail
        self.contentSubtitleNode.attributedText = NSAttributedString(string: "Select chats", font: subtitleFont, textColor: subtitleColor)
        
        self.contentSeparatorNode = ASDisplayNode()
        self.contentSeparatorNode.isLayerBacked = true
        self.contentSeparatorNode.displaysAsynchronously = false
        self.contentSeparatorNode.backgroundColor = separatorColor
        
        self.installActionSeparatorNode = ASDisplayNode()
        self.installActionSeparatorNode.isLayerBacked = true
        self.installActionSeparatorNode.displaysAsynchronously = false
        self.installActionSeparatorNode.backgroundColor = separatorColor
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.controllerInteraction = ShareControllerInteraction(togglePeer: { [weak self] peer in
            if let strongSelf = self {
                if strongSelf.controllerInteraction!.selectedPeerIds.contains(peer.id) {
                    strongSelf.controllerInteraction!.selectedPeerIds.remove(peer.id)
                    strongSelf.selectedPeers = strongSelf.selectedPeers.filter({ $0.id != peer.id })
                } else {
                    strongSelf.controllerInteraction!.selectedPeerIds.insert(peer.id)
                    strongSelf.selectedPeers.append(peer)
                }
                
                strongSelf.updateVisibleItemsSelection(animated: true)
                if strongSelf.selectedPeers.isEmpty {
                    if let defaultAction = strongSelf.defaultAction {
                        strongSelf.installActionButtonNode.setTitle(defaultAction.title, with: Font.regular(20.0), with: UIColor(0x007ee5), for: .normal)
                    }
                    strongSelf.installActionButtonNode.badge = nil
                } else {
                    strongSelf.installActionButtonNode.setTitle("Send", with: Font.medium(20.0), with: UIColor(0x007ee5), for: .normal)
                    strongSelf.installActionButtonNode.badge = "\(strongSelf.selectedPeers.count)"
                }
                
                var subtitleText = "Select chats"
                if !strongSelf.selectedPeers.isEmpty {
                    subtitleText = strongSelf.selectedPeers.reduce("", { string, peer in
                        if !string.isEmpty {
                            return string + ", " + peer.displayTitle
                        } else {
                            return string + peer.displayTitle
                        }
                    })
                }
                strongSelf.contentSubtitleNode.attributedText = NSAttributedString(string: subtitleText, font: subtitleFont, textColor: subtitleColor)
                
                if let (layout, navigationBarHeight) = strongSelf.containerLayout, let _ = strongSelf.peers {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
        })
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.cancelButtonNode.setTitle("Cancel", with: Font.medium(20.0), with: UIColor(0x007ee5), for: .normal)
        /*self.cancelButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelButtonNode.backgroundColor = highlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.cancelButtonNode.backgroundColor = defaultBackgroundColor
                    })
                }
            }
        }*/
        
        /*self.installActionButtonNode.backgroundColor = defaultBackgroundColor
        self.installActionButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.installActionButtonNode.backgroundColor = highlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.installActionButtonNode.backgroundColor = defaultBackgroundColor
                    })
                }
            }
        }*/
        
        self.wrappingScrollNode.addSubnode(self.cancelButtonNode)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        
        self.installActionButtonNode.addTarget(self, action: #selector(self.installActionButtonPressed), forControlEvents: .touchUpInside)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.contentGridNode)
        self.contentContainerNode.addSubnode(self.installActionSeparatorNode)
        self.contentContainerNode.addSubnode(self.installActionButtonNode)
        self.wrappingScrollNode.addSubnode(self.contentTitleNode)
        self.wrappingScrollNode.addSubnode(self.contentSubtitleNode)
        self.wrappingScrollNode.addSubnode(self.contentSeparatorNode)
        
        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let bottomInset: CGFloat = 10.0
        let buttonHeight: CGFloat = 57.0
        let sectionSpacing: CGFloat = 8.0
        let titleAreaHeight: CGFloat = 64.0
        
        let width = min(layout.size.width, layout.size.height) - 20.0
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
        
        let maximumContentHeight = layout.size.height - insets.top - bottomInset - buttonHeight - sectionSpacing
        
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
        let contentFrame = contentContainerFrame.insetBy(dx: 12.0, dy: 0.0)
        
        var insertItems: [GridNodeInsertItem] = []
        
        var itemCount = 0
        var animateIn = false
        
        if let peers = self.peers {
            if let activityIndicatorView = self.activityIndicatorView {
                activityIndicatorView.removeFromSuperview()
                activityIndicatorView.stopAnimating()
            }
            itemCount = peers.count
            if !self.didSetItems {
                self.contentTitleNode.attributedText = NSAttributedString(string: "Share to", font: Font.medium(20.0), textColor: .black)
                
                self.didSetItems = true
                animateIn = true
                for i in 0 ..< peers.count {
                    insertItems.append(GridNodeInsertItem(index: i, item: ShareControllerPeerGridItem(account: self.account, peer: peers[i], controllerInteraction: self.controllerInteraction!), previousIndex: nil))
                }
            }
        }
        
        let titleSize = self.contentTitleNode.measure(contentContainerFrame.size)
        let titleFrame = CGRect(origin: CGPoint(x: contentContainerFrame.minX + floor((contentContainerFrame.size.width - titleSize.width) / 2.0), y: self.contentBackgroundNode.frame.minY + 15.0), size: titleSize)
        let deltaTitlePosition = CGPoint(x: titleFrame.midX - self.contentTitleNode.frame.midX, y: titleFrame.midY - self.contentTitleNode.frame.midY)
        self.contentTitleNode.frame = titleFrame
        transition.animatePosition(node: self.contentTitleNode, from: CGPoint(x: titleFrame.midX + deltaTitlePosition.x, y: titleFrame.midY + deltaTitlePosition.y))
        
        let subtitleSize = self.contentSubtitleNode.measure(CGSize(width: contentContainerFrame.size.width - 44.0 * 2.0 - 4.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let subtitleFrame = CGRect(origin: CGPoint(x: contentContainerFrame.minX + floor((contentContainerFrame.size.width - subtitleSize.width) / 2.0), y: self.contentBackgroundNode.frame.minY + 40.0), size: subtitleSize)
        let deltaSubtitlePosition = CGPoint(x: subtitleFrame.midX - self.contentSubtitleNode.frame.midX, y: subtitleFrame.midY - self.contentSubtitleNode.frame.midY)
        self.contentSubtitleNode.frame = subtitleFrame
        transition.animatePosition(node: self.contentSubtitleNode, from: CGPoint(x: subtitleFrame.midX, y: subtitleFrame.midY + deltaSubtitlePosition.y))
        
        transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: contentContainerFrame.minX, y: self.contentBackgroundNode.frame.minY + titleAreaHeight), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
        
        let itemsPerRow = 4
        let itemWidth = floor(contentFrame.size.width / CGFloat(itemsPerRow))
        let rowCount = itemCount / itemsPerRow + (itemCount % itemsPerRow != 0 ? 1 : 0)
        
        let minimallyRevealedRowCount: CGFloat = 3.5
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let topInset = max(0.0, contentFrame.size.height - initiallyRevealedRowCount * itemWidth - titleAreaHeight)
        let bottomGridInset = buttonHeight
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        
        if let activityIndicatorView = activityIndicatorView {
            transition.updateFrame(layer: activityIndicatorView.layer, frame: CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.width - activityIndicatorView.bounds.size.width) / 2.0), y: contentFrame.maxY - activityIndicatorView.bounds.size.height - 34.0), size: activityIndicatorView.bounds.size))
        }
        
        transition.updateFrame(node: self.installActionButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - buttonHeight), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
        transition.updateFrame(node: self.installActionSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - buttonHeight - UIScreenPixel), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: insertItems, updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: contentFrame.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomGridInset, right: 0.0), preloadSize: 80.0, type: .fixed(itemSize: CGSize(width: itemWidth, height: itemWidth + 25.0))), transition: transition), stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        transition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height - titleAreaHeight))))
        
        if animateIn {
            var durationOffset = 0.0
            self.contentGridNode.forEachRow { itemNodes in
                for itemNode in itemNodes {
                    itemNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 4.0), to: CGPoint(), duration: 0.4 + durationOffset, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    if let itemNode = itemNode as? StickerPackPreviewGridItemNode {
                        itemNode.animateIn()
                    }
                }
                durationOffset += 0.04
            }
            
            self.contentGridNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.installActionButtonNode.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.installActionSeparatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            
            self.contentGridNode.layer.animateBoundsOriginYAdditive(from: -(topInset - buttonHeight), to: 0.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        if let _ = self.peers, self.peersUpdated {
            self.dequeueUpdatePeers()
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        if let (layout, _) = self.containerLayout {
            var insets = layout.insets(options: [.statusBar])
            insets.top = max(10.0, insets.top)
            
            let bottomInset: CGFloat = 10.0
            let buttonHeight: CGFloat = 57.0
            let sectionSpacing: CGFloat = 8.0
            let titleAreaHeight: CGFloat = 64.0
            
            let width = min(layout.size.width, layout.size.height) - 20.0
            
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let maximumContentHeight = layout.size.height - insets.top - bottomInset - buttonHeight - sectionSpacing
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
            
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY - presentationLayout.contentOffset.y), size: contentFrame.size)
            if backgroundFrame.minY < contentFrame.minY {
                backgroundFrame.origin.y = contentFrame.minY
            }
            if backgroundFrame.maxY > contentFrame.maxY {
                backgroundFrame.size.height += contentFrame.maxY - backgroundFrame.maxY
            }
            if backgroundFrame.size.height < buttonHeight + 32.0 {
                backgroundFrame.origin.y -= buttonHeight + 32.0 - backgroundFrame.size.height
                backgroundFrame.size.height = buttonHeight + 32.0
            }
            var compactFrame = true
            if let _ = self.peers, !inProgress {
                compactFrame = false
            }
            if compactFrame {
                backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.maxY - buttonHeight - 32.0), size: CGSize(width: contentFrame.size.width, height: buttonHeight + 32.0))
            }
            transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
            
            let titleSize = self.contentTitleNode.bounds.size
            let titleFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.size.width - titleSize.width) / 2.0), y: backgroundFrame.minY + 15.0), size: titleSize)
            transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
            
            let subtitleSize = self.contentSubtitleNode.bounds.size
            let subtitleFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.size.width - subtitleSize.width) / 2.0), y: backgroundFrame.minY + 40.0), size: subtitleSize)
            transition.updateFrame(node: self.contentSubtitleNode, frame: subtitleFrame)
            
            transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: backgroundFrame.minY + titleAreaHeight), size: CGSize(width: contentFrame.size.width, height: UIScreenPixel)))
            
            if !compactFrame && CGFloat(0.0).isLessThanOrEqualTo(presentationLayout.contentOffset.y) {
                self.contentSeparatorNode.alpha = 1.0
            } else {
                self.contentSeparatorNode.alpha = 0.0
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func installActionButtonPressed() {
        if self.selectedPeers.isEmpty {
            if let defaultAction = self.defaultAction {
                defaultAction.action()
            }
        } else {
            self.share?(self.selectedPeers.map { $0.id })
            /*self.inProgress = true
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
            }*/
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    func updatePeers(peers: [Peer], defaultAction: ShareControllerAction?) {
        self.defaultAction = defaultAction
        
        self.peers = peers
        self.peersUpdated = true
        if let _ = self.containerLayout {
            self.dequeueUpdatePeers()
        }
        
        self.installActionSeparatorNode.alpha = 1.0
        
        if let defaultAction = defaultAction {
            self.installActionButtonNode.setTitle(defaultAction.title, with: Font.regular(20.0), with: UIColor(0x007ee5), for: .normal)
        }
    }
    
    func dequeueUpdatePeers() {
        if let (layout, navigationBarHeight) = self.containerLayout, let _ = peers, self.peersUpdated {
            self.peersUpdated = false
            
            let transition: ContainedViewLayoutTransition
            if self.didSetReady {
                transition = .animated(duration: 0.4, curve: .spring)
            } else {
                transition = .immediate
            }
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.installActionButtonNode.hitTest(self.installActionButtonNode.convert(point, from: self), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    private func updateVisibleItemsSelection(animated: Bool) {
        self.contentGridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ShareControllerPeerGridItemNode {
                itemNode.updateSelection(animated: animated)
            }
        }
    }
}
