import Foundation
import TelegramCore

enum InstantPageMediaArguments {
    case image(interactive: Bool, roundCorners: Bool, fit: Bool)
    case video(interactive: Bool, autoplay: Bool)
}

final class InstantPageMediaItem: InstantPageItem {
    var frame: CGRect
    
    let media: InstantPageMedia
    var medias: [InstantPageMedia] {
        return [self.media]
    }
    
    let arguments: InstantPageMediaArguments
    
    let wantsNode: Bool = true
    let hasLinks: Bool = false
    
    init(frame: CGRect, media: InstantPageMedia, arguments: InstantPageMediaArguments) {
        self.frame = frame
        self.media = media
        self.arguments = arguments
    }
    
    func node(account: Account) -> InstantPageNode? {
        return InstantPageMediaNode(account: account, media: self.media, arguments: self.arguments)
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPageMediaNode {
            return node.media == self.media
        } else {
            return false
        }
    }
    
    func distanceThresholdGroup() -> Int? {
        return 1
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 400.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    func drawInTile(context: CGContext) {
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
}
