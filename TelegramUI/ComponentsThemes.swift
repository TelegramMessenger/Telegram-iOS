import Foundation
import Display

public extension TabBarControllerTheme {
    public convenience init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.tabBar
        self.init(backgroundColor: rootControllerTheme.list.plainBackgroundColor, tabBarBackgroundColor: theme.backgroundColor, tabBarSeparatorColor: theme.separatorColor, tabBarTextColor: theme.textColor, tabBarSelectedTextColor: theme.selectedIconColor, tabBarBadgeBackgroundColor: theme.badgeBackgroundColor, tabBarBadgeStrokeColor: theme.badgeStrokeColor, tabBarBadgeTextColor: theme.badgeTextColor)
    }
}

public extension NavigationBarTheme {
    public convenience init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.navigationBar
        self.init(buttonColor: theme.buttonColor, disabledButtonColor: theme.disabledButtonColor, primaryTextColor: theme.primaryTextColor, backgroundColor: theme.backgroundColor, separatorColor: theme.separatorColor, badgeBackgroundColor: theme.badgeBackgroundColor, badgeStrokeColor: theme.badgeStrokeColor, badgeTextColor: theme.badgeTextColor)
    }
}

public extension NavigationBarStrings {
    public convenience init(presentationStrings: PresentationStrings) {
        self.init(back: presentationStrings.Common_Back, close: presentationStrings.Common_Close)
    }
}

public extension NavigationBarPresentationData {
    public convenience init(presentationData: PresentationData) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }
}

extension ActionSheetControllerTheme {
    convenience init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(dimColor: actionSheet.dimColor, backgroundType: actionSheet.backgroundType == .light ? .light : .dark, itemBackgroundColor: actionSheet.itemBackgroundColor, itemHighlightedBackgroundColor: actionSheet.itemHighlightedBackgroundColor, standardActionTextColor: actionSheet.standardActionTextColor, destructiveActionTextColor: actionSheet.destructiveActionTextColor, disabledActionTextColor: actionSheet.disabledActionTextColor, primaryTextColor: actionSheet.primaryTextColor, secondaryTextColor: actionSheet.secondaryTextColor, controlAccentColor: actionSheet.controlAccentColor, controlColor: presentationTheme.list.disclosureArrowColor)
    }
}

extension ActionSheetController {
    convenience init(presentationTheme: PresentationTheme) {
        self.init(theme: ActionSheetControllerTheme(presentationTheme: presentationTheme))
    }
}

public extension AlertControllerTheme {
    convenience init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(backgroundColor: actionSheet.opaqueItemBackgroundColor, separatorColor: actionSheet.opaqueItemSeparatorColor, highlightedItemColor: actionSheet.opaqueItemHighlightedBackgroundColor, primaryColor: actionSheet.primaryTextColor, secondaryColor: actionSheet.secondaryTextColor, accentColor: actionSheet.controlAccentColor, destructiveColor: actionSheet.destructiveActionTextColor)
    }
    
    convenience init(authTheme: AuthorizationTheme) {
        self.init(backgroundColor: authTheme.alertBackgroundColor, separatorColor: authTheme.separatorColor, highlightedItemColor: authTheme.itemHighlightedBackgroundColor, primaryColor: authTheme.primaryColor, secondaryColor: authTheme.textPlaceholderColor, accentColor: authTheme.accentColor, destructiveColor: authTheme.destructiveColor)
    }
}

extension PeekControllerTheme {
    convenience init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(isDark: actionSheet.backgroundType == .dark, menuBackgroundColor: actionSheet.opaqueItemBackgroundColor, menuItemHighligtedColor: actionSheet.opaqueItemHighlightedBackgroundColor, menuItemSeparatorColor: actionSheet.opaqueItemSeparatorColor, accentColor: actionSheet.controlAccentColor, destructiveColor: actionSheet.destructiveActionTextColor)
    }
}

public extension NavigationControllerTheme {
    convenience init(presentationTheme: PresentationTheme) {
        self.init(navigationBar: NavigationBarTheme(rootControllerTheme: presentationTheme), emptyAreaColor: presentationTheme.chatList.backgroundColor, emptyDetailIcon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/EmptyMasterDetailIcon"), color: presentationTheme.chatList.messageTextColor.withAlphaComponent(0.2)))
    }
}
