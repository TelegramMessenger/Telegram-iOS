import Foundation
import UIKit
import ComponentFlow
import Display
import AccountContext
import SwiftSignalKit

private final class NavigationBarComponent: CombinedComponent {
    let leftItem: AnyComponent<Empty>?
    let rightItem: AnyComponent<Empty>?
    let centerItem: AnyComponent<Empty>?
    
    init(
        leftItem: AnyComponent<Empty>?,
        rightItem: AnyComponent<Empty>?,
        centerItem: AnyComponent<Empty>?
    ) {
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.centerItem = centerItem
    }
    
    static func ==(lhs: NavigationBarComponent, rhs: NavigationBarComponent) -> Bool {
        return true
    }
    
    static var body: Body {
        let leftItem = Child(environment: Empty.self)
        let rightItem = Child(environment: Empty.self)
        let centerItem = Child(environment: Empty.self)
        
        return { context in
            var availableWidth = context.availableSize.width
            let sideInset: CGFloat = 16.0
            
            let leftItem = context.component.leftItem.flatMap { leftItemComponent in
                return leftItem.update(
                    component: leftItemComponent,
                    availableSize: CGSize(width: availableWidth, height: context.availableSize.height),
                    transition: context.transition
                )
            }
            if let leftItem = leftItem {
                availableWidth -= leftItem.size.width
            }
            
            let rightItem = context.component.rightItem.flatMap { rightItemComponent in
                return rightItem.update(
                    component: rightItemComponent,
                    availableSize: CGSize(width: availableWidth, height: context.availableSize.height),
                    transition: context.transition
                )
            }
            if let rightItem = rightItem {
                availableWidth -= rightItem.size.width
            }
            
            let centerItem = context.component.centerItem.flatMap { centerItemComponent in
                return centerItem.update(
                    component: centerItemComponent,
                    availableSize: CGSize(width: availableWidth, height: context.availableSize.height),
                    transition: context.transition
                )
            }
            if let centerItem = centerItem {
                availableWidth -= centerItem.size.width
            }
            
            var centerLeftInset = sideInset
            if let leftItem = leftItem {
                context.add(leftItem
                    .position(CGPoint(x: sideInset + leftItem.size.width / 2.0, y: context.availableSize.height / 2.0))
                )
                centerLeftInset += leftItem.size.width + 4.0
            }
            
            var centerRightInset = sideInset
            if let rightItem = rightItem {
                context.add(rightItem
                    .position(CGPoint(x: context.availableSize.width - sideInset - rightItem.size.width / 2.0, y: context.availableSize.height / 2.0))
                )
                centerRightInset += rightItem.size.width + 4.0
            }
            
            let maxCenterInset = max(centerLeftInset, centerRightInset)
            if let centerItem = centerItem {
                context.add(centerItem
                    .position(CGPoint(x: maxCenterInset + (context.availableSize.width - maxCenterInset - maxCenterInset) / 2.0, y: context.availableSize.height / 2.0))
                )
            }
            
            return context.availableSize
        }
    }
}

public final class MediaStreamComponent: CombinedComponent {
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
        
        init(call: PresentationGroupCallImpl) {
            self.call = call
            
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
            
            let _ = call.accountContext.engine.calls.getGroupCallStreamCredentials(peerId: call.peerId, revokePreviousCredentials: false).start()
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
    }
    
    public func makeState() -> State {
        return State(call: self.call)
    }
    
    public static var body: Body {
        let background = Child(Rectangle.self)
        let video = Child(MediaStreamVideoComponent.self)
        let navigationBar = Child(NavigationBarComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let background = background.update(
                component: Rectangle(color: .black),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let video = Condition(context.state.hasVideo) {
                return video.update(
                    component: MediaStreamVideoComponent(
                        call: context.component.call
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: floor(context.availableSize.width * 9.0 / 16.0)),
                    transition: context.transition
                )
            }
            
            let call = context.component.call
            let navigationBar = navigationBar.update(
                component: NavigationBarComponent(
                    leftItem: AnyComponent(Button(
                        content: AnyComponent(Text(text: "Leave", font: Font.regular(17.0), color: .white)),
                        insets: UIEdgeInsets(),
                        action: { [weak call] in
                            let _ = call?.leave(terminateIfPossible: false)
                        })
                    ),
                    rightItem: nil,
                    centerItem: AnyComponent(Text(text: "Live Stream", font: Font.semibold(17.0), color: .white))
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 44.0),
                transition: context.transition
            )
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let video = video {
                context.add(video
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))
            }
            
            context.add(navigationBar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: environment.statusBarHeight + navigationBar.size.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class MediaStreamComponentController: ViewControllerComponentContainer, VoiceChatController {
    public let call: PresentationGroupCall
    public private(set) var currentOverlayController: VoiceChatOverlayController? = nil
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    public init(call: PresentationGroupCall) {
        self.call = call
        
        super.init(MediaStreamComponent(call: call as! PresentationGroupCallImpl))
        
        self.statusBar.statusBarStyle = .White
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async {
            self.onViewDidAppear?()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        DispatchQueue.main.async {
            self.onViewDidDisappear?()
        }
    }
    
    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss(animated: true, completion: nil)
    }
}
