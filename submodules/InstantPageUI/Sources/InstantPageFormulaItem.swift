import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

final class InstantPageFormulaNode: ASImageNode, InstantPageNode {
    let attachment: InstantPageMathAttachment

    init(attachment: InstantPageMathAttachment) {
        self.attachment = attachment
        super.init()

        self.isUserInteractionEnabled = false
        self.displaysAsynchronously = false
        self.image = attachment.rendered.image
    }

    func updateIsVisible(_ isVisible: Bool) {
    }

    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }

    func updateHiddenMedia(media: InstantPageMedia?) {
    }

    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }

    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
}

final class InstantPageTextFormulaItem: InstantPageItem {
    var frame: CGRect
    let attachment: InstantPageMathAttachment

    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []

    init(frame: CGRect, attachment: InstantPageMathAttachment) {
        self.frame = frame
        self.attachment = attachment
    }

    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }

    func drawInTile(context: CGContext) {
    }

    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        return InstantPageFormulaNode(attachment: self.attachment)
    }

    func matchesNode(_ node: InstantPageNode) -> Bool {
        guard let node = node as? InstantPageFormulaNode else {
            return false
        }
        return self.attachment.isEqual(to: node.attachment)
    }

    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }

    func distanceThresholdGroup() -> Int? {
        return nil
    }

    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}

final class InstantPageFormulaItem: InstantPageItem {
    var frame: CGRect
    let attachment: InstantPageMathAttachment

    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []

    init(frame: CGRect, attachment: InstantPageMathAttachment) {
        self.frame = frame
        self.attachment = attachment
    }

    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }

    func drawInTile(context: CGContext) {
    }

    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        return InstantPageFormulaNode(attachment: self.attachment)
    }

    func matchesNode(_ node: InstantPageNode) -> Bool {
        guard let node = node as? InstantPageFormulaNode else {
            return false
        }
        return self.attachment.isEqual(to: node.attachment)
    }

    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }

    func distanceThresholdGroup() -> Int? {
        return nil
    }

    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}

final class InstantPageScrollableFormulaItem: InstantPageScrollableItem {
    var frame: CGRect
    let attachment: InstantPageMathAttachment
    let totalWidth: CGFloat
    let horizontalInset: CGFloat

    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let isRTL: Bool = false

    init(frame: CGRect, attachment: InstantPageMathAttachment, totalWidth: CGFloat, horizontalInset: CGFloat) {
        self.frame = frame
        self.attachment = attachment
        self.totalWidth = totalWidth
        self.horizontalInset = horizontalInset
    }

    var contentSize: CGSize {
        return CGSize(width: self.totalWidth, height: self.frame.height)
    }

    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }

    func drawInTile(context: CGContext) {
    }

    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        let node = InstantPageFormulaNode(attachment: self.attachment)
        node.frame = CGRect(origin: .zero, size: self.attachment.rendered.size)
        return InstantPageScrollableNode(item: self, additionalNodes: [node])
    }

    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageScrollableNode {
            return node.item === self
        }
        return false
    }

    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }

    func distanceThresholdGroup() -> Int? {
        return nil
    }

    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }

    func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
        return nil
    }
}
