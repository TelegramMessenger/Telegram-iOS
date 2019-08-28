import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AlertUI
import AccountContext

private final class CreateThemeControllerArguments {
    let context: AccountContext
    let updateState: ((CreateThemeControllerState) -> CreateThemeControllerState) -> Void
    
    init(context: AccountContext, updateState: @escaping ((CreateThemeControllerState) -> CreateThemeControllerState) -> Void) {
        self.context = context
        self.updateState = updateState
    }
}

private enum CreateThemeControllerSection: Int32 {
    case chatPreview
    case info
}

private enum CreateThemeControllerEntry: ItemListNodeEntry {
    case chatPreviewHeader(PresentationTheme, String)
    case chatPreview(PresentationTheme, PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder)
    case title(PresentationTheme, PresentationStrings, String, String)
    case slug(PresentationTheme, PresentationStrings, String, String, Bool)
    case slugInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .chatPreviewHeader, .chatPreview:
                return CreateThemeControllerSection.chatPreview.rawValue
            case .title, .slug, .slugInfo:
                return CreateThemeControllerSection.info.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .chatPreviewHeader:
                return 0
            case .chatPreview:
                return 1
            case .title:
                return 2
            case .slug:
                return 3
            case .slugInfo:
                return 4
        }
    }
    
    static func ==(lhs: CreateThemeControllerEntry, rhs: CreateThemeControllerEntry) -> Bool {
        switch lhs {
            case let .chatPreviewHeader(lhsTheme, lhsText):
                if case let .chatPreviewHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .chatPreview(lhsTheme, lhsComponentTheme, lhsWallpaper, lhsFontSize, lhsStrings, lhsTimeFormat, lhsNameOrder):
                if case let .chatPreview(rhsTheme, rhsComponentTheme, rhsWallpaper, rhsFontSize, rhsStrings, rhsTimeFormat, rhsNameOrder) = rhs, lhsComponentTheme === rhsComponentTheme, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat, lhsNameOrder == rhsNameOrder {
                    return true
                } else {
                    return false
                }
            case let .title(lhsTheme, lhsStrings, lhsTitle, lhsValue):
                if case let .title(rhsTheme, rhsStrings, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .slug(lhsTheme, lhsStrings, lhsTitle, lhsValue, lhsEnabled):
                if case let .slug(rhsTheme, rhsStrings, rhsTitle, rhsValue, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsValue == rhsValue, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .slugInfo(lhsTheme, lhsText):
                if case let .slugInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CreateThemeControllerEntry, rhs: CreateThemeControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: CreateThemeControllerArguments) -> ListViewItem {
        switch self {
            case let .chatPreviewHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .chatPreview(theme, componentTheme, wallpaper, fontSize, strings, dateTimeFormat, nameDisplayOrder):
                return ThemeSettingsChatPreviewItem(context: arguments.context, theme: theme, componentTheme: componentTheme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder)
            case let .title(theme, strings, title, text):
                return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(), text: text, placeholder: title, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.title = value
                        return state
                    }
                }, action: {})
            case let .slug(theme, strings, title, text, enabled):
                return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(string: "t.me/addtheme/", textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: title, type: .username, enabled: enabled, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.slug = value
                        return state
                    }
                }, action: {})
            case let .slugInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private enum CreateThemeControllerMode {
    case create
    case update
}

private struct CreateThemeControllerState: Equatable {
    var mode: CreateThemeControllerMode
    var title: String
    var slug: String
    
    var isComplete: Bool {
        if self.title.isEmpty || self.slug.isEmpty {
            return false
        }
        return true
    }
}

private func createThemeControllerEntries(presentationData: PresentationData, theme: PresentationTheme, state: CreateThemeControllerState) -> [CreateThemeControllerEntry] {
    var entries: [CreateThemeControllerEntry] = []
    
    entries.append(.chatPreviewHeader(presentationData.theme, presentationData.strings.CreateTheme_Preview.uppercased()))
    entries.append(.chatPreview(presentationData.theme, theme, theme.chat.defaultWallpaper, presentationData.fontSize, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder))
    
    entries.append(.title(presentationData.theme, presentationData.strings, presentationData.strings.CreateTheme_Title, state.title))
    entries.append(.slug(presentationData.theme, presentationData.strings, presentationData.strings.CreateTheme_ShortLink, state.slug, true))
    entries.append(.slugInfo(presentationData.theme, presentationData.strings.CreateTheme_ShortLinkInfo))
    
    return entries
}

public func createThemeController(context: AccountContext, theme: PresentationTheme, resource: MediaResource) -> ViewController {
    let initialState = CreateThemeControllerState(mode: .create, title: theme.name.string, slug: "")
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateThemeControllerState) -> CreateThemeControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let arguments = CreateThemeControllerArguments(context: context, updateState: { f in
        updateState(f)
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<CreateThemeControllerEntry>, CreateThemeControllerEntry.ItemGenerationArguments)) in
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
                let _ = (createTheme(account: context.account, resource: resource, title: state.title, slug: state.slug) |> deliverOnMainQueue).start(completed: {
                    dismissImpl?()
                })
            })
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.CreateTheme_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: createThemeControllerEntries(presentationData: presentationData, theme: theme, state: state), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    return controller
}
