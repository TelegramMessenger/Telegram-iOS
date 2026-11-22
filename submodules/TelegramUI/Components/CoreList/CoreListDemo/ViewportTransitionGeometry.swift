import CoreGraphics

enum ViewportTravelDirection {
    case forward
    case backward
}

struct ViewportTransitionGeometry {
    /// `fallback` is used when there is no anchor witness — no current anchor, or one that does not
    /// appear in the new order, which is what a full collection replace produces. Index comparison
    /// has nothing to compare there, so the caller's declared direction is the only information
    /// available. A present witness always wins: the hint is a fallback, never an override.
    static func direction(currentAnchor: AnyHashable?, targetIndex: Int,
                          newOrder: [AnyHashable],
                          fallback: ViewportTravelDirection = .forward) -> ViewportTravelDirection {
        guard let anchor = currentAnchor,
              let anchorIndex = newOrder.firstIndex(of: anchor)
        else { return fallback }
        return targetIndex >= anchorIndex ? .forward : .backward
    }

    static func overlapReference(currentAnchor: AnyHashable?,
                                 direction: ViewportTravelDirection,
                                 oldLoaded: [AnyHashable],
                                 newLoaded: [AnyHashable],
                                 newOrder: [AnyHashable]) -> AnyHashable? {
        let shared = Set(oldLoaded).intersection(newLoaded)
        if let anchor = currentAnchor, shared.contains(anchor) { return anchor }
        guard !shared.isEmpty else { return nil }
        let anchorIndex = currentAnchor.flatMap { newOrder.firstIndex(of: $0) }
            ?? (direction == .forward ? -1 : newOrder.count)
        let indexed = newOrder.enumerated().filter { shared.contains($0.element) }
        let directional = indexed.filter {
            direction == .forward ? $0.offset >= anchorIndex : $0.offset <= anchorIndex
        }
        return (directional.isEmpty ? indexed : directional)
            .min { abs($0.offset - anchorIndex) < abs($1.offset - anchorIndex) }?.element
    }

    static func coordinateShift(oldReferenceY: CGFloat, newReferenceY: CGFloat) -> CGFloat {
        newReferenceY - oldReferenceY
    }

    static func overlapViewportFrom(oldEngineOffset: CGFloat,
                                    currentViewportCorrection: CGFloat,
                                    coordinateShift: CGFloat,
                                    newEngineOffset: CGFloat) -> CGFloat {
        oldEngineOffset + currentViewportCorrection + coordinateShift - newEngineOffset
    }

    static func carouselViewportFrom(direction: ViewportTravelDirection,
                                     oldVisibleTop: CGFloat,
                                     newVisibleTop: CGFloat,
                                     oldStripHeight: CGFloat,
                                     newWindowHeight: CGFloat) -> CGFloat {
        switch direction {
        case .forward: return newVisibleTop - (oldVisibleTop + oldStripHeight)
        case .backward: return newVisibleTop + newWindowHeight - oldVisibleTop
        }
    }

    static func mappedContentY(oldScreenY: CGFloat,
                               newEngineOffset: CGFloat,
                               viewportFrom: CGFloat) -> CGFloat {
        oldScreenY + newEngineOffset + viewportFrom
    }
}
