import Foundation
import CoreLocation
import SwiftSignalKit

public enum DeviceLocationMode: Int32 {
    case precise = 0
}

private final class DeviceLocationSubscriber {
    let id: Int32
    let mode: DeviceLocationMode
    let update: (CLLocationCoordinate2D, Double, Double?) -> Void
    
    init(id: Int32, mode: DeviceLocationMode, update: @escaping (CLLocationCoordinate2D, Double, Double?) -> Void) {
        self.id = id
        self.mode = mode
        self.update = update
    }
}

private func getTopMode(subscribers: [DeviceLocationSubscriber]) -> DeviceLocationMode? {
    var mode: DeviceLocationMode?
    for subscriber in subscribers {
        if mode == nil || subscriber.mode.rawValue > mode!.rawValue {
            mode = subscriber.mode
        }
    }
    return mode
}

public final class DeviceLocationManager: NSObject {
    private let queue: Queue
    private let log: ((String) -> Void)?
    
    private let manager: CLLocationManager
    private var requestedAuthorization = false
    
    private var nextSubscriberId: Int32 = 0
    private var subscribers: [DeviceLocationSubscriber] = []
    private var currentTopMode: DeviceLocationMode?
    
    private var currentLocation: (CLLocationCoordinate2D, Double)?
    private var currentHeading: CLHeading?
    
    public init(queue: Queue, log: ((String) -> Void)? = nil) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.log = log
        self.manager = CLLocationManager()
        
        super.init()
        
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            self.manager.allowsBackgroundLocationUpdates = true
        }
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.manager.distanceFilter = 10.0
        self.manager.activityType = .other
        self.manager.pausesLocationUpdatesAutomatically = false
    }
    
    public func push(mode: DeviceLocationMode, updated: @escaping (CLLocationCoordinate2D, Double, Double?) -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        let id = self.nextSubscriberId
        self.nextSubscriberId += 1
        self.subscribers.append(DeviceLocationSubscriber(id: id, mode: mode, update: updated))
        
        if let currentLocation = self.currentLocation {
            updated(currentLocation.0, currentLocation.1, self.currentHeading?.magneticHeading)
        }
        
        self.updateTopMode()
        
        let queue = self.queue
        return ActionDisposable { [weak queue, weak self] in
            if let queue = queue {
                queue.async {
                    if let strongSelf = self {
                        loop: for i in 0 ..< strongSelf.subscribers.count {
                            if strongSelf.subscribers[i].id == id {
                                strongSelf.subscribers.remove(at: i)
                                break loop
                            }
                        }
                        
                        strongSelf.updateTopMode()
                    }
                }
            }
        }
    }
    
    private func updateTopMode() {
        assert(self.queue.isCurrent())
        
        let previousTopMode = self.currentTopMode
        let topMode = getTopMode(subscribers: self.subscribers)
        if topMode != previousTopMode {
            self.currentTopMode = topMode
            if let topMode = topMode {
                self.log?("setting mode \(topMode)")
                if previousTopMode == nil {
                    if !self.requestedAuthorization {
                        self.requestedAuthorization = true
                        self.manager.requestAlwaysAuthorization()
                    }
                    self.manager.startUpdatingLocation()
                    self.manager.startUpdatingHeading()
                }
            } else {
                self.currentLocation = nil
                self.manager.stopUpdatingLocation()
                self.log?("stopped")
            }
        }
    }
}

extension DeviceLocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        assert(self.queue.isCurrent())
        
        if let location = locations.first {
            if self.currentTopMode != nil {
                self.currentLocation = (location.coordinate, location.horizontalAccuracy)
                for subscriber in self.subscribers {
                    subscriber.update(location.coordinate, location.horizontalAccuracy, self.currentHeading?.magneticHeading)
                }
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        assert(self.queue.isCurrent())
        
        if self.currentTopMode != nil {
            self.currentHeading = newHeading
            if let currentLocation = self.currentLocation {
                for subscriber in self.subscribers {
                    subscriber.update(currentLocation.0, currentLocation.1, newHeading.magneticHeading)
                }
            }
        }
    }
}

public func currentLocationManagerCoordinate(manager: DeviceLocationManager, timeout timeoutValue: Double) -> Signal<CLLocationCoordinate2D?, NoError> {
    return (
        Signal { subscriber in
            let disposable = manager.push(mode: .precise, updated: { coordinate, _, _ in
                subscriber.putNext(coordinate)
                subscriber.putCompletion()
            })
            return disposable
        }
        |> runOn(Queue.mainQueue())
    )
    |> timeout(timeoutValue, queue: Queue.mainQueue(), alternate: .single(nil))
}
