import UIKit
import AsyncDisplayKit
import ComponentFlow
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData
import ShareController
import ViewControllerComponent
import ContextUI

public final class ShareScreenExternalConfiguration {
    public let environment: ShareControllerEnvironment
    public let accounts: [(context: AccountContext, peer: EnginePeer)]
    public let immediatePeerId: EnginePeer.Id?

    public init(environment: ShareControllerEnvironment, accounts: [(context: AccountContext, peer: EnginePeer)], immediatePeerId: EnginePeer.Id? = nil) {
        self.environment = environment
        self.accounts = accounts
        self.immediatePeerId = immediatePeerId
    }
}

final class ShareScreenAccountReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView
    private let actionsPosition: ContextControllerReferenceViewInfo.ActionsPosition
    let forceDisplayBelowKeyboard = true

    init(sourceView: UIView, actionsPosition: ContextControllerReferenceViewInfo.ActionsPosition = .bottom) {
        self.sourceView = sourceView
        self.actionsPosition = actionsPosition
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds, actionsPosition: self.actionsPosition)
    }
}

final class ShareScreenLoadingComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let node: ASDisplayNode
    let visibleHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    init(node: ASDisplayNode, visibleHeight: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
        self.node = node
        self.visibleHeight = visibleHeight
        self.topInset = topInset
        self.bottomInset = bottomInset
    }

    static func ==(lhs: ShareScreenLoadingComponent, rhs: ShareScreenLoadingComponent) -> Bool {
        return lhs.node === rhs.node && lhs.visibleHeight == rhs.visibleHeight && lhs.topInset == rhs.topInset && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private var node: ASDisplayNode?

        func update(component: ShareScreenLoadingComponent, availableSize: CGSize, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            if self.node !== component.node {
                self.node?.view.removeFromSuperview()
                self.node = component.node
                self.addSubview(component.node.view)
                transition.animateAlpha(view: component.node.view, from: 0.0, to: 1.0)
            }
            let theme = environment[EnvironmentType.self].value.theme
            let size = CGSize(width: availableSize.width, height: component.visibleHeight)
            let isProlonged = component.node is ShareProlongedLoadingContainerNode
            let nodeHeight: CGFloat = isProlonged ? 257.0 : 125.0
            let visualHeight: CGFloat = isProlonged ? 233.0 : 125.0
            let availableHeight = max(visualHeight, component.visibleHeight - component.topInset - component.bottomInset)
            let nodeSize = CGSize(width: availableSize.width, height: nodeHeight)
            component.node.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels(component.topInset + (availableHeight - visualHeight) * 0.5)), size: nodeSize)
            if let node = component.node as? ShareProlongedLoadingContainerNode {
                node.updateTheme(theme)
                node.updateLayout(size: nodeSize, isLandscape: false, bottomInset: 0.0, transition: .immediate)
            } else if let node = component.node as? ShareLoadingContainerNode {
                node.updateTheme(theme)
                node.updateLayout(size: nodeSize, isLandscape: false, bottomInset: 0.0, transition: .immediate)
            }
            return size
        }
    }

    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

final class ShareScreenBodyComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let content: AnyComponent<EnvironmentType>
    let loadingNode: ASDisplayNode?
    let loadingHeight: CGFloat

    init(content: AnyComponent<EnvironmentType>, loadingNode: ASDisplayNode?, loadingHeight: CGFloat) {
        self.content = content
        self.loadingNode = loadingNode
        self.loadingHeight = loadingHeight
    }

    static func ==(lhs: ShareScreenBodyComponent, rhs: ShareScreenBodyComponent) -> Bool {
        return lhs.content == rhs.content && lhs.loadingNode === rhs.loadingNode && lhs.loadingHeight == rhs.loadingHeight
    }

    final class View: UIView {
        private let content = ComponentView<EnvironmentType>()
        private var loading = ComponentView<EnvironmentType>()
        private var hadLoadingNode = false

        func update(component: ShareScreenBodyComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environmentValue = environment[EnvironmentType.self].value
            let bandMinX = environmentValue.safeInsets.left
            let bandSize = CGSize(width: max(0.0, availableSize.width - environmentValue.safeInsets.left - environmentValue.safeInsets.right), height: availableSize.height)
            self.content.parentState = state
            self.loading.parentState = state
            let size: CGSize
            if component.loadingNode != nil && !self.hadLoadingNode && !transition.animation.isImmediate, let contentView = self.content.view as? ShareScreenContentComponent.View {
                contentView.scatterItems(into: self)
            } else if component.loadingNode == nil && self.hadLoadingNode, let contentView = self.content.view as? ShareScreenContentComponent.View {
                contentView.setItemsHidden(false)
            }
            self.hadLoadingNode = component.loadingNode != nil
            if let node = component.loadingNode {
                let loadingSize = self.loading.update(transition: transition, component: AnyComponent(ShareScreenLoadingComponent(node: node, visibleHeight: component.loadingHeight, topInset: 60.0, bottomInset: environmentValue.safeInsets.bottom)), environment: { environmentValue }, containerSize: bandSize)
                if let view = self.loading.view {
                    if view.superview == nil { self.addSubview(view) }
                    view.frame = CGRect(origin: CGPoint(x: bandMinX, y: 0.0), size: loadingSize)
                }
                size = CGSize(width: availableSize.width, height: loadingSize.height)
            } else {
                self.loading.view?.removeFromSuperview()
                self.loading = ComponentView<EnvironmentType>()
                let contentSize = self.content.update(transition: transition, component: component.content, environment: { environmentValue }, containerSize: bandSize)
                if let view = self.content.view {
                    if view.superview == nil { self.insertSubview(view, at: 0) }
                    view.frame = CGRect(origin: CGPoint(x: bandMinX, y: 0.0), size: contentSize)
                }
                size = CGSize(width: availableSize.width, height: contentSize.height)
            }
            if let view = self.content.view {
                view.isUserInteractionEnabled = component.loadingNode == nil
                view.accessibilityElementsHidden = component.loadingNode != nil
                transition.setAlpha(view: view, alpha: component.loadingNode == nil ? 1.0 : 0.0)
            }
            return size
        }
    }

    func makeView() -> View { return View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
