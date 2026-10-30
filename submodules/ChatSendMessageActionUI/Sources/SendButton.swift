import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramCore
import TextFormat
import ReactionSelectionNode
import ViewControllerComponent
import ComponentFlow
import ComponentDisplayAdapters
import ChatMessageBackground
import WallpaperBackgroundNode
import AppBundle
import ActivityIndicator
import RadialStatusNode
import GlassBackgroundComponent

final class SendButton: HighlightTrackingButton {
    enum Kind {
        case send
        case edit
    }
    
    private let kind: Kind
    
    private let containerView: UIView
    private let backgroundView: UIImageView
    // Stands in for `backgroundView` when the source button is glass (bubble mode off), so the copy looks the same.
    private var glassContainerView: GlassBackgroundContainerView?
    private var glassView: GlassBackgroundView?
    private var glassIconImage: (source: UIImage, image: UIImage)?
    private let iconView: UIImageView
    private var activityIndicator: RadialStatusNode?
    
    private var previousIsAnimatedIn: Bool?
    private var sourceCustomContentView: UIView?
    private weak var extractedContainerView: ContextExtractedContentContainingView?

    init(kind: Kind) {
        self.kind = kind
        
        self.containerView = UIView()
        self.containerView.isUserInteractionEnabled = false
        
        self.backgroundView = UIImageView()
        self.backgroundView.image = generateStretchableFilledCircleImage(diameter: 34.0, color: .white)?.withRenderingMode(.alwaysTemplate)
        
        self.iconView = UIImageView()
        self.iconView.isUserInteractionEnabled = false
        
        super.init(frame: CGRect())
        
        self.containerView.clipsToBounds = true
        self.addSubview(self.containerView)
        
        self.containerView.addSubview(self.backgroundView)
        self.containerView.addSubview(self.iconView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(
        context: AccountContext,
        presentationData: PresentationData,
        backgroundNode: WallpaperBackgroundNode?,
        sourceSendButton: UIView,
        isAnimatedIn: Bool,
        isLoadingEffectAnimation: Bool,
        size: CGSize,
        transition: ComponentTransition
    ) {
        if let extractedContainer = sourceSendButton as? ContextExtractedContentContainingView {
            self.containerView.isHidden = true
            self.sourceCustomContentView?.isHidden = true

            let contentView = extractedContainer.contentView

            if self.extractedContainerView !== extractedContainer {
                self.extractedContainerView = extractedContainer
                self.previousIsAnimatedIn = nil
            }

            if self.previousIsAnimatedIn != isAnimatedIn {
                self.previousIsAnimatedIn = isAnimatedIn

                if isAnimatedIn {
                    extractedContainer.willUpdateIsExtractedToContextPreview?(true, .animated(duration: 0.3, curve: .spring))
                    extractedContainer.isExtractedToContextPreview = true
                    extractedContainer.isExtractedToContextPreviewUpdated?(true)

                    extractedContainer.layer.removeAnimation(forKey: "extractedContentReturn")
                    
                    self.addSubview(contentView)
                } else {
                    extractedContainer.willUpdateIsExtractedToContextPreview?(false, .animated(duration: 0.3, curve: .spring))
                    extractedContainer.isExtractedToContextPreview = false
                    extractedContainer.isExtractedToContextPreviewUpdated?(false)

                    transition.attachAnimation(view: self, id: "extractedContentReturn", completion: { [weak extractedContainer] _ in
                        guard let extractedContainer else {
                            return
                        }
                        extractedContainer.addSubview(extractedContainer.contentView)
                    })
                }
            }

            if contentView.superview === self {
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: size))
            }

            return
        }

        self.containerView.isHidden = false
        self.extractedContainerView = nil

        let sourceButtonNode = sourceSendButton.asyncdisplaykit_node as? ChatSendMessageActionSheetControllerSourceSendButtonNode
        let glassTintColor = sourceButtonNode?.sendButtonGlassTintColor
        
        let innerSize: CGSize
        let containerFrame: CGRect
        if glassTintColor != nil, let sourceGlassFrame = sourceButtonNode?.sendButtonGlassFrame {
            // A glass button keeps exactly its size and place: this view is the source's frame aligned to its right
            // edge (see ChatSendMessageContextScreen), so the glass moves by the width the menu cut off.
            innerSize = sourceGlassFrame.size
            containerFrame = sourceGlassFrame.offsetBy(dx: size.width - sourceSendButton.bounds.width, dy: 0.0)
        } else {
            if size.height == 40.0 {
                innerSize = CGSize(width: size.width - 3.0 * 2.0, height: size.height - 3.0 * 2.0)
            } else {
                innerSize = CGSize(width: isAnimatedIn ? 38.0 : size.width - 5.0 * 2.0, height: 33.0)
            }
            containerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - innerSize.width) * 0.5), y: floorToScreenPixels((size.height - innerSize.height) * 0.5)), size: innerSize)
        }
        transition.setFrame(view: self.containerView, frame: containerFrame)
        transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: innerSize.height * 0.5)
        
        self.backgroundView.tintColor = presentationData.theme.chat.inputPanel.actionControlFillColor
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: innerSize))
        
        if let glassTintColor {
            let glassContainerView: GlassBackgroundContainerView
            let glassView: GlassBackgroundView
            var glassTransition = transition
            if let currentContainer = self.glassContainerView, let current = self.glassView {
                glassContainerView = currentContainer
                glassView = current
            } else {
                glassTransition = .immediate
                glassContainerView = GlassBackgroundContainerView(spacing: 0.0)
                glassContainerView.isUserInteractionEnabled = false
                glassView = GlassBackgroundView()
                glassView.isUserInteractionEnabled = false
                glassContainerView.contentView.addSubview(glassView)
                self.glassContainerView = glassContainerView
                self.glassView = glassView
                self.containerView.insertSubview(glassContainerView, aboveSubview: self.backgroundView)
            }
            glassTransition.setFrame(view: glassContainerView, frame: CGRect(origin: CGPoint(), size: innerSize))
            glassContainerView.update(size: innerSize, isDark: presentationData.theme.overallDarkAppearance, transition: glassTransition)
            glassTransition.setFrame(view: glassView, frame: CGRect(origin: CGPoint(), size: innerSize))
            glassView.update(size: innerSize, cornerRadius: innerSize.height * 0.5, isDark: presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .custom(style: .default, color: glassTintColor)), transition: glassTransition)
            self.backgroundView.isHidden = true
        } else {
            if let glassContainerView = self.glassContainerView {
                self.glassContainerView = nil
                self.glassView = nil
                glassContainerView.removeFromSuperview()
            }
            self.backgroundView.isHidden = false
        }
        
        if self.previousIsAnimatedIn != isAnimatedIn {
            self.previousIsAnimatedIn = isAnimatedIn
            
            var sourceCustomContentViewAlpha: CGFloat = 1.0
            if let sourceCustomContentView = self.sourceCustomContentView {
                sourceCustomContentViewAlpha = sourceCustomContentView.alpha
                sourceCustomContentView.removeFromSuperview()
                self.sourceCustomContentView = nil
            }
            
            if let sourceSendButton = sourceSendButton.asyncdisplaykit_node as? ChatSendMessageActionSheetControllerSourceSendButtonNode {
                if let sourceCustomContentView = sourceSendButton.makeCustomContents() {
                    self.sourceCustomContentView = sourceCustomContentView
                    sourceCustomContentView.alpha = sourceCustomContentViewAlpha
                    self.addSubview(sourceCustomContentView)
                }
            }
        }
        
        if self.iconView.image == nil {
            switch self.kind {
            case .send:
                self.iconView.image = PresentationResourcesChat.chatInputPanelSendIconImage(presentationData.theme)
            case .edit:
                self.iconView.image = PresentationResourcesChat.chatInputPanelApplyIconImage(presentationData.theme)
            }
        }
        
        if let sourceCustomContentView = self.sourceCustomContentView {
            var sourceCustomContentTransition = transition
            if sourceCustomContentView.bounds.isEmpty {
                sourceCustomContentTransition = .immediate
            }
            
            let sourceCustomContentSize = sourceCustomContentView.bounds.size
            let sourceCustomContentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((innerSize.width - sourceCustomContentSize.width) * 0.5) + UIScreenPixel, y: floorToScreenPixels((innerSize.height - sourceCustomContentSize.height) * 0.5)), size: sourceCustomContentSize).offsetBy(dx: containerFrame.minX, dy: containerFrame.minY)
            sourceCustomContentTransition.setPosition(view: sourceCustomContentView, position: sourceCustomContentFrame.center)
            sourceCustomContentTransition.setBounds(view: sourceCustomContentView, bounds: CGRect(origin: CGPoint(), size: sourceCustomContentFrame.size))
            sourceCustomContentTransition.setAlpha(view: sourceCustomContentView, alpha: isAnimatedIn ? 0.0 : 1.0)
        }
        
        if glassTintColor != nil, let source = self.iconView.image, self.glassIconImage?.image !== source {
            // The glass button draws a white glyph whatever the theme's glyph colour, as the source button does.
            if let cache = self.glassIconImage, cache.source === source {
                self.iconView.image = cache.image
            } else if let tinted = generateTintedImage(image: source, color: .white) {
                self.glassIconImage = (source, tinted)
                self.iconView.image = tinted
            }
        }
        
        if let icon = self.iconView.image {
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((innerSize.width - icon.size.width) * 0.5), y: floorToScreenPixels((innerSize.height - icon.size.height) * 0.5)), size: icon.size)
            transition.setPosition(view: self.iconView, position: iconFrame.center)
            transition.setBounds(view: self.iconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            
            let iconViewAlpha: CGFloat
            if (self.sourceCustomContentView != nil && !isAnimatedIn) || isLoadingEffectAnimation {
                iconViewAlpha = 0.0
            } else {
                iconViewAlpha = 1.0
            }
            transition.setAlpha(view: self.iconView, alpha: iconViewAlpha)
            transition.setScale(view: self.iconView, scale: isLoadingEffectAnimation ? 0.001 : 1.0)
        }
        
        if isLoadingEffectAnimation {
            var animateIn = false
            let activityIndicator: RadialStatusNode
            if let current = self.activityIndicator {
                activityIndicator = current
            } else {
                animateIn = true
                activityIndicator = RadialStatusNode(
                    backgroundNodeColor: .clear,
                    enableBlur: false,
                    isPreview: false
                )
                activityIndicator.transitionToState(.progress(
                    color: presentationData.theme.list.itemCheckColors.foregroundColor,
                    lineWidth: 2.0,
                    value: nil,
                    cancelEnabled: false,
                    animateRotation: true
                ))
                self.activityIndicator = activityIndicator
                self.containerView.addSubview(activityIndicator.view)
            }
            
            let activityIndicatorSize = CGSize(width: 18.0, height: 18.0)
            let activityIndicatorFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((innerSize.width - activityIndicatorSize.width) * 0.5), y: floor((innerSize.height - activityIndicatorSize.height) * 0.5) + UIScreenPixel), size: activityIndicatorSize)
            if animateIn {
                activityIndicator.view.frame = activityIndicatorFrame
                transition.animateAlpha(view: activityIndicator.view, from: 0.0, to: 1.0)
                transition.animateScale(view: activityIndicator.view, from: 0.001, to: 1.0)
            } else {
                transition.setFrame(view: activityIndicator.view, frame: activityIndicatorFrame)
            }
        } else {
            if let activityIndicator = self.activityIndicator {
                self.activityIndicator = nil
                transition.setAlpha(view: activityIndicator.view, alpha: 0.0, completion: { [weak activityIndicator] _ in
                    activityIndicator?.view.removeFromSuperview()
                })
                transition.setScale(view: activityIndicator.view, scale: 0.001)
            }
        }
    }
    
    func updateGlobalRect(rect: CGRect, within containerSize: CGSize, transition: ComponentTransition) {
    }
}
