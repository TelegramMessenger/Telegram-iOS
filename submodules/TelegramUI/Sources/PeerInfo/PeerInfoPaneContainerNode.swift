import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import Postbox
import TelegramCore
import AccountContext
import ContextUI

protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    var parentController: ViewController? { get set }

    var status: Signal<PeerInfoStatusData?, NoError> { get }
    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    var tabBarOffset: CGFloat { get }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func transferVelocity(_ velocity: CGFloat)
    func cancelPreviewGestures()
    func findLoadedMessage(id: MessageId) -> Message?
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    func addToTransitionSurface(view: UIView)
    func updateHiddenMedia()
    func updateSelectedMessages(animated: Bool)
    func ensureMessageIsVisible(id: MessageId)
}

final class PeerInfoPaneWrapper {
    let key: PeerInfoPaneKey
    let node: PeerInfoPaneNode
    var isAnimatingOut: Bool = false
    private var appliedParams: (CGSize, CGFloat, CGFloat, CGFloat, CGFloat, Bool, CGFloat, PresentationData)?
    
    init(key: PeerInfoPaneKey, node: PeerInfoPaneNode) {
        self.key = key
        self.node = node
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        if let (currentSize, currentTopInset, currentSideInset, currentBottomInset, _, currentIsScrollingLockedAtTop, currentExpandProgress, currentPresentationData) = self.appliedParams {
            if currentSize == size && currentTopInset == topInset, currentSideInset == sideInset && currentBottomInset == bottomInset, currentIsScrollingLockedAtTop == isScrollingLockedAtTop && currentExpandProgress == expandProgress && currentPresentationData === presentationData {
                return
            }
        }
        self.appliedParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        self.node.update(size: size, topInset: topInset, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: synchronous, transition: transition)
    }
}

enum PeerInfoPaneKey: Int32 {
    case members
    case media
    case files
    case links
    case voice
    case music
    case gifs
    case groupsInCommon
}

final class PeerInfoPaneTabsContainerPaneNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let titleNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    private var isSelected: Bool = false
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        /*self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted && !strongSelf.isSelected {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }*/
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func updateText(_ title: String, isSelected: Bool, presentationData: PresentationData) {
        self.isSelected = isSelected
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: isSelected ? presentationData.theme.list.itemAccentColor : presentationData.theme.list.itemSecondaryTextColor)
        
        self.buttonNode.accessibilityLabel = title
        self.buttonNode.accessibilityTraits = [.button]
        if isSelected {
            self.buttonNode.accessibilityTraits.insert(.selected)
        }
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

struct PeerInfoPaneSpecifier: Equatable {
    var key: PeerInfoPaneKey
    var title: String
}

private func interpolateFrame(from fromValue: CGRect, to toValue: CGRect, t: CGFloat) -> CGRect {
    return CGRect(x: floorToScreenPixels(toValue.origin.x * t + fromValue.origin.x * (1.0 - t)), y: floorToScreenPixels(toValue.origin.y * t + fromValue.origin.y * (1.0 - t)), width: floorToScreenPixels(toValue.size.width * t + fromValue.size.width * (1.0 - t)), height: floorToScreenPixels(toValue.size.height * t + fromValue.size.height * (1.0 - t)))
}

final class PeerInfoPaneTabsContainerNode: ASDisplayNode {
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
        
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.scrollNode.view.contentOffset.x > .ulpOfOne
        }
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.selectedLineNode)
    }
    
    func update(size: CGSize, presentationData: PresentationData, paneList: [PeerInfoPaneSpecifier], selectedPane: PeerInfoPaneKey?, transitionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
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
                if let current = self.paneNodes[specifier.key] {
                    paneNode = current
                } else {
                    paneNode = PeerInfoPaneTabsContainerPaneNode(pressed: { [weak self] in
                        self?.paneSelected(specifier.key)
                    })
                    self.paneNodes[specifier.key] = paneNode
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
        
        var tabSizes: [(CGSize, PeerInfoPaneTabsContainerPaneNode, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        var selectionFrames: [CGRect] = []
        
        for specifier in paneList {
            guard let paneNode = self.paneNodes[specifier.key] else {
                continue
            }
            let wasAdded = paneNode.supernode == nil
            if wasAdded {
                self.scrollNode.addSubnode(paneNode)
            }
            let paneNodeWidth = paneNode.updateLayout(height: size.height)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            tabSizes.append((paneNodeSize, paneNode, wasAdded))
            totalRawTabSize += paneNodeSize.width
        }
        
        let minSpacing: CGFloat = 26.0
        if tabSizes.count <= 1 {
            for i in 0 ..< tabSizes.count {
                let (paneNodeSize, paneNode, wasAdded) = tabSizes[i]
                let leftOffset: CGFloat = 16.0
                
                let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                if wasAdded {
                    paneNode.frame = paneFrame
                    paneNode.alpha = 0.0
                    transition.updateAlpha(node: paneNode, alpha: 1.0)
                } else {
                    transition.updateFrameAdditiveToCenter(node: paneNode, frame: paneFrame)
                }
                let areaSideInset: CGFloat = 16.0
                paneNode.updateArea(size: paneFrame.size, sideInset: areaSideInset)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -areaSideInset, bottom: 0.0, right: -areaSideInset)
                
                selectionFrames.append(paneFrame)
            }
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: size.height)
        } else if totalRawTabSize + CGFloat(tabSizes.count + 1) * minSpacing <= size.width {
            let availableSpace = size.width
            let availableSpacing = availableSpace - totalRawTabSize
            let perTabSpacing = floor(availableSpacing / CGFloat(tabSizes.count + 1))
            
            let normalizedPerTabWidth = floor(availableSpace / CGFloat(tabSizes.count))
            var maxSpacing: CGFloat = 0.0
            var minSpacing: CGFloat = .greatestFiniteMagnitude
            for i in 0 ..< tabSizes.count - 1 {
                let distanceToNextBoundary = (normalizedPerTabWidth - tabSizes[i].0.width) / 2.0
                let nextDistanceToBoundary = (normalizedPerTabWidth - tabSizes[i + 1].0.width) / 2.0
                let distance = nextDistanceToBoundary + distanceToNextBoundary
                maxSpacing = max(distance, maxSpacing)
                minSpacing = min(distance, minSpacing)
            }
            
            if minSpacing >= 100.0 || (maxSpacing / minSpacing) < 0.2 {
                for i in 0 ..< tabSizes.count {
                    let (paneNodeSize, paneNode, wasAdded) = tabSizes[i]
                    
                    let paneFrame = CGRect(origin: CGPoint(x: CGFloat(i) * normalizedPerTabWidth + floor((normalizedPerTabWidth - paneNodeSize.width) / 2.0), y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                    if wasAdded {
                        paneNode.frame = paneFrame
                        paneNode.alpha = 0.0
                        transition.updateAlpha(node: paneNode, alpha: 1.0)
                    } else {
                        transition.updateFrameAdditiveToCenter(node: paneNode, frame: paneFrame)
                    }
                    let areaSideInset = floor((normalizedPerTabWidth - paneNodeSize.width) / 2.0)
                    paneNode.updateArea(size: paneFrame.size, sideInset: areaSideInset)
                    paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -areaSideInset, bottom: 0.0, right: -areaSideInset)
                    
                    selectionFrames.append(paneFrame)
                }
            } else {
                var leftOffset = perTabSpacing
                for i in 0 ..< tabSizes.count {
                    let (paneNodeSize, paneNode, wasAdded) = tabSizes[i]
                    
                    let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                    if wasAdded {
                        paneNode.frame = paneFrame
                        paneNode.alpha = 0.0
                        transition.updateAlpha(node: paneNode, alpha: 1.0)
                    } else {
                        transition.updateFrameAdditiveToCenter(node: paneNode, frame: paneFrame)
                    }
                    let areaSideInset = floor(perTabSpacing / 2.0)
                    paneNode.updateArea(size: paneFrame.size, sideInset: areaSideInset)
                    paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -areaSideInset, bottom: 0.0, right: -areaSideInset)
                    
                    leftOffset += paneNodeSize.width + perTabSpacing
                    
                    selectionFrames.append(paneFrame)
                }
            }
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: size.height)
        } else {
            let sideInset: CGFloat = 16.0
            var leftOffset: CGFloat = sideInset
            for i in 0 ..< tabSizes.count {
                let (paneNodeSize, paneNode, wasAdded) = tabSizes[i]
                let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                if wasAdded {
                    paneNode.frame = paneFrame
                    paneNode.alpha = 0.0
                    transition.updateAlpha(node: paneNode, alpha: 1.0)
                } else {
                    transition.updateFrameAdditiveToCenter(node: paneNode, frame: paneFrame)
                }
                paneNode.updateArea(size: paneFrame.size, sideInset: minSpacing)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -minSpacing, bottom: 0.0, right: -minSpacing)
                
                selectionFrames.append(paneFrame)
                
                leftOffset += paneNodeSize.width + minSpacing
            }
            self.scrollNode.view.contentSize = CGSize(width: leftOffset - minSpacing + sideInset, height: size.height)
        }
        
        var selectedFrame: CGRect?
        if let selectedPane = selectedPane, let currentIndex = paneList.firstIndex(where: { $0.key == selectedPane }) {
            if currentIndex != 0 && transitionFraction > 0.0 {
                let currentFrame = selectionFrames[currentIndex]
                let previousFrame = selectionFrames[currentIndex - 1]
                selectedFrame = interpolateFrame(from: currentFrame, to: previousFrame, t: abs(transitionFraction))
            } else if currentIndex != paneList.count - 1 && transitionFraction < 0.0 {
                let currentFrame = selectionFrames[currentIndex]
                let previousFrame = selectionFrames[currentIndex + 1]
                selectedFrame = interpolateFrame(from: currentFrame, to: previousFrame, t: abs(transitionFraction))
            } else {
                selectedFrame = selectionFrames[currentIndex]
            }
        }
        
        if let selectedFrame = selectedFrame {
            let wasAdded = self.selectedLineNode.isHidden
            self.selectedLineNode.isHidden = false
            let lineFrame = CGRect(origin: CGPoint(x: selectedFrame.minX, y: size.height - 4.0), size: CGSize(width: selectedFrame.width, height: 4.0))
            if wasAdded {
                self.selectedLineNode.frame = lineFrame
                self.selectedLineNode.alpha = 0.0
                transition.updateAlpha(node: self.selectedLineNode, alpha: 1.0)
            } else {
                transition.updateFrame(node: self.selectedLineNode, frame: lineFrame)
            }
            if focusOnSelectedPane {
                if selectedPane == paneList.first?.key {
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size))
                } else if selectedPane == paneList.last?.key {
                    transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: max(0.0, self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width), y: 0.0), size: self.scrollNode.bounds.size))
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

private final class PeerInfoPendingPane {
    let pane: PeerInfoPaneWrapper
    private var disposable: Disposable?
    var isReady: Bool = false
    
    init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
        chatControllerInteraction: ChatControllerInteraction,
        data: PeerInfoScreenData,
        openPeerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void,
        openAddMemberAction: @escaping () -> Void,
        requestPerformPeerMemberAction: @escaping (PeerInfoMember, PeerMembersListAction) -> Void,
        peerId: PeerId,
        key: PeerInfoPaneKey,
        hasBecomeReady: @escaping (PeerInfoPaneKey) -> Void,
        parentController: ViewController?,
        openMediaCalendar: @escaping () -> Void,
        paneDidScroll: @escaping () -> Void
    ) {
        let captureProtected = data.peer?.isCopyProtectionEnabled ?? false
        let paneNode: PeerInfoPaneNode
        switch key {
        case .media:
            let visualPaneNode = PeerInfoVisualMediaPaneNode(context: context, chatControllerInteraction: chatControllerInteraction, peerId: peerId, contentType: .photoOrVideo, captureProtected: captureProtected)
            paneNode = visualPaneNode
            visualPaneNode.openCurrentDate = {
                openMediaCalendar()
            }
            visualPaneNode.paneDidScroll = {
                paneDidScroll()
            }
        case .files:
            let visualPaneNode = PeerInfoVisualMediaPaneNode(context: context, chatControllerInteraction: chatControllerInteraction, peerId: peerId, contentType: .files, captureProtected: captureProtected)
            paneNode = visualPaneNode
            //paneNode = PeerInfoListPaneNode(context: context, updatedPresentationData: updatedPresentationData, chatControllerInteraction: chatControllerInteraction, peerId: peerId, tagMask: .file)
        case .links:
            paneNode = PeerInfoListPaneNode(context: context, updatedPresentationData: updatedPresentationData, chatControllerInteraction: chatControllerInteraction, peerId: peerId, tagMask: .webPage)
        case .voice:
            let visualPaneNode = PeerInfoVisualMediaPaneNode(context: context, chatControllerInteraction: chatControllerInteraction, peerId: peerId, contentType: .voiceAndVideoMessages, captureProtected: captureProtected)
            paneNode = visualPaneNode
            //paneNode = PeerInfoListPaneNode(context: context, updatedPresentationData: updatedPresentationData, chatControllerInteraction: chatControllerInteraction, peerId: peerId, tagMask: .voiceOrInstantVideo)
        case .music:
            let visualPaneNode = PeerInfoVisualMediaPaneNode(context: context, chatControllerInteraction: chatControllerInteraction, peerId: peerId, contentType: .music, captureProtected: captureProtected)
            paneNode = visualPaneNode
            //paneNode = PeerInfoListPaneNode(context: context, updatedPresentationData: updatedPresentationData, chatControllerInteraction: chatControllerInteraction, peerId: peerId, tagMask: .music)
        case .gifs:
            let visualPaneNode = PeerInfoGifPaneNode(context: context, chatControllerInteraction: chatControllerInteraction, peerId: peerId, contentType: .gifs)
            paneNode = visualPaneNode
        case .groupsInCommon:
            paneNode = PeerInfoGroupsInCommonPaneNode(context: context, peerId: peerId, chatControllerInteraction: chatControllerInteraction, openPeerContextAction: openPeerContextAction, groupsInCommonContext: data.groupsInCommon!)
        case .members:
            if case let .longList(membersContext) = data.members {
                paneNode = PeerInfoMembersPaneNode(context: context, peerId: peerId, membersContext: membersContext, addMemberAction: {
                    openAddMemberAction()
                }, action: { member, action in
                    requestPerformPeerMemberAction(member, action)
                })
            } else {
                preconditionFailure()
            }
        }
        paneNode.parentController = parentController
        self.pane = PeerInfoPaneWrapper(key: key, node: paneNode)
        self.disposable = (paneNode.isReady
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.isReady = true
            hasBecomeReady(key)
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

final class PeerInfoPaneContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let peerId: PeerId
    private let isMediaOnly: Bool
    
    weak var parentController: ViewController?
    
    private let coveringBackgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let tabsContainerNode: PeerInfoPaneTabsContainerNode
    private let tabsSeparatorNode: ASDisplayNode
    
    let isReady = Promise<Bool>()
    var didSetIsReady = false
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, expansionFraction: CGFloat, presentationData: PresentationData, data: PeerInfoScreenData?)?
    
    private(set) var currentPaneKey: PeerInfoPaneKey?
    var pendingSwitchToPaneKey: PeerInfoPaneKey?
    var expandOnSwitch = false
    
    var currentPane: PeerInfoPaneWrapper? {
        if let currentPaneKey = self.currentPaneKey {
            return self.currentPanes[currentPaneKey]
        } else {
            return nil
        }
    }

    private let currentPaneStatusPromise = Promise<PeerInfoStatusData?>(nil)
    private let nextPaneStatusPromise = Promise<PeerInfoStatusData?>(nil)
    private let paneTransitionPromise = ValuePromise<CGFloat?>(nil)
    
    var currentPaneStatus: Signal<(PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?), NoError> {
        return combineLatest(queue: Queue.mainQueue(), self.currentPaneStatusPromise.get(), self.nextPaneStatusPromise.get(), self.paneTransitionPromise.get())
    }
    
    private var currentPanes: [PeerInfoPaneKey: PeerInfoPaneWrapper] = [:]
    private var pendingPanes: [PeerInfoPaneKey: PeerInfoPendingPane] = [:]
    private var shouldFadeIn = false
    
    private var transitionFraction: CGFloat = 0.0
    
    var selectionPanelNode: PeerInfoSelectionPanelNode?
    
    var chatControllerInteraction: ChatControllerInteraction?
    var openPeerContextAction: ((Peer, ASDisplayNode, ContextGesture?) -> Void)?
    var openAddMemberAction: (() -> Void)?
    var requestPerformPeerMemberAction: ((PeerInfoMember, PeerMembersListAction) -> Void)?
    
    var currentPaneUpdated: ((Bool) -> Void)?
    var requestExpandTabs: (() -> Bool)?

    var openMediaCalendar: (() -> Void)?
    var paneDidScroll: (() -> Void)?
    
    private var currentAvailablePanes: [PeerInfoPaneKey]?
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    
    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: PeerId, isMediaOnly: Bool) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.peerId = peerId
        self.isMediaOnly = isMediaOnly
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.coveringBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.coveringBackgroundNode.isUserInteractionEnabled = false
        
        self.tabsContainerNode = PeerInfoPaneTabsContainerNode()
        
        self.tabsSeparatorNode = ASDisplayNode()
        self.tabsSeparatorNode.isLayerBacked = true
        
        super.init()
        
//        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coveringBackgroundNode)
        self.addSubnode(self.tabsContainerNode)
        self.addSubnode(self.tabsSeparatorNode)
        
        self.tabsContainerNode.requestSelectPane = { [weak self] key in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentPaneKey == key {
                if let requestExpandTabs = strongSelf.requestExpandTabs, requestExpandTabs() {
                } else {
                    let _ = strongSelf.currentPane?.node.scrollToTop()
                }
                return
            }
            if strongSelf.currentPanes[key] != nil {
                strongSelf.currentPaneKey = key
                
                if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                    strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: .animated(duration: 0.4, curve: .spring))
                    
                    strongSelf.currentPaneUpdated?(true)

                    strongSelf.currentPaneStatusPromise.set(strongSelf.currentPane?.node.status ?? .single(nil))
                    strongSelf.nextPaneStatusPromise.set(.single(nil))
                    strongSelf.paneTransitionPromise.set(nil)
                }
            } else if strongSelf.pendingSwitchToPaneKey != key {
                strongSelf.pendingSwitchToPaneKey = key
                strongSelf.expandOnSwitch = true
                
                if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                    strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
            guard let strongSelf = self, let currentPaneKey = strongSelf.currentPaneKey, let availablePanes = strongSelf.currentParams?.data?.availablePanes, let index = availablePanes.firstIndex(of: currentPaneKey) else {
                return []
            }
            if strongSelf.tabsContainerNode.bounds.contains(strongSelf.view.convert(point, to: strongSelf.tabsContainerNode.view)) {
                return []
            }
            if index == 0 {
                return .left
            }
            return [.left, .right]
        })
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            func cancelContextGestures(view: UIView) {
                if let gestureRecognizers = view.gestureRecognizers {
                    for gesture in gestureRecognizers {
                        if let gesture = gesture as? ContextGesture {
                            gesture.cancel()
                        }
                    }
                }
                for subview in view.subviews {
                    cancelContextGestures(view: subview)
                }
            }
            
            cancelContextGestures(view: self.view)
        case .changed:
            if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = self.currentParams, let availablePanes = data?.availablePanes, availablePanes.count > 1, let currentPaneKey = self.currentPaneKey, let currentIndex = availablePanes.firstIndex(of: currentPaneKey) {
                let translation = recognizer.translation(in: self.view)
                var transitionFraction = translation.x / size.width
                if currentIndex <= 0 {
                    transitionFraction = min(0.0, transitionFraction)
                }
                if currentIndex >= availablePanes.count - 1 {
                    transitionFraction = max(0.0, transitionFraction)
                }
                self.transitionFraction = transitionFraction
                
//                let nextKey = availablePanes[updatedIndex]
//                print(transitionFraction)
                self.paneTransitionPromise.set(transitionFraction)
                
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: .immediate)
                self.currentPaneUpdated?(false)
            }
        case .cancelled, .ended:
            if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = self.currentParams, let availablePanes = data?.availablePanes, availablePanes.count > 1, let currentPaneKey = self.currentPaneKey, let currentIndex = availablePanes.firstIndex(of: currentPaneKey) {
                let translation = recognizer.translation(in: self.view)
                let velocity = recognizer.velocity(in: self.view)
                var directionIsToRight: Bool?
                if abs(velocity.x) > 10.0 {
                    directionIsToRight = velocity.x < 0.0
                } else {
                    if abs(translation.x) > size.width / 2.0 {
                        directionIsToRight = translation.x > size.width / 2.0
                    }
                }
                if let directionIsToRight = directionIsToRight {
                    var updatedIndex = currentIndex
                    if directionIsToRight {
                        updatedIndex = min(updatedIndex + 1, availablePanes.count - 1)
                    } else {
                        updatedIndex = max(updatedIndex - 1, 0)
                    }
                    let switchToKey = availablePanes[updatedIndex]
                    if switchToKey != self.currentPaneKey && self.currentPanes[switchToKey] != nil{
                        self.currentPaneKey = switchToKey
                    }
                }
                self.transitionFraction = 0.0
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: .animated(duration: 0.35, curve: .spring))
                self.currentPaneUpdated?(false)

                self.currentPaneStatusPromise.set(self.currentPane?.node.status ?? .single(nil))
            }
        default:
            break
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
    
    func updateHiddenMedia() {
        self.currentPane?.node.updateHiddenMedia()
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.currentPane?.node.transitionNodeForGallery(messageId: messageId, media: media)
    }
    
    func updateSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?, animated: Bool) {
        for (_, pane) in self.currentPanes {
            pane.node.updateSelectedMessages(animated: animated)
        }
        for (_, pane) in self.pendingPanes {
            pane.pane.node.updateSelectedMessages(animated: animated)
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, expansionFraction: CGFloat, presentationData: PresentationData, data: PeerInfoScreenData?, transition: ContainedViewLayoutTransition) {
        let previousAvailablePanes = self.currentAvailablePanes
        let availablePanes = data?.availablePanes ?? []
        self.currentAvailablePanes = data?.availablePanes
        
        let previousPaneKeys = Set<PeerInfoPaneKey>(self.currentPanes.keys)
        
        let previousCurrentPaneKey = self.currentPaneKey
        var updateCurrentPaneStatus = false
        
        if let currentPaneKey = self.currentPaneKey, !availablePanes.contains(currentPaneKey) {
            var nextCandidatePaneKey: PeerInfoPaneKey?
            if let previousAvailablePanes = previousAvailablePanes, let index = previousAvailablePanes.firstIndex(of: currentPaneKey), index != 0 {
                for i in (0 ... index - 1).reversed() {
                    if availablePanes.contains(previousAvailablePanes[i]) {
                        nextCandidatePaneKey = previousAvailablePanes[i]
                    }
                }
            }
            if nextCandidatePaneKey == nil {
                nextCandidatePaneKey = availablePanes.first
            }
            
            if let nextCandidatePaneKey = nextCandidatePaneKey {
                self.pendingSwitchToPaneKey = nextCandidatePaneKey
            } else {
                self.currentPaneKey = nil
                self.pendingSwitchToPaneKey = nil
            }
        } else if self.currentPaneKey == nil {
            self.pendingSwitchToPaneKey = availablePanes.first
        }
        
        let currentIndex: Int?
        if let currentPaneKey = self.currentPaneKey {
            currentIndex = availablePanes.firstIndex(of: currentPaneKey)
        } else {
            currentIndex = nil
        }
        
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data)
        
        transition.updateAlpha(node: self.coveringBackgroundNode, alpha: expansionFraction)
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.coveringBackgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.opaqueBackgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.tabsSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor

        let isScrollingLockedAtTop = expansionFraction < 1.0 - CGFloat.ulpOfOne

        let tabsHeight: CGFloat = 48.0
        
        let paneFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
        
        var visiblePaneIndices: [Int] = []
        var requiredPendingKeys: [PeerInfoPaneKey] = []
        if let currentIndex = currentIndex {
            if currentIndex != 0 {
                visiblePaneIndices.append(currentIndex - 1)
            }
            visiblePaneIndices.append(currentIndex)
            if currentIndex != availablePanes.count - 1 {
                visiblePaneIndices.append(currentIndex + 1)
            }
        
            for index in visiblePaneIndices {
                let key = availablePanes[index]
                if self.currentPanes[key] == nil && self.pendingPanes[key] == nil {
                    requiredPendingKeys.append(key)
                }
            }
        }
        if let pendingSwitchToPaneKey = self.pendingSwitchToPaneKey {
            if self.currentPanes[pendingSwitchToPaneKey] == nil && self.pendingPanes[pendingSwitchToPaneKey] == nil {
                if !requiredPendingKeys.contains(pendingSwitchToPaneKey) {
                    requiredPendingKeys.append(pendingSwitchToPaneKey)
                }
            }
        }
        
        for key in requiredPendingKeys {
            if self.pendingPanes[key] == nil {
                var leftScope = false
                let pane = PeerInfoPendingPane(
                    context: self.context,
                    updatedPresentationData: self.updatedPresentationData,
                    chatControllerInteraction: self.chatControllerInteraction!,
                    data: data!,
                    openPeerContextAction: { [weak self] peer, node, gesture in
                        self?.openPeerContextAction?(peer, node, gesture)
                    },
                    openAddMemberAction: { [weak self] in
                        self?.openAddMemberAction?()
                    },
                    requestPerformPeerMemberAction: { [weak self] member, action in
                        self?.requestPerformPeerMemberAction?(member, action)
                    },
                    peerId: self.peerId,
                    key: key,
                    hasBecomeReady: { [weak self] key in
                        let apply: () -> Void = {
                            guard let strongSelf = self else {
                                return
                            }
                            if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                                var transition: ContainedViewLayoutTransition = .immediate
                                if strongSelf.pendingSwitchToPaneKey == key && strongSelf.currentPaneKey != nil {
                                    transition = .animated(duration: 0.4, curve: .spring)
                                }
                                strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: transition)
                            }
                        }
                        if leftScope {
                            apply()
                        }
                    },
                    parentController: self.parentController,
                    openMediaCalendar: { [weak self] in
                        self?.openMediaCalendar?()
                    },
                    paneDidScroll: { [weak self] in
                        self?.paneDidScroll?()
                    }
                )
                self.pendingPanes[key] = pane
                pane.pane.node.frame = paneFrame
                pane.pane.update(size: paneFrame.size, topInset: tabsHeight, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expansionFraction, presentationData: presentationData, synchronous: true, transition: .immediate)
                let paneNode = pane.pane.node
                pane.pane.node.tabBarOffsetUpdated = { [weak self, weak paneNode] transition in
                    guard let strongSelf = self, let paneNode = paneNode, let currentPane = strongSelf.currentPane, paneNode === currentPane.node else {
                        return
                    }
                    if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: transition)
                    }
                }
                leftScope = true
            }
        }
        
        for (key, pane) in self.pendingPanes {
            pane.pane.node.frame = paneFrame
            pane.pane.update(size: paneFrame.size, topInset: tabsHeight, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expansionFraction, presentationData: presentationData, synchronous: self.currentPaneKey == nil, transition: .immediate)
            
            if pane.isReady {
                self.pendingPanes.removeValue(forKey: key)
                self.currentPanes[key] = pane.pane
            }
        }
        
        var paneDefaultTransition = transition
        var previousPaneKey: PeerInfoPaneKey?
        var paneSwitchAnimationOffset: CGFloat = 0.0
        
        var updatedCurrentIndex = currentIndex
        if let pendingSwitchToPaneKey = self.pendingSwitchToPaneKey, let _ = self.currentPanes[pendingSwitchToPaneKey] {
            self.pendingSwitchToPaneKey = nil
            previousPaneKey = self.currentPaneKey
            self.currentPaneKey = pendingSwitchToPaneKey
            updateCurrentPaneStatus = true
            updatedCurrentIndex = availablePanes.firstIndex(of: pendingSwitchToPaneKey)
            if let previousPaneKey = previousPaneKey, let previousIndex = availablePanes.firstIndex(of: previousPaneKey), let updatedCurrentIndex = updatedCurrentIndex {
                if updatedCurrentIndex < previousIndex {
                    paneSwitchAnimationOffset = -size.width
                } else {
                    paneSwitchAnimationOffset = size.width
                }
            }
            
            paneDefaultTransition = .immediate
        }
                
        if let _ = data {
            if let previousAvailablePanes = previousAvailablePanes, previousAvailablePanes.isEmpty, !availablePanes.isEmpty {
                self.shouldFadeIn = true
            }
            
            let currentPaneKeys = Set<PeerInfoPaneKey>(self.currentPanes.keys)
            if previousPaneKeys.isEmpty && !currentPaneKeys.isEmpty && self.shouldFadeIn {
                self.shouldFadeIn = false
                self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
        }
        
        for (key, pane) in self.currentPanes {
            if let index = availablePanes.firstIndex(of: key), let updatedCurrentIndex = updatedCurrentIndex {
                var paneWasAdded = false
                if pane.node.supernode == nil {
                    self.insertSubnode(pane.node, belowSubnode: self.coveringBackgroundNode)
                    paneWasAdded = true
                }
                let indexOffset = CGFloat(index - updatedCurrentIndex)
                
                let paneTransition: ContainedViewLayoutTransition = paneWasAdded ? .immediate : paneDefaultTransition
                let adjustedFrame = paneFrame.offsetBy(dx: size.width * self.transitionFraction + indexOffset * size.width, dy: 0.0)
                
                let paneCompletion: () -> Void = { [weak self, weak pane] in
                    guard let strongSelf = self, let pane = pane else {
                        return
                    }
                    pane.isAnimatingOut = false
                    if let (_, _, _, _, _, _, data) = strongSelf.currentParams {
                        if let availablePanes = data?.availablePanes, let currentPaneKey = strongSelf.currentPaneKey, let currentIndex = availablePanes.firstIndex(of: currentPaneKey), let paneIndex = availablePanes.firstIndex(of: key), abs(paneIndex - currentIndex) <= 1 {
                        } else {
                            if let pane = strongSelf.currentPanes.removeValue(forKey: key) {
                                //print("remove \(key)")
                                pane.node.removeFromSupernode()
                            }
                        }
                    }
                }
                if let previousPaneKey = previousPaneKey, key == previousPaneKey {
                    pane.node.frame = adjustedFrame
                    let isAnimatingOut = pane.isAnimatingOut
                    pane.isAnimatingOut = true
                    transition.animateFrame(node: pane.node, from: paneFrame, to: paneFrame.offsetBy(dx: -paneSwitchAnimationOffset, dy: 0.0), completion: isAnimatingOut ? nil : { _ in
                        paneCompletion()
                    })
                } else if let _ = previousPaneKey, key == self.currentPaneKey {
                    pane.node.frame = adjustedFrame
                    let isAnimatingOut = pane.isAnimatingOut
                    pane.isAnimatingOut = true
                    transition.animatePositionAdditive(node: pane.node, offset: CGPoint(x: paneSwitchAnimationOffset, y: 0.0), completion: isAnimatingOut ? nil : {
                        paneCompletion()
                    })
                } else {
                    let isAnimatingOut = pane.isAnimatingOut
                    pane.isAnimatingOut = true
                    paneTransition.updateFrame(node: pane.node, frame: adjustedFrame, completion: isAnimatingOut ? nil :  { _ in
                        paneCompletion()
                    })
                }
                pane.update(size: paneFrame.size, topInset: tabsHeight, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expansionFraction, presentationData: presentationData, synchronous: paneWasAdded, transition: paneTransition)
            }
        }

        var tabsOffset: CGFloat = 0.0
        if let currentPane = self.currentPane {
            tabsOffset = currentPane.node.tabBarOffset
        }
        tabsOffset = max(0.0, min(tabsHeight, tabsOffset))
        if isScrollingLockedAtTop || self.isMediaOnly {
            tabsOffset = 0.0
        }
        var tabsAlpha = 1.0 - tabsOffset / tabsHeight
        tabsAlpha *= tabsAlpha
        transition.updateFrame(node: self.tabsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -tabsOffset), size: CGSize(width: size.width, height: tabsHeight)))
        transition.updateAlpha(node: self.tabsContainerNode, alpha: tabsAlpha)

        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel - tabsOffset), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.coveringBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel - tabsOffset), size: CGSize(width: size.width, height: tabsHeight + UIScreenPixel)))
        self.coveringBackgroundNode.update(size: self.coveringBackgroundNode.bounds.size, transition: transition)

        transition.updateFrame(node: self.tabsSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: tabsHeight - tabsOffset), size: CGSize(width: size.width, height: UIScreenPixel)))

        self.tabsContainerNode.update(size: CGSize(width: size.width, height: tabsHeight), presentationData: presentationData, paneList: availablePanes.map { key in
            let title: String
            switch key {
            case .media:
                title = presentationData.strings.PeerInfo_PaneMedia
            case .files:
                title = presentationData.strings.PeerInfo_PaneFiles
            case .links:
                title = presentationData.strings.PeerInfo_PaneLinks
            case .voice:
                title = presentationData.strings.PeerInfo_PaneVoiceAndVideo
            case .gifs:
                title = presentationData.strings.PeerInfo_PaneGifs
            case .music:
                title = presentationData.strings.PeerInfo_PaneAudio
            case .groupsInCommon:
                title = presentationData.strings.PeerInfo_PaneGroups
            case .members:
                title = presentationData.strings.PeerInfo_PaneMembers
            }
            return PeerInfoPaneSpecifier(key: key, title: title)
        }, selectedPane: self.currentPaneKey, transitionFraction: self.transitionFraction, transition: transition)
        
        for (_, pane) in self.pendingPanes {
            let paneTransition: ContainedViewLayoutTransition = .immediate
            paneTransition.updateFrame(node: pane.pane.node, frame: paneFrame)
            pane.pane.update(size: paneFrame.size, topInset: tabsHeight, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expansionFraction, presentationData: presentationData, synchronous: true, transition: paneTransition)
        }
        if !self.didSetIsReady && data != nil {
            if let currentPaneKey = self.currentPaneKey, let currentPane = self.currentPanes[currentPaneKey] {
                self.didSetIsReady = true
                self.isReady.set(currentPane.node.isReady)
            } else if self.pendingSwitchToPaneKey == nil {
                self.didSetIsReady = true
                self.isReady.set(.single(true))
            }
        }
        if let previousCurrentPaneKey = previousCurrentPaneKey, self.currentPaneKey != previousCurrentPaneKey {
            self.currentPaneUpdated?(self.expandOnSwitch)
            self.expandOnSwitch = false
        }
        if updateCurrentPaneStatus {
            self.currentPaneStatusPromise.set(self.currentPane?.node.status ?? .single(nil))
        }
    }
}
