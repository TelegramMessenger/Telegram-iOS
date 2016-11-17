import Foundation
import CoreLocation
import SwiftSignalKit

enum GeoLocation {
    case location(CLLocation)
    case unavailable
}

private final class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let queue: Queue
    private var locationManager: CLLocationManager?
    let location = Promise<GeoLocation>()
    private var startedUpdating = false
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
        
        queue.async {
            let locationManager = CLLocationManager()
            self.locationManager = locationManager
            locationManager.delegate = self
            switch CLLocationManager.authorizationStatus() {
                case .authorizedAlways, .authorizedWhenInUse:
                    locationManager.startUpdatingLocation()
                case .denied, .restricted:
                    self.location.set(.single(.unavailable))
                case .notDetermined:
                    locationManager.requestWhenInUseAuthorization()
                    locationManager.startUpdatingLocation()
            }
        }
    }
    
    deinit {
        if let locationManager = self.locationManager {
            self.queue.async {
                locationManager.stopUpdatingLocation()
            }
        }
    }
    
    func stop() {
        if let locationManager = self.locationManager {
            self.queue.async {
                locationManager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.queue.async {
            if !locations.isEmpty {
                self.location.set(.single(.location(locations[locations.count - 1])))
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.queue.async {
            switch status {
                case .denied, .restricted:
                    self.location.set(.single(.unavailable))
                default:
                    break
            }
        }
    }
}

func currentGeoLocation() -> Signal<GeoLocation, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        let helper = LocationHelper(queue: queue)
        let disposable = (helper.location.get() |> deliverOn(queue)).start(next: { location in
            subscriber.putNext(location)
        })
        return ActionDisposable {
            helper.stop()
        }
    }
    return .complete()
}
