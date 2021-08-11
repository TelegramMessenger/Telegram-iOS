import Foundation
import Postbox
import TelegramApi


extension TelegramMediaGame {
    convenience init(apiGame: Api.Game) {
        switch apiGame {
            case let .game(_, id, accessHash, shortName, title, description, photo, document):
                var file: TelegramMediaFile?
                if let document = document {
                    file = telegramMediaFileFromApiDocument(document)
                }
                self.init(gameId: id, accessHash: accessHash, name: shortName, title: title, description: description, image: telegramMediaImageFromApiPhoto(photo), file: file)
        }
    }
}
