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
import LottieAnimationComponent
import ContextUI
import ViewControllerComponent
import BundleIconComponent

final class NavigationBackButtonComponent: Component {
    let text: String
    let color: UIColor
    
    init(text: String, color: UIColor) {
        self.text = text
        self.color = color
    }
    
    static func ==(lhs: NavigationBackButtonComponent, rhs: NavigationBackButtonComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return false
    }
    
    public final class View: UIView {
        private let arrowView: UIImageView
        private let textView: ComponentHostView<Empty>
        
        private var component: NavigationBackButtonComponent?
        
        override init(frame: CGRect) {
            self.arrowView = UIImageView()
            self.textView = ComponentHostView<Empty>()
            
            super.init(frame: frame)
            
            self.addSubview(self.arrowView)
            self.addSubview(self.textView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: NavigationBackButtonComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let spacing: CGFloat = 6.0
            let innerArrowInset: CGFloat = -8.0
            
            if self.component?.color != component.color {
                self.arrowView.image = NavigationBarTheme.generateBackArrowImage(color: component.color)
            }
            
            self.component = component
            
            let textSize = self.textView.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.text,
                    font: Font.regular(17.0),
                    color: component.color
                )),
                environment: {},
                containerSize: availableSize
            )
            
            var leftInset: CGFloat = 0.0
            var size = textSize
            if let arrowImage = self.arrowView.image {
                size.width += innerArrowInset + arrowImage.size.width + spacing
                size.height = max(size.height, arrowImage.size.height)
                
                self.arrowView.frame = CGRect(origin: CGPoint(x: innerArrowInset, y: floor((size.height - arrowImage.size.height) / 2.0)), size: arrowImage.size)
                leftInset += innerArrowInset + arrowImage.size.width + spacing
            }
            self.textView.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((size.height - textSize.height) / 2.0)), size: textSize)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class NavigationBarComponent: CombinedComponent {
    let topInset: CGFloat
    let sideInset: CGFloat
    let leftItem: AnyComponent<Empty>?
    let rightItems: [AnyComponentWithIdentity<Empty>]
    let centerItem: AnyComponent<Empty>?
    
    init(
        topInset: CGFloat,
        sideInset: CGFloat,
        leftItem: AnyComponent<Empty>?,
        rightItems: [AnyComponentWithIdentity<Empty>],
        centerItem: AnyComponent<Empty>?
    ) {
        self.topInset = topInset
        self.sideInset = sideInset
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
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
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
                    .position(CGPoint(x: sideInset + leftItem.size.width / 2.0, y: context.component.topInset + contentHeight / 2.0))
                )
                centerLeftInset += leftItem.size.width + 4.0
            }
            
            var centerRightInset = sideInset
            var rightItemX = context.availableSize.width - sideInset
            for item in rightItemList.reversed() {
                context.add(item
                    .position(CGPoint(x: rightItemX - item.size.width / 2.0, y: context.component.topInset + contentHeight / 2.0))
                )
                rightItemX -= item.size.width + 8.0
                centerRightInset += item.size.width + 8.0
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            if let centerItem = centerItem {
                context.add(centerItem
                    .position(CGPoint(x: maxCenterInset + (context.availableSize.width - maxCenterInset - maxCenterInset) / 2.0, y: context.component.topInset + contentHeight / 2.0))
                )
            }
            
            return size
        }
    }
}

private final class OriginInfoComponent: CombinedComponent {
    let title: String
    let subtitle: String
    
    init(
        title: String,
        subtitle: String
    ) {
        self.title = title
        self.subtitle = subtitle
    }
    
    static func ==(lhs: OriginInfoComponent, rhs: OriginInfoComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        
        return true
    }
    
    static var body: Body {
        let title = Child(Text.self)
        let subtitle = Child(Text.self)
        
        return { context in
            let spacing: CGFloat = 0.0
            
            let title = title.update(
                component: Text(
                    text: context.component.title, font: Font.semibold(17.0), color: .white),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let subtitle = subtitle.update(
                component: Text(
                    text: context.component.subtitle, font: Font.regular(14.0), color: .white),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            var size = CGSize(width: max(title.size.width, subtitle.size.width), height: title.size.height + spacing + subtitle.size.height)
            size.width = min(size.width, context.availableSize.width)
            size.height = min(size.height, context.availableSize.height)
            
            context.add(title
                .position(CGPoint(x: size.width / 2.0, y: title.size.height / 2.0))
            )
            context.add(subtitle
                .position(CGPoint(x: size.width / 2.0, y: title.size.height + spacing + subtitle.size.height / 2.0))
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
            
            let centerItem = context.component.centerItem.flatMap { centerItemComponent in
                return centerItem.update(
                    component: centerItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
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
                    .position(CGPoint(x: maxCenterInset + (context.availableSize.width - maxCenterInset - maxCenterInset) / 2.0, y: contentHeight / 2.0))
                )
            }
            
            return size
        }
    }
}

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
        
        var storedIsLandscape: Bool?
        
        private(set) var canManageCall: Bool = false
        let isPictureInPictureSupported: Bool
        
        private(set) var peerTitle: String = ""
        
        private(set) var isVisibleInHierarchy: Bool = false
        private var isVisibleInHierarchyDisposable: Disposable?
        
        private var scheduledDismissUITimer: SwiftSignalKit.Timer?
        
        init(call: PresentationGroupCallImpl) {
            self.call = call
            
            if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported() {
                self.isPictureInPictureSupported = true
            } else {
                self.isPictureInPictureSupported = false
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
            
            let peerId = call.peerId
            let callPeer = call.accountContext.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            
            self.infoDisposable = (combineLatest(queue: .mainQueue(), call.state, call.members, callPeer)
            |> deliverOnMainQueue).start(next: { [weak self] state, members, callPeer in
                guard let strongSelf = self, let members = members, let callPeer = callPeer else {
                    return
                }
                
                var updated = false
                if state.canManageCall != strongSelf.canManageCall {
                    strongSelf.canManageCall = state.canManageCall
                    updated = true
                }
                if strongSelf.peerTitle != callPeer.debugDisplayTitle {
                    strongSelf.peerTitle = callPeer.debugDisplayTitle
                    updated = true
                }
                
                let originInfo = OriginInfo(title: callPeer.debugDisplayTitle, memberCount: members.totalCount)
                if strongSelf.originInfo != originInfo {
                    strongSelf.originInfo = originInfo
                    updated = true
                }
                
                if updated {
                    strongSelf.updated(transition: .immediate)
                }
            })
            
            //let _ = call.accountContext.engine.calls.getGroupCallStreamCredentials(peerId: call.peerId, revokePreviousCredentials: false).start()
            
            self.isVisibleInHierarchyDisposable = (call.accountContext.sharedContext.applicationBindings.applicationInForeground
            |> deliverOnMainQueue).start(next: { [weak self] inForeground in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.isVisibleInHierarchy != inForeground {
                    strongSelf.isVisibleInHierarchy = inForeground
                    strongSelf.updated(transition: .immediate)
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
    
    public static var body: Body {
        let background = Child(Rectangle.self)
        let video = Child(MediaStreamVideoComponent.self)
        let navigationBar = Child(NavigationBarComponent.self)
        let toolbar = Child(ToolbarComponent.self)
        
        let activatePictureInPicture = StoredActionSlot(Action<Void>.self)
        let moreButtonTag = GenericComponentViewTag()
        let moreAnimationTag = GenericComponentViewTag()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            if environment.isVisible {
            } else {
                context.state.dismissOffset = 0.0
            }
            
            let background = background.update(
                component: Rectangle(color: .black),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let call = context.component.call
            let controller = environment.controller
            
            let video = video.update(
                component: MediaStreamVideoComponent(
                    call: context.component.call,
                    hasVideo: context.state.hasVideo,
                    isVisible: environment.isVisible && context.state.isVisibleInHierarchy,
                    isAdmin: context.state.canManageCall,
                    peerTitle: context.state.peerTitle,
                    activatePictureInPicture: activatePictureInPicture,
                    bringBackControllerForPictureInPictureDeactivation: { [weak call] completed in
                        guard let call = call else {
                            completed()
                            return
                        }
                        
                        call.accountContext.sharedContext.mainWindow?.inCallNavigate?()
                        
                        completed()
                    }
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            var navigationRightItems: [AnyComponentWithIdentity<Empty>] = []
            if context.state.isPictureInPictureSupported, context.state.hasVideo {
                navigationRightItems.append(AnyComponentWithIdentity(id: "pip", component: AnyComponent(Button(
                    content: AnyComponent(BundleIconComponent(
                        name: "Media Gallery/PictureInPictureButton",
                        tintColor: .white
                    )),
                    action: {
                        activatePictureInPicture.invoke(Action {
                            guard let controller = controller() as? MediaStreamComponentController else {
                                return
                            }
                            controller.dismiss(closing: false, manual: true)
                        })
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)))))
            }
            
            if context.state.canManageCall {
                let whiteColor = UIColor(white: 1.0, alpha: 1.0)
                navigationRightItems.append(AnyComponentWithIdentity(id: "more", component: AnyComponent(Button(
                    content: AnyComponent(ZStack([
                        AnyComponentWithIdentity(id: "b", component: AnyComponent(Circle(
                            color: .white,
                            size: CGSize(width: 22.0, height: 22.0),
                            width: 1.5
                        ))),
                        AnyComponentWithIdentity(id: "a", component: AnyComponent(LottieAnimationComponent(
                            animation: LottieAnimationComponent.Animation(
                                name: "anim_profilemore",
                                colors: [
                                    "Point 2.Group 1.Fill 1": whiteColor,
                                    "Point 3.Group 1.Fill 1": whiteColor,
                                    "Point 1.Group 1.Fill 1": whiteColor
                                ],
                                loop: false,
                                isAnimating: false
                            ),
                            size: CGSize(width: 22.0, height: 22.0)
                        ).tagged(moreAnimationTag))),
                    ])),
                    action: { [weak call] in
                        guard let call = call else {
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
                        items.append(.action(ContextMenuActionItem(id: nil, text: presentationData.strings.VoiceChat_StopRecordingStop, textColor: .primary, textLayout: .singleLine, textFont: .regular, badge: nil, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor, backgroundColor: nil)
                        }, action: { [weak call] _, a in
                            guard let call = call else {
                                return
                            }
                            
                            let _ = call.leave(terminateIfPossible: true).start()
                            
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
                ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(moreButtonTag))))
            }
            
            let navigationBar = navigationBar.update(
                component: NavigationBarComponent(
                    topInset: environment.statusBarHeight,
                    sideInset: environment.safeInsets.left,
                    leftItem: AnyComponent(Button(
                        content: AnyComponent(Text(text: environment.strings.Common_Close, font: Font.regular(17.0), color: .white)),
                        action: { [weak call] in
                            let _ = call?.leave(terminateIfPossible: false)
                        })
                    ),
                    rightItems: navigationRightItems,
                    centerItem: AnyComponent(Text(text: environment.strings.VoiceChatChannel_Title, font: Font.semibold(17.0), color: .white))
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            
            let isLandscape = context.availableSize.width > context.availableSize.height
            if context.state.storedIsLandscape != isLandscape {
                context.state.storedIsLandscape = isLandscape
                if isLandscape {
                    context.state.scheduleDismissUI()
                } else {
                    context.state.cancelScheduledDismissUI()
                }
            }
            
            var infoItem: AnyComponent<Empty>?
            if let originInfo = context.state.originInfo {
                let memberCountString: String
                if originInfo.memberCount == 0 {
                    memberCountString = environment.strings.LiveStream_NoViewers
                } else {
                    memberCountString = environment.strings.LiveStream_ViewerCount(Int32(originInfo.memberCount))
                }
                infoItem = AnyComponent(OriginInfoComponent(
                    title: originInfo.title,
                    subtitle: memberCountString
                ))
            }
            
            let toolbar = toolbar.update(
                component: ToolbarComponent(
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
                    ).minSize(CGSize(width: 44.0, height: 44.0))),
                    rightItem: AnyComponent(Button(
                        content: AnyComponent(BundleIconComponent(
                            name: isLandscape ? "Media Gallery/Minimize" : "Media Gallery/Fullscreen",
                            tintColor: .white
                        )),
                        action: {
                            if let controller = controller() as? MediaStreamComponentController {
                                controller.updateOrientation(orientation: isLandscape ? .portrait : .landscapeRight)
                            }
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0))),
                    centerItem: infoItem
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: context.transition
            )
            
            let state = context.state
            let height = context.availableSize.height
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                .gesture(.tap { [weak state] in
                    guard let state = state else {
                        return
                    }
                    state.toggleDisplayUI()
                })
                .gesture(.pan { [weak state] panState in
                    guard let state = state else {
                        return
                    }
                    switch panState {
                    case .began:
                        break
                    case let .updated(offset):
                        state.updateDismissOffset(value: offset.y, interactive: true)
                    case let .ended(velocity):
                        if abs(velocity.y) > 200.0 {
                            state.updateDismissOffset(value: velocity.y < 0 ? -height : height, interactive: false)
                            (controller() as? MediaStreamComponentController)?.dismiss(closing: false, manual: true)
                        } else {
                            state.updateDismissOffset(value: 0.0, interactive: false)
                        }
                    }
                })
            )
            
            context.add(video
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0 + context.state.dismissOffset))
            )
            
            context.add(navigationBar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: navigationBar.size.height / 2.0))
                .opacity(context.state.displayUI ? 1.0 : 0.0)
            )
            
            context.add(toolbar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - toolbar.size.height / 2.0))
                .opacity(context.state.displayUI ? 1.0 : 0.0)
            )
            
            return context.availableSize
        }
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
        
        self.view.layer.allowsGroupOpacity = true
        self.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.layer.allowsGroupOpacity = false
        })
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        DispatchQueue.main.async {
            self.onViewDidDisappear?()
        }
        
        if let initialOrientation = self.initialOrientation {
            self.initialOrientation = nil
            self.call.accountContext.sharedContext.applicationBindings.forceOrientation(initialOrientation)
        }
    }
    
    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss(completion: nil)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.view.layer.allowsGroupOpacity = true
        self.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak self] _ in
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
            
            let callPeerId = strongSelf.call.peerId
            let _ = (strongSelf.call.accountContext.account.postbox.transaction { transaction -> GroupCallInviteLinks? in
                if let inviteLinks = inviteLinks {
                    return inviteLinks
                } else if let peer = transaction.getPeer(callPeerId), let addressName = peer.addressName, !addressName.isEmpty {
                    return GroupCallInviteLinks(listenerLink: "https://t.me/\(addressName)?voicechat", speakerLink: nil)
                } else if let cachedData = transaction.getPeerCachedData(peerId: callPeerId) {
                    if let cachedData = cachedData as? CachedChannelData, let link = cachedData.exportedInvitation?.link {
                        return GroupCallInviteLinks(listenerLink: link, speakerLink: nil)
                    } else if let cachedData = cachedData as? CachedGroupData, let link = cachedData.exportedInvitation?.link {
                        return GroupCallInviteLinks(listenerLink: link, speakerLink: nil)
                    }
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
                        let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Peer] in
                            var peers: [Peer] = []
                            for peerId in peerIds {
                                if let peer = transaction.getPeer(peerId) {
                                    peers.append(peer)
                                }
                            }
                            return peers
                        } |> deliverOnMainQueue).start(next: { [weak self] peers in
                            if let strongSelf = self {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                
                                let text: String
                                var isSavedMessages = false
                                if peers.count == 1, let peer = peers.first {
                                    isSavedMessages = peer.id == strongSelf.context.account.peerId
                                    let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = presentationData.strings.VoiceChat_ForwardTooltip_Chat(peerName).string
                                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                    let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(firstPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(secondPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    text = presentationData.strings.VoiceChat_ForwardTooltip_TwoChats(firstPeerName, secondPeerName).string
                                } else if let peer = peers.first {
                                    let peerName = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
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
