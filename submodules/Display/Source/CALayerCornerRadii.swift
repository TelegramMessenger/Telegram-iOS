import Foundation
import UIKit

/// Four independent corner radii for a layer — what `CALayer.cornerRadius` cannot express, and what
/// a merged chat bubble needs (small radii where it meets its neighbour, full ones on the free side).
public struct CornerRadii: Equatable {
    public var topLeft: CGFloat
    public var topRight: CGFloat
    public var bottomLeft: CGFloat
    public var bottomRight: CGFloat

    public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public init(uniform radius: CGFloat) {
        self.init(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }

    public var isUniform: Bool {
        return self.topLeft == self.topRight && self.topLeft == self.bottomLeft && self.topLeft == self.bottomRight
    }

    public func mapRadii(_ transform: (CGFloat) -> CGFloat) -> CornerRadii {
        return CornerRadii(
            topLeft: transform(self.topLeft),
            topRight: transform(self.topRight),
            bottomLeft: transform(self.bottomLeft),
            bottomRight: transform(self.bottomRight)
        )
    }
}

/// PRIVATE API. `CALayer` carries an undocumented `cornerRadii` property alongside the public
/// `cornerRadius`; it is a real animatable Core Animation property, so it composites with the layer
/// and needs no mask (a mask forces an offscreen pass and does not animate with the layer).
///
/// The struct layout is taken from QuartzCore's own Objective-C type encoding, which names and orders
/// the fields — do NOT reorder these from memory:
///
///     {CACornerRadii = "minXMaxY"{CGSize} "maxXMaxY"{CGSize} "maxXMinY"{CGSize} "minXMinY"{CGSize}}
///
/// Two things that encoding settles and intuition gets wrong: each corner is a **CGSize**, not a
/// CGFloat (the radii are elliptical, like SwiftUI's `UnevenRoundedRectangle`), and the fields are
/// ordered bottom-left, bottom-right, top-right, top-left in UIKit terms — a layer's y grows
/// downward, so `minY` is the TOP edge.
///
/// Nothing here sends a private selector: the value is boxed with the public
/// `NSValue(bytes:objCType:)` using that encoding, and applied through KVC, which `CALayer` supports
/// for its animatable properties. Only the property *name* is private, so a future OS that drops it
/// degrades to `cornerRadiiSupported == false` rather than crashing.
private let cornerRadiiObjCType = "{CACornerRadii={CGSize=dd}{CGSize=dd}{CGSize=dd}{CGSize=dd}}"

private let cornerRadiiKey = "cornerRadii"

public extension CornerRadii {
    /// Boxed in Core Animation's field order. Used for both the KVC set and the animation's
    /// from/to values, so the two cannot disagree about the layout.
    var boxedValue: NSValue {
        var fields: [CGSize] = [
            CGSize(width: self.bottomLeft, height: self.bottomLeft),    // minXMaxY
            CGSize(width: self.bottomRight, height: self.bottomRight),  // maxXMaxY
            CGSize(width: self.topRight, height: self.topRight),        // maxXMinY
            CGSize(width: self.topLeft, height: self.topLeft)           // minXMinY
        ]
        return NSValue(bytes: &fields, objCType: cornerRadiiObjCType)
    }

    /// Decodes a value read back off a layer. Returns nil when the box is not a `CACornerRadii` —
    /// checking the encoding rather than trusting it is what keeps a future layout change from being
    /// reinterpreted as four garbage doubles.
    init?(boxedValue value: NSValue) {
        guard strcmp(value.objCType, cornerRadiiObjCType) == 0 else {
            return nil
        }
        var fields = [CGSize](repeating: CGSize(), count: 4)
        value.getValue(&fields, size: MemoryLayout<CGSize>.stride * 4)
        // Field order per the encoding: minXMaxY, maxXMaxY, maxXMinY, minXMinY.
        self.init(
            topLeft: fields[3].width,
            topRight: fields[2].width,
            bottomLeft: fields[0].width,
            bottomRight: fields[1].width
        )
    }
}

public extension CALayer {
    /// Whether this OS exposes the private per-corner radii property. Probed once against `CALayer`
    /// itself rather than assumed from an OS version, since the property is not API and could be
    /// withdrawn independently of any version we could test for.
    static let cornerRadiiSupported: Bool = {
        return CALayer.instancesRespond(to: NSSelectorFromString("setCornerRadii:"))
    }()

    /// The layer's current four radii, read back through KVC — so an in-flight animation can be
    /// resumed from `presentation()?.cornerRadii` exactly like any ordinary layer property, rather
    /// than from a shadow copy the caller has to keep in sync.
    ///
    /// Not named to shadow anything: Swift cannot see the private ObjC property (it is in no header),
    /// so this is the only `cornerRadii` in scope and `value(forKey:)` reaches the real one.
    var cornerRadii: CornerRadii? {
        guard CALayer.cornerRadiiSupported, let value = self.value(forKey: cornerRadiiKey) as? NSValue else {
            return nil
        }
        return CornerRadii(boxedValue: value)
    }

    /// Applies four radii without animation. No-op when unsupported — callers that need a guaranteed
    /// clip must check `CALayer.cornerRadiiSupported` and fall back to a mask.
    func setCornerRadii(_ radii: CornerRadii) {
        guard CALayer.cornerRadiiSupported else {
            return
        }
        self.setValue(radii.boxedValue, forKey: cornerRadiiKey)
    }

    var cornerRadiiKeyPath: String {
        return cornerRadiiKey
    }
}
