import SwiftSignalKit
import Postbox

public extension TelegramEngine.EngineData.Item {
    enum Messages {
        public struct Message: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EngineMessage>

            fileprivate var id: EngineMessage.Id

            public init(id: EngineMessage.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .messages(Set([self.id]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessagesView else {
                    preconditionFailure()
                }
                guard let message = view.messages[self.id] else {
                    return nil
                }
                return EngineMessage(message)
            }
        }

        public struct Messages: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [EngineMessage.Id: EngineMessage]

            fileprivate var ids: Set<EngineMessage.Id>

            public init(ids: Set<EngineMessage.Id>) {
                self.ids = ids
            }

            var key: PostboxViewKey {
                return .messages(self.ids)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessagesView else {
                    preconditionFailure()
                }
                var result: [EngineMessage.Id: EngineMessage] = [:]
                for (id, message) in view.messages {
                    result[id] = EngineMessage(message)
                }
                return result
            }
        }
    }
}
