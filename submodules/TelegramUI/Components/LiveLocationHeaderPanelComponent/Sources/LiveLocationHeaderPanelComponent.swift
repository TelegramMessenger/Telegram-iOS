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
import Postbox
import PresentationDataUtils

private func presentLiveLocationController(context: AccountContext, peerId: PeerId, controller: ViewController) {
    let presentImpl: (EngineMessage?) -> Void = { [weak controller] message in
        if let message = message, let strongController = controller {
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: false, navigationController: strongController.navigationController as? NavigationController, modal: true, dismissInput: {
                controller?.view.endEditing(true)
            }, present: { c, a, _ in
                controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, transitionNode: { _, _, _ in
                return nil
            }, addToTransitionSurface: { _ in
            }, openUrl: { _ in
            }, openPeer: { peer, navigation in
            }, callPeer: { _, _ in
            }, openConferenceCall: { _ in
            }, enqueueMessage: { message in
                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in
            }, chatAvatarHiddenMedia: { _, _ in
            }))
        }
    }
    if let id = context.liveLocationManager?.internalMessageForPeerId(peerId) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
        |> deliverOnMainQueue).start(next: presentImpl)
    } else if let liveLocationManager = context.liveLocationManager {
        let _ = (liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId)
        |> take(1)
        |> map { peersAndMessages -> EngineMessage? in
            return peersAndMessages?.first?.1
        } |> deliverOnMainQueue).start(next: presentImpl)
    }
}

public final class LiveLocationHeaderPanelComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let data: GlobalControlPanelsContext.LiveLocation
    public let controller: () -> ViewController?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        data: GlobalControlPanelsContext.LiveLocation,
        controller: @escaping () -> ViewController?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.data = data
        self.controller = controller
    }
    
    public static func ==(lhs: LiveLocationHeaderPanelComponent, rhs: LiveLocationHeaderPanelComponent) -> Bool {
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
        private var panel: LocationBroadcastNavigationAccessoryPanel?
        
        private var component: LiveLocationHeaderPanelComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: LiveLocationHeaderPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme

            self.component = component
            self.state = state
            
            let panel: LocationBroadcastNavigationAccessoryPanel
            if let current = self.panel {
                panel = current
            } else {
                panel = LocationBroadcastNavigationAccessoryPanel(
                    accountPeerId: component.context.account.peerId,
                    theme: component.theme,
                    strings: component.strings,
                    nameDisplayOrder: component.context.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder,
                    tapAction: { [weak self] in
                        guard let self, let component = self.component, let controller = component.controller() else {
                            return
                        }
                        switch component.data.mode {
                        case .all:
                            let messages = component.data.messages.values.sorted(by: { $0.index > $1.index })
                            
                            if messages.count == 1 {
                                presentLiveLocationController(context: component.context, peerId: messages[0].id.peerId, controller: controller)
                            } else {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                let actionSheet = ActionSheetController(presentationData: presentationData)
                                let dismissAction: () -> Void = { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                }
                                var items: [ActionSheetItem] = []
                                if !messages.isEmpty {
                                    items.append(ActionSheetTextItem(title: presentationData.strings.LiveLocation_MenuChatsCount(Int32(messages.count))))
                                    for message in messages {
                                        if let peer = message.peers[message.id.peerId] {
                                            var beginTimeAndTimeout: (Double, Double)?
                                            for media in message.media {
                                                if let media = media as? TelegramMediaMap, let timeout = media.liveBroadcastingTimeout {
                                                    beginTimeAndTimeout = (Double(message.timestamp), Double(timeout))
                                                }
                                            }
                                            
                                            if let beginTimeAndTimeout {
                                                items.append(LocationBroadcastActionSheetItem(context: component.context, peer: peer, title: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), beginTimestamp: beginTimeAndTimeout.0, timeout: beginTimeAndTimeout.1, strings: presentationData.strings, action: { [weak self] in
                                                    dismissAction()
                                                    
                                                    guard let self, let component = self.component, let controller = component.controller() else {
                                                        return
                                                    }
                                                    presentLiveLocationController(context: component.context, peerId: peer.id, controller: controller)
                                                }))
                                            }
                                        }
                                    }
                                    items.append(ActionSheetButtonItem(title: presentationData.strings.LiveLocation_MenuStopAll, color: .destructive, action: { [weak self] in
                                        dismissAction()
                                        
                                        guard let self, let component = self.component else {
                                            return
                                        }
                                        for peer in component.data.peers {
                                            component.context.liveLocationManager?.cancelLiveLocation(peerId: peer.id)
                                        }
                                    }))
                                }
                                actionSheet.setItemGroups([
                                    ActionSheetItemGroup(items: items),
                                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                                ])
                                self.window?.endEditing(true)
                                controller.present(actionSheet, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            }
                        case let .peer(peerId):
                            presentLiveLocationController(context: component.context, peerId: peerId, controller: controller)
                        }
                    },
                    close: { [weak self] in
                        guard let self, let component = self.component, let controller = component.controller() else {
                            return
                        }
                        var closePeers: [EnginePeer]?
                        var closePeerId: EnginePeer.Id?
                        switch component.data.mode {
                        case .all:
                            if component.data.peers.count > 1 {
                                closePeers = component.data.peers
                            } else {
                                closePeerId = component.data.peers.first?.id
                            }
                        case let .peer(peerId):
                            closePeerId = peerId
                        }
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        }
                        var items: [ActionSheetItem] = []
                        if let closePeers = closePeers, !closePeers.isEmpty {
                            items.append(ActionSheetTextItem(title: presentationData.strings.LiveLocation_MenuChatsCount(Int32(closePeers.count))))
                            for peer in closePeers {
                                items.append(ActionSheetButtonItem(title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), action: { [weak self] in
                                    dismissAction()
                                    
                                    guard let self, let component = self.component, let controller = component.controller() else {
                                        return
                                    }
                                    presentLiveLocationController(context: component.context, peerId: peer.id, controller: controller)
                                }))
                            }
                            items.append(ActionSheetButtonItem(title: presentationData.strings.LiveLocation_MenuStopAll, color: .destructive, action: { [weak self] in
                                dismissAction()
                                
                                guard let self, let component = self.component else {
                                    return
                                }
                                for peer in closePeers {
                                    component.context.liveLocationManager?.cancelLiveLocation(peerId: peer.id)
                                }
                            }))
                        } else if let closePeerId {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Map_StopLiveLocation, color: .destructive, action: { [weak self] in
                                dismissAction()
                                
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.context.liveLocationManager?.cancelLiveLocation(peerId: closePeerId)
                            }))
                        }
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                            ])
                        self.window?.endEditing(true)
                        controller.present(actionSheet, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                )
                self.panel = panel
                self.addSubview(panel.view)
            }
            
            let size = CGSize(width: availableSize.width, height: 40.0)
            let panelFrame = CGRect(origin: CGPoint(), size: size)
            transition.setFrame(view: panel.view, frame: panelFrame)
            panel.updateLayout(size: panelFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition.containedViewLayoutTransition)
            
            let mappedMode: LocationBroadcastNavigationAccessoryPanelMode
            switch component.data.mode {
            case .all:
                mappedMode = .summary
            case .peer:
                mappedMode = .peer
            }
            panel.update(peers: component.data.peers, mode: mappedMode, canClose: component.data.canClose)
            
            if themeUpdated {
                panel.updatePresentationData(PresentationData(
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
