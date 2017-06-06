import Foundation
import Display
import AsyncDisplayKit

final class VideoOverlayMediaItem: OverlayMediaItem {
    fileprivate weak var player: MediaPlayer?
    
    init(player: MediaPlayer) {
        self.player = player
    }
    
    func node() -> OverlayMediaItemNode {
        return VideoOverlayMediaItemNode(item: self)
    }
}

final class VideoOverlayMediaItemNode: OverlayMediaItemNode {
    private let item: VideoOverlayMediaItem
    
    init(item: VideoOverlayMediaItem) {
        self.item = item
        
        super.init()
        
        self.backgroundColor = .green
    }
}
