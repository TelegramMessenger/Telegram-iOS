import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

final class ShareControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let account: Account
    private var presentationData: PresentationData
    private let externalShare: Bool
    
    private let defaultAction: ShareControllerAction?
    private let requestLayout: (ContainedViewLayoutTransition) -> Void
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let dimNode: ASDisplayNode
    
    private let wrappingScrollNode: ASScrollNode
    private let cancelButtonNode: ASButtonNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASImageNode
    
    private var contentNode: (ASDisplayNode & ShareContentContainerNode)?
    private var previousContentNode: (ASDisplayNode & ShareContentContainerNode)?
    private var animateContentNodeOffsetFromBackgroundOffset: CGFloat?
    
    private let actionsBackgroundNode: ASImageNode
    private let actionButtonNode: ShareActionButtonNode
    private let inputFieldNode: ShareInputFieldNode
    private let actionSeparatorNode: ASDisplayNode
    
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    var share: ((String, [PeerId]) -> Signal<Void, NoError>)?
    var shareExternal: (() -> Void)?
    
    let ready = Promise<Bool>()
    private var didSetReady = false
    
    private var controllerInteraction: ShareControllerInteraction?
    
    private var peersContentNode: SharePeersContainerNode?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private let shareDisposable = MetaDisposable()
    
    init(account: Account, defaultAction: ShareControllerAction?, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void, externalShare: Bool) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.externalShare = externalShare
        
        self.defaultAction = defaultAction
        self.requestLayout = requestLayout
        
        let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: .white)
        let highlightedRoundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: UIColor(white: 0.9, alpha: 1.0))
        
        let halfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
        let highlightedHalfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor(white: 0.9, alpha: 1.0).cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
        
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
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        self.contentContainerNode.clipsToBounds = true
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.image = roundedBackground
        
        self.actionsBackgroundNode = ASImageNode()
        self.actionsBackgroundNode.isLayerBacked = true
        self.actionsBackgroundNode.displayWithoutProcessing = true
        self.actionsBackgroundNode.displaysAsynchronously = false
        self.actionsBackgroundNode.image = halfRoundedBackground
        
        self.actionButtonNode = ShareActionButtonNode()
        self.actionButtonNode.displaysAsynchronously = false
        self.actionButtonNode.titleNode.displaysAsynchronously = false
        self.actionButtonNode.setBackgroundImage(highlightedHalfRoundedBackground, for: .highlighted)
        
        self.inputFieldNode = ShareInputFieldNode(placeholder: self.presentationData.strings.ShareMenu_Comment)
        self.inputFieldNode.alpha = 0.0
        
        self.actionSeparatorNode = ASDisplayNode()
        self.actionSeparatorNode.isLayerBacked = true
        self.actionSeparatorNode.displaysAsynchronously = false
        self.actionSeparatorNode.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        
        super.init()
        
        self.controllerInteraction = ShareControllerInteraction(togglePeer: { [weak self] peer in
            if let strongSelf = self {
                if strongSelf.controllerInteraction!.selectedPeerIds.contains(peer.id) {
                    strongSelf.controllerInteraction!.selectedPeerIds.remove(peer.id)
                    strongSelf.controllerInteraction!.selectedPeers = strongSelf.controllerInteraction!.selectedPeers.filter({ $0.id != peer.id })
                } else {
                    strongSelf.controllerInteraction!.selectedPeerIds.insert(peer.id)
                    strongSelf.controllerInteraction!.selectedPeers.append(peer)
                    
                    strongSelf.contentNode?.setEnsurePeerVisibleOnLayout(peer.id)
                }
                
                let inputNodeAlpha: CGFloat = strongSelf.controllerInteraction!.selectedPeers.isEmpty ? 0.0 : 1.0
                if !strongSelf.inputFieldNode.alpha.isEqual(to: inputNodeAlpha) {
                    let previousAlpha = strongSelf.inputFieldNode.alpha
                    strongSelf.inputFieldNode.alpha = inputNodeAlpha
                    strongSelf.inputFieldNode.layer.animateAlpha(from: previousAlpha, to: inputNodeAlpha, duration: inputNodeAlpha.isZero ? 0.18 : 0.32)
                    
                    if inputNodeAlpha.isZero {
                        strongSelf.inputFieldNode.deactivateInput()
                    }
                }
                
                strongSelf.updateButton()
                
                strongSelf.contentNode?.updateSelectedPeers()
                
                if let (layout, navigationBarHeight) = strongSelf.containerLayout {
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
        
        self.cancelButtonNode.setTitle(self.presentationData.strings.Common_Cancel, with: Font.medium(20.0), with: UIColor(rgb: 0x007ee5), for: .normal)
        
        self.wrappingScrollNode.addSubnode(self.cancelButtonNode)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        
        self.actionButtonNode.addTarget(self, action: #selector(self.installActionButtonPressed), forControlEvents: .touchUpInside)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.actionSeparatorNode)
        self.contentContainerNode.addSubnode(self.actionsBackgroundNode)
        self.contentContainerNode.addSubnode(self.actionButtonNode)
        self.contentContainerNode.addSubnode(self.inputFieldNode)
        
        self.inputFieldNode.updateHeight = { [weak self] in
            if let strongSelf = self {
                if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.15, curve: .spring))
                }
            }
        }
        
        self.updateButton()
    }
    
    deinit {
        self.shareDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    func transitionToContentNode(_ contentNode: (ASDisplayNode & ShareContentContainerNode)?, fastOut: Bool = false) {
        if self.contentNode !== contentNode {
            let transition: ContainedViewLayoutTransition
            
            let previous = self.contentNode
            if let previous = previous {
                previous.setContentOffsetUpdated(nil)
                transition = .animated(duration: 0.4, curve: .spring)
                
                self.previousContentNode = previous
                previous.alpha = 0.0
                previous.layer.animateAlpha(from: 1.0, to: 0.0, duration: fastOut ? 0.1 : 0.2, removeOnCompletion: true, completion: { [weak self, weak previous] _ in
                    if let strongSelf = self, let previous = previous {
                        if strongSelf.previousContentNode === previous {
                            strongSelf.previousContentNode = nil
                        }
                        previous.removeFromSupernode()
                    }
                })
            } else {
                transition = .immediate
            }
            self.contentNode = contentNode
            if let contentNode = contentNode {
                contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                    self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                })
                self.contentContainerNode.insertSubnode(contentNode, at: 0)
            }
            
            if let (layout, navigationBarHeight) = self.containerLayout {
                if let contentNode = contentNode, let previous = previous {
                    contentNode.alpha = 1.0
                    let animation = contentNode.layer.makeAnimation(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: 0.35)
                    animation.fillMode = kCAFillModeBoth
                    if !fastOut {
                        animation.beginTime = CACurrentMediaTime() + 0.1
                    }
                    contentNode.layer.add(animation, forKey: "opacity")
                    
                    contentNode.frame = previous.frame
                    var bottomGridInset: CGFloat = 57.0
                    
                    let inputHeight = self.inputFieldNode.bounds.size.height
                    
                    if !self.controllerInteraction!.selectedPeers.isEmpty {
                        bottomGridInset += inputHeight
                    }
                    self.animateContentNodeOffsetFromBackgroundOffset = self.contentBackgroundNode.frame.minY
                    self.scheduleInteractiveTransition(transition)
                    contentNode.activate()
                    previous.deactivate()
                    //self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                } else {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                }
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        self.scheduledLayoutTransitionRequest = nil
        
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insets = layout.insets(options: [.statusBar, .input])
        insets.top = max(10.0, insets.top)
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let bottomInset: CGFloat = 10.0
        let buttonHeight: CGFloat = 57.0
        let sectionSpacing: CGFloat = 8.0
        let titleAreaHeight: CGFloat = 64.0
        
        let width = min(layout.size.width, layout.size.height) - 20.0
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
        
        let maximumContentHeight = layout.size.height - insets.top - max(bottomInset + buttonHeight, insets.bottom) - sectionSpacing
        
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
        let contentFrame = contentContainerFrame.insetBy(dx: 0.0, dy: 0.0)
        
        var bottomGridInset = buttonHeight
        
        let inputHeight = self.inputFieldNode.updateLayout(width: contentContainerFrame.size.width, transition: transition)
        
        if !self.controllerInteraction!.selectedPeers.isEmpty {
            bottomGridInset += inputHeight
        }
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        
        transition.updateFrame(node: self.actionsBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset), size: CGSize(width: contentContainerFrame.size.width, height: bottomGridInset)))
        
        transition.updateFrame(node: self.actionButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - buttonHeight), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
        
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset), size: CGSize(width: contentContainerFrame.size.width, height: inputHeight)))
        
        transition.updateFrame(node: self.actionSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset - UIScreenPixel), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
        
        let gridSize = CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height - titleAreaHeight))
        
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: gridSize))
            contentNode.updateLayout(size: gridSize, bottomInset: bottomGridInset, transition: transition)
        }
    }
    
    private func contentNodeOffsetUpdated(_ contentOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        if let (layout, _) = self.containerLayout {
            var insets = layout.insets(options: [.statusBar, .input])
            insets.top = max(10.0, insets.top)
            
            let bottomInset: CGFloat = 10.0
            let buttonHeight: CGFloat = 57.0
            let sectionSpacing: CGFloat = 8.0
            
            let width = min(layout.size.width, layout.size.height) - 20.0
            
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let maximumContentHeight = layout.size.height - insets.top - max(bottomInset + buttonHeight, insets.bottom) - sectionSpacing
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
            
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY - contentOffset), size: contentFrame.size)
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
            transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
            
            if let animateContentNodeOffsetFromBackgroundOffset = self.animateContentNodeOffsetFromBackgroundOffset {
                self.animateContentNodeOffsetFromBackgroundOffset = nil
                let offset = backgroundFrame.minY - animateContentNodeOffsetFromBackgroundOffset
                if let contentNode = self.contentNode {
                    transition.animatePositionAdditive(node: contentNode, offset: -offset)
                }
                if let previousContentNode = self.previousContentNode {
                    transition.updatePosition(node: previousContentNode, position: previousContentNode.position.offsetBy(dx: 0.0, dy: offset))
                }
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
        if self.controllerInteraction!.selectedPeers.isEmpty {
            if let defaultAction = self.defaultAction {
                defaultAction.action()
            }
        } else {
            self.inputFieldNode.deactivateInput()
            let transition = ContainedViewLayoutTransition.animated(duration: 0.12, curve: .easeInOut)
            transition.updateAlpha(node: self.actionButtonNode, alpha: 0.0)
            transition.updateAlpha(node: self.inputFieldNode, alpha: 0.0)
            transition.updateAlpha(node: self.actionSeparatorNode, alpha: 0.0)
            transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 0.0)
            
            if let signal = self.share?(self.inputFieldNode.text, self.controllerInteraction!.selectedPeers.map { $0.id }) {
                self.transitionToContentNode(ShareLoadingContainerNode(), fastOut: true)
                let timestamp = CACurrentMediaTime()
                self.shareDisposable.set(signal.start(completed: { [weak self] in
                    let minDelay = 1.2
                    let delay = max(0.0, (timestamp + minDelay) - CACurrentMediaTime())
                    Queue.mainQueue().after(delay, {
                        if let strongSelf = self {
                            strongSelf.cancel?()
                        }
                    })
                }))
            }
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
        self.ready.set(.single(true))
        
        let peersContentNode = SharePeersContainerNode(account: self.account, strings: self.presentationData.strings, peers: peers, controllerInteraction: self.controllerInteraction!, externalShare: false && self.externalShare)
        self.peersContentNode = peersContentNode
        peersContentNode.openSearch = { [weak self] in
            if let strongSelf = self {
                let _ = (recentlySearchedPeers(postbox: strongSelf.account.postbox)
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { peers in
                        if let strongSelf = self {
                            let searchContentNode = ShareSearchContainerNode(account: strongSelf.account, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, controllerInteraction: strongSelf.controllerInteraction!, recentPeers: peers)
                            searchContentNode.cancel = {
                                if let strongSelf = self, let peersContentNode = strongSelf.peersContentNode {
                                    strongSelf.transitionToContentNode(peersContentNode)
                                }
                            }
                            strongSelf.transitionToContentNode(searchContentNode)
                        }
                    })
            }
        }
        peersContentNode.openShare = { [weak self] in
            self?.shareExternal?()
        }
        self.transitionToContentNode(peersContentNode)
        
        /*self.defaultAction = defaultAction
        
        self.peersContainerNode.peers = peers
        self.peersUpdated = true
        if let _ = self.containerLayout {
            self.dequeueUpdatePeers()
        }
        
        self.actionSeparatorNode.alpha = 1.0
        
        if let defaultAction = defaultAction {
            self.actionButtonNode.setTitle(defaultAction.title, with: Font.regular(20.0), with: UIColor(rgb: 0x007ee5), for: .normal)
        } else {
            self.actionButtonNode.setTitle(self.presentationData.strings.ShareMenu_Send, with: Font.medium(20.0), with: .gray, for: .normal)
        }*/
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.actionButtonNode.hitTest(self.actionButtonNode.convert(point, from: self), with: event) {
            return result
        }
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) && !self.cancelButtonNode.bounds.contains(self.convert(point, to: self.cancelButtonNode)) {
                return self.dimNode.view
            }
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
    
    private func scheduleInteractiveTransition(_ transition: ContainedViewLayoutTransition) {
        if let scheduledLayoutTransitionRequest = self.scheduledLayoutTransitionRequest {
            switch scheduledLayoutTransitionRequest.1 {
                case .immediate:
                    self.scheduleLayoutTransitionRequest(transition)
                default:
                    break
            }
        } else {
            self.scheduleLayoutTransitionRequest(transition)
        }
    }
    
    private func scheduleLayoutTransitionRequest(_ transition: ContainedViewLayoutTransition) {
        let requestId = self.scheduledLayoutTransitionRequestId
        self.scheduledLayoutTransitionRequestId += 1
        self.scheduledLayoutTransitionRequest = (requestId, transition)
        (self.view as? UITracingLayerView)?.schedule(layout: { [weak self] in
            if let strongSelf = self {
                if let (currentRequestId, currentRequestTransition) = strongSelf.scheduledLayoutTransitionRequest, currentRequestId == requestId {
                    strongSelf.scheduledLayoutTransitionRequest = nil
                    strongSelf.requestLayout(currentRequestTransition)
                }
            }
        })
        self.setNeedsLayout()
    }
    
    private func updateButton() {
        if self.controllerInteraction!.selectedPeers.isEmpty {
            if let defaultAction = self.defaultAction {
                self.actionButtonNode.setTitle(defaultAction.title, with: Font.regular(20.0), with: UIColor(rgb: 0x007ee5), for: .normal)
            } else {
                self.actionButtonNode.setTitle(self.presentationData.strings.ShareMenu_Send, with: Font.medium(20.0), with: UIColor(rgb: 0x787878), for: .normal)
            }
            self.actionButtonNode.badge = nil
        } else {
            self.actionButtonNode.setTitle(self.presentationData.strings.ShareMenu_Send, with: Font.medium(20.0), with: UIColor(rgb: 0x007ee5), for: .normal)
            self.actionButtonNode.badge = "\(self.controllerInteraction!.selectedPeers.count)"
        }
    }
    
    func transitionToProgress(signal: Signal<Void, NoError>) {
        self.inputFieldNode.deactivateInput()
        let transition = ContainedViewLayoutTransition.animated(duration: 0.12, curve: .easeInOut)
        transition.updateAlpha(node: self.actionButtonNode, alpha: 0.0)
        transition.updateAlpha(node: self.inputFieldNode, alpha: 0.0)
        transition.updateAlpha(node: self.actionSeparatorNode, alpha: 0.0)
        transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 0.0)
        
        self.transitionToContentNode(ShareLoadingContainerNode(), fastOut: true)
        let timestamp = CACurrentMediaTime()
        self.shareDisposable.set(signal.start(completed: { [weak self] in
            let minDelay = 1.2
            let delay = max(0.0, (timestamp + minDelay) - CACurrentMediaTime())
            Queue.mainQueue().after(delay, {
                if let strongSelf = self {
                    strongSelf.cancel?()
                }
            })
        }))
    }
}
