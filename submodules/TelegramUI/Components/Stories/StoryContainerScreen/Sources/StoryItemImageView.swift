import Foundation
import UIKit
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import ComponentFlow
import TinyThumbnail
import ImageBlur
import MediaResources
import Display
import TelegramPresentationData
import BundleIconComponent
import MultilineTextComponent

final class StoryItemImageView: UIView {
    private let contentView: UIImageView
    private var captureProtectedView: UITextField?
    
    private var captureProtectedInfo: ComponentView<Empty>?
    
    private var currentMedia: EngineMedia?
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    
    private(set) var isContentLoaded: Bool = false
    var didLoadContents: (() -> Void)?
    
    override init(frame: CGRect) {
        self.contentView = UIImageView()
        self.contentView.contentMode = .scaleAspectFill
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    private func updateImage(image: UIImage, isCaptureProtected: Bool) {
        self.contentView.image = image
        
        if isCaptureProtected {
            let captureProtectedView: UITextField
            if let current = self.captureProtectedView {
                captureProtectedView = current
            } else {
                captureProtectedView = UITextField(frame: self.contentView.frame)
                captureProtectedView.isSecureTextEntry = true
                self.captureProtectedView = captureProtectedView
                self.layer.addSublayer(captureProtectedView.layer)
                captureProtectedView.layer.sublayers?.first?.addSublayer(self.contentView.layer)
            }
        } else {
            if self.contentView.layer.superlayer !== self.layer {
                self.layer.addSublayer(self.contentView.layer)
            }
            if let captureProtectedView = self.captureProtectedView {
                self.captureProtectedView = nil
                captureProtectedView.layer.removeFromSuperlayer()
            }
        }
    }
    
    func update(context: AccountContext, strings: PresentationStrings, peer: EnginePeer, storyId: Int32, media: EngineMedia, size: CGSize, isCaptureProtected: Bool, attemptSynchronous: Bool, transition: Transition) {
        self.backgroundColor = isCaptureProtected ? UIColor(rgb: 0x181818) : nil
        
        var dimensions: CGSize?
        
        let isMediaUpdated: Bool
        if let currentMedia = self.currentMedia {
            isMediaUpdated = !currentMedia._asMedia().isSemanticallyEqual(to: media._asMedia())
        } else {
            isMediaUpdated = true
        }
        
        switch media {
        case let .image(image):
            if let representation = largestImageRepresentation(image.representations) {
                dimensions = representation.dimensions.cgSize
                
                if isMediaUpdated {
                    if attemptSynchronous, let path = context.account.postbox.mediaBox.completedResourcePath(id: representation.resource.id, pathExtension: nil) {
                        if #available(iOS 15.0, *) {
                            if let image = UIImage(contentsOfFile: path)?.preparingForDisplay() {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            }
                        } else {
                            if let image = UIImage(contentsOfFile: path)?.precomposed() {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            }
                        }
                        self.isContentLoaded = true
                        self.didLoadContents?()
                    } else {
                        if let thumbnailData = image.immediateThumbnailData.flatMap(decodeTinyThumbnail), let thumbnailImage = UIImage(data: thumbnailData) {
                            if let image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3) {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            }
                        }
                        
                        if let peerReference = PeerReference(peer._asPeer()) {
                            self.fetchDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .story, reference: .media(media: .story(peer: peerReference, id: storyId, media: media._asMedia()), resource: representation.resource), ranges: nil).start()
                        }
                        self.disposable = (context.account.postbox.mediaBox.resourceData(representation.resource, option: .complete(waitUntilFetchStatus: false))
                        |> map { result -> UIImage? in
                            if result.complete {
                                if #available(iOS 15.0, *) {
                                    if let image = UIImage(contentsOfFile: result.path)?.preparingForDisplay() {
                                        return image
                                    } else {
                                        return nil
                                    }
                                } else {
                                    if let image = UIImage(contentsOfFile: result.path)?.precomposed() {
                                        return image
                                    } else {
                                        return nil
                                    }
                                }
                            } else {
                                return nil
                            }
                        }
                        |> deliverOnMainQueue).start(next: { [weak self] image in
                            guard let self else {
                                return
                            }
                            if let image {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                                self.isContentLoaded = true
                                self.didLoadContents?()
                            }
                        })
                    }
                }
            }
        case let .file(file):
            dimensions = file.dimensions?.cgSize
            
            if isMediaUpdated {
                let cachedPath = context.account.postbox.mediaBox.cachedRepresentationCompletePath(file.resource.id, representation: CachedVideoFirstFrameRepresentation())
                
                if attemptSynchronous, FileManager.default.fileExists(atPath: cachedPath) {
                    if #available(iOS 15.0, *) {
                        if let image = UIImage(contentsOfFile: cachedPath)?.preparingForDisplay() {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                        }
                    } else {
                        if let image = UIImage(contentsOfFile: cachedPath)?.precomposed() {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                        }
                    }
                    self.isContentLoaded = true
                    self.didLoadContents?()
                } else {
                    if let thumbnailData = file.immediateThumbnailData.flatMap(decodeTinyThumbnail), let thumbnailImage = UIImage(data: thumbnailData) {
                        if let image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3) {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                        }
                    }
                    
                    self.disposable = (context.account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedVideoFirstFrameRepresentation(), complete: true, fetch: true, attemptSynchronously: false)
                    |> map { result -> UIImage? in
                        if result.complete {
                            if #available(iOS 15.0, *) {
                                if let image = UIImage(contentsOfFile: result.path)?.preparingForDisplay() {
                                    return image
                                } else {
                                    return nil
                                }
                            } else {
                                if let image = UIImage(contentsOfFile: result.path)?.precomposed() {
                                    return image
                                } else {
                                    return nil
                                }
                            }
                        } else {
                            return nil
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] image in
                        guard let self else {
                            return
                        }
                        if let image {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            self.isContentLoaded = true
                            self.didLoadContents?()
                        }
                    })
                }
            }
        default:
            break
        }
        self.currentMedia = media
        
        if let dimensions {
            let filledSize = dimensions.aspectFilled(size)
            let contentFrame = CGRect(origin: CGPoint(x: floor((size.width - filledSize.width) * 0.5), y: floor((size.height - filledSize.height) * 0.5)), size: filledSize)
            
            if let captureProtectedView = self.captureProtectedView {
                transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: contentFrame.size))
                transition.setFrame(view: captureProtectedView, frame: contentFrame)
            } else {
                transition.setFrame(view: self.contentView, frame: contentFrame)
            }
        }
        
        if isCaptureProtected {
            let captureProtectedInfo: ComponentView<Empty>
            var captureProtectedInfoTransition = transition
            if let current = self.captureProtectedInfo {
                captureProtectedInfo = current
            } else {
                captureProtectedInfoTransition = transition.withAnimation(.none)
                captureProtectedInfo = ComponentView()
                self.captureProtectedInfo = captureProtectedInfo
            }
            let captureProtectedInfoSize = captureProtectedInfo.update(
                transition: captureProtectedInfoTransition,
                component: AnyComponent(CaptureProtectedInfoComponent(
                    strings: strings
                )),
                environment: {},
                containerSize: size
            )
            if let captureProtectedInfoView = captureProtectedInfo.view {
                if captureProtectedInfoView.superview == nil {
                    self.insertSubview(captureProtectedInfoView, at: 0)
                }
                captureProtectedInfoTransition.setFrame(view: captureProtectedInfoView, frame: CGRect(origin: CGPoint(x: floor((size.width - captureProtectedInfoSize.width) * 0.5), y: floor((size.height - captureProtectedInfoSize.height) * 0.5)), size: captureProtectedInfoSize))
                captureProtectedInfoView.isHidden = false
            }
        } else if let captureProtectedInfo = self.captureProtectedInfo {
            self.captureProtectedInfo = nil
            captureProtectedInfo.view?.removeFromSuperview()
        }
    }
}

final class CaptureProtectedInfoComponent: Component {
    let strings: PresentationStrings
    
    init(strings: PresentationStrings) {
        self.strings = strings
    }
    
    static func ==(lhs: CaptureProtectedInfoComponent, rhs: CaptureProtectedInfoComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let icon = ComponentView<Empty>()
        let title = ComponentView<Empty>()
        let text = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: CaptureProtectedInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: "Stories/ScreenshotsOffIcon",
                    tintColor: .white,
                    maxSize: nil
                )),
                environment: {},
                containerSize: availableSize
            )
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.Story_ScreenshotBlockedTitle, font: Font.semibold(20.0), textColor: .white)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: availableSize
            )
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.Story_ScreenshotBlockedText, font: Font.regular(17.0), textColor: UIColor(white: 1.0, alpha: 0.6))),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: min(320.0, availableSize.width - 16.0), height: availableSize.height)
            )
            
            var contentWidth: CGFloat = 0.0
            contentWidth = max(contentWidth, iconSize.width)
            contentWidth = max(contentWidth, titleSize.width)
            contentWidth = max(contentWidth, textSize.width)
            
            var contentHeight: CGFloat = 0.0
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: CGRect(origin: CGPoint(x: floor((contentWidth - iconSize.width) * 0.5), y: contentHeight), size: iconSize))
            }
            contentHeight += iconSize.height + 11.0
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((contentWidth - titleSize.width) * 0.5), y: contentHeight), size: titleSize))
            }
            contentHeight += titleSize.height + 16.0
            
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: floor((contentWidth - textSize.width) * 0.5), y: contentHeight), size: textSize))
            }
            contentHeight += textSize.height
            
            return CGSize(width: contentWidth, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
