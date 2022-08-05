import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AnimationCache
import MultiAnimationRenderer
import EntityKeyboard
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import PagerComponent

public final class EmojiStatusSelectionComponent: Component {
    public typealias EnvironmentType = Empty
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let deviceMetrics: DeviceMetrics
    public let emojiContent: EmojiPagerContentComponent
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        deviceMetrics: DeviceMetrics,
        emojiContent: EmojiPagerContentComponent
    ) {
        self.theme = theme
        self.strings = strings
        self.deviceMetrics = deviceMetrics
        self.emojiContent = emojiContent
    }
    
    public static func ==(lhs: EmojiStatusSelectionComponent, rhs: EmojiStatusSelectionComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.emojiContent != rhs.emojiContent {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let keyboardView: ComponentView<Empty>
        private let panelHostView: PagerExternalTopPanelContainer
        private let panelBackgroundView: BlurredBackgroundView
        private let panelSeparatorView: UIView
        
        private var component: EmojiStatusSelectionComponent?
        
        override init(frame: CGRect) {
            self.keyboardView = ComponentView<Empty>()
            self.panelHostView = PagerExternalTopPanelContainer()
            self.panelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.panelSeparatorView = UIView()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 24.0
            
            self.addSubview(self.panelBackgroundView)
            self.addSubview(self.panelSeparatorView)
            self.addSubview(self.panelHostView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EmojiStatusSelectionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            if self.component?.theme !== component.theme {
                self.backgroundColor = component.theme.list.plainBackgroundColor
                self.panelBackgroundView.updateColor(color: component.theme.list.plainBackgroundColor.withMultipliedAlpha(0.85), transition: .immediate)
                self.panelSeparatorView.backgroundColor = component.theme.list.itemPlainSeparatorColor.withMultipliedAlpha(0.5)
            }
            
            self.component = component
            
            let keyboardSize = self.keyboardView.update(
                transition: transition,
                component: AnyComponent(EntityKeyboardComponent(
                    theme: component.theme,
                    strings: component.strings,
                    containerInsets: UIEdgeInsets(top: 41.0 - 34.0, left: 0.0, bottom: 0.0, right: 0.0),
                    topPanelInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    emojiContent: component.emojiContent,
                    stickerContent: nil,
                    gifContent: nil,
                    hasRecentGifs: false,
                    availableGifSearchEmojies: [],
                    defaultToEmojiTab: true,
                    externalTopPanelContainer: self.panelHostView,
                    topPanelExtensionUpdated: { _, _ in },
                    hideInputUpdated: { _, _, _ in },
                    switchToTextInput: {},
                    switchToGifSubject: { _ in },
                    makeSearchContainerNode: { _ in return nil },
                    deviceMetrics: component.deviceMetrics,
                    hiddenInputHeight: 0.0,
                    displayBottomPanel: false,
                    isExpanded: false
                )),
                environment: {},
                containerSize: availableSize
            )
            if let keyboardComponentView = self.keyboardView.view {
                if keyboardComponentView.superview == nil {
                    self.insertSubview(keyboardComponentView, at: 0)
                }
                transition.setFrame(view: keyboardComponentView, frame: CGRect(origin: CGPoint(), size: keyboardSize))
                transition.setFrame(view: self.panelHostView, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0 - 34.0), size: CGSize(width: keyboardSize.width, height: 0.0)))
                
                transition.setFrame(view: self.panelBackgroundView, frame: CGRect(origin: CGPoint(), size: CGSize(width: keyboardSize.width, height: 41.0)))
                self.panelBackgroundView.update(size: self.panelBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
                
                transition.setFrame(view: self.panelSeparatorView, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0), size: CGSize(width: keyboardSize.width, height: UIScreenPixel)))
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class EmojiStatusSelectionController: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: EmojiStatusSelectionController?
        private let context: AccountContext
        private weak var sourceView: UIView?
        private var globalSourceRect: CGRect?
        
        private let componentHost: ComponentView<Empty>
        private let componentShadowLayer: SimpleLayer
        
        private let cloudLayer0: SimpleLayer
        private let cloudShadowLayer0: SimpleLayer
        private let cloudLayer1: SimpleLayer
        private let cloudShadowLayer1: SimpleLayer
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        private var emojiContentDisposable: Disposable?
        private var emojiContent: EmojiPagerContentComponent?
        
        private var isDismissed: Bool = false
        
        init(controller: EmojiStatusSelectionController, context: AccountContext, sourceView: UIView?, emojiContent: Signal<EmojiPagerContentComponent, NoError>) {
            self.controller = controller
            self.context = context
            
            if let sourceView = sourceView {
                self.globalSourceRect = sourceView.convert(sourceView.bounds, to: nil)
            }
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.componentHost = ComponentView<Empty>()
            self.componentShadowLayer = SimpleLayer()
            self.componentShadowLayer.shadowOpacity = 0.15
            self.componentShadowLayer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.componentShadowLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.componentShadowLayer.shadowRadius = 15.0
            
            self.cloudLayer0 = SimpleLayer()
            self.cloudShadowLayer0 = SimpleLayer()
            self.cloudShadowLayer0.shadowOpacity = 0.15
            self.cloudShadowLayer0.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.cloudShadowLayer0.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.cloudShadowLayer0.shadowRadius = 15.0
            
            self.cloudLayer1 = SimpleLayer()
            self.cloudShadowLayer1 = SimpleLayer()
            self.cloudShadowLayer1.shadowOpacity = 0.15
            self.cloudShadowLayer1.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
            self.cloudShadowLayer1.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.cloudShadowLayer1.shadowRadius = 15.0
            
            super.init()
            
            self.layer.addSublayer(self.componentShadowLayer)
            self.layer.addSublayer(self.cloudShadowLayer0)
            self.layer.addSublayer(self.cloudShadowLayer1)
            
            self.layer.addSublayer(self.cloudLayer0)
            self.layer.addSublayer(self.cloudLayer1)
            
            self.emojiContentDisposable = (emojiContent
            |> deliverOnMainQueue).start(next: { [weak self] emojiContent in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controller?._ready.set(.single(true))
                strongSelf.emojiContent = emojiContent
                
                emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
                    performItemAction: { _, item, _, _, _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.applyItem(item: item)
                    },
                    deleteBackwards: {
                    },
                    openStickerSettings: {
                    },
                    openFeatured: {
                    },
                    addGroupAction: { groupId, isPremiumLocked in
                        
                    },
                    clearGroup: { groupId in
                    },
                    pushController: { c in
                    },
                    presentController: { c in
                    },
                    presentGlobalOverlayController: { c in
                    },
                    navigationController: {
                        return nil
                    },
                    sendSticker: nil,
                    chatPeerId: nil
                )
                
                strongSelf.refreshLayout(transition: .immediate)
            })
        }
        
        deinit {
            self.emojiContentDisposable?.dispose()
        }
        
        private func refreshLayout(transition: Transition) {
            guard let layout = self.validLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: transition)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.componentShadowLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.componentHost.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion()
            })
            
            self.cloudLayer0.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.cloudShadowLayer0.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.cloudLayer1.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
            self.cloudShadowLayer1.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, transition: Transition) {
            self.validLayout = layout
            
            guard let emojiContent = self.emojiContent else {
                return
            }
            
            self.cloudLayer0.backgroundColor = self.presentationData.theme.list.plainBackgroundColor.cgColor
            self.cloudLayer1.backgroundColor = self.presentationData.theme.list.plainBackgroundColor.cgColor
            
            let sideInset: CGFloat = 16.0
            
            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(EmojiStatusSelectionComponent(
                    theme: self.presentationData.theme,
                    strings: self.presentationData.strings,
                    deviceMetrics: layout.deviceMetrics,
                    emojiContent: emojiContent
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width - sideInset * 2.0, height: min(300.0, layout.size.height))
            )
            if let componentView = self.componentHost.view {
                var animateIn = false
                if componentView.superview == nil {
                    self.view.addSubview(componentView)
                    animateIn = true
                }
                
                let sourceOrigin: CGPoint
                if let sourceView = self.sourceView {
                    let sourceRect = sourceView.convert(sourceView.bounds, to: self.view)
                    sourceOrigin = CGPoint(x: sourceRect.midX, y: sourceRect.maxY)
                } else if let globalSourceRect = self.globalSourceRect {
                    let sourceRect = self.view.convert(globalSourceRect, from: nil)
                    sourceOrigin = CGPoint(x: sourceRect.midX, y: sourceRect.maxY)
                } else {
                    sourceOrigin = CGPoint(x: layout.size.width / 2.0, y: floor(layout.size.height / 2.0 - componentSize.height))
                }
                
                let componentFrame = CGRect(origin: CGPoint(x: sideInset, y: sourceOrigin.y + 8.0), size: componentSize)
                
                if self.componentShadowLayer.bounds.size != componentFrame.size {
                    let componentShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: componentFrame.size), cornerRadius: 24.0).cgPath
                    self.componentShadowLayer.shadowPath = componentShadowPath
                }
                transition.setFrame(layer: self.componentShadowLayer, frame: componentFrame)
                
                let cloudOffset0: CGFloat = 30.0
                let cloudSize0: CGFloat = 16.0
                let cloudFrame0 = CGRect(origin: CGPoint(x: floor(sourceOrigin.x + cloudOffset0 - cloudSize0 / 2.0), y: componentFrame.minY - cloudSize0 / 2.0), size: CGSize(width: cloudSize0, height: cloudSize0))
                transition.setFrame(layer: self.cloudLayer0, frame: cloudFrame0)
                if self.cloudShadowLayer0.bounds.size != cloudFrame0.size {
                    let cloudShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: cloudFrame0.size), cornerRadius: 24.0).cgPath
                    self.cloudShadowLayer0.shadowPath = cloudShadowPath
                }
                transition.setFrame(layer: self.cloudShadowLayer0, frame: cloudFrame0)
                transition.setCornerRadius(layer: self.cloudLayer0, cornerRadius: cloudFrame0.width / 2.0)
                
                let cloudOffset1 = CGPoint(x: -9.0, y: -14.0)
                let cloudSize1: CGFloat = 8.0
                let cloudFrame1 = CGRect(origin: CGPoint(x: floor(cloudFrame0.midX + cloudOffset1.x - cloudSize1 / 2.0), y: floor(cloudFrame0.midY + cloudOffset1.y - cloudSize1 / 2.0)), size: CGSize(width: cloudSize1, height: cloudSize1))
                transition.setFrame(layer: self.cloudLayer1, frame: cloudFrame1)
                if self.cloudShadowLayer1.bounds.size != cloudFrame1.size {
                    let cloudShadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: cloudFrame1.size), cornerRadius: 24.0).cgPath
                    self.cloudShadowLayer1.shadowPath = cloudShadowPath
                }
                transition.setFrame(layer: self.cloudShadowLayer1, frame: cloudFrame1)
                transition.setCornerRadius(layer: self.cloudLayer1, cornerRadius: cloudFrame1.width / 2.0)
                
                transition.setFrame(view: componentView, frame: componentFrame)
                
                if animateIn {
                    self.allowsGroupOpacity = true
                    self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self] _ in
                        self?.allowsGroupOpacity = false
                    })
                    
                    //componentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.28)
                    componentView.layer.animateScale(from: (componentView.bounds.width - 10.0) / componentView.bounds.width, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    
                    //self.cloudShadowLayer0.animateAlpha(from: 0.0, to: 1.0, duration: 0.28)
                    //self.cloudLayer0.animateAlpha(from: 0.0, to: 1.0, duration: 0.28)
                    self.cloudLayer0.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.cloudShadowLayer0.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    
                    //self.cloudShadowLayer1.animateAlpha(from: 0.0, to: 1.0, duration: 0.28)
                    //self.cloudLayer1.animateAlpha(from: 0.0, to: 1.0, duration: 0.28)
                    self.cloudLayer1.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.cloudShadowLayer1.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let result = super.hitTest(point, with: event) {
                if self.isDismissed {
                    return self.view
                }
                
                if result === self.view {
                    self.isDismissed = true
                    self.controller?.dismiss()
                }
                
                return result
            }
            return nil
        }
        
        private func applyItem(item: EmojiPagerContentComponent.Item?) {
            let _ = (self.context.engine.accountData.setEmojiStatus(file: item?.itemFile)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controller?.dismiss()
            })
        }
    }
    
    private let context: AccountContext
    private weak var sourceView: UIView?
    private let emojiContent: Signal<EmojiPagerContentComponent, NoError>
    
    fileprivate let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, sourceView: UIView, emojiContent: Signal<EmojiPagerContentComponent, NoError>) {
        self.context = context
        self.sourceView = sourceView
        self.emojiContent = emojiContent
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        (self.displayNode as! Node).animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, sourceView: self.sourceView, emojiContent: self.emojiContent)

        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}
