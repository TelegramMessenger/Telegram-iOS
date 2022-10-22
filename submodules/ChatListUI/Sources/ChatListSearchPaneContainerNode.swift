import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramCore
import AccountContext
import ContextUI
import AnimationCache
import MultiAnimationRenderer

protocol ChatListSearchPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func cancelPreviewGestures()
    func transitionNodeForGallery(messageId: EngineMessage.Id, media: EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    func addToTransitionSurface(view: UIView)
    func updateHiddenMedia()
    func updateSelectedMessages(animated: Bool)
    func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)?
    func didBecomeFocused()
    var searchCurrentMessages: [EngineMessage]? { get }
}

final class ChatListSearchPaneWrapper {
    let key: ChatListSearchPaneKey
    let node: ChatListSearchPaneNode
    var isAnimatingOut: Bool = false
    private var appliedParams: (CGSize, CGFloat, CGFloat, CGFloat, PresentationData)?
    
    init(key: ChatListSearchPaneKey, node: ChatListSearchPaneNode) {
        self.key = key
        self.node = node
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        if let (currentSize, currentSideInset, currentBottomInset, _, currentPresentationData) = self.appliedParams {
            if currentSize == size && currentSideInset == sideInset && currentBottomInset == bottomInset && currentPresentationData === presentationData {
                return
            }
        }
        self.appliedParams = (size, sideInset, bottomInset, visibleHeight, presentationData)
        self.node.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: synchronous, transition: transition)
    }
}

public enum ChatListSearchPaneKey {
    case chats
    case topics
    case media
    case downloads
    case links
    case files
    case music
    case voice
}

extension ChatListSearchPaneKey {
    var filter: ChatListSearchFilter {
        switch self {
        case .chats:
            return .chats
        case .topics:
            return .topics
        case .media:
            return .media
        case .downloads:
            return .downloads
        case .links:
            return .links
        case .files:
            return .files
        case .music:
            return .music
        case .voice:
            return .voice
        }
    }
}

func defaultAvailableSearchPanes(isForum: Bool, hasDownloads: Bool) -> [ChatListSearchPaneKey] {
    var result: [ChatListSearchPaneKey] = []
    if isForum {
        result.append(.topics)
    } else {
        result.append(.chats)
    }
    result.append(contentsOf: [.media, .downloads, .links, .files, .music, .voice])
        
    if !hasDownloads {
        result.removeAll(where: { $0 == .downloads })
    }
    
    return result
}

struct ChatListSearchPaneSpecifier: Equatable {
    var key: ChatListSearchPaneKey
    var title: String
}

private func interpolateFrame(from fromValue: CGRect, to toValue: CGRect, t: CGFloat) -> CGRect {
    return CGRect(x: floorToScreenPixels(toValue.origin.x * t + fromValue.origin.x * (1.0 - t)), y: floorToScreenPixels(toValue.origin.y * t + fromValue.origin.y * (1.0 - t)), width: floorToScreenPixels(toValue.size.width * t + fromValue.size.width * (1.0 - t)), height: floorToScreenPixels(toValue.size.height * t + fromValue.size.height * (1.0 - t)))
}

private final class ChatListSearchPendingPane {
    let pane: ChatListSearchPaneWrapper
    private var disposable: Disposable?
    var isReady: Bool = false
    
    init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
        interaction: ChatListSearchInteraction,
        navigationController: NavigationController?,
        peersFilter: ChatListNodePeersFilter,
        location: ChatListControllerLocation,
        searchQuery: Signal<String?, NoError>,
        searchOptions: Signal<ChatListSearchOptions?, NoError>,
        key: ChatListSearchPaneKey,
        hasBecomeReady: @escaping (ChatListSearchPaneKey) -> Void
    ) {
        let paneNode = ChatListSearchListPaneNode(context: context, animationCache: animationCache, animationRenderer: animationRenderer, updatedPresentationData: updatedPresentationData, interaction: interaction, key: key, peersFilter: (key == .chats || key == .topics) ? peersFilter : [], location: location, searchQuery: searchQuery, searchOptions: searchOptions, navigationController: navigationController)
        
        self.pane = ChatListSearchPaneWrapper(key: key, node: paneNode)
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

final class ChatListSearchPaneContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let peersFilter: ChatListNodePeersFilter
    private let location: ChatListControllerLocation
    private let searchQuery: Signal<String?, NoError>
    private let searchOptions: Signal<ChatListSearchOptions?, NoError>
    private let navigationController: NavigationController?
    var interaction: ChatListSearchInteraction?
        
    let isReady = Promise<Bool>()
    var didSetIsReady = false
    
    var isAdjacentLoadingEnabled = false
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, [ChatListSearchPaneKey])?
    
    private(set) var currentPaneKey: ChatListSearchPaneKey?
    var pendingSwitchToPaneKey: ChatListSearchPaneKey?
    
    var currentPane: ChatListSearchPaneWrapper? {
        if let currentPaneKey = self.currentPaneKey {
            return self.currentPanes[currentPaneKey]
        } else {
            return nil
        }
    }
    
    var currentPanes: [ChatListSearchPaneKey: ChatListSearchPaneWrapper] = [:]
    private var pendingPanes: [ChatListSearchPaneKey: ChatListSearchPendingPane] = [:]
    
    private var transitionFraction: CGFloat = 0.0
            
    var currentPaneUpdated: ((ChatListSearchPaneKey?, CGFloat, ContainedViewLayoutTransition) -> Void)?
    var requestExpandTabs: (() -> Bool)?
    
    private var currentAvailablePanes: [ChatListSearchPaneKey]?
    
    init(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peersFilter: ChatListNodePeersFilter, location: ChatListControllerLocation, searchQuery: Signal<String?, NoError>, searchOptions: Signal<ChatListSearchOptions?, NoError>, navigationController: NavigationController?) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.updatedPresentationData = updatedPresentationData
        self.peersFilter = peersFilter
        self.location = location
        self.searchQuery = searchQuery
        self.searchOptions = searchOptions
        self.navigationController = navigationController
                
        super.init()
    }
    
    func requestSelectPane(_ key: ChatListSearchPaneKey) {
        if self.currentPaneKey == key {
            if let requestExpandTabs = self.requestExpandTabs, requestExpandTabs() {
            } else {
                let _ = self.currentPane?.node.scrollToTop()
            }
            return
        }
        self.isAdjacentLoadingEnabled = true
        if self.currentPanes[key] != nil {
            self.currentPaneKey = key

            if let (size, sideInset, bottomInset, visibleHeight, presentationData, availablePanes) = self.currentParams {
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, availablePanes: availablePanes, transition: .animated(duration: 0.4, curve: .spring))
            }
        } else if self.pendingSwitchToPaneKey != key {
            self.pendingSwitchToPaneKey = key

            if let (size, sideInset, bottomInset, visibleHeight, presentationData, availablePanes) = self.currentParams {
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, availablePanes: availablePanes, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
            guard let strongSelf = self, let (_, _, _, _, _, availablePanes) = strongSelf.currentParams, let currentPaneKey = strongSelf.currentPaneKey, let index = availablePanes.firstIndex(of: currentPaneKey) else {
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
            if let (size, sideInset, bottomInset, visibleHeight, presentationData, availablePanes) = self.currentParams, let currentPaneKey = self.currentPaneKey, let currentIndex = availablePanes.firstIndex(of: currentPaneKey) {
                self.isAdjacentLoadingEnabled = true
                let translation = recognizer.translation(in: self.view)
                var transitionFraction = translation.x / size.width
                if currentIndex <= 0 {
                    transitionFraction = min(0.0, transitionFraction)
                }
                if currentIndex >= availablePanes.count - 1 {
                    transitionFraction = max(0.0, transitionFraction)
                }
                self.transitionFraction = transitionFraction
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, availablePanes: availablePanes, transition: .immediate)
            }
        case .cancelled, .ended:
            if let (size, sideInset, bottomInset, visibleHeight, presentationData, availablePanes) = self.currentParams, let currentPaneKey = self.currentPaneKey, let currentIndex = availablePanes.firstIndex(of: currentPaneKey) {
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
                self.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, availablePanes: availablePanes, transition: .animated(duration: 0.35, curve: .spring))
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

    func updateHiddenMedia() {
        self.currentPane?.node.updateHiddenMedia()
    }
    
    func transitionNodeForGallery(messageId: EngineMessage.Id, media: EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.currentPane?.node.transitionNodeForGallery(messageId: messageId, media: media)
    }
    
    func updateSelectedMessageIds(_ selectedMessageIds: Set<EngineMessage.Id>?, animated: Bool) {
        for (_, pane) in self.currentPanes {
            pane.node.updateSelectedMessages(animated: animated)
        }
        for (_, pane) in self.pendingPanes {
            pane.pane.node.updateSelectedMessages(animated: animated)
        }
    }
        
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, availablePanes: [ChatListSearchPaneKey], transition: ContainedViewLayoutTransition) {
        let previousAvailablePanes = self.currentAvailablePanes ?? []
        self.currentAvailablePanes = availablePanes
                
        if let currentPaneKey = self.currentPaneKey, !availablePanes.contains(currentPaneKey) {
            var nextCandidatePaneKey: ChatListSearchPaneKey?
            if let index = previousAvailablePanes.firstIndex(of: currentPaneKey), index != 0 {
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
        } else if self.currentPaneKey == nil && self.pendingSwitchToPaneKey == nil {
            self.pendingSwitchToPaneKey = availablePanes.first
        }
        
        let currentIndex: Int?
        if let currentPaneKey = self.currentPaneKey {
            currentIndex = availablePanes.firstIndex(of: currentPaneKey)
        } else {
            currentIndex = nil
        }
        
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, presentationData, availablePanes)
                
        if case .forum = self.location {
            self.backgroundColor = .clear
        } else {
            self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        }
        let paneFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
        
        var visiblePaneIndices: [Int] = []
        var requiredPendingKeys: [ChatListSearchPaneKey] = []
        if let currentIndex = currentIndex {
            if currentIndex != 0 && self.isAdjacentLoadingEnabled {
                visiblePaneIndices.append(currentIndex - 1)
            }
            visiblePaneIndices.append(currentIndex)
            if currentIndex != availablePanes.count - 1 && self.isAdjacentLoadingEnabled {
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
                let pane = ChatListSearchPendingPane(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    updatedPresentationData: self.updatedPresentationData,
                    interaction: self.interaction!,
                    navigationController: self.navigationController,
                    peersFilter: self.peersFilter,
                    location: self.location,
                    searchQuery: self.searchQuery,
                    searchOptions: self.searchOptions,
                    key: key,
                    hasBecomeReady: { [weak self] key in
                        let apply: () -> Void = {
                            guard let strongSelf = self else {
                                return
                            }
                            if let (size, sideInset, bottomInset, visibleHeight, presentationData, availablePanes) = strongSelf.currentParams {
                                var transition: ContainedViewLayoutTransition = .immediate
                                if strongSelf.pendingSwitchToPaneKey == key && strongSelf.currentPaneKey != nil {
                                    transition = .animated(duration: 0.4, curve: .spring)
                                }
                                strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, availablePanes: availablePanes, transition: transition)
                            }
                        }
                        if leftScope {
                            apply()
                        }
                    }
                )
                self.pendingPanes[key] = pane
                pane.pane.node.frame = paneFrame
                pane.pane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: true, transition: .immediate)
                leftScope = true
            }
        }
                
        for (key, pane) in self.pendingPanes {
            pane.pane.node.frame = paneFrame
            pane.pane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: self.currentPaneKey == nil, transition: .immediate)
            
            if pane.isReady {
                self.pendingPanes.removeValue(forKey: key)
                self.currentPanes[key] = pane.pane
            }
        }
        
        var paneDefaultTransition = transition
        var previousPaneKey: ChatListSearchPaneKey?
        var paneSwitchAnimationOffset: CGFloat = 0.0
        
        var updatedCurrentIndex = currentIndex
        if let pendingSwitchToPaneKey = self.pendingSwitchToPaneKey, let _ = self.currentPanes[pendingSwitchToPaneKey] {
            self.pendingSwitchToPaneKey = nil
            previousPaneKey = self.currentPaneKey
            self.currentPaneKey = pendingSwitchToPaneKey
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
        
        for (key, pane) in self.currentPanes {
            if let index = availablePanes.firstIndex(of: key), let updatedCurrentIndex = updatedCurrentIndex {
                var paneWasAdded = false
                if pane.node.supernode == nil {
                    self.addSubnode(pane.node)
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
                    if let _ = strongSelf.currentParams {
                        if let currentPaneKey = strongSelf.currentPaneKey, let currentIndex = availablePanes.firstIndex(of: currentPaneKey), let paneIndex = availablePanes.firstIndex(of: key), paneIndex == 0 || abs(paneIndex - currentIndex) <= 1 {
                        } else {
                            if let pane = strongSelf.currentPanes.removeValue(forKey: key) {
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
                pane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: paneWasAdded, transition: paneTransition)
                if paneWasAdded && key == self.currentPaneKey {
                    pane.node.didBecomeFocused()
                }
            }
        }
        
        for (_, pane) in self.pendingPanes {
            let paneTransition: ContainedViewLayoutTransition = .immediate
            paneTransition.updateFrame(node: pane.pane.node, frame: paneFrame)
            pane.pane.update(size: paneFrame.size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: true, transition: paneTransition)
        }
        if !self.didSetIsReady {
            if let currentPaneKey = self.currentPaneKey, let currentPane = self.currentPanes[currentPaneKey] {
                self.didSetIsReady = true
                self.isReady.set(currentPane.node.isReady)
            } else if self.pendingSwitchToPaneKey == nil {
                self.didSetIsReady = true
                self.isReady.set(.single(true))
            }
        }
        
        self.currentPaneUpdated?(self.currentPaneKey, self.transitionFraction, transition)
    }
    
    func allCurrentMessages() -> [EngineMessage.Id: EngineMessage] {
        var allMessages: [EngineMessage.Id: EngineMessage] = [:]
        for (_, pane) in self.currentPanes {
            if let messages = pane.node.searchCurrentMessages {
                for message in messages {
                    allMessages[message.id] = message
                }
            }
        }
        return allMessages
    }
}
