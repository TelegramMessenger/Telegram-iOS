import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import EmojiStatusComponent

final class EmptySearchResultsView: UIView {
    override public static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    let tintContainerView: UIView
    let titleLabel: ComponentView<Empty>
    let titleTintLabel: ComponentView<Empty>
    let icon: ComponentView<Empty>
    
    override init(frame: CGRect) {
        self.tintContainerView = UIView()
        
        self.titleLabel = ComponentView()
        self.titleTintLabel = ComponentView()
        self.icon = ComponentView()
        
        super.init(frame: frame)
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.tintContainerView.layer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(context: AccountContext, theme: PresentationTheme, useOpaqueTheme: Bool, text: String, file: TelegramMediaFile?, size: CGSize, searchInitiallyHidden: Bool, transition: ComponentTransition) {
        let titleColor: UIColor
        if useOpaqueTheme {
            titleColor = theme.chat.inputMediaPanel.panelContentOpaqueSearchOverlayColor
        } else {
            titleColor = theme.chat.inputMediaPanel.panelContentVibrantSearchOverlayColor
        }
        
        let iconSize: CGSize
        if let file = file {
            iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    content: .animation(content: .file(file: file), size: CGSize(width: 32.0, height: 32.0), placeholderColor: titleColor, themeColor: nil, loopMode: .forever),
                    isVisibleForAnimations: context.sharedContext.energyUsageSettings.loopEmoji,
                    action: nil
                )),
                environment: {},
                containerSize: CGSize(width: 32.0, height: 32.0)
            )
        } else {
            iconSize = CGSize()
        }
        
        let titleSize = self.titleLabel.update(
            transition: .immediate,
            component: AnyComponent(Text(text: text, font: Font.regular(15.0), color: titleColor)),
            environment: {},
            containerSize: CGSize(width: size.width, height: 100.0)
        )
        let _ = self.titleTintLabel.update(
            transition: .immediate,
            component: AnyComponent(Text(text: text, font: Font.regular(15.0), color: .white)),
            environment: {},
            containerSize: CGSize(width: size.width, height: 100.0)
        )
        
        let spacing: CGFloat = 4.0
        let contentHeight = iconSize.height + spacing + titleSize.height
        let contentOriginY = searchInitiallyHidden ? floor((size.height - contentHeight) / 2.0) : 10.0
        let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: contentOriginY), size: iconSize)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: iconFrame.maxY + spacing), size: titleSize)
        
        if let iconView = self.icon.view {
            if iconView.superview == nil {
                self.addSubview(iconView)
            }
            transition.setFrame(view: iconView, frame: iconFrame)
        }
        if let titleLabelView = self.titleLabel.view {
            if titleLabelView.superview == nil {
                self.addSubview(titleLabelView)
            }
            transition.setFrame(view: titleLabelView, frame: titleFrame)
        }
        if let titleTintLabelView = self.titleTintLabel.view {
            if titleTintLabelView.superview == nil {
                self.tintContainerView.addSubview(titleTintLabelView)
            }
            transition.setFrame(view: titleTintLabelView, frame: titleFrame)
        }
    }
}
