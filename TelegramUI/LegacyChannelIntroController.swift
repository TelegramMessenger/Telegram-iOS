import Foundation
import TelegramCore
import Display

import TelegramUIPrivateModule

func legacyChannelIntroController(account: Account, theme: PresentationTheme, strings: PresentationStrings) -> ViewController {
    let controller = LegacyController(presentation: .custom, theme: theme)
    controller.bind(controller: TGChannelIntroController(context: controller.context, getLocalizedString: { string in
        return strings.dict[string!] ?? string
    }, theme: TGChannelIntroControllerTheme(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, secondaryColor: theme.list.itemSecondaryTextColor, accentColor: theme.list.itemAccentColor, backArrowImage: NavigationBarTheme.generateBackArrowImage(color: theme.list.itemAccentColor), introImage: UIImage(bundleImageName: "Chat/Intro/ChannelIntro")), completion: { [weak controller] in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.replaceTopController(createChannelController(account: account), animated: true)
        }
    })!)
    return controller
}
