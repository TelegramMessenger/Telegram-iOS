import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

final class InstantPagePeerReferenceItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia] = []
    
    let initialPeer: Peer
    let safeInset: CGFloat
    let transparent: Bool
    let rtl: Bool
    
    init(frame: CGRect, initialPeer: Peer, safeInset: CGFloat, transparent: Bool, rtl: Bool) {
        self.frame = frame
        self.initialPeer = initialPeer
        self.safeInset = safeInset
        self.transparent = transparent
        self.rtl = rtl
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPagePeerReferenceNode(context: context, strings: strings, nameDisplayOrder: nameDisplayOrder, theme: theme, initialPeer: self.initialPeer, safeInset: self.safeInset, transparent: self.transparent, rtl: self.rtl, openPeer: openPeer)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPagePeerReferenceNode {
            return self.initialPeer.id == node.peer?.id && self.safeInset == node.safeInset
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 5
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    func drawInTile(context: CGContext) {
    }
}
