import Foundation
import Postbox
internal import TelegramApi

public class RichTextMessageAttribute: MessageAttribute, Equatable {
    public let instantPage: InstantPage
    public var fullInstantPage: InstantPage?
    
    /// The users the page refers to by id (mention names, "User Profile" buttons), so that a rendered
    /// message's `peers` carries them: sending lists them in `inputRichMessage.users`.
    public var associatedPeerIds: [PeerId] {
        guard let fullInstantPage = self.fullInstantPage else {
            return self.instantPage.referencedUserIds
        }
        var result = self.instantPage.referencedUserIds
        var seen = Set(result)
        for peerId in fullInstantPage.referencedUserIds where seen.insert(peerId).inserted {
            result.append(peerId)
        }
        return result
    }
    
    /// The page's custom emoji files, so that a rendered message's `associatedMedia` carries the stored
    /// ones (`extractEmojiFileIds` fetches them when the message arrives): a preview draws an emoji whose
    /// file is known and keeps the alt text of one that is not.
    public var associatedMediaIds: [MediaId] {
        var fileIds = self.instantPage.customEmojiFileIds
        if let fullInstantPage = self.fullInstantPage {
            var seen = Set(fileIds)
            for fileId in fullInstantPage.customEmojiFileIds where seen.insert(fileId).inserted {
                fileIds.append(fileId)
            }
        }
        return fileIds.map { MediaId(namespace: Namespaces.Media.CloudFile, id: $0) }
    }
    
    public init(instantPage: InstantPage, fullInstantPage: InstantPage?) {
        self.instantPage = instantPage
        self.fullInstantPage = fullInstantPage
    }
    
    required public init(decoder: PostboxDecoder) {
        self.instantPage = decoder.decodeObjectForKey("instantPage", decoder: { InstantPage(decoder: $0) }) as! InstantPage
        self.fullInstantPage = decoder.decodeObjectForKey("fullInstantPage", decoder: { InstantPage(decoder: $0) }) as? InstantPage
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.instantPage, forKey: "instantPage")
        if let fullInstantPage = self.fullInstantPage {
            encoder.encodeObject(fullInstantPage, forKey: "fullInstantPage")
        } else {
            encoder.encodeNil(forKey: "fullInstantPage")
        }
    }
    
    public static func ==(lhs: RichTextMessageAttribute, rhs: RichTextMessageAttribute) -> Bool {
        return lhs.instantPage == rhs.instantPage && lhs.fullInstantPage == rhs.fullInstantPage
    }
}

extension RichTextMessageAttribute {
    convenience init(apiRichMessage: Api.RichMessage) {
        switch apiRichMessage {
        case let .richMessage(richMessage):
            var media: [MediaId: Media] = [:]
            for photo in richMessage.photos {
                if let image = telegramMediaImageFromApiPhoto(photo), let id = image.id {
                    media[id] = image
                }
            }
            for file in richMessage.documents {
                if let file = telegramMediaFileFromApiDocument(file, altDocuments: []), let id = file.id {
                    media[id] = file
                }
            }
            let isRtl = (richMessage.flags & (1 << 0)) != 0
            let isPartial = (richMessage.flags & (1 << 1)) != 0
            let instantPage = InstantPage(blocks: richMessage.blocks.map({ InstantPageBlock(apiBlock: $0) }), rawMedia: media, isComplete: !isPartial, rtl: isRtl, url: "", views: nil)
            self.init(instantPage: instantPage, fullInstantPage: nil)
        }
    }

    /// `users`: `apiInputRichMessageUsers(self.instantPage, …)`, the users the page refers to by id.
    func apiInputRichMessage(users: [Api.InputUser]) -> Api.InputRichMessage {
        var flags: Int32 = 0
        if self.instantPage.rtl {
            flags |= (1 << 0)
        }
        if !users.isEmpty {
            flags |= (1 << 4)
        }
        
        return Api.InputRichMessage.inputRichMessage(Api.InputRichMessage.Cons_inputRichMessage(
            flags: flags,
            blocks: self.instantPage.blocks.compactMap { $0.apiInputBlock() },
            photos: nil,
            documents: nil,
            users: users.isEmpty ? nil : users
        ))
    }
}
