import Foundation
import UIKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

final class InstantPagePlayableVideoItem: InstantPageItem {
    var frame: CGRect
    let webPage: TelegramMediaWebpage
    
    let media: InstantPageMedia
    var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let interactive: Bool
    
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    
    init(frame: CGRect, webPage: TelegramMediaWebpage, media: InstantPageMedia, interactive: Bool) {
        self.frame = frame
        self.webPage = webPage
        self.media = media
        self.interactive = interactive
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourcePeerType: MediaAutoDownloadPeerType, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> InstantPageNode? {
        return InstantPagePlayableVideoNode(context: context, webPage: self.webPage, theme: theme, media: self.media, interactive: self.interactive, openMedia: openMedia)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPagePlayableVideoNode {
            return node.media == self.media
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 2
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 200.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
}

