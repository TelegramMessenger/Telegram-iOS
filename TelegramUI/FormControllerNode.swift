import Foundation
import SwiftSignalKit
import AsyncDisplayKit
import Display

struct FormControllerLayoutState {
    var layout: ContainerViewLayout
    var navigationHeight: CGFloat
    
    func isEqual(to: FormControllerLayoutState) -> Bool {
        if self.layout != to.layout {
            return false
        }
        if self.navigationHeight != to.navigationHeight {
            return false
        }
        return true
    }
}

struct FormControllerPresentationState {
    var theme: PresentationTheme
    var strings: PresentationStrings
    
    func isEqual(to: FormControllerPresentationState) -> Bool {
        if self.theme !== to.theme {
            return false
        }
        if self.strings !== to.strings {
            return false
        }
        return true
    }
}

struct FormControllerInternalState<InnerState: FormControllerInnerState> {
    var layoutState: FormControllerLayoutState?
    var presentationState: FormControllerPresentationState
    var innerState: InnerState?
    
    func isEqual(to: FormControllerInternalState) -> Bool {
        if let lhsLayoutState = self.layoutState, let rhsLayoutState = to.layoutState {
            if !lhsLayoutState.isEqual(to: rhsLayoutState) {
                return false
            }
        } else if (self.layoutState != nil) != (to.layoutState != nil) {
            return false
        }
        
        if !self.presentationState.isEqual(to: to.presentationState) {
            return false
        }
        
        if let lhsInnerState = self.innerState, let rhsInnerState = to.innerState {
            if !lhsInnerState.isEqual(to: rhsInnerState) {
                return false
            }
        } else if (self.innerState != nil) != (to.innerState != nil) {
            return false
        }
        
        return true
    }
}

struct FormControllerState<InnerState: FormControllerInnerState> {
    let layoutState: FormControllerLayoutState
    let presentationState: FormControllerPresentationState
    let innerState: InnerState
}

enum FormControllerItemEntry<Entry: FormControllerEntry> {
    case entry(Entry)
    case spacer
}

protocol FormControllerInnerState {
    associatedtype Entry: FormControllerEntry
    
    func isEqual(to: Self) -> Bool
    func entries() -> [FormControllerItemEntry<Entry>]
}

private enum FilteredItemNeighbor {
    case spacer
    case item(FormControllerItem)
}

class FormControllerNode<InnerState: FormControllerInnerState>: ViewControllerTracingNode, UIScrollViewDelegate {
    private typealias InternalState = FormControllerInternalState<InnerState>
    typealias State = FormControllerState<InnerState>
    typealias Entry = InnerState.Entry
    
    private var internalState: InternalState
    
    private let scrollNode: FormControllerScrollerNode
    
    private var appliedLayout: FormControllerLayoutState?
    private var appliedEntries: [Entry] = []
    private var itemNodes: [ASDisplayNode & FormControllerItemNode] = []
    
    required init(theme: PresentationTheme, strings: PresentationStrings) {
        self.internalState = FormControllerInternalState(layoutState: nil, presentationState: FormControllerPresentationState(theme: theme, strings: strings), innerState: nil)
        
        self.scrollNode = FormControllerScrollerNode()
        
        super.init()
        
        self.backgroundColor = theme.list.blocksBackgroundColor
        
        self.scrollNode.backgroundColor = nil
        self.scrollNode.isOpaque = false
        self.scrollNode.delegate = self
        
        self.addSubnode(self.scrollNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.updateInternalState(transition: transition, { state in
            var state = state
            state.layoutState = FormControllerLayoutState(layout: layout, navigationHeight: navigationHeight)
            return state
        })
    }
    
    func updateInnerState(transition: ContainedViewLayoutTransition, with innerState: InnerState) {
        self.updateInternalState(transition: transition, { state in
            var state = state
            state.innerState = innerState
            return state
        })
    }
    
    private func updateInternalState(transition: ContainedViewLayoutTransition, _ f: (InternalState) -> InternalState) {
        let updated = f(self.internalState)
        if !updated.isEqual(to: self.internalState) {
            self.internalState = updated
            if let layoutState = updated.layoutState, let innerState = updated.innerState {
                self.stateUpdated(state: FormControllerState(layoutState: layoutState, presentationState: updated.presentationState, innerState: innerState), transition: transition)
            }
        }
    }
    
    func stateUpdated(state: State, transition: ContainedViewLayoutTransition) {
        let previousLayout = self.appliedLayout
        self.appliedLayout = state.layoutState
        
        let layout = state.layoutState.layout
        var insets = layout.insets(options: [.input])
        insets.top += max(state.layoutState.navigationHeight, layout.insets(options: [.statusBar]).top)
        
        let entries = state.innerState.entries()
        var filteredEntries: [Entry] = []
        var filteredItemNeighbors: [FilteredItemNeighbor] = []
        var itemNodes: [ASDisplayNode & FormControllerItemNode] = []
        var insertedItemNodeIndices = Set<Int>()
        
        for i in 0 ..< entries.count {
            if case let .entry(entry) = entries[i] {
                let item = entry.item(strings: state.presentationState.strings)
                
                filteredEntries.append(entry)
                filteredItemNeighbors.append(.item(item))
                
                var found = false
                inner: for j in 0 ..< self.appliedEntries.count {
                    if entry.stableId == self.appliedEntries[j].stableId {
                        itemNodes.append(self.itemNodes[j])
                        found = true
                        break inner
                    }
                }
                if !found {
                    let itemNode = item.node()
                    insertedItemNodeIndices.insert(itemNodes.count)
                    itemNodes.append(itemNode)
                    self.scrollNode.addSubnode(itemNode)
                }
            } else {
                filteredItemNeighbors.append(.spacer)
            }
        }
        
        for itemNode in self.itemNodes {
            var found = false
            inner: for updated in itemNodes {
                if updated === itemNode {
                    found = true
                    break inner
                }
            }
            if !found {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        self.appliedEntries = filteredEntries
        self.itemNodes = itemNodes
        
        var contentHeight: CGFloat = 0.0
        
        var itemNodeIndex = 0
        for i in 0 ..< filteredItemNeighbors.count {
            if case let .item(item) = filteredItemNeighbors[i] {
                let previousNeighbor: FormControllerItemNeighbor
                let nextNeighbor: FormControllerItemNeighbor
                if i != 0 {
                    switch filteredItemNeighbors[i - 1] {
                        case .spacer:
                            previousNeighbor = .spacer
                        case let .item(item):
                            previousNeighbor = .item(item)
                    }
                } else {
                    previousNeighbor = .none
                }
                if i != filteredItemNeighbors.count - 1 {
                    switch filteredItemNeighbors[i + 1] {
                        case .spacer:
                            nextNeighbor = .spacer
                        case let .item(item):
                            nextNeighbor = .item(item)
                    }
                } else {
                    nextNeighbor = .none
                }
                
                let itemTransition: ContainedViewLayoutTransition
                if insertedItemNodeIndices.contains(i) {
                    itemTransition = .immediate
                } else {
                    itemTransition = transition
                }
                
                let itemHeight = item.update(node: itemNodes[itemNodeIndex], theme: state.presentationState.theme, strings: state.presentationState.strings, width: layout.size.width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: itemTransition)
                itemTransition.updateFrame(node: itemNodes[itemNodeIndex], frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: itemHeight)))
                contentHeight += itemHeight
                
                itemNodeIndex += 1
            }
        }
        
        let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
        
        let previousBoundsOrigin = self.scrollNode.bounds.origin
        self.scrollNode.view.ignoreUpdateBounds = true
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.scrollNode.view.contentSize = scrollContentSize
        self.scrollNode.view.contentInset = insets
        self.scrollNode.view.scrollIndicatorInsets = insets
        self.scrollNode.view.ignoreUpdateBounds = false
        
        if let previousLayout = previousLayout {
            var previousInsets = previousLayout.layout.insets(options: [.input])
            previousInsets.top += max(previousLayout.navigationHeight, previousLayout.layout.insets(options: [.statusBar]).top)
            let insetsScrollOffset = insets.top - previousInsets.top
            
            var contentOffset = CGPoint(x: 0.0, y: previousBoundsOrigin.y + insetsScrollOffset)
            contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
            contentOffset.y = max(contentOffset.y, -insets.top)
            
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        } else {
            let contentOffset = CGPoint(x: 0.0, y: -insets.top)
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
}
