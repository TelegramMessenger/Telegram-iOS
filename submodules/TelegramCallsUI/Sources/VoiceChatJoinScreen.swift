import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AlertUI
import PresentationDataUtils
import PeerInfoUI
import ShareController
import AvatarNode
import UndoUI

public final class VoiceChatJoinScreen: ViewController {
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let peerId: PeerId
    private let invite: String?
    private var join: (CachedChannelData.ActiveCall) -> Void
    
    private var presentationData: PresentationData
    
    private let disposable = MetaDisposable()
    
    public init(context: AccountContext, peerId: PeerId, invite: String?, join: @escaping (CachedChannelData.ActiveCall) -> Void) {
        self.context = context
        self.peerId = peerId
        self.invite = invite
        self.join = join
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, asSpeaker: self.invite != nil)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.join = { [weak self] call in
            self?.dismiss()
            self?.join(call)
        }
        self.displayNodeDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        let invite = self.invite
        let signal = context.engine.calls.updatedCurrentPeerGroupCall(peerId: peerId)
        |> castError(GetCurrentGroupCallError.self)
        |> mapToSignal { call -> Signal<(Peer, GroupCallSummary)?, GetCurrentGroupCallError> in
            if let call = call {
                let peer = context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                }
                |> castError(GetCurrentGroupCallError.self)
                return combineLatest(peer, context.engine.calls.getCurrentGroupCall(callId: call.id, accessHash: call.accessHash))
                |> map { peer, call -> (Peer, GroupCallSummary)? in
                    if let peer = peer, let call = call {
                        return (peer, call)
                    } else {
                        return nil
                    }
                }
            } else {
                return .single(nil)
            }
        }
        
        let cachedData = context.account.postbox.transaction { transaction -> CachedPeerData? in
            return transaction.getPeerCachedData(peerId: peerId)
        }
        |> castError(GetCurrentGroupCallError.self)
        
        let currentGroupCall: Signal<(PresentationGroupCall, Int64, Bool)?, GetCurrentGroupCallError>
        if let callManager = context.sharedContext.callManager {
            currentGroupCall = callManager.currentGroupCallSignal
            |> castError(GetCurrentGroupCallError.self)
            |> mapToSignal { call -> Signal<(PresentationGroupCall, Int64, Bool)?, GetCurrentGroupCallError> in
                if let call = call {
                    return call.summaryState
                    |> castError(GetCurrentGroupCallError.self)
                    |> map { state -> (PresentationGroupCall, Int64, Bool)? in
                        if let state = state, let info = state.info {
                            return (call, info.id, state.callState.muteState?.canUnmute ?? true)
                        } else {
                            return nil
                        }
                    }
                    |> filter { value in
                        return value != nil
                    }
                } else {
                    return .single(nil)
                }
            }
            |> take(1)
        } else {
            currentGroupCall = .single(nil)
        }
            
        self.disposable.set(combineLatest(queue: Queue.mainQueue(), signal, context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId) |> castError(GetCurrentGroupCallError.self), cachedData, currentGroupCall).start(next: { [weak self] peerAndCall, availablePeers, cachedData, currentGroupCallIdAndCanUnmute in
            if let strongSelf = self {
                if let (peer, call) = peerAndCall {
                    if let (currentGroupCall, currentGroupCallId, canUnmute) = currentGroupCallIdAndCanUnmute, call.info.id == currentGroupCallId {
                        strongSelf.dismiss()
                        
                        if let invite = invite, !canUnmute {
                            currentGroupCall.reconnect(with: invite)
                        }
                        strongSelf.context.sharedContext.navigateToCurrentCall()
                        return
                    }
                    
                    var defaultJoinAsPeerId: PeerId?
                    if let cachedData = cachedData as? CachedChannelData {
                        defaultJoinAsPeerId = cachedData.callJoinPeerId
                    } else if let cachedData = cachedData as? CachedGroupData {
                        defaultJoinAsPeerId = cachedData.callJoinPeerId
                    }
                    
                    let activeCall = CachedChannelData.ActiveCall(id: call.info.id, accessHash: call.info.accessHash, title: call.info.title, scheduleTimestamp: call.info.scheduleTimestamp, subscribedToScheduled: call.info.subscribedToScheduled, isStream: call.info.isStream)
                    if availablePeers.count > 0 && defaultJoinAsPeerId == nil {
                        strongSelf.dismiss()
                        strongSelf.join(activeCall)
                    } else {
                        strongSelf.controllerNode.setPeer(call: activeCall, peer: peer, title: call.info.title, memberCount: call.info.participantCount, isStream: call.info.isStream)
                    }
                } else {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .linkRevoked(text: presentationData.strings.InviteLinks_InviteLinkExpired), elevatedLayout: true, animateInAsReplacement: true, action: { _ in return false }), in: .window(.root))
                    strongSelf.dismiss()
                }
            }
        }))

        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    class Node: ViewControllerTracingNode, UIScrollViewDelegate {
        private let context: AccountContext
        private var presentationData: PresentationData
        private let asSpeaker: Bool
        
        private var call: CachedChannelData.ActiveCall?
        
        private let requestLayout: (ContainedViewLayoutTransition) -> Void
        
        private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
        
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
        private let actionSeparatorNode: ASDisplayNode
        
        var dismiss: (() -> Void)?
        var cancel: (() -> Void)?
        var join: ((CachedChannelData.ActiveCall) -> Void)?
        
        let ready = Promise<Bool>()
        private var didSetReady = false
        
        private var scheduledLayoutTransitionRequestId: Int = 0
        private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
        
        private let disposable = MetaDisposable()
        
        init(context: AccountContext, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void, asSpeaker: Bool) {
            self.context = context
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.asSpeaker = asSpeaker
            self.requestLayout = requestLayout
            
            let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
            let highlightedRoundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor)
            
            let theme = self.presentationData.theme
            let halfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
                context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
            })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 1)
            
            let highlightedHalfRoundedBackground = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.actionSheet.opaqueItemHighlightedBackgroundColor.cgColor)
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
            
            self.actionButtonNode = ShareActionButtonNode(badgeBackgroundColor: self.presentationData.theme.actionSheet.controlAccentColor, badgeTextColor: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
            self.actionButtonNode.displaysAsynchronously = false
            self.actionButtonNode.titleNode.displaysAsynchronously = false
            self.actionButtonNode.setBackgroundImage(highlightedHalfRoundedBackground, for: .highlighted)
            
            self.actionSeparatorNode = ASDisplayNode()
            self.actionSeparatorNode.isLayerBacked = true
            self.actionSeparatorNode.displaysAsynchronously = false
            self.actionSeparatorNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemSeparatorColor
            
            super.init()
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            self.addSubnode(self.dimNode)
            
            self.wrappingScrollNode.view.delegate = self
            self.addSubnode(self.wrappingScrollNode)
            
            self.cancelButtonNode.setTitle(self.presentationData.strings.Common_Cancel, with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
            
            self.wrappingScrollNode.addSubnode(self.cancelButtonNode)
            self.cancelButtonNode.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
            
            self.actionButtonNode.addTarget(self, action: #selector(self.installActionButtonPressed), forControlEvents: .touchUpInside)
            
            self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
            
            self.wrappingScrollNode.addSubnode(self.contentContainerNode)
            self.contentContainerNode.addSubnode(self.actionSeparatorNode)
            self.contentContainerNode.addSubnode(self.actionsBackgroundNode)
            self.contentContainerNode.addSubnode(self.actionButtonNode)
            
            self.transitionToContentNode(ShareLoadingContainerNode(theme: theme, forceNativeAppearance: false))
            
            self.actionButtonNode.alpha = 0.0
            self.actionSeparatorNode.alpha = 0.0
            self.actionsBackgroundNode.alpha = 0.0
            
            self.ready.set(.single(true))
            self.didSetReady = true
        }
        
        deinit {
            self.disposable.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
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
                
                if let (layout, navigationBarHeight, bottomGridInset) = self.containerLayout {
                    if let contentNode = contentNode, let previous = previous {
                        contentNode.frame = previous.frame
                        contentNode.updateLayout(size: previous.bounds.size, isLandscape: layout.size.width > layout.size.height, bottomInset: bottomGridInset, transition: .immediate)
                        
                        contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                            self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                        })
                        self.contentContainerNode.insertSubnode(contentNode, at: 0)
                        
                        contentNode.alpha = 1.0
                        let animation = contentNode.layer.makeAnimation(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.35)
                        animation.fillMode = .both
                        if !fastOut {
                            animation.beginTime = CACurrentMediaTime() + 0.1
                        }
                        contentNode.layer.add(animation, forKey: "opacity")
                        
                        self.animateContentNodeOffsetFromBackgroundOffset = self.contentBackgroundNode.frame.minY
                        self.scheduleInteractiveTransition(transition)
                        
                        contentNode.activate()
                        previous.deactivate()
                    } else {
                        if let contentNode = self.contentNode {
                            contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                                self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                            })
                            self.contentContainerNode.insertSubnode(contentNode, at: 0)
                        }
                        
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                    }
                } else if let contentNode = contentNode {
                    contentNode.setContentOffsetUpdated({ [weak self] contentOffset, transition in
                        self?.contentNodeOffsetUpdated(contentOffset, transition: transition)
                    })
                    self.contentContainerNode.insertSubnode(contentNode, at: 0)
                }
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            var insets = layout.insets(options: [.statusBar, .input])
            let cleanInsets = layout.insets(options: [.statusBar])
            insets.top = max(10.0, insets.top)
            
            var bottomInset: CGFloat = 10.0 + cleanInsets.bottom
            if insets.bottom > 0 {
                bottomInset -= 12.0
            }
            let buttonHeight: CGFloat = 57.0
            let sectionSpacing: CGFloat = 8.0
            let titleAreaHeight: CGFloat = 64.0
            
            let maximumContentHeight = layout.size.height - insets.top - max(bottomInset + buttonHeight, insets.bottom) - sectionSpacing
            
            let width = min(layout.size.width, layout.size.height) - 20.0
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
            let contentFrame = contentContainerFrame.insetBy(dx: 0.0, dy: 0.0)
            
            let bottomGridInset = buttonHeight
            
            self.containerLayout = (layout, navigationBarHeight, bottomGridInset)
            self.scheduledLayoutTransitionRequest = nil
            
            transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
            
            transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
            
            transition.updateFrame(node: self.actionsBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset), size: CGSize(width: contentContainerFrame.size.width, height: bottomGridInset)))
            
            transition.updateFrame(node: self.actionButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - buttonHeight), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
            
            transition.updateFrame(node: self.actionSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - bottomGridInset - UIScreenPixel), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
            
            let gridSize = CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height - titleAreaHeight))
            
            if let contentNode = self.contentNode {
                transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: gridSize))
                contentNode.updateLayout(size: gridSize, isLandscape: layout.size.width > layout.size.height, bottomInset: bottomGridInset, transition: transition)
            }
        }
        
        private func contentNodeOffsetUpdated(_ contentOffset: CGFloat, transition: ContainedViewLayoutTransition) {
            if let (layout, _, _) = self.containerLayout {
                var insets = layout.insets(options: [.statusBar, .input])
                insets.top = max(10.0, insets.top)
                let cleanInsets = layout.insets(options: [.statusBar])
                
                var bottomInset: CGFloat = 10.0 + cleanInsets.bottom
                if insets.bottom > 0 {
                    bottomInset -= 12.0
                }
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
                        transition.animatePositionAdditive(node: contentNode, offset: CGPoint(x: 0.0, y: -offset))
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
            if let call = self.call {
                self.join?(call)
            }
        }
        
        func animateIn() {
            if self.contentNode != nil {
                self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
                
                let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
                let dimPosition = self.dimNode.layer.position
                
                let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                let targetBounds = self.bounds
                self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
                self.dimNode.position = CGPoint(x: dimPosition.x, y: dimPosition.y - offset)
                transition.animateView({
                    self.bounds = targetBounds
                    self.dimNode.position = dimPosition
                })
            }
        }
        
        private var animatingOut = false
        func animateOut(completion: (() -> Void)? = nil) {
            guard !self.animatingOut else {
                return
            }
            self.animatingOut = true
            
            if self.contentNode != nil {
                var dimCompleted = false
                var offsetCompleted = false
                
                let internalCompletion: () -> Void = { [weak self] in
                    if let strongSelf = self, dimCompleted && offsetCompleted {
                        strongSelf.animatingOut = false
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
            } else {
                self.dismiss?()
                completion?()
            }
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
        
        func transitionToProgress(signal: Signal<Void, NoError>) {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.12, curve: .easeInOut)
            transition.updateAlpha(node: self.actionButtonNode, alpha: 0.0)
            transition.updateAlpha(node: self.actionSeparatorNode, alpha: 0.0)
            transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 0.0)
            
            self.transitionToContentNode(ShareLoadingContainerNode(theme: self.presentationData.theme, forceNativeAppearance: false), fastOut: true)
            let timestamp = CACurrentMediaTime()
            self.disposable.set(signal.start(completed: { [weak self] in
                let minDelay = 0.6
                let delay = max(0.0, (timestamp + minDelay) - CACurrentMediaTime())
                Queue.mainQueue().after(delay, {
                    if let strongSelf = self {
                        strongSelf.cancel?()
                    }
                })
            }))
        }
        
        func setPeer(call: CachedChannelData.ActiveCall, peer: Peer, title: String?, memberCount: Int, isStream: Bool) {
            self.call = call
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.22, curve: .easeInOut)
            transition.updateAlpha(node: self.actionButtonNode, alpha: 1.0)
            transition.updateAlpha(node: self.actionSeparatorNode, alpha: 1.0)
            transition.updateAlpha(node: self.actionsBackgroundNode, alpha: 1.0)
            
            self.actionButtonNode.isEnabled = true
            self.actionButtonNode.setTitle(self.asSpeaker ? self.presentationData.strings.Invitation_JoinVoiceChatAsSpeaker : self.presentationData.strings.Invitation_JoinVoiceChatAsListener, with: Font.medium(20.0), with: self.presentationData.theme.actionSheet.standardActionTextColor, for: .normal)
            
            self.transitionToContentNode(VoiceChatPreviewContentNode(context: self.context, peer: peer, title: title, memberCount: memberCount, isStream: isStream, theme: self.presentationData.theme, strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder))
        }
    }
}

private let avatarFont = avatarPlaceholderFont(size: 26.0)

final class VoiceChatPreviewContentNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let countNode: ImmediateTextNode
    
    init(context: AccountContext, peer: Peer, title: String?, memberCount: Int, isStream: Bool, theme: PresentationTheme, strings: PresentationStrings, displayOrder: PresentationPersonNameOrder) {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 4
        self.titleNode.textAlignment = .center
        
        self.countNode = ImmediateTextNode()
        self.countNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer), emptyColor: theme.list.mediaPlaceholderColor)
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: title ?? EnginePeer(peer).displayTitle(strings: strings, displayOrder: displayOrder), font: Font.semibold(16.0), textColor: theme.actionSheet.primaryTextColor)
        
        self.addSubnode(self.countNode)

        self.countNode.isHidden = memberCount == 0
        let text: String
        if isStream {
            text = memberCount == 0 ? "" : strings.LiveStream_ViewerCount(Int32(memberCount))
        } else {
            text = memberCount == 0 ? "" : strings.VoiceChat_Panel_Members(Int32(memberCount))
        }
        self.countNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: theme.actionSheet.secondaryTextColor)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 16.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0, height: size.height))
        let countSize = self.countNode.updateLayout(CGSize(width: size.width - sideInset * 2.0, height: size.height))
        
        var nodeHeight: CGFloat = 185.0 + titleSize.height
        if !self.countNode.isHidden {
            nodeHeight += 20.0
        }
        
        let verticalOrigin = size.height - nodeHeight
        let avatarSize: CGFloat = 75.0

        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: floor((size.width - avatarSize) / 2.0), y: verticalOrigin + 22.0), size: CGSize(width: avatarSize, height: avatarSize)))
                
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: verticalOrigin + 22.0 + avatarSize + 15.0), size: titleSize))
    
        transition.updateFrame(node: self.countNode, frame: CGRect(origin: CGPoint(x: floor((size.width - countSize.width) / 2.0), y: verticalOrigin + 22.0 + avatarSize + 15.0 + titleSize.height + 1.0), size: countSize))
        
        self.contentOffsetUpdated?(-size.height + nodeHeight - 64.0, transition)
    }
    
    func updateSelectedPeers() {
    }
}
