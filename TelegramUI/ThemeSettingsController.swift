import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ThemeSettingsControllerArguments {
    let account: Account
    let selectTheme: (Int32) -> Void
    let selectFontSize: (PresentationFontSize) -> Void
    let openWallpaperSettings: () -> Void
    
    init(account: Account, selectTheme: @escaping (Int32) -> Void, selectFontSize: @escaping (PresentationFontSize) -> Void, openWallpaperSettings: @escaping () -> Void) {
        self.account = account
        self.selectTheme = selectTheme
        self.selectFontSize = selectFontSize
        self.openWallpaperSettings = openWallpaperSettings
    }
}

private enum ThemeSettingsControllerSection: Int32 {
    case chatPreview
    case themeList
    case fontSize
}

private enum ThemeSettingsControllerEntry: ItemListNodeEntry {
    case fontSizeHeader(PresentationTheme, String)
    case fontSize(PresentationTheme, PresentationFontSize)
    case chatPreviewHeader(PresentationTheme, String)
    case chatPreview(PresentationTheme, TelegramWallpaper, PresentationFontSize, PresentationStrings, PresentationTimeFormat)
    case wallpaper(PresentationTheme, String)
    case themeListHeader(PresentationTheme, String)
    case themeItem(PresentationTheme, String, Bool, Int32)
    
    var section: ItemListSectionId {
        switch self {
            case .chatPreviewHeader, .chatPreview, .wallpaper:
                return ThemeSettingsControllerSection.chatPreview.rawValue
            case .themeListHeader, .themeItem:
                return ThemeSettingsControllerSection.themeList.rawValue
            case .fontSizeHeader, .fontSize:
                return ThemeSettingsControllerSection.fontSize.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .fontSizeHeader:
                return 0
            case .fontSize:
                return 1
            case .chatPreviewHeader:
                return 2
            case .chatPreview:
                return 3
            case .wallpaper:
                return 4
            case .themeListHeader:
                return 5
            case let .themeItem(_, _, _, index):
                return 6 + index
        }
    }
    
    static func ==(lhs: ThemeSettingsControllerEntry, rhs: ThemeSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .chatPreviewHeader(lhsTheme, lhsText):
                if case let .chatPreviewHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .chatPreview(lhsTheme, lhsWallpaper, lhsFontSize, lhsStrings, lhsTimeFormat):
                if case let .chatPreview(rhsTheme, rhsWallpaper, rhsFontSize, rhsStrings, rhsTimeFormat) = rhs, lhsTheme === rhsTheme, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsStrings === rhsStrings, lhsTimeFormat == rhsTimeFormat {
                    return true
                } else {
                    return false
                }
            case let .wallpaper(lhsTheme, lhsText):
                if case let .wallpaper(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .themeListHeader(lhsTheme, lhsText):
                if case let .themeListHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .themeItem(lhsTheme, lhsText, lhsValue, lhsIndex):
                if case let .themeItem(rhsTheme, rhsText, rhsValue, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .fontSizeHeader(lhsTheme, lhsText):
                if case let .fontSizeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .fontSize(lhsTheme, lhsFontSize):
                if case let .fontSize(rhsTheme, rhsFontSize) = rhs, lhsTheme === rhsTheme, lhsFontSize == rhsFontSize {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemeSettingsControllerEntry, rhs: ThemeSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ThemeSettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .fontSizeHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .fontSize(theme, fontSize):
                return ThemeSettingsFontSizeItem(theme: theme, fontSize: fontSize, sectionId: self.section, updated: { value in
                    arguments.selectFontSize(value)
                })
            case let .chatPreviewHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .chatPreview(theme, wallpaper, fontSize, strings, timeFormat):
                return ThemeSettingsChatPreviewItem(account: arguments.account, theme: theme, strings: strings, sectionId: self.section, fontSize: fontSize, wallpaper: wallpaper, timeFormat: timeFormat)
            case let .wallpaper(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openWallpaperSettings()
                })
            case let .themeListHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .themeItem(theme, title, value, index):
                return ItemListCheckboxItem(theme: theme, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.selectTheme(index)
                })
        }
    }
}

private func themeSettingsControllerEntries(theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, timeFormat: PresentationTimeFormat) -> [ThemeSettingsControllerEntry] {
    var entries: [ThemeSettingsControllerEntry] = []
    
    entries.append(.fontSizeHeader(theme, "TEXT SIZE"))
    entries.append(.fontSize(theme, fontSize))
    entries.append(.chatPreviewHeader(theme, "CHAT PREVIEW"))
    entries.append(.chatPreview(theme, wallpaper, fontSize, strings, timeFormat))
    entries.append(.wallpaper(theme, "Chat Background"))
    entries.append(.themeListHeader(theme, "COLOR THEME"))
    entries.append(.themeItem(theme, "Day Classic", theme.name == .builtin(.dayClassic), 0))
    entries.append(.themeItem(theme, "Day", theme.name == .builtin(.day), 1))
    entries.append(.themeItem(theme, "Night", theme.name == .builtin(.nightGrayscale), 2))
    entries.append(.themeItem(theme, "Night Blue", theme.name == .builtin(.nightAccent), 3))
    
    return entries
}

public func themeSettingsController(account: Account) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = ThemeSettingsControllerArguments(account: account, selectTheme: { index in
        let _ = updatePresentationThemeSettingsInteractively(postbox: account.postbox, { current in
            let wallpaper: TelegramWallpaper
            let theme: PresentationThemeReference
            if index == 0 {
                wallpaper = .builtin
                theme = .builtin(.dayClassic)
            } else if index == 1 {
                wallpaper = .color(0xffffff)
                theme = .builtin(.day)
            } else if index == 2 {
                wallpaper = .color(0x000000)
                theme = .builtin(.nightGrayscale)
            } else {
                wallpaper = .color(0x18222D)
                theme = .builtin(.nightAccent)
            }
            return PresentationThemeSettings(chatWallpaper: wallpaper, theme: theme, fontSize: current.fontSize)
        }).start()
    }, selectFontSize: { size in
        let _ = updatePresentationThemeSettingsInteractively(postbox: account.postbox, { current in
            return PresentationThemeSettings(chatWallpaper: current.chatWallpaper, theme: current.theme, fontSize: size)
        }).start()
    }, openWallpaperSettings: {
        pushControllerImpl?(ThemeGridController(account: account))
    })
    
    let themeSettingsKey = ApplicationSpecificPreferencesKeys.presentationThemeSettings
    let localizationSettingsKey = PreferencesKeys.localizationSettings
    let preferences = account.postbox.preferencesView(keys: [themeSettingsKey, localizationSettingsKey])
    
    let previousTheme = Atomic<PresentationTheme?>(value: nil)
    
    let signal = preferences
        |> deliverOnMainQueue
        |> map { preferences -> (ItemListControllerState, (ItemListNodeState<ThemeSettingsControllerEntry>, ThemeSettingsControllerEntry.ItemGenerationArguments)) in
            let theme: PresentationTheme
            let fontSize: PresentationFontSize
            let wallpaper: TelegramWallpaper
            let strings: PresentationStrings
            let timeFormat: PresentationTimeFormat
            
            let settings = (preferences.values[themeSettingsKey] as? PresentationThemeSettings) ?? PresentationThemeSettings.defaultSettings
            switch settings.theme {
                case let .builtin(reference):
                    switch reference {
                        case .dayClassic:
                            theme = defaultPresentationTheme
                        case .nightGrayscale:
                            theme = defaultDarkPresentationTheme
                        case .nightAccent:
                            theme = defaultDarkAccentPresentationTheme
                        case .day:
                            theme = defaultDayPresentationTheme
                }
            }
            wallpaper = settings.chatWallpaper
            fontSize = settings.fontSize
            
            if let entry = preferences.values[localizationSettingsKey] as? LocalizationSettings {
                strings = PresentationStrings(languageCode: entry.languageCode, dict: dictFromLocalization(entry.localization))
            } else {
                strings = defaultPresentationStrings
            }
            
            timeFormat = .regular
            
            let controllerState = ItemListControllerState(theme: theme, title: .text("Appearance"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: strings.Common_Back))
            let listState = ItemListNodeState(entries: themeSettingsControllerEntries(theme: theme, strings: strings, wallpaper: wallpaper, fontSize: fontSize, timeFormat: timeFormat), style: .blocks, animateChanges: false)
            
            if previousTheme.swap(theme) !== theme {
                presentControllerImpl?(ThemeSettingsCrossfadeController())
            }
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

private final class ThemeSettingsCrossfadeController: ViewController {
    private let snapshotView: UIView?
    
    init() {
        self.snapshotView = UIScreen.main.snapshotView(afterScreenUpdates: false)
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Hide
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ViewControllerTracingNode()
        
        self.displayNode.backgroundColor = nil
        self.displayNode.isOpaque = false
        if let snapshotView = self.snapshotView {
            self.displayNode.view.addSubview(snapshotView)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
