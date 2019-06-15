import Foundation
import TelegramCore
import Display
import TelegramPresentationData

import TelegramUIPrivateModule

func legacyChannelIntroController(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) -> ViewController {
    let controller = LegacyController(presentation: .custom, theme: theme)
    controller.bind(controller: TGChannelIntroController(context: controller.context, getLocalizedString: { string in
        guard let string = string else {
            return nil
        }
        if let value = strings.primaryComponent.dict[string] {
            return value
        } else if let value = strings.secondaryComponent?.dict[string] {
            return value
        } else {
            return string
        }
    }, theme: TGChannelIntroControllerTheme(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, secondaryColor: theme.list.itemSecondaryTextColor, accentColor: theme.list.itemAccentColor, backArrowImage: NavigationBarTheme.generateBackArrowImage(color: theme.list.itemAccentColor), introImage: UIImage(bundleImageName: "Chat/Intro/ChannelIntro")), dismiss: { [weak controller] in
            if let navigationController = controller?.navigationController as? NavigationController {
                _ = navigationController.popViewController(animated: true)
            }
        }, completion: { [weak controller] in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.replaceTopController(createChannelController(context: context), animated: true)
        }
    })!)
    return controller
}
