import Foundation
import Display
import LegacyComponents
import TelegramCore

func legacyLocationPickerController(sendLocation: @escaping (CLLocationCoordinate2D, MapVenue?) -> Void) -> ViewController {
    let legacyController = LegacyController(presentation: .modal(animateIn: true))
    let controller = TGLocationPickerController(context: legacyController.context, intent: TGLocationPickerControllerDefaultIntent)!
    let navigationController = TGNavigationController(controllers: [controller])!
    controller.navigation_setDismiss({ [weak legacyController] in
        legacyController?.dismiss()
    }, rootController: nil)
    legacyController.bind(controller: navigationController)
    controller.locationPicked = { [weak legacyController] coordinate, venue in
        sendLocation(coordinate, venue.flatMap { venue in
            return MapVenue(title: venue.title, address: venue.address, provider: venue.provider, id: venue.venueId)
        })
        legacyController?.dismiss()
    }
    return legacyController
}
