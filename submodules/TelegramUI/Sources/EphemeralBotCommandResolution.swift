import Foundation
import TelegramCore

struct ResolvedEphemeralBotCommand {
    let botPeerId: EnginePeer.Id
    let text: String
    let entities: [MessageTextEntity]
}

private struct ParsedBotCommandToken {
    let command: String
    let botAddressName: String?
    let length: Int
}

private func isBotCommandScalar(_ scalar: UnicodeScalar) -> Bool {
    if scalar.value >= 48 && scalar.value <= 57 {
        return true
    }
    if scalar.value >= 65 && scalar.value <= 90 {
        return true
    }
    if scalar.value >= 97 && scalar.value <= 122 {
        return true
    }
    return scalar.value == 95
}

private func parseFirstBotCommandToken(_ text: String) -> ParsedBotCommandToken? {
    let nsText = text as NSString
    if nsText.length < 2 || nsText.character(at: 0) != 47 {
        return nil
    }

    var index = 1
    while index < nsText.length {
        let value = nsText.character(at: index)
        guard let scalar = UnicodeScalar(Int(value)), isBotCommandScalar(scalar) else {
            break
        }
        index += 1
    }

    if index == 1 {
        return nil
    }

    let command = nsText.substring(with: NSRange(location: 1, length: index - 1))
    var botAddressName: String?

    if index < nsText.length && nsText.character(at: index) == 64 {
        let botStartIndex = index + 1
        index = botStartIndex
        while index < nsText.length {
            let value = nsText.character(at: index)
            guard let scalar = UnicodeScalar(Int(value)), isBotCommandScalar(scalar) else {
                break
            }
            index += 1
        }
        if index == botStartIndex {
            return nil
        }
        botAddressName = nsText.substring(with: NSRange(location: botStartIndex, length: index - botStartIndex))
    }

    if index < nsText.length {
        let value = nsText.character(at: index)
        guard let scalar = UnicodeScalar(Int(value)), CharacterSet.whitespacesAndNewlines.contains(scalar) else {
            return nil
        }
    }

    return ParsedBotCommandToken(command: command, botAddressName: botAddressName, length: index)
}

func mayContainTypedEphemeralBotCommand(_ text: String) -> Bool {
    return parseFirstBotCommandToken(text) != nil
}

func resolveEphemeralBotCommand(text: String, peerCommands: PeerCommands, forcedBotPeerId: EnginePeer.Id? = nil) -> ResolvedEphemeralBotCommand? {
    guard let parsed = parseFirstBotCommandToken(text) else {
        return nil
    }

    var matches = peerCommands.commands.filter { command in
        if command.command.text != parsed.command {
            return false
        }
        if let forcedBotPeerId, command.peer.id != forcedBotPeerId {
            return false
        }
        if let botAddressName = parsed.botAddressName {
            guard let addressName = command.peer.addressName else {
                return false
            }
            return addressName.caseInsensitiveCompare(botAddressName) == .orderedSame
        }
        return true
    }

    if forcedBotPeerId == nil && parsed.botAddressName == nil && matches.count != 1 {
        return nil
    }

    if forcedBotPeerId != nil {
        matches = Array(matches.prefix(1))
    }

    guard let match = matches.first, match.command.isEphemeral else {
        return nil
    }

    let resolvedText: String
    let commandLength: Int
    if parsed.botAddressName == nil, let addressName = match.peer.addressName, !addressName.isEmpty {
        let commandText = "/\(parsed.command)@\(addressName)"
        let suffix = (text as NSString).substring(from: parsed.length)
        resolvedText = commandText + suffix
        commandLength = (commandText as NSString).length
    } else {
        resolvedText = text
        commandLength = parsed.length
    }

    return ResolvedEphemeralBotCommand(
        botPeerId: match.peer.id,
        text: resolvedText,
        entities: [MessageTextEntity(range: 0 ..< commandLength, type: .BotCommand)]
    )
}
