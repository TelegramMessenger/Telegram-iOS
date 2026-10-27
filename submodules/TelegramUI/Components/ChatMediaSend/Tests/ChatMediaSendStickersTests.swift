import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
@testable import ChatMediaSend

final class ChatMediaSendStickersTests: XCTestCase {
    private func file(_ id: Int64) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: LocalFileMediaResource(fileId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: [])
    }

    func testCollectsStickerFilesInOrder() {
        let first = DrawingStickerEntity(content: .file(.standalone(media: file(1)), .sticker))
        let reaction = DrawingStickerEntity(content: .file(.standalone(media: file(2)), .reaction(.builtin("👍"), .white)))
        let image = DrawingStickerEntity(content: .image(UIImage(), .sticker))
        let textEntity = DrawingTextEntity(text: NSAttributedString(string: "a"), style: .regular, animation: .none, font: .sanFrancisco, alignment: .left, fontSize: 1.0, color: DrawingColor(rgb: 0xffffff))
        textEntity.renderSubEntities = [DrawingStickerEntity(content: .file(.standalone(media: file(3)), .sticker)), DrawingStickerEntity(content: .file(.standalone(media: file(4)), .reaction(.builtin("👍"), .black)))]
        let last = DrawingStickerEntity(content: .file(.standalone(media: file(5)), .sticker))

        let stickers = chatMediaSendCollectStickers(entities: [.sticker(first), .sticker(reaction), .sticker(image), .text(textEntity), .sticker(last)])
        XCTAssertEqual(stickers.map { $0.fileId.id }, [1, 3, 5])
    }

    func testNoEntitiesNoStickers() {
        XCTAssertEqual(chatMediaSendCollectStickers(entities: []).count, 0)
    }
}
