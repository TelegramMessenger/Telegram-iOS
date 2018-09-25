import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private func galleryMediaForMedia(media: Media) -> Media? {
    if let media = media as? TelegramMediaImage {
        return media
    } else if let file = media as? TelegramMediaFile {
        if file.mimeType.hasPrefix("audio/") {
            return nil
        } else if !file.isVideo && file.mimeType.hasPrefix("video/") {
            return file
        } else {
            return file
        }
    }
    return nil
}

private func mediaForMessage(message: Message) -> Media? {
    for media in message.media {
        if let result = galleryMediaForMedia(media: media) {
            return result
        } else if let webpage = media as? TelegramMediaWebpage {
            switch webpage.content {
            case let .Loaded(content):
                if let embedUrl = content.embedUrl, !embedUrl.isEmpty {
                    return webpage
                } else if let image = content.image {
                    if let result = galleryMediaForMedia(media: image) {
                        return result
                    }
                } else if let file = content.file {
                    if let result = galleryMediaForMedia(media: file) {
                        return result
                    }
                }
            case .Pending:
                break
            }
        }
    }
    return nil
}

private final class SecretMediaPreviewControllerNode: GalleryControllerNode {
    private var timeoutNode: RadialStatusNode?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var beginTimeAndTimeout: (Double, Double)? {
        didSet {
            if let (beginTime, timeout) = self.beginTimeAndTimeout {
                if self.timeoutNode == nil {
                    let timeoutNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
                    self.timeoutNode = timeoutNode
                    var iconImage: UIImage?
                    if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/SecretMediaIcon"), color: .white) {
                        let factor: CGFloat = 0.48
                        iconImage = generateImage(CGSize(width: floor(image.size.width * factor), height: floor(image.size.height * factor)), contextGenerator: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        })
                    }
                    timeoutNode.transitionToState(.secretTimeout(color: .white, icon: iconImage, beginTime: beginTime, timeout: timeout), completion: {})
                    self.addSubnode(timeoutNode)
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.layoutTimeoutNode(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                    }
                }
            } else if let timeoutNode = self.timeoutNode {
                self.timeoutNode = nil
                timeoutNode.removeFromSupernode()
            }
        }
    }
    
    override func animateIn(animateContent: Bool) {
        super.animateIn(animateContent: animateContent)
        
        self.timeoutNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateOut(animateContent: Bool, completion: @escaping () -> Void) {
        super.animateOut(animateContent: animateContent, completion: completion)
        
        if let timeoutNode = self.timeoutNode {
            timeoutNode.layer.animateAlpha(from: timeoutNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    override func updateDismissTransition(_ value: CGFloat) {
        self.timeoutNode?.alpha = value
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.validLayout = (layout, navigationBarHeight)
        self.layoutTimeoutNode(layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    private func layoutTimeoutNode(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        if let timeoutNode = self.timeoutNode {
            let diameter: CGFloat = 28.0
            transition.updateFrame(node: timeoutNode, frame: CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.right - diameter - 9.0, y: navigationBarHeight - 9.0 - diameter), size: CGSize(width: diameter, height: diameter)))
        }
    }
}

public final class SecretMediaPreviewController: ViewController {
    private let account: Account
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    private let markMessageAsConsumedDisposable = MetaDisposable()
    
    private var controllerNode: SecretMediaPreviewControllerNode {
        return self.displayNode as! SecretMediaPreviewControllerNode
    }
    
    private var messageView: MessageView?
    private var currentNodeMessageId: MessageId?
    
    private let _hiddenMedia = Promise<(MessageId, Media)?>(nil)
    private var hiddenMediaManagerIndex: Int?
    
    private let presentationData: PresentationData
    
    private var screenCaptureEventsDisposable: Disposable?
    
    public init(account: Account, messageId: MessageId) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        self.disposable.set((account.postbox.messageView(messageId) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                strongSelf.messageView = view
                if strongSelf.isViewLoaded {
                    strongSelf.applyMessageView()
                }
            }
        }))
        
        self.hiddenMediaManagerIndex = account.telegramApplicationContext.mediaManager.galleryHiddenMediaManager.addSource(self._hiddenMedia.get() |> map { messageIdAndMedia in
            if let (messageId, media) = messageIdAndMedia {
                return .chat(messageId, media)
            } else {
                return nil
            }
        })
        
        self.screenCaptureEventsDisposable = (screenCaptureEvents()
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            if let strongSelf = self, strongSelf.traceVisibility() {
                let _ = addSecretChatMessageScreenshot(account: account, peerId: messageId.peerId).start()
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.markMessageAsConsumedDisposable.dispose()
        if let hiddenMediaManagerIndex = self.hiddenMediaManagerIndex {
            self.account.telegramApplicationContext.mediaManager.galleryHiddenMediaManager.removeSource(hiddenMediaManagerIndex)
        }
        self.screenCaptureEventsDisposable?.dispose()
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    public override func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments)
            }
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] _, _ in
        })
        self.displayNode = SecretMediaPreviewControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.controllerNode.statusBar = self.statusBar
        self.controllerNode.navigationBar = self.navigationBar
        
        self.controllerNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.controllerNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? GalleryControllerPresentationArguments {
                    if let message = strongSelf.messageView?.message {
                        if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                            return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                        }
                    }
                }
            }
            return nil
        }
        self.controllerNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.controllerNode.beginCustomDismiss = { [weak self] in
            if let strongSelf = self {
                strongSelf._hiddenMedia.set(.single(nil))
                
                var animatedOutNode = true
                var animatedOutInterface = false
                
                let completion = {
                    if animatedOutNode && animatedOutInterface {
                        //self?.presentingViewController?.dismiss(animated: false, completion: nil)
                    }
                }
                
                strongSelf.controllerNode.animateOut(animateContent: animatedOutNode, completion: {
                    animatedOutInterface = true
                    //completion()
                })
            }
        }
        
        self.controllerNode.completeCustomDismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.controllerNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: (MessageId, Media)?
                if let _ = index {
                    if let message = strongSelf.messageView?.message, let media = mediaForMessage(message: message) {
                        var beginTimeAndTimeout: (Double, Double)?
                        for attribute in message.attributes {
                            if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                                if let countdownBeginTime = attribute.countdownBeginTime {
                                    beginTimeAndTimeout = (Double(countdownBeginTime), Double(attribute.timeout))
                                }
                                break
                            }
                        }
                        
                        if let _ = media as? TelegramMediaFile {
                            strongSelf.title = strongSelf.presentationData.strings.Message_Video
                        } else {
                            strongSelf.title = strongSelf.presentationData.strings.Message_Photo
                        }
                        
                        if let beginTimeAndTimeout = beginTimeAndTimeout {
                            strongSelf.controllerNode.beginTimeAndTimeout = beginTimeAndTimeout
                        }
                        
                        if !message.flags.contains(.Incoming) {
                            if let _ = beginTimeAndTimeout {
                                strongSelf.controllerNode.updatePresentationState({
                                    $0.withUpdatedFooterContentNode(nil)
                                }, transition: .immediate)
                            } else {
                                let contentNode = SecretMediaPreviewFooterContentNode()
                                let peerTitle = messageMainPeer(message)?.compactDisplayTitle ?? ""
                                let text: String
                                if let _ = media as? TelegramMediaFile {
                                    text = strongSelf.presentationData.strings.SecretVideo_NotViewedYet(peerTitle).0
                                } else {
                                    text = strongSelf.presentationData.strings.SecretImage_NotViewedYet(peerTitle).0
                                }
                               contentNode.setText(text)
                                strongSelf.controllerNode.updatePresentationState({
                                    $0.withUpdatedFooterContentNode(contentNode)
                                }, transition: .immediate)
                            }
                        }
                        hiddenItem = (message.id, media)
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        if let _ = self.messageView {
            self.applyMessageView()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.controllerNode.pager.centralItemNode(), let message = self.messageView?.message {
            
            if let media = mediaForMessage(message: message) {
                if let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments, let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                    nodeAnimatesItself = true
                    centralItemNode.activateAsInitial()
                    
                    if presentationArguments.animated {
                        centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface)
                    }
                    
                    self._hiddenMedia.set(.single((message.id, media)))
                } else if self.isPresentedInPreviewingContext() {
                    centralItemNode.activateAsInitial()
                }
            }
        }
        
        self.controllerNode.setControlsHidden(false, animated: false)
        if let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
            if presentationArguments.animated {
                self.controllerNode.animateIn(animateContent: !nodeAnimatesItself)
            }
        }
    }
    
    private func dismiss(forceAway: Bool) {
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.controllerNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments, let message = self.messageView?.message {
            if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media), !forceAway {
                animatedOutNode = false
                centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                    animatedOutNode = true
                    completion()
                })
            }
        }
        
        self.controllerNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    private func applyMessageView() {
        var message: Message?
        if let messageView = self.messageView, let m = messageView.message {
            message = m
            for media in m.media {
                if media is TelegramMediaExpiredContent {
                    message = nil
                    break
                }
            }
        }
        if let message = message {
            if self.currentNodeMessageId != message.id {
                self.currentNodeMessageId = message.id
                guard let item = galleryItemForEntry(account: account, presentationData: self.presentationData, entry: .MessageEntry(message, false, nil, nil), streamVideos: false, hideControls: true, playbackCompleted: { [weak self] in
                    self?.dismiss(forceAway: false)
                    }) else {
                    self._ready.set(.single(true))
                    return
                }
                
                self.controllerNode.pager.replaceItems([item], centralItemIndex: 0)
                let ready = self.controllerNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
                    self?.didSetReady = true
                }
                self._ready.set(ready |> map { true })
                self.markMessageAsConsumedDisposable.set(markMessageContentAsConsumedInteractively(postbox: self.account.postbox, messageId: message.id).start())
            } else {
                var beginTimeAndTimeout: (Double, Double)?
                for attribute in message.attributes {
                    if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                        if let countdownBeginTime = attribute.countdownBeginTime {
                            beginTimeAndTimeout = (Double(countdownBeginTime), Double(attribute.timeout))
                        }
                        break
                    }
                }
                
                if self.isNodeLoaded {
                    if let beginTimeAndTimeout = beginTimeAndTimeout {
                        self.controllerNode.beginTimeAndTimeout = beginTimeAndTimeout
                    }
                }
            }
        } else {
            if !self.didSetReady {
                self._ready.set(.single(true))
            }
            self.dismiss()
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.presentingViewController?.dismiss(animated: false, completion: completion)
    }
}
