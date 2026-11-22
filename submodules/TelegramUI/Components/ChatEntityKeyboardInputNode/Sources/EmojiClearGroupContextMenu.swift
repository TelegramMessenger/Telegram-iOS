import Foundation
import UIKit
import Display
import TelegramPresentationData
import ContextUI

private final class EmojiClearGroupReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    private let sourceRect: CGRect

    init(sourceView: UIView, sourceRect: CGRect) {
        self.sourceView = sourceView
        self.sourceRect = sourceRect
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        let bounds = self.sourceView.bounds
        let insets = UIEdgeInsets(
            top: self.sourceRect.minY - bounds.minY,
            left: self.sourceRect.minX - bounds.minX,
            bottom: bounds.maxY - self.sourceRect.maxY,
            right: bounds.maxX - self.sourceRect.maxX
        )
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds, insets: insets)
    }
}

public func makeEmojiClearGroupContextController(presentationData: PresentationData, title: String, sourceView: UIView, sourceRect: CGRect, action: @escaping () -> Void) -> ViewController {
    let items: [ContextMenuItem] = [
        .action(ContextMenuActionItem(text: title, textColor: .destructive, icon: { _ in
            return nil
        }, action: { _, f in
            f(.default)
            action()
        }))
    ]
    return makeContextController(presentationData: presentationData, source: .reference(EmojiClearGroupReferenceContentSource(sourceView: sourceView, sourceRect: sourceRect)), items: .single(ContextController.Items(content: .list(items))))
}
