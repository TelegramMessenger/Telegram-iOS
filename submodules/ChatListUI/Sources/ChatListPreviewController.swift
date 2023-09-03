//
//  ChatListPreviewController.swift
//  ChatListUI
//
//  Created by Bogdan Redkin on 02/09/2023.
//

import AccountContext
import AsyncDisplayKit
import ChatAvatarNavigationNode
import ChatTitleView
import ContextUI
import Display
import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import UIKit

final class ChatListPreviewContentContainerNode: ASDisplayNode {
    public var controllerNode: ContextControllerContentNode?

    override public init() {
        super.init()
    }

    public func updateLayout(size: CGSize, scaledSize: CGSize, transition: ContainedViewLayoutTransition) {
        guard let contentNode = self.controllerNode else { return }
        transition.updatePosition(node: contentNode, position: CGPoint(x: scaledSize.width / 2.0, y: scaledSize.height / 2.0))
        transition.updateBounds(node: contentNode, bounds: CGRect(origin: CGPoint(), size: size))
        transition.updateTransformScale(node: contentNode, scale: scaledSize.width / size.width)
        contentNode.updateLayout(size: size, transition: transition)
        contentNode.controller.containerLayoutUpdated(
            ContainerViewLayout(
                size: size,
                metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact),
                deviceMetrics: .iPhoneX,
                intrinsicInsets: UIEdgeInsets(),
                safeInsets: UIEdgeInsets(),
                additionalInsets: UIEdgeInsets(),
                statusBarHeight: nil,
                inputHeight: nil,
                inputHeightIsInteractivellyChanging: false,
                inVoiceOver: false
            ),
            transition: transition
        )
    }
}

func convertFrame(_ frame: CGRect, from fromView: UIView, to toView: UIView) -> CGRect {
    let sourceWindowFrame = fromView.convert(frame, to: nil)
    var targetWindowFrame = toView.convert(sourceWindowFrame, from: nil)

    if let fromWindow = fromView.window, let toWindow = toView.window {
        targetWindowFrame.origin.x += toWindow.bounds.width - fromWindow.bounds.width
    }
    return targetWindowFrame
}

final class ChatListPreviewControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let presentationData: PresentationData

    private var validLayout: ContainerViewLayout?

    private let effectView: UIVisualEffectView
    private var propertyAnimator: AnyObject?
    private var displayLinkAnimator: DisplayLinkAnimator?
    private let dimNode: ASDisplayNode
    private let withoutBlurDimNode: ASDisplayNode
    private let dismissNode: ASDisplayNode
    private let dismissAccessibilityArea: AccessibilityAreaNode
    private let clippingNode: ASDisplayNode
    private let scrollNode: ASScrollNode

    private var originalProjectedContentViewFrame: (CGRect, CGRect)?
//    private var contentAreaInScreenSpace: CGRect?
//    private var customPosition: CGPoint?
    private let contentContainerNode: ChatListPreviewContentContainerNode
    private weak var gesture: ContextGesture?

    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?

    private var animatedIn = false
    private var isAnimatingOut = false
    private var didCompleteAnimationIn = false

    var presentationArguments: ChatListPreviewPresentationData?
    var controller: ViewController?

    init(context: AccountContext, gesture: ContextGesture?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.gesture = gesture

        self.effectView = UIVisualEffectView()
        if #available(iOS 9.0, *) {
        } else {
            if presentationData.theme.rootController.keyboardColor == .dark {
                self.effectView.effect = UIBlurEffect(style: .dark)
            } else {
                self.effectView.effect = UIBlurEffect(style: .light)
            }
            self.effectView.alpha = 0.0
        }

        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = presentationData.theme.contextMenu.dimColor
        self.dimNode.alpha = 0.0

        self.withoutBlurDimNode = ASDisplayNode()
        self.withoutBlurDimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        self.withoutBlurDimNode.alpha = 0.0

        self.dismissNode = ASDisplayNode()
        self.dismissAccessibilityArea = AccessibilityAreaNode()
        self.dismissAccessibilityArea.accessibilityLabel = presentationData.strings.VoiceOver_DismissContextMenu
        self.dismissAccessibilityArea.accessibilityTraits = .button

        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true

        self.scrollNode = ASScrollNode()
        self.scrollNode.canCancelAllTouchesInViews = true
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }

        self.contentContainerNode = ChatListPreviewContentContainerNode()

        super.init()
        self.scrollNode.view.delegate = self

        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        self.addSubnode(self.withoutBlurDimNode)

        self.addSubnode(self.clippingNode)

        self.clippingNode.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.dismissNode)
        self.scrollNode.addSubnode(self.dismissAccessibilityArea)

        self.initializeContent()

        self.dismissAccessibilityArea.activate = { [weak self] in
            self?.dimNodeTapped()
            return true
        }
    }

    deinit {
        if let propertyAnimator = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
        }
    }

    override func didLoad() {
        super.didLoad()

        self.dismissNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTapped)))
    }

    @objc private func dimNodeTapped() {
        guard self.animatedIn else {
            return
        }
        self.cancel?()
    }

    func initializeContent() {
        guard
            let presentationArguments,
            let controller,
            let (sourceNode, sourceNodeRect) = presentationArguments.sourceNodeAndRect()
        else { return }

        let controlleContentrNode = ContextControllerContentNode(sourceView: sourceNode.view, controller: controller, tapped: {
            print("tapped")
        })

        self.contentContainerNode.controllerNode = controlleContentrNode
        self.scrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.clipsToBounds = true
        self.contentContainerNode.cornerRadius = 14.0
        self.contentContainerNode.addSubnode(controlleContentrNode)

        let projectedFrame = convertFrame(sourceNodeRect, from: sourceNode.view, to: self.view)
        self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
    }

    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }

    func animateIn() {
        self.gesture?.endPressedAppearance()
//        guard
//            let tp = transitionParams
//        else { return }
//        let sourceTitleSnapshot = transitionParams.sourceTitleSnapshot
//        let sourceChatItemSnapshot = tp.sourceChatItemSnapshot
//        let sourceAvatarSnapshot = transitionParams.sourceAvatarSnapshot

        if let validLayout = self.validLayout {
            self.updateLayout(validLayout, transition: .immediate)
        }

        if !self.dimNode.isHidden {
            self.dimNode.alpha = 1.0
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        } else {
            self.withoutBlurDimNode.alpha = 1.0
            self.withoutBlurDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
//
//        if let propertyAnimator = self.propertyAnimator {
//            let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
//            propertyAnimator?.stopAnimation(true)
//        }
//        self.effectView.effect = makeCustomZoomBlurEffect(isLight: presentationData.theme.rootController.keyboardColor == .light)
//        self.effectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
//        self.propertyAnimator = UIViewPropertyAnimator(duration: 0.3 * UIView.animationDurationFactor(), curve: .easeInOut, animations: {
//        })
//

//        let springDuration: Double = 0.52
//        let springDamping: CGFloat = 110.0

//        self.contentContainerNode.allowsGroupOpacity = true
//        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 1.15, completion: { [weak self] _ in
//            self?.contentContainerNode.allowsGroupOpacity = false
//        })

//        sourceAvatarSnapshot.animateAlpha(from: 1.0, to: 0.0, duration: 1.15)
//        sourceChatItemSnapshot.animateAlpha(from: 1.0, to: 0.0, duration: 1.15)

        if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame {
            let localSourceFrame = self.view.convert(
                CGRect(
                    origin: CGPoint(
                        x: originalProjectedContentViewFrame.1.minX,
                        y: originalProjectedContentViewFrame.1.minY
                    ),
                    size: CGSize(
                        width: originalProjectedContentViewFrame.1.width,
                        height: originalProjectedContentViewFrame.1.height
                    )
                ),
                to: self.scrollNode.view
            )

            print("locate source frame: \(localSourceFrame) originalProjectedContentViewFrame: \(originalProjectedContentViewFrame)")

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                print("animation finsihed")
            }
            CATransaction.setAnimationDuration(0.5)

            if let _ = self.propertyAnimator {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 1.15 * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: { [weak self] in
                    self?.didCompleteAnimationIn = true
                })
            } else {
                UIView.animate(withDuration: 1.15, animations: {
                    self.effectView.effect = makeCustomZoomBlurEffect(isLight: self.presentationData.theme.rootController.keyboardColor == .light)
                }, completion: { [weak self] _ in
                    self?.didCompleteAnimationIn = true
                    //                self?.actionsContainerNode.animateIn()
                })
            }
            CATransaction.commit()
            //prepare variables to transition snapshots
            guard
                let controller = self.contentContainerNode.controllerNode,
                let (sourceNode, sourceFrame) = self.presentationArguments?.sourceNodeAndRect(),
                let contentArea = self.presentationArguments?.contentArea(),
                let sourceChatItem = sourceNode.supernode as? ChatListItemNode else { return }

            let titleNode = sourceChatItem.titleNode
            let titleSnapshot = titleNode.view.snapshotContentTree()
            let titleSourceframe = self.view.convert(titleNode.view.frame, from: titleNode.view)

            let avatarNode = sourceChatItem.avatarContainerNode
            let avatarSnapshot = avatarNode.view.snapshotContentTree()
            let avatarSourceFrame = self.view.convert(avatarNode.view.frame, from: avatarNode.view)

            titleNode.isHidden = true
            avatarNode.isHidden = true

            guard
                let chatSnapshot = sourceChatItem.view.snapshotContentTree(),
                let titleView = controller.controller.navigationItem.titleView as? ChatTitleView,
                let navigationBackgroundSnapshot = controller.controller.navigationBar?.layer.snapshotContentTree(),
                let titleSnapshot,
                let avatarSnapshot
            else {
                titleNode.isHidden = false
                avatarNode.isHidden = false
                return
            }

            titleNode.isHidden = false
            avatarNode.isHidden = false
            
            
            // snapshot transition and resize
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.35)

            let targeBgPosition = CGPoint(x: self.contentContainerNode.frame.midX, y: self.contentContainerNode.frame.minY + localSourceFrame.height / 2.0)
            _ = self.contentContainerNode.frame.size

            let sourceMessageFrameStart = self.view.convert(sourceFrame, from: titleView)

            let navigationFrameStart = sourceMessageFrameStart.insetBy(dx: .zero, dy: -15)
            //                let contentViewFrame = originalProjectedContentViewFrame.1
            let navigationFrameEnd = self.view.convert(controller.controller.navigationBar!.frame, from: controller.controller.navigationBar!.view)

            let convertedFrame = self.view
                .convert(titleView.frame, from: titleView) // CGRect(x: (contentViewFrame.width - titleSourceframe.width) / 2, y: contentViewFrame.minY + titleSourceframe.height / 2, width: titleSourceframe.width, height: titleSourceframe.height)
            let titleFinalFrame = CGRect(
                x: (originalProjectedContentViewFrame.1.width - convertedFrame.width) / 2,
                y: convertedFrame.minY - (titleView.frame.height - convertedFrame.height.rounded()) * 2 - 5,
                width: convertedFrame.width,
                height: titleView.frame.height
            )

            //                    let heightScale =  titleSourceframe.height / titleFinalFrame.height

            let targetAvatarSize = CGSize(width: 36, height: 36)
            let avatarFinalFrame = CGRect(
                x: titleFinalFrame.minX - targetAvatarSize.width / 2,
                y: titleFinalFrame.midY - targetAvatarSize.height / 2,
                width: targetAvatarSize.width,
                height: targetAvatarSize.height
            )

            let smallAvatarHeight = CGFloat(20)

            let sourceMessageFrameFinal = CGRect(
                x: avatarFinalFrame.minX,
                y: avatarFinalFrame.midY - sourceMessageFrameStart.height / 2,
                width: sourceMessageFrameStart.width,
                height: sourceMessageFrameStart.height
            )

            let startedBackgrounMaskPath = UIBezierPath(roundedRect: sourceMessageFrameStart, cornerRadius: .zero)
            let targtePath = UIBezierPath(roundedRect: contentArea, cornerRadius: 40)

            let targetBackgroundMaskLayer = CAShapeLayer()
            targetBackgroundMaskLayer.frame = clippingNode.layer.bounds
            targetBackgroundMaskLayer.position = targeBgPosition
            navigationBackgroundSnapshot.mask = targetBackgroundMaskLayer
            navigationBackgroundSnapshot.masksToBounds = true

            targetBackgroundMaskLayer.path = targtePath.cgPath
            targetBackgroundMaskLayer.path = targtePath.cgPath
            clippingNode.layer.mask = targetBackgroundMaskLayer
            let animation = clippingNode.layer.makeAnimation(from: startedBackgrounMaskPath.cgPath, to: targtePath.cgPath, keyPath: "path", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3) { _ in
                print("mask path updated")
            }
            animation.fillMode = .forwards
            targetBackgroundMaskLayer.add(animation, forKey: "path")

            print("titleSourceframe: \(titleSourceframe) titleFinalFrame: \(titleFinalFrame) navigationFrameStar: \(navigationFrameStart)")

            avatarSnapshot.layer.animateScale(from: 1.0, to: smallAvatarHeight / avatarFinalFrame.height, duration: 1.0)

            chatSnapshot.frame = sourceMessageFrameStart
            chatSnapshot.layer.addSublayer(navigationBackgroundSnapshot)
            self.view.addSubview(chatSnapshot)
            chatSnapshot.layer.animatePosition(from: sourceMessageFrameStart.center, to: sourceMessageFrameFinal.center, duration: 0.3, removeOnCompletion: true) { _ in
                print("title snapshot animation finished")
                //                    chatSnapshot.removeFromSuperview()
            }
            chatSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)

            titleSnapshot.frame = titleSourceframe
            self.view.addSubview(titleSnapshot)
            titleSnapshot.layer.animatePosition(from: titleSourceframe.center, to: titleFinalFrame.center, duration: 0.3, removeOnCompletion: true) { _ in
                print("title snapshot animation finished")
                chatSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 1.5, removeOnCompletion: false)
                //                    titleSnapshot.removeFromSuperview()
            }
            

            avatarSnapshot.frame = avatarSourceFrame
            self.view.addSubview(avatarSnapshot)
            avatarSnapshot.layer.animatePosition(from: avatarSourceFrame.center, to: avatarFinalFrame.center, duration: 0.3, removeOnCompletion: true) { _ in
                print("avatarSnapshot snapshot animation finished")
                avatarSnapshot.removeFromSuperview()
            }
            avatarSnapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)


            let navigationSnapshotView = UIView()
            navigationSnapshotView.layer.addSublayer(navigationBackgroundSnapshot)
            navigationSnapshotView.frame = navigationFrameStart
            navigationSnapshotView.layer.animatePosition(from: navigationFrameStart.center, to: navigationFrameEnd.center, duration: 0.3, removeOnCompletion: true) { _ in
                print("navigationSnapshotView snapshot animation finished")
                navigationSnapshotView.removeFromSuperview()
            }

//                let pf = originalProjectedContentViewFrame.1

            CATransaction.commit()
        
//            self.contentContainerNode.layer.animateSpring(from: NSValue(cgPoint: targetBackgroundMaskLay cgPath), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true, completion: { [weak self] _ in
//                self?.animatedIn = true
//            })
        }
    }

    func updateLayout() {
        if let layout = self.validLayout {
            self.updateLayout(layout, transition: .immediate)
        }
    }

    func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.isAnimatingOut {
            return
        }

        self.validLayout = layout

        let targetFrame = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(view: self.effectView, frame: targetFrame)
        transition.updateFrame(node: self.dimNode, frame: targetFrame)
        transition.updateFrame(node: self.withoutBlurDimNode, frame: targetFrame)

        switch layout.metrics.widthClass {
        case .compact:
            if self.effectView.superview == nil {
                self.view.insertSubview(self.effectView, at: 0)
                if let propertyAnimator = self.propertyAnimator {
                    let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                    propertyAnimator?.stopAnimation(true)
                }
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: presentationData.theme.rootController.keyboardColor == .light)
                self.dimNode.alpha = 1.0
            }
            self.dimNode.isHidden = false
            self.withoutBlurDimNode.isHidden = true
        case .regular:
            if self.effectView.superview != nil {
                self.effectView.removeFromSuperview()
                self.withoutBlurDimNode.alpha = 1.0
            }
            self.dimNode.isHidden = true
            self.withoutBlurDimNode.isHidden = false
        }
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))

        let actionsSideInset: CGFloat = layout.safeInsets.left + 11
        let contentTopInset: CGFloat = max(11.0, layout.statusBarHeight ?? 0.0)

        let actionsBottomInset: CGFloat = 11.0

        if let contentParentNode = contentContainerNode.controllerNode {
            var projectedFrame: CGRect = convertFrame(contentParentNode.sourceView.bounds, from: contentParentNode.sourceView, to: self.view)
            if let presentationArguments, let (sourceNode, sourceRect) = presentationArguments.sourceNodeAndRect() {
                projectedFrame = convertFrame(sourceRect, from: sourceNode.view, to: self.view)
            }
            self.originalProjectedContentViewFrame = (projectedFrame, projectedFrame)
            if let originalProjectedContentViewFrame = self.originalProjectedContentViewFrame, let contentArea = self.presentationArguments?.contentArea() {
                let topEdge = max(contentTopInset, contentArea.minY)

                let constrainedWidth: CGFloat
                if layout.size.width < layout.size.height {
                    constrainedWidth = layout.size.width
                } else {
                    constrainedWidth = floor(layout.size.width / 2.0)
                }
                let contentScale = (constrainedWidth - actionsSideInset * 2.0) / constrainedWidth

                var contentUnscaledSize: CGSize
                if case .compact = layout.metrics.widthClass {
                    let proposedContentHeight: CGFloat
                    if layout.size.width < layout.size.height {
                        proposedContentHeight = layout.size.height - topEdge - actionsSideInset - layout.intrinsicInsets.bottom - actionsBottomInset
                    } else {
                        proposedContentHeight = layout.size.height - topEdge - topEdge
                    }

                    contentUnscaledSize = CGSize(width: constrainedWidth, height: max(100.0, proposedContentHeight))
                    if
                        let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(
                            size: contentUnscaledSize,
                            metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact),
                            deviceMetrics: layout.deviceMetrics,
                            intrinsicInsets: UIEdgeInsets(),
                            safeInsets: UIEdgeInsets(),
                            additionalInsets: UIEdgeInsets(),
                            statusBarHeight: nil,
                            inputHeight: nil,
                            inputHeightIsInteractivellyChanging: false,
                            inVoiceOver: false
                        )) {
                        contentUnscaledSize = preferredSize
                    }
                } else {
                    let proposedContentHeight = layout.size.height - topEdge - actionsSideInset - layout.intrinsicInsets.bottom

                    contentUnscaledSize = CGSize(width: min(layout.size.width, 340.0), height: min(400.0, proposedContentHeight))
                    if
                        let preferredSize = contentParentNode.controller.preferredContentSizeForLayout(ContainerViewLayout(
                            size: contentUnscaledSize,
                            metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact),
                            deviceMetrics: layout.deviceMetrics,
                            intrinsicInsets: UIEdgeInsets(),
                            safeInsets: UIEdgeInsets(),
                            additionalInsets: UIEdgeInsets(),
                            statusBarHeight: nil,
                            inputHeight: nil,
                            inputHeightIsInteractivellyChanging: false,
                            inVoiceOver: false
                        )) {
                        contentUnscaledSize = preferredSize
                    }
                }
                let contentSize = CGSize(width: floor(contentUnscaledSize.width * contentScale), height: floor(contentUnscaledSize.height * contentScale))
                self.contentContainerNode.updateLayout(size: contentUnscaledSize, scaledSize: contentSize, transition: transition)

                let contentActionsSpacing: CGFloat = .zero
                let actionsSize: CGSize = .zero

                let maximumActionsFrameOrigin = max(60.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - actionsSize.height)
                var originalActionsFrame: CGRect
                var originalContentFrame: CGRect
                var contentHeight: CGFloat

                if case .compact = layout.metrics.widthClass {
                    if layout.size.width < layout.size.height {
                        let sideInset = floor((layout.size.width - contentSize.width) / 2.0)
                        originalActionsFrame = CGRect(origin: CGPoint(x: sideInset, y: min(maximumActionsFrameOrigin, floor((layout.size.height - actionsSideInset - contentSize.height) / 2.0) + contentSize.height)), size: actionsSize)
                        originalContentFrame = CGRect(origin: CGPoint(x: sideInset, y: originalActionsFrame.minY - contentActionsSpacing - contentSize.height), size: contentSize)
                        if originalContentFrame.minY < topEdge {
                            let requiredOffset = topEdge - originalContentFrame.minY
                            let availableOffset = max(0.0, layout.size.height - layout.intrinsicInsets.bottom - actionsBottomInset - originalActionsFrame.maxY)
                            let offset = min(requiredOffset, availableOffset)
                            originalActionsFrame = originalActionsFrame.offsetBy(dx: 0.0, dy: offset)
                            originalContentFrame = originalContentFrame.offsetBy(dx: 0.0, dy: offset)
                        }
                        contentHeight = max(layout.size.height, max(layout.size.height, originalActionsFrame.maxY + actionsBottomInset) - originalContentFrame.minY + contentTopInset)
                    } else {
                        originalContentFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width - actionsSideInset - actionsSize.width) / 2.0), y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
                        originalActionsFrame = CGRect(origin: CGPoint(x: originalContentFrame.maxX + actionsSideInset, y: max(topEdge, originalContentFrame.minY)), size: actionsSize)
                        contentHeight = max(layout.size.height, max(originalContentFrame.maxY, originalActionsFrame.maxY))
                    }
                } else {
                    originalContentFrame = CGRect(origin: CGPoint(x: floor(originalProjectedContentViewFrame.1.midX - contentSize.width / 2.0), y: floor(originalProjectedContentViewFrame.1.midY - contentSize.height / 2.0)), size: contentSize)
                    originalContentFrame.origin.x = min(originalContentFrame.origin.x, layout.size.width - actionsSideInset - contentSize.width)
                    originalContentFrame.origin.x = max(originalContentFrame.origin.x, actionsSideInset)
                    originalContentFrame.origin.y = min(originalContentFrame.origin.y, layout.size.height - layout.intrinsicInsets.bottom - actionsSideInset - contentSize.height)
                    originalContentFrame.origin.y = max(originalContentFrame.origin.y, contentTopInset)
                    if originalContentFrame.maxX <= layout.size.width - actionsSideInset - actionsSize.width - contentActionsSpacing {
                        originalActionsFrame = CGRect(origin: CGPoint(x: originalContentFrame.maxX + contentActionsSpacing, y: originalContentFrame.minY), size: actionsSize)
                        if originalActionsFrame.maxX > layout.size.width - actionsSideInset {
                            let offset = originalActionsFrame.maxX - (layout.size.width - actionsSideInset)
                            originalActionsFrame.origin.x -= offset
                            originalContentFrame.origin.x -= offset
                        }
                    } else {
                        originalActionsFrame = CGRect(origin: CGPoint(x: originalContentFrame.minX - contentActionsSpacing - actionsSize.width, y: originalContentFrame.minY), size: actionsSize)
                        if originalActionsFrame.minX < actionsSideInset {
                            let offset = actionsSideInset - originalActionsFrame.minX
                            originalActionsFrame.origin.x += offset
                            originalContentFrame.origin.x += offset
                        }
                    }
                    contentHeight = layout.size.height
                    contentHeight = max(contentHeight, originalActionsFrame.maxY + actionsBottomInset)
                    contentHeight = max(contentHeight, originalContentFrame.maxY + actionsBottomInset)
                }

                let scrollContentSize = CGSize(width: layout.size.width, height: contentSize.height)
                print("originalContentFrame: \(originalContentFrame) contentTopInset: \(contentTopInset) scrollContentSize: \(scrollContentSize)")

                if self.scrollNode.view.contentSize != scrollContentSize {
                    self.scrollNode.view.contentSize = scrollContentSize
                }

                let overflowOffset = min(0.0, originalContentFrame.minY - contentTopInset)

                let contentContainerFrame = originalContentFrame
                transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame.offsetBy(dx: 0.0, dy: -overflowOffset))

                if let maskLayer = self.clippingNode.layer.mask as? CAShapeLayer {
                    let newPath = UIBezierPath(roundedRect: originalContentFrame, cornerRadius: 40)
                    transition.updatePath(layer: maskLayer, path: newPath.cgPath)
                }

//                let contentContainerFrame = CGRect(origin: CGPoint(x: floor(originalProjectedContentViewFrame.1.midX - contentSize.width / 2.0), y: floor(originalProjectedContentViewFrame.1.midY - contentSize.height / 2.0)), size: contentSize)
//                transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
            }
        }

        transition.updateFrame(node: self.dismissNode, frame: CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize))
        self.dismissAccessibilityArea.frame = CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize)
    }

    private func animateBlurBackground(isHidden: Bool) {}

    func animateOut(targetNode: ASDisplayNode?, completion: (() -> Void)? = nil) {
        var dimCompleted = false

        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }

        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
    }

    func updatePresentationArguments(_ arguments: ChatListPreviewPresentationData?, controller: ViewController?) {
        self.presentationArguments = arguments
        self.controller = controller
//        guard
//            let (sourceNode, sourceFrame) = arguments?.sourceNodeAndRect(),
//            let contentArea = arguments?.contentArea(),
//            let sourceChatItem = sourceNode.supernode as? ChatListItemNode,
//            let controller = controller
//        else { return }
//
//        self.gesture?.endPressedAppearance()
//
//        let titleNode = sourceChatItem.titleNode
//        let titleSnapshot = titleNode.layer.snapshotContentTree()
//        let titleSourceframe = titleNode.convert(titleNode.frame, to: nil)
//
//        let avatarNode = sourceChatItem.avatarContainerNode
//        let avatarSnapshot = avatarNode.layer.snapshotContentTree()
//        let avatarSourceFrame = avatarNode.convert(avatarNode.frame, to: nil)
//
//        titleNode.isHidden = true
//        avatarNode.isHidden = true
//
//        guard
//            let chatSnapshot = sourceChatItem.layer.snapshotContentTree(),
//            let sourceMessageNode,
//            let titleSnapshot,
//            let avatarSnapshot,
//            let navigationBar = controller.navigationBar,
//            let avatarNode = navigationBar.subnodes?.compactMap({ $0.subnodes }).flatMap({ $0 }).first(where: { $0 is NavigationButtonNode }) as? NavigationButtonNode,
//            let titleView = controller.navigationItem.titleView as? ChatTitleView,
//            let navigationBackgroundSnapshot = navigationBar.layer.snapshotContentTree()
//        else { return }
//
//        let sourceMessageFrameStart = sourceNode.convert(sourceFrame, to: nil)//.align(in: finalFrame)
//
//        let finalFrame = previewFrame(from: contentArea)
//        let navigationFrameStart = sourceMessageFrameStart.insetBy(dx: .zero, dy: -15)
//        let navigationFrameEnd = CGRect(origin: finalFrame.origin, size: CGSize(width: finalFrame.width, height: 43.0))
//
//        let titleFinalFrame = CGRect(x: (finalFrame.width - titleSourceframe.width) / 2, y: finalFrame.minX + titleSourceframe.height / 2, width: titleSourceframe.width, height: titleSourceframe.height)
//        let targetAvatarSize = CGSize(width: 36, height: 36)
//        let avatarFinalFrame = CGRect(x: (titleFinalFrame.minX - targetAvatarSize.width) / 2 + finalFrame.minX,
//                                      y: (navigationFrameEnd.height - targetAvatarSize.height) / 2, width: targetAvatarSize.width, height: targetAvatarSize.height)
//
//        let targetAvatarStart = CGRect(origin: CGPoint(x: finalFrame.maxX - 5 - (targetAvatarSize.width / 2),
//                                                       y: (sourceMessageFrameStart.minY - (targetAvatarSize.height / 2))),
//                                       size: CGSize(width: targetAvatarSize.width / 2, height: targetAvatarSize.height / 2))
//
//        let contentScale = self.view.contentScaleFactor
//
//        chatSnapshot.bounds = sourceMessageFrameStart
//        chatSnapshot.contentsScale = contentScale
//        chatSnapshot.contentsGravity = .resizeAspect
//        chatSnapshot.position = sourceMessageFrameStart.center
//        sourceMessageNode.layer.addSublayer(chatSnapshot)
//
//        let targetBackgroundMaskLayer = CAShapeLayer()
//        targetBackgroundMaskLayer.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: navigationFrameStart.size), cornerRadius: .zero).cgPath
//        targetBackgroundMaskLayer.bounds = sourceMessageFrameStart
//        targetBackgroundMaskLayer.position = sourceMessageFrameStart.center
//        navigationBackgroundSnapshot.mask = targetBackgroundMaskLayer
//        sourceMessageNode.layer.addSublayer(navigationBackgroundSnapshot)
//
//        titleSnapshot.bounds = titleSourceframe
//        titleSnapshot.position = titleSourceframe.center
//        titleSnapshot.contentsScale = contentScale
//        titleSnapshot.contentsGravity = .resizeAspect
//        sourceMessageNode.layer.addSublayer(titleSnapshot)
//
//        self.sourceAvatarNode?.bounds = avatarSourceFrame
//        self.sourceAvatarNode?.position = avatarSourceFrame.center
//        self.sourceAvatarNode?.layer.addSublayer(avatarSnapshot)
//        avatarSnapshot.contentsScale = contentScale
//        avatarSnapshot.contentsGravity = .resizeAspect
//        avatarSnapshot.frame = self.sourceAvatarNode!.layer.bounds
//
//        let sourceMessageFrameEnd = CGRect(x: finalFrame.minX + 60, y: navigationFrameEnd.minY, width: sourceMessageFrameStart.width, height: sourceMessageFrameStart.height)
//        let targtetAvatarEnd = CGRect(origin: CGPoint(x: finalFrame.maxX - 5 - targetAvatarSize.width, y: finalFrame.minY + 5), size: targetAvatarSize)
//
//
//        self.transitionParams = TransitionParams(contentArea: finalFrame,
//                                                 sourceMessageFrameStart: sourceMessageFrameStart,
//                                                 sourceMessageFrameEnd: sourceMessageFrameEnd,
//                                                 sourceChatItemSnapshot: chatSnapshot,
//                                                 sourceTitleSnapshot: titleSnapshot,
//                                                 sourceTitleFrame: titleSourceframe,
        ////                                                 sourceAvatarSnapshot: avatarSnapshot,
//                                                 sourceAvatarStartFrame: avatarSourceFrame,
//                                                 sourceAvatarFinalFrame: avatarFinalFrame,
//                                                 targetTitleView: titleView,
//                                                 targetTitleViewFrame: titleFinalFrame,
//                                                 targetAvatarNode: avatarNode,
//                                                 targetAvatarFrameStart: targetAvatarStart,
//                                                 targetAvatarFrameEnd: targtetAvatarEnd,
//                                                 targetBackgroundLayer: navigationBackgroundSnapshot,
//                                                 targetBackgroundMaskLayer: targetBackgroundMaskLayer,
//                                                 targetBackgroundStartFrame: navigationFrameStart,
//                                                 targetBackgroundEndFrame: navigationFrameEnd)
//
//        print("calculated transition params: \(self.transitionParams!)")
    }

    private func previewFrame(from contentArea: CGRect) -> CGRect {
        let size = CGSize(width: min(self.bounds.width - 22, contentArea.width), height: min(400, contentArea.height))
        return CGRect(x: (self.bounds.width - size.width) / 2, y: (self.bounds.height - size.height) / 2, width: size.width, height: size.height)
    }
}

public final class ChatListPreviewController: ViewController {
    private weak var recognizer: TapLongTapOrDoubleTapGestureRecognizer?
    private weak var gesture: ContextGesture?

    private var animatedDidAppear = false
    private var wasDismissed = false

    private var controllerNode: ChatListPreviewControllerNode {
        return self.displayNode as! ChatListPreviewControllerNode
    }

    private var animatedIn = false

    private let context: AccountContext
    private var chatLocation: ChatLocation
    private var chatPrevewController: ChatController

    public init(context: AccountContext, chatLocation: ChatLocation, recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil, gesture: ContextGesture? = nil) {
        self.context = context
        self.chatLocation = chatLocation
        self.chatPrevewController = context.sharedContext.makeChatController(context: context, chatLocation: chatLocation, subject: nil, botStart: nil, mode: .standard(previewing: true))
        self.recognizer = recognizer
        self.gesture = gesture
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Hide
        self.lockOrientation = true
        self.blocksBackgroundWhenInOverlay = true
    }

    @available(*, unavailable) public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = ChatListPreviewControllerNode(context: context, gesture: gesture)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let _ = self.presentationArguments as? ChatListPreviewPresentationData {
            self.updateChatLocation(self.chatLocation)
            self.ready.set(.single(true))
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        super.viewDidAppear(animated)
        _ = (self.ready.get() |> deliverOnMainQueue).start(next: { value in
            guard value else { return }

            self.controllerNode.initializeContent()

            print("content is ready: \(value)")
            if !self.wasDismissed, !self.animatedDidAppear {
                self.animatedDidAppear = true
                self.controllerNode.animateIn()
            }
        })
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        guard
            let arguments = self.presentationArguments as? ChatListPreviewPresentationData,
            let (sourceNode, _) = arguments.sourceNodeAndRect()
        else { return }

        self.controllerNode.animateOut(targetNode: sourceNode, completion: completion)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.chatPrevewController.updateNavigationBarLayout(layout, transition: transition)
        self.controllerNode.updateLayout(layout, transition: transition)
    }

    public func updateChatLocation(_ chatLocation: ChatLocation) {
        self.chatLocation = chatLocation
        let chatController = context.sharedContext.makeChatController(context: self.context, chatLocation: chatLocation, subject: nil, botStart: nil, mode: .standard(previewing: true))
        self.chatPrevewController = chatController
        if let layout = self.currentlyAppliedLayout {
            chatController.updateNavigationBarLayout(layout, transition: .immediate)
            self.controllerNode.updatePresentationArguments(
                self.presentationArguments as? ChatListPreviewPresentationData,
                controller: chatController
            )
        }

//        if self.chatLocation != chatLocation {
//        }
    }
}
