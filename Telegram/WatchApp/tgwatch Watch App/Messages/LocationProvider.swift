import CoreLocation

/// CoreLocation seam. Production uses `CLLocationProvider`; tests use a fake.
/// `@MainActor` (not `Sendable`) to mirror `RecordingBackend` — it's consumed
/// only from the `@MainActor LocationSendController`, and `CLLocationManager`'s
/// delegate callbacks arrive on the main run loop.
@MainActor
protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    /// Requests when-in-use authorization. Resolves once the user responds;
    /// returns immediately with the current status if already determined.
    func requestAuthorization() async -> CLAuthorizationStatus
    /// One-shot location fix. Throws on failure/timeout (CLLocationManager's own).
    func requestLocation() async throws -> CLLocationCoordinate2D
}

@MainActor
final class CLLocationProvider: NSObject, LocationProviding {
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }
        return await withCheckedContinuation { cont in
            authContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestLocation() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { cont in
            locationContinuation = cont
            manager.requestLocation()
        }
    }
}

extension CLLocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined, let cont = authContinuation else { return }
        authContinuation = nil
        cont.resume(returning: status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate, let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(returning: coord)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(throwing: error)
    }
}
