import Foundation
import CoreGraphics

enum CrossingEndpointSide: Equatable {
    case old
    case new
}

struct CrossingDisplacementSample: Equatable {
    let identity: AnyHashable
    let oldIndex: Int
    let newIndex: Int
    let oldY: CGFloat
    let newY: CGFloat

    var delta: CGFloat { newY - oldY }
    var ordinalDelta: Int { newIndex - oldIndex }

    func index(on side: CrossingEndpointSide) -> Int {
        side == .old ? oldIndex : newIndex
    }
}

struct CrossingKnownEndpoint: Equatable {
    let identity: AnyHashable
    let side: CrossingEndpointSide
    let oldIndex: Int
    let newIndex: Int
    let y: CGFloat
    let height: CGFloat
    let isMoveParticipant: Bool

    var ordinalDelta: Int { newIndex - oldIndex }

    func index(on side: CrossingEndpointSide) -> Int {
        side == .old ? oldIndex : newIndex
    }
}

struct CrossingRetentionBand: Equatable {
    let minY: CGFloat
    let maxY: CGFloat
    let anchorY: CGFloat?
    let anchorIndex: Int?
    let occupiedMinY: CGFloat?
    let occupiedMaxY: CGFloat?

    init(minY: CGFloat,
         maxY: CGFloat,
         anchorY: CGFloat?,
         anchorIndex: Int?,
         occupiedMinY: CGFloat? = nil,
         occupiedMaxY: CGFloat? = nil) {
        self.minY = minY
        self.maxY = maxY
        self.anchorY = anchorY
        self.anchorIndex = anchorIndex
        self.occupiedMinY = occupiedMinY
        self.occupiedMaxY = occupiedMaxY
    }

    var safeMinY: CGFloat { min(minY, occupiedMinY ?? minY) }
    var safeMaxY: CGFloat { max(maxY, occupiedMaxY ?? maxY) }
}

struct CrossingEndpointPlan: Equatable {
    enum Source: Equatable {
        case shared(AnyHashable)
        case retentionBoundary
    }

    let identity: AnyHashable
    let oldY: CGFloat
    let newY: CGFloat
    let source: Source
}

enum CrossingSurvivorPlanner {
    static func infer(endpoint: CrossingKnownEndpoint,
                      samples: [CrossingDisplacementSample],
                      band: CrossingRetentionBand) -> CrossingEndpointPlan {
        sharedPlan(for: endpoint, samples: samples, band: band)
            ?? individualBoundaryPlan(for: endpoint, band: band)
    }

    static func infer(endpoints: [CrossingKnownEndpoint],
                      samples: [CrossingDisplacementSample],
                      band: CrossingRetentionBand) -> [CrossingEndpointPlan] {
        var plans: [CrossingEndpointPlan] = []
        var index = 0
        while index < endpoints.count {
            let endpoint = endpoints[index]
            if endpoint.isMoveParticipant
                || sharedPlan(for: endpoint, samples: samples, band: band) != nil {
                plans.append(infer(endpoint: endpoint, samples: samples, band: band))
                index += 1
                continue
            }

            let belowAnchor = liesBelowAnchor(endpoint, band: band)
            var end = index + 1
            while end < endpoints.count,
                  formsFallbackRun(previous: endpoints[end - 1],
                                   next: endpoints[end],
                                   belowAnchor: belowAnchor,
                                   samples: samples,
                                   band: band) {
                end += 1
            }
            plans.append(contentsOf: projectFallbackSegment(
                Array(endpoints[index..<end]),
                belowAnchor: belowAnchor,
                band: band
            ))
            index = end
        }
        return plans
    }

    private static func sharedPlan(
        for endpoint: CrossingKnownEndpoint,
        samples: [CrossingDisplacementSample],
        band: CrossingRetentionBand
    ) -> CrossingEndpointPlan? {
        guard !endpoint.isMoveParticipant,
              let sample = nearestSample(to: endpoint, samples: samples, band: band)
        else { return nil }
        switch endpoint.side {
        case .old:
            return CrossingEndpointPlan(identity: endpoint.identity,
                                        oldY: endpoint.y,
                                        newY: endpoint.y + sample.delta,
                                        source: .shared(sample.identity))
        case .new:
            return CrossingEndpointPlan(identity: endpoint.identity,
                                        oldY: endpoint.y - sample.delta,
                                        newY: endpoint.y,
                                        source: .shared(sample.identity))
        }
    }

    private static func liesBelowAnchor(
        _ endpoint: CrossingKnownEndpoint,
        band: CrossingRetentionBand
    ) -> Bool {
        if let anchorY = band.anchorY {
            return endpoint.y + endpoint.height * 0.5 >= anchorY
        } else if let anchorIndex = band.anchorIndex {
            return endpoint.index(on: endpoint.side) >= anchorIndex
        } else {
            return endpoint.y + endpoint.height * 0.5
                >= (band.minY + band.maxY) * 0.5
        }
    }

    private static func individualBoundaryPlan(
        for endpoint: CrossingKnownEndpoint,
        band: CrossingRetentionBand
    ) -> CrossingEndpointPlan {
        let missingY = liesBelowAnchor(endpoint, band: band)
            ? band.safeMaxY
            : band.safeMinY - endpoint.height
        return CrossingEndpointPlan(
            identity: endpoint.identity,
            oldY: endpoint.side == .old ? endpoint.y : missingY,
            newY: endpoint.side == .new ? endpoint.y : missingY,
            source: .retentionBoundary
        )
    }

    private static func formsFallbackRun(
        previous: CrossingKnownEndpoint,
        next: CrossingKnownEndpoint,
        belowAnchor: Bool,
        samples: [CrossingDisplacementSample],
        band: CrossingRetentionBand
    ) -> Bool {
        previous.side == next.side
            && previous.ordinalDelta == next.ordinalDelta
            && previous.oldIndex + 1 == next.oldIndex
            && previous.newIndex + 1 == next.newIndex
            && !next.isMoveParticipant
            && sharedPlan(for: next, samples: samples, band: band) == nil
            && liesBelowAnchor(next, band: band) == belowAnchor
    }

    private static func projectFallbackSegment(
        _ segment: [CrossingKnownEndpoint],
        belowAnchor: Bool,
        band: CrossingRetentionBand
    ) -> [CrossingEndpointPlan] {
        guard let first = segment.first, let last = segment.last else { return [] }
        let translation = belowAnchor
            ? band.safeMaxY - first.y
            : band.safeMinY - (last.y + last.height)
        return segment.map { endpoint in
            CrossingEndpointPlan(
                identity: endpoint.identity,
                oldY: endpoint.side == .old ? endpoint.y : endpoint.y + translation,
                newY: endpoint.side == .new ? endpoint.y : endpoint.y + translation,
                source: .retentionBoundary
            )
        }
    }

    private static func nearestSample(
        to endpoint: CrossingKnownEndpoint,
        samples: [CrossingDisplacementSample],
        band: CrossingRetentionBand
    ) -> CrossingDisplacementSample? {
        samples.filter { $0.ordinalDelta == endpoint.ordinalDelta }.min { lhs, rhs in
            let lhsIndex = lhs.index(on: endpoint.side)
            let rhsIndex = rhs.index(on: endpoint.side)
            let endpointIndex = endpoint.index(on: endpoint.side)
            let lhsDistance = abs(lhsIndex - endpointIndex)
            let rhsDistance = abs(rhsIndex - endpointIndex)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }

            if let anchorIndex = band.anchorIndex {
                let lhsAnchorDistance = abs(lhsIndex - anchorIndex)
                let rhsAnchorDistance = abs(rhsIndex - anchorIndex)
                if lhsAnchorDistance != rhsAnchorDistance {
                    return lhsAnchorDistance < rhsAnchorDistance
                }
            }
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return String(reflecting: lhs.identity) < String(reflecting: rhs.identity)
        }
    }
}
