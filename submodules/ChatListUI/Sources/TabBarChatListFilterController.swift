import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext

final class TabBarChatListFilterController: ViewController {
    private var controllerNode: TabBarChatListFilterControllerNode {
        return self.displayNode as! TabBarChatListFilterControllerNode
    }
    
    private let _ready = Promise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let sourceNodes: [ASDisplayNode]
    private let currentFilter: ChatListNodeFilter
    private let updateFilter: (ChatListNodeFilter) -> Void
    
    private var presentationData: PresentationData
    private var didPlayPresentationAnimation = false
    
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, sourceNodes: [ASDisplayNode], currentFilter: ChatListNodeFilter, updateFilter: @escaping (ChatListNodeFilter) -> Void) {
        self.context = context
        self.sourceNodes = sourceNodes
        self.currentFilter = currentFilter
        self.updateFilter = updateFilter
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.statusBar.ignoreInCall = true
        
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TabBarChatListFilterControllerNode(context: self.context, presentationData: self.presentationData, cancel: { [weak self] in
            self?.dismiss()
        }, sourceNodes: self.sourceNodes, currentFilter: self.currentFilter, updateFilter: self.updateFilter)
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            
            self.hapticFeedback.impact()
            self.controllerNode.animateIn()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(sourceNodes: [])
    }
    
    public func dismiss(sourceNodes: [ASDisplayNode]) {
        self.controllerNode.animateOut(sourceNodes: sourceNodes, completion: { [weak self] in
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}

private let animationDurationFactor: Double = 1.0

private protocol AbstractTabBarChatListFilterItemNode {
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void)
}

private final class FilterItemNode: ASDisplayNode, AbstractTabBarChatListFilterItemNode {
    private let context: AccountContext
    private let title: String
    private let isCurrent: Bool
    private let presentationData: PresentationData
    private let action: () -> Bool
    
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let titleNode: ImmediateTextNode
    private let checkNode: ASImageNode
    
    private let badgeBackgroundNode: ASImageNode
    private let badgeTitleNode: ImmediateTextNode
    
    init(context: AccountContext, title: String, isCurrent: Bool, displaySeparator: Bool, presentationData: PresentationData, action: @escaping () -> Bool) {
        self.context = context
        self.title = title
        self.isCurrent = isCurrent
        self.presentationData = presentationData
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
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        self.checkNode = ASImageNode()
        self.checkNode.image = generateItemListCheckIcon(color: presentationData.theme.actionSheet.primaryTextColor)
        self.checkNode.isHidden = !isCurrent
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: presentationData.theme.list.itemCheckColors.fillColor)
        self.badgeTitleNode = ImmediateTextNode()
        self.badgeBackgroundNode.isHidden = true
        self.badgeTitleNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
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
        let leftInset: CGFloat = 16.0
        
        let badgeTitleSize = self.badgeTitleNode.updateLayout(CGSize(width: 100.0, height: .greatestFiniteMagnitude))
        let badgeMinSize = self.badgeBackgroundNode.image?.size.width ?? 20.0
        let badgeSize = CGSize(width: max(badgeMinSize, badgeTitleSize.width + 12.0), height: badgeMinSize)
        
        let rightInset: CGFloat = max(60.0, badgeSize.width + 40.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        
        let height: CGFloat = 61.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
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
        let isCurrent = self.action()
        self.checkNode.isHidden = !isCurrent
    }
}

private final class TabBarChatListFilterControllerNode: ViewControllerTracingNode {
    private let presentationData: PresentationData
    private let cancel: () -> Void
    
    private let effectView: UIVisualEffectView
    private var propertyAnimator: AnyObject?
    private var displayLinkAnimator: DisplayLinkAnimator?
    private let dimNode: ASDisplayNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentNodes: [ASDisplayNode & AbstractTabBarChatListFilterItemNode]
    
    private var sourceNodes: [ASDisplayNode]
    private var snapshotViews: [UIView] = []
    
    private var validLayout: ContainerViewLayout?
    
    init(context: AccountContext, presentationData: PresentationData, cancel: @escaping () -> Void, sourceNodes: [ASDisplayNode], currentFilter: ChatListNodeFilter, updateFilter: @escaping (ChatListNodeFilter) -> Void) {
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
        
        var contentNodes: [ASDisplayNode & AbstractTabBarChatListFilterItemNode] = []
        
        let labels: [(String, ChatListNodeFilter)] = [
            ("Private Chats", .privateChats),
            ("Groups", .groups),
            ("Bots", .bots),
            ("Channels", .channels),
            ("Muted", .muted)
        ]
        
        var updatedFilter = currentFilter
        let toggleFilter: (ChatListNodeFilter) -> Void = { filter in
            if updatedFilter.contains(filter) {
                updatedFilter.remove(filter)
            } else {
                updatedFilter.insert(filter)
            }
            updateFilter(updatedFilter)
        }
        
        for i in 0 ..< labels.count {
            let filter = labels[i].1
            contentNodes.append(FilterItemNode(context: context, title: labels[i].0, isCurrent: updatedFilter.contains(filter), displaySeparator: i != labels.count - 1, presentationData: presentationData, action: {
                toggleFilter(filter)
                return updatedFilter.contains(filter)
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
                self?.effectView.effect = makeCustomZoomBlurEffect()
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
                self.effectView.effect = makeCustomZoomBlurEffect()
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
    
    func animateOut(sourceNodes: [ASDisplayNode], completion: @escaping () -> Void) {
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
        completedSourceNodes = true
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
