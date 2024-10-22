import Foundation
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import SwiftSignalKit
import Postbox
import TelegramCore

extension ChatControllerImpl {    
    func updateSearch(_ interfaceState: ChatPresentationInterfaceState) -> ChatPresentationInterfaceState? {
        guard let peerId = self.chatLocation.peerId else {
            return nil
        }
        
        let limit: Int32 = 100
        
        var derivedSearchState: ChatSearchState?
        if let search = interfaceState.search {
            func loadMoreStateFromResultsState(_ resultsState: ChatSearchResultsState?) -> SearchMessagesState? {
                guard let resultsState = resultsState, let currentId = resultsState.currentId else {
                    return nil
                }
                if let index = resultsState.messageIndices.firstIndex(where: { $0.id == currentId }) {
                    if index <= limit / 2 {
                        return resultsState.state
                    }
                }
                return nil
            }
            var threadId: Int64?
            switch self.chatLocation {
            case .peer:
                break
            case let .replyThread(replyThreadMessage):
                threadId = replyThreadMessage.threadId
            case .customChatContents:
                break
            }
            
            var reactions: [MessageReaction.Reaction]?
            if !search.query.isEmpty, let historyFilter = interfaceState.historyFilter {
                reactions = ReactionsMessageAttribute.reactionFromMessageTag(tag: historyFilter.customTag).flatMap {
                    [$0]
                }
            }
            
            switch search.domain {
            case .everything:
                derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: nil, tags: nil, reactions: reactions, threadId: threadId, minDate: nil, maxDate: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
            case let .tag(reaction):
                derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: nil, tags: nil, reactions: reactions ?? [reaction], threadId: threadId, minDate: nil, maxDate: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
            case .members:
                derivedSearchState = nil
            case let .member(peer):
                derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: peer.id, tags: nil, reactions: reactions, threadId: threadId, minDate: nil, maxDate: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
            }
        }
        
        if derivedSearchState != self.searchState {
            let previousSearchState = self.searchState
            self.searchState = derivedSearchState
            if let searchState = derivedSearchState {
                if previousSearchState?.query != searchState.query || previousSearchState?.location != searchState.location {
                    var queryIsEmpty = false
                    if searchState.query.isEmpty {
                        if case let .peer(_, fromId, _, reactions, _, _, _) = searchState.location {
                            if fromId == nil {
                                queryIsEmpty = true
                            }
                            if let reactions, !reactions.isEmpty {
                                queryIsEmpty = false
                            }
                        } else {
                            queryIsEmpty = true
                        }
                    }
                    
                    if queryIsEmpty {
                        self.searching.set(false)
                        self.searchResultsCount.set(0)
                        self.searchDisposable?.set(nil)
                        self.searchResult.set(.single(nil))
                        if let data = interfaceState.search {
                            return interfaceState.updatedSearch(data.withUpdatedResultsState(nil))
                        }
                    } else {
                        self.searching.set(true)
                        let searchDisposable: MetaDisposable
                        if let current = self.searchDisposable {
                            searchDisposable = current
                        } else {
                            searchDisposable = MetaDisposable()
                            self.searchDisposable = searchDisposable
                        }

                        let search = self.context.engine.messages.searchMessages(location: searchState.location, query: searchState.query, state: nil, limit: limit)
                        |> delay(0.2, queue: Queue.mainQueue())
                        self.searchResult.set(search
                        |> map { (result, state) -> (SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)? in
                            return (result, state, searchState.location)
                        })
                        
                        searchDisposable.set((search
                        |> deliverOnMainQueue).startStrict(next: { [weak self] results, updatedState in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.searchResultsCount.set(results.totalCount)
                            var navigateIndex: MessageIndex?
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                if let data = current.search {
                                    let messageIndices = results.messages.map({ $0.index }).sorted()
                                    var currentIndex = messageIndices.last
                                    if let previousResultId = data.resultsState?.currentId {
                                        for index in messageIndices {
                                            if index.id >= previousResultId {
                                                currentIndex = index
                                                break
                                            }
                                        }
                                    }
                                    navigateIndex = currentIndex
                                    return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id, state: updatedState, totalCount: results.totalCount, completed: results.completed)))
                                } else {
                                    return current
                                }
                            })
                            if let navigateIndex = navigateIndex {
                                switch strongSelf.chatLocation {
                                case .peer, .replyThread, .customChatContents:
                                    strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                                }
                            }
                            strongSelf.updateItemNodesSearchTextHighlightStates()
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.searching.set(false)
                            }
                        }))
                    }
                } else if previousSearchState?.loadMoreState != searchState.loadMoreState {
                    if let loadMoreState = searchState.loadMoreState {
                        self.searching.set(true)
                        let searchDisposable: MetaDisposable
                        if let current = self.searchDisposable {
                            searchDisposable = current
                        } else {
                            searchDisposable = MetaDisposable()
                            self.searchDisposable = searchDisposable
                        }
                        searchDisposable.set((self.context.engine.messages.searchMessages(location: searchState.location, query: searchState.query, state: loadMoreState, limit: limit)
                        |> delay(0.2, queue: Queue.mainQueue())
                        |> deliverOnMainQueue).startStrict(next: { [weak self] results, updatedState in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.searchResultsCount.set(results.totalCount)
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                if let data = current.search, let previousResultsState = data.resultsState {
                                    let messageIndices = results.messages.map({ $0.index }).sorted()
                                    return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: previousResultsState.currentId, state: updatedState, totalCount: results.totalCount, completed: results.completed)))
                                } else {
                                    return current
                                }
                            })
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.searching.set(false)
                            }
                        }))
                    } else {
                        self.searching.set(false)
                        self.searchResultsCount.set(0)
                        self.searchDisposable?.set(nil)
                    }
                }
            } else {
                self.searching.set(false)
                self.searchResultsCount.set(0)
                self.searchDisposable?.set(nil)
                
                if let data = interfaceState.search {
                    return interfaceState.updatedSearch(data.withUpdatedResultsState(nil))
                }
            }
        }
        self.updateItemNodesSearchTextHighlightStates()
        return nil
    }
}
