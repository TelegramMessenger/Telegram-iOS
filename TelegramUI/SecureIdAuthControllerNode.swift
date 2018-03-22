import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore

final class SecureIdAuthControllerNode: ViewControllerTracingNode {
    private let account: Account
    private var presentationData: PresentationData
    private let requestLayout: (ContainedViewLayoutTransition) -> Void
    private let interaction: SecureIdAuthControllerInteraction
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let headerNode: SecureIdAuthHeaderNode
    private var contentNode: (ASDisplayNode & SecureIdAuthContentNode)?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    init(account: Account, presentationData: PresentationData, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void, interaction: SecureIdAuthControllerInteraction) {
        self.account = account
        self.presentationData = presentationData
        self.requestLayout = requestLayout
        self.interaction = interaction
        
        self.headerNode = SecureIdAuthHeaderNode(account: account, theme: presentationData.theme, strings: presentationData.strings)
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.bottom = max(insets.bottom, layout.safeInsets.bottom)
        
        let contentRect = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - insets.bottom - navigationBarHeight))
        
        let headerNodeTransition: ContainedViewLayoutTransition = headerNode.bounds.isEmpty ? .immediate : transition
        let headerHeight = self.headerNode.updateLayout(width: layout.size.width, transition: headerNodeTransition)
        
        if let contentNode = self.contentNode {
            let contentNodeTransition: ContainedViewLayoutTransition = contentNode.bounds.isEmpty ? .immediate : transition
            let contentLayout = contentNode.updateLayout(width: layout.size.width, transition: contentNodeTransition)
            
            let contentSpacing: CGFloat = 70.0
            
            let boundingHeight = headerHeight + contentLayout.height + contentSpacing
            
            let boundingRect = CGRect(origin: CGPoint(x: 0.0, y: contentRect.minY + floor((contentRect.height - boundingHeight) / 2.0)), size: CGSize(width: layout.size.width, height: boundingHeight))
            
            headerNodeTransition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: boundingRect.minY), size: CGSize(width: boundingRect.width, height: headerHeight)))
            
            contentNodeTransition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: boundingRect.minY + headerHeight + contentSpacing), size: CGSize(width: boundingRect.width, height: contentLayout.height)))
        }
    }
    
    func transitionToContentNode(_ contentNode: (ASDisplayNode & SecureIdAuthContentNode)?, transition: ContainedViewLayoutTransition) {
        if let current = self.contentNode {
            current.willDisappear()
            current.animateOut { [weak current] in
                current?.removeFromSupernode()
            }
        }
        
        self.contentNode = contentNode
        
        if let contentNode = self.contentNode {
            self.addSubnode(contentNode)
            if let (layout, navigationBarHeight) = self.validLayout {
                self.scheduleLayoutTransitionRequest(.animated(duration: 0.5, curve: .spring))
                contentNode.didAppear()
                contentNode.animateIn()
            }
        }
    }
    
    func updateState(_ state: SecureIdAuthControllerState, transition: ContainedViewLayoutTransition) {
        if let formData = state.formData, let verificationState = state.verificationState {
            if self.headerNode.supernode == nil {
                self.addSubnode(self.headerNode)
                self.headerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            self.headerNode.updateState(formData: formData, verificationState: verificationState)
            
            switch verificationState {
                case let .passwordChallenge(challengeState):
                    if let contentNode = self.contentNode as? SecureIdAuthPasswordOptionContentNode {
                        contentNode.updateIsChecking(challengeState == .checking)
                    } else {
                        let contentNode = SecureIdAuthPasswordOptionContentNode(theme: presentationData.theme, strings: presentationData.strings, checkPassword: { [weak self] password in
                            if let strongSelf = self {
                                strongSelf.interaction.checkPassword(password)
                            }
                        })
                        contentNode.updateIsChecking(challengeState == .checking)
                        self.transitionToContentNode(contentNode, transition: transition)
                        
                    }
                case .noChallenge:
                    if self.contentNode != nil {
                        self.transitionToContentNode(nil, transition: transition)
                    }
                case .verified:
                    if let contentNode = self.contentNode as? SecureIdAuthFormContentNode {
                        
                    } else {
                        let contentNode = SecureIdAuthFormContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, form: formData.form, openField: { [weak self] type in
                            if let strongSelf = self {
                                strongSelf.interaction.present(SecureIdIdentityFormController(account: strongSelf.account, data: nil), nil)
                            }
                        })
                        self.transitionToContentNode(contentNode, transition: transition)
                    }
            }
        }
    }
    
    private func scheduleLayoutTransitionRequest(_ transition: ContainedViewLayoutTransition) {
        let requestId = self.scheduledLayoutTransitionRequestId
        self.scheduledLayoutTransitionRequestId += 1
        self.scheduledLayoutTransitionRequest = (requestId, transition)
        (self.view as? UITracingLayerView)?.schedule(layout: { [weak self] in
            if let strongSelf = self {
                if let (currentRequestId, currentRequestTransition) = strongSelf.scheduledLayoutTransitionRequest, currentRequestId == requestId {
                    strongSelf.scheduledLayoutTransitionRequest = nil
                    strongSelf.requestLayout(currentRequestTransition)
                }
            }
        })
        self.setNeedsLayout()
    }
}
