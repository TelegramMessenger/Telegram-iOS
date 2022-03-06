import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import MergeLists
import AccountContext
import TelegramStringFormatting

private struct BadPasscodeAttemptListEntry: Comparable, Identifiable {
    var bpa: BadPasscodeAttempt
    
    var stableId: CFAbsoluteTime {
        return self.bpa.date
    }
    
    static func ==(lhs: BadPasscodeAttemptListEntry, rhs: BadPasscodeAttemptListEntry) -> Bool {
        return lhs.bpa == rhs.bpa
    }
    
    static func <(lhs: BadPasscodeAttemptListEntry, rhs: BadPasscodeAttemptListEntry) -> Bool {
        return lhs.bpa.date < rhs.bpa.date
    }
    
    func item(presentationData: PresentationData) -> ListViewItem {
        var text = bpa.type == BadPasscodeAttempt.AppUnlockType ? presentationData.strings.PasscodeSettings_BadAttempts_AppLogin : presentationData.strings.PasscodeSettings_BadAttempts_SettingsLogin
        
        if bpa.isFakePasscode {
            text += "\n" + presentationData.strings.PasscodeSettings_BadAttempts_FakePasscode
        }
        
        text += "\n" + stringForFullDate(timestamp: Int32(bpa.date + NSTimeIntervalSince1970), strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
        
        return ItemListMultilineTextItem(presentationData: ItemListPresentationData(presentationData), text: text, enabledEntityTypes: [], sectionId: 0, style: .blocks)
    }
}

private struct BadPasscodeAttemptListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedBadPasscodeAttemptListNodeTransition(presentationData: PresentationData, from fromEntries: [BadPasscodeAttemptListEntry], to toEntries: [BadPasscodeAttemptListEntry], forceUpdate: Bool) -> BadPasscodeAttemptListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData), directionHint: nil) }
    
    return BadPasscodeAttemptListNodeTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class BadPasscodeAttemptsControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var didSetReady = false
    let _ready = ValuePromise<Bool>()
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    let listNode: ListView
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    private var queuedTransitions: [BadPasscodeAttemptListNodeTransition] = []
    
    private let presentationDataValue = Promise<PresentationData>()
    private var listDisposable: Disposable?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        
        self.listNode = ListView()
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.list.blocksBackgroundColor, direction: true)
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.addSubnode(self.listNode)
        
        let previousEntriesHolder = Atomic<([BadPasscodeAttemptListEntry], PresentationTheme, PresentationStrings)?>(value: nil)
        self.listDisposable = combineLatest(queue: .mainQueue(), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), self.presentationDataValue.get()).start(next: { [weak self] sharedData, presentationData in
            guard let strongSelf = self else {
                return
            }
            
            let passcodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]?.get(PresentationPasscodeSettings.self)
            let entries = (passcodeSettings?.badPasscodeAttempts ?? []).sorted(by: { l, r in
                return l.date > r.date
            }).map { BadPasscodeAttemptListEntry(bpa: $0) }
            
            let previousEntriesAndPresentationData = previousEntriesHolder.swap((entries, presentationData.theme, presentationData.strings))
            let transition = preparedBadPasscodeAttemptListNodeTransition(presentationData: presentationData, from: previousEntriesAndPresentationData?.0 ?? [], to: entries, forceUpdate: previousEntriesAndPresentationData?.1 !== presentationData.theme || previousEntriesAndPresentationData?.2 !== presentationData.strings)
            
            strongSelf.enqueueTransition(transition)
        })
        
        self.listNode.itemNodeHitTest = { [weak self] point in
            if let strongSelf = self {
                return point.x > strongSelf.leftOverlayNode.frame.maxX && point.x < strongSelf.rightOverlayNode.frame.minX
            } else {
                return true
            }
        }
    }
    
    deinit {
        self.listDisposable?.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationDataValue.set(.single(presentationData))
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.list.blocksBackgroundColor, direction: true)
        self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.containerLayout != nil
        self.containerLayout = (layout, navigationBarHeight)
        
        var listInsets = layout.insets(options: [.input])
        listInsets.top += navigationBarHeight
        if layout.size.width >= 375.0 {
            let inset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
            listInsets.left += inset
            listInsets.right += inset
        } else {
            listInsets.left += layout.safeInsets.left
            listInsets.right += layout.safeInsets.right
        }
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: listInsets.left, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - listInsets.right, y: 0.0, width: listInsets.right, height: layout.size.height)
        
        if self.leftOverlayNode.supernode == nil {
            self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.listNode)
        }
        if self.rightOverlayNode.supernode == nil {
            self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.listNode)
        }
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: listInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: BadPasscodeAttemptListNodeTransition) {
        self.queuedTransitions.append(transition)
        
        if self.containerLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        guard let _ = self.containerLayout else {
            return
        }
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            
            let options: ListViewDeleteAndInsertOptions = [.Synchronous, .LowLatency]
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            })
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
