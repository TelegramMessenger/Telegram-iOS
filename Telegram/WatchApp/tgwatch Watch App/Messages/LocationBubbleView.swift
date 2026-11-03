import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// Renders one location / venue bubble: a rounded static map image
/// (`MKMapSnapshotter`) with a centered pin, a "LIVE" badge for live
/// locations. The snapshot renders in `.task(id:)`,
/// keyed by the cache key, so live-location coordinate changes re-render
/// automatically.
///
/// A plain static location is chrome-less (bare map). Venues and live
/// locations sit inside a gray (incoming) / accent (outgoing) chrome bubble:
/// venues add a title/address card, live locations a relative "Updated …"
/// caption that ticks once a minute.
///
/// Tap builds an `MKMapItem` and hands the coordinate to the system Maps app.
struct LocationBubbleView: View {
    let location: LocationVisual
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?

    @Environment(\.bubbleMetrics) private var metrics
    @State private var snapshot: UIImage?

    // The map always spans the full content width. In a chrome bubble it sits flush to the
    // bubble edges (like photo/video); only the caption text is padded.
    private var mapWidth: CGFloat { metrics.mapWidth }
    private let mapHeight: CGFloat = 110
    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }

    private var cacheKey: String {
        MapSnapshotRenderer.cacheKey(
            latitude: location.latitude, longitude: location.longitude,
            width: Int(mapWidth), height: Int(mapHeight)
        )
    }

    /// A caption (venue title/address or live "Live Location") gives the bubble chrome, with the
    /// map flush to the edges. A plain static location stays chrome-less (bare rounded map).
    private var hasChrome: Bool { location.title != nil || location.isLive }

    var body: some View {
        Group {
            if hasChrome { chromeBubble } else { plainBubble }
        }
        .task(id: cacheKey) {
            snapshot = await MapSnapshotRenderer.image(
                latitude: location.latitude, longitude: location.longitude,
                size: CGSize(width: mapWidth, height: mapHeight)
            )
        }
    }

    private var plainBubble: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
            replyMiniCard
            mapView(roundedCorners: true)
        }
    }

    private var chromeBubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: style)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
            }
            mapView(roundedCorners: false)
            if let title = location.title, !title.isEmpty {
                Text(title)
                    .font(.caption2).bold().lineLimit(1)
                    .padding(.horizontal, 8)
            }
            if let address = location.address, !address.isEmpty {
                Text(address)
                    .font(.system(size: 9))
                    .foregroundStyle(style.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
            if location.isLive {
                Text("Live Location")
                    .font(.caption2).bold()
                    .padding(.horizontal, 8)
                liveCaption.padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 6)
        .frame(width: mapWidth, alignment: .leading)
        .background(style.fill)
        .foregroundStyle(style.content)
        .clipShape(RoundedRectangle(cornerRadius: BubbleShape.cornerRadius))
    }

    @ViewBuilder
    private var replyMiniCard: some View {
        if let header = replyHeader {
            ReplyHeaderView(header: header, style: style)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(style.fill))
                .frame(maxWidth: mapWidth)
        }
    }

    private func mapView(roundedCorners: Bool) -> some View {
        mapImage
            .frame(width: mapWidth, height: mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: roundedCorners ? BubbleShape.cornerRadius : 0))
            .overlay { pin }
            .contentShape(Rectangle())
            .onTapGesture { openInMaps() }
    }

    /// Relative "Updated …" caption for a live location; ticks once a minute so
    /// "just now" decays to "Updated N minutes ago" even between TDLib updates.
    private var liveCaption: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(liveUpdatedCaption(updatedAt: location.liveUpdatedAt ?? context.date, now: context.date))
                .font(.system(size: 9))
                .foregroundStyle(style.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var mapImage: some View {
        if let snapshot {
            Image(uiImage: snapshot).resizable().scaledToFill()
        } else {
            Color.gray.opacity(0.3)
        }
    }

    @ViewBuilder
    private var pin: some View {
        if location.isLive {
            ZStack {
                Circle().fill(.white).frame(width: 18, height: 18)
                Circle().fill(location.isExpired ? Color.gray : Color.accentColor).frame(width: 12, height: 12)
            }
            .shadow(radius: 2)
        } else {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
                .shadow(radius: 2)
        }
    }

    private func openInMaps() {
        let mapItem = MKMapItem(
            location: CLLocation(latitude: location.latitude, longitude: location.longitude),
            address: nil
        )
        mapItem.name = location.title
        mapItem.openInMaps(launchOptions: nil)
    }
}

#if DEBUG
#Preview("Static location") {
    LocationBubbleView(
        location: LocationVisual(
            latitude: 37.3349, longitude: -122.0090,
            title: nil, address: nil, isLive: false, heading: 0, isExpired: false,
            liveUpdatedAt: nil
        ),
        isOutgoing: false, replyHeader: nil
    )
    .bubblePreview()
}

#Preview("Venue") {
    LocationBubbleView(
        location: LocationVisual(
            latitude: 48.8584, longitude: 2.2945,
            title: "Eiffel Tower", address: "Champ de Mars, 75007 Paris",
            isLive: false, heading: 0, isExpired: false, liveUpdatedAt: nil
        ),
        isOutgoing: true, replyHeader: nil
    )
    .bubblePreview()
}

#Preview("Live location — active") {
    LocationBubbleView(
        location: LocationVisual(
            latitude: 37.3318, longitude: -122.0312,
            title: nil, address: nil, isLive: true, heading: 90, isExpired: false,
            liveUpdatedAt: Date().addingTimeInterval(-90)
        ),
        isOutgoing: false, replyHeader: nil
    )
    .bubblePreview()
}

#Preview("Live location — expired") {
    LocationBubbleView(
        location: LocationVisual(
            latitude: 37.3318, longitude: -122.0312,
            title: nil, address: nil, isLive: true, heading: 0, isExpired: true,
            liveUpdatedAt: Date().addingTimeInterval(-7200)
        ),
        isOutgoing: false, replyHeader: nil
    )
    .bubblePreview()
}

#Preview("Location — incoming with reply") {
    LocationBubbleView(
        location: LocationVisual(
            latitude: 37.3349, longitude: -122.0090,
            title: nil, address: nil, isLive: false, heading: 0, isExpired: false,
            liveUpdatedAt: nil
        ),
        isOutgoing: false,
        replyHeader: ReplyHeader(
            senderName: "Bob",
            snippet: "where are you?",
            minithumbnail: nil,
            isOutgoing: false
        )
    )
    .bubblePreview()
}
#endif
