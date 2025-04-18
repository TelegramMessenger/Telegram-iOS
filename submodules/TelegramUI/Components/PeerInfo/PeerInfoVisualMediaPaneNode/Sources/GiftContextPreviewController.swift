import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import GiftAnimationComponent

private final class GiftContextPreviewComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gift: ProfileGiftsContext.State.StarGift
    
    init(
        context: AccountContext,
        gift: ProfileGiftsContext.State.StarGift
    ) {
        self.context = context
        self.gift = gift
    }
    
    static func ==(lhs: GiftContextPreviewComponent, rhs: GiftContextPreviewComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let animation = ComponentView<Empty>()
        private let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private var component: GiftContextPreviewComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    
        func update(component: GiftContextPreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            self.component = component
            self.state = state
            
            let subject: GiftCompositionComponent.Subject
            switch component.gift.gift {
            case let .generic(gift):
                subject = .generic(gift.file)
            case let .unique(gift):
                subject = .unique(gift)
            }
            
            let animationSize = self.animation.update(
                transition: .immediate,
                component: AnyComponent(GiftCompositionComponent(
                    context: component.context,
                    theme: environment.theme,
                    subject: subject,
                    animationOffset: nil,
                    animationScale: nil,
                    displayAnimationStars: false,
                    externalState: self.giftCompositionExternalState,
                    requestUpdate: { [weak state] in
                        state?.updated()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.animation.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = CGRect(origin: .zero, size: animationSize)
            }
            
            if case let .unique(uniqueGift) = component.gift.gift {
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(
                        NSAttributedString(string: uniqueGift.title, font: Font.semibold(20.0), textColor: .white)
                    ))),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.title.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: availableSize.height - titleSize.height - 40.0), size: titleSize)
                }
                
                let vibrantColor: UIColor
                if let previewPatternColor = giftCompositionExternalState.previewPatternColor {
                    vibrantColor = previewPatternColor.withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
                } else {
                    vibrantColor = UIColor.white.withAlphaComponent(0.6)
                }
                let subtitleSize = self.subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(
                        NSAttributedString(string: "\(environment.strings.Gift_Unique_Collectible) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))", font: Font.regular(13.0), textColor: vibrantColor)
                    ))),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.subtitle.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - subtitleSize.width) / 2.0), y: availableSize.height - subtitleSize.height - 20.0), size: subtitleSize)
                }
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class GiftContextPreviewController: ViewController {
    fileprivate final class Node: ViewControllerTracingNode, ASGestureRecognizerDelegate {
        private weak var controller: GiftContextPreviewController?
    
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>

        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        init(controller: GiftContextPreviewController) {
            self.controller = controller
            self.presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
        
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            super.init()
            
            self.backgroundColor = .clear
        }
                
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
        }
         
        func requestLayout(transition: ComponentTransition) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, forceUpdate: true, transition: transition)
            }
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, animateOut: Bool = false, transition: ComponentTransition) {
            guard let controller = self.controller else {
                return
            }

            self.validLayout = layout

            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: 0.0,
                safeInsets: layout.safeInsets,
                additionalInsets: layout.additionalInsets,
                inputHeight: 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    GiftContextPreviewComponent(
                        context: controller.context,
                        gift: controller.gift
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: forceUpdate,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    componentView.clipsToBounds = true
                    self.view.addSubview(componentView)
                }
                let componentFrame = CGRect(origin: .zero, size: componentSize)
                transition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    fileprivate let context: AccountContext
    fileprivate let gift: ProfileGiftsContext.State.StarGift
    
    init(
        context: AccountContext,
        gift: ProfileGiftsContext.State.StarGift
    ) {
        self.context = context
        self.gift = gift
        
        super.init(navigationBarPresentationData: nil)
                
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
            
    override func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        let minSide = min(layout.size.width, layout.size.height)
        if case .unique = self.gift.gift {
            return CGSize(width: minSide, height: floor(minSide * 0.66))
        } else {
            return CGSize(width: minSide, height: 180.0)
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: ComponentTransition(transition))
    }
}

