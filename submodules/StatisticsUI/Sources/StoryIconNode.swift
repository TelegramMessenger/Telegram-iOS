import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import PhotoResources
import AvatarStoryIndicatorComponent
import AccountContext
import TelegramPresentationData

final class StoryIconNode: ASDisplayNode {
    private let imageNode = TransformImageNode()
    private let storyIndicator = ComponentView<Empty>()
    
    init(context: AccountContext, theme: PresentationTheme, peer: Peer, storyItem: EngineStoryItem) {
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
       
        let imageSize = CGSize(width: 30.0, height: 30.0)
        let size = CGSize(width: 36.0, height: 36.0)
        let bounds = CGRect(origin: .zero, size: size)
        
        self.imageNode.frame = bounds.insetBy(dx: 3.0, dy: 3.0)
        self.frame = bounds
        
        let media: Media?
        switch storyItem.media {
        case let .image(image):
            media = image
        case let .file(file):
            media = file
        default:
            media = nil
        }
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        var dimensions: CGSize?
        if let peerReference = PeerReference(peer), let media {
            if let image = media as? TelegramMediaImage {
                updateImageSignal = mediaGridMessagePhoto(account: context.account, userLocation: .peer(peer.id), photoReference: .story(peer: peerReference, id: storyItem.id, media: image))
                dimensions = largestRepresentationForPhoto(image)?.dimensions.cgSize
            } else if let file = media as? TelegramMediaFile {
                updateImageSignal = mediaGridMessageVideo(postbox: context.account.postbox, userLocation: .peer(peer.id), videoReference: .story(peer: peerReference, id: storyItem.id, media: file), autoFetchFullSizeThumbnail: true)
                dimensions = file.dimensions?.cgSize
            }
        }

        if let updateImageSignal {
            self.imageNode.setSignal(updateImageSignal)
        }
        
        if let dimensions {
            let cornerRadius = imageSize.width / 2.0
            let makeImageLayout = self.imageNode.asyncLayout()
            let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(radius: cornerRadius), imageSize: dimensions.aspectFilled(imageSize), boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
            applyImageLayout()
        }
        
        let lineWidth: CGFloat = 1.5
        let indicatorSize = CGSize(width: size.width - lineWidth * 4.0, height: size.height - lineWidth * 4.0)

        let _ = self.storyIndicator.update(
            transition: .immediate,
            component: AnyComponent(AvatarStoryIndicatorComponent(
                hasUnseen: true,
                hasUnseenCloseFriendsItems: false,
                colors: AvatarStoryIndicatorComponent.Colors(
                    unseenColors: theme.chatList.storyUnseenColors.array,
                    unseenCloseFriendsColors: theme.chatList.storyUnseenPrivateColors.array,
                    seenColors: theme.chatList.storySeenColors.array
                ),
                activeLineWidth: lineWidth,
                inactiveLineWidth: lineWidth,
                counters: AvatarStoryIndicatorComponent.Counters(
                    totalCount: 1,
                    unseenCount: 1
                ),
                progress: nil
            )),
            environment: {},
            containerSize: indicatorSize
        )
        if let storyIndicatorView = self.storyIndicator.view {
            storyIndicatorView.frame = CGRect(origin: CGPoint(x: bounds.midX - indicatorSize.width / 2.0, y: bounds.midY - indicatorSize.height / 2.0), size: indicatorSize)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let storyIndicatorView = self.storyIndicator.view {
            if storyIndicatorView.superview == nil {
                self.view.addSubview(storyIndicatorView)
            }
        }
    }

    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 36.0, height: 36.0)
    }
}
