import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData

private func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    }
    for subview in view.subviews {
        if hasFirstResponder(subview) {
            return true
        }
    }
    return false
}

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
    var dateTimeFormat: PresentationDateTimeFormat
    
    func isEqual(to: FormControllerPresentationState) -> Bool {
        if self.theme !== to.theme {
            return false
        }
        if self.strings !== to.strings {
            return false
        }
        if self.dateTimeFormat != to.dateTimeFormat {
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

public struct FormControllerState<InnerState: FormControllerInnerState> {
    let layoutState: FormControllerLayoutState
    let presentationState: FormControllerPresentationState
    let innerState: InnerState
}

public enum FormControllerItemEntry<Entry: FormControllerEntry> {
    case entry(Entry)
    case spacer
}

public protocol FormControllerInnerState {
    associatedtype Entry: FormControllerEntry
    
    func isEqual(to: Self) -> Bool
    func entries() -> [FormControllerItemEntry<Entry>]
}

private enum FilteredItemNeighbor {
    case spacer
    case item(FormControllerItem)
}

public class FormControllerNode<InitParams, InnerState: FormControllerInnerState>: ViewControllerTracingNode, UIScrollViewDelegate {
    private typealias InternalState = FormControllerInternalState<InnerState>
    typealias State = FormControllerState<InnerState>
    typealias Entry = InnerState.Entry
    
    private var internalState: InternalState
    var innerState: InnerState? {
        return self.internalState.innerState
    }
    
    var layoutState: FormControllerLayoutState? {
        return self.internalState.layoutState
    }
    
    let scrollNode: FormControllerScrollerNode
    
    private var appliedLayout: FormControllerLayoutState?
    private var appliedEntries: [Entry] = []
    private(set) var itemNodes: [ASDisplayNode & FormControllerItemNode] = []
    
    var present: (ViewController, Any?) -> Void = { _, _ in }
    
    var itemParams: Entry.ItemParams {
        preconditionFailure()
    }
    
    required public init(initParams: InitParams, presentationData: PresentationData) {
        self.internalState = FormControllerInternalState(layoutState: nil, presentationState: FormControllerPresentationState(theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat), innerState: nil)
        
        self.scrollNode = FormControllerScrollerNode()
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.scrollNode.backgroundColor = nil
        self.scrollNode.isOpaque = false
        self.scrollNode.delegate = self
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.view.delaysContentTouches = true
        self.scrollNode.touchesPrevented = { [weak self] position in
            guard let strongSelf = self else {
                return false
            }
            
            for i in 0 ..< strongSelf.itemNodes.count {
                if strongSelf.itemNodes[i].preventsTouchesToOtherItems {
                    if let node = strongSelf.itemNodeAtPoint(position), node === strongSelf.itemNodes[i]  {
                        return false
                    }
                    strongSelf.itemNodes[i].touchesToOtherItemsPrevented()
                    return true
                }
            }
            
            return false
        }
    }
    
    func itemNodeAtPoint(_ point: CGPoint) -> (ASDisplayNode & FormControllerItemNode)? {
        for node in self.itemNodes {
            if node.frame.contains(point) {
                return node
            }
        }
        return nil
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
    
    private weak var preivousItemNodeWithFocus: (ASDisplayNode & FormControllerItemNode)?
    
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
                let item = entry.item(params: self.itemParams, strings: state.presentationState.strings)
                
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
        
        var applyLayouts: [(ContainedViewLayoutTransition, FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat)] = []
        
        var itemNodeIndex = 0
        for i in 0 ..< filteredItemNeighbors.count {
            if case let .item(item) = filteredItemNeighbors[i] {
                let previousNeighbor: FormControllerItemNeighbor
                let nextNeighbor: FormControllerItemNeighbor
                if i != 0 {
                    switch filteredItemNeighbors[i - 1] {
                        case .spacer:
                            previousNeighbor = .spacer
                        case .item:
                            previousNeighbor = .item(itemNodes[itemNodeIndex - 1])
                    }
                } else {
                    previousNeighbor = .none
                }
                if i != filteredItemNeighbors.count - 1 {
                    switch filteredItemNeighbors[i + 1] {
                        case .spacer:
                            nextNeighbor = .spacer
                        case .item:
                            nextNeighbor = .item(itemNodes[itemNodeIndex + 1])
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
                
                let (preLayout, apply) = item.update(node: itemNodes[itemNodeIndex], theme: state.presentationState.theme, strings: state.presentationState.strings, dateTimeFormat: state.presentationState.dateTimeFormat, width: layout.size.width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: itemTransition)
                applyLayouts.append((itemTransition, preLayout, apply))
                
                itemNodeIndex += 1
            }
        }
        
        var commonAligningInset: CGFloat = 0.0
        for i in 0 ..< itemNodes.count {
            commonAligningInset = max(commonAligningInset, applyLayouts[i].1.aligningInset)
        }
        
        var contentHeight: CGFloat = 0.0
        
        itemNodeIndex = 0
        for i in 0 ..< filteredItemNeighbors.count {
            if case .item = filteredItemNeighbors[i] {
                let itemNode = itemNodes[itemNodeIndex]
                let (itemTransition, _, apply) = applyLayouts[itemNodeIndex]
                
                let itemHeight = apply(FormControllerItemLayoutParams(maxAligningInset: commonAligningInset))
                itemTransition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: itemHeight)))
                contentHeight += itemHeight
                itemNodeIndex += 1
            } else {
                contentHeight += 35.0
            }
        }
        
        contentHeight += 36.0
        
        let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
        
        let previousBoundsOrigin = self.scrollNode.bounds.origin
        self.scrollNode.view.ignoreUpdateBounds = true
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.scrollNode.view.contentSize = scrollContentSize
        self.scrollNode.view.contentInset = insets
        self.scrollNode.view.scrollIndicatorInsets = insets
        self.scrollNode.view.ignoreUpdateBounds = false
        
        var updatedItemNodeWithFocus: (ASDisplayNode & FormControllerItemNode)?
        for itemNode in self.itemNodes {
            if hasFirstResponder(itemNode.view) {
                if self.preivousItemNodeWithFocus !== itemNode {
                    self.preivousItemNodeWithFocus = itemNode
                    updatedItemNodeWithFocus = itemNode
                }
                break
            }
        }
        
        if let previousLayout = previousLayout {
            var previousInsets = previousLayout.layout.insets(options: [.input])
            previousInsets.top += max(previousLayout.navigationHeight, previousLayout.layout.insets(options: [.statusBar]).top)
            let insetsScrollOffset = insets.top - previousInsets.top
            
            let negativeOverscroll = min(previousBoundsOrigin.y + insets.top, 0.0)
            let cleanOrigin = max(previousBoundsOrigin.y, -insets.top)
            
            var contentOffset = CGPoint(x: 0.0, y: cleanOrigin + insetsScrollOffset)
            contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
            contentOffset.y = max(contentOffset.y, -insets.top)
            contentOffset.y += negativeOverscroll
            
            if let updatedItemNodeWithFocus = updatedItemNodeWithFocus {
                let itemRect = updatedItemNodeWithFocus.view.convert(updatedItemNodeWithFocus.view.bounds, to: self.scrollNode.view)
                if contentOffset.y + layout.size.height - insets.bottom < itemRect.maxY + 4.0 {
                    contentOffset.y = itemRect.maxY + 4.0 - (layout.size.height - insets.bottom)
                }
            }
            
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        } else {
            let contentOffset = CGPoint(x: 0.0, y: -insets.top)
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        }
        
        if previousLayout == nil {
            self.didAppear()
        }
    }
    
    func didAppear() {
        
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    func enumerateItemsAndEntries(_ f: (InnerState.Entry, ASDisplayNode & FormControllerItemNode) -> Bool) {
        for i in 0 ..< self.appliedEntries.count {
            if !f(self.appliedEntries[i], self.itemNodes[i]) {
                break
            }
        }
    }
    
    func forceUpdateState(transition: ContainedViewLayoutTransition) {
        if let layoutState = self.layoutState, let innerState = self.innerState {
            self.stateUpdated(state: FormControllerState(layoutState: layoutState, presentationState: self.internalState.presentationState, innerState: innerState), transition: transition)
        }
    }
    
    func scrollToItemNode(_ itemNode: ASDisplayNode & FormControllerItemNode) {
        self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: max(0.0, min(itemNode.frame.minY, self.scrollNode.view.contentSize.height - self.scrollNode.view.frame.height)))
    }
}
