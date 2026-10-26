import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

enum InstantPageShape {
    case rect
    case ellipse
    case roundLine
}

/// Diameter of an unordered list's bullet dot, shared by both renderers — V1 draws it as an
/// `.ellipse` shape item, V2 as a `CALayer` dot filling the marker frame.
///
/// In V2 this is also the bullet's contribution to `maxIndexWidth`, the shared marker column that
/// list text starts after, so it moves the text indent too; in V1 a bullet never feeds the column
/// (only ordered/checklist markers do), so there it moves the dot alone.
let instantPageBulletMarkerDiameter: CGFloat = 5.0

/// How far below the line's geometric midpoint the bullet dot is drawn, in points.
///
/// Both renderers otherwise centre the dot on the midpoint of the first text line's box, which
/// includes the ascender headroom above the cap line — so a geometrically centred dot reads high
/// against lowercase text. This nudges it back down optically. It applies to the bullet ONLY;
/// number and checkbox markers stay geometrically centred.
let instantPageBulletMarkerVerticalOffset: CGFloat = 1.0

/// How far a list item's CONTENT sits away from the marker column, beyond the marker→text gap.
///
/// Applied by WIDENING the gutter rather than shifting the content origin: that narrows the content
/// column by the same amount, so a full-width wrapped line still ends on the page margin instead of
/// overhanging it by this much — and in V2 it mirrors for RTL for free, since
/// `instantPageV2ContentColumnX` derives the origin from the gutter.
let instantPageListItemTextwardOffset: CGFloat = 2.0

/// How far the bullet dot is nudged toward its item's text, in points — i.e. RIGHT in LTR and LEFT
/// in RTL, where V2 mirrors the marker gutter onto the trailing edge and the text sits to its left.
/// Named for the direction relative to the item rather than a physical one, because the sign flips.
/// Bullet only; number and checkbox markers are unshifted. (V1 lists never mirror, so there it is
/// always rightward.)
let instantPageBulletMarkerTextwardOffset: CGFloat = 2.0

public final class InstantPageShapeItem: InstantPageItem {
    public var frame: CGRect
    let shapeFrame: CGRect
    let shape: InstantPageShape
    let color: UIColor
    
    public let medias: [InstantPageMedia] = []
    public let wantsNode: Bool = false
    public let separatesTiles: Bool = false
    
    init(frame: CGRect, shapeFrame: CGRect, shape: InstantPageShape, color: UIColor) {
        self.frame = frame
        self.shapeFrame = shapeFrame
        self.shape = shape
        self.color = color
    }
    
    public func drawInTile(context: CGContext) {
        context.setFillColor(self.color.cgColor)
        
        switch self.shape {
            case .rect:
                context.fill(self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY))
            case .ellipse:
                context.fillEllipse(in: self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY))
            case .roundLine:
                if self.shapeFrame.size.width < self.shapeFrame.size.height {
                    let radius = self.shapeFrame.size.width / 2.0
                    var shapeFrame = self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY)
                    shapeFrame.origin.y += radius
                    shapeFrame.size.height -= radius + radius
                    context.fill(shapeFrame)
                    context.fillEllipse(in: CGRect(x: shapeFrame.minX, y: shapeFrame.minY - radius, width: radius + radius, height: radius + radius))
                    context.fillEllipse(in: CGRect(x: shapeFrame.minX, y: shapeFrame.maxY - radius, width: radius + radius, height: radius + radius))
                } else {
                    context.fill(self.shapeFrame.offsetBy(dx: self.frame.minX, dy: self.frame.minY))
                }
        }
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        return nil
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    public func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}
