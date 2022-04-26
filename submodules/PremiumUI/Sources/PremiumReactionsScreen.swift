import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import SolidRoundedButtonNode
import AppBundle

public final class PremiumStickersScreen: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let reactions: [AvailableReactions.Reaction]
    
    public var proceed: (() -> Void)?
    
    private class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: PremiumStickersScreen?
        private var presentationData: PresentationData
        
        private let blurView: UIVisualEffectView
        private let vibrancyView: UIVisualEffectView
        private let dimNode: ASDisplayNode
        private let darkDimNode: ASDisplayNode
        private let containerNode: ASDisplayNode
        
        private let textNode: ImmediateTextNode
        private let proceedButton: SolidRoundedButtonNode
        private let cancelButton: HighlightableButtonNode
        private let carouselNode: ReactionCarouselNode
        
        private var validLayout: ContainerViewLayout?
        
        init(controller: PremiumStickersScreen) {
            self.controller = controller
            self.presentationData = controller.presentationData
            
            self.dimNode = ASDisplayNode()
            let blurEffect = UIBlurEffect(style: self.presentationData.theme.overallDarkAppearance ? .dark : .light)
            self.blurView = UIVisualEffectView(effect: blurEffect)
            self.blurView.isUserInteractionEnabled = false
            
            self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
            
            self.darkDimNode = ASDisplayNode()
            self.darkDimNode.alpha = 0.0
            self.darkDimNode.backgroundColor = self.presentationData.theme.contextMenu.dimColor
            self.darkDimNode.isUserInteractionEnabled = false
            
            self.dimNode.backgroundColor = UIColor(white: self.presentationData.theme.overallDarkAppearance ? 0.0 : 1.0, alpha: 0.5)
            
            self.containerNode = ASDisplayNode()
            
            self.textNode = ImmediateTextNode()
            self.textNode.displaysAsynchronously = false
            self.textNode.textAlignment = .center
            self.textNode.maximumNumberOfLines = 0
            self.textNode.lineSpacing = 0.1
            self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.Premium_Reactions_Description, font: Font.regular(17.0), textColor: self.presentationData.theme.contextMenu.secondaryColor)
            self.textNode.alpha = 1.0
            
            self.proceedButton = SolidRoundedButtonNode(title: self.presentationData.strings.Premium_Reactions_Proceed, icon: UIImage(bundleImageName: "Premium/ButtonIcon"), theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 50.0, cornerRadius: 11.0, gloss: true)
            
            self.cancelButton = HighlightableButtonNode()
            self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
            
            self.carouselNode = ReactionCarouselNode(context: controller.context, theme: controller.presentationData.theme, reactions: controller.reactions)
            
            super.init()
            
            self.addSubnode(self.dimNode)
            self.addSubnode(self.darkDimNode)
            self.addSubnode(self.containerNode)
            
            self.containerNode.addSubnode(self.proceedButton)
            self.containerNode.addSubnode(self.cancelButton)
            self.addSubnode(self.carouselNode)
            
            self.proceedButton.pressed = { [weak self] in
                self?.animateOut()
            }
            
            self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.insertSubview(self.blurView, aboveSubview: self.dimNode.view)
            self.blurView.contentView.addSubview(self.vibrancyView)
            
            self.vibrancyView.contentView.addSubview(self.textNode.view)
            
            self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTap(_:))))
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            
            self.dimNode.backgroundColor = UIColor(white: self.presentationData.theme.overallDarkAppearance ? 0.0 : 1.0, alpha: 0.5)
            self.darkDimNode.backgroundColor = self.presentationData.theme.contextMenu.dimColor
            self.blurView.effect = UIBlurEffect(style: self.presentationData.theme.overallDarkAppearance ? .dark : .light)
        }
        
        func animateIn() {
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.blurView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            self.carouselNode.layer.animatePosition(from: CGPoint(x: 312.0, y: 252.0), to: self.carouselNode.position, duration: 0.45, timingFunction: kCAMediaTimingFunctionSpring)
            self.carouselNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.45, timingFunction: kCAMediaTimingFunctionSpring)
            self.carouselNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.carouselNode.animateIn()
            
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.containerNode.layer.animateScale(from: 0.95, to: 1.0, duration: 0.3)
            
            self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.vibrancyView.layer.animateScale(from: 0.95, to: 1.0, duration: 0.3)
        }
        
        func animateOut() {
            self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            self.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            self.carouselNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            self.blurView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.controller?.dismiss(animated: false, completion: nil)
                }
            })
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
                        
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(node: self.darkDimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(view: self.blurView, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(view: self.vibrancyView, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let carouselFrame = CGRect(origin: CGPoint(x: 0.0, y: 100.0), size: CGSize(width: layout.size.width, height: layout.size.width))
            self.carouselNode.updateLayout(size: carouselFrame.size, transition: transition)
            transition.updateFrame(node: self.carouselNode, frame: carouselFrame)
            
            let sideInset: CGFloat = 16.0
            
            let cancelSize = self.cancelButton.measure(layout.size)
            self.cancelButton.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - cancelSize.width) / 2.0), y: layout.size.height - cancelSize.height - 49.0), size: cancelSize)
            
            let buttonWidth = layout.size.width - sideInset * 2.0
            let buttonHeight = self.proceedButton.updateLayout(width: buttonWidth, transition: transition)
            self.proceedButton.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - cancelSize.height - 49.0 - buttonHeight - 23.0), size: CGSize(width: buttonWidth, height: buttonHeight))
            
            let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 5.0, height: CGFloat.greatestFiniteMagnitude))
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - textSize.width) / 2.0), y: layout.size.height - cancelSize.height - 48.0 - buttonHeight - 20.0 - textSize.height - 31.0), size: textSize)
        }
        
        
        @objc private func dimNodeTap(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.cancelPressed()
            }
        }
        
        @objc private func cancelPressed() {
            self.animateOut()
        }
    }
        
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, reactions: [AvailableReactions.Reaction]) {
        self.context = context
        self.reactions = reactions
        
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.updatedPresentationData = updatedPresentationData
                
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.controllerNode.updatePresentationData(strongSelf.presentationData)
                }
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)
                
        super.displayNodeDidLoad()
    }
    
    private var didAppear = false
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didAppear {
            self.didAppear = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
