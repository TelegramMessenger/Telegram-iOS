import Foundation
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class HashtagSearchController: TelegramController {
    private let queue = Queue()
    
    private let account: Account
    private var transitionDisposable: Disposable?
    private let openMessageFromSearchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var controllerNode: HashtagSearchControllerNode {
        return self.displayNode as! HashtagSearchControllerNode
    }
    
    init(account: Account, peerName: String?, query: String) {
        self.account = account
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(account: account, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), enableMediaAccessoryPanel: true, locationBroadcastPanelSource: .none)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        if let peerName = peerName {
            self.title = query + "@" + peerName
        } else {
            self.title = query
        }
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        let peerId: Signal<PeerId?, NoError>
        if let peerName = peerName {
            peerId = resolvePeerByName(account: account, name: peerName)
                |> take(1)
        } else {
            peerId = .single(nil)
        }
        
        let chatListPresentationData = ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, timeFormat: self.presentationData.timeFormat)
        let foundMessages: Signal<[ChatListSearchEntry], NoError> = peerId
            |> mapToSignal { peerId -> Signal<[ChatListSearchEntry], NoError> in
                let location: SearchMessagesLocation
                if let peerId = peerId {
                    location = .peer(peerId: peerId, fromId: nil, tags: nil)
                } else {
                    location = .general
                }
                let search = searchMessages(account: account, location: location, query: query)
                return search
                    |> map { return $0.map({ .message($0, chatListPresentationData) }) }
            }
        
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { peer in
            
        }, messageSelected: { [weak self] message in
            if let strongSelf = self {
                if let peer = message.peers[message.id.peerId] {
                    strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.account, peer: peer) |> deliverOnMainQueue).start(completed: {
                        if let strongSelf = self {
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(message.id.peerId), messageId: message.id))
                        }
                    }))
                }
                strongSelf.controllerNode.listNode.clearHighlightAnimated(true)
            }
        }, groupSelected: { _ in
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _ in
        }, updatePeerGrouping: { _, _ in
        })
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        self.transitionDisposable = (foundMessages |> deliverOn(self.queue)).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousSearchItems.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries, displayingResults: true, account: account, enableHeaders: false, onlyWriteable: false, interaction: interaction)
                strongSelf.controllerNode.enqueueTransition(transition, firstTime: firstTime)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.transitionDisposable?.dispose()
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = HashtagSearchControllerNode(account: self.account, theme: self.presentationData.theme)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
