import Foundation
import UIKit
import SwiftSignalKit
import Display
import ComponentFlow
import TelegramCore
import AccountContext
import EmojiStatusComponent

final class ReactionPreviewView: UIView {
    private let context: AccountContext
    private let file: TelegramMediaFile
    
    private let icon = ComponentView<Empty>()

    init(context: AccountContext, file: TelegramMediaFile) {
        self.context = context
        self.file = file
        
        super.init(frame: CGRect())
    }

    required init(coder: NSCoder) {
        preconditionFailure()
    }

    func update(size: CGSize) {
        let iconSize = self.icon.update(
            transition: .immediate,
            component: AnyComponent(EmojiStatusComponent(
                context: self.context,
                animationCache: self.context.animationCache,
                animationRenderer: self.context.animationRenderer,
                content: .animation(
                    content: .file(file: self.file),
                    size: size,
                    placeholderColor: .clear,
                    themeColor: .white,
                    loopMode: .forever
                ),
                isVisibleForAnimations: true,
                action: nil
            )),
            environment: {},
            containerSize: size
        )
        let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
        if let iconView = self.icon.view {
            if iconView.superview == nil {
                self.addSubview(iconView)
            }
            iconView.frame = iconFrame
        }
    }
}
