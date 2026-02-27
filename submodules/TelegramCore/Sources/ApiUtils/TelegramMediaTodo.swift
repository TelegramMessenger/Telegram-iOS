import Foundation
import Postbox
import TelegramApi


extension TelegramMediaTodo.Item {
    init(apiItem: Api.TodoItem) {
        switch apiItem {
        case let .todoItem(todoItemData):
            let (id, title) = (todoItemData.id, todoItemData.title)
            let itemText: String
            let itemEntities: [MessageTextEntity]
            switch title {
            case let .textWithEntities(textWithEntitiesData):
                let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                itemText = text
                itemEntities = messageTextEntitiesFromApiEntities(entities)
            }
            self.init(text: itemText, entities: itemEntities, id: id)
        }
    }
    
    var apiItem: Api.TodoItem {
        return .todoItem(.init(id: self.id, title: .textWithEntities(.init(text: self.text, entities: apiEntitiesFromMessageTextEntities(self.entities, associatedPeers: SimpleDictionary())))))
    }
}

extension TelegramMediaTodo.Completion {
    init(apiCompletion: Api.TodoCompletion) {
        switch apiCompletion {
        case let .todoCompletion(todoCompletionData):
            let (id, completedBy, date) = (todoCompletionData.id, todoCompletionData.completedBy, todoCompletionData.date)
            self.init(id: id, date: date, completedBy: completedBy.peerId)
        }
    }
}
