import Foundation
import TelegramCore
import FactCheckAlertController

extension ChatControllerImpl {
    func openEditMessageFactCheck(messageId: EngineMessage.Id) {
        guard let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) else {
            return
        }
        var currentText: String = ""
        var currentEntities: [MessageTextEntity] = []
        for attribute in message.attributes {
            if let attribute = attribute as? FactCheckMessageAttribute, case let .Loaded(text, entities, _) = attribute.content {
                currentText = text
                currentEntities = entities
                break
            }
        }
        let controller = factCheckAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, value: currentText, entities: currentEntities, characterLimit: 4096, apply: { [weak self] text, entities in
            guard let self else {
                return
            }
            if !currentText.isEmpty && text.isEmpty {
                let _ = self.context.engine.messages.deleteMessageFactCheck(messageId: messageId).startStandalone()
            } else {
                let _ = self.context.engine.messages.editMessageFactCheck(messageId: messageId, text: text, entities: entities).startStandalone()
            }
        })
        self.present(controller, in: .window(.root))
    }
}
