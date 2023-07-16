import Foundation
import UIKit
import ComponentFlow
import Display
import AccountContext
import SwiftSignalKit
import AVKit
import TelegramCore
import Postbox
import ShareController
import UndoUI
import TelegramPresentationData
import PresentationDataUtils
import LottieAnimationComponent
import ContextUI
import ViewControllerComponent
import BundleIconComponent
import CreateExternalMediaStreamScreen
import HierarchyTrackingLayer
import UndoPanelComponent
import AvatarNode

public final class MediaStreamComponent: CombinedComponent {
    struct OriginInfo: Equatable {
        var title: String
        var memberCount: Int
    }
    
    public typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public let call: PresentationGroupCallImpl
    
    public init(call: PresentationGroupCallImpl) {
        self.call = call
    }
    
    public static func ==(lhs: MediaStreamComponent, rhs: MediaStreamComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        
        return true
    }
    
    public final class State: ComponentState {
        private let call: PresentationGroupCallImpl
        
        private(set) var hasVideo: Bool = false
        private var stateDisposable: Disposable?
        private var infoDisposable: Disposable?
        
        private(set) var originInfo: OriginInfo?
        
        private(set) var displayUI: Bool = true
        var dismissOffset: CGFloat = 0.0
        var initialOffset: CGFloat = 0.0
        var storedIsFullscreen: Bool?
        var isFullscreen: Bool = false
        var videoSize: CGSize?
        var prevFullscreenOrientation: UIDeviceOrientation?
        
        private(set) var canManageCall: Bool = false
        let isPictureInPictureSupported: Bool
        
        private(set) var callTitle: String?
        private(set) var recordingStartTimestamp: Int32?
        
        private(set) var peerTitle: String = ""
        private(set) var chatPeer: Peer?
        
        private(set) var isVisibleInHierarchy: Bool = false
        private var isVisibleInHierarchyDisposable: Disposable?
        
        private var scheduledDismissUITimer: SwiftSignalKit.Timer?
        var videoStalled: Bool = true
        
        var videoIsPlayable: Bool {
            !videoStalled && hasVideo
        }
//        var wantsPiP: Bool = false
        
        let deactivatePictureInPictureIfVisible = StoredActionSlot(Void.self)
        
        private let infoThrottler = Throttler<Int>.init(duration: 5, queue: .main)

        init(call: PresentationGroupCallImpl) {
            self.call = call
            
            if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported() {
                self.isPictureInPictureSupported = true
            } else {
                self.isPictureInPictureSupported = AVPictureInPictureController.isPictureInPictureSupported()
            }
            
            super.init()
            
            self.stateDisposable = (call.state
            |> map { state -> Bool in
                switch state.networkState {
                case .connected:
                    return true
                default:
                    return false
                }
            }
            |> filter { $0 }
            |> take(1)).start(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.hasVideo = true
                strongSelf.updated(transition: .immediate)
            })
            
            let callPeer = call.accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: call.peerId))
            
            self.infoDisposable = (combineLatest(queue: .mainQueue(), call.state, call.members, callPeer)
            |> deliverOnMainQueue).start(next: { [weak self] state, members, callPeer in
                guard let strongSelf = self, let members = members, let callPeer = callPeer else {
                    return
                }
                
                var updated = false
//                 TODO: remove debug timer
//                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                var shouldReplaceNoViewersWithOne: Bool { true }
                let membersCount = members.totalCount // Int.random(in: 0..<10000000) //
                strongSelf.infoThrottler.publish(shouldReplaceNoViewersWithOne ? max(membersCount, 1) : membersCount) { [weak strongSelf] latestCount in
                        let _ = members.totalCount
                        guard let strongSelf = strongSelf else { return }
                        var updated = false
                        let originInfo = OriginInfo(title: callPeer.debugDisplayTitle, memberCount: latestCount)
                        if strongSelf.originInfo != originInfo {
                            strongSelf.originInfo = originInfo
                            updated = true
                        }    
                        if updated {
                            strongSelf.updated(transition: .immediate)
                        }
                    }
//                }.fire()
                if state.canManageCall != strongSelf.canManageCall {
                    strongSelf.canManageCall = state.canManageCall
                    updated = true
                }
                if strongSelf.peerTitle != callPeer.debugDisplayTitle {
                    strongSelf.peerTitle = callPeer.debugDisplayTitle
                    updated = true
                }
                strongSelf.chatPeer = callPeer._asPeer()
                
                if strongSelf.callTitle != state.title {
                    strongSelf.callTitle = state.title
                    updated = true
                }
                
                if strongSelf.recordingStartTimestamp != state.recordingStartTimestamp {
                    strongSelf.recordingStartTimestamp = state.recordingStartTimestamp
                    updated = true
                }
                
                if updated {
                    strongSelf.updated(transition: .immediate)
                }
            })
            
            self.isVisibleInHierarchyDisposable = (call.accountContext.sharedContext.applicationBindings.applicationInForeground
            |> deliverOnMainQueue).start(next: { [weak self] inForeground in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.isVisibleInHierarchy != inForeground {
                    strongSelf.isVisibleInHierarchy = inForeground
                    strongSelf.updated(transition: .immediate)
                    
                    if inForeground {
                        Queue.mainQueue().after(0.5, {
                            guard let strongSelf = self, strongSelf.isVisibleInHierarchy else {
                                return
                            }
                            
                            strongSelf.deactivatePictureInPictureIfVisible.invoke(Void())
                        })
                    } else {
                        // MARK: TODO: fullscreen ui toggle
                    }
                }
            })
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.infoDisposable?.dispose()
            self.isVisibleInHierarchyDisposable?.dispose()
        }
        
        func toggleDisplayUI() {
            self.displayUI = !self.displayUI
            self.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .easeInOut)))
        }
        
        func cancelScheduledDismissUI() {
            self.scheduledDismissUITimer?.invalidate()
            self.scheduledDismissUITimer = nil
        }
        
        func scheduleDismissUI() {
            if self.scheduledDismissUITimer == nil {
                self.scheduledDismissUITimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.scheduledDismissUITimer = nil
                    if strongSelf.displayUI {
                        strongSelf.toggleDisplayUI()
                    }
                }, queue: .mainQueue())
                self.scheduledDismissUITimer?.start()
            }
        }
        
        func updateDismissOffset(value: CGFloat, interactive: Bool) {
            self.dismissOffset = value
            if interactive {
                self.updated(transition: .immediate)
            } else {
                self.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
            }
        }
    }
    
    public func makeState() -> State {
        return State(call: self.call)
    }
    
    class Local {
        let background = Child(Rectangle.self)
        let dismissTapComponent = Child(Rectangle.self)
        let video = Child(MediaStreamVideoComponent.self)
        let sheet = Child(StreamSheetComponent.self)
        let topItem = Child(environment: Empty.self)
        let fullscreenBottomItem = Child(environment: Empty.self)
        let buttonsRow = Child(environment: Empty.self)
        
        let activatePictureInPicture = StoredActionSlot(Action<Void>.self)
        let deactivatePictureInPicture = StoredActionSlot(Void.self)
        let moreButtonTag = GenericComponentViewTag()
        let moreAnimationTag = GenericComponentViewTag()
    }
    
    public static var body: Body {
        let local = Local()
        
        return { context in
            _body(context, local) // { context in
        }
    }
    
    private static func _body(_ context: CombinedComponentContext<MediaStreamComponent>, _ local: Local) -> CGSize {
        let background = local.background
        let dismissTapComponent = local.dismissTapComponent
        let video = local.video
        let sheet = local.sheet
        let topItem = local.topItem
        let fullscreenBottomItem = local.fullscreenBottomItem
        let buttonsRow = local.buttonsRow
        
        let activatePictureInPicture = local.activatePictureInPicture
        let deactivatePictureInPicture = local.deactivatePictureInPicture
        let moreButtonTag = local.moreButtonTag
        let moreAnimationTag = local.moreAnimationTag
        
        func makeBody() -> CGSize {
            let canEnforceOrientation = UIDevice.current.model != "iPad"
            var forceFullScreenInLandscape: Bool { canEnforceOrientation && true }
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            if environment.isVisible {
            } else {
                context.state.dismissOffset = 0.0
            }
            
            let background = background.update(
                component: Rectangle(color: .black.withAlphaComponent(0.0)),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let call = context.component.call
            let state = context.state
            let controller = environment.controller
            
            context.state.deactivatePictureInPictureIfVisible.connect {
                guard let controller = controller(), controller.view.window != nil else {
                    return
                }
                
                state.updated(transition: .easeInOut(duration: 3))
                deactivatePictureInPicture.invoke(Void())
            }
            let isFullscreen: Bool
            let isLandscape = context.availableSize.width > context.availableSize.height
            
            // Always fullscreen in landscape
            if forceFullScreenInLandscape && isLandscape && !state.isFullscreen {
                state.isFullscreen = true
                isFullscreen = true
            } else if !isLandscape && state.isFullscreen && canEnforceOrientation {
                state.prevFullscreenOrientation = nil
                state.isFullscreen = false
                isFullscreen = false
            } else {
                isFullscreen = state.isFullscreen
            }
            
            let videoInset: CGFloat
            if !isFullscreen {
                videoInset = 16.0
            } else {
                videoInset = 0.0
            }
            
            let videoHeight: CGFloat = forceFullScreenInLandscape
            ? (context.availableSize.width - videoInset * 2) / 16 * 9
            : context.state.videoSize?.height ?? (min(context.availableSize.width, context.availableSize.height) - videoInset * 2) / 16.0 * 9.0
            let bottomPadding = 32.0 + environment.safeInsets.bottom
            let requiredSheetHeight: CGFloat = isFullscreen
            ? context.availableSize.height
            : (44.0 + videoHeight + 40.0 + 69.0 + 16.0 + 32.0 + 70.0 + bottomPadding + 8.0)
            
            let safeAreaTopInView: CGFloat
            if #available(iOS 16.0, *) {
                safeAreaTopInView = context.view.window.flatMap { $0.convert(CGPoint(x: 0, y: $0.safeAreaInsets.top), to: context.view).y } ?? 0
            } else {
                safeAreaTopInView = context.view.safeAreaInsets.top
            }
            
            let isFullyDragged = context.availableSize.height - requiredSheetHeight + state.dismissOffset - safeAreaTopInView < 30.0
            
            var dragOffset = context.state.dismissOffset
            if isFullyDragged {
                dragOffset = max(context.state.dismissOffset, requiredSheetHeight - context.availableSize.height + safeAreaTopInView)
            }
            
            let dismissTapAreaHeight = isFullscreen ? 0 : (context.availableSize.height - requiredSheetHeight + dragOffset)
            let dismissTapComponent = dismissTapComponent.update(
                component: Rectangle(color: .red.withAlphaComponent(0)),
                availableSize: CGSize(width: context.availableSize.width, height: dismissTapAreaHeight),
                transition: context.transition
            )
            //            (controller() as? MediaStreamComponentController)?.prefersOnScreenNavigationHidden = isFullscreen
            //            (controller() as? MediaStreamComponentController)?.window?.invalidatePrefersOnScreenNavigationHidden()
            let video = video.update(
                component: MediaStreamVideoComponent(
                    call: context.component.call,
                    hasVideo: context.state.hasVideo,
                    isVisible: environment.isVisible && context.state.isVisibleInHierarchy,
                    isAdmin: context.state.canManageCall,
                    peerTitle: context.state.peerTitle,
                    isFullscreen: isFullscreen,
                    videoLoading: context.state.videoStalled,
                    callPeer: context.state.chatPeer,
                    activatePictureInPicture: activatePictureInPicture,
                    deactivatePictureInPicture: deactivatePictureInPicture,
                    bringBackControllerForPictureInPictureDeactivation: { [weak call] completed in
                        guard let call = call else {
                            completed()
                            return
                        }
                        
                        call.accountContext.sharedContext.mainWindow?.inCallNavigate?()
                        completed()
                    },
                    pictureInPictureClosed: { [weak call] in
                        let _ = call?.leave(terminateIfPossible: false)
                    },
                    onVideoSizeRetrieved: { [weak state] size in
                        state?.videoSize = size
                    },
                    onVideoPlaybackLiveChange: { [weak state] isLive in
                        guard let state else { return }
                        let wasLive = !state.videoStalled
                        if isLive != wasLive {
                            state.videoStalled = !isLive
                            state.updated()
                        }
                    }
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            var navigationRightItems: [AnyComponentWithIdentity<Empty>] = []
            
            //            let videoIsPlayable = context.state.videoIsPlayable
            //            if state.wantsPiP && state.hasVideo {
            //                state.wantsPiP = false
            //                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            //                    activatePictureInPicture.invoke(Action {
            //                        guard let controller = controller() as? MediaStreamComponentController else {
            //                            return
            //                        }
            //                        controller.dismiss(closing: false, manual: true)
            //                    })
            //                }
            //            }
            
            if context.state.isPictureInPictureSupported {
                navigationRightItems.append(AnyComponentWithIdentity(id: "pip", component: AnyComponent(Button(
                    content: AnyComponent(ZStack([
                        AnyComponentWithIdentity(id: "b", component: AnyComponent(Circle(
                            fillColor: .white.withAlphaComponent(0.08),
                            size: CGSize(width: 32.0, height: 32.0)
                        ))),
                        AnyComponentWithIdentity(id: "a", component: AnyComponent(BundleIconComponent(
                            name: "Call/pip",
                            tintColor: .white // .withAlphaComponent(context.state.videoIsPlayable ? 1.0 : 0.6)
                        )))
                    ]
                                                )),
                    action: { [weak state] in
                        guard let state, state.hasVideo else {
                            guard let controller = controller() as? MediaStreamComponentController else {
                                return
                            }
                            //                            state?.wantsPiP = true
                            controller.dismiss(closing: false, manual: true)
                            return
                        }
                        
                        activatePictureInPicture.invoke(Action {
                            guard let controller = controller() as? MediaStreamComponentController else {
                                return
                            }
                            controller.dismiss(closing: false, manual: true)
                            if state.displayUI {
                                state.toggleDisplayUI()
                            }
                        })
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)))))
            }
            var topLeftButton: AnyComponent<Empty>?
            
            if context.state.canManageCall {
                let whiteColor = UIColor(white: 1.0, alpha: 1.0)
                topLeftButton = AnyComponent(Button(
                    content: AnyComponent(ZStack([
                        AnyComponentWithIdentity(id: "b", component: AnyComponent(Circle(
                            fillColor: .white.withAlphaComponent(0.08),
                            size: CGSize(width: 32.0, height: 32.0)
                        ))),
                        AnyComponentWithIdentity(id: "a", component: AnyComponent(LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "anim_profilemore",
                                mode: .still(position: .begin)
                            ),
                            colors: [
                                "Point 2.Group 1.Fill 1": whiteColor,
                                "Point 3.Group 1.Fill 1": whiteColor,
                                "Point 1.Group 1.Fill 1": whiteColor
                            ],
                            size: CGSize(width: 32.0, height: 32.0)
                        ).tagged(moreAnimationTag))),
                    ])),
                    action: { [weak call, weak state] in
                        guard let call = call, let state = state else {
                            return
                        }
                        guard let controller = controller() as? MediaStreamComponentController else {
                            return
                        }
                        guard let anchorView = controller.node.hostView.findTaggedView(tag: moreButtonTag) else {
                            return
                        }
                        
                        if let animationView = controller.node.hostView.findTaggedView(tag: moreAnimationTag) as? LottieAnimationComponent.View {
                            animationView.playOnce()
                        }
                        
                        let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
                        
                        var items: [ContextMenuItem] = []
                        
                        items.append(.action(ContextMenuActionItem(id: nil, text: presentationData.strings.LiveStream_EditTitle, textColor: .primary, textLayout: .singleLine, textFont: .regular, badge: nil, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pencil"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak call, weak controller, weak state] _, dismissWithResult in
                            guard let call = call, let controller = controller, let state = state, let chatPeer = state.chatPeer else {
                                return
                            }
                            
                            let initialTitle = state.callTitle ?? ""
                            
                            let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
                            
                            let title: String = presentationData.strings.LiveStream_EditTitle
                            let text: String = presentationData.strings.LiveStream_EditTitleText
                            
                            let editController = voiceChatTitleEditController(sharedContext: call.accountContext.sharedContext, account: call.accountContext.account, forceTheme: defaultDarkPresentationTheme, title: title, text: text, placeholder: EnginePeer(chatPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), value: initialTitle, maxLength: 40, apply: { [weak call] title in
                                guard let call = call else {
                                    return
                                }
                                
                                let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
                                
                                if let title = title, title != initialTitle {
                                    call.updateTitle(title)
                                    
                                    let text: String = title.isEmpty ? presentationData.strings.LiveStream_EditTitleRemoveSuccess : presentationData.strings.LiveStream_EditTitleSuccess(title).string
                                    
                                    let _ = text
                                    //strongSelf.presentUndoOverlay(content: .voiceChatFlag(text: text), action: { _ in return false })
                                }
                            })
                            controller.present(editController, in: .window(.root))
                            
                            dismissWithResult(.default)
                        })))
                        
                        if let recordingStartTimestamp = state.recordingStartTimestamp {
                            items.append(.custom(VoiceChatRecordingContextItem(timestamp: recordingStartTimestamp, action: { [weak call, weak controller] _, dismissWithResult in

                                guard let call = call, let controller = controller else {
                                    return
                                }
                                
                                let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }

                                let alertController = textAlertController(context: call.accountContext, forceTheme: defaultDarkPresentationTheme, title: nil, text: presentationData.strings.VoiceChat_StopRecordingTitle, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.VoiceChat_StopRecordingStop, action: { [weak call, weak controller] in
                                    guard let call = call, let controller = controller else {
                                        return
                                    }
                                    call.setShouldBeRecording(false, title: nil, videoOrientation: nil)
                                    
                                    let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
                                    let text = presentationData.strings.LiveStream_RecordingSaved
                                    
                                    let _ = text
                                    let _ = controller
                                    
                                    /*strongSelf.presentUndoOverlay(content: .forward(savedMessages: true, text: text), action: { [weak self] value in
                                        if case .info = value, let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                            let context = strongSelf.context
                                            strongSelf.controller?.dismiss(completion: {
                                                Queue.mainQueue().justDispatch {
                                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(context.account.peerId), keepStack: .always, purposefulAction: {}, peekData: nil))
                                                }
                                            })
                                            
                                            return true
                                        }
                                        return false
                                    })*/
                                })])
                                controller.present(alertController, in: .window(.root))
                                
                                dismissWithResult(.dismissWithoutContent)
                            }), false))
                        } else {
                            let text = presentationData.strings.LiveStream_StartRecording
                            items.append(.action(ContextMenuActionItem(text: text, icon: { theme -> UIImage? in
                                return generateStartRecordingIcon(color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak call, weak state, weak controller] _, f in
                                f(.dismissWithoutContent)

                                guard let call = call, let state = state, let _ = state.chatPeer, let controller = controller else {
                                    return
                                }
                                
                                let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
                                
                                let title: String
                                let text: String
                                let placeholder: String = presentationData.strings.VoiceChat_RecordingTitlePlaceholderVideo
                                
                                title = presentationData.strings.LiveStream_StartRecordingTitle
                                text = presentationData.strings.LiveStream_StartRecordingTextVideo
                                
                                let editController = voiceChatTitleEditController(sharedContext: call.accountContext.sharedContext, account: call.accountContext.account, forceTheme: defaultDarkPresentationTheme, title: title, text: text, placeholder: placeholder, value: nil, maxLength: 40, apply: { [weak call, weak controller] title in
                                    guard let call = call, let controller = controller else {
                                        return
                                    }
                                    
                                    let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
                                    
                                    if let title = title {
                                        call.setShouldBeRecording(true, title: title, videoOrientation: false)

                                        let text = presentationData.strings.LiveStream_RecordingStarted
                                        let _ = text

                                        let _ = controller
                                        
                                        call.playTone(.recordingStarted)
                                    }
                                })
                                controller.present(editController, in: .window(.root))
                            })))
                        }
                        
                        let credentialsPromise = Promise<GroupCallStreamCredentials>()
                        credentialsPromise.set(call.accountContext.engine.calls.getGroupCallStreamCredentials(peerId: call.peerId, revokePreviousCredentials: false) |> `catch` { _ -> Signal<GroupCallStreamCredentials, NoError> in return .never() })
                        
                        items.append(.action(ContextMenuActionItem(id: nil, text: presentationData.strings.LiveStream_ViewCredentials, textColor: .primary, textLayout: .singleLine, textFont: .regular, badge: nil, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor, backgroundColor: nil)
                        }, action: { [weak call, weak controller] _, a in
                            guard let call = call, let controller = controller else {
                                return
                            }
                            
                            controller.push(CreateExternalMediaStreamScreen(context: call.accountContext, peerId: call.peerId, credentialsPromise: credentialsPromise, mode: .view))
                            
                            a(.default)
                        })))
                        
                        items.append(.action(ContextMenuActionItem(id: nil, text: presentationData.strings.LiveStream_StopLiveStream, textColor: .destructive, textLayout: .singleLine, textFont: .regular, badge: nil, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor, backgroundColor: nil)
                        }, action: { [weak call] _, a in
                            guard let call = call else {
                                return
                            }
                            let alertController = textAlertController(
                                context: call.accountContext,
                                forceTheme: defaultDarkPresentationTheme,
                                title: presentationData.strings.LiveStream_EndConfirmationTitle,
                                text: presentationData.strings.LiveStream_EndConfirmationText,
                                actions: [
                                    TextAlertAction(
                                        type: .genericAction,
                                        title: presentationData.strings.Common_Cancel,
                                        action: {}
                                    ),
                                    TextAlertAction(
                                        type: .destructiveAction,
                                        title: presentationData.strings.VoiceChat_EndConfirmationEnd,
                                        action: { [weak call] in
                                        guard let call = call else {
                                            return
                                        }
                                        let _ = call.leave(terminateIfPossible: true).start()
                                    })
                                ])
                            controller.present(alertController, in: .window(.root))
                            
                            a(.default)
                        })))
                        
                        final class ReferenceContentSource: ContextReferenceContentSource {
                            private let sourceView: UIView
                            
                            init(sourceView: UIView) {
                                self.sourceView = sourceView
                            }
                            
                            func transitionInfo() -> ContextControllerReferenceViewInfo? {
                                return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
                            }
                        }
                        
                        let contextController = ContextController(account: call.accountContext.account, presentationData: presentationData.withUpdated(theme: defaultDarkPresentationTheme), source: .reference(ReferenceContentSource(sourceView: anchorView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
                        /*contextController.passthroughTouchEvent = { sourceView, point in
                            guard let strongSelf = self else {
                                return .ignore
                            }

                            let localPoint = strongSelf.view.convert(sourceView.convert(point, to: nil), from: nil)
                            guard let localResult = strongSelf.hitTest(localPoint, with: nil) else {
                                return .dismiss(consume: true, result: nil)
                            }

                            var testView: UIView? = localResult
                            while true {
                                if let testViewValue = testView {
                                    if let node = testViewValue.asyncdisplaykit_node as? PeerInfoHeaderNavigationButton {
                                        node.isUserInteractionEnabled = false
                                        DispatchQueue.main.async {
                                            node.isUserInteractionEnabled = true
                                        }
                                        return .dismiss(consume: false, result: nil)
                                    } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoVisualMediaPaneNode {
                                        node.brieflyDisableTouchActions()
                                        return .dismiss(consume: false, result: nil)
                                    } else {
                                        testView = testViewValue.superview
                                    }
                                } else {
                                    break
                                }
                            }

                            return .dismiss(consume: true, result: nil)
                        }*/
                        controller.presentInGlobalOverlay(contextController)
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(moreButtonTag))
            }
            
            let navigationComponent = NavigationBarComponent(
                topInset: environment.statusBarHeight,
                sideInset: environment.safeInsets.left,
                backgroundVisible: isFullscreen,
                leftItem: topLeftButton,
                rightItems: navigationRightItems,
                centerItem: AnyComponent(StreamTitleComponent(text: state.callTitle ?? state.peerTitle, isRecording: state.recordingStartTimestamp != nil, isLive: context.state.videoIsPlayable))
            )
            
            if context.state.storedIsFullscreen != isFullscreen {
                context.state.storedIsFullscreen = isFullscreen
                if isFullscreen {
                    context.state.scheduleDismissUI()
                } else {
                    context.state.cancelScheduledDismissUI()
                }
            }
            
            var infoItem: AnyComponent<Empty>?
            if let originInfo = context.state.originInfo {
                infoItem = AnyComponent(OriginInfoComponent(
                    memberCount: originInfo.memberCount
                ))
            }
            let availableSize = context.availableSize
            let safeAreaTop = safeAreaTopInView
            
            let onPanGesture: ((Gesture.PanGestureState) -> Void) = { [weak state] panState in
                guard let state = state else {
                    return
                }
                switch panState {
                case .began:
                    state.initialOffset = state.dismissOffset
                case let .updated(offset):
                    state.updateDismissOffset(value: state.initialOffset + offset.y, interactive: true)
                case let .ended(velocity):
                    if velocity.y > 200.0 {
                        if state.isFullscreen {
                            state.isFullscreen = false
                            state.prevFullscreenOrientation = UIDevice.current.orientation
                            state.dismissOffset = 0.0
                            if canEnforceOrientation, let controller = controller() as? MediaStreamComponentController {
                                controller.updateOrientation(orientation: .portrait)
                            } else {
                                state.updated(transition: .easeInOut(duration: 0.25))
                            }
                        } else {
                            if isFullyDragged || state.initialOffset != 0 {
                                state.updateDismissOffset(value: 0.0, interactive: false)
                            } else {
                                if state.isPictureInPictureSupported {
                                    guard let controller = controller() as? MediaStreamComponentController else {
                                        return
                                    }
                                    if state.hasVideo {
                                        activatePictureInPicture.invoke(Action {
                                            controller.dismiss(closing: false, manual: true)
                                            if state.displayUI {
                                                state.toggleDisplayUI()
                                            }
                                        })
                                    } else {
                                        //                                        state.wantsPiP = true
                                        controller.dismiss(closing: false, manual: true)
                                    }
                                } else {
                                    guard let controller = controller() as? MediaStreamComponentController else {
                                        return
                                    }
                                    controller.dismiss(closing: false, manual: true)
                                }
                            }
                        }
                    } else {
                        if isFullyDragged {
                            state.updateDismissOffset(value: requiredSheetHeight - availableSize.height + safeAreaTop, interactive: false)
                        } else {
                            if velocity.y < -200 {
                                // Expand
                                state.updateDismissOffset(value: requiredSheetHeight - availableSize.height + safeAreaTop, interactive: false)
                            } else {
                                state.updateDismissOffset(value: 0.0, interactive: false)
                            }
                        }
                    }
                }
            }
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                .gesture(.tap { [weak state] in
                    guard let state = state, state.isFullscreen else {
                        return
                    }
                    state.toggleDisplayUI()
                })
                    .gesture(.pan { panState in
                        onPanGesture(panState)
                    })
            )
            
            context.add(dismissTapComponent
                .position(CGPoint(x: context.availableSize.width / 2, y: dismissTapAreaHeight / 2))
                .gesture(.tap {
                    guard let controller = controller() as? MediaStreamComponentController else {
                        return
                    }
                    controller.dismiss(closing: false, manual: true)
                })
                    .gesture(.pan(onPanGesture))
            )
            
            let presentationData = call.accountContext.sharedContext.currentPresentationData.with { $0 }
            
            let imageRenderScale = UIScreen.main.scale
            let bottomComponent = AnyComponent(ButtonsRowComponent(
                bottomInset: environment.safeInsets.bottom,
                sideInset: environment.safeInsets.left,
                leftItem: AnyComponent(Button(
                    content: AnyComponent(RoundGradientButtonComponent(
                        gradientColors: [UIColor(red: 0.165, green: 0.173, blue: 0.357, alpha: 1).cgColor],
                        image: generateTintedImage(image: UIImage(bundleImageName: "Call/CallShareButton"), color: .white),
                        // TODO: localize:
                        title: presentationData.strings.VoiceChat_ShareShort)),
                    action: {
                        guard let controller = controller() as? MediaStreamComponentController else {
                            return
                        }
                        controller.presentShare()
                    }
                ).minSize(CGSize(width: 65, height: 80))),
                rightItem: AnyComponent(Button(
                    content: AnyComponent(RoundGradientButtonComponent(
                        gradientColors: [
                            UIColor(red: 0.314, green: 0.161, blue: 0.197, alpha: 1).cgColor
                        ],
                        image: generateImage(CGSize(width: 44.0 * imageRenderScale, height: 44 * imageRenderScale), opaque: false, rotatedContext: { size, context in
                            context.translateBy(x: size.width / 2, y: size.height / 2)
                            context.scaleBy(x: 0.4, y: 0.4)
                            context.translateBy(x: -size.width / 2, y: -size.height / 2)
                            let imageColor = UIColor.white
                            let bounds = CGRect(origin: CGPoint(), size: size)
                            context.clear(bounds)
                            let lineWidth: CGFloat = size.width / 7
                            context.setLineWidth(lineWidth - UIScreenPixel)
                            context.setLineCap(.round)
                            context.setStrokeColor(imageColor.cgColor)
                            
                            context.move(to: CGPoint(x: lineWidth / 2 + UIScreenPixel, y: lineWidth / 2 + UIScreenPixel))
                            context.addLine(to: CGPoint(x: size.width - lineWidth / 2 - UIScreenPixel, y: size.height - lineWidth / 2 - UIScreenPixel))
                            context.strokePath()
                            
                            context.move(to: CGPoint(x: size.width - lineWidth / 2 - UIScreenPixel, y: lineWidth / 2 + UIScreenPixel))
                            context.addLine(to: CGPoint(x: lineWidth / 2 + UIScreenPixel, y: size.height - lineWidth / 2 - UIScreenPixel))
                            context.strokePath()
                        }),
                        title: presentationData.strings.VoiceChat_Leave
                    )),
                    action: { [weak call] in
                        let _ = call?.leave(terminateIfPossible: false)
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0))),
                centerItem: AnyComponent(Button(
                    content: AnyComponent(RoundGradientButtonComponent(
                        gradientColors: [
                            UIColor(red: 0.165, green: 0.173, blue: 0.357, alpha: 1).cgColor
                        ],
                        image: generateImage(CGSize(width: 44 * imageRenderScale, height: 44.0 * imageRenderScale), opaque: false, rotatedContext: { size, context in
                            
                            let imageColor = UIColor.white
                            let bounds = CGRect(origin: CGPoint(), size: size)
                            context.clear(bounds)
                            
                            context.setLineWidth(2.4 * imageRenderScale - UIScreenPixel)
                            context.setLineCap(.round)
                            context.setStrokeColor(imageColor.cgColor)
                            
                            let lineSide = size.width / 5
                            let centerOffset = size.width / 20
                            context.move(to: CGPoint(x: size.width / 2 + lineSide, y: size.height / 2 - centerOffset / 2))
                            context.addLine(to: CGPoint(x: size.width / 2 + lineSide, y: size.height / 2 - lineSide))
                            context.addLine(to: CGPoint(x: size.width / 2 + centerOffset / 2, y: size.height / 2 - lineSide))
                            context.move(to: CGPoint(x: size.width / 2 + lineSide, y: size.height / 2 - lineSide))
                            context.addLine(to: CGPoint(x: size.width / 2 + centerOffset, y: size.height / 2 - centerOffset))
                            context.strokePath()
                            
                            context.move(to: CGPoint(x: size.width / 2 - lineSide, y: size.height / 2 + centerOffset / 2))
                            context.addLine(to: CGPoint(x: size.width / 2 - lineSide, y: size.height / 2 + lineSide))
                            context.addLine(to: CGPoint(x: size.width / 2 - centerOffset / 2, y: size.height / 2 + lineSide))
                            context.move(to: CGPoint(x: size.width / 2 - lineSide, y: size.height / 2 + lineSide))
                            context.addLine(to: CGPoint(x: size.width / 2 - centerOffset, y: size.height / 2 + centerOffset))
                            context.strokePath()
                        }),
                        title: presentationData.strings.LiveStream_Expand
                    )),
                    action: { [weak state] in
                        guard let state = state else { return }
                        
                        if let controller = controller() as? MediaStreamComponentController {
                            state.isFullscreen.toggle()
                            if state.isFullscreen {
                                state.dismissOffset = 0.0
                                let currentOrientation = state.prevFullscreenOrientation ?? UIDevice.current.orientation
                                switch currentOrientation {
                                case .landscapeLeft:
                                    controller.updateOrientation(orientation: .landscapeRight)
                                case .landscapeRight:
                                    controller.updateOrientation(orientation: .landscapeLeft)
                                default:
                                    controller.updateOrientation(orientation: .landscapeRight)
                                }
                            } else {
                                state.prevFullscreenOrientation = UIDevice.current.orientation
                                controller.updateOrientation(orientation: .portrait)
                            }
                            if !canEnforceOrientation {
                                state.updated(transition: .easeInOut(duration: 0.25))
                            }
                        }
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)))
            ))
            
            let sheetHeight: CGFloat = max(requiredSheetHeight - dragOffset, requiredSheetHeight)
            let topOffset: CGFloat = isFullscreen
            ? max(context.state.dismissOffset, 0)
            : (context.availableSize.height - requiredSheetHeight + dragOffset)
            
            let sheet = sheet.update(
                component: StreamSheetComponent(
                    topOffset: topOffset,
                    sheetHeight: sheetHeight,
                    backgroundColor: (isFullscreen && !state.hasVideo) ? .clear : (isFullyDragged ? fullscreenBackgroundColor : panelBackgroundColor),
                    bottomPadding: bottomPadding,
                    participantsCount: context.state.originInfo?.memberCount ?? 0, // Int.random(in: 0...999998) // [0, 5, 15, 16, 95, 100, 16042, 942539].randomElement()!
                    isFullyExtended: isFullyDragged,
                    deviceCornerRadius: ((controller() as? MediaStreamComponentController)?.validLayout?.deviceMetrics.screenCornerRadius ?? 1) - 1,
                    videoHeight: videoHeight,
                    isFullscreen: isFullscreen,
                    fullscreenTopComponent: AnyComponent(navigationComponent),
                    fullscreenBottomComponent: bottomComponent
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(.init(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2))
            )
            
            var availableWidth: CGFloat { context.availableSize.width }
            var contentHeight: CGFloat { 44.0 }
            
            let topItem = topItem.update(
                component: AnyComponent(navigationComponent),
                availableSize: CGSize(width: availableWidth, height: contentHeight),
                transition: context.transition
            )
            
            let fullScreenToolbarComponent = AnyComponent(ToolbarComponent(
                bottomInset: environment.safeInsets.bottom,
                sideInset: environment.safeInsets.left,
                leftItem: AnyComponent(Button(
                    content: AnyComponent(BundleIconComponent(
                        name: "Chat/Input/Accessory Panels/MessageSelectionForward",
                        tintColor: .white
                    )),
                    action: {
                        guard let controller = controller() as? MediaStreamComponentController else {
                            return
                        }
                        controller.presentShare()
                    }
                ).minSize(CGSize(width: 64.0, height: 80))),
                rightItem: /*state.hasVideo ?*/ AnyComponent(Button(
                    content: AnyComponent(BundleIconComponent(
                        name: isFullscreen ? "Media Gallery/Minimize" : "Media Gallery/Fullscreen",
                        tintColor: .white
                    )),
                    action: {
                        state.isFullscreen = false
                        state.prevFullscreenOrientation = UIDevice.current.orientation
                        if let controller = controller() as? MediaStreamComponentController {
                            if canEnforceOrientation {
                                controller.updateOrientation(orientation: .portrait)
                            } else {
                                state.updated(transition: .easeInOut(duration: 0.25))
                            }
                        }
                    }
                ).minSize(CGSize(width: 64.0, height: 80.0))),
                centerItem: infoItem
            ))
            
            let buttonsRow = buttonsRow.update(
                component: bottomComponent,
                availableSize: CGSize(width: availableWidth, height: contentHeight),
                transition: context.transition
            )
            
            let fullscreenBottomItem = fullscreenBottomItem.update(
                component: fullScreenToolbarComponent,
                availableSize: CGSize(width: availableWidth, height: contentHeight),
                transition: context.transition
            )
            
            let videoPos: CGFloat
            
            if isFullscreen {
                videoPos = context.availableSize.height / 2 + dragOffset
            } else {
                videoPos = topOffset + 28.0 + 28.0 + videoHeight / 2
            }
            context.add(video
                .position(CGPoint(x: context.availableSize.width / 2.0, y: videoPos))
            )
            
            context.add(topItem
                .position(CGPoint(x: topItem.size.width / 2.0, y: topOffset + (isFullscreen ? topItem.size.height / 2.0 : 28.0)))
                .opacity((!isFullscreen || state.displayUI) ? 1.0 : 0.0)
                .gesture(.pan { panState in
                    onPanGesture(panState)
                })
            )
            
            context.add(buttonsRow
                .opacity(isFullscreen ? 0.0 : 1.0)
                .position(CGPoint(x: buttonsRow.size.width / 2, y: sheetHeight - 50.0 / 2 + topOffset - bottomPadding))
            )
            
            context.add(fullscreenBottomItem
                .opacity((isFullscreen && state.displayUI) ? 1.0 : 0.0)
                .position(CGPoint(x: fullscreenBottomItem.size.width / 2, y: context.availableSize.height - fullscreenBottomItem.size.height / 2 + topOffset - 0.0))
            )
            return context.availableSize
        }
        return makeBody()
    }
    
}

public final class MediaStreamComponentController: ViewControllerComponentContainer, VoiceChatController {
    private let context: AccountContext
    public let call: PresentationGroupCall
    public private(set) var currentOverlayController: VoiceChatOverlayController? = nil
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var initialOrientation: UIInterfaceOrientation?
    
    private let inviteLinksPromise = Promise<GroupCallInviteLinks?>(nil)
    
    public init(call: PresentationGroupCall) {
        self.context = call.accountContext
        self.call = call
        
        super.init(context: call.accountContext, component: MediaStreamComponent(call: call as! PresentationGroupCallImpl), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .White
        self.view.disablesInteractiveModalDismiss = true
        
        self.inviteLinksPromise.set(.single(nil)
        |> then(call.inviteLinks))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async {
            self.onViewDidAppear?()
        }
        
        if let view = self.node.hostView.findTaggedView(tag: MediaStreamVideoComponent.View.Tag()) as? MediaStreamVideoComponent.View {
            view.expandFromPictureInPicture()
        }
        
            self.view.clipsToBounds = true
            
            self.view.layer.animatePosition(from: CGPoint(x: self.view.frame.center.x, y: self.view.bounds.maxY + self.view.bounds.height / 2), to: self.view.center, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            })
        
        self.view.layer.allowsGroupOpacity = true
        
        self.backgroundDimView.layer.animateAlpha(from: 0, to: 1, duration: 0.3, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.layer.allowsGroupOpacity = false
        })
        if backgroundDimView.superview == nil {
            guard let superview = view.superview else { return }
            superview.insertSubview(backgroundDimView, belowSubview: view)
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        DispatchQueue.main.async {
            self.onViewDidDisappear?()
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        // TODO: replace with actual color
        backgroundDimView.backgroundColor = .black.withAlphaComponent(0.3)
        self.view.clipsToBounds = false
    }
    
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let dimViewSide: CGFloat = max(view.bounds.width, view.bounds.height)
        backgroundDimView.frame = .init(x: view.bounds.midX - dimViewSide / 2, y: -view.bounds.height * 3, width: dimViewSide, height: view.bounds.height * 4)
    }
    
    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss(completion: nil)
    }
    
    let backgroundDimView = UIView()
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.view.layer.allowsGroupOpacity = true
        
        self.backgroundDimView.layer.animateAlpha(from: 1.0, to: 0, duration: 0.3, removeOnCompletion: false)
        self.view.layer.animatePosition(from: self.view.center, to: CGPoint(x: self.view.center.x, y: self.view.bounds.maxY + self.view.bounds.height / 2), duration: 0.4, removeOnCompletion: false, completion: { [weak self] _ in
            guard let strongSelf = self else {
                completion?()
                return
            }
            strongSelf.view.layer.allowsGroupOpacity = false
            strongSelf.dismissImpl(completion: completion)
        })
    }
    
    private func dismissImpl(completion: (() -> Void)? = nil) {
        super.dismiss(completion: completion)
    }
    
    func updateOrientation(orientation: UIInterfaceOrientation) {
        if self.initialOrientation == nil {
            self.initialOrientation = orientation == .portrait ? .landscapeRight : .portrait
        } else if self.initialOrientation == orientation {
            self.initialOrientation = nil
        }
        self.call.accountContext.sharedContext.applicationBindings.forceOrientation(orientation)
    }
    
    func presentShare() {
        let _ = (self.inviteLinksPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] inviteLinks in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.call.peerId),
                TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: strongSelf.call.peerId)
            )
            |> map { peer, exportedInvitation -> GroupCallInviteLinks? in
                if let inviteLinks = inviteLinks {
                    return inviteLinks
                } else if let peer = peer, let addressName = peer.addressName, !addressName.isEmpty {
                    return GroupCallInviteLinks(listenerLink: "https://t.me/\(addressName)?voicechat", speakerLink: nil)
                } else if let link = exportedInvitation?.link {
                    return GroupCallInviteLinks(listenerLink: link, speakerLink: nil)
                }
                return nil
            }
            |> deliverOnMainQueue).start(next: { links in
                guard let strongSelf = self else {
                    return
                }
                
                if let links = links {
                    strongSelf.presentShare(links: links)
                }
            })
        })
    }
        
    func presentShare(links inviteLinks: GroupCallInviteLinks) {
        let formatSendTitle: (String) -> String = { string in
            var string = string
            if string.contains("[") && string.contains("]") {
                if let startIndex = string.firstIndex(of: "["), let endIndex = string.firstIndex(of: "]") {
                    string.removeSubrange(startIndex ... endIndex)
                }
            } else {
                string = string.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,."))
            }
            return string
        }
        let _ = formatSendTitle
        
        let _ = (combineLatest(queue: .mainQueue(), self.context.account.postbox.loadedPeerWithId(self.call.peerId), self.call.state |> take(1))
        |> deliverOnMainQueue).start(next: { [weak self] peer, callState in
            if let strongSelf = self {
                var inviteLinks = inviteLinks
                
                if let peer = peer as? TelegramChannel, case .group = peer.info, !peer.flags.contains(.isGigagroup), !(peer.addressName ?? "").isEmpty, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
                    let isMuted = defaultParticipantMuteState == .muted
                    
                    if !isMuted {
                        inviteLinks = GroupCallInviteLinks(listenerLink: inviteLinks.listenerLink, speakerLink: nil)
                    }
                }
                
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                
                var segmentedValues: [ShareControllerSegmentedValue]?
                segmentedValues = nil
                let shareController = ShareController(context: strongSelf.context, subject: .url(inviteLinks.listenerLink), segmentedValues: segmentedValues, forceTheme: defaultDarkPresentationTheme, forcedActionTitle: presentationData.strings.VoiceChat_CopyInviteLink)
                shareController.completed = { [weak self] peerIds in
                    if let strongSelf = self {
                        let _ = (strongSelf.context.engine.data.get(
                            EngineDataList(
                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                            )
                        )
                        |> deliverOnMainQueue).start(next: { [weak self] peerList in
                            if let strongSelf = self {
                                let peers = peerList.compactMap { $0 }
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                
                                let text: String
                                var isSavedMessages = false
                                if peers.count == 1, let peer = peers.first {
                                    isSavedMessages = peer.id == strongSelf.context.account.peerId
                                    let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = presentationData.strings.VoiceChat_ForwardTooltip_Chat(peerName).string
                                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                    let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = presentationData.strings.VoiceChat_ForwardTooltip_TwoChats(firstPeerName, secondPeerName).string
                                } else if let peer = peers.first {
                                    let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = presentationData.strings.VoiceChat_ForwardTooltip_ManyChats(peerName, "\(peers.count - 1)").string
                                } else {
                                    text = ""
                                }
                                
                                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: isSavedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                            }
                        })
                    }
                }
                shareController.actionCompleted = {
                    if let strongSelf = self {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.VoiceChat_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                }
                strongSelf.present(shareController, in: .window(.root))
            }
        })
    }
}

// MARK: - Subcomponents

private final class NavigationBarComponent: CombinedComponent {
    let topInset: CGFloat
    let sideInset: CGFloat
    let leftItem: AnyComponent<Empty>?
    let rightItems: [AnyComponentWithIdentity<Empty>]
    let centerItem: AnyComponent<Empty>?
    let backgroundVisible: Bool
    
    init(
        topInset: CGFloat,
        sideInset: CGFloat,
        backgroundVisible: Bool,
        leftItem: AnyComponent<Empty>?,
        rightItems: [AnyComponentWithIdentity<Empty>],
        centerItem: AnyComponent<Empty>?
    ) {
        self.topInset = 0 // topInset
        self.sideInset = sideInset
        self.backgroundVisible = backgroundVisible
        
        self.leftItem = leftItem
        self.rightItems = rightItems
        self.centerItem = centerItem
    }
    
    static func ==(lhs: NavigationBarComponent, rhs: NavigationBarComponent) -> Bool {
        if lhs.topInset != rhs.topInset {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.leftItem != rhs.leftItem {
            return false
        }
        if lhs.rightItems != rhs.rightItems {
            return false
        }
        if lhs.centerItem != rhs.centerItem {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let leftItem = Child(environment: Empty.self)
        let rightItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let centerItem = Child(environment: Empty.self)
        
        return { context in
            var availableWidth = context.availableSize.width
            let sideInset: CGFloat = 16.0 + context.component.sideInset
            
            let contentHeight: CGFloat = 44.0
            let size = CGSize(width: context.availableSize.width, height: context.component.topInset + contentHeight)
            
            let background = background.update(
                component: Rectangle(color: UIColor(white: 0.0, alpha: 0.5)),
                availableSize: CGSize(width: size.width, height: size.height),
                transition: context.transition
            )
            
            let leftItem = context.component.leftItem.flatMap { leftItemComponent in
                return leftItem.update(
                    component: leftItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            if let leftItem = leftItem {
                availableWidth -= leftItem.size.width
            }
            
            var rightItemList: [_UpdatedChildComponent] = []
            for item in context.component.rightItems {
                let item = rightItems[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
                rightItemList.append(item)
                availableWidth -= item.size.width
            }
            
            let centerItem = context.component.centerItem.flatMap { centerItemComponent in
                return centerItem.update(
                    component: centerItemComponent,
                    availableSize: CGSize(width: availableWidth - 44.0 - 44.0, height: contentHeight),
                    transition: context.transition
                )
            }
            if let centerItem = centerItem {
                availableWidth -= centerItem.size.width
            }
            
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
                .opacity(context.component.backgroundVisible ? 1 : 0)
            )
            
            var centerLeftInset = sideInset
            if let leftItem = leftItem {
                context.add(leftItem
                    .position(CGPoint(x: sideInset + leftItem.size.width / 2.0, y: context.component.topInset + contentHeight / 2.0))
                )
                centerLeftInset += leftItem.size.width + 4.0
            }
            
            var rightItemX = context.availableSize.width - sideInset
            for item in rightItemList.reversed() {
                context.add(item
                    .position(CGPoint(x: rightItemX - item.size.width / 2.0, y: context.component.topInset + contentHeight / 2.0))
                )
                rightItemX -= item.size.width + 8.0
            }
            
            let accumulatedOffset: CGFloat = 16.0
            if let centerItem = centerItem {
                context.add(centerItem
                    .position(CGPoint(x: context.availableSize.width / 2 - accumulatedOffset, y: context.component.topInset + contentHeight / 2.0))
                )
            }
            
            return size
        }
    }
}

private final class StreamTitleComponent: Component {
    private final class LiveIndicatorView: UIView {
        private let label = UILabel()
        private let stalledAnimatedGradient = CAGradientLayer()
        private var wasLive = false
        
        var desiredWidth: CGFloat { label.intrinsicContentSize.width + 6.0 + 6.0 }
        
        override init(frame: CGRect = .zero) {
            super.init(frame: frame)
            
            self.addSubview(label)
            
            let liveString = NSAttributedString(
                string: "LIVE",
                attributes: [
                    .font: Font.with(size: 11.0, design: .round, weight: .bold),
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.alignment = .center
                        return style
                    }(),
                    .foregroundColor: UIColor.white,
                    .kern: -0.6
                ]
            )
            self.label.attributedText = liveString
            
            self.layer.addSublayer(stalledAnimatedGradient)
            self.clipsToBounds = true
            self.toggle(isLive: false)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            label.frame = bounds
            stalledAnimatedGradient.frame = bounds
            self.layer.cornerRadius = min(bounds.width, bounds.height) / 2
        }
        
        func toggle(isLive: Bool) {
            if isLive {
                if !self.wasLive {
                    self.wasLive = true
                    let anim = CAKeyframeAnimation(keyPath: "transform.scale")
                    anim.values = [1.0, 1.12, 0.9, 1.0]
                    anim.keyTimes = [0, 0.5, 0.8, 1]
                    anim.duration = 0.4
                    self.layer.add(anim, forKey: "transform")
                    
                    UIView.animate(withDuration: 0.15, animations: {
                        self.toggle(isLive: true) })
                    return
                }
                self.backgroundColor = UIColor(red: 1, green: 0.176, blue: 0.333, alpha: 1)
                self.stalledAnimatedGradient.opacity = 0
                self.stalledAnimatedGradient.removeAllAnimations()
            } else {
                if wasLive {
                    wasLive = false
                    UIView.animate(withDuration: 0.3) {
                        self.toggle(isLive: false)
                    }
                    return
                }
                self.backgroundColor = UIColor(white: 0.36, alpha: 1)
                stalledAnimatedGradient.opacity = 1
            }
            wasLive = isLive
        }
    }
    
    private let text: String
    private let isRecording: Bool
    private let isLive: Bool
    
    init(text: String, isRecording: Bool, isLive: Bool) {
        self.text = text
        self.isRecording = isRecording
        self.isLive = isLive
    }
    
    static func ==(lhs: StreamTitleComponent, rhs: StreamTitleComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isRecording != rhs.isRecording {
            return false
        }
        if lhs.isLive != rhs.isLive {
            return false
        }
        return false
    }
    
    public final class View: UIView {
        private var indicatorView: UIImageView?
        private let liveIndicatorView = LiveIndicatorView()
        private let titleLabel = UILabel()
        private var titleFadeLayer = CALayer()
        
        private let trackingLayer: HierarchyTrackingLayer
        
        override init(frame: CGRect) {
            self.trackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.titleLabel)
            self.addSubview(self.liveIndicatorView)
            
            self.trackingLayer.didEnterHierarchy = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateIndicatorAnimation()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateIndicatorAnimation() {
            guard let indicatorView = self.indicatorView else {
                return
            }
            if indicatorView.layer.animation(forKey: "blink") == nil {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.55 as NSNumber]
                animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
                animation.duration = 0.7
                animation.autoreverses = true
                animation.repeatCount = Float.infinity
                indicatorView.layer.add(animation, forKey: "recording")
            }
        }
        
        func update(component: StreamTitleComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let liveIndicatorWidth: CGFloat = self.liveIndicatorView.desiredWidth
            let liveIndicatorHeight: CGFloat = 20.0
            
            let currentText = self.titleLabel.text
            if currentText != component.text {
                if currentText?.isEmpty == false {
                    UIView.transition(with: self.titleLabel, duration: 0.2) {
                        self.titleLabel.text = component.text
                        self.titleLabel.invalidateIntrinsicContentSize()
                    }
                } else {
                    self.titleLabel.text = component.text
                    self.titleLabel.invalidateIntrinsicContentSize()
                }
            }
            self.titleLabel.font = Font.semibold(17.0)
            self.titleLabel.textColor = .white
            self.titleLabel.numberOfLines = 1
            
            let textSize = CGSize(width: min(availableSize.width - 4 - liveIndicatorWidth, self.titleLabel.intrinsicContentSize.width), height: availableSize.height)
            
            if component.isRecording {
                if self.indicatorView == nil {
                    let indicatorView = UIImageView(image: generateFilledCircleImage(diameter: 8.0, color: .red, strokeColor: nil, strokeWidth: nil, backgroundColor: nil))
                    self.addSubview(indicatorView)
                    self.indicatorView = indicatorView
                    
                    self.updateIndicatorAnimation()
                }
            } else {
                if let indicatorView = self.indicatorView {
                    self.indicatorView = nil
                    indicatorView.removeFromSuperview()
                }
            }
            let sideInset: CGFloat = 20.0
            let size = CGSize(width: textSize.width + sideInset * 2.0, height: textSize.height)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - textSize.height) / 2.0)), size: textSize)
            
            if currentText?.isEmpty == false {
                UIView.transition(with: self.titleLabel, duration: 0.2, options: .transitionCrossDissolve) {
                    self.updateTitleFadeLayer(constrainedTextFrame: textFrame)
                }
            } else {
                self.updateTitleFadeLayer(constrainedTextFrame: textFrame)
            }
            
            liveIndicatorView.frame = CGRect(origin: CGPoint(x: textFrame.maxX + 6.0, y: textFrame.midY - liveIndicatorHeight / 2), size: .init(width: liveIndicatorWidth, height: liveIndicatorHeight))
            self.liveIndicatorView.toggle(isLive: component.isLive)
            
            if let indicatorView = self.indicatorView, let image = indicatorView.image {
                indicatorView.frame = CGRect(origin: CGPoint(x: liveIndicatorView.frame.maxX + 6.0, y: floorToScreenPixels((size.height - image.size.height) / 2.0) + 1.0), size: image.size)
            }
            
            return size
        }
        
        private func updateTitleFadeLayer(constrainedTextFrame: CGRect) {
            guard let textBounds = titleLabel.attributedText.flatMap({ $0.boundingRect(with: CGSize(width: .max, height: .max), context: nil) }),
                textBounds.width > constrainedTextFrame.width
            else {
                titleLabel.layer.mask = nil
                titleLabel.frame = constrainedTextFrame
                self.titleLabel.textAlignment = .center
                return
            }
                 
            var isRTL: Bool = false
            if let string = titleLabel.attributedText {
                let coreTextLine = CTLineCreateWithAttributedString(string)
                let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                if glyphRuns.count > 0 {
                    let run = glyphRuns[0] as! CTRun
                    if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                        isRTL = true
                    }
                }
            }
            
            let gradientInset: CGFloat = 0.0
            let gradientRadius: CGFloat = 50.0
            let extraSpaceToFitTruncation: CGFloat = 100.0
            
            let solidPartLayer = CALayer()
            solidPartLayer.backgroundColor = UIColor.black.cgColor
            
            let availableWidth: CGFloat = constrainedTextFrame.width - gradientRadius
            
            if isRTL {
                solidPartLayer.frame = CGRect(
                    origin: CGPoint(x: constrainedTextFrame.width + extraSpaceToFitTruncation - availableWidth, y: 0),
                    size: CGSize(width: availableWidth, height: constrainedTextFrame.height))
                
                self.titleLabel.textAlignment = .right
                
                titleLabel.frame = CGRect(x: constrainedTextFrame.minX - extraSpaceToFitTruncation, y: constrainedTextFrame.minY, width: constrainedTextFrame.width + extraSpaceToFitTruncation, height: constrainedTextFrame.height)
            } else {
                self.titleLabel.textAlignment = .left
                
                solidPartLayer.frame = CGRect(
                    origin: .zero,
                    size: CGSize(width: availableWidth, height: constrainedTextFrame.height))
                titleLabel.frame = CGRect(origin: constrainedTextFrame.origin, size: CGSize(width: constrainedTextFrame.width + extraSpaceToFitTruncation, height: constrainedTextFrame.height))
            }
            
            titleFadeLayer = CALayer()
            titleFadeLayer.addSublayer(solidPartLayer)
            
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [UIColor.red.cgColor, UIColor.clear.cgColor]
            if isRTL {
                gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
                gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)
                gradientLayer.frame = CGRect(x: solidPartLayer.frame.minX - gradientRadius, y: 0, width: gradientRadius, height: constrainedTextFrame.height)
            } else {
                gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
                gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
                gradientLayer.frame = CGRect(x: availableWidth + gradientInset, y: 0, width: gradientRadius, height: constrainedTextFrame.height)
            }
            titleFadeLayer.addSublayer(gradientLayer)
            titleFadeLayer.masksToBounds = false
            
            titleFadeLayer.frame = titleLabel.bounds
            
            titleLabel.layer.mask = titleFadeLayer
        }
        
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}


private final class OriginInfoComponent: CombinedComponent {
    let participantsCount: Int
    
    init(
        memberCount: Int
    ) {
        self.participantsCount = memberCount
    }
    
    static func ==(lhs: OriginInfoComponent, rhs: OriginInfoComponent) -> Bool {
        if lhs.participantsCount != rhs.participantsCount {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let viewerCounter = Child(ParticipantsComponent.self)
        
        return { context in
            let viewerCounter = viewerCounter.update(
                component: ParticipantsComponent(
                    count: context.component.participantsCount,
                    showsSubtitle: true,
                    fontSize: 18.0,
                    gradientColors: [UIColor.white.cgColor]
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            let heightReduction: CGFloat = 16.0
            var size = CGSize(width: viewerCounter.size.width, height: viewerCounter.size.height - heightReduction)
            size.width = min(size.width, context.availableSize.width)
            size.height = min(size.height, context.availableSize.height)
            
            context.add(viewerCounter
                .position(CGPoint(x: size.width / 2.0, y: context.availableSize.height / 2.0 + 16.0 - heightReduction / 2))
            )
            
            return size
        }
    }
}

private final class ToolbarComponent: CombinedComponent {
    let bottomInset: CGFloat
    let sideInset: CGFloat
    let leftItem: AnyComponent<Empty>?
    let rightItem: AnyComponent<Empty>?
    let centerItem: AnyComponent<Empty>?
    
    init(
        bottomInset: CGFloat,
        sideInset: CGFloat,
        leftItem: AnyComponent<Empty>?,
        rightItem: AnyComponent<Empty>?,
        centerItem: AnyComponent<Empty>?
    ) {
        self.bottomInset = bottomInset
        self.sideInset = sideInset
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.centerItem = centerItem
    }
    
    static func ==(lhs: ToolbarComponent, rhs: ToolbarComponent) -> Bool {
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.leftItem != rhs.leftItem {
            return false
        }
        if lhs.rightItem != rhs.rightItem {
            return false
        }
        if lhs.centerItem != rhs.centerItem {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let leftItem = Child(environment: Empty.self)
        let rightItem = Child(environment: Empty.self)
        let centerItem = Child(environment: Empty.self)
        
        return { context in
            var availableWidth = context.availableSize.width
            let sideInset: CGFloat = 16.0 + context.component.sideInset
            
            let contentHeight: CGFloat = 44.0
            let size = CGSize(width: context.availableSize.width, height: contentHeight + context.component.bottomInset)
            
            let background = background.update(component: Rectangle(color: UIColor(white: 0.0, alpha: 0.5)), availableSize: CGSize(width: size.width, height: size.height), transition: context.transition)
            
            let leftItem = context.component.leftItem.flatMap { leftItemComponent in
                return leftItem.update(
                    component: leftItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            if let leftItem = leftItem {
                availableWidth -= leftItem.size.width
            }
            
            let rightItem = context.component.rightItem.flatMap { rightItemComponent in
                return rightItem.update(
                    component: rightItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            if let rightItem = rightItem {
                availableWidth -= rightItem.size.width
            }
            
            let temporaryOffsetForSmallerSubtitle: CGFloat = 12
            let centerItem = context.component.centerItem.flatMap { centerItemComponent in
                return centerItem.update(
                    component: centerItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight - temporaryOffsetForSmallerSubtitle / 2),
                    transition: context.transition
                )
            }
            if let centerItem = centerItem {
                availableWidth -= centerItem.size.width
            }
            
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )
            
            var centerLeftInset = sideInset
            if let leftItem = leftItem {
                context.add(leftItem
                    .position(CGPoint(x: sideInset + leftItem.size.width / 2.0, y: contentHeight / 2.0))
                )
                centerLeftInset += leftItem.size.width + 4.0
            }
            
            var centerRightInset = sideInset
            if let rightItem = rightItem {
                context.add(rightItem
                    .position(CGPoint(x: context.availableSize.width - sideInset - rightItem.size.width / 2.0, y: contentHeight / 2.0))
                )
                centerRightInset += rightItem.size.width + 4.0
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            if let centerItem = centerItem {
                context.add(centerItem
                    .position(CGPoint(x: maxCenterInset + (context.availableSize.width - maxCenterInset - maxCenterInset) / 2.0, y: contentHeight / 2.0 - temporaryOffsetForSmallerSubtitle))
                )
            }
            
            return size
        }
    }
}

private final class ButtonsRowComponent: CombinedComponent {
    let bottomInset: CGFloat
    let sideInset: CGFloat
    let leftItem: AnyComponent<Empty>?
    let rightItem: AnyComponent<Empty>?
    let centerItem: AnyComponent<Empty>?
    
    init(
        bottomInset: CGFloat,
        sideInset: CGFloat,
        leftItem: AnyComponent<Empty>?,
        rightItem: AnyComponent<Empty>?,
        centerItem: AnyComponent<Empty>?
    ) {
        self.bottomInset = bottomInset
        self.sideInset = sideInset
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.centerItem = centerItem
    }
    
    static func ==(lhs: ButtonsRowComponent, rhs: ButtonsRowComponent) -> Bool {
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.leftItem != rhs.leftItem {
            return false
        }
        if lhs.rightItem != rhs.rightItem {
            return false
        }
        if lhs.centerItem != rhs.centerItem {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let leftItem = Child(environment: Empty.self)
        let rightItem = Child(environment: Empty.self)
        let centerItem = Child(environment: Empty.self)
        
        return { context in
            var availableWidth = context.availableSize.width
            let sideInset: CGFloat = 48.0 + context.component.sideInset
            
            let contentHeight: CGFloat = 80.0
            let size = CGSize(width: context.availableSize.width, height: contentHeight + context.component.bottomInset)
            
            let leftItem = context.component.leftItem.flatMap { leftItemComponent in
                return leftItem.update(
                    component: leftItemComponent,
                    availableSize: CGSize(width: 50.0, height: contentHeight),
                    transition: context.transition
                )
            }
            if let leftItem = leftItem {
                availableWidth -= leftItem.size.width
            }
            
            let rightItem = context.component.rightItem.flatMap { rightItemComponent in
                return rightItem.update(
                    component: rightItemComponent,
                    availableSize: CGSize(width: 50.0, height: contentHeight),
                    transition: context.transition
                )
            }
            if let rightItem = rightItem {
                availableWidth -= rightItem.size.width
            }
            
            let centerItem = context.component.centerItem.flatMap { centerItemComponent in
                return centerItem.update(
                    component: centerItemComponent,
                    availableSize: CGSize(width: 50.0, height: contentHeight),
                    transition: context.transition
                )
            }
            if let centerItem = centerItem {
                availableWidth -= centerItem.size.width
            }
            
            var centerLeftInset = sideInset
            if let leftItem = leftItem {
                context.add(leftItem
                    .position(CGPoint(x: sideInset + leftItem.size.width / 2.0, y: contentHeight / 2.0))
                )
                centerLeftInset += leftItem.size.width + 4.0
            }
            
            var centerRightInset = sideInset
            if let rightItem = rightItem {
                context.add(rightItem
                    .position(CGPoint(x: context.availableSize.width - sideInset - rightItem.size.width / 2.0, y: contentHeight / 2.0))
                )
                centerRightInset += rightItem.size.width + 4.0
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            if let centerItem = centerItem {
                context.add(centerItem
                    .position(CGPoint(x: maxCenterInset + (context.availableSize.width - maxCenterInset - maxCenterInset) / 2.0, y: contentHeight / 2.0))
                )
            }
            
            return size
        }
    }
}

final class RoundGradientButtonComponent: Component {
    init(gradientColors: [CGColor], icon: String? = nil, image: UIImage? = nil, title: String) {
        self.gradientColors = gradientColors
        self.icon = icon
        self.image = image
        self.title = title
    }
    
    static func == (lhs: RoundGradientButtonComponent, rhs: RoundGradientButtonComponent) -> Bool {
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.gradientColors != rhs.gradientColors {
            return false
        }
        return true
    }
    
    let gradientColors: [CGColor]
    let icon: String?
    let image: UIImage?
    let title: String
    
    final class View: UIView {
        let gradientLayer = CAGradientLayer()
        let iconView = UIImageView()
        let titleLabel = UILabel()
        
        override init(frame: CGRect = .zero) {
            super.init(frame: frame)
            
            gradientLayer.type = .radial
            gradientLayer.startPoint = .init(x: 1, y: 1)
            gradientLayer.endPoint = .init(x: 0, y: 0)
            
            self.layer.addSublayer(gradientLayer)
            self.addSubview(iconView)
            self.clipsToBounds = false
            
            self.addSubview(titleLabel)
            titleLabel.textAlignment = .center
            iconView.contentMode = .scaleAspectFit
            titleLabel.font = .systemFont(ofSize: 13)
            titleLabel.textColor = .white
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            titleLabel.invalidateIntrinsicContentSize()
            let heightForIcon = bounds.height - max(round(titleLabel.intrinsicContentSize.height), 12) - 8.0
            iconView.frame = .init(x: bounds.midX - heightForIcon / 2, y: 0, width: heightForIcon, height: heightForIcon)
            gradientLayer.masksToBounds = true
            gradientLayer.cornerRadius = min(iconView.frame.width, iconView.frame.height) / 2
            gradientLayer.frame = iconView.frame
            titleLabel.frame = .init(x: 0, y: bounds.height - titleLabel.intrinsicContentSize.height, width: bounds.width, height: titleLabel.intrinsicContentSize.height)
        }
    }
    
    func makeView() -> View {
        View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.iconView.image = image ?? icon.flatMap { UIImage(bundleImageName: $0) }
        let gradientColors: [CGColor]
        if self.gradientColors.count == 1 {
            gradientColors = [self.gradientColors[0], self.gradientColors[0]]
        } else {
            gradientColors = self.gradientColors
        }
        view.gradientLayer.colors = gradientColors
        view.titleLabel.text = title
        view.setNeedsLayout()
        return availableSize
    }
}

public final class Throttler<T: Hashable> {
    public var duration: TimeInterval = 0.25
    public var queue: DispatchQueue = .main
    public var isEnabled: Bool { duration > 0 }
    
    private var isThrottling: Bool = false
    private var lastValue: T?
    private var accumulator = Set<T>()
    private var lastCompletedValue: T?
    
    public init(duration: TimeInterval = 0.25, queue: DispatchQueue = .main) {
        self.duration = duration
        self.queue = queue
    }
    
    public func publish(_ value: T, includingLatest: Bool = false, using completion: ((T) -> Void)?) {
        queue.async { [self] in
            accumulator.insert(value)
            
            if !isThrottling {
                isThrottling = true
                lastValue = nil
                completion?(value)
                self.lastCompletedValue = value
            } else {
                lastValue = value
            }
            
            if lastValue == nil {
                queue.asyncAfter(deadline: .now() + duration) { [self] in
                    accumulator.removeAll()
                    // TODO: quick fix, replace with timer
                    queue.asyncAfter(deadline: .now() + duration) { [self] in
                        isThrottling = false
                    }
                    
                    guard
                        let lastValue = lastValue,
                        lastCompletedValue != lastValue || includingLatest
                    else { return }
                    
                    accumulator.insert(lastValue)
                    self.lastValue = nil
                    completion?(lastValue)
                    lastCompletedValue = lastValue
                }
            }
        }
    }
    
    public func cancelCurrent() {
        lastValue = nil
        isThrottling = false
        accumulator.removeAll()
    }
    
    public func canEmit(_ value: T) -> Bool {
        !accumulator.contains(value)
    }
}

public extension Throttler where T == Bool {
    func throttle(includingLatest: Bool = false, _ completion: ((T) -> Void)?) {
        publish(true, includingLatest: includingLatest, using: completion)
    }
}
