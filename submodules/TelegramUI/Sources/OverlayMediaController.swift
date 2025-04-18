import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import AccountContext
import AVKit

public final class OverlayMediaControllerImpl: ViewController, OverlayMediaController {
    private var controllerNode: OverlayMediaControllerNode {
        return self.displayNode as! OverlayMediaControllerNode
    }
    
    public var updatePossibleEmbeddingItem: ((OverlayMediaControllerEmbeddingItem?) -> Void)?
    public var embedPossibleEmbeddingItem: ((OverlayMediaControllerEmbeddingItem) -> Bool)?

    private var pictureInPictureContainer: ASDisplayNode?
    private var pictureInPictureContent: PictureInPictureContent?
    
    public init() {
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayMediaControllerNode(updatePossibleEmbeddingItem: { [weak self] item in
            self?.updatePossibleEmbeddingItem?(item)
        }, embedPossibleEmbeddingItem: { [weak self] item in
            return self?.embedPossibleEmbeddingItem?(item) ?? false
        })
        self.displayNodeDidLoad()
    }
    
    public var hasNodes: Bool {
        return self.controllerNode.hasNodes
    }
    
    public func addNode(_ node: OverlayMediaItemNode, customTransition: Bool) {
        self.controllerNode.addNode(node, customTransition: customTransition)
    }
    
    public func removeNode(_ node: OverlayMediaItemNode, customTransition: Bool) {
        self.controllerNode.removeNode(node, customTransition: customTransition)
    }

    public func setPictureInPictureContent(content: PictureInPictureContent, absoluteRect: CGRect) {
        if self.pictureInPictureContainer == nil {
            let pictureInPictureContainer = ASDisplayNode()
            pictureInPictureContainer.clipsToBounds = false
            self.pictureInPictureContainer = pictureInPictureContainer
            self.controllerNode.addSubnode(pictureInPictureContainer)
        }
        self.pictureInPictureContainer?.clipsToBounds = false
        self.pictureInPictureContent = content
        self.pictureInPictureContainer?.addSubnode(content.videoNode)
    }

    public func setPictureInPictureContentHidden(content: PictureInPictureContent, isHidden value: Bool) {
        if self.pictureInPictureContent === content {
            self.pictureInPictureContainer?.clipsToBounds = value
        }
    }

    public func removePictureInPictureContent(content: PictureInPictureContent) {
        if self.pictureInPictureContent === content {
            self.pictureInPictureContent = nil
            content.videoNode.removeFromSupernode()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let updatedLayout = ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: (layout.statusBarHeight ?? 0.0) + 44.0, left: layout.intrinsicInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.intrinsicInsets.right), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver)
        self.controllerNode.containerLayoutUpdated(updatedLayout, transition: transition)
    }
}
