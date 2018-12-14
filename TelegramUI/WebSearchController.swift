import Foundation
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import LegacyComponents

private func requestContextResults(account: Account, botId: PeerId, query: String, peerId: PeerId, offset: String = "", existingResults: ChatContextResultCollection? = nil, limit: Int = 30) -> Signal<ChatContextResultCollection?, NoError> {
    return requestChatContextResults(account: account, botId: botId, peerId: peerId, query: query, offset: offset)
    |> mapToSignal { results -> Signal<ChatContextResultCollection?, NoError> in
        var collection = existingResults
        if let existingResults = existingResults, let results = results {
            var newResults: [ChatContextResult] = []
            newResults.append(contentsOf: existingResults.results)
            newResults.append(contentsOf: results.results)
            collection = ChatContextResultCollection(botId: existingResults.botId, peerId: existingResults.peerId, query: existingResults.query, geoPoint: existingResults.geoPoint, queryId: results.queryId, nextOffset: results.nextOffset, presentation: existingResults.presentation, switchPeer: existingResults.switchPeer, results: newResults, cacheTimeout: existingResults.cacheTimeout)
        } else {
            collection = results
        }
        if let collection = collection, collection.results.count < limit, let nextOffset = collection.nextOffset {
            return requestContextResults(account: account, botId: botId, query: query, peerId: peerId, offset: nextOffset, existingResults: collection)
        } else {
            return .single(collection)
        }
    }
}

final class WebSearchControllerInteraction {
    let openResult: (ChatContextResult) -> Void
    let setSearchQuery: (String) -> Void
    let deleteRecentQuery: (String) -> Void
    let toggleSelection: ([String], Bool) -> Void
    let sendSelected: (ChatContextResultCollection, ChatContextResult?) -> Void
    var selectionState: WebSearchSelectionState?
    var hiddenMediaId: String?
    let editingContext: TGMediaEditingContext
    
    init(openResult: @escaping (ChatContextResult) -> Void, setSearchQuery: @escaping (String) -> Void, deleteRecentQuery: @escaping (String) -> Void, toggleSelection: @escaping ([String], Bool) -> Void, sendSelected: @escaping (ChatContextResultCollection, ChatContextResult?) -> Void, editingContext: TGMediaEditingContext) {
        self.openResult = openResult
        self.setSearchQuery = setSearchQuery
        self.deleteRecentQuery = deleteRecentQuery
        self.toggleSelection = toggleSelection
        self.sendSelected = sendSelected
        self.editingContext = editingContext
    }
}

final class WebSearchController: ViewController {
    private var validLayout: ContainerViewLayout?
    
    private let account: Account
    private let chatLocation: ChatLocation
    private let configuration: SearchBotsConfiguration
    
    private var controllerNode: WebSearchControllerNode {
        return self.displayNode as! WebSearchControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var didPlayPresentationAnimation = false
    
    private var controllerInteraction: WebSearchControllerInteraction?
    private var interfaceState: WebSearchInterfaceState
    private let interfaceStatePromise = ValuePromise<WebSearchInterfaceState>()
    
    private var disposable: Disposable?
    private let resultsDisposable = MetaDisposable()
    
    private var navigationContentNode: WebSearchNavigationContentNode?
    
    init(account: Account, chatLocation: ChatLocation, configuration: SearchBotsConfiguration, sendSelected: @escaping ([String], ChatContextResultCollection, TGMediaEditingContext) -> Void) {
        self.account = account
        self.chatLocation = chatLocation
        self.configuration = configuration
        
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.interfaceState = WebSearchInterfaceState(presentationData: presentationData)
    
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme).withUpdatedSeparatorColor(presentationData.theme.rootController.navigationBar.backgroundColor), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBar.style.style
        
        let settings = self.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.webSearchSettings])
        |> take(1)
        |> map { view -> WebSearchSettings in
            if let current = view.values[ApplicationSpecificPreferencesKeys.webSearchSettings] as? WebSearchSettings {
                return current
            } else {
                return WebSearchSettings.defaultSettings
            }
        }

        self.disposable = ((combineLatest(settings, account.telegramApplicationContext.presentationData))
        |> deliverOnMainQueue).start(next: { [weak self] settings, presentationData in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateInterfaceState { current -> WebSearchInterfaceState in
                var updated = current
                if current.state?.mode != settings.mode {
                    updated = updated.withUpdatedMode(settings.mode)
                }
                if current.presentationData !== presentationData {
                    updated = updated.withUpdatedPresentationData(presentationData)
                }
                return updated
            }
        })
        
        let navigationContentNode = WebSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings)
        self.navigationContentNode = navigationContentNode
        navigationContentNode.setQueryUpdated { [weak self] query in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.updateSearchQuery(query)
        }
        self.navigationBar?.setContentNode(navigationContentNode, animated: false)
        
        let editingContext = TGMediaEditingContext()
        self.controllerInteraction = WebSearchControllerInteraction(openResult: { [weak self] result in
            if let strongSelf = self {
                strongSelf.controllerNode.openResult(currentResult: result, present: { [weak self] viewController, arguments in
                    if let strongSelf = self {
                        strongSelf.present(viewController, in: .window(.root), with: arguments)
                    }
                })
            }
        }, setSearchQuery: { [weak self] query in
            if let strongSelf = self {
                strongSelf.navigationContentNode?.setQuery(query)
                strongSelf.updateSearchQuery(query)
                strongSelf.navigationContentNode?.deactivate()
            }
        }, deleteRecentQuery: { [weak self] query in
            if let strongSelf = self {
                _ = removeRecentWebSearchQuery(postbox: strongSelf.account.postbox, string: query).start()
            }
        }, toggleSelection: { [weak self] ids, value in
            if let strongSelf = self {
                strongSelf.updateInterfaceState { $0.withToggledSelectedMessages(ids, value: value) }
            }
        }, sendSelected: { [weak self] collection, current in
            if let strongSelf = self, let state = strongSelf.interfaceState.state {
                var selectedIds = state.selectionState.selectedIds
                if let current = current {
                    selectedIds.insert(current.id)
                }
                sendSelected(Array(selectedIds), collection, editingContext)
            }
        }, editingContext: editingContext)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationContentNode?.activate()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WebSearchControllerNode(account: self.account, theme: self.interfaceState.presentationData.theme, strings: interfaceState.presentationData.strings, controllerInteraction: self.controllerInteraction!)
        self.controllerNode.requestUpdateInterfaceState = { [weak self] animated, f in
            if let strongSelf = self {
                strongSelf.updateInterfaceState(f)
            }
        }
        self.controllerNode.cancel = { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }
        self.controllerNode.dismissInput = { [weak self] in
            if let strongSelf = self {
                strongSelf.navigationContentNode?.deactivate()
            }
        }
        self.controllerNode.updateInterfaceState(self.interfaceState, animated: false)
        
        self._ready.set(.single(true))
        self.displayNodeDidLoad()
    }
    
    func updateInterfaceState(animated: Bool = true, _ f: (WebSearchInterfaceState) -> WebSearchInterfaceState) {
        let previousInterfaceState = self.interfaceState
        let previousTheme = self.interfaceState.presentationData.theme
        let previousStrings = self.interfaceState.presentationData.theme
        
        let updatedInterfaceState = f(self.interfaceState)
        self.interfaceState = updatedInterfaceState
        self.interfaceStatePromise.set(updatedInterfaceState)
        
        self.controllerInteraction?.selectionState = updatedInterfaceState.state?.selectionState
        
        if self.isNodeLoaded {
            if previousTheme !== updatedInterfaceState.presentationData.theme || previousStrings !== updatedInterfaceState.presentationData.strings {
                self.controllerNode.updatePresentationData(theme: updatedInterfaceState.presentationData.theme, strings: updatedInterfaceState.presentationData.strings)
            }
            if previousInterfaceState != self.interfaceState {
                self.controllerNode.updateInterfaceState(self.interfaceState, animated: animated)
            }
        }
    }
    
    private func updateSearchQuery(_ query: String) {
        if !query.isEmpty {
            let _ = addRecentWebSearchQuery(postbox: self.account.postbox, string: query).start()
        }
        
        let mode = self.interfaceStatePromise.get()
        |> map { state -> WebSearchMode? in
            return state.state?.mode
        }
        |> distinctUntilChanged
        
        self.updateInterfaceState { $0.withUpdatedQuery(query) }
        
        var results = mode
        |> mapToSignal { mode -> (Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>) in
            if let mode = mode {
                return self.signalForQuery(query, mode: mode)
                |> deliverOnMainQueue
                |> beforeStarted { [weak self] in
                    if let strongSelf = self {
                        strongSelf.navigationContentNode?.setActivity(true)
                    }
                }
                |> afterCompleted { [weak self] in
                    if let strongSelf = self {
                        strongSelf.navigationContentNode?.setActivity(false)
                    }
                }
            } else {
                return .complete()
            }
        }
        
        if query.isEmpty {
            results = .single({ _ in return nil})
            self.navigationContentNode?.setActivity(false)
        }
        
        self.resultsDisposable.set((results
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                if let result = result(nil), case let .contextRequestResult(_, results) = result {
                    if let results = results {
                        strongSelf.controllerNode.updateResults(results)
                    }
                } else {
                    strongSelf.controllerNode.updateResults(nil)
                }
            }
        }))
    }
    
    private func signalForQuery(_ query: String, mode: WebSearchMode) -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> {
        var delayRequest = true
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
//        if let previousQuery = previousQuery {
//            switch previousQuery {
//                case let .contextRequest(currentAddressName, currentContextQuery) where currentAddressName == addressName:
//                    if query.isEmpty && !currentContextQuery.isEmpty {
//                        delayRequest = false
//                    }
//                default:
//                    delayRequest = false
//                    signal = .single({ _ in return .contextRequestResult(nil, nil) })
//            }
//        } else {
            signal = .single({ _ in return .contextRequestResult(nil, nil) })
//        }
        
        guard case let .peer(peerId) = self.chatLocation else {
            return .single({ _ in return .contextRequestResult(nil, nil) })
        }
        
        let botName: String?
        switch mode {
            case .images:
                botName = self.configuration.imageBotUsername
            case .gifs:
                botName = self.configuration.gifBotUsername
        }
        guard let name = botName else {
            return .single({ _ in return .contextRequestResult(nil, nil) })
        }
        
        let account = self.account
        let contextBot = resolvePeerByName(account: account, name: name)
        |> mapToSignal { peerId -> Signal<Peer?, NoError> in
            if let peerId = peerId {
                return account.postbox.loadedPeerWithId(peerId)
                |> map { peer -> Peer? in
                    return peer
                }
                |> take(1)
            } else {
                return .single(nil)
            }
        }
        |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
            if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                let results = requestContextResults(account: account, botId: user.id, query: query, peerId: peerId, limit: 64)
                |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in
                        return .contextRequestResult(user, results)
                    }
                }
            
                let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ previousResult in
                    var passthroughPreviousResult: ChatContextResultCollection?
                    if let previousResult = previousResult {
                        if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                            if previousUser?.id == user.id {
                                passthroughPreviousResult = previousResults
                            }
                        }
                    }
                    return .contextRequestResult(nil, passthroughPreviousResult)
                })
                
                let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>
                if delayRequest {
                    maybeDelayedContextResults = results |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                } else {
                    maybeDelayedContextResults = results
                }
                
                return botResult |> then(maybeDelayedContextResults)
            } else {
                return .single({ _ in return nil })
            }
        }
        return signal |> then(contextBot)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.navigationContentNode?.deactivate()
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
