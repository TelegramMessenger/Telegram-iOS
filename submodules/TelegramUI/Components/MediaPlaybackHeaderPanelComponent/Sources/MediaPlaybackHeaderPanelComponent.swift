import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import TelegramCore
import GlobalControlPanelsContext
import SwiftSignalKit
import UniversalMediaPlayer
import UndoUI
import OverlayStatusController
import TelegramUIPreferences
import Postbox
import PresentationDataUtils

public final class MediaPlaybackHeaderPanelComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let data: GlobalControlPanelsContext.MediaPlayback
    public let controller: () -> ViewController?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        data: GlobalControlPanelsContext.MediaPlayback,
        controller: @escaping () -> ViewController?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.data = data
        self.controller = controller
    }
    
    public static func ==(lhs: MediaPlaybackHeaderPanelComponent, rhs: MediaPlaybackHeaderPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.data != rhs.data {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var panel: MediaNavigationAccessoryPanel?
        
        private var component: MediaPlaybackHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        private var playlistPreloadDisposable: Disposable?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.playlistPreloadDisposable?.dispose()
        }
        
        func update(component: MediaPlaybackHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            
            self.component = component
            self.state = state
            
            let panel: MediaNavigationAccessoryPanel
            if let current = self.panel {
                panel = current
            } else {
                panel = MediaNavigationAccessoryPanel(context: component.context, presentationData: PresentationData(
                    strings: component.strings,
                    theme: component.theme,
                    autoNightModeTriggered: false,
                    chatWallpaper: .builtin(WallpaperSettings()),
                    chatFontSize: .regular,
                    chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: true),
                    listsFontSize: .regular,
                    dateTimeFormat: PresentationDateTimeFormat(),
                    nameDisplayOrder: .firstLast,
                    nameSortOrder: .firstLast,
                    reduceMotion: false,
                    largeEmoji: false
                ))
                self.panel = panel
                self.addSubview(panel.view)
                
                let delayedStatus = component.context.sharedContext.mediaManager.globalMediaPlayerState
                |> mapToSignal { value -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> in
                    guard let value = value else {
                        return .single(nil)
                    }
                    switch value.1 {
                    case .state:
                        return .single(value)
                    case .loading:
                        return .single(value) |> delay(0.1, queue: .mainQueue())
                    }
                }
                
                panel.containerNode.headerNode.playbackStatus = delayedStatus
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
                
                panel.containerNode.headerNode.displayScrubber = component.data.item.playbackData?.type != .instantVideo
                panel.getController = { [weak self] in
                    guard let self, let component = self.component else {
                        return nil
                    }
                    return component.controller()
                }
                panel.presentInGlobalOverlay = { [weak self] c in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.controller()?.presentInGlobalOverlay(c)
                }
                panel.close = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.context.sharedContext.mediaManager.setPlaylist(nil, type: component.data.kind, control: SharedMediaPlayerControlAction.playback(.pause))
                }
                panel.setRate = { [weak self] rate, changeType in
                    guard let self, let component = self.component else {
                        return
                    }
                    let _ = (component.context.sharedContext.accountManager.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings)?.get(MusicPlaybackSettings.self) ?? MusicPlaybackSettings.defaultSettings
                        
                        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { _ in
                            return PreferencesEntry(settings.withUpdatedVoicePlaybackRate(rate))
                        })
                        return rate
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] baseRate in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.context.sharedContext.mediaManager.playlistControl(.setBaseRate(baseRate), type: component.data.kind)
                        
                        var hasTooltip = false
                        component.controller()?.forEachController({ controller in
                            if let controller = controller as? UndoOverlayController {
                                hasTooltip = true
                                controller.dismissWithCommitAction()
                            }
                            return true
                        })
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let text: String?
                        let rate: CGFloat?
                        if case let .sliderCommit(previousValue, newValue) = changeType {
                            let value = String(format: "%0.1f", baseRate.doubleValue)
                            if baseRate == .x1 {
                                text = presentationData.strings.Conversation_AudioRateTooltipNormal
                            } else {
                                text = presentationData.strings.Conversation_AudioRateTooltipCustom(value).string
                            }
                            if newValue > previousValue {
                                rate = .infinity
                            } else if newValue < previousValue {
                                rate = -.infinity
                            } else {
                                rate = nil
                            }
                        } else if baseRate == .x1 {
                            text = presentationData.strings.Conversation_AudioRateTooltipNormal
                            rate = 1.0
                        } else if baseRate == .x1_5 {
                            text = presentationData.strings.Conversation_AudioRateTooltip15X
                            rate = 1.5
                        } else if baseRate == .x2 {
                            text = presentationData.strings.Conversation_AudioRateTooltipSpeedUp
                            rate = 2.0
                        } else {
                            text = nil
                            rate = nil
                        }
                        var showTooltip = true
                        if case .sliderChange = changeType {
                            showTooltip = false
                        }
                        if let rate, let text, showTooltip {
                            let controller = UndoOverlayController(
                                presentationData: presentationData,
                                content: .audioRate(
                                    rate: rate,
                                    text: text
                                ),
                                elevatedLayout: false,
                                animateInAsReplacement: hasTooltip,
                                action: { action in
                                    return true
                                }
                            )
                            //strongSelf.audioRateTooltipController = controller
                            component.controller()?.present(controller, in: .current)
                        }
                    })
                }
                panel.togglePlayPause = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: component.data.kind)
                }
                panel.playPrevious = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.context.sharedContext.mediaManager.playlistControl(.next, type: component.data.kind)
                }
                panel.playNext = { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.context.sharedContext.mediaManager.playlistControl(.previous, type: component.data.kind)
                }
                panel.tapAction = { [weak self] in
                    guard let self, let component = self.component, let controller = component.controller(), let navigationController = controller.navigationController as? NavigationController else {
                        return
                    }
                    
                    if let id = component.data.item.id as? PeerMessagesMediaPlaylistItemId, let playlistLocation = component.data.playlistLocation as? PeerMessagesPlaylistLocation {
                        if case .music = component.data.kind {
                            switch playlistLocation {
                            case .custom, .savedMusic:
                                let controllerContext: AccountContext
                                if component.data.account.id == component.context.account.id {
                                    controllerContext = component.context
                                } else {
                                    controllerContext = component.context.sharedContext.makeTempAccountContext(account: component.data.account)
                                }
                                let playerController = component.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, chatLocation: .peer(id: id.messageId.peerId), type: component.data.kind, initialMessageId: id.messageId, initialOrder: component.data.playbackOrder, playlistLocation: playlistLocation, parentNavigationController: navigationController)
                                self.window?.endEditing(true)
                                controller.present(playerController, in: .window(.root))
                            case let .messages(chatLocation, _, _):
                                let signal = component.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: .id(id.messageId)), count: 60, highlight: true, setupReply: false), id: 0), context: component.context, chatLocation: chatLocation, subject: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), tag: .tag(MessageTags.music))
                                
                                var cancelImpl: (() -> Void)?
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                        cancelImpl?()
                                    }))
                                    self?.component?.controller()?.present(controller, in: .window(.root))
                                    return ActionDisposable { [weak controller] in
                                        Queue.mainQueue().async() {
                                            controller?.dismiss()
                                        }
                                    }
                                }
                                |> runOn(Queue.mainQueue())
                                |> delay(0.15, queue: Queue.mainQueue())
                                let progressDisposable = MetaDisposable()
                                var progressStarted = false
                                self.playlistPreloadDisposable?.dispose()
                                self.playlistPreloadDisposable = (signal
                                |> afterDisposed {
                                    Queue.mainQueue().async {
                                        progressDisposable.dispose()
                                    }
                                }
                                |> deliverOnMainQueue).start(next: { [weak self] index in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if let _ = index.0 {
                                        let controllerContext: AccountContext
                                        if component.data.account.id == component.context.account.id {
                                            controllerContext = component.context
                                        } else {
                                            controllerContext = component.context.sharedContext.makeTempAccountContext(account: component.data.account)
                                        }
                                        let playerController = component.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, chatLocation: chatLocation, type: component.data.kind, initialMessageId: id.messageId, initialOrder: component.data.playbackOrder, playlistLocation: nil, parentNavigationController: navigationController)
                                        self.window?.endEditing(true)
                                        controller.present(playerController, in: .window(.root))
                                    } else if index.1 {
                                        if !progressStarted {
                                            progressStarted = true
                                            progressDisposable.set(progressSignal.start())
                                        }
                                    }
                                }, completed: {
                                })
                                cancelImpl = { [weak self] in
                                    self?.playlistPreloadDisposable?.dispose()
                                }
                            default:
                                break
                            }
                        } else {
                            component.context.sharedContext.navigateToChat(accountId: component.context.account.id, peerId: id.messageId.peerId, messageId: id.messageId)
                        }
                    }
                }
            }
            
            let size = CGSize(width: availableSize.width, height: 40.0)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: panel.view, frame: panelFrame)
            panel.updateLayout(size: panelFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition.containedViewLayoutTransition)
            
            switch component.data.playbackOrder {
            case .regular:
                panel.containerNode.headerNode.playbackItems = (component.data.item, component.data.previousItem, component.data.nextItem)
            case .reversed:
                panel.containerNode.headerNode.playbackItems = (component.data.item, component.data.nextItem, component.data.previousItem)
            case .random:
                panel.containerNode.headerNode.playbackItems = (component.data.item, nil, nil)
            }
            
            if themeUpdated {
                panel.containerNode.updatePresentationData(PresentationData(
                    strings: component.strings,
                    theme: component.theme,
                    autoNightModeTriggered: false,
                    chatWallpaper: .builtin(WallpaperSettings()),
                    chatFontSize: .regular,
                    chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: true),
                    listsFontSize: .regular,
                    dateTimeFormat: PresentationDateTimeFormat(),
                    nameDisplayOrder: .firstLast,
                    nameSortOrder: .firstLast,
                    reduceMotion: false,
                    largeEmoji: false
                ))
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
