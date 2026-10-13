import Foundation
import Postbox
import TelegramApi

extension BotMenuButton {
    init(apiBotMenuButton: Api.BotMenuButton) {
        switch apiBotMenuButton {
            case .botMenuButtonCommands, .botMenuButtonDefault:
                self = .commands
            case let .botMenuButton(botMenuButtonData):
                let (text, url) = (botMenuButtonData.text, botMenuButtonData.url)
                self = .webView(text: text, url: url)
        }
    }
}

extension BotAppSettings {
    init(apiBotAppSettings: Api.BotAppSettings) {
        switch apiBotAppSettings {
        case let .botAppSettings(botAppSettingsData):
            let (_, placeholder, backgroundColor, backgroundDarkColor, headerColor, headerDarkColor) = (botAppSettingsData.flags, botAppSettingsData.placeholderPath, botAppSettingsData.backgroundColor, botAppSettingsData.backgroundDarkColor, botAppSettingsData.headerColor, botAppSettingsData.headerDarkColor)
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
        case let .botVerifierSettings(botVerifierSettingsData):
            let (flags, iconFileId, companyName, customDescription) = (botVerifierSettingsData.flags, botVerifierSettingsData.icon, botVerifierSettingsData.company, botVerifierSettingsData.customDescription)
            var text: String?
            var entities: [MessageTextEntity]?
            if case let .textWithEntities(textWithEntitiesData) = customDescription {
                text = textWithEntitiesData.text
                entities = messageTextEntitiesFromApiEntities(textWithEntitiesData.entities)
            }
            self.init(
                iconFileId: iconFileId,
                companyName: companyName,
                customDescription: text,
                customDescriptionEntities: entities,
                canModifyDescription: (flags & (1 << 1)) != 0
            )
        }
    }
}

extension BotInfo {
    convenience init(apiBotInfo: Api.BotInfo) {
        switch apiBotInfo {
            case let .botInfo(botInfoData):
                let (_, _, description, descriptionPhoto, descriptionDocument, apiCommands, apiMenuButton, privacyPolicyUrl, appSettings, verifierSettings) = (botInfoData.flags, botInfoData.userId, botInfoData.description, botInfoData.descriptionPhoto, botInfoData.descriptionDocument, botInfoData.commands, botInfoData.menuButton, botInfoData.privacyPolicyUrl, botInfoData.appSettings, botInfoData.verifierSettings)
                let photo: TelegramMediaImage? = descriptionPhoto.flatMap { telegramMediaImageFromApiPhoto($0) }
                let video: TelegramMediaFile? = descriptionDocument.flatMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
                var commands: [BotCommand] = []
                if let apiCommands = apiCommands {
                    commands = apiCommands.map { command in
                        switch command {
                            case let .botCommand(botCommandData):
                                let (flags, command, description) = (botCommandData.flags, botCommandData.command, botCommandData.description)
                                return BotCommand(text: command, description: description, isEphemeral: (flags & (1 << 0)) != 0)
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
