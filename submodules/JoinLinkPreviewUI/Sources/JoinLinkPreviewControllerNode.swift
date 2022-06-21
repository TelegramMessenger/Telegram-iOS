import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ShareController

private func closeButtonImage(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: 0x808084, alpha: 0.1).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(theme.actionSheet.inputClearButtonColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

struct JoinLinkPreviewData {
    let isGroup: Bool
    let isJoined: Bool
}

final class JoinLinkPreviewControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let requestLayout: (ContainedViewLayoutTransition) -> Void
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    private let dimNode: ASDisplayNode
    
    private let wrappingScrollNode: ASScrollNode
    
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    
    private var contentNode: (ASDisplayNode & ShareContentContainerNode)?
    private var previousContentNode: (ASDisplayNode & ShareContentContainerNode)?
    private var animateContentNodeOffsetFromBackgroundOffset: CGFloat?
    
    private let cancelButton: HighlightableButtonNode
    
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    var join: (() -> Void)?
    
    let ready = Promise<Bool>()
    private var didSetReady = false
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private let disposable = MetaDisposable()
    
    init(context: AccountContext, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.context = context
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.requestLayout = requestLayout
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 16.0
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: presentationData.theme.actionSheet.backgroundType == .light ? .light : .dark))
        })
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.itemBackgroundColor
                
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setImage(closeButtonImage(theme: self.presentationData.theme), for: .normal)
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
                
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
                
        self.backgroundNode.addSubnode(self.effectNode)
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.wrappingScrollNode.addSubnode(self.cancelButton)
        
        self.transitionToContentNode(JoinLinkPreviewLoadingContainerNode(theme: self.presentationData.theme))
                
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
                    let animation = contentNode.layer.makeAnimation(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.25)
                    animation.fillMode = .both
                    if !fastOut {
                        animation.beginTime = CACurrentMediaTime() + 0.1
                    }
                    contentNode.layer.add(animation, forKey: "opacity")
                    
                    self.animateContentNodeOffsetFromBackgroundOffset = self.backgroundNode.frame.minY
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
        if insets.bottom > 0.0 {
            bottomInset -= 12.0
        }
        
        let maximumContentHeight = layout.size.height - insets.top - max(bottomInset, insets.bottom)
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
        let sideInset = floor((layout.size.width - width) / 2.0)
        
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
        let contentFrame = contentContainerFrame
                
        self.containerLayout = (layout, navigationBarHeight, 0.0)
        self.scheduledLayoutTransitionRequest = nil
        
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
                
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        
        let gridSize = CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height))
        
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: 0.0), size: gridSize))
            contentNode.updateLayout(size: gridSize, isLandscape: layout.size.width > layout.size.height, bottomInset: 0.0, transition: transition)
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
            
            let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let maximumContentHeight = layout.size.height - insets.top - max(bottomInset, insets.bottom)
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
            
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY - contentOffset), size: contentFrame.size)
            if backgroundFrame.minY < contentFrame.minY {
                backgroundFrame.origin.y = contentFrame.minY
            }
            if backgroundFrame.maxY > contentFrame.maxY {
                backgroundFrame.size.height += contentFrame.maxY - backgroundFrame.maxY
            }
            backgroundFrame.size.height += 2000.0

            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            let cancelSize = CGSize(width: 44.0, height: 44.0)
            let cancelFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - cancelSize.width - 3.0, y: backgroundFrame.minY + 6.0), size: cancelSize)
            transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
            
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
    
    func animateIn() {
        if self.contentNode != nil {
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            
            let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
            
            let dimPosition = self.dimNode.layer.position
            self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
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
                    strongSelf.dismiss?()
                    strongSelf.animatingOut = true
                }
                completion?()
            }
            
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                dimCompleted = true
                internalCompletion()
            })
            
            let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
            let dimPosition = self.dimNode.layer.position
            self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
            self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
                offsetCompleted = true
                internalCompletion()
            })
        } else {
            self.dismiss?()
            completion?()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) && !self.cancelButton.bounds.contains(self.convert(point, to: self.cancelButton)) {
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
    
    func setInvitePeer(image: TelegramMediaImageRepresentation?, title: String, memberCount: Int32, members: [EnginePeer], data: JoinLinkPreviewData) {
        let contentNode = JoinLinkPreviewPeerContentNode(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, content: .invite(isGroup: data.isGroup, image: image, title: title, memberCount: memberCount, members: members))
        contentNode.join = { [weak self] in
            self?.join?()
        }
        self.transitionToContentNode(contentNode)
    }
    
    func setRequestPeer(image: TelegramMediaImageRepresentation?, title: String, about: String?, memberCount: Int32, isGroup: Bool) {
        let contentNode = JoinLinkPreviewPeerContentNode(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, content: .request(isGroup: isGroup, image: image, title: title, about: about, memberCount: memberCount))
        contentNode.join = { [weak self] in
            self?.join?()
        }
        self.transitionToContentNode(contentNode)
    }
}
