import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TwelveSettings

private final class TwelveSettingsControllerArguments {
    let toggle: (TwelveSettings.Key, Bool) -> Void
    
    init(toggle: @escaping (TwelveSettings.Key, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum TwelveSettingsSection: Int32 {
    case ads
    case messages
    case ghost
}

private enum TwelveSettingsEntry: ItemListNodeEntry {
    case header(section: TwelveSettingsSection, id: Int32, text: String)
    case toggle(section: TwelveSettingsSection, id: Int32, key: TwelveSettings.Key, title: String, value: Bool)
    case footer(section: TwelveSettingsSection, id: Int32, text: String)
    
    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .toggle(section, _, _, _, _), let .footer(section, _, _):
            return section.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case let .header(_, id, _), let .toggle(_, id, _, _, _), let .footer(_, id, _):
            return id
        }
    }
    
    static func <(lhs: TwelveSettingsEntry, rhs: TwelveSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TwelveSettingsControllerArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, key, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct TwelveStrings {
    let title: String
    let adsHeader: String
    let hideAds: String
    let adsFooter: String
    let messagesHeader: String
    let saveDeleted: String
    let saveEdits: String
    let messagesFooter: String
    let ghostHeader: String
    let ghostOnline: String
    let ghostTyping: String
    let ghostRead: String
    let ghostStories: String
    let ghostFooter: String
    
    init(languageCode: String) {
        if languageCode == "ru" {
            self.title = "Настройки Twelve"
            self.adsHeader = "РЕКЛАМА"
            self.hideAds = "Убрать рекламу"
            self.adsFooter = "Не загружать спонсорские сообщения в каналах, ботах и видео, рекламные каналы в поиске и спонсорский канал прокси."
            self.messagesHeader = "СООБЩЕНИЯ"
            self.saveDeleted = "Сохранять удалённые сообщения"
            self.saveEdits = "Сохранять историю правок"
            self.messagesFooter = "Удалённые собеседником сообщения остаются в чате с пометкой 🗑. Старые версии изменённых сообщений доступны по долгому нажатию: «История правок»."
            self.ghostHeader = "РЕЖИМ ПРИЗРАКА"
            self.ghostOnline = "Не показывать «в сети»"
            self.ghostTyping = "Не отправлять «печатает»"
            self.ghostRead = "Не отправлять прочтение"
            self.ghostStories = "Смотреть истории анонимно"
            self.ghostFooter = "Прочитанные чаты помечаются прочитанными только на этом устройстве, у собеседника сообщения остаются непрочитанными."
        } else {
            self.title = "Twelve Settings"
            self.adsHeader = "ADS"
            self.hideAds = "Hide Ads"
            self.adsFooter = "Don't load sponsored messages in channels, bots and videos, sponsored channels in search and the proxy sponsor channel."
            self.messagesHeader = "MESSAGES"
            self.saveDeleted = "Save Deleted Messages"
            self.saveEdits = "Save Edit History"
            self.messagesFooter = "Messages deleted by others stay in the chat marked with 🗑. Previous versions of edited messages are available on long press: \"Edit History\"."
            self.ghostHeader = "GHOST MODE"
            self.ghostOnline = "Don't Send Online Status"
            self.ghostTyping = "Don't Send Typing"
            self.ghostRead = "Don't Send Read Receipts"
            self.ghostStories = "View Stories Anonymously"
            self.ghostFooter = "Chats are marked as read on this device only; your messages stay unread for the other side."
        }
    }
}

private func twelveSettingsEntries(strings: TwelveStrings, values: [TwelveSettings.Key: Bool]) -> [TwelveSettingsEntry] {
    var entries: [TwelveSettingsEntry] = []
    func value(_ key: TwelveSettings.Key) -> Bool {
        return values[key] ?? false
    }
    entries.append(.header(section: .ads, id: 0, text: strings.adsHeader))
    entries.append(.toggle(section: .ads, id: 1, key: .hideAds, title: strings.hideAds, value: value(.hideAds)))
    entries.append(.footer(section: .ads, id: 2, text: strings.adsFooter))
    
    entries.append(.header(section: .messages, id: 10, text: strings.messagesHeader))
    entries.append(.toggle(section: .messages, id: 11, key: .saveDeletedMessages, title: strings.saveDeleted, value: value(.saveDeletedMessages)))
    entries.append(.toggle(section: .messages, id: 12, key: .saveEditHistory, title: strings.saveEdits, value: value(.saveEditHistory)))
    entries.append(.footer(section: .messages, id: 13, text: strings.messagesFooter))
    
    entries.append(.header(section: .ghost, id: 20, text: strings.ghostHeader))
    entries.append(.toggle(section: .ghost, id: 21, key: .ghostOnline, title: strings.ghostOnline, value: value(.ghostOnline)))
    entries.append(.toggle(section: .ghost, id: 22, key: .ghostTyping, title: strings.ghostTyping, value: value(.ghostTyping)))
    entries.append(.toggle(section: .ghost, id: 23, key: .ghostRead, title: strings.ghostRead, value: value(.ghostRead)))
    entries.append(.toggle(section: .ghost, id: 24, key: .ghostStories, title: strings.ghostStories, value: value(.ghostStories)))
    entries.append(.footer(section: .ghost, id: 25, text: strings.ghostFooter))
    return entries
}

private func currentTwelveValues() -> [TwelveSettings.Key: Bool] {
    var values: [TwelveSettings.Key: Bool] = [:]
    for key in TwelveSettings.Key.allCases {
        values[key] = TwelveSettings.value(key)
    }
    return values
}

/// Settings ▸ Настройки Twelve.
public func twelveSettingsController(context: AccountContext) -> ViewController {
    let valuesPromise = ValuePromise<[TwelveSettings.Key: Bool]>(currentTwelveValues(), ignoreRepeated: true)
    
    let arguments = TwelveSettingsControllerArguments(toggle: { key, value in
        TwelveSettings.set(key, value: value)
        valuesPromise.set(currentTwelveValues())
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, valuesPromise.get())
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = TwelveStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: twelveSettingsEntries(strings: strings, values: values), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    
    return ItemListController(context: context, state: signal)
}

