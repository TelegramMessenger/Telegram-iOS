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

/// The model and speed an agent chat shows, with test values until the API carries them. Kept in memory per chat.
public final class AgentChatPlaceholderOptions {
    public struct Model: Equatable {
        public let id: String
        /// The composer chip: "Opus 5.5".
        public let title: String
        /// The chat title's subtitle: "Claude Opus 5.5".
        public let fullTitle: String
    }

    public struct Speed: Equatable {
        public let id: String
        public let title: String
    }

    public struct Selection: Equatable {
        public var model: Model
        public var speed: Speed
    }

    public static let shared = AgentChatPlaceholderOptions()

    public let models: [Model] = [
        Model(id: "opus", title: "Opus 5.5", fullTitle: "Claude Opus 5.5"),
        Model(id: "sonnet", title: "Sonnet 5.5", fullTitle: "Claude Sonnet 5.5"),
        Model(id: "haiku", title: "Haiku 5.5", fullTitle: "Claude Haiku 5.5")
    ]

    public let speeds: [Speed] = [
        Speed(id: "fast", title: "Fast"),
        Speed(id: "balanced", title: "Balanced"),
        Speed(id: "thorough", title: "Thorough")
    ]

    private var selections: [EnginePeer.Id: Selection] = [:]
    private let updatedPipe = ValuePipe<EnginePeer.Id>()

    private init() {
    }

    public func selection(peerId: EnginePeer.Id) -> Selection {
        assert(Queue.mainQueue().isCurrent())
        return self.selections[peerId] ?? Selection(model: self.models[0], speed: self.speeds[0])
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
