import CoreLocation
import Foundation

enum LocationSendState: Equatable {
    case idle
    case requestingPermission
    case locating
    case ready(latitude: Double, longitude: Double)
    case denied
    case failed(String)
}

/// Drives location acquisition for the send-location screen: requests
/// authorization if needed, then a one-shot fix. Owns acquisition only — the
/// send itself goes through `ChatHistoryStore.sendLocation` (mirrors how
/// `VoiceRecorder` handles capture and the store handles send).
@Observable @MainActor
final class LocationSendController {
    private(set) var state: LocationSendState = .idle
    private let provider: LocationProviding

    init(provider: LocationProviding) {
        self.provider = provider
    }

    func start() async {
        // Ignore re-entry while a request is in flight or already done.
        switch state {
        case .requestingPermission, .locating, .ready: return
        default: break
        }
        switch provider.authorizationStatus {
        case .notDetermined:
            state = .requestingPermission
            let status = await provider.requestAuthorization()
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                state = .denied
                return
            }
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .denied, .restricted:
            state = .denied
            return
        @unknown default:
            state = .denied
            return
        }
        await locate()
    }

    func retry() async {
        state = .idle
        await start()
    }

    private func locate() async {
        state = .locating
        do {
            let coord = try await provider.requestLocation()
            state = .ready(latitude: coord.latitude, longitude: coord.longitude)
        } catch {
            state = .failed("Couldn't get your location. Try again.")
        }
    }
}
