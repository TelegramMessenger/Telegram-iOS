import Foundation
import Postbox
import TelegramApi

extension BotMenuButton {
    init(apiBotMenuButton: Api.BotMenuButton) {
        switch apiBotMenuButton {
            case .botMenuButtonCommands, .botMenuButtonDefault:
                self = .commands
            case let .botMenuButton(text, url):
                self = .webView(text: text, url: url)
        }
    }
}

extension BotAppSettings {
    init(apiBotAppSettings: Api.BotAppSettings) {
        switch apiBotAppSettings {
        case let .botAppSettings(_, placeholder, backgroundColor, backgroundDarkColor, headerColor, headerDarkColor):
            self.init(
                placeholderData: placeholder.flatMap { $0.makeData() },
                backgroundColor: backgroundColor,
                backgroundDarkColor: backgroundDarkColor,
                headerColor: headerColor,
                headerDarkColor: headerDarkColor
            )
        }
    }
}

extension BotVerifierSettings {
    init(apiBotVerifierSettings: Api.BotVerifierSettings) {
        switch apiBotVerifierSettings {
        case let .botVerifierSettings(flags, iconFileId, companyName, customDescription):
            self.init(
                iconFileId: iconFileId,
                companyName: companyName,
                customDescription: customDescription,
                canModifyDescription: (flags & (1 << 1)) != 0
            )
        }
    }
}

extension BotInfo {
    convenience init(apiBotInfo: Api.BotInfo) {
        switch apiBotInfo {
            case let .botInfo(_, _, description, descriptionPhoto, descriptionDocument, apiCommands, apiMenuButton, privacyPolicyUrl, appSettings, verifierSettings):
                let photo: TelegramMediaImage? = descriptionPhoto.flatMap(telegramMediaImageFromApiPhoto)
                let video: TelegramMediaFile? = descriptionDocument.flatMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
                var commands: [BotCommand] = []
                if let apiCommands = apiCommands {
                    commands = apiCommands.map { command in
                        switch command {
                            case let .botCommand(command, description):
                                return BotCommand(text: command, description: description)
                        }
                    }
                }
                var menuButton: BotMenuButton = .commands
                if let apiMenuButton = apiMenuButton {
                    menuButton = BotMenuButton(apiBotMenuButton: apiMenuButton)
                }
            self.init(description: description ?? "", photo: photo, video: video, commands: commands, menuButton: menuButton, privacyPolicyUrl: privacyPolicyUrl, appSettings: appSettings.flatMap { BotAppSettings(apiBotAppSettings: $0) }, verifierSettings: verifierSettings.flatMap { BotVerifierSettings(apiBotVerifierSettings: $0) })
        }
    }
}
