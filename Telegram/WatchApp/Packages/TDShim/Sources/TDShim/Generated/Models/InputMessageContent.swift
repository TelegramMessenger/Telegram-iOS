//
//  InputMessageContent.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// The content of a message to send
/// This Swift enum is recursive.
public indirect enum InputMessageContent: Codable, Equatable, Hashable {

    /// A text message
    case inputMessageText(InputMessageText)

    /// An animation message (GIF-style).
    case inputMessageAnimation(InputMessageAnimation)

    /// An audio message
    case inputMessageAudio(InputMessageAudio)

    /// A document message (general file)
    case inputMessageDocument(InputMessageDocument)

    /// A message with paid media; can be used only in channel chats with supergroupFullInfo.has_paid_media_allowed
    case inputMessagePaidMedia(InputMessagePaidMedia)

    /// A photo message
    case inputMessagePhoto(InputMessagePhoto)

    /// A sticker message
    case inputMessageSticker(InputMessageSticker)

    /// A video message
    case inputMessageVideo(InputMessageVideo)

    /// A video note message
    case inputMessageVideoNote(InputMessageVideoNote)

    /// A voice note message
    case inputMessageVoiceNote(InputMessageVoiceNote)

    /// A message with a location
    case inputMessageLocation(InputMessageLocation)

    /// A message with information about a venue
    case inputMessageVenue(InputMessageVenue)

    /// A message containing a user contact
    case inputMessageContact(InputMessageContact)

    /// A dice message
    case inputMessageDice(InputMessageDice)

    /// A message with a game; not supported for channels or secret chats
    case inputMessageGame(InputMessageGame)

    /// A message with an invoice; can be used only by bots
    case inputMessageInvoice(InputMessageInvoice)

    /// A message with a poll. Polls can't be sent to secret chats and channel direct messages chats. Polls can be sent to a private chat only if the chat is a chat with a bot or the Saved Messages chat
    case inputMessagePoll(InputMessagePoll)

    /// A stake dice message
    case inputMessageStakeDice(InputMessageStakeDice)

    /// A message with a forwarded story. Stories can't be forwarded to secret chats. A story can be forwarded only if story.can_be_forwarded
    case inputMessageStory(InputMessageStory)

    /// A message with a checklist. Checklists can't be sent to secret chats, channel chats and channel direct messages chats; for Telegram Premium users only
    case inputMessageChecklist(InputMessageChecklist)

    /// A forwarded message
    case inputMessageForwarded(InputMessageForwarded)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case inputMessageText
        case inputMessageAnimation
        case inputMessageAudio
        case inputMessageDocument
        case inputMessagePaidMedia
        case inputMessagePhoto
        case inputMessageSticker
        case inputMessageVideo
        case inputMessageVideoNote
        case inputMessageVoiceNote
        case inputMessageLocation
        case inputMessageVenue
        case inputMessageContact
        case inputMessageDice
        case inputMessageGame
        case inputMessageInvoice
        case inputMessagePoll
        case inputMessageStakeDice
        case inputMessageStory
        case inputMessageChecklist
        case inputMessageForwarded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .inputMessageText:
            let value = try InputMessageText(from: decoder)
            self = .inputMessageText(value)
        case .inputMessageAnimation:
            let value = try InputMessageAnimation(from: decoder)
            self = .inputMessageAnimation(value)
        case .inputMessageAudio:
            let value = try InputMessageAudio(from: decoder)
            self = .inputMessageAudio(value)
        case .inputMessageDocument:
            let value = try InputMessageDocument(from: decoder)
            self = .inputMessageDocument(value)
        case .inputMessagePaidMedia:
            let value = try InputMessagePaidMedia(from: decoder)
            self = .inputMessagePaidMedia(value)
        case .inputMessagePhoto:
            let value = try InputMessagePhoto(from: decoder)
            self = .inputMessagePhoto(value)
        case .inputMessageSticker:
            let value = try InputMessageSticker(from: decoder)
            self = .inputMessageSticker(value)
        case .inputMessageVideo:
            let value = try InputMessageVideo(from: decoder)
            self = .inputMessageVideo(value)
        case .inputMessageVideoNote:
            let value = try InputMessageVideoNote(from: decoder)
            self = .inputMessageVideoNote(value)
        case .inputMessageVoiceNote:
            let value = try InputMessageVoiceNote(from: decoder)
            self = .inputMessageVoiceNote(value)
        case .inputMessageLocation:
            let value = try InputMessageLocation(from: decoder)
            self = .inputMessageLocation(value)
        case .inputMessageVenue:
            let value = try InputMessageVenue(from: decoder)
            self = .inputMessageVenue(value)
        case .inputMessageContact:
            let value = try InputMessageContact(from: decoder)
            self = .inputMessageContact(value)
        case .inputMessageDice:
            let value = try InputMessageDice(from: decoder)
            self = .inputMessageDice(value)
        case .inputMessageGame:
            let value = try InputMessageGame(from: decoder)
            self = .inputMessageGame(value)
        case .inputMessageInvoice:
            let value = try InputMessageInvoice(from: decoder)
            self = .inputMessageInvoice(value)
        case .inputMessagePoll:
            let value = try InputMessagePoll(from: decoder)
            self = .inputMessagePoll(value)
        case .inputMessageStakeDice:
            let value = try InputMessageStakeDice(from: decoder)
            self = .inputMessageStakeDice(value)
        case .inputMessageStory:
            let value = try InputMessageStory(from: decoder)
            self = .inputMessageStory(value)
        case .inputMessageChecklist:
            let value = try InputMessageChecklist(from: decoder)
            self = .inputMessageChecklist(value)
        case .inputMessageForwarded:
            let value = try InputMessageForwarded(from: decoder)
            self = .inputMessageForwarded(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .inputMessageText(let value):
            try container.encode(Kind.inputMessageText, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageAnimation(let value):
            try container.encode(Kind.inputMessageAnimation, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageAudio(let value):
            try container.encode(Kind.inputMessageAudio, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageDocument(let value):
            try container.encode(Kind.inputMessageDocument, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessagePaidMedia(let value):
            try container.encode(Kind.inputMessagePaidMedia, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessagePhoto(let value):
            try container.encode(Kind.inputMessagePhoto, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageSticker(let value):
            try container.encode(Kind.inputMessageSticker, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageVideo(let value):
            try container.encode(Kind.inputMessageVideo, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageVideoNote(let value):
            try container.encode(Kind.inputMessageVideoNote, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageVoiceNote(let value):
            try container.encode(Kind.inputMessageVoiceNote, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageLocation(let value):
            try container.encode(Kind.inputMessageLocation, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageVenue(let value):
            try container.encode(Kind.inputMessageVenue, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageContact(let value):
            try container.encode(Kind.inputMessageContact, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageDice(let value):
            try container.encode(Kind.inputMessageDice, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageGame(let value):
            try container.encode(Kind.inputMessageGame, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageInvoice(let value):
            try container.encode(Kind.inputMessageInvoice, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessagePoll(let value):
            try container.encode(Kind.inputMessagePoll, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageStakeDice(let value):
            try container.encode(Kind.inputMessageStakeDice, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageStory(let value):
            try container.encode(Kind.inputMessageStory, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageChecklist(let value):
            try container.encode(Kind.inputMessageChecklist, forKey: .type)
            try value.encode(to: encoder)
        case .inputMessageForwarded(let value):
            try container.encode(Kind.inputMessageForwarded, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A text message
public struct InputMessageText: Codable, Equatable, Hashable {

    /// True, if the chat message draft must be deleted
    public let clearDraft: Bool

    /// Options to be used for generation of a link preview; may be null if none; pass null to use default link preview options
    public let linkPreviewOptions: LinkPreviewOptions?

    /// Formatted text to be sent; 0-getOption("message_text_length_max") characters. Only Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, BlockQuote, ExpandableBlockQuote, Code, Pre, PreCode, TextUrl, MentionName, and DateTime entities are allowed to be specified manually
    public let text: FormattedText


    public init(
        clearDraft: Bool,
        linkPreviewOptions: LinkPreviewOptions?,
        text: FormattedText
    ) {
        self.clearDraft = clearDraft
        self.linkPreviewOptions = linkPreviewOptions
        self.text = text
    }
}

/// An animation message (GIF-style).
public struct InputMessageAnimation: Codable, Equatable, Hashable {

    /// File identifiers of the stickers added to the animation, if applicable
    public let addedStickerFileIds: [Int]

    /// Animation file to be sent
    public let animation: InputFile

    /// Animation caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// Duration of the animation, in seconds
    public let duration: Int

    /// True, if the animation preview must be covered by a spoiler animation; not supported in secret chats
    public let hasSpoiler: Bool

    /// Height of the animation; may be replaced by the server
    public let height: Int

    /// True, if the caption must be shown above the animation; otherwise, the caption must be shown below the animation; not supported in secret chats
    public let showCaptionAboveMedia: Bool

    /// Animation thumbnail; pass null to skip thumbnail uploading
    public let thumbnail: InputThumbnail?

    /// Width of the animation; may be replaced by the server
    public let width: Int


    public init(
        addedStickerFileIds: [Int],
        animation: InputFile,
        caption: FormattedText?,
        duration: Int,
        hasSpoiler: Bool,
        height: Int,
        showCaptionAboveMedia: Bool,
        thumbnail: InputThumbnail?,
        width: Int
    ) {
        self.addedStickerFileIds = addedStickerFileIds
        self.animation = animation
        self.caption = caption
        self.duration = duration
        self.hasSpoiler = hasSpoiler
        self.height = height
        self.showCaptionAboveMedia = showCaptionAboveMedia
        self.thumbnail = thumbnail
        self.width = width
    }
}

/// An audio message
public struct InputMessageAudio: Codable, Equatable, Hashable {

    /// Thumbnail of the cover for the album; pass null to skip thumbnail uploading
    public let albumCoverThumbnail: InputThumbnail?

    /// Audio file to be sent
    public let audio: InputFile

    /// Audio caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// Duration of the audio, in seconds; may be replaced by the server
    public let duration: Int

    /// Performer of the audio; 0-64 characters, may be replaced by the server
    public let performer: String

    /// Title of the audio; 0-64 characters; may be replaced by the server
    public let title: String


    public init(
        albumCoverThumbnail: InputThumbnail?,
        audio: InputFile,
        caption: FormattedText?,
        duration: Int,
        performer: String,
        title: String
    ) {
        self.albumCoverThumbnail = albumCoverThumbnail
        self.audio = audio
        self.caption = caption
        self.duration = duration
        self.performer = performer
        self.title = title
    }
}

/// A document message (general file)
public struct InputMessageDocument: Codable, Equatable, Hashable {

    /// Document caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// Pass true to disable automatic file type detection and send the document as a file. Always true for files sent to secret chats
    public let disableContentTypeDetection: Bool

    /// Document to be sent
    public let document: InputFile

    /// Document thumbnail; pass null to skip thumbnail uploading
    public let thumbnail: InputThumbnail?


    public init(
        caption: FormattedText?,
        disableContentTypeDetection: Bool,
        document: InputFile,
        thumbnail: InputThumbnail?
    ) {
        self.caption = caption
        self.disableContentTypeDetection = disableContentTypeDetection
        self.document = document
        self.thumbnail = thumbnail
    }
}

/// A message with paid media; can be used only in channel chats with supergroupFullInfo.has_paid_media_allowed
public struct InputMessagePaidMedia: Codable, Equatable, Hashable {

    /// Message caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// The content of the paid media
    public let paidMedia: [InputPaidMedia]

    /// Bot-provided data for the paid media; bots only
    public let payload: String

    /// True, if the caption must be shown above the media; otherwise, the caption must be shown below the media; not supported in secret chats
    public let showCaptionAboveMedia: Bool

    /// The number of Telegram Stars that must be paid to see the media; 1-getOption("paid_media_message_star_count_max")
    public let starCount: Int64


    public init(
        caption: FormattedText?,
        paidMedia: [InputPaidMedia],
        payload: String,
        showCaptionAboveMedia: Bool,
        starCount: Int64
    ) {
        self.caption = caption
        self.paidMedia = paidMedia
        self.payload = payload
        self.showCaptionAboveMedia = showCaptionAboveMedia
        self.starCount = starCount
    }
}

/// A photo message
public struct InputMessagePhoto: Codable, Equatable, Hashable {

    /// File identifiers of the stickers added to the photo, if applicable
    public let addedStickerFileIds: [Int]

    /// Photo caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// True, if the photo preview must be covered by a spoiler animation; not supported in secret chats
    public let hasSpoiler: Bool

    /// Photo height
    public let height: Int

    /// Photo to send. The photo must be at most 10 MB in size. The photo's width and height must not exceed 10000 in total. Width and height ratio must be at most 20
    public let photo: InputFile

    /// Photo self-destruct type; pass null if none; private chats only
    public let selfDestructType: MessageSelfDestructType?

    /// True, if the caption must be shown above the photo; otherwise, the caption must be shown below the photo; not supported in secret chats
    public let showCaptionAboveMedia: Bool

    /// Photo thumbnail to be sent; pass null to skip thumbnail uploading. The thumbnail is sent to the other party only in secret chats
    public let thumbnail: InputThumbnail?

    /// Video of the live photo; not supported in secret chats; pass null if the photo isn't a live photo
    public let video: InputFile?

    /// Photo width
    public let width: Int


    public init(
        addedStickerFileIds: [Int],
        caption: FormattedText?,
        hasSpoiler: Bool,
        height: Int,
        photo: InputFile,
        selfDestructType: MessageSelfDestructType?,
        showCaptionAboveMedia: Bool,
        thumbnail: InputThumbnail?,
        video: InputFile?,
        width: Int
    ) {
        self.addedStickerFileIds = addedStickerFileIds
        self.caption = caption
        self.hasSpoiler = hasSpoiler
        self.height = height
        self.photo = photo
        self.selfDestructType = selfDestructType
        self.showCaptionAboveMedia = showCaptionAboveMedia
        self.thumbnail = thumbnail
        self.video = video
        self.width = width
    }
}

/// A sticker message
public struct InputMessageSticker: Codable, Equatable, Hashable {

    /// Emoji used to choose the sticker
    public let emoji: String

    /// Sticker height
    public let height: Int

    /// Sticker to be sent
    public let sticker: InputFile

    /// Sticker thumbnail; pass null to skip thumbnail uploading
    public let thumbnail: InputThumbnail?

    /// Sticker width
    public let width: Int


    public init(
        emoji: String,
        height: Int,
        sticker: InputFile,
        thumbnail: InputThumbnail?,
        width: Int
    ) {
        self.emoji = emoji
        self.height = height
        self.sticker = sticker
        self.thumbnail = thumbnail
        self.width = width
    }
}

/// A video message
public struct InputMessageVideo: Codable, Equatable, Hashable {

    /// File identifiers of the stickers added to the video, if applicable
    public let addedStickerFileIds: [Int]

    /// Video caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// Cover of the video; pass null to skip cover uploading; not supported in secret chats and for self-destructing messages
    public let cover: InputFile?

    /// Duration of the video, in seconds
    public let duration: Int

    /// True, if the video preview must be covered by a spoiler animation; not supported in secret chats
    public let hasSpoiler: Bool

    /// Video height
    public let height: Int

    /// Video self-destruct type; pass null if none; private chats only
    public let selfDestructType: MessageSelfDestructType?

    /// True, if the caption must be shown above the video; otherwise, the caption must be shown below the video; not supported in secret chats
    public let showCaptionAboveMedia: Bool

    /// Timestamp from which the video playing must start, in seconds
    public let startTimestamp: Int

    /// True, if the video is expected to be streamed
    public let supportsStreaming: Bool

    /// Video thumbnail; pass null to skip thumbnail uploading
    public let thumbnail: InputThumbnail?

    /// Video to be sent. The video is expected to be re-encoded to MPEG4 format with H.264 codec by the sender
    public let video: InputFile

    /// Video width
    public let width: Int


    public init(
        addedStickerFileIds: [Int],
        caption: FormattedText?,
        cover: InputFile?,
        duration: Int,
        hasSpoiler: Bool,
        height: Int,
        selfDestructType: MessageSelfDestructType?,
        showCaptionAboveMedia: Bool,
        startTimestamp: Int,
        supportsStreaming: Bool,
        thumbnail: InputThumbnail?,
        video: InputFile,
        width: Int
    ) {
        self.addedStickerFileIds = addedStickerFileIds
        self.caption = caption
        self.cover = cover
        self.duration = duration
        self.hasSpoiler = hasSpoiler
        self.height = height
        self.selfDestructType = selfDestructType
        self.showCaptionAboveMedia = showCaptionAboveMedia
        self.startTimestamp = startTimestamp
        self.supportsStreaming = supportsStreaming
        self.thumbnail = thumbnail
        self.video = video
        self.width = width
    }
}

/// A video note message
public struct InputMessageVideoNote: Codable, Equatable, Hashable {

    /// Duration of the video, in seconds; 0-60
    public let duration: Int

    /// Video width and height; must be positive and not greater than 640
    public let length: Int

    /// Video note self-destruct type; may be null if none; pass null if none; private chats only
    public let selfDestructType: MessageSelfDestructType?

    /// Video thumbnail; may be null if empty; pass null to skip thumbnail uploading
    public let thumbnail: InputThumbnail?

    /// Video note to be sent. The video is expected to be encoded to MPEG4 format with H.264 codec and have no data outside of the visible circle
    public let videoNote: InputFile


    public init(
        duration: Int,
        length: Int,
        selfDestructType: MessageSelfDestructType?,
        thumbnail: InputThumbnail?,
        videoNote: InputFile
    ) {
        self.duration = duration
        self.length = length
        self.selfDestructType = selfDestructType
        self.thumbnail = thumbnail
        self.videoNote = videoNote
    }
}

/// A voice note message
public struct InputMessageVoiceNote: Codable, Equatable, Hashable {

    /// Voice note caption; may be null if empty; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let caption: FormattedText?

    /// Duration of the voice note, in seconds
    public let duration: Int

    /// Voice note self-destruct type; may be null if none; pass null if none; private chats only
    public let selfDestructType: MessageSelfDestructType?

    /// Voice note to be sent. The voice note must be encoded with the Opus codec and stored inside an OGG container with a single audio channel, or be in MP3 or M4A format as regular audio
    public let voiceNote: InputFile

    /// Waveform representation of the voice note in 5-bit format
    public let waveform: Data


    public init(
        caption: FormattedText?,
        duration: Int,
        selfDestructType: MessageSelfDestructType?,
        voiceNote: InputFile,
        waveform: Data
    ) {
        self.caption = caption
        self.duration = duration
        self.selfDestructType = selfDestructType
        self.voiceNote = voiceNote
        self.waveform = waveform
    }
}

/// A message with a location
public struct InputMessageLocation: Codable, Equatable, Hashable {

    /// For live locations, a direction in which the location moves, in degrees; 1-360. Pass 0 if unknown
    public let heading: Int

    /// Period for which the location can be updated, in seconds; must be between 60 and 86400 for a temporary live location, 0x7FFFFFFF for permanent live location, and 0 otherwise
    public let livePeriod: Int

    /// Location to be sent
    public let location: Location

    /// For live locations, a maximum distance to another chat member for proximity alerts, in meters (0-100000). Pass 0 if the notification is disabled. Can't be enabled in channels and Saved Messages
    public let proximityAlertRadius: Int


    public init(
        heading: Int,
        livePeriod: Int,
        location: Location,
        proximityAlertRadius: Int
    ) {
        self.heading = heading
        self.livePeriod = livePeriod
        self.location = location
        self.proximityAlertRadius = proximityAlertRadius
    }
}

/// A message with information about a venue
public struct InputMessageVenue: Codable, Equatable, Hashable {

    /// Venue to send
    public let venue: Venue


    public init(venue: Venue) {
        self.venue = venue
    }
}

/// A message containing a user contact
public struct InputMessageContact: Codable, Equatable, Hashable {

    /// Contact to send
    public let contact: Contact


    public init(contact: Contact) {
        self.contact = contact
    }
}

/// A dice message
public struct InputMessageDice: Codable, Equatable, Hashable {

    /// True, if the chat message draft must be deleted
    public let clearDraft: Bool

    /// Emoji on which the dice throw animation is based
    public let emoji: String


    public init(
        clearDraft: Bool,
        emoji: String
    ) {
        self.clearDraft = clearDraft
        self.emoji = emoji
    }
}

/// A message with a game; not supported for channels or secret chats
public struct InputMessageGame: Codable, Equatable, Hashable {

    /// User identifier of the bot that owns the game
    public let botUserId: Int64

    /// Short name of the game
    public let gameShortName: String


    public init(
        botUserId: Int64,
        gameShortName: String
    ) {
        self.botUserId = botUserId
        self.gameShortName = gameShortName
    }
}

/// A message with an invoice; can be used only by bots
public struct InputMessageInvoice: Codable, Equatable, Hashable {

    public let description: String

    /// Invoice
    public let invoice: Invoice

    /// The content of paid media attached to the invoice; pass null if none
    public let paidMedia: InputPaidMedia?

    /// Paid media caption; pass null to use an empty caption; 0-getOption("message_caption_length_max") characters
    public let paidMediaCaption: FormattedText?

    /// The invoice payload
    public let payload: Data

    /// Product photo height
    public let photoHeight: Int

    /// Product photo size
    public let photoSize: Int

    /// Product photo URL; optional
    public let photoUrl: String

    /// Product photo width
    public let photoWidth: Int

    /// JSON-encoded data about the invoice, which will be shared with the payment provider
    public let providerData: String

    /// Payment provider token; may be empty for payments in Telegram Stars
    public let providerToken: String

    /// Unique invoice bot deep link parameter for the generation of this invoice. If empty, it would be possible to pay directly from forwards of the invoice message
    public let startParameter: String

    /// Product title; 1-32 characters
    public let title: String


    public init(
        description: String,
        invoice: Invoice,
        paidMedia: InputPaidMedia?,
        paidMediaCaption: FormattedText?,
        payload: Data,
        photoHeight: Int,
        photoSize: Int,
        photoUrl: String,
        photoWidth: Int,
        providerData: String,
        providerToken: String,
        startParameter: String,
        title: String
    ) {
        self.description = description
        self.invoice = invoice
        self.paidMedia = paidMedia
        self.paidMediaCaption = paidMediaCaption
        self.payload = payload
        self.photoHeight = photoHeight
        self.photoSize = photoSize
        self.photoUrl = photoUrl
        self.photoWidth = photoWidth
        self.providerData = providerData
        self.providerToken = providerToken
        self.startParameter = startParameter
        self.title = title
    }
}

/// A message with a poll. Polls can't be sent to secret chats and channel direct messages chats. Polls can be sent to a private chat only if the chat is a chat with a bot or the Saved Messages chat
public struct InputMessagePoll: Codable, Equatable, Hashable {

    /// True, if multiple answer options can be chosen simultaneously
    public let allowsMultipleAnswers: Bool

    /// True, if the poll can be answered multiple times
    public let allowsRevoting: Bool

    /// Point in time (Unix timestamp) when the poll will automatically be closed; must be 0-getOption("poll_open_period_max") seconds in the future; pass 0 if not specified
    public let closeDate: Int

    /// The list of two-letter ISO 3166-1 alpha-2 codes of countries, users from which will be able to vote; for channel chats only. If empty, then all users can participate in the poll. There can be up to getOption("poll_country_count_max") chosen countries
    public let countryCodes: [String]

    public let description: FormattedText

    /// True, if the poll results will appear only after the poll closes
    public let hideResultsUntilCloses: Bool

    /// True, if the poll voters are anonymous. Non-anonymous polls can't be sent or forwarded to channels
    public let isAnonymous: Bool

    /// True, if the poll needs to be sent already closed; for bots only
    public let isClosed: Bool

    /// Media attached to the poll; pass null if none. Must be one of the following types: inputMessageAnimation, inputMessageAudio, inputMessageDocument, non-live inputMessageLocation, inputMessagePhoto, inputMessageVenue, or inputMessageVideo without caption
    public let media: InputMessageContent?

    /// True, if only the users that are members of the chat for more than a day will be able to vote; for channel chats only
    public let membersOnly: Bool

    /// Amount of time the poll will be active after creation, in seconds; 0-getOption("poll_open_period_max"); pass 0 if not specified
    public let openPeriod: Int

    /// List of poll answer options; 1-getOption("poll_answer_count_max") options
    public let options: [InputPollOption]

    /// Poll question; 1-255 characters (up to 300 characters for bots). Only custom emoji entities are allowed to be added and only by Premium users
    public let question: FormattedText

    /// True, if poll options must be shown in a fixed random order
    public let shuffleOptions: Bool

    /// Type of the poll
    public let type: InputPollType


    public init(
        allowsMultipleAnswers: Bool,
        allowsRevoting: Bool,
        closeDate: Int,
        countryCodes: [String],
        description: FormattedText,
        hideResultsUntilCloses: Bool,
        isAnonymous: Bool,
        isClosed: Bool,
        media: InputMessageContent?,
        membersOnly: Bool,
        openPeriod: Int,
        options: [InputPollOption],
        question: FormattedText,
        shuffleOptions: Bool,
        type: InputPollType
    ) {
        self.allowsMultipleAnswers = allowsMultipleAnswers
        self.allowsRevoting = allowsRevoting
        self.closeDate = closeDate
        self.countryCodes = countryCodes
        self.description = description
        self.hideResultsUntilCloses = hideResultsUntilCloses
        self.isAnonymous = isAnonymous
        self.isClosed = isClosed
        self.media = media
        self.membersOnly = membersOnly
        self.openPeriod = openPeriod
        self.options = options
        self.question = question
        self.shuffleOptions = shuffleOptions
        self.type = type
    }
}

/// A stake dice message
public struct InputMessageStakeDice: Codable, Equatable, Hashable {

    /// True, if the chat message draft must be deleted
    public let clearDraft: Bool

    /// The Toncoin amount that will be staked; in the smallest units of the currency. Must be in the range getOption("stake_dice_stake_amount_min")-getOption("stake_dice_stake_amount_max")
    public let stakeToncoinAmount: Int64

    /// Hash of the stake dice state. The state hash can be used only if it was received recently enough. Otherwise, a new state must be requested using getStakeDiceState
    public let stateHash: String


    public init(
        clearDraft: Bool,
        stakeToncoinAmount: Int64,
        stateHash: String
    ) {
        self.clearDraft = clearDraft
        self.stakeToncoinAmount = stakeToncoinAmount
        self.stateHash = stateHash
    }
}

/// A message with a forwarded story. Stories can't be forwarded to secret chats. A story can be forwarded only if story.can_be_forwarded
public struct InputMessageStory: Codable, Equatable, Hashable {

    /// Story identifier
    public let storyId: Int

    /// Identifier of the chat that posted the story
    public let storyPosterChatId: Int64


    public init(
        storyId: Int,
        storyPosterChatId: Int64
    ) {
        self.storyId = storyId
        self.storyPosterChatId = storyPosterChatId
    }
}

/// A message with a checklist. Checklists can't be sent to secret chats, channel chats and channel direct messages chats; for Telegram Premium users only
public struct InputMessageChecklist: Codable, Equatable, Hashable {

    /// The checklist to send
    public let checklist: InputChecklist


    public init(checklist: InputChecklist) {
        self.checklist = checklist
    }
}

/// A forwarded message
public struct InputMessageForwarded: Codable, Equatable, Hashable {

    /// Options to be used to copy content of the message without reference to the original sender; pass null to forward the message as usual
    public let copyOptions: MessageCopyOptions?

    /// Identifier for the chat this forwarded message came from
    public let fromChatId: Int64

    /// Pass true if a game message is being shared from a launched game; applies only to game messages
    public let inGameShare: Bool

    /// Identifier of the message to forward. A message can be forwarded only if messageProperties.can_be_forwarded
    public let messageId: Int64

    /// The new video start timestamp; ignored if replace_video_start_timestamp == false
    public let newVideoStartTimestamp: Int

    /// Pass true to replace video start timestamp in the forwarded message
    public let replaceVideoStartTimestamp: Bool


    public init(
        copyOptions: MessageCopyOptions?,
        fromChatId: Int64,
        inGameShare: Bool,
        messageId: Int64,
        newVideoStartTimestamp: Int,
        replaceVideoStartTimestamp: Bool
    ) {
        self.copyOptions = copyOptions
        self.fromChatId = fromChatId
        self.inGameShare = inGameShare
        self.messageId = messageId
        self.newVideoStartTimestamp = newVideoStartTimestamp
        self.replaceVideoStartTimestamp = replaceVideoStartTimestamp
    }
}

