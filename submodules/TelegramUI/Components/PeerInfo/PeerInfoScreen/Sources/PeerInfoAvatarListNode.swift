import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import PeerInfoAvatarListNode
import SwiftSignalKit
import Postbox
import TelegramCore
import ContextUI
import AccountContext
import Display

final class PeerInfoAvatarListNode: ASDisplayNode {
    private let isSettings: Bool
    let containerNode: ASDisplayNode
    let pinchSourceNode: PinchSourceContainerNode
    let bottomCoverNode: ASDisplayNode
    let maskNode: DynamicIslandMaskNode
    let topCoverNode: DynamicIslandBlurNode
    let avatarContainerNode: PeerInfoAvatarTransformContainerNode
    let listContainerTransformNode: ASDisplayNode
    let listContainerNode: PeerInfoAvatarListContainerNode
    
    let isReady = Promise<Bool>()
   
    var arguments: (Peer?, Int64?, EngineMessageHistoryThread.Info?, PresentationTheme, CGFloat, Bool)?
    var item: PeerInfoAvatarListItem?
    
    var itemsUpdated: (([PeerInfoAvatarListItem]) -> Void)?
    var animateOverlaysFadeIn: (() -> Void)?
    var openStories: (() -> Void)?
    
    init(context: AccountContext, readyWhenGalleryLoads: Bool, isSettings: Bool) {
        self.isSettings = isSettings
        
        self.containerNode = ASDisplayNode()

        self.bottomCoverNode = ASDisplayNode()
        
        self.maskNode = DynamicIslandMaskNode()
        self.pinchSourceNode = PinchSourceContainerNode()
        
        self.avatarContainerNode = PeerInfoAvatarTransformContainerNode(context: context)
        self.listContainerTransformNode = ASDisplayNode()
        self.listContainerNode = PeerInfoAvatarListContainerNode(context: context, isSettings: isSettings)
        self.listContainerNode.clipsToBounds = true
        self.listContainerNode.isHidden = true
        
        self.topCoverNode = DynamicIslandBlurNode()
        
        super.init()

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.bottomCoverNode)
        self.containerNode.addSubnode(self.pinchSourceNode)
        self.pinchSourceNode.contentNode.addSubnode(self.avatarContainerNode)
        self.listContainerTransformNode.addSubnode(self.listContainerNode)
        self.pinchSourceNode.contentNode.addSubnode(self.listContainerTransformNode)
        self.containerNode.addSubnode(self.topCoverNode)
        
        let avatarReady = (self.avatarContainerNode.avatarNode.ready
        |> mapToSignal { _ -> Signal<Bool, NoError> in
            return .complete()
        }
        |> then(.single(true)))
        
        let galleryReady = self.listContainerNode.isReady.get()
        |> filter { value in
            return value
        }
        |> take(1)
        
        let combinedSignal: Signal<Bool, NoError>
        if readyWhenGalleryLoads {
            combinedSignal = combineLatest(queue: .mainQueue(),
                avatarReady,
                galleryReady
            )
            |> map { lhs, rhs in
                return lhs && rhs
            }
        } else {
            combinedSignal = avatarReady
        }
        
        self.isReady.set(combinedSignal
        |> filter { value in
            return value
        }
        |> take(1))
        
        self.listContainerNode.itemsUpdated = { [weak self] items in
            if let strongSelf = self {
                strongSelf.item = items.first
                strongSelf.itemsUpdated?(items)
                if let (peer, threadId, threadInfo, theme, avatarSize, isExpanded) = strongSelf.arguments {
                    strongSelf.avatarContainerNode.update(peer: peer, threadId: threadId, threadInfo: threadInfo, item: strongSelf.item, theme: theme, avatarSize: avatarSize, isExpanded: isExpanded, isSettings: strongSelf.isSettings)
                }
            }
        }

        self.pinchSourceNode.activate = { [weak self] sourceNode in
            guard let strongSelf = self, let (_, _, _, _, _, isExpanded) = strongSelf.arguments, isExpanded else {
                return
            }
            let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                return UIScreen.main.bounds
            })
            context.sharedContext.mainWindow?.presentInGlobalOverlay(pinchController)
            
            strongSelf.listContainerNode.bottomShadowNode.alpha = 0.0
            strongSelf.listContainerNode.contentNode.updateIsInPinchMode(true)
        }

        self.pinchSourceNode.animatedOut = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.animateOverlaysFadeIn?()
            strongSelf.listContainerNode.contentNode.updateIsInPinchMode(false)
        }
        
        self.listContainerNode.openStories = { [weak self] in
            guard let self else {
                return
            }
            self.openStories?()
        }
    }
    
    func update(size: CGSize, avatarSize: CGFloat, isExpanded: Bool, peer: Peer?, isForum: Bool, threadId: Int64?, threadInfo: EngineMessageHistoryThread.Info?, theme: PresentationTheme, transition: ContainedViewLayoutTransition) {
        self.arguments = (peer, threadId, threadInfo, theme, avatarSize, isExpanded)
        self.maskNode.isForum = isForum
        self.pinchSourceNode.update(size: size, transition: transition)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.pinchSourceNode.frame = CGRect(origin: CGPoint(), size: size)
        self.avatarContainerNode.update(peer: peer, threadId: threadId, threadInfo: threadInfo, item: self.item, theme: theme, avatarSize: avatarSize, isExpanded: isExpanded, isSettings: self.isSettings)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.listContainerNode.isHidden {
            if let result = self.listContainerNode.view.hitTest(self.view.convert(point, to: self.listContainerNode.view), with: event) {
                return result
            }
        } else {
            if let result = self.avatarContainerNode.avatarNode.view.hitTest(self.view.convert(point, to: self.avatarContainerNode.avatarNode.view), with: event) {
                return result
            } else if let result = self.avatarContainerNode.iconView?.view?.hitTest(self.view.convert(point, to: self.avatarContainerNode.iconView?.view), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    func animateAvatarCollapse(transition: ContainedViewLayoutTransition) {
        if let currentItemNode = self.listContainerNode.currentItemNode, case .animated = transition {
            if let _ = self.avatarContainerNode.videoNode {

            } else if let _ = self.avatarContainerNode.markupNode {
                
            } else if let unroundedImage = self.avatarContainerNode.avatarNode.unroundedImage {
                let avatarCopyView = UIImageView()
                avatarCopyView.image = unroundedImage
                avatarCopyView.frame = self.avatarContainerNode.avatarNode.frame
                avatarCopyView.center = currentItemNode.imageNode.position
                currentItemNode.view.addSubview(avatarCopyView)
                let scale = currentItemNode.imageNode.bounds.height / avatarCopyView.bounds.height
                avatarCopyView.layer.transform = CATransform3DMakeScale(scale, scale, scale)
                avatarCopyView.alpha = 0.0
                transition.updateAlpha(layer: avatarCopyView.layer, alpha: 1.0, completion: { [weak avatarCopyView] _ in
                    Queue.mainQueue().after(0.1, {
                        avatarCopyView?.removeFromSuperview()
                    })
                })
            }
        }
    }
}
