import Foundation

final class OverlayMediaManager {
    var controller: OverlayMediaController?
    
    private var items: [(OverlayMediaItem, OverlayMediaItemNode)] = []
    
    init() {
        
    }
    
    func attachOverlayMediaController(_ controller: OverlayMediaController) {
        self.controller = controller
    }
    
    func addItem(_ item: OverlayMediaItem) {
        let node = item.node()
        self.items.append((item, node))
        
        if let controller = self.controller {
            node.frame = CGRect(origin: CGPoint(x: 10.0, y: 80.0), size: CGSize(width: 100.0, height: 60.0))
            controller.displayNode.addSubnode(node)
        }
    }
    
    func removeItem(_ item: OverlayMediaItem) {
        for i in 0 ..< self.items.count {
            if item === self.items[i].0 {
                self.items[i].1.removeFromSupernode()
                self.items.remove(at: i)
                break
            }
        }
    }
}
