import Foundation
import Display

extension TabBarControllerTheme {
    convenience init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.tabBar
        self.init(backgroundColor: rootControllerTheme.list.plainBackgroundColor, tabBarBackgroundColor: theme.backgroundColor, tabBarSeparatorColor: theme.separatorColor, tabBarTextColor: theme.textColor, tabBarSelectedTextColor: theme.selectedIconColor, tabBarBadgeBackgroundColor: theme.badgeBackgroundColor, tabBarBadgeTextColor: theme.badgeTextColor)
    }
}

extension NavigationBarTheme {
    convenience init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.navigationBar
        self.init(buttonColor: theme.buttonColor, primaryTextColor: theme.primaryTextColor, backgroundColor: theme.backgroundColor, separatorColor: theme.separatorColor)
    }
}
