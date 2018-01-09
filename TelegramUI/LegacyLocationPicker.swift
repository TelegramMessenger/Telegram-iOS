import Foundation
import Display
import LegacyComponents
import TelegramCore

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

func legacyLocationPickerController(sendLocation: @escaping (CLLocationCoordinate2D, MapVenue?) -> Void, theme: PresentationTheme) -> ViewController {
    let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: theme)
    let controller = TGLocationPickerController(context: legacyController.context, intent: TGLocationPickerControllerDefaultIntent)!
    let listTheme = theme.list
    let searchTheme = theme.rootController.activeNavigationSearchBar
    controller.pallete = TGLocationPallete(backgroundColor: listTheme.plainBackgroundColor, selectionColor: listTheme.itemHighlightedBackgroundColor, separatorColor: listTheme.itemPlainSeparatorColor, textColor: listTheme.itemPrimaryTextColor, secondaryTextColor: listTheme.itemSecondaryTextColor, accentColor: listTheme.itemAccentColor, destructiveColor: listTheme.itemDestructiveColor, locationColor: UIColor(rgb: 0x008df2), liveLocationColor: UIColor(rgb: 0xff6464), iconColor: listTheme.controlSecondaryColor, sectionHeaderBackgroundColor: theme.chatList.sectionHeaderFillColor, sectionHeaderTextColor: theme.chatList.sectionHeaderTextColor, searchBarPallete: TGSearchBarPallete(dark: theme.overallDarkAppearance, backgroundColor: searchTheme.backgroundColor, highContrastBackgroundColor: searchTheme.backgroundColor, textColor: searchTheme.inputTextColor, placeholderColor: searchTheme.inputPlaceholderTextColor, clearIcon: generateClearIcon(color: theme.rootController.activeNavigationSearchBar.inputClearButtonColor), barBackgroundColor: searchTheme.backgroundColor, barSeparatorColor: searchTheme.separatorColor, plainBackgroundColor: searchTheme.backgroundColor, accentColor: searchTheme.accentColor, accentContrastColor: searchTheme.accentColor, menuBackgroundColor: searchTheme.backgroundColor, segmentedControlBackgroundImage: nil, segmentedControlSelectedImage: nil, segmentedControlHighlightedImage: nil, segmentedControlDividerImage: nil), avatarPlaceholder: nil)
    let navigationController = TGNavigationController(controllers: [controller])!
    controller.navigation_setDismiss({ [weak legacyController] in
        legacyController?.dismiss()
    }, rootController: nil)
    legacyController.bind(controller: navigationController)
    controller.locationPicked = { [weak legacyController] coordinate, venue in
        sendLocation(coordinate, venue.flatMap { venue in
            return MapVenue(title: venue.title, address: venue.address, provider: venue.provider, id: venue.venueId, type: venue.type)
        })
        legacyController?.dismiss()
    }
    return legacyController
}
