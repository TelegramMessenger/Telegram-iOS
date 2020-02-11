import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import SyncCore
import Postbox
import TelegramUIPreferences
import TelegramCore

final class TabBarChatListFilterController: ViewController {
    private var controllerNode: TabBarChatListFilterControllerNode {
        return self.displayNode as! TabBarChatListFilterControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let sourceNodes: [ASDisplayNode]
    private let presetList: [ChatListFilter]
    private let currentPreset: ChatListFilter?
    private let setup: () -> Void
    private let updatePreset: (ChatListFilter?) -> Void
    
    private var presentationData: PresentationData
    private var didPlayPresentationAnimation = false
    
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, sourceNodes: [ASDisplayNode], presetList: [ChatListFilter], currentPreset: ChatListFilter?, setup: @escaping () -> Void, updatePreset: @escaping (ChatListFilter?) -> Void) {
        self.context = context
        self.sourceNodes = sourceNodes
        self.presetList = presetList
        self.currentPreset = currentPreset
        self.setup = setup
        self.updatePreset = updatePreset
        
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
        }, sourceNodes: self.sourceNodes, presetList: self.presetList, currentPreset: self.currentPreset, setup: { [weak self] in
            self?.setup()
            self?.dismiss(sourceNodes: [], fadeOutIcon: true)
        }, updatePreset: { [weak self] filter in
            self?.updatePreset(filter)
            self?.dismiss()
        })
        self._ready.set(self.controllerNode.isReady.get())
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
        self.dismiss(sourceNodes: [], fadeOutIcon: false)
    }
    
    func dismiss(sourceNodes: [ASDisplayNode], fadeOutIcon: Bool) {
        self.controllerNode.animateOut(sourceNodes: sourceNodes, fadeOutIcon: fadeOutIcon, completion: { [weak self] in
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}

private let animationDurationFactor: Double = 1.0

private protocol AbstractTabBarChatListFilterItemNode {
    func updateLayout(maxWidth: CGFloat) -> (CGFloat, CGFloat, (CGFloat) -> Void)
}

private final class AddFilterItemNode: ASDisplayNode, AbstractTabBarChatListFilterItemNode {
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
        self.titleNode.attributedText = NSAttributedString(string: "Setup", font: Font.regular(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
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
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 10.0
        let iconInset: CGFloat = 60.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: maxWidth - leftInset - rightInset, height: .greatestFiniteMagnitude))
        let height: CGFloat = 61.0
        
        return (titleSize.width + leftInset + rightInset, height, { width in
            self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            
            if let image = self.plusNode.image {
                self.plusNode.frame = CGRect(origin: CGPoint(x: floor(width - iconInset + (iconInset - image.size.width) / 2.0), y: floor((height - image.size.height) / 2.0)), size: image.size)
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

private final class FilterItemNode: ASDisplayNode, AbstractTabBarChatListFilterItemNode {
    private let context: AccountContext
    private let title: String
    let preset: ChatListFilter?
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
    private var badgeText: String = ""
    
    init(context: AccountContext, title: String, preset: ChatListFilter?, isCurrent: Bool, displaySeparator: Bool, presentationData: PresentationData, action: @escaping () -> Bool) {
        self.context = context
        self.title = title
        self.preset = preset
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
        self.checkNode.isHidden = true//!isCurrent
        
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
        
        let rightInset: CGFloat = max(20.0, badgeSize.width + 20.0)
        
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
        let _ = self.action()
        //self.checkNode.isHidden = !isCurrent
    }
    
    func updateBadge(text: String) -> Bool {
        if text != self.badgeText {
            self.badgeText = text
            self.badgeTitleNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: self.presentationData.theme.list.itemCheckColors.foregroundColor)
            self.badgeBackgroundNode.isHidden = text.isEmpty
            self.badgeTitleNode.isHidden = text.isEmpty
            return true
        } else {
            return false
        }
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
    
    private var countsDisposable: Disposable?
    let isReady = Promise<Bool>()
    private var didSetIsReady = false
    
    init(context: AccountContext, presentationData: PresentationData, cancel: @escaping () -> Void, sourceNodes: [ASDisplayNode], presetList: [ChatListFilter], currentPreset: ChatListFilter?, setup: @escaping () -> Void, updatePreset: @escaping (ChatListFilter?) -> Void) {
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
        contentNodes.append(AddFilterItemNode(displaySeparator: true, presentationData: presentationData, action: {
            setup()
        }))
        
        for i in 0 ..< presetList.count {
            let preset = presetList[i]
            
            let title: String = preset.title ?? ""
            contentNodes.append(FilterItemNode(context: context, title: title, preset: preset, isCurrent: currentPreset == preset, displaySeparator: i != presetList.count - 1, presentationData: presentationData, action: {
                updatePreset(preset)
                return false
            }))
        }
        self.contentNodes = contentNodes
        
        super.init()
        
        self.view.addSubview(self.effectView)
        self.addSubnode(self.dimNode)
        self.addSubnode(self.contentContainerNode)
        self.contentNodes.forEach(self.contentContainerNode.addSubnode)
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        
        var unreadCountItems: [UnreadMessageCountsItem] = []
        unreadCountItems.append(.total(nil))
        var additionalPeerIds = Set<PeerId>()
        for preset in presetList {
            additionalPeerIds.formUnion(preset.includePeers)
        }
        if !additionalPeerIds.isEmpty {
            for peerId in additionalPeerIds {
                unreadCountItems.append(.peer(peerId))
            }
        }
        let unreadKey: PostboxViewKey = .unreadCounts(items: unreadCountItems)
        var keys: [PostboxViewKey] = []
        keys.append(unreadKey)
        for peerId in additionalPeerIds {
            keys.append(.basicPeer(peerId))
        }
        
        self.countsDisposable = (context.account.postbox.combinedView(keys: keys)
        |> deliverOnMainQueue).start(next: { [weak self] view in
            guard let strongSelf = self else {
                return
            }
            
            if let unreadCounts = view.views[unreadKey] as? UnreadMessageCountsView {
                var peerTagAndCount: [PeerId: (PeerSummaryCounterTags, Int)] = [:]
                
                var totalState: ChatListTotalUnreadState?
                for entry in unreadCounts.entries {
                    switch entry {
                    case let .total(_, totalStateValue):
                        totalState = totalStateValue
                    case let .peer(peerId, state):
                        if let state = state, state.isUnread {
                            if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer {
                                let tag = context.account.postbox.seedConfiguration.peerSummaryCounterTags(peer)
                                var peerCount = Int(state.count)
                                if state.isUnread {
                                    peerCount = max(1, peerCount)
                                }
                                peerTagAndCount[peerId] = (tag, peerCount)
                            }
                        }
                    }
                }
                
                var totalUnreadChatCount = 0
                if let totalState = totalState {
                    for (_, counters) in totalState.filteredCounters {
                        totalUnreadChatCount += Int(counters.chatCount)
                    }
                }
                
                var shouldUpdateLayout = false
                for case let contentNode as FilterItemNode in strongSelf.contentNodes {
                    let badgeString: String
                    if let preset = contentNode.preset {
                        var tags: [PeerSummaryCounterTags] = []
                        if preset.categories.contains(.privateChats) {
                            tags.append(.privateChat)
                        }
                        if preset.categories.contains(.secretChats) {
                            tags.append(.secretChat)
                        }
                        if preset.categories.contains(.privateGroups) {
                            tags.append(.privateGroup)
                        }
                        if preset.categories.contains(.bots) {
                            tags.append(.bot)
                        }
                        if preset.categories.contains(.publicGroups) {
                            tags.append(.publicGroup)
                        }
                        if preset.categories.contains(.channels) {
                            tags.append(.channel)
                        }
                        
                        var count = 0
                        if let totalState = totalState {
                            for tag in tags {
                                if let value = totalState.filteredCounters[tag] {
                                    count += Int(value.chatCount)
                                }
                            }
                        }
                        for peerId in preset.includePeers {
                            if let (tag, peerCount) = peerTagAndCount[peerId] {
                                if !tags.contains(tag) {
                                    count += peerCount
                                }
                            }
                        }
                        if count != 0 {
                            badgeString = "\(count)"
                        } else {
                            badgeString = ""
                        }
                    } else {
                        badgeString = ""
                    }
                    if contentNode.updateBadge(text: badgeString) {
                        shouldUpdateLayout = true
                    }
                }
                
                if shouldUpdateLayout {
                    if let layout = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                    }
                }
            }
            
            if !strongSelf.didSetIsReady {
                strongSelf.didSetIsReady = true
                strongSelf.isReady.set(.single(true))
            }
        })
    }
    
    deinit {
        if let propertyAnimator = self.propertyAnimator {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                let propertyAnimator = propertyAnimator as? UIViewPropertyAnimator
                propertyAnimator?.stopAnimation(true)
            }
        }
        
        self.countsDisposable?.dispose()
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
    
    func animateOut(sourceNodes: [ASDisplayNode], fadeOutIcon: Bool, completion: @escaping () -> Void) {
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
        if fadeOutIcon {
            for snapshotView in self.snapshotViews {
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            }
            completedSourceNodes = true
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
        contentSize.width = min(layout.size.width - 40.0, 260.0)
        var applyNodes: [(ASDisplayNode, CGFloat, (CGFloat) -> Void)] = []
        for itemNode in self.contentNodes {
            let (width, height, apply) = itemNode.updateLayout(maxWidth: contentSize.width - sideInset * 2.0)
            applyNodes.append((itemNode, height, apply))
            contentSize.width = max(contentSize.width, width)
            contentSize.height += height
        }
        
        let insets = layout.insets(options: .input)
        
        let contentOrigin: CGPoint
        if let sourceNode = self.sourceNodes.first, let screenFrame = sourceNode.supernode?.convert(sourceNode.frame, to: nil) {
            contentOrigin = CGPoint(x: max(16.0, screenFrame.maxX - contentSize.width + 8.0), y: layout.size.height - 66.0 - insets.bottom - contentSize.height)
        } else {
            contentOrigin = CGPoint(x: max(16.0, layout.size.width - sideInset - contentSize.width), y: layout.size.height - 66.0 - layout.intrinsicInsets.bottom - contentSize.height)
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
