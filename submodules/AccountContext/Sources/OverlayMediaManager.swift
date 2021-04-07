import Foundation
import UIKit
import Display

public final class OverlayMediaControllerEmbeddingItem {
    public let position: CGPoint
    public let itemNode: OverlayMediaItemNode
    
    public init(
        position: CGPoint,
        itemNode: OverlayMediaItemNode
    ) {
        self.position = position
        self.itemNode = itemNode
    }
}

public protocol OverlayMediaController: class {
    var updatePossibleEmbeddingItem: ((OverlayMediaControllerEmbeddingItem?) -> Void)? { get set }
    var embedPossibleEmbeddingItem: ((OverlayMediaControllerEmbeddingItem) -> Bool)? { get set }
    
    var hasNodes: Bool { get }
    func addNode(_ node: OverlayMediaItemNode, customTransition: Bool)
    func removeNode(_ node: OverlayMediaItemNode, customTransition: Bool)
}

public final class OverlayMediaManager {
    public var controller: (OverlayMediaController & ViewController)?
    
    public var updatePossibleEmbeddingItem: ((OverlayMediaControllerEmbeddingItem?) -> Void)?
    public var embedPossibleEmbeddingItem: ((OverlayMediaControllerEmbeddingItem) -> Bool)?
    
    public init() {
    }
    
    public func attachOverlayMediaController(_ controller: OverlayMediaController & ViewController) {
        self.controller = controller
        
        controller.updatePossibleEmbeddingItem = { [weak self] item in
            self?.updatePossibleEmbeddingItem?(item)
        }
        
        controller.embedPossibleEmbeddingItem = { [weak self] item in
            return self?.embedPossibleEmbeddingItem?(item) ?? false
        }
    }
}
