import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

extension PeerInfoScreenNode {
    /// The message tag listed by a shared-media pane, or nil for panes that do not list messages.
    private func selectAllMessageTag(paneKey: PeerInfoPaneKey) -> EngineMessage.Tags? {
        switch paneKey {
        case .media:
            return .photoOrVideo
        case .files:
            return .file
        case .music:
            return .music
        case .voice:
            return .voiceOrInstantVideo
        case .links:
            return .webPage
        case .gifs:
            return .gif
        default:
            return nil
        }
    }

    /// Selects every message of the current shared-media tab, not only the loaded cells: the ids are
    /// paged from the server search (100 per request, the server maximum) until it reports completion.
    func selectAllMessagesInCurrentPane() {
        guard self.state.selectedMessageIds != nil, let paneKey = self.paneContainerNode.currentPaneKey, let tag = self.selectAllMessageTag(paneKey: paneKey) else {
            return
        }
        let chatLocation = self.sharedMediaChatLocation
        let location: SearchMessagesLocation = .peer(peerId: chatLocation.peerId, fromId: nil, tags: tag, reactions: nil, threadId: chatLocation.chatLocation.threadId, minDate: nil, maxDate: nil)
        let engine = self.context.engine

        // A paged result may repeat the pages before it, so ids are gathered into a set.
        func loadAll(state: SearchMessagesState?, collected: Set<EngineMessage.Id>) -> Signal<Set<EngineMessage.Id>, NoError> {
            return engine.messages.searchMessages(location: location, query: "", state: state, limit: 100)
            |> take(1)
            |> mapToSignal { result, updatedState -> Signal<Set<EngineMessage.Id>, NoError> in
                let previousCount = collected.count
                let collected = collected.union(result.messages.map { EngineMessage($0).id })
                if result.completed || result.messages.isEmpty || collected.count == previousCount {
                    return .single(collected)
                }
                return loadAll(state: updatedState, collected: collected)
            }
        }

        self.selectAllDisposable.set((loadAll(state: nil, collected: Set())
        |> deliverOnMainQueue).startStrict(next: { [weak self] ids in
            guard let self, self.state.selectedMessageIds != nil, !ids.isEmpty else {
                return
            }
            self.chatInterfaceInteraction.toggleMessagesSelection(Array(ids), true)
        }))
    }
}
