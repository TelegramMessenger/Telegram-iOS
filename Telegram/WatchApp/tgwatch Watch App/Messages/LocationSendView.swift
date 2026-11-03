import SwiftUI
import UIKit
import CoreLocation

/// Preview-and-confirm screen for sending the current location. On appear it
/// drives `LocationSendController` to acquire a one-shot fix, renders a map
/// preview of the position, and sends on confirm. Pushed inside the
/// AttachmentSheet's NavigationStack; `onComplete` dismisses the whole sheet.
struct LocationSendView: View {
    /// Sends the chosen coordinate; returns true on success.
    let onSend: (_ latitude: Double, _ longitude: Double) async -> Bool
    /// Dismisses the whole attachment sheet (called after a successful send).
    let onComplete: () -> Void

    @State private var controller: LocationSendController
    @State private var sending = false
    @State private var sendError: String?

    init(
        onSend: @escaping (_ latitude: Double, _ longitude: Double) async -> Bool,
        onComplete: @escaping () -> Void
    ) {
        self.onSend = onSend
        self.onComplete = onComplete
        _controller = State(wrappedValue: LocationSendController(provider: CLLocationProvider()))
    }

    /// Injecting-init for previews/tests.
    init(
        controller: LocationSendController,
        onSend: @escaping (_ latitude: Double, _ longitude: Double) async -> Bool = { _, _ in true },
        onComplete: @escaping () -> Void = {}
    ) {
        self.onSend = onSend
        self.onComplete = onComplete
        _controller = State(wrappedValue: controller)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                switch controller.state {
                case .idle, .requestingPermission, .locating:
                    locating
                case .ready(let lat, let lon):
                    ready(latitude: lat, longitude: lon)
                case .denied:
                    denied
                case .failed(let reason):
                    failed(reason)
                }
            }
            .padding()
        }
        .navigationTitle("Location")
        .task { await controller.start() }
    }

    private var locating: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Locating…").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func ready(latitude: Double, longitude: Double) -> some View {
        VStack(spacing: 10) {
            LocationPreviewMap(latitude: latitude, longitude: longitude)
            if let sendError {
                Text(sendError).font(.caption2).foregroundStyle(.red)
            }
            Button { send(latitude: latitude, longitude: longitude) } label: {
                if sending { ProgressView() } else { Label("Send", systemImage: "paperplane.fill") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sending)
            .accessibilityIdentifier("locationSend")
        }
    }

    private var denied: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("Location access is off. Enable it in Settings.")
                .font(.caption).multilineTextAlignment(.center)
        }
    }

    private func failed(_ reason: String) -> some View {
        VStack(spacing: 10) {
            Text(reason).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            Button("Retry") { Task { await controller.retry() } }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("locationRetry")
        }
    }

    private func send(latitude: Double, longitude: Double) {
        guard !sending else { return }
        sending = true
        sendError = nil
        Task {
            if await onSend(latitude, longitude) {
                onComplete()
            } else {
                sendError = "Couldn't send. Try again."
                sending = false
            }
        }
    }
}

/// Static map preview with a centered pin for the confirm screen. Mirrors
/// LocationBubbleView's map rendering (same `MapSnapshotRenderer`).
private struct LocationPreviewMap: View {
    let latitude: Double
    let longitude: Double
    @State private var snapshot: UIImage?

    private let mapWidth: CGFloat = 150
    private let mapHeight: CGFloat = 120

    private var cacheKey: String {
        MapSnapshotRenderer.cacheKey(
            latitude: latitude, longitude: longitude,
            width: Int(mapWidth), height: Int(mapHeight)
        )
    }

    var body: some View {
        Group {
            if let snapshot {
                Image(uiImage: snapshot).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: mapWidth, height: mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24)).foregroundStyle(.red).shadow(radius: 2)
        }
        .task(id: cacheKey) {
            snapshot = await MapSnapshotRenderer.image(
                latitude: latitude, longitude: longitude,
                size: CGSize(width: mapWidth, height: mapHeight)
            )
        }
    }
}

#if DEBUG
/// Preview-only provider: drives the controller into a fixed state via `.task`.
@MainActor
private final class PreviewLocationProvider: LocationProviding {
    var status: CLAuthorizationStatus
    var result: Result<CLLocationCoordinate2D, Error>
    init(status: CLAuthorizationStatus, result: Result<CLLocationCoordinate2D, Error>) {
        self.status = status
        self.result = result
    }
    var authorizationStatus: CLAuthorizationStatus { status }
    func requestAuthorization() async -> CLAuthorizationStatus { status }
    func requestLocation() async throws -> CLLocationCoordinate2D { try result.get() }
}

@MainActor private func previewController(
    status: CLAuthorizationStatus = .authorizedWhenInUse,
    result: Result<CLLocationCoordinate2D, Error> = .success(CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090))
) -> LocationSendController {
    LocationSendController(provider: PreviewLocationProvider(status: status, result: result))
}

#Preview("Ready") {
    NavigationStack { LocationSendView(controller: previewController()) }
}

#Preview("Denied") {
    NavigationStack { LocationSendView(controller: previewController(status: .denied, result: .failure(CancellationError()))) }
}

#Preview("Failed") {
    NavigationStack {
        LocationSendView(controller: previewController(result: .failure(NSError(domain: "preview", code: 1))))
    }
}
#endif
