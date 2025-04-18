import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramNotices
import TelegramPresentationData
import ActivityIndicator
import ChatPresentationInterfaceState
import ChatInputPanelNode
import ComponentFlow
import MultilineTextComponent
import PlainButtonComponent
import ComponentDisplayAdapters
import AccountContext

private let labelFont = Font.regular(15.0)

final class ChatPremiumRequiredInputPanelNode: ChatInputPanelNode {
    private struct Params: Equatable {
        var width: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var bottomInset: CGFloat
        var additionalSideInsets: UIEdgeInsets
        var maxHeight: CGFloat
        var isSecondary: Bool
        var interfaceState: ChatPresentationInterfaceState
        var metrics: LayoutMetrics
        var isMediaInputExpanded: Bool

        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.bottomInset = bottomInset
            self.additionalSideInsets = additionalSideInsets
            self.maxHeight = maxHeight
            self.isSecondary = isSecondary
            self.interfaceState = interfaceState
            self.metrics = metrics
            self.isMediaInputExpanded = isMediaInputExpanded
        }
    }

    private struct Layout {
        var params: Params
        var height: CGFloat

        init(params: Params, height: CGFloat) {
            self.params = params
            self.height = height
        }
    }

    private let button = ComponentView<Empty>()
    
    private var params: Params?
    private var currentLayout: Layout?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
        }
    }
    
    init(theme: PresentationTheme) {
        super.init()
    }
    
    deinit {
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, interfaceState: interfaceState, metrics: metrics, isMediaInputExpanded: isMediaInputExpanded)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.height
        }

        let height = self.update(params: params, transition: ComponentTransition(transition))
        self.currentLayout = Layout(params: params, height: height)

        return height
    }

    private func update(params: Params, transition: ComponentTransition) -> CGFloat {
        let height: CGFloat
        if case .regular = params.metrics.widthClass {
            height = 49.0
        } else {
            height = 45.0
        }
        
        let peerTitle: String
        if let peer = params.interfaceState.renderedPeer?.chatMainPeer {
            peerTitle = EnginePeer(peer).compactDisplayTitle
        } else {
            peerTitle = " "
        }
        
        let buttonTitle: String = params.interfaceState.strings.Chat_MessagingRestrictedPlaceholder(peerTitle).string
        let buttonSubtitle: String = params.interfaceState.strings.Chat_MessagingRestrictedPlaceholderAction
        
        var buttonContents: [AnyComponentWithIdentity<Empty>] = []
        buttonContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
            text: .plain(NSAttributedString(string: buttonTitle, font: Font.regular(13.0), textColor: params.interfaceState.theme.rootController.navigationBar.secondaryTextColor))
        ))))
        if let context = self.context {
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            if !premiumConfiguration.isPremiumDisabled {
                buttonContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: buttonSubtitle, font: Font.regular(13.0), textColor: params.interfaceState.theme.rootController.navigationBar.accentTextColor))
                ))))
            }
        }

        let size = CGSize(width: params.width - params.additionalSideInsets.left * 2.0 - params.leftInset * 2.0, height: height)
        let buttonSize = self.button.update(
            transition: .immediate,
            component: AnyComponent(PlainButtonComponent(
                content: AnyComponent(VStack(buttonContents, spacing: 1.0)),
                effectAlignment: .center,
                minSize: size,
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.openPremiumRequiredForMessaging()
                }
            )),
            environment: {},
            containerSize: size
        )
        if let buttonView = self.button.view {
            if buttonView.superview == nil {
                self.view.addSubview(buttonView)
            }
            transition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(), size: buttonSize))
        }

        return height
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
