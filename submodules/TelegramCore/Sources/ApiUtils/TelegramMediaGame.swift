import Foundation
import Postbox
import TelegramApi


extension TelegramMediaGame {
    convenience init(apiGame: Api.Game) {
        switch apiGame {
            case let .game(gameData):
                let (id, accessHash, shortName, title, description, photo, document) = (gameData.id, gameData.accessHash, gameData.shortName, gameData.title, gameData.description, gameData.photo, gameData.document)
                var file: TelegramMediaFile?
                if let document = document {
                    file = telegramMediaFileFromApiDocument(document, altDocuments: [])
                }
                self.init(gameId: id, accessHash: accessHash, name: shortName, title: title, description: description, image: telegramMediaImageFromApiPhoto(photo), file: file)
        }
    }
}
