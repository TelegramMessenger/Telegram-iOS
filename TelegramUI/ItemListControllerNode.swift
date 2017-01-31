import Foundation
import Display
import SwiftSignalKit
import TelegramCore

typealias ItemListSectionId = Int32

protocol ItemListNodeEntry: Equatable, Comparable, Identifiable {
    associatedtype ItemGenerationArguments
    
    var section: ItemListSectionId { get }
    
    func item(_ arguments: ItemGenerationArguments) -> ListViewItem
}

private struct ItemListNodeEntryTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedItemListNodeEntryTransition<Entry: ItemListNodeEntry>(from fromEntries: [Entry], to toEntries: [Entry], arguments: Entry.ItemGenerationArguments) -> ItemListNodeEntryTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(arguments), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(arguments), directionHint: nil) }
    
    return ItemListNodeEntryTransition(deletions: deletions, insertions: insertions, updates: updates)
}

enum ItemListStyle {
    case plain
    case blocks
}

private struct ItemListNodeTransition {
    let entries: ItemListNodeEntryTransition
    let updateStyle: ItemListStyle?
    let firstTime: Bool
    let animated: Bool
}

struct ItemListNodeState<Entry: ItemListNodeEntry> {
    let entries: [Entry]
    let style: ItemListStyle
}

final class ItemListNode<Entry: ItemListNodeEntry>: ASDisplayNode {
    private var _ready = ValuePromise<Bool>()
    public var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    private var didSetReady = false
    
    private let listNode: ListView
    private let transitionDisposable = MetaDisposable()
    
    private var enqueuedTransitions: [ItemListNodeTransition] = []
    private var hadValidLayout = false
    
    var dismiss: (() -> Void)?
    
    init(state: Signal<(ItemListNodeState<Entry>, Entry.ItemGenerationArguments), NoError>) {
        self.listNode = ListView()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.addSubnode(self.listNode)
        
        self.backgroundColor = UIColor(0xefeff4)
        
        let previousState = Atomic<ItemListNodeState<Entry>?>(value: nil)
        self.transitionDisposable.set(((state |> map { state, arguments -> ItemListNodeTransition in
            assert(state.entries == state.entries.sorted())
            let previous = previousState.swap(state)
            let transition = preparedItemListNodeEntryTransition(from: previous?.entries ?? [], to: state.entries, arguments: arguments)
            var updatedStyle: ItemListStyle?
            if previous?.style != state.style {
                updatedStyle = state.style
            }
            return ItemListNodeTransition(entries: transition, updateStyle: updatedStyle, firstTime: previous == nil, animated: previous != nil)
        }) |> deliverOnMainQueue).start(next: { [weak self] transition in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        }))
    }
    
    deinit {
        self.transitionDisposable.dispose()
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hadValidLayout {
            self.hadValidLayout = true
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: ItemListNodeTransition) {
        self.enqueuedTransitions.append(transition)
        if self.hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while !self.enqueuedTransitions.isEmpty {
            let transition = self.enqueuedTransitions.removeFirst()
            
            if let updateStyle = transition.updateStyle {
                switch updateStyle {
                case .plain:
                    self.backgroundColor = .white
                case .blocks:
                    self.backgroundColor = UIColor(0xefeff4)
                }
            }
            var options = ListViewDeleteAndInsertOptions()
            if transition.firstTime {
                options.insert(.Synchronous)
                options.insert(.LowLatency)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            self.listNode.transaction(deleteIndices: transition.entries.deletions, insertIndicesAndItems: transition.entries.insertions, updateIndicesAndItems: transition.entries.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            })
        }
    }
}
