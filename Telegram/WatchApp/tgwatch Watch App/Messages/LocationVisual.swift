import Foundation
import TDShim

/// Per-location data the bubble consumes. Projected from `messageLocation`
/// (static or live) and `messageVenue`. Mutually exclusive with the other
/// `MessageBubble` media fields. The map image itself is rendered locally by
/// `MapSnapshotRenderer` in the view layer — there is no TDLib file to plumb.
struct LocationVisual: Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    /// Venue name; nil for a plain location. Non-nil (even if "") marks a venue,
    /// which is one of the two cases that render inside a chrome bubble.
    let title: String?
    /// Venue address; nil for a plain location.
    let address: String?
    /// True when `messageLocation.livePeriod != 0`; always false for a venue.
    let isLive: Bool
    /// Live-location direction in degrees (1–360); 0 = unknown / not live.
    let heading: Int
    /// True when a live location has stopped updating (`livePeriod != 0 && expiresIn == 0`).
    let isExpired: Bool
    /// Last-update time of a live location (its edit time, falling back to send
    /// time); nil for static locations and venues. Drives the "Updated …" caption.
    let liveUpdatedAt: Foundation.Date?
}

/// Builds a `LocationVisual` for `messageLocation` / `messageVenue` content,
/// or returns `nil` for any other content. `messageDate` is the message's
/// last-update time (used as the live-location "Updated …" basis). Internal
/// (not `private`) so `LocationVisualTests` can exercise it directly via
/// `@testable import`, matching the `voiceNoteVisual` precedent.
func locationVisual(for content: MessageContent, messageDate: Foundation.Date? = nil) -> LocationVisual? {
    switch content {
    case .messageLocation(let m):
        let isLive = m.livePeriod != 0
        return LocationVisual(
            latitude: m.location.latitude,
            longitude: m.location.longitude,
            title: nil,
            address: nil,
            isLive: isLive,
            heading: m.heading,
            isExpired: isLive && m.expiresIn == 0,
            liveUpdatedAt: isLive ? messageDate : nil
        )
    case .messageVenue(let m):
        return LocationVisual(
            latitude: m.venue.location.latitude,
            longitude: m.venue.location.longitude,
            title: m.venue.title,
            address: m.venue.address,
            isLive: false,
            heading: 0,
            isExpired: false,
            liveUpdatedAt: nil
        )
    default:
        return nil
    }
}

/// Relative "Updated …" caption for a live-location bubble. Pure so it's
/// deterministically unit-testable; the view feeds it a ticking `now`.
func liveUpdatedCaption(updatedAt: Foundation.Date, now: Foundation.Date) -> String {
    let elapsed = max(0, now.timeIntervalSince(updatedAt))
    if elapsed < 60 { return "Updated just now" }
    let minutes = Int(elapsed / 60)
    if minutes < 60 { return "Updated \(minutes) minute\(minutes == 1 ? "" : "s") ago" }
    let hours = minutes / 60
    if hours < 24 { return "Updated \(hours) hour\(hours == 1 ? "" : "s") ago" }
    let days = hours / 24
    return "Updated \(days) day\(days == 1 ? "" : "s") ago"
}
