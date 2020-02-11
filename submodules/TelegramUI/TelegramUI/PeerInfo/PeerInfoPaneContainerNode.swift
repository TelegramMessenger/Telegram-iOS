import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import Postbox
import SyncCore
import TelegramCore
import AccountContext
import ContextUI

protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func transferVelocity(_ velocity: CGFloat)
    func findLoadedMessage(id: MessageId) -> Message?
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    func addToTransitionSurface(view: UIView)
    func updateHiddenMedia()
    func updateSelectedMessages(animated: Bool)
}

final class PeerInfoPaneWrapper {
    let key: PeerInfoPaneKey
    let node: PeerInfoPaneNode
    private var appliedParams: (CGSize, CGFloat, CGFloat, CGFloat, Bool, PresentationData)?
    
    init(key: PeerInfoPaneKey, node: PeerInfoPaneNode) {
        self.key = key
        self.node = node
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        if let (currentSize, currentSideInset, currentBottomInset, visibleHeight, currentIsScrollingLockedAtTop, currentPresentationData) = self.appliedParams {
            if currentSize == size && currentSideInset == sideInset && currentBottomInset == bottomInset, currentIsScrollingLockedAtTop == isScrollingLockedAtTop && currentPresentationData === presentationData {
                return
            }
        }
        self.appliedParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, presentationData)
        self.node.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: synchronous, transition: transition)
    }
}

enum PeerInfoPaneKey {
    case media
    case files
    case links
    case voice
    case music
    case groupsInCommon
    case members
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
    
    func update(size: CGSize, presentationData: PresentationData, paneList: [PeerInfoPaneSpecifier], selectedPane: PeerInfoPaneKey?, transition: ContainedViewLayoutTransition) {
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
                var wasAdded = false
                if let current = self.paneNodes[specifier.key] {
                    paneNode = current
                } else {
                    wasAdded = true
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
        
        var selectedFrame: CGRect?
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
        
        let spacing: CGFloat = 32.0
        if tabSizes.count == 1 {
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
                
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
                }
            }
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: size.height)
        } else if totalRawTabSize + CGFloat(tabSizes.count + 1) * spacing <= size.width {
            let availableSpace = size.width
            let availableSpacing = availableSpace - totalRawTabSize
            let perTabSpacing = floor(availableSpacing / CGFloat(tabSizes.count + 1))
            
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
                
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
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
                paneNode.updateArea(size: paneFrame.size, sideInset: spacing)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -spacing, bottom: 0.0, right: -spacing)
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
                }
                leftOffset += paneNodeSize.width + spacing
            }
            self.scrollNode.view.contentSize = CGSize(width: leftOffset - spacing + sideInset, height: size.height)
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

final class PeerInfoPaneContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let coveringBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let tabsContainerNode: PeerInfoPaneTabsContainerNode
    private let tapsSeparatorNode: ASDisplayNode
    
    let isReady = Promise<Bool>()
    var didSetIsReady = false
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, expansionFraction: CGFloat, presentationData: PresentationData, data: PeerInfoScreenData?)?
    private(set) var currentPaneKey: PeerInfoPaneKey?
    private(set) var currentPane: PeerInfoPaneWrapper?
    
    private var currentCandidatePaneKey: PeerInfoPaneKey?
    private var candidatePane: (PeerInfoPaneWrapper, Disposable, Bool)?
    
    var selectionPanelNode: PeerInfoSelectionPanelNode?
    
    var chatControllerInteraction: ChatControllerInteraction?
    var openPeerContextAction: ((Peer, ASDisplayNode, ContextGesture?) -> Void)?
    var requestPerformPeerMemberAction: ((PeerInfoMember, PeerMembersListAction) -> Void)?
    
    var currentPaneUpdated: (() -> Void)?
    var requestExpandTabs: (() -> Bool)?
    
    private var currentAvailablePanes: [PeerInfoPaneKey]?
    
    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.coveringBackgroundNode = ASDisplayNode()
        self.coveringBackgroundNode.isLayerBacked = true
        
        self.tabsContainerNode = PeerInfoPaneTabsContainerNode()
        
        self.tapsSeparatorNode = ASDisplayNode()
        self.tapsSeparatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coveringBackgroundNode)
        self.addSubnode(self.tabsContainerNode)
        self.addSubnode(self.tapsSeparatorNode)
        
        self.tabsContainerNode.requestSelectPane = { [weak self] key in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentPaneKey == key {
                if let requestExpandTabs = strongSelf.requestExpandTabs, requestExpandTabs() {
                } else {
                    strongSelf.currentPane?.node.scrollToTop()
                }
                return
            }
            if strongSelf.currentCandidatePaneKey == key {
                return
            }
            strongSelf.currentCandidatePaneKey = key
            
            if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: .immediate)
            }
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
        self.currentPane?.node.updateSelectedMessages(animated: animated)
        self.candidatePane?.0.node.updateSelectedMessages(animated: animated)
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, expansionFraction: CGFloat, presentationData: PresentationData, data: PeerInfoScreenData?, transition: ContainedViewLayoutTransition) {
        let previousAvailablePanes = self.currentAvailablePanes ?? []
        let availablePanes = data?.availablePanes ?? []
        self.currentAvailablePanes = availablePanes
        
        if let currentPaneKey = self.currentPaneKey, !availablePanes.contains(currentPaneKey) {
            var nextCandidatePaneKey: PeerInfoPaneKey?
            if let index = previousAvailablePanes.index(of: currentPaneKey), index != 0 {
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
                if self.currentCandidatePaneKey != nextCandidatePaneKey {
                    self.currentCandidatePaneKey = nextCandidatePaneKey
                }
            } else {
                self.currentCandidatePaneKey = nil
                if let (_, disposable, _) = self.candidatePane {
                    disposable.dispose()
                    self.candidatePane = nil
                }
                if let currentPane = self.currentPane {
                    self.currentPane = nil
                    currentPane.node.removeFromSupernode()
                }
            }
        } else if self.currentPaneKey == nil {
            self.currentCandidatePaneKey = availablePanes.first
        }
        
        let previousCurrentPaneKey = self.currentPaneKey
        
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data)
        
        transition.updateAlpha(node: self.coveringBackgroundNode, alpha: expansionFraction)
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.coveringBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.tapsSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let tabsHeight: CGFloat = 48.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.coveringBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: tabsHeight + UIScreenPixel)))
        
        transition.updateFrame(node: self.tapsSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: tabsHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        let paneFrame = CGRect(origin: CGPoint(x: 0.0, y: tabsHeight), size: CGSize(width: size.width, height: size.height - tabsHeight))
        
        if let currentCandidatePaneKey = self.currentCandidatePaneKey {
            if self.candidatePane?.0.key != currentCandidatePaneKey {
                self.candidatePane?.1.dispose()
                
                let paneNode: PeerInfoPaneNode
                switch currentCandidatePaneKey {
                case .media:
                    paneNode = PeerInfoVisualMediaPaneNode(context: self.context, chatControllerInteraction: self.chatControllerInteraction!, peerId: self.peerId)
                case .files:
                    paneNode = PeerInfoListPaneNode(context: self.context, chatControllerInteraction: self.chatControllerInteraction!, peerId: self.peerId, tagMask: .file)
                case .links:
                    paneNode = PeerInfoListPaneNode(context: self.context, chatControllerInteraction: self.chatControllerInteraction!, peerId: self.peerId, tagMask: .webPage)
                case .voice:
                    paneNode = PeerInfoListPaneNode(context: self.context, chatControllerInteraction: self.chatControllerInteraction!, peerId: self.peerId, tagMask: .voiceOrInstantVideo)
                case .music:
                    paneNode = PeerInfoListPaneNode(context: self.context, chatControllerInteraction: self.chatControllerInteraction!, peerId: self.peerId, tagMask: .music)
                case .groupsInCommon:
                    paneNode = PeerInfoGroupsInCommonPaneNode(context: self.context, peerId: self.peerId, chatControllerInteraction: self.chatControllerInteraction!, openPeerContextAction: self.openPeerContextAction!, groupsInCommonContext: data!.groupsInCommon!)
                case .members:
                    if case let .longList(membersContext) = data?.members {
                        paneNode = PeerInfoMembersPaneNode(context: self.context, peerId: self.peerId, membersContext: membersContext, action: { [weak self] member, action in
                            self?.requestPerformPeerMemberAction?(member, action)
                        })
                    } else {
                        preconditionFailure()
                    }
                }
                
                let disposable = MetaDisposable()
                self.candidatePane = (PeerInfoPaneWrapper(key: currentCandidatePaneKey, node: paneNode), disposable, false)
                
                var shouldReLayout = false
                disposable.set((paneNode.isReady
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    if let (candidatePane, disposable, _) = strongSelf.candidatePane {
                        strongSelf.candidatePane = (candidatePane, disposable, true)
                        
                        if shouldReLayout {
                            if let (size, sideInset, bottomInset, visibleHeight, expansionFraction, presentationData, data) = strongSelf.currentParams {
                                strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: expansionFraction, presentationData: presentationData, data: data, transition: strongSelf.currentPane != nil ? .animated(duration: 0.35, curve: .spring) : .immediate)
                            }
                        }
                    }
                }))
                shouldReLayout = true
            }
        }
        
        if let (candidatePane, _, isReady) = self.candidatePane, isReady {
            let previousPane = self.currentPane
            self.candidatePane = nil
            self.currentPaneKey = candidatePane.key
            self.currentCandidatePaneKey = nil
            self.currentPane = candidatePane
            
            if let selectionPanelNode = self.selectionPanelNode {
                self.insertSubnode(candidatePane.node, belowSubnode: selectionPanelNode)
            } else {
                self.addSubnode(candidatePane.node)
            }
            candidatePane.node.frame = paneFrame
            candidatePane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: max(0.0, visibleHeight - paneFrame.minY), isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: true, transition: .immediate)
            
            if let previousPane = previousPane {
                let directionToRight: Bool
                if let previousIndex = availablePanes.index(of: previousPane.key), let updatedIndex = availablePanes.index(of: candidatePane.key) {
                    directionToRight = previousIndex < updatedIndex
                } else {
                    directionToRight = false
                }
                
                let offset: CGFloat = directionToRight ? previousPane.node.bounds.width : -previousPane.node.bounds.width
                
                transition.animatePositionAdditive(node: candidatePane.node, offset: CGPoint(x: offset, y: 0.0))
                let previousNode = previousPane.node
                transition.updateFrame(node: previousNode, frame: paneFrame.offsetBy(dx: -offset, dy: 0.0), completion: { [weak previousNode] _ in
                    previousNode?.removeFromSupernode()
                })
            }
        } else if let currentPane = self.currentPane {
            let paneWasAdded = currentPane.node.supernode == nil
            if paneWasAdded {
                self.addSubnode(currentPane.node)
            }
            
            let paneTransition: ContainedViewLayoutTransition = paneWasAdded ? .immediate : transition
            paneTransition.updateFrame(node: currentPane.node, frame: paneFrame)
            currentPane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: paneWasAdded, transition: paneTransition)
        }
        
        transition.updateFrame(node: self.tabsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: tabsHeight)))
        self.tabsContainerNode.update(size: CGSize(width: size.width, height: tabsHeight), presentationData: presentationData, paneList: availablePanes.map { key in
            let title: String
            switch key {
            case .media:
                title = "Media"
            case .files:
                title = "Files"
            case .links:
                title = "Links"
            case .voice:
                title = "Voice Messages"
            case .music:
                title = "Audio"
            case .groupsInCommon:
                title = "Groups"
            case .members:
                title = "Members"
            }
            return PeerInfoPaneSpecifier(key: key, title: title)
        }, selectedPane: self.currentPaneKey, transition: transition)
        
        if let (candidatePane, _, _) = self.candidatePane {
            let paneTransition: ContainedViewLayoutTransition = .immediate
            paneTransition.updateFrame(node: candidatePane.node, frame: paneFrame)
            candidatePane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: expansionFraction < 1.0 - CGFloat.ulpOfOne, presentationData: presentationData, synchronous: true, transition: paneTransition)
        }
        if !self.didSetIsReady && data != nil {
            if let currentPane = self.currentPane {
                self.didSetIsReady = true
                self.isReady.set(currentPane.node.isReady)
            } else if self.candidatePane == nil {
                self.didSetIsReady = true
                self.isReady.set(.single(true))
            }
        }
        if let previousCurrentPaneKey = previousCurrentPaneKey, self.currentPaneKey != previousCurrentPaneKey {
            self.currentPaneUpdated?()
        }
    }
}
