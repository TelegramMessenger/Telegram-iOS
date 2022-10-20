import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramApi
import DeviceLocationManager
import CoreLocation
import AccountContext
import DeviceAccess

private let locationUpdateTimePeriod: Double = 1.0 * 60.0 * 60.0
private let locationDistanceUpdateThreshold: Double = 1000

final class PeersNearbyManagerImpl: PeersNearbyManager {
    private let account: Account
    private let engine: TelegramEngine
    private let locationManager: DeviceLocationManager
    private let inForeground: Signal<Bool, NoError>
    
    private var preferencesDisposable: Disposable?
    private var locationDisposable = MetaDisposable()
    private var updateDisposable = MetaDisposable()
    private var accessDisposable: Disposable?
    
    private var previousLocation: CLLocation?
    
    init(account: Account, engine: TelegramEngine, locationManager: DeviceLocationManager, inForeground: Signal<Bool, NoError>)  {
        self.account = account
        self.engine = engine
        self.locationManager = locationManager
        self.inForeground = inForeground
        
        self.preferencesDisposable = (account.postbox.preferencesView(keys: [PreferencesKeys.peersNearby])
        |> map { view -> Int32? in
            let state = view.values[PreferencesKeys.peersNearby]?.get(PeersNearbyState.self) ?? .default
            return state.visibilityExpires
        }
        |> deliverOnMainQueue
        |> distinctUntilChanged).start(next: { [weak self] visibility in
            if let strongSelf = self {
                strongSelf.visibilityUpdated(visible: visibility != nil)
            }
        })

        self.accessDisposable = (DeviceAccess.authorizationStatus(applicationInForeground: nil, siriAuthorization: nil, subject: .location(.live))
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            switch status {
            case .denied:
                let _ = strongSelf.engine.peersNearby.updatePeersNearbyVisibility(update: .invisible, background: false).start()
                strongSelf.locationDisposable.set(nil)
                strongSelf.updateDisposable.set(nil)
            default:
                break
            }
        })
    }
    
    deinit {
        self.preferencesDisposable?.dispose()
        self.locationDisposable.dispose()
        self.updateDisposable.dispose()
        self.accessDisposable?.dispose()
    }
    
    private func visibilityUpdated(visible: Bool) {
        if visible {
            let poll = self.inForeground
            |> take(until: { value in
                return SignalTakeAction(passthrough: value, complete: value)
            })
            |> mapToSignal { _ in
                return currentLocationManagerCoordinate(manager: self.locationManager, timeout: 5.0)
            }
                   
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
        self.updateDisposable.set(self.engine.peersNearby.updatePeersNearbyVisibility(update: .location(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), background: true).start())
    }
}
