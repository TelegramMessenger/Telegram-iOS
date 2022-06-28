import Foundation
import UIKit
import Display
import ComponentFlow

public final class PagerComponentChildEnvironment: Equatable {
    public struct ContentScrollingUpdate {
        public var relativeOffset: CGFloat
        public var absoluteOffsetToClosestEdge: CGFloat?
        public var transition: Transition
        
        public init(
            relativeOffset: CGFloat,
            absoluteOffsetToClosestEdge: CGFloat?,
            transition: Transition
        ) {
            self.relativeOffset = relativeOffset
            self.absoluteOffsetToClosestEdge = absoluteOffsetToClosestEdge
            self.transition = transition
        }
    }
    
    public let containerInsets: UIEdgeInsets
    public let onChildScrollingUpdate: (ContentScrollingUpdate) -> Void
    
    init(
        containerInsets: UIEdgeInsets,
        onChildScrollingUpdate: @escaping (ContentScrollingUpdate) -> Void
    ) {
        self.containerInsets = containerInsets
        self.onChildScrollingUpdate = onChildScrollingUpdate
    }
    
    public static func ==(lhs: PagerComponentChildEnvironment, rhs: PagerComponentChildEnvironment) -> Bool {
        if lhs.containerInsets != rhs.containerInsets {
            return false
        }
        
        return true
    }
}

public final class PagerComponentPanelEnvironment: Equatable {
    public let contentOffset: CGFloat
    public let contentTopPanels: [AnyComponentWithIdentity<Empty>]
    public let contentIcons: [AnyComponentWithIdentity<Empty>]
    public let contentAccessoryRightButtons: [AnyComponentWithIdentity<Empty>]
    public let activeContentId: AnyHashable?
    public let navigateToContentId: (AnyHashable) -> Void
    
    init(
        contentOffset: CGFloat,
        contentTopPanels: [AnyComponentWithIdentity<Empty>],
        contentIcons: [AnyComponentWithIdentity<Empty>],
        contentAccessoryRightButtons: [AnyComponentWithIdentity<Empty>],
        activeContentId: AnyHashable?,
        navigateToContentId: @escaping (AnyHashable) -> Void
    ) {
        self.contentOffset = contentOffset
        self.contentTopPanels = contentTopPanels
        self.contentIcons = contentIcons
        self.contentAccessoryRightButtons = contentAccessoryRightButtons
        self.activeContentId = activeContentId
        self.navigateToContentId = navigateToContentId
    }
    
    public static func ==(lhs: PagerComponentPanelEnvironment, rhs: PagerComponentPanelEnvironment) -> Bool {
        if lhs.contentOffset != rhs.contentOffset {
            return false
        }
        if lhs.contentTopPanels != rhs.contentTopPanels {
            return false
        }
        if lhs.contentIcons != rhs.contentIcons {
            return false
        }
        if lhs.contentAccessoryRightButtons != rhs.contentAccessoryRightButtons {
            return false
        }
        if lhs.activeContentId != rhs.activeContentId {
            return false
        }
        
        return true
    }
}

public struct PagerComponentPanelState {
    public var topPanelHeight: CGFloat
    
    public init(topPanelHeight: CGFloat) {
        self.topPanelHeight = topPanelHeight
    }
}

public final class PagerComponent<ChildEnvironmentType: Equatable>: Component {
    public typealias EnvironmentType = ChildEnvironmentType
    
    public let contentInsets: UIEdgeInsets
    public let contents: [AnyComponentWithIdentity<(ChildEnvironmentType, PagerComponentChildEnvironment)>]
    public let contentTopPanels: [AnyComponentWithIdentity<Empty>]
    public let contentIcons: [AnyComponentWithIdentity<Empty>]
    public let contentAccessoryRightButtons:[AnyComponentWithIdentity<Empty>]
    public let defaultId: AnyHashable?
    public let contentBackground: AnyComponent<Empty>?
    public let topPanel: AnyComponent<PagerComponentPanelEnvironment>?
    public let externalTopPanelContainer: UIView?
    public let bottomPanel: AnyComponent<PagerComponentPanelEnvironment>?
    public let panelStateUpdated: ((PagerComponentPanelState, Transition) -> Void)?
    
    public init(
        contentInsets: UIEdgeInsets,
        contents: [AnyComponentWithIdentity<(ChildEnvironmentType, PagerComponentChildEnvironment)>],
        contentTopPanels: [AnyComponentWithIdentity<Empty>],
        contentIcons: [AnyComponentWithIdentity<Empty>],
        contentAccessoryRightButtons:[AnyComponentWithIdentity<Empty>],
        defaultId: AnyHashable?,
        contentBackground: AnyComponent<Empty>?,
        topPanel: AnyComponent<PagerComponentPanelEnvironment>?,
        externalTopPanelContainer: UIView?,
        bottomPanel: AnyComponent<PagerComponentPanelEnvironment>?,
        panelStateUpdated: ((PagerComponentPanelState, Transition) -> Void)?
    ) {
        self.contentInsets = contentInsets
        self.contents = contents
        self.contentTopPanels = contentTopPanels
        self.contentIcons = contentIcons
        self.contentAccessoryRightButtons = contentAccessoryRightButtons
        self.defaultId = defaultId
        self.contentBackground = contentBackground
        self.topPanel = topPanel
        self.externalTopPanelContainer = externalTopPanelContainer
        self.bottomPanel = bottomPanel
        self.panelStateUpdated = panelStateUpdated
    }
    
    public static func ==(lhs: PagerComponent, rhs: PagerComponent) -> Bool {
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        if lhs.contents != rhs.contents {
            return false
        }
        if lhs.contentTopPanels != rhs.contentTopPanels {
            return false
        }
        if lhs.contentIcons != rhs.contentIcons {
            return false
        }
        if lhs.defaultId != rhs.defaultId {
            return false
        }
        if lhs.contentBackground != rhs.contentBackground {
            return false
        }
        if lhs.topPanel != rhs.topPanel {
            return false
        }
        if lhs.externalTopPanelContainer !== rhs.externalTopPanelContainer {
            return false
        }
        if lhs.bottomPanel != rhs.bottomPanel {
            return false
        }
        
        return true
    }
    
    public final class View: UIView {
        private final class ContentView {
            let view: ComponentHostView<(ChildEnvironmentType, PagerComponentChildEnvironment)>
            var scrollingPanelOffsetToClosestEdge: CGFloat = 0.0
                                            
            init(view: ComponentHostView<(ChildEnvironmentType, PagerComponentChildEnvironment)>) {
                self.view = view
            }
        }
        
        private struct PaneTransitionGestureState {
            var fraction: CGFloat = 0.0
        }
        
        private var contentViews: [AnyHashable: ContentView] = [:]
        private var contentBackgroundView: ComponentHostView<Empty>?
        private var topPanelView: ComponentHostView<PagerComponentPanelEnvironment>?
        private var bottomPanelView: ComponentHostView<PagerComponentPanelEnvironment>?
        
        private var centralId: AnyHashable?
        private var paneTransitionGestureState: PaneTransitionGestureState?
        
        private var component: PagerComponent<ChildEnvironmentType>?
        private weak var state: EmptyComponentState?
        
        private var panRecognizer: UIPanGestureRecognizer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.disablesInteractiveTransitionGestureRecognizer = true
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            self.panRecognizer = panRecognizer
            self.addGestureRecognizer(panRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.paneTransitionGestureState = PaneTransitionGestureState()
            case .changed:
                if var paneTransitionGestureState = self.paneTransitionGestureState, self.bounds.width > 0.0 {
                    paneTransitionGestureState.fraction = recognizer.translation(in: self).x / self.bounds.width
                    
                    self.paneTransitionGestureState = paneTransitionGestureState
                    self.state?.updated(transition: .immediate)
                }
            case .ended, .cancelled:
                if let paneTransitionGestureState = self.paneTransitionGestureState {
                    self.paneTransitionGestureState = nil
                    
                    if paneTransitionGestureState.fraction != 0.0, let component = self.component, let centralId = self.centralId, let centralIndex = component.contents.firstIndex(where: { $0.id == centralId }) {
                        let fraction = recognizer.translation(in: self).x / self.bounds.width
                        let velocity = recognizer.velocity(in: self)
                        
                        var updatedCentralIndex = centralIndex
                        if abs(velocity.x) > 180.0 {
                            if velocity.x > 0.0 {
                                updatedCentralIndex = max(0, updatedCentralIndex - 1)
                            } else {
                                updatedCentralIndex = min(component.contents.count - 1, updatedCentralIndex + 1)
                            }
                        } else if abs(fraction) > 0.35 {
                            if fraction > 0.0 {
                                updatedCentralIndex = max(0, updatedCentralIndex - 1)
                            } else {
                                updatedCentralIndex = min(component.contents.count - 1, updatedCentralIndex + 1)
                            }
                        }
                        if updatedCentralIndex != centralIndex {
                            self.centralId = component.contents[updatedCentralIndex].id
                        }
                    }
                    
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            default:
                break
            }
        }
        
        func update(component: PagerComponent<ChildEnvironmentType>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let navigateToContentId: (AnyHashable) -> Void = { [weak self] id in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.centralId != id {
                    strongSelf.centralId = id
                    strongSelf.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            }
            
            var centralId: AnyHashable?
            if let current = self.centralId {
                if component.contents.contains(where: { $0.id == current }) {
                    centralId = current
                }
            }
            if centralId == nil {
                if let defaultId = component.defaultId {
                    if component.contents.contains(where: { $0.id == defaultId }) {
                        centralId = defaultId
                    }
                } else {
                    centralId = component.contents.first?.id
                }
            }
            
            if self.centralId != centralId {
                self.centralId = centralId
            }
            
            var contentInsets = component.contentInsets
            
            let scrollingPanelOffsetToClosestEdge: CGFloat
            if let centralId = centralId, let centralContentView = self.contentViews[centralId] {
                scrollingPanelOffsetToClosestEdge = centralContentView.scrollingPanelOffsetToClosestEdge
            } else {
                scrollingPanelOffsetToClosestEdge = 0.0
            }
            
            var topPanelHeight: CGFloat = 0.0
            if let topPanel = component.topPanel {
                let topPanelView: ComponentHostView<PagerComponentPanelEnvironment>
                var topPanelTransition = transition
                if let current = self.topPanelView {
                    topPanelView = current
                } else {
                    topPanelTransition = .immediate
                    topPanelView = ComponentHostView<PagerComponentPanelEnvironment>()
                    topPanelView.clipsToBounds = true
                    self.topPanelView = topPanelView
                }
                
                let topPanelSuperview = component.externalTopPanelContainer ?? self
                if topPanelView.superview !== topPanelSuperview {
                    topPanelSuperview.addSubview(topPanelView)
                }
                
                let topPanelSize = topPanelView.update(
                    transition: topPanelTransition,
                    component: topPanel,
                    environment: {
                        PagerComponentPanelEnvironment(
                            contentOffset: 0.0,
                            contentTopPanels: component.contentTopPanels,
                            contentIcons: [],
                            contentAccessoryRightButtons: [],
                            activeContentId: centralId,
                            navigateToContentId: navigateToContentId
                        )
                    },
                    containerSize: availableSize
                )
                
                let topPanelOffset = max(0.0, min(topPanelSize.height, scrollingPanelOffsetToClosestEdge))
                
                topPanelHeight = max(0.0, topPanelSize.height - topPanelOffset)
                
                if component.externalTopPanelContainer != nil {
                    let visibleTopPanelHeight = max(0.0, topPanelSize.height - topPanelOffset)
                    transition.setFrame(view: topPanelView, frame: CGRect(origin: CGPoint(), size: CGSize(width: topPanelSize.width, height: visibleTopPanelHeight)))
                } else {
                    transition.setFrame(view: topPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: -topPanelOffset), size: topPanelSize))
                }
                
                contentInsets.top += topPanelSize.height
            } else {
                if let bottomPanelView = self.bottomPanelView {
                    self.bottomPanelView = nil
                    
                    bottomPanelView.removeFromSuperview()
                }
            }
            
            var bottomPanelOffset: CGFloat = 0.0
            if let bottomPanel = component.bottomPanel {
                let bottomPanelView: ComponentHostView<PagerComponentPanelEnvironment>
                var bottomPanelTransition = transition
                if let current = self.bottomPanelView {
                    bottomPanelView = current
                } else {
                    bottomPanelTransition = .immediate
                    bottomPanelView = ComponentHostView<PagerComponentPanelEnvironment>()
                    self.bottomPanelView = bottomPanelView
                    self.addSubview(bottomPanelView)
                }
                let bottomPanelSize = bottomPanelView.update(
                    transition: bottomPanelTransition,
                    component: bottomPanel,
                    environment: {
                        PagerComponentPanelEnvironment(
                            contentOffset: 0.0,
                            contentTopPanels: [],
                            contentIcons: component.contentIcons,
                            contentAccessoryRightButtons: component.contentAccessoryRightButtons,
                            activeContentId: centralId,
                            navigateToContentId: navigateToContentId
                        )
                    },
                    containerSize: availableSize
                )
                
                bottomPanelOffset = max(0.0, min(bottomPanelSize.height, scrollingPanelOffsetToClosestEdge))
                
                transition.setFrame(view: bottomPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelSize.height + bottomPanelOffset), size: bottomPanelSize))
                
                contentInsets.bottom += bottomPanelSize.height
            } else {
                if let bottomPanelView = self.bottomPanelView {
                    self.bottomPanelView = nil
                    
                    bottomPanelView.removeFromSuperview()
                }
            }
            
            if let contentBackground = component.contentBackground {
                let contentBackgroundView: ComponentHostView<Empty>
                var contentBackgroundTransition = transition
                if let current = self.contentBackgroundView {
                    contentBackgroundView = current
                } else {
                    contentBackgroundTransition = .immediate
                    contentBackgroundView = ComponentHostView<Empty>()
                    self.contentBackgroundView = contentBackgroundView
                    self.insertSubview(contentBackgroundView, at: 0)
                }
                let contentBackgroundSize = contentBackgroundView.update(
                    transition: contentBackgroundTransition,
                    component: contentBackground,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height - topPanelHeight - contentInsets.bottom + bottomPanelOffset)
                )
                contentBackgroundTransition.setFrame(view: contentBackgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight), size: contentBackgroundSize))
            } else {
                if let contentBackgroundView = self.contentBackgroundView {
                    self.contentBackgroundView = nil
                    contentBackgroundView.removeFromSuperview()
                }
            }
            
            var validIds: [AnyHashable] = []
            if let centralId = self.centralId, let centralIndex = component.contents.firstIndex(where: { $0.id == centralId }) {
                let contentSize = CGSize(width: availableSize.width, height: availableSize.height)
                
                var referenceFrames: [AnyHashable: CGRect] = [:]
                if case .none = transition.animation {
                } else {
                    for (id, contentView) in self.contentViews {
                        referenceFrames[id] = contentView.view.frame
                    }
                }
                
                for index in 0 ..< component.contents.count {
                    let indexOffset = index - centralIndex
                    let clippedIndexOffset = max(-1, min(1, indexOffset))
                    var checkingContentFrame = CGRect(origin: CGPoint(x: contentSize.width * CGFloat(indexOffset), y: 0.0), size: contentSize)
                    var contentFrame = CGRect(origin: CGPoint(x: contentSize.width * CGFloat(clippedIndexOffset), y: 0.0), size: contentSize)
                    
                    if let paneTransitionGestureState = self.paneTransitionGestureState {
                        checkingContentFrame.origin.x += paneTransitionGestureState.fraction * availableSize.width
                        contentFrame.origin.x += paneTransitionGestureState.fraction * availableSize.width
                    }
                    let content = component.contents[index]
                    
                    let isInBounds = CGRect(origin: CGPoint(), size: availableSize).intersects(checkingContentFrame)
                    
                    var isPartOfTransition = false
                    if case .none = transition.animation {
                    } else if self.contentViews[content.id] != nil {
                        isPartOfTransition = true
                    }
                    
                    if isInBounds || isPartOfTransition || content.id == centralId {
                        let id = content.id
                        validIds.append(content.id)
                        
                        var wasAdded = false
                        var contentTransition = transition
                        let contentView: ContentView
                        if let current = self.contentViews[content.id] {
                            contentView = current
                        } else {
                            wasAdded = true
                            contentView = ContentView(view: ComponentHostView<(ChildEnvironmentType, PagerComponentChildEnvironment)>())
                            contentTransition = .immediate
                            self.contentViews[content.id] = contentView
                            if let contentBackgroundView = self.contentBackgroundView {
                                self.insertSubview(contentView.view, aboveSubview: contentBackgroundView)
                            } else {
                                self.insertSubview(contentView.view, at: 0)
                            }
                        }
                        
                        let pagerChildEnvironment = PagerComponentChildEnvironment(
                            containerInsets: contentInsets,
                            onChildScrollingUpdate: { [weak self] update in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.onChildScrollingUpdate(id: id, update: update)
                            }
                        )
                        
                        let _ = contentView.view.update(
                            transition: contentTransition,
                            component: content.component,
                            environment: {
                                environment[ChildEnvironmentType.self]
                                pagerChildEnvironment
                            },
                            containerSize: contentFrame.size
                        )
                        
                        if wasAdded {
                            if case .none = transition.animation {
                                contentView.view.frame = contentFrame
                            } else {
                                var referenceDirectionIsRight: Bool?
                                for (previousId, previousFrame) in referenceFrames {
                                    if let previousIndex = component.contents.firstIndex(where: { $0.id == previousId }) {
                                        if previousFrame.minX == 0.0 {
                                            if previousIndex < index {
                                                referenceDirectionIsRight = true
                                            } else {
                                                referenceDirectionIsRight = false
                                            }
                                            break
                                        }
                                    }
                                }
                                if let referenceDirectionIsRight = referenceDirectionIsRight {
                                    contentView.view.frame = contentFrame.offsetBy(dx: referenceDirectionIsRight ? contentFrame.width : (-contentFrame.width), dy: 0.0)
                                    transition.setFrame(view: contentView.view, frame: contentFrame, completion: { [weak self] completed in
                                        if completed && !isInBounds && isPartOfTransition {
                                            DispatchQueue.main.async {
                                                self?.state?.updated(transition: .immediate)
                                            }
                                        }
                                    })
                                } else {
                                    contentView.view.frame = contentFrame
                                }
                            }
                        } else {
                            transition.setFrame(view: contentView.view, frame: contentFrame, completion: { [weak self] completed in
                                if completed && !isInBounds && isPartOfTransition {
                                    DispatchQueue.main.async {
                                        self?.state?.updated(transition: .immediate)
                                    }
                                }
                            })
                        }
                    }
                }
            }
            
            var removedIds: [AnyHashable] = []
            for (id, _) in self.contentViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                }
            }
            for id in removedIds {
                self.contentViews.removeValue(forKey: id)?.view.removeFromSuperview()
            }
            
            if let panelStateUpdated = component.panelStateUpdated {
                panelStateUpdated(
                    PagerComponentPanelState(
                        topPanelHeight: topPanelHeight
                    ),
                    transition
                )
            }
            
            return availableSize
        }
        
        private func onChildScrollingUpdate(id: AnyHashable, update: PagerComponentChildEnvironment.ContentScrollingUpdate) {
            guard let contentView = self.contentViews[id] else {
                return
            }
            
            if let absoluteOffsetToClosestEdge = update.absoluteOffsetToClosestEdge {
                contentView.scrollingPanelOffsetToClosestEdge = absoluteOffsetToClosestEdge
            } else {
                contentView.scrollingPanelOffsetToClosestEdge = 1000.0
            }

            state?.updated(transition: update.transition)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
