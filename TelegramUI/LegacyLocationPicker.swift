import Foundation
import Display
import TelegramLegacyComponents
import TelegramCore

func legacyLocationPickerController(sendLocation: @escaping (CLLocationCoordinate2D, MapVenue?) -> Void) -> ViewController {
    let controller = TGLocationPickerController(intent: TGLocationPickerControllerDefaultIntent)!
    let navigationController = TGNavigationController(controllers: [controller])!
    let legacyController = LegacyController(legacyController: navigationController, presentation: .modal(animateIn: true))
    controller.customDismiss = { [weak legacyController] in
        legacyController?.dismiss()
    }
    controller.locationPicked = { [weak legacyController] coordinate, venue in
        sendLocation(coordinate, venue.flatMap { venue in
            return MapVenue(title: venue.title, address: venue.address, provider: venue.provider, id: venue.venueId)
        })
        legacyController?.dismiss()
    }
    return legacyController
}
