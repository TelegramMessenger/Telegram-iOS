import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import AsyncDisplayKit
import PhotoResources
import SwiftSignalKit
import UniversalMediaPlayer
import TelegramUniversalVideoContent

final class StoryMessageContentComponent: Component {
	let context: AccountContext
	let message: EngineMessage

	init(context: AccountContext, message: EngineMessage) {
		self.context = context
		self.message = message
	}

	static func ==(lhs: StoryMessageContentComponent, rhs: StoryMessageContentComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
		if lhs.message != rhs.message {
			return false
		}
		return true
	}
    
    static func preload(context: AccountContext, message: EngineMessage) -> Signal<Never, NoError> {
        var messageMedia: EngineMedia?
        for media in message.media {
            switch media {
            case let image as TelegramMediaImage:
                messageMedia = .image(image)
            case let file as TelegramMediaFile:
                messageMedia = .file(file)
            default:
                break
            }
        }
        
        guard let messageMedia else {
            return .complete()
        }
        
        var fetchSignal: Signal<Never, NoError>?
        switch messageMedia {
        case let .image(image):
            if let representation = image.representations.last {
                fetchSignal = fetchedMediaResource(
                    mediaBox: context.account.postbox.mediaBox,
                    userLocation: .peer(message.id.peerId),
                    userContentType: .image,
                    reference: ImageMediaReference.message(message: MessageReference(message._asMessage()), media: image).resourceReference(representation.resource)
                )
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            }
        case let .file(file):
            fetchSignal = fetchedMediaResource(
                mediaBox: context.account.postbox.mediaBox,
                userLocation: .peer(message.id.peerId),
                userContentType: .image,
                reference: FileMediaReference.message(message: MessageReference(message._asMessage()), media: file).resourceReference(file.resource)
            )
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
        default:
            break
        }
        
        return fetchSignal ?? .complete()
    }

	final class View: UIView {
        private let imageNode: TransformImageNode
        private var videoNode: UniversalVideoNode?
        
        private var currentMessageMedia: EngineMedia?
        private var fetchDisposable: Disposable?
        
        private var component: StoryMessageContentComponent?
        private weak var state: EmptyComponentState?
        
		override init(frame: CGRect) {
            self.imageNode = TransformImageNode()
            
			super.init(frame: frame)
            
            self.addSubnode(self.imageNode)
		}
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable?.dispose()
        }
        
        private func performActionAfterImageContentLoaded(update: Bool) {
            guard let component = self.component, let currentMessageMedia = self.currentMessageMedia else {
                return
            }
            
            if case let .file(file) = currentMessageMedia {
                if self.videoNode == nil {
                    let videoNode = UniversalVideoNode(
                        postbox: component.context.account.postbox,
                        audioSession: component.context.sharedContext.mediaManager.audioSession,
                        manager: component.context.sharedContext.mediaManager.universalVideoManager,
                        decoration: StoryVideoDecoration(),
                        content: NativeVideoContent(
                            id: .message(component.message.stableId, file.fileId),
                            userLocation: .peer(component.message.id.peerId),
                            fileReference: .message(message: MessageReference(component.message._asMessage()), media: file),
                            imageReference: nil,
                            loopVideo: true,
                            enableSound: true,
                            tempFilePath: nil,
                            captureProtected: component.message._asMessage().isCopyProtected(),
                            storeAfterDownload: nil
                        ),
                        priority: .gallery
                    )
                    videoNode.ownsContentNodeUpdated = { [weak self] value in
                        guard let self else {
                            return
                        }
                        if value {
                            self.videoNode?.seek(0.0)
                            self.videoNode?.play()
                        }
                    }
                    videoNode.canAttachContent = true
                    self.videoNode = videoNode
                    self.addSubnode(videoNode)
                    if update {
                        self.state?.updated(transition: .immediate)
                    }
                }
            }
        }
        
        func update(component: StoryMessageContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            var messageMedia: EngineMedia?
            for media in component.message.media {
                switch media {
                case let image as TelegramMediaImage:
                    messageMedia = .image(image)
                case let file as TelegramMediaFile:
                    messageMedia = .file(file)
                default:
                    break
                }
            }
            
            var reloadMedia = false
            if self.currentMessageMedia?.id != messageMedia?.id {
                self.currentMessageMedia = messageMedia
                reloadMedia = true
            }
            
            if reloadMedia, let messageMedia {
                var signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var fetchSignal: Signal<Never, NoError>?
                switch messageMedia {
                case let .image(image):
                    signal = chatMessagePhoto(
                        postbox: component.context.account.postbox,
                        userLocation: .peer(component.message.id.peerId),
                        photoReference: .message(message: MessageReference(component.message._asMessage()), media: image),
                        synchronousLoad: true,
                        highQuality: true
                    )
                    if let representation = image.representations.last {
                        fetchSignal = fetchedMediaResource(
                            mediaBox: component.context.account.postbox.mediaBox,
                            userLocation: .peer(component.message.id.peerId),
                            userContentType: .image,
                            reference: ImageMediaReference.message(message: MessageReference(component.message._asMessage()), media: image).resourceReference(representation.resource)
                        )
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    }
                case let .file(file):
                    signal = chatMessageVideo(
                        postbox: component.context.account.postbox,
                        userLocation: .peer(component.message.id.peerId),
                        videoReference: .message(message: MessageReference(component.message._asMessage()), media: file),
                        synchronousLoad: true
                    )
                    fetchSignal = fetchedMediaResource(
                        mediaBox: component.context.account.postbox.mediaBox,
                        userLocation: .peer(component.message.id.peerId),
                        userContentType: .image,
                        reference: FileMediaReference.message(message: MessageReference(component.message._asMessage()), media: file).resourceReference(file.resource)
                    )
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .complete()
                    }
                default:
                    break
                }
                
                if let signal {
                    var wasSynchronous = true
                    self.imageNode.setSignal(signal |> afterCompleted { [weak self] in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            
                            self.performActionAfterImageContentLoaded(update: !wasSynchronous)
                        }
                    }, attemptSynchronously: true)
                    wasSynchronous = false
                }
                
                self.fetchDisposable?.dispose()
                self.fetchDisposable = nil
                if let fetchSignal {
                    self.fetchDisposable = fetchSignal.start()
                }
            }
            
            if let messageMedia {
                var dimensions: CGSize?
                switch messageMedia {
                case let .image(image):
                    dimensions = image.representations.last?.dimensions.cgSize
                case let .file(file):
                    dimensions = file.dimensions?.cgSize
                default:
                    break
                }
                
                if let dimensions {
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(
                        corners: ImageCorners(),
                        imageSize: dimensions.aspectFilled(availableSize),
                        boundingSize: availableSize,
                        intrinsicInsets: UIEdgeInsets()
                    ))
                    apply()
                    
                    if let videoNode = self.videoNode {
                        let videoSize = dimensions.aspectFilled(availableSize)
                        videoNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) * 0.5), y: floor((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                        videoNode.updateLayout(size: videoSize, transition: .immediate)
                    }
                }
                self.imageNode.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            
            return availableSize
        }
	}

	func makeView() -> View {
		return View(frame: CGRect())
	}

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
