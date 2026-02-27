import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import Display
import RadialStatusNode
import Postbox
import TelegramCore
import PeerInfoAvatarListNode
import AvatarNode
import SwiftSignalKit

final class PeerInfoEditingAvatarOverlayNode: ASDisplayNode {
    private let context: AccountContext
    
    private let imageNode: ImageNode
    private let updatingAvatarOverlay: ASImageNode
    private let iconNode: ASImageNode
    private var statusNode: RadialStatusNode
    
    private var currentRepresentation: TelegramMediaImageRepresentation?
    
    init(context: AccountContext) {
        self.context = context
        
        self.imageNode = ImageNode(enableEmpty: true)
        
        self.updatingAvatarOverlay = ASImageNode()
        self.updatingAvatarOverlay.displayWithoutProcessing = true
        self.updatingAvatarOverlay.displaysAsynchronously = false
        self.updatingAvatarOverlay.alpha = 0.0
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.6))
        self.statusNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: .white)
        self.iconNode.alpha = 0.0
        
        super.init()
        
        self.imageNode.frame = CGRect(origin: CGPoint(x: -50.0, y: -50.0), size: CGSize(width: 100.0, height: 100.0))
        self.updatingAvatarOverlay.frame = self.imageNode.frame
        
        let radialStatusSize: CGFloat = 50.0
        let imagePosition = self.imageNode.position
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor(imagePosition.x - radialStatusSize / 2.0), y: floor(imagePosition.y - radialStatusSize / 2.0)), size: CGSize(width: radialStatusSize, height: radialStatusSize))
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor(imagePosition.x - image.size.width / 2.0), y: floor(imagePosition.y - image.size.height / 2.0)), size: image.size)
        }
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.updatingAvatarOverlay)
        self.addSubnode(self.statusNode)
    }
    
    func updateTransitionFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self, alpha: 1.0 - fraction)
    }
    
    func update(peer: Peer?, threadData: MessageHistoryThreadData?, chatLocation: ChatLocation, item: PeerInfoAvatarListItem?, updatingAvatar: PeerInfoUpdatingAvatar?, uploadProgress: AvatarUploadProgress?, theme: PresentationTheme, avatarSize: CGFloat, isEditing: Bool) {
        guard let peer = peer else {
            return
        }
        
        self.imageNode.frame = CGRect(origin: CGPoint(x: -avatarSize / 2.0, y: -avatarSize / 2.0), size: CGSize(width: avatarSize, height: avatarSize))
        self.updatingAvatarOverlay.frame = self.imageNode.frame
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
        
        let clipStyle: AvatarNodeClipStyle
        if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
            clipStyle = .roundedRect
        } else {
            clipStyle = .round
        }
        
        var isPersonal = false
        if let updatingAvatar, case let .image(image) = updatingAvatar, image.isPersonal {
            isPersonal = true
        }
        
        if canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData)
            || isPersonal
            || self.currentRepresentation != nil && updatingAvatar == nil  {
            var overlayHidden = true
            if let updatingAvatar = updatingAvatar {
                overlayHidden = false
                
                var cancelEnabled = true
                let progressValue: CGFloat?
                if let uploadProgress {
                    switch uploadProgress {
                    case let .value(value):
                        progressValue = max(0.027, value)
                    case .indefinite:
                        progressValue = nil
                        cancelEnabled = false
                    }
                } else {
                    progressValue = 0.027
                }
                self.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: progressValue, cancelEnabled: cancelEnabled, animateRotation: true))
                
                if case let .image(representation) = updatingAvatar {
                    if representation != self.currentRepresentation {
                        self.currentRepresentation = representation

                        if let signal = peerAvatarImage(account: context.account, peerReference: nil, authorOfMessage: nil, representation: representation, displayDimensions: CGSize(width: avatarSize, height: avatarSize), clipStyle: clipStyle, emptyColor: nil, synchronousLoad: false, provideUnrounded: false) {
                            self.imageNode.setSignal(signal |> map { $0?.0 })
                        }
                    }
                }
                
                transition.updateAlpha(node: self.updatingAvatarOverlay, alpha: 1.0)
            } else {
                let targetOverlayAlpha: CGFloat = 0.0
                if self.updatingAvatarOverlay.alpha != targetOverlayAlpha {
                    let update = {
                        self.statusNode.transitionToState(.none)
                        self.currentRepresentation = nil
                        self.imageNode.setSignal(.single(nil))
                        transition.updateAlpha(node: self.updatingAvatarOverlay, alpha: overlayHidden ? 0.0 : 1.0)
                    }
                    Queue.mainQueue().after(0.3) {
                        update()
                    }
                }
            }
            if !overlayHidden && self.updatingAvatarOverlay.image == nil {
                switch clipStyle {
                case .round:
                    self.updatingAvatarOverlay.image = generateFilledCircleImage(diameter: avatarSize, color: UIColor(white: 0.0, alpha: 0.4), backgroundColor: nil)
                case .roundedRect:
                    self.updatingAvatarOverlay.image = generateFilledRoundedRectImage(size: CGSize(width: avatarSize, height: avatarSize), cornerRadius: avatarSize * 0.25, color: UIColor(white: 0.0, alpha: 0.4), backgroundColor: nil)
                default:
                    break
                }
            }
        } else {
            self.statusNode.transitionToState(.none)
            self.currentRepresentation = nil
            transition.updateAlpha(node: self.iconNode, alpha: 0.0)
            transition.updateAlpha(node: self.updatingAvatarOverlay, alpha: 0.0)
        }
    }
}
