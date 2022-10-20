import Foundation
import CoreLocation
import SwiftSignalKit

public enum DeviceLocationMode: Int32 {
    case preciseForeground = 0
    case preciseAlways = 1
}

private final class DeviceLocationSubscriber {
    let id: Int32
    let mode: DeviceLocationMode
    let update: (CLLocation, Double?) -> Void
    
    init(id: Int32, mode: DeviceLocationMode, update: @escaping (CLLocation, Double?) -> Void) {
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
    
    private var currentLocation: CLLocation?
    private var currentHeading: CLHeading?
    
    public init(queue: Queue, log: ((String) -> Void)? = nil) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.log = log
        self.manager = CLLocationManager()
        
        super.init()
        
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.manager.distanceFilter = 5.0
        self.manager.activityType = .other
        self.manager.pausesLocationUpdatesAutomatically = false
        self.manager.headingFilter = 2.0
        if #available(iOS 11.0, *) {
            self.manager.showsBackgroundLocationIndicator = true
        }
    }
    
    public func push(mode: DeviceLocationMode, updated: @escaping (CLLocation, Double?) -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        let id = self.nextSubscriberId
        self.nextSubscriberId += 1
        self.subscribers.append(DeviceLocationSubscriber(id: id, mode: mode, update: updated))
        
        if let currentLocation = self.currentLocation {
            updated(currentLocation, self.currentHeading?.magneticHeading)
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
                    
                    switch topMode {
                    case .preciseForeground:
                        self.manager.allowsBackgroundLocationUpdates = false
                    case .preciseAlways:
                        self.manager.allowsBackgroundLocationUpdates = true
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

extension CLHeading {
    var effectiveHeading: Double? {
        if self.headingAccuracy < 0.0 {
            return nil
        }
        if self.trueHeading > 0.0 {
            return self.trueHeading
        } else {
            return self.magneticHeading
        }
    }
}

extension DeviceLocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        assert(self.queue.isCurrent())
        
        if let location = locations.first {
            if self.currentTopMode != nil {
                self.currentLocation = location
                for subscriber in self.subscribers {
                    subscriber.update(location, self.currentHeading?.effectiveHeading)
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
                    subscriber.update(currentLocation, newHeading.effectiveHeading)
                }
            }
        }
    }
}

public func currentLocationManagerCoordinate(manager: DeviceLocationManager, timeout timeoutValue: Double) -> Signal<CLLocationCoordinate2D?, NoError> {
    return (
        Signal { subscriber in
            let disposable = manager.push(mode: .preciseForeground, updated: { location, _ in
                subscriber.putNext(location.coordinate)
                subscriber.putCompletion()
            })
            return disposable
        }
        |> runOn(Queue.mainQueue())
    )
    |> timeout(timeoutValue, queue: Queue.mainQueue(), alternate: .single(nil))
}
