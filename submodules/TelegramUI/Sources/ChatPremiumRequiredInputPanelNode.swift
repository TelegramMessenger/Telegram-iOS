import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
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
import GlassBackgroundComponent

private let labelFont = Font.regular(15.0)

final class ChatPremiumRequiredInputPanelNode: ChatInputPanelNode {
    private struct Params: Equatable {
        var width: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var bottomInset: CGFloat
        var additionalSideInsets: UIEdgeInsets
        var maxHeight: CGFloat
        var maxOverlayHeight: CGFloat
        var isSecondary: Bool
        var interfaceState: ChatPresentationInterfaceState
        var metrics: LayoutMetrics
        var deviceMetrics: DeviceMetrics
        var isMediaInputExpanded: Bool

        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isMediaInputExpanded: Bool) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.bottomInset = bottomInset
            self.additionalSideInsets = additionalSideInsets
            self.maxHeight = maxHeight
            self.maxOverlayHeight = maxOverlayHeight
            self.isSecondary = isSecondary
            self.interfaceState = interfaceState
            self.metrics = metrics
            self.deviceMetrics = deviceMetrics
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

    private let backgroundView: GlassBackgroundView
    private let button = ComponentView<Empty>()
    private let tintContent = ComponentView<Empty>()
    
    private var params: Params?
    private var currentLayout: Layout?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
        }
    }
    
    init(theme: PresentationTheme) {
        self.backgroundView = GlassBackgroundView()
        
        super.init()
        
        self.view.addSubview(self.backgroundView)
    }
    
    deinit {
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, maxOverlayHeight: maxOverlayHeight, isSecondary: isSecondary, interfaceState: interfaceState, metrics: metrics, deviceMetrics: deviceMetrics, isMediaInputExpanded: isMediaInputExpanded)
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
        var tintContents: [AnyComponentWithIdentity<Empty>] = []
        buttonContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
            text: .plain(NSAttributedString(string: buttonTitle, font: Font.regular(13.0), textColor: params.interfaceState.theme.rootController.navigationBar.secondaryTextColor))
        ))))
        tintContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
            text: .plain(NSAttributedString(string: buttonTitle, font: Font.regular(13.0), textColor: .black))
        ))))
        if let context = self.context {
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            if !premiumConfiguration.isPremiumDisabled {
                buttonContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: buttonSubtitle, font: Font.regular(13.0), textColor: params.interfaceState.theme.rootController.navigationBar.accentTextColor))
                ))))
                tintContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: buttonSubtitle, font: Font.regular(13.0), textColor: .black))
                ))))
            }
        }

        let buttonHeight: CGFloat = 40.0
        let horizontalContentInset: CGFloat = 12.0
        let size = CGSize(width: max(1.0, params.width - params.additionalSideInsets.left * 2.0 - params.leftInset * 2.0 - 32.0), height: buttonHeight)
        let buttonSize = self.button.update(
            transition: .immediate,
            component: AnyComponent(PlainButtonComponent(
                content: AnyComponent(VStack(buttonContents, spacing: 1.0)),
                effectAlignment: .center,
                minSize: CGSize(width: 1.0, height: buttonHeight),
                contentInsets: UIEdgeInsets(top: 0.0, left: horizontalContentInset, bottom: 0.0, right: horizontalContentInset),
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.openPremiumRequiredForMessaging()
                },
                animateAlpha: false,
                animateScale: false
            )),
            environment: {},
            containerSize: size
        )
        let backgroundFrame = CGRect(
            origin: CGPoint(
                x: floorToScreenPixels((params.width - buttonSize.width) / 2.0),
                y: floorToScreenPixels((height - buttonHeight) / 2.0)
            ),
            size: buttonSize
        )
        transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: buttonHeight * 0.5, isDark: params.interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
        
        if let buttonView = self.button.view {
            if buttonView.superview == nil {
                self.backgroundView.contentView.addSubview(buttonView)
            }
            transition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(), size: buttonSize))
        }
        
        let tintContentSize = self.tintContent.update(
            transition: .immediate,
            component: AnyComponent(VStack(tintContents, spacing: 1.0)),
            environment: {},
            containerSize: CGSize(width: max(1.0, buttonSize.width - horizontalContentInset * 2.0), height: buttonHeight)
        )
        if let tintContentView = self.tintContent.view {
            if tintContentView.superview == nil {
                tintContentView.isUserInteractionEnabled = false
                self.backgroundView.maskContentView.addSubview(tintContentView)
            }
            transition.setFrame(view: tintContentView, frame: CGRect(
                origin: CGPoint(
                    x: floor((buttonSize.width - tintContentSize.width) * 0.5),
                    y: floor((buttonSize.height - tintContentSize.height) * 0.5)
                ),
                size: tintContentSize
            ))
        }

        return height
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
