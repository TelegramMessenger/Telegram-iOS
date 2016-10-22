import Foundation
import Display
import Postbox
import SwiftSignalKit
import TelegramCore

final class PeerInfoControllerInteraction {
    let updateState: ((PeerInfoState?) -> PeerInfoState?) -> Void
    let openSharedMedia: () -> Void
    let changeNotificationMuteSettings: () -> Void
    let openPeerInfo: (PeerId) -> Void
    
    init(updateState: @escaping ((PeerInfoState?) -> PeerInfoState?) -> Void, openSharedMedia: @escaping () -> Void, changeNotificationMuteSettings: @escaping () -> Void, openPeerInfo: @escaping (PeerId) -> Void) {
        self.updateState = updateState
        self.openSharedMedia = openSharedMedia
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openPeerInfo = openPeerInfo
    }
}

private struct PeerInfoSortableStableId: Hashable {
    let id: PeerInfoEntryStableId
    
    static func ==(lhs: PeerInfoSortableStableId, rhs: PeerInfoSortableStableId) -> Bool {
        return lhs.id.isEqual(to: rhs.id)
    }
    
    var hashValue: Int {
        return self.id.hashValue
    }
}

private struct PeerInfoSortableEntry: Identifiable, Comparable {
    let entry: PeerInfoEntry
    
    var stableId: PeerInfoSortableStableId {
        return PeerInfoSortableStableId(id: self.entry.stableId)
    }
    
    static func ==(lhs: PeerInfoSortableEntry, rhs: PeerInfoSortableEntry) -> Bool {
        return lhs.entry.isEqual(to: rhs.entry)
    }
    
    static func <(lhs: PeerInfoSortableEntry, rhs: PeerInfoSortableEntry) -> Bool {
        return lhs.entry.isOrderedBefore(rhs.entry)
    }
}

private struct PeerInfoEntryTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedPeerInfoEntryTransition(account: Account, from fromEntries: [PeerInfoSortableEntry], to toEntries: [PeerInfoSortableEntry], interaction: PeerInfoControllerInteraction) -> PeerInfoEntryTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.entry.item(account: account, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.entry.item(account: account, interaction: interaction), directionHint: nil) }
    
    return PeerInfoEntryTransition(deletions: deletions, insertions: insertions, updates: updates)
}

private struct PeerInfoEquatableState: Equatable {
    let state: PeerInfoState?
    
    static func ==(lhs: PeerInfoEquatableState, rhs: PeerInfoEquatableState) -> Bool {
        if let lhsState = lhs.state, let rhsState = rhs.state {
            return lhsState.isEqual(to: rhsState)
        } else if (lhs.state != nil) != (rhs.state != nil) {
            return false
        } else {
            return true
        }
    }
}

public final class PeerInfoController: ListController {
    private let account: Account
    private let peerId: PeerId
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let transitionDisposable = MetaDisposable()
    private let changeSettingsDisposable = MetaDisposable()
    
    private var currentListStyle: PeerInfoListStyle = .plain
    
    private var state = PeerInfoEquatableState(state: nil) {
        didSet {
            self.statePromise.set(.single(self.state))
        }
    }
    private var statePromise = Promise<PeerInfoEquatableState>(PeerInfoEquatableState(state: nil))
    
    private var leftNavigationButtonItem: UIBarButtonItem?
    private var leftNavigationButton: PeerInfoNavigationButton?
    private var rightNavigationButtonItem: UIBarButtonItem?
    private var rightNavigationButton: PeerInfoNavigationButton?
    
    public init(account: Account, peerId: PeerId) {
        self.account = account
        self.peerId = peerId
        
        super.init()
        
        self.title = "Info"
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.transitionDisposable.dispose()
        self.changeSettingsDisposable.dispose()
    }
    
    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        
        let interaction = PeerInfoControllerInteraction(updateState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.state = PeerInfoEquatableState(state: f(strongSelf.state.state))
            }
        }, openSharedMedia: { [weak self] in
            if let strongSelf = self {
                if let controller = peerSharedMediaController(account: strongSelf.account, peerId: strongSelf.peerId) {
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                }
            }
        }, changeNotificationMuteSettings: { [weak self] in
            if let strongSelf = self {
                let controller = ActionSheetController()
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                let notificationAction: (Int32) -> Void = { [weak strongSelf] muteUntil in
                    if let strongSelf = strongSelf {
                        let muteState: PeerMuteState
                        if muteUntil <= 0 {
                            muteState = .unmuted
                        } else if muteUntil == Int32.max {
                            muteState = .muted(until: Int32.max)
                        } else {
                            muteState = .muted(until: Int32(Date().timeIntervalSince1970) + muteUntil)
                        }
                        strongSelf.changeSettingsDisposable.set(changePeerNotificationSettings(account: strongSelf.account, peerId: strongSelf.peerId, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.appDefault)).start())
                    }
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: "Enable", action: {
                            dismissAction()
                            notificationAction(0)
                        }),
                        ActionSheetButtonItem(title: "Mute for 1 hour", action: {
                            dismissAction()
                            notificationAction(1 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "Mute for 8 hours", action: {
                            dismissAction()
                            notificationAction(8 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "Mute for 2 days", action: {
                            dismissAction()
                            notificationAction(2 * 24 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "Disable", action: {
                            dismissAction()
                            notificationAction(Int32.max)
                        })
                        ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
                    ])
                strongSelf.present(controller, in: .window)
            }
        }, openPeerInfo: { [weak self] peerId in
            if let strongSelf = self {
                let controller = PeerInfoController(account: strongSelf.account, peerId: peerId)
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
            }
        })
        
        self.listDisplayNode.backgroundColor = UIColor.white
        
        let previousEntries = Atomic<[PeerInfoSortableEntry]?>(value: nil)
        
        let account = self.account
        let transition = combineLatest(account.viewTracker.peerView(self.peerId), self.statePromise.get()
            |> distinctUntilChanged)
            |> map { view, state -> (PeerInfoEntryTransition, PeerInfoListStyle, Bool, Bool, PeerInfoNavigationButton?, PeerInfoNavigationButton?) in
                let infoEntries = peerInfoEntries(view: view, state: state.state)
                let entries = infoEntries.entries.map { PeerInfoSortableEntry(entry: $0) }
                assert(entries == entries.sorted())
                let previous = previousEntries.swap(entries)
                let style: PeerInfoListStyle
                if let group = view.peers[view.peerId] as? TelegramGroup {
                    style = .blocks
                } else if let channel = view.peers[view.peerId] as? TelegramChannel, case .group = channel.info {
                    style = .blocks
                } else {
                    style = .plain
                }
                return (preparedPeerInfoEntryTransition(account: account, from: previous ?? [], to: entries, interaction: interaction), style, previous == nil, previous != nil, infoEntries.leftNavigationButton, infoEntries.rightNavigationButton)
            }
            |> deliverOnMainQueue
        
        self.transitionDisposable.set(transition.start(next: { [weak self] (transition, style, firstTime, animated, leftButton, rightButton) in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition, style: style, firstTime: firstTime, animated: animated)
                if let leftButton = leftButton {
                    if let leftNavigationButtonItem = strongSelf.leftNavigationButtonItem {
                        if leftNavigationButtonItem.title != leftButton.title {
                            strongSelf.leftNavigationButtonItem = UIBarButtonItem(title: leftButton.title, style: .plain, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                            strongSelf.navigationItem.setLeftBarButton(strongSelf.leftNavigationButtonItem, animated: false)
                        }
                        strongSelf.leftNavigationButton = leftButton
                    } else {
                        strongSelf.leftNavigationButton = leftButton
                        strongSelf.leftNavigationButtonItem = UIBarButtonItem(title: leftButton.title, style: .plain, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                        strongSelf.navigationItem.setLeftBarButton(strongSelf.leftNavigationButtonItem, animated: false)
                    }
                } else if strongSelf.leftNavigationButtonItem != nil {
                    strongSelf.leftNavigationButtonItem = nil
                    strongSelf.leftNavigationButton = nil
                    strongSelf.navigationItem.setLeftBarButton(nil, animated: false)
                }
                
                if let rightButton = rightButton {
                    if let rightNavigationButtonItem = strongSelf.rightNavigationButtonItem {
                        if rightNavigationButtonItem.title != rightButton.title {
                            strongSelf.rightNavigationButtonItem = UIBarButtonItem(title: rightButton.title, style: .plain, target: strongSelf, action: #selector(strongSelf.rightNavigationButtonPressed))
                            strongSelf.navigationItem.setRightBarButton(strongSelf.rightNavigationButtonItem, animated: false)
                        }
                        strongSelf.rightNavigationButton = rightButton
                    } else {
                        strongSelf.rightNavigationButton = rightButton
                        strongSelf.rightNavigationButtonItem = UIBarButtonItem(title: rightButton.title, style: .plain, target: strongSelf, action: #selector(strongSelf.rightNavigationButtonPressed))
                        strongSelf.navigationItem.setRightBarButton(strongSelf.rightNavigationButtonItem, animated: false)
                    }
                } else if strongSelf.rightNavigationButtonItem != nil {
                    strongSelf.rightNavigationButtonItem = nil
                    strongSelf.rightNavigationButton = nil
                    strongSelf.navigationItem.setRightBarButton(nil, animated: false)
                }
            }
        }))
    }
    
    private func enqueueTransition(_ transition: PeerInfoEntryTransition, style: PeerInfoListStyle, firstTime: Bool, animated: Bool) {
        if self.currentListStyle != style {
            self.currentListStyle = style
            switch style {
                case .plain:
                    self.listDisplayNode.backgroundColor = .white
                case .blocks:
                    self.listDisplayNode.backgroundColor = UIColor(0xefeff4)
            }
        }
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else if animated {
            options.insert(.AnimateInsertion)
        }
        self.listDisplayNode.listView.deleteAndInsertItems(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, completion: { [weak self] _ in
            if let strongSelf = self {
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(true))
                }
            }
        })
    }
    
    @objc func leftNavigationButtonPressed() {
        if let leftNavigationButton = self.leftNavigationButton {
            self.state = PeerInfoEquatableState(state: leftNavigationButton.action(self.state.state))
        }
    }
    
    @objc func rightNavigationButtonPressed() {
        if let rightNavigationButton = self.rightNavigationButton {
            self.state = PeerInfoEquatableState(state: rightNavigationButton.action(self.state.state))
        }
    }
}
