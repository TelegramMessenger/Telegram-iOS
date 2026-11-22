import Foundation
import SwiftSignalKit
import TelegramCore

/// A bot that runs on the user's own AI provider key: one of `appConfig.agent_bot_ids`. Its profile manages the keys
/// and its chat uses the agent composer.
public func isAgentBotPeer(appConfiguration: AppConfiguration, peerId: EnginePeer.Id) -> Bool {
    guard peerId.namespace == Namespaces.Peer.CloudUser, let data = appConfiguration.data, let botIds = data["agent_bot_ids"] as? [Any] else {
        return false
    }
    let id = peerId.id._internalGetInt64Value()
    return botIds.contains(where: { value in
        if let value = value as? NSNumber {
            return value.int64Value == id
        } else if let value = value as? String {
            return Int64(value) == id
        } else {
            return false
        }
    })
}

/// The model and effort an agent chat shows, with test values until the API carries them. Kept in memory per chat.
public final class AgentChatPlaceholderOptions {
    public struct Model: Equatable {
        public let id: String
        /// The composer chip: "Opus 5.5".
        public let title: String
        /// The chat title's subtitle: "Claude Opus 5.5".
        public let fullTitle: String
        /// The model menu's line under the title.
        public let subtitle: String
    }

    /// How hard the agent thinks: a step of the model menu's effort slider.
    public struct Effort: Equatable {
        public let id: String
        public let title: String
    }

    public struct Selection: Equatable {
        public var model: Model
        public var effort: Effort
    }

    public static let shared = AgentChatPlaceholderOptions()

    public let models: [Model] = [
        Model(id: "fable", title: "Fable 5.1", fullTitle: "Claude Fable 5.1", subtitle: "Most capable for ambitious work"),
        Model(id: "opus", title: "Opus 5.5", fullTitle: "Claude Opus 5.5", subtitle: "Deep reasoning for complex tasks"),
        Model(id: "sonnet", title: "Sonnet 5.5", fullTitle: "Claude Sonnet 5.5", subtitle: "Smart and fast for everyday use"),
        Model(id: "haiku", title: "Haiku 5.5", fullTitle: "Claude Haiku 5.5", subtitle: "Fastest for quick answers")
    ]

    /// The effort slider's steps, lowest first.
    public let efforts: [Effort] = [
        Effort(id: "low", title: "Low"),
        Effort(id: "medium", title: "Medium"),
        Effort(id: "high", title: "High"),
        Effort(id: "xhigh", title: "Extra High"),
        Effort(id: "max", title: "Max")
    ]

    private var selections: [EnginePeer.Id: Selection] = [:]
    private let updatedPipe = ValuePipe<EnginePeer.Id>()

    private init() {
    }

    public func selection(peerId: EnginePeer.Id) -> Selection {
        assert(Queue.mainQueue().isCurrent())
        return self.selections[peerId] ?? Selection(model: self.models[1], effort: self.efforts[2])
    }

    public func update(peerId: EnginePeer.Id, _ f: (Selection) -> Selection) {
        assert(Queue.mainQueue().isCurrent())
        self.selections[peerId] = f(self.selection(peerId: peerId))
        self.updatedPipe.putNext(peerId)
    }

    /// The chat's selection now and after every change, on the main queue.
    public func selectionSignal(peerId: EnginePeer.Id) -> Signal<Selection, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            subscriber.putNext(self.selection(peerId: peerId))
            return (self.updatedPipe.signal()
            |> filter { $0 == peerId }).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                subscriber.putNext(self.selection(peerId: peerId))
            })
        }
        |> runOn(Queue.mainQueue())
    }
}
