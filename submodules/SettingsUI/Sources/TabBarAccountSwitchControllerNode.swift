import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import LocalizedPeerData

private let animationDurationFactor: Double = 1.0
private let avatarFont = avatarPlaceholderFont(size: 16.0)

private protocol AbstractSwitchAccountItemNode {
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void)
}

private final class AddAccountItemNode: ASDisplayNode, AbstractSwitchAccountItemNode {
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let plusNode: ASImageNode
    private let titleNode: ImmediateTextNode
    
    init(displaySeparator: Bool, presentationData: PresentationData, action: @escaping () -> Void) {
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        self.separatorNode.isHidden = !displaySeparator
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: presentationData.strings.Settings_AddAccount, font: Font.regular(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        self.plusNode = ASImageNode()
        self.plusNode.image = generateItemListPlusIcon(presentationData.theme.actionSheet.primaryTextColor)
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.plusNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
    }
    
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void) {
        let leftInset: CGFloat = 56.0
        let rightInset: CGFloat = 10.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        let height: CGFloat = 61.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let image = self.plusNode.image {
                self.plusNode.frame = CGRect(origin: CGPoint(x: floor((leftInset - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
            }
            
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel))
            self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
            self.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
        })
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
}

private final class SwitchAccountItemNode: ASDisplayNode, AbstractSwitchAccountItemNode {
    private let context: AccountContext
    private let peer: Peer
    private let isCurrent: Bool
    private let unreadCount: Int32
    private let presentationData: PresentationData
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let checkNode: ASImageNode
    
    private let badgeBackgroundNode: ASImageNode
    private let badgeTitleNode: ImmediateTextNode
    
    init(context: AccountContext, peer: Peer, isCurrent: Bool, unreadCount: Int32, displaySeparator: Bool, presentationData: PresentationData, action: @escaping () -> Void) {
        self.context = context
        self.peer = peer
        self.isCurrent = isCurrent
        self.unreadCount = unreadCount
        self.presentationData = presentationData
        self.action = action
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemSeparatorColor
        self.separatorNode.isHidden = !displaySeparator
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.regular(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        self.checkNode = ASImageNode()
        self.checkNode.image = generateItemListCheckIcon(color: presentationData.theme.actionSheet.primaryTextColor)
        self.checkNode.isHidden = !isCurrent
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: presentationData.theme.list.itemCheckColors.fillColor)
        self.badgeTitleNode = ImmediateTextNode()
        if unreadCount > 0 {
            let countString = compactNumericCountString(Int(unreadCount), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            self.badgeTitleNode.attributedText = NSAttributedString(string: countString, font: Font.regular(14.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
        } else {
            self.badgeBackgroundNode.isHidden = true
            self.badgeTitleNode.isHidden = true
        }
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTitleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
    }
    
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void) {
        let leftInset: CGFloat = 56.0
        
        let badgeTitleSize = self.badgeTitleNode.updateLayout(CGSize(width: 100.0, height: .greatestFiniteMagnitude))
        let badgeMinSize = self.badgeBackgroundNode.image?.size.width ?? 20.0
        let badgeSize = CGSize(width: max(badgeMinSize, badgeTitleSize.width + 12.0), height: badgeMinSize)
        
        let rightInset: CGFloat = max(60.0, badgeSize.width + 40.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        
        let height: CGFloat = 61.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
            let avatarSize = CGSize(width: 30.0, height: 30.0)
            self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((leftInset - avatarSize.width) / 2.0), y: floor((height - avatarSize.height) / 2.0)), size: avatarSize)
            self.avatarNode.setPeer(context: self.context, theme: self.presentationData.theme, peer: EnginePeer(self.peer))
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let image = self.checkNode.image {
                self.checkNode.frame = CGRect(origin: CGPoint(x: width - rightInset + floor((rightInset - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
            }
            
            let badgeBackgroundFrame = CGRect(origin: CGPoint(x: width - rightInset + floor((rightInset - badgeSize.width) / 2.0), y: floor((height - badgeSize.height) / 2.0)), size: badgeSize)
            self.badgeBackgroundNode.frame = badgeBackgroundFrame
            self.badgeTitleNode.frame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.minX + floor((badgeBackgroundFrame.width - badgeTitleSize.width) / 2.0), y: badgeBackgroundFrame.minY + floor((badgeBackgroundFrame.height - badgeTitleSize.height) / 2.0)), size: badgeTitleSize)
            
            self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel))
            self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
            self.buttonNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height))
        })
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
}

final class TabBarAccountSwitchControllerNode: ViewControllerTracingNode {
    private let presentationData: PresentationData
    private let cancel: () -> Void
    
    private let effectView: UIVisualEffectView
    private var propertyAnimator: AnyObject?
    private var displayLinkAnimator: DisplayLinkAnimator?
    private let dimNode: ASDisplayNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentNodes: [ASDisplayNode & AbstractSwitchAccountItemNode]
    
    private var sourceNodes: [ASDisplayNode]
    private var snapshotViews: [UIView] = []
    
    private var validLayout: ContainerViewLayout?
    
    init(sharedContext: SharedAccountContext, accounts: (primary: (Account, Peer), other: [(Account, Peer, Int32)]), presentationData: PresentationData, canAddAccounts: Bool, switchToAccount: @escaping (AccountRecordId) -> Void, addAccount: @escaping () -> Void, cancel: @escaping () -> Void, sourceNodes: [ASDisplayNode]) {
        self.presentationData = presentationData
        self.cancel = cancel
        self.sourceNodes = sourceNodes
        
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
        self.dimNode.alpha = 1.0
        if presentationData.theme.rootController.keyboardColor == .light {
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.04)
        } else {
            self.dimNode.backgroundColor = presentationData.theme.chatList.backgroundColor.withAlphaComponent(0.2)
        }
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
        self.contentContainerNode.cornerRadius = 20.0
        self.contentContainerNode.clipsToBounds = true
        
        var contentNodes: [ASDisplayNode & AbstractSwitchAccountItemNode] = []
        if canAddAccounts {
            contentNodes.append(AddAccountItemNode(displaySeparator: true, presentationData: presentationData, action: {
                addAccount()
                cancel()
            }))
        }
        contentNodes.append(SwitchAccountItemNode(context: sharedContext.makeTempAccountContext(account: accounts.primary.0), peer: accounts.primary.1, isCurrent: true, unreadCount: 0, displaySeparator: !accounts.other.isEmpty, presentationData: presentationData, action: {
            cancel()
        }))
        for i in 0 ..< accounts.other.count {
            let (account, peer, count) = accounts.other[i]
            let id = account.id
            contentNodes.append(SwitchAccountItemNode(context: sharedContext.makeTempAccountContext(account: account), peer: peer, isCurrent: false, unreadCount: count, displaySeparator: i != accounts.other.count - 1, presentationData: presentationData, action: {
                switchToAccount(id)
            }))
        }
        self.contentNodes = contentNodes
        
        super.init()
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        self.addSubnode(self.contentContainerNode)
        self.contentNodes.forEach(self.contentContainerNode.addSubnode)
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    deinit {
        if let propertyAnimator = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        if #available(iOS 10.0, *) {
            if let propertyAnimator = self.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            self.propertyAnimator = UIViewPropertyAnimator(duration: 0.2 * animationDurationFactor, curve: .easeInOut, animations: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.effectView.effect = makeCustomZoomBlurEffect(isLight: !strongSelf.presentationData.theme.overallDarkAppearance)
            })
        }
        
        if let _ = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * animationDurationFactor, from: 0.0, to: 1.0, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                }, completion: {
                })
            }
        } else {
            UIView.animate(withDuration: 0.2 * animationDurationFactor, animations: {
                self.effectView.effect = makeCustomZoomBlurEffect(isLight: !self.presentationData.theme.overallDarkAppearance)
            }, completion: { _ in
            })
        }
        
        self.contentContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        if let _ = self.validLayout, let sourceNode = self.sourceNodes.first {
            let sourceFrame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
            self.contentContainerNode.layer.animateFrame(from: sourceFrame, to: self.contentContainerNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        for sourceNode in self.sourceNodes {
            if let imageNode = sourceNode as? ASImageNode {
                let snapshot = UIImageView()
                snapshot.image = imageNode.image
                snapshot.frame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
                snapshot.isUserInteractionEnabled = false
                self.view.addSubview(snapshot)
                self.snapshotViews.append(snapshot)
            } else if let snapshot = sourceNode.view.snapshotContentTree() {
                snapshot.frame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
                snapshot.isUserInteractionEnabled = false
                self.view.addSubview(snapshot)
                self.snapshotViews.append(snapshot)
            }
            sourceNode.alpha = 0.0
        }
    }
    
    func animateOut(sourceNodes: [ASDisplayNode], changedAccount: Bool, completion: @escaping () -> Void) {
        self.isUserInteractionEnabled = false
        
        var completedEffect = false
        var completedSourceNodes = false
        
        let intermediateCompletion: () -> Void = {
            if completedEffect && completedSourceNodes {
                completion()
            }
        }
        
        if #available(iOS 10.0, *) {
            if let propertyAnimator = self.propertyAnimator {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
            self.propertyAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .easeInOut, animations: { [weak self] in
                self?.effectView.effect = nil
            })
        }
        
        if let _ = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                self.displayLinkAnimator = DisplayLinkAnimator(duration: 0.2 * animationDurationFactor, from: 0.0, to: 0.999, update: { [weak self] value in
                    (self?.propertyAnimator as? UIViewPropertyAnimator)?.fractionComplete = value
                    }, completion: { [weak self] in
                        if let strongSelf = self {
                            for sourceNode in strongSelf.sourceNodes {
                                sourceNode.alpha = 1.0
                            }
                        }
                        
                        completedEffect = true
                        intermediateCompletion()
                })
            }
            self.effectView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.05 * animationDurationFactor, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
        } else {
            UIView.animate(withDuration: 0.21 * animationDurationFactor, animations: {
                if #available(iOS 9.0, *) {
                    self.effectView.effect = nil
                } else {
                    self.effectView.alpha = 0.0
                }
            }, completion: { [weak self] _ in
                if let strongSelf = self {
                    for sourceNode in strongSelf.sourceNodes {
                        sourceNode.alpha = 1.0
                    }
                }
                
                completedEffect = true
                intermediateCompletion()
            })
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.contentContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
        })
        if let _ = self.validLayout, let sourceNode = self.sourceNodes.first {
            let sourceFrame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
            self.contentContainerNode.layer.animateFrame(from: self.contentContainerNode.frame, to: sourceFrame, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
        }
        
        if changedAccount {
            for sourceNode in self.sourceNodes {
                sourceNode.alpha = 1.0
            }
            
            var previousImage: UIImage?
            for i in 0 ..< self.snapshotViews.count {
                let view = self.snapshotViews[i]
                if view.bounds.size.width.isEqual(to: 42.0) {
                    if i == 0, let imageView = view as? UIImageView {
                        previousImage = imageView.image
                    }
                    view.removeFromSuperview()
                } else {
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                    view.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
                }
            }
            let previousSnapshotViews = self.snapshotViews
            self.snapshotViews = []
            
            self.sourceNodes = sourceNodes
            
            var hadBounce = false
            for i in 0 ..< self.sourceNodes.count {
                let sourceNode = self.sourceNodes[i]
                var snapshot: UIView?
                if let imageNode = sourceNode as? ASImageNode {
                    let snapshotView = UIImageView()
                    snapshotView.image = imageNode.image
                    snapshotView.frame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
                    snapshotView.isUserInteractionEnabled = false
                    self.view.addSubview(snapshotView)
                    self.snapshotViews.append(snapshotView)
                    snapshot = snapshotView
                } else if let genericSnapshot = sourceNode.view.snapshotContentTree() {
                    genericSnapshot.frame = sourceNode.view.convert(sourceNode.bounds, to: self.view)
                    genericSnapshot.isUserInteractionEnabled = false
                    self.view.addSubview(genericSnapshot)
                    self.snapshotViews.append(genericSnapshot)
                    snapshot = genericSnapshot
                }
                
                if let snapshot = snapshot {
                    if snapshot.bounds.size.width.isEqual(to: 42.0) {
                        if i == 0, let imageView = snapshot as? UIImageView {
                            hadBounce = true
                            let updatedImage = imageView.image
                            imageView.image = previousImage
                            setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.3), forView: imageView)
                            imageView.layer.animateScale(from: 1.0, to: 0.6, duration: 0.1, removeOnCompletion: false, completion: { [weak imageView] _ in
                                guard let imageView = imageView else {
                                    return
                                }
                                imageView.image = updatedImage
                                if let previousContents = previousImage?.cgImage, let updatedContents = updatedImage?.cgImage {
                                    imageView.layer.animate(from: previousContents as AnyObject, to: updatedContents as AnyObject, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.15)
                                }
                                imageView.layer.animateSpring(from: 0.6 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, completion: { _ in
                                    completedSourceNodes = true
                                    intermediateCompletion()
                                })
                            })
                        }
                    } else {
                        snapshot.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        snapshot.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2, removeOnCompletion: false)
                    }
                }
                sourceNode.alpha = 0.0
            }
            
            previousSnapshotViews.forEach { view in
                self.view.bringSubviewToFront(view)
            }
            
            if !hadBounce {
                completedSourceNodes = true
            }
        } else {
            completedSourceNodes = true
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sideInset: CGFloat = 18.0
        
        var contentSize = CGSize()
        contentSize.width = min(layout.size.width - 40.0, 250.0)
        var applyNodes: [(ASDisplayNode, CGFloat, (CGFloat) -> Void)] = []
        for itemNode in self.contentNodes {
            let (width, height, apply) = itemNode.updateLayout(maxWidth: layout.size.width - sideInset * 2.0)
            applyNodes.append((itemNode, height, apply))
            contentSize.width = max(contentSize.width, width)
            contentSize.height += height
        }
        
        let insets = layout.insets(options: .input)
        
        let contentOrigin: CGPoint
        if let sourceNode = self.sourceNodes.first, let screenFrame = sourceNode.supernode?.convert(sourceNode.frame, to: nil) {
            contentOrigin = CGPoint(x: screenFrame.maxX - contentSize.width + 8.0, y: layout.size.height - 66.0 - insets.bottom - contentSize.height)
        } else {
            contentOrigin = CGPoint(x: layout.size.width - sideInset - contentSize.width, y: layout.size.height - 66.0 - layout.intrinsicInsets.bottom - contentSize.height)
        }

        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: contentOrigin, size: contentSize))
        var nextY: CGFloat = 0.0
        for (itemNode, height, apply) in applyNodes {
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: nextY), size: CGSize(width: contentSize.width, height: height)))
            apply(contentSize.width)
            nextY += height
        }
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel()
        }
    }
}

private func setAnchorPoint(anchorPoint: CGPoint, forView view: UIView) {
    var newPoint = CGPoint(x: view.bounds.size.width * anchorPoint.x,
                           y: view.bounds.size.height * anchorPoint.y)
    
    
    var oldPoint = CGPoint(x: view.bounds.size.width * view.layer.anchorPoint.x,
                           y: view.bounds.size.height * view.layer.anchorPoint.y)
    
    newPoint = newPoint.applying(view.transform)
    oldPoint = oldPoint.applying(view.transform)
    
    var position = view.layer.position
    position.x -= oldPoint.x
    position.x += newPoint.x
    
    position.y -= oldPoint.y
    position.y += newPoint.y
    
    view.layer.position = position
    view.layer.anchorPoint = anchorPoint
}
