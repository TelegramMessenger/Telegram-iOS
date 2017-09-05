import Foundation
import Postbox
import TelegramCore

final class InstantPagePlayableVideoItem: InstantPageItem {
    var frame: CGRect
    
    let media: InstantPageMedia
    var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let interactive: Bool
    
    let wantsNode: Bool = true
    
    init(frame: CGRect, media: InstantPageMedia, interactive: Bool) {
        self.frame = frame
        self.media = media
        self.interactive = interactive
    }
    
    func node(account: Account, strings: PresentationStrings, theme: InstantPageTheme, openMedia: @escaping (InstantPageMedia) -> Void, openPeer: @escaping (PeerId) -> Void) -> InstantPageNode? {
        return InstantPagePlayableVideoNode(account: account, media: self.media, interactive: self.interactive, openMedia: openMedia)
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

