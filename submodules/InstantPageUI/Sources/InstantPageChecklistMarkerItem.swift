import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI
import CheckNode

final class InstantPageChecklistMarkerItem: InstantPageItem {
    var frame: CGRect
    let checked: Bool
    
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []
    
    init(frame: CGRect, checked: Bool) {
        self.frame = frame
        self.checked = checked
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        return InstantPageChecklistMarkerNode(theme: theme, checked: self.checked)
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageChecklistMarkerNode {
            return node.checked == self.checked
        } else {
            return false
        }
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

private func instantPageChecklistMarkerTheme(theme: InstantPageTheme) -> CheckNodeTheme {
    return CheckNodeTheme(
        backgroundColor: theme.panelAccentColor,
        strokeColor: theme.pageBackgroundColor,
        borderColor: theme.controlColor,
        overlayBorder: false,
        hasInset: false,
        hasShadow: false
    )
}

final class InstantPageChecklistMarkerNode: ASDisplayNode, InstantPageNode {
    let checked: Bool
    private let checkNode: CheckNode
    
    init(theme: InstantPageTheme, checked: Bool) {
        self.checked = checked
        self.checkNode = CheckNode(theme: instantPageChecklistMarkerTheme(theme: theme), content: .check(isRectangle: true))
        
        super.init()
        
        self.isUserInteractionEnabled = false
        self.checkNode.isUserInteractionEnabled = false
        self.addSubnode(self.checkNode)
        self.checkNode.setSelected(checked, animated: false)
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.checkNode.theme = instantPageChecklistMarkerTheme(theme: theme)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.checkNode, frame: CGRect(origin: .zero, size: size))
    }
}
