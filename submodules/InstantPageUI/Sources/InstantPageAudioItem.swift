import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

final class InstantPageAudioItem: InstantPageItem {
    var frame: CGRect
    let wantsNode: Bool = true
    let separatesTiles: Bool = false
    let medias: [InstantPageMedia]
    
    let media: InstantPageMedia
    let webpage: TelegramMediaWebpage
    
    init(frame: CGRect, media: InstantPageMedia, webpage: TelegramMediaWebpage) {
        self.frame = frame
        self.media = media
        self.webpage = webpage
        self.medias = [media]
    }
    
    func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?) -> (InstantPageNode & ASDisplayNode)? {
        return InstantPageAudioNode(context: context, strings: strings, theme: theme, webPage: self.webpage, media: self.media, openMedia: openMedia)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageAudioNode {
            return self.media == node.media
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 4
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

