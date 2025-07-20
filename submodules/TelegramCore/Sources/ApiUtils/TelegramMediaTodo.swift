import Foundation
import Postbox
import TelegramApi


extension TelegramMediaTodo.Item {
    init(apiItem: Api.TodoItem) {
        switch apiItem {
        case let .todoItem(id, title):
            let itemText: String
            let itemEntities: [MessageTextEntity]
            switch title {
            case let .textWithEntities(text, entities):
                itemText = text
                itemEntities = messageTextEntitiesFromApiEntities(entities)
            }
            self.init(text: itemText, entities: itemEntities, id: id)
        }
    }
    
    var apiItem: Api.TodoItem {
        return .todoItem(id: self.id, title: .textWithEntities(text: self.text, entities: apiEntitiesFromMessageTextEntities(self.entities, associatedPeers: SimpleDictionary())))
    }
}

extension TelegramMediaTodo.Completion {
    init(apiCompletion: Api.TodoCompletion) {
        switch apiCompletion {
        case let .todoCompletion(id, completedBy, date):
            self.init(id: id, date: date, completedBy: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(completedBy)))
        }
    }
}
