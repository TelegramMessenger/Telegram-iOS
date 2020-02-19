import Foundation
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore
import TelegramApi
import DeviceLocationManager
import CoreLocation
import AccountContext

private let locationUpdateTimePeriod: Double = 1.0 * 60.0 * 60.0
private let locationDistanceUpdateThreshold: Double = 1000

final class PeersNearbyManagerImpl: PeersNearbyManager {
    private let account: Account
    private let locationManager: DeviceLocationManager
    
    private var preferencesDisposable: Disposable?
    private var locationDisposable = MetaDisposable()
    private var updateDisposable = MetaDisposable()
    
    private var previousLocation: CLLocation?
    
    init(account: Account, locationManager: DeviceLocationManager)  {
        self.account = account
        self.locationManager = locationManager
        
        self.preferencesDisposable = (account.postbox.preferencesView(keys: [PreferencesKeys.peersNearby])
        |> map { view -> Int32? in
            let state = view.values[PreferencesKeys.peersNearby] as? PeersNearbyState ?? .default
            return state.visibilityExpires
        }
        |> distinctUntilChanged).start(next: { [weak self] visibility in
            if let strongSelf = self {
                strongSelf.visibilityUpdated(visible: visibility != nil)
            }
        })
    }
    
    deinit {
        self.preferencesDisposable?.dispose()
        self.locationDisposable.dispose()
        self.updateDisposable.dispose()
    }
    
    private func visibilityUpdated(visible: Bool) {
        if visible {
            let account = self.account
            let poll = currentLocationManagerCoordinate(manager: self.locationManager, timeout: 5.0)
            let signal = (poll |> then(.complete() |> suspendAwareDelay(locationUpdateTimePeriod, queue: Queue.concurrentDefaultQueue()))) |> restart
            self.locationDisposable.set(signal.start(next: { [weak self] coordinate in
                if let strongSelf = self, let coordinate = coordinate {
                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    var update = true
                    if let previousLocation = strongSelf.previousLocation, location.distance(from: previousLocation) < locationDistanceUpdateThreshold {
                        update = false
                    }
                    if update {
                        strongSelf.updateLocation(location)
                        strongSelf.previousLocation = location
                    }
                }
            }))
        } else {
            self.previousLocation = nil
            self.locationDisposable.set(nil)
            self.updateDisposable.set(nil)
        }
    }
    
    private func updateLocation(_ location: CLLocation) {
        self.updateDisposable.set(updatePeersNearbyVisibility(account: self.account, update: .location(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), background: true).start(error: { [weak self] _ in
            if let strongSelf = self {
                let _ = updatePeersNearbyVisibility(account: strongSelf.account, update: .invisible, background: false).start()
                strongSelf.locationDisposable.set(nil)
                strongSelf.updateDisposable.set(nil)
            }
        }))
    }
}
