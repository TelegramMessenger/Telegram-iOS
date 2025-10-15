import Postbox

public enum EngineMedia: Equatable {
    public typealias Id = MediaId

    case image(TelegramMediaImage)
    case file(TelegramMediaFile)
    case geo(TelegramMediaMap)
    case contact(TelegramMediaContact)
    case action(TelegramMediaAction)
    case dice(TelegramMediaDice)
    case expiredContent(TelegramMediaExpiredContent)
    case game(TelegramMediaGame)
    case invoice(TelegramMediaInvoice)
    case poll(TelegramMediaPoll)
    case unsupported(TelegramMediaUnsupported)
    case webFile(TelegramMediaWebFile)
    case webpage(TelegramMediaWebpage)
    case story(TelegramMediaStory)
    case giveaway(TelegramMediaGiveaway)
    case giveawayResults(TelegramMediaGiveawayResults)
    case paidContent(TelegramMediaPaidContent)
    case todo(TelegramMediaTodo)
}

public extension EngineMedia {
    var id: Id? {
        switch self {
        case let .image(image):
            return image.id
        case let .file(file):
            return file.id
        case let .geo(geo):
            return geo.id
        case let .contact(contact):
            return contact.id
        case let .action(action):
            return action.id
        case let .dice(dice):
            return dice.id
        case let .expiredContent(expiredContent):
            return expiredContent.id
        case let .game(game):
            return game.id
        case let .invoice(invoice):
            return invoice.id
        case let .poll(poll):
            return poll.id
        case let .unsupported(unsupported):
            return unsupported.id
        case let .webFile(webFile):
            return webFile.id
        case let .webpage(webpage):
            return webpage.id
        case let .story(story):
            return story.id
        case let .giveaway(giveaway):
            return giveaway.id
        case let .giveawayResults(giveawayResults):
            return giveawayResults.id
        case let .paidContent(paidContent):
            return paidContent.id
        case .todo:
            return nil
        }
    }
}

public extension EngineMedia {
    init(_ media: Media) {
        switch media {
        case let image as TelegramMediaImage:
            self = .image(image)
        case let file as TelegramMediaFile:
            self = .file(file)
        case let geo as TelegramMediaMap:
            self = .geo(geo)
        case let contact as TelegramMediaContact:
            self = .contact(contact)
        case let action as TelegramMediaAction:
            self = .action(action)
        case let dice as TelegramMediaDice:
            self = .dice(dice)
        case let expiredContent as TelegramMediaExpiredContent:
            self = .expiredContent(expiredContent)
        case let game as TelegramMediaGame:
            self = .game(game)
        case let invoice as TelegramMediaInvoice:
            self = .invoice(invoice)
        case let poll as TelegramMediaPoll:
            self = .poll(poll)
        case let unsupported as TelegramMediaUnsupported:
            self = .unsupported(unsupported)
        case let webFile as TelegramMediaWebFile:
            self = .webFile(webFile)
        case let webpage as TelegramMediaWebpage:
            self = .webpage(webpage)
        case let story as TelegramMediaStory:
            self = .story(story)
        case let giveaway as TelegramMediaGiveaway:
            self = .giveaway(giveaway)
        case let giveawayResults as TelegramMediaGiveawayResults:
            self = .giveawayResults(giveawayResults)
        case let paidContent as TelegramMediaPaidContent:
            self = .paidContent(paidContent)
        case let todo as TelegramMediaTodo:
            self = .todo(todo)
        default:
            preconditionFailure()
        }
    }

    func _asMedia() -> Media {
        switch self {
        case let .image(image):
            return image
        case let .file(file):
            return file
        case let .geo(geo):
            return geo
        case let .contact(contact):
            return contact
        case let .action(action):
            return action
        case let .dice(dice):
            return dice
        case let .expiredContent(expiredContent):
            return expiredContent
        case let .game(game):
            return game
        case let .invoice(invoice):
            return invoice
        case let .poll(poll):
            return poll
        case let .unsupported(unsupported):
            return unsupported
        case let .webFile(webFile):
            return webFile
        case let .webpage(webpage):
            return webpage
        case let .story(story):
            return story
        case let .giveaway(giveaway):
            return giveaway
        case let .giveawayResults(giveawayResults):
            return giveawayResults
        case let .paidContent(paidContent):
            return paidContent
        case let .todo(todo):
            return todo
        }
    }
}
